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

# A DuckDB connection without duckdb's notice about where it keeps extensions (~/.duckdb): in a script the package
# prints its five lines for each of the first 60 connections, so a dump's log had them once per table written
# (hafdruna, 2026-10-16). Only that message is muffled; the home and its cached extensions stay as they are.
.duckdb_quiet <- function() {
  withCallingHandlers(DBI::dbConnect(duckdb::duckdb()),
                      duckdb_storage_location = function(m) invokeRestart("muffleMessage"))
}

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

# The fd.* stamps, in one place so write_curated() and write_curated_sql() cannot
# drift apart. `inputs` are hashed here, at the moment of writing.
.curated_kv <- function(script, rows, schema_hash, inputs = character(),
                        geom = NA_character_, crs = NA_character_) {
  g  <- .git_info()
  ih <- if (length(inputs)) {
    ex <- inputs[file.exists(inputs)]
    paste(sprintf("%s=%s", basename(ex), unname(tools::md5sum(ex))), collapse = ";")
  } else NA_character_
  kv <- c(
    "fd.repo"         = g$repo,
    "fd.commit"       = g$commit,
    "fd.dirty"        = tolower(as.character(g$dirty)),
    "fd.script"       = script,
    "fd.built"        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    "fd.rows"         = as.character(rows),
    "fd.schema_hash"  = schema_hash,
    "fd.inputs"       = ih,
    "fd.geometry"     = geom,
    "fd.crs"          = crs
  )
  kv[!is.na(kv)]
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

  kv <- .curated_kv(script %||% .calling_script(), nrow(d), .schema_hash(d), inputs,
                    geom = geom, crs = crs)

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

# write_curated_sql() — the same contract for a table too big to hold in R.
#
# `sql` is a SELECT run on `con`; the result goes straight to `path` by
# COPY ... TO, so a 50-million-row year never enters R memory. Used for the partitioned
# sweep tables (one call per year, path = .../year=YYYY/part_001.parquet), each file
# carrying its own stamps. Rows are counted from the written file, not assumed.
# `order_by` (e.g. "vid, time") fixes the row order of the written file.
write_curated_sql <- function(con, sql, path, inputs = character(), script = NULL,
                              order_by = NULL) {
  if (!grepl("/curated/", path, fixed = TRUE))
    stop("write_curated_sql() writes under curated/ only; got: ", path, call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".partial")
  unlink(tmp)

  ds <- DBI::dbGetQuery(con, sprintf("DESCRIBE %s", sql))
  sh <- substr(digest_string(paste(ds$column_name, ds$column_type, collapse = "|")), 1, 16)
  # Two passes over the stamps: the row count is only known after the write, but
  # KV_METADATA has to be given to the COPY. Write once without it, count, then
  # rewrite with it from the file - cheaper than running the query twice.
  DBI::dbExecute(con, sprintf("COPY (%s) TO %s (FORMAT parquet)", sql, shQuote(tmp, type = "sh")))
  n <- DBI::dbGetQuery(con, sprintf("SELECT count(*) n FROM read_parquet(%s)",
                                    shQuote(tmp, type = "sh")))$n
  kv <- .curated_kv(script %||% .calling_script(), n, sh, inputs)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"),
                        shQuote(unname(kv), type = "sh")), collapse = ", ")
  unlink(path)
  # `order_by` is applied to THIS pass, not left to the query: a sweep table is read
  # sequentially by vessel and time, and row order in the file is part of the contract.
  ord <- if (!is.null(order_by)) paste("ORDER BY", order_by) else ""
  # hive_partitioning = FALSE: the temp file sits under .../year=Y/month=M/, and read_parquet() would turn those
  # directory names into columns of the file (found 2026-10-01 on ais/trail), so a partitioned table carried its
  # partition keys twice. A key that is also a column of the query (ping_trail's `year`) is already in the file.
  DBI::dbExecute(con, sprintf("COPY (SELECT * FROM read_parquet(%s, hive_partitioning = false) %s) TO %s (FORMAT parquet, KV_METADATA {%s})",
                              shQuote(tmp, type = "sh"), ord, shQuote(path, type = "sh"), meta))
  unlink(tmp)
  invisible(n)
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
  con <- .duckdb_quiet()
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
