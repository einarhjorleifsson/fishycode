# write_curated.R — the only way anything enters curated/.
#
# Input:  a data frame (or sf object) and a path under $FISHYDATA/curated/
# Output: a parquet file carrying provenance in its key/value metadata
#
# Why this exists rather than write_parquet():
#
# A curated file is the product. Six months later the only question that
# matters about a row is "what produced this, from what, and was the tree
# clean at the time" - and nothing in a bare parquet file answers it. The
# stamps below are written at the one moment they are knowable for free.
#
# COPY ... (FORMAT parquet, KV_METADATA {...}) is used rather than
# arrow/nanoparquet for two reasons: those writers emit TIMESTAMP WITH TIME
# ZONE, which DuckDB cannot subtract, and neither writes KV metadata at all.
#
# sf objects are accepted: geometry is stored as WKB and the CRS recorded in
# the metadata, so curated/ stays parquet-only and an analyst still gets
# geometry back (see read_curated_sf()).

.git_info <- function() {
  g <- function(...) tryCatch(
    system2("git", c(...), stdout = TRUE, stderr = FALSE),
    warning = function(e) NA_character_, error = function(e) NA_character_)
  sha   <- g("rev-parse", "HEAD")
  dirty <- length(g("status", "--porcelain")) > 0
  repo  <- g("rev-parse", "--show-toplevel")
  list(repo   = if (length(repo)) basename(repo[1]) else NA_character_,
       commit = if (length(sha)) sha[1] else NA_character_,
       dirty  = if (is.na(dirty)) NA else dirty)
}

# The script currently being source()d, which is how targets runs everything
# here (see produces() in _targets.R). source() keeps the path in a local
# `ofile`, so walk the stack outward looking for it.
.calling_script <- function() {
  for (i in rev(seq_len(sys.nframe()))) {
    of <- tryCatch(get("ofile", envir = sys.frame(i), inherits = FALSE),
                   error = function(e) NULL)
    if (is.character(of) && length(of) == 1L) {
      return(sub(paste0("^", getwd(), "/"), "", normalizePath(of, mustWork = FALSE)))
    }
  }
  NA_character_
}

.schema_hash <- function(d) {
  substr(digest_string(paste(names(d), vapply(d, \(x) class(x)[1], ""),
                             collapse = "|")), 1, 16)
}

# Small dependency-free hash so this file needs nothing beyond base + duckdb.
digest_string <- function(x) {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, "SELECT md5(?) h", params = list(x))$h
}

write_curated <- function(d, path, inputs = character(), script = NULL) {
  stopifnot(is.data.frame(d))
  if (!grepl("/curated/", path, fixed = TRUE))
    stop("write_curated() writes under curated/ only; got: ", path, call. = FALSE)

  crs <- NA_character_; geom <- NA_character_
  if (inherits(d, "sf")) {
    geom <- attr(d, "sf_column")
    crs  <- sf::st_crs(d)$wkt
    # Drop to a plain data frame BEFORE assigning. st_as_binary() returns a
    # WKB-classed list, and assigning that into a tibble-backed sf dispatches
    # to tibble's [[<- , which rejects it as a non-vector. unclass() makes it
    # an ordinary list of raw, which duckdb registers as BLOB.
    wkb <- unclass(sf::st_as_binary(sf::st_geometry(d)))
    d <- as.data.frame(sf::st_drop_geometry(d))
    d[[geom]] <- wkb
  }

  g  <- .git_info()
  ih <- if (length(inputs)) {
    ex <- inputs[file.exists(inputs)]
    paste(sprintf("%s=%s", basename(ex), unname(tools::md5sum(ex))), collapse = ";")
  } else NA_character_

  kv <- c(
    "fd.repo"         = g$repo,
    "fd.commit"       = g$commit,
    "fd.dirty"        = tolower(as.character(g$dirty)),
    "fd.script"       = script %||% .calling_script(),
    "fd.built"        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    "fd.rows"         = as.character(nrow(d)),
    "fd.schema_hash"  = .schema_hash(d),
    "fd.inputs"       = ih,
    "fd.geometry"     = geom,
    "fd.crs"          = crs
  )
  kv <- kv[!is.na(kv)]

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "cur", d)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"),
                        shQuote(unname(kv), type = "sh")), collapse = ", ")
  DBI::dbExecute(con, sprintf("COPY cur TO %s (FORMAT parquet, KV_METADATA {%s})",
                              shQuote(path, type = "sh"), meta))
  invisible(path)
}

`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

# Read back a curated file that carries geometry, as sf.
read_curated_sf <- function(path) {
  m <- curated_provenance(path)
  d <- as.data.frame(nanoparquet::read_parquet(path))
  gcol <- m$value[m$key == "fd.geometry"]
  if (!length(gcol)) stop("no geometry recorded in ", path, call. = FALSE)
  crs <- m$value[m$key == "fd.crs"]

  # Decode IN PLACE, under the column's original name. st_as_sf(d, geometry = ...)
  # ADDS a column called `geometry` and leaves the raw WKB blob sitting where it
  # was, so the frame comes back with both - `geom` as a blob and `geometry` as the
  # geometry. Harmless in R, fatal downstream: write_sf() then writes both to
  # ports.fgb, and DuckDB's st_read() maps the geometry to `geom` as well and
  # refuses the file with `duplicate column name "geom"`. That broke
  # curate/ais_ping_tag.R on 2026-09-22. Round-tripping under the original name
  # also means read(write(x)) gives back x, which it did not before.
  g <- sf::st_as_sfc(structure(d[[gcol]], class = "WKB"), EWKB = TRUE)
  if (length(crs)) sf::st_crs(g) <- crs
  d[[gcol]] <- g
  sf::st_as_sf(d, sf_column_name = gcol)
}

curated_provenance <- function(path) {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  r <- DBI::dbGetQuery(con, sprintf(
    "SELECT decode(key) AS \"key\", decode(value) AS \"value\" FROM parquet_kv_metadata(%s)",
    shQuote(path, type = "sh")))
  r[startsWith(r$key, "fd."), ]
}

# check_sync() — which curated files are out of step with the working tree?
#
# Reports three kinds of drift: built from a dirty tree, built from a commit
# that is not HEAD, and built before an input it names was last modified.
check_sync <- function(dir = fd_curated()) {
  files <- list.files(dir, pattern = "[.]parquet$", recursive = TRUE, full.names = TRUE)
  if (!length(files)) { cat("no curated parquet files under ", dir, "\n"); return(invisible(NULL)) }
  head_sha <- .git_info()$commit
  rows <- lapply(files, function(f) {
    m <- tryCatch(curated_provenance(f), error = function(e) NULL)
    get1 <- function(k) { v <- m$value[m$key == k]; if (length(v)) v[1] else NA_character_ }
    data.frame(
      file    = sub(paste0("^", dir, "/?"), "", f),
      stamped = !is.null(m) && nrow(m) > 0,
      commit  = substr(get1("fd.commit"), 1, 8),
      dirty   = get1("fd.dirty"),
      rows    = get1("fd.rows"),
      built   = get1("fd.built"),
      at_head = identical(get1("fd.commit"), head_sha),
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  cat(sprintf("HEAD %s   (%d curated files, %d stamped)\n",
              substr(head_sha, 1, 8), nrow(out), sum(out$stamped)))
  print(out, row.names = FALSE)
  invisible(out)
}
