# release.R — the user tables' repository: a release frozen from the candidate, with its manifest, its changes, its
# metadata and its README (plan 056).
#
# Input:  the candidate, $FISHYDATA/products/v0/ (products/user_tables.R); products/repository/{README.qmd,
#         release.qmd, meta.yml, releases.md}; docs/data-dict.yaml; the raw dumps' stamps (fd.dumped, never their rows)
# Output: publish_release() writes $FISHYDATA/published/releases/<id>/ (the release, never rewritten) and the
#         repository's README.html, RELEASES.md and LATEST, and appends the release's row to
#         products/repository/releases.md
#
# Definitions only: targets sources R/ wholesale.
#
# A release is kept, not rebuilt (plan 056 §2.2): its files are the version, and the manifest says what made them.
# One id for the whole release, YYYY.MM.DD.n, the day it was published; the schema version beside it says whether a
# user's code still runs. The repository is a folder on a share with no links (ask a): LATEST is a text file, and a
# release a full copy, its links followed.

RELEASE_FOLDERS <- c("logbook", "aggregate", "landing", "vessel", "reference")
# Frozen once fixes, built before the fd.ramb stamp: the manifest names the record that froze each (plan 056 §2.3).
RELEASE_FROZEN <- c("logbook/sensor_gps" = "decision 075")
# The keys a changelog compares rows by; a table not named here is compared whole (rows and content).
RELEASE_KEYS <- list(
  "logbook/trip"              = c(".tid", "schema"),
  "logbook/station"           = c(".sid", "schema"),
  "logbook/catch"             = c(".sid", "schema", "sid", "condition"),
  "logbook/landed_not_logged" = c(".tid", "schema", "sid_landing", "witness"),
  "landing/landing"           = c(".lid", "schema"),
  "vessel/vessel"             = "vid",
  "vessel/vessel_year"        = c("vid", "year"),
  "aggregate/logged_monthly"  = c("kind", ".row"),
  "aggregate/nephrops_fleet"  = ".row")
# Each source's dump, the table whose fd.dumped stamp dates it, under raw/oracle/.
RELEASE_SOURCES <- c(afli = "afli/stofn.parquet", afli_grasl = "afli/grasl_sokn.parquet",
                     fs_afladagbok = "fs_afladagbok/ws_veidi.parquet", adb = "adb/fishing_station.parquet",
                     aflaskeyti = "dw/dw_aflaskeyti.parquet", agf = "agf/aflagrunnur.parquet",
                     lods = "kvoti/lods_slaegt.parquet", ops_sigfus = "ops_sigfus/gamall_humar.parquet",
                     ices = "ops_einarhj/ices_landed_catch.parquet")
# A person's column, by name: the release holds none (plan 056 §3; AGENTS.md on kennitala).
PERSONS_PATTERN <- "kennitala|^kt$|^kt_|_kt$|eigand|owner|heimilisf|address|phone|^simi|e_?mail|netfang|skipstj|captain|^person|^nafn$"

# Helpers ----------------------------------------------------------------------
# NULL's default. Not `%||%`: R/write_curated.R defines its own, which takes NA as missing too.
`%or%` <- function(a, b) if (is.null(a)) b else a
.release_files <- function(dirs) {
  dirs <- dirs[dir.exists(dirs)]
  if (!length(dirs)) return(character())
  sort(system2("find", c("-L", shQuote(dirs), "-type", "f", "-name", shQuote("*.parquet")), stdout = TRUE))
}
.columns <- function(con, f) DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", f))$column_name
.kv <- function(con, f) {
  m <- DBI::dbGetQuery(con, sprintf("SELECT key::VARCHAR AS k, value::VARCHAR AS v FROM parquet_kv_metadata('%s')", f))
  stats::setNames(m$v, m$k)
}
# A file's table: its path under the release less ".parquet", a partitioned table's folder for each of its files.
.table_of <- function(rel) sub("/[^/]*=[^/]*/.*$", "", sub("[.]parquet$", "", rel))
.git <- function(...) suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE))

# Stops on a column of a person in any parquet file under `dirs`.
check_no_persons <- function(dirs) {
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  hit <- unlist(lapply(.release_files(dirs), function(f) {
    n <- .columns(con, f)
    n <- n[grepl(PERSONS_PATTERN, n, ignore.case = TRUE)]
    if (length(n)) paste0(f, ": ", n)
  }))
  if (length(hit)) stop("a person's column in the release:\n", paste(hit, collapse = "\n"), call. = FALSE)
  invisible(TRUE)
}

# The id the next release published today takes.
next_release_id <- function(root = fd_published()) {
  day <- format(Sys.time(), "%Y.%m.%d", tz = "UTC")
  have <- list.files(file.path(root, "releases"), pattern = paste0("^", gsub(".", "[.]", day, fixed = TRUE), "[.]"))
  paste0(day, ".", length(have) + 1L)
}

# ramb at a file's build. Stamped (fd.ramb) where the file carries it. Else derived where the file was built after the
# installed ramb was: that ramb built it, since a package is only replaced by a reinstall. Else "not used" where its
# script, as it stood at the file's own commit, calls no ramb function, directly or through an R/ function that does
# (four reference tables of 2026-10-28 were built hours before this ramb's install). A frozen once fix names its
# record; anything else is unknown, and publish_release() refuses it (plan 056 §2.3).
.ramb_installed <- function() {
  d <- suppressWarnings(utils::packageDescription("ramb"))
  if (!is.list(d) || is.null(d$Built)) return(as.POSIXct(NA))
  as.POSIXct(sub(" UTC$", "", strsplit(d$Built, "; ")[[1]][3]), tz = "UTC")
}
.ramb_at <- function(kv, tab) {
  if (!is.na(kv["fd.ramb"])) return(c(ramb = unname(kv[["fd.ramb"]]), basis = "stamped"))
  if (tab %in% names(RELEASE_FROZEN)) return(c(ramb = NA_character_, basis = paste("frozen:", RELEASE_FROZEN[[tab]])))
  inst <- .ramb_installed()
  built <- as.POSIXct(unname(kv["fd.built"]), format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
  if (!is.na(built) && !is.na(inst) && built >= inst)
    return(c(ramb = .ramb_info(), basis = sprintf("derived: built after this ramb's install, %s UTC",
                                                   format(inst, "%Y-%m-%d %H:%M"))))
  commit <- unname(kv["fd.commit"]); script <- unname(kv["fd.script"])
  if (identical(unname(kv["fd.dirty"]), "false") && !is.na(commit) && !is.na(script) &&
      isFALSE(.ramb_used(script, commit)))
    return(c(ramb = NA_character_, basis = sprintf("not used: %s at %s calls no ramb function", script,
                                                   substr(commit, 1, 7))))
  c(ramb = NA_character_, basis = "unknown")
}

# Whether `script`, as it stood at `commit`, calls ramb: directly, or through an R/ function that does, followed
# through R/ until no new caller is found. NA where git does not hold the script at that commit.
.ramb_used <- function(script, commit) {
  txt <- .git("show", paste0(commit, ":", script))
  if (!length(txt)) return(NA)
  rf <- grep("[.]R$", .git("ls-tree", "--name-only", commit, "R/"), value = TRUE)
  rt <- stats::setNames(lapply(rf, \(f) .git("show", paste0(commit, ":", f))), rf)
  direct <- function(x) any(grepl("ramb::|library[(]ramb[)]|\\brb_[a-z_]+[(]", x))
  defs <- function(x) sub(" <- function.*$", "", grep("^[A-Za-z_.][A-Za-z0-9_.]* <- function", x, value = TRUE))
  calls <- function(x, fns) length(fns) && any(vapply(fns, \(f) any(grepl(paste0("(^|[^A-Za-z0-9_.])",
                                                         gsub(".", "[.]", f, fixed = TRUE), "[(]"), x)), TRUE))
  users <- rf[vapply(rt, direct, TRUE)]
  repeat {
    fns <- unlist(lapply(rt[users], defs))
    more <- setdiff(rf[vapply(rt, \(x) calls(x, fns), TRUE)], users)
    if (!length(more)) break
    users <- c(users, more)
  }
  direct(txt) || calls(txt, unlist(lapply(rt[users], defs)))
}

# The manifest -------------------------------------------------------------------
# What travels with a release (plan 056 §2.3): the id and schema version; the code that published it; per file its
# rows, md5, schema hash and the stamps of the build that made it; per source its dump and the span of its records.
.release_manifest <- function(con, dest, id, schema_version, previous) {
  rel <- sub(paste0("^", dest, "/"), "", .release_files(dest))
  files <- lapply(rel, function(r) {
    f <- file.path(dest, r); kv <- .kv(con, f); tab <- .table_of(r)
    get <- function(k) if (k %in% names(kv)) unname(kv[[k]]) else NA_character_
    ra <- .ramb_at(kv, tab)
    list(path = r, table = tab,
         rows = as.numeric(DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM read_parquet('%s')", f))$n),
         md5 = unname(tools::md5sum(f)), schema_hash = get("fd.schema_hash"), script = get("fd.script"),
         built = get("fd.built"), fishycode = get("fd.commit"), dirty = get("fd.dirty"),
         ramb = unname(ra["ramb"]), ramb_basis = unname(ra["basis"]), duckdb = get("fd.duckdb"))
  })
  p <- function(...) file.path(dest, ...)
  # Each source's span, from the tables the release holds.
  span <- function(file, sql) if (file.exists(file)) DBI::dbGetQuery(con, sprintf(sql, file))
  by_schema <- "SELECT schema AS source, min(\"date\")::DATE::VARCHAR AS first, max(\"date\")::DATE::VARCHAR AS last
                FROM read_parquet('%s') GROUP BY 1"
  by_year <- function(name) sprintf("SELECT '%s' AS source, min(year)::VARCHAR AS first, max(year)::VARCHAR AS last
                                     FROM read_parquet('%%s')", name)
  spans <- rbind(span(p("logbook", "station.parquet"), by_schema), span(p("landing", "landing.parquet"), by_schema),
                 span(p("aggregate", "logged_monthly.parquet"), by_year("ops_sigfus")),
                 span(p("aggregate", "ices.parquet"), by_year("ices")))
  if (is.null(spans)) spans <- data.frame(source = character(), first = character(), last = character())
  sources <- lapply(seq_len(nrow(spans)), function(i) {
    s <- spans$source[i]
    raw <- if (s %in% names(RELEASE_SOURCES)) tryCatch(fd_raw("oracle", RELEASE_SOURCES[[s]]),
                                                       error = function(e) NA_character_) else NA_character_
    dumped <- if (!is.na(raw) && file.exists(raw)) unname(.kv(con, raw)["fd.dumped"]) else NA_character_
    list(source = s, first = spans$first[i], last = spans$last[i], dumped = dumped)
  })
  landed <- spans$last[spans$source %in% c("agf", "lods")]
  landing_last <- if (length(landed)) as.integer(substr(max(landed), 1, 4)) else NA_integer_
  stamped <- function(k) sort(unique(na.omit(vapply(files, \(f) f[[k]] %or% NA_character_, ""))))
  list(id = id, schema_version = schema_version,
       published = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), previous = previous,
       code = list(fishycode = .git("rev-parse", "HEAD")[1], ramb = .ramb_info(),
                   duckdb = as.character(utils::packageVersion("duckdb")), r = R.version$version.string),
       built_with = list(fishycode = stamped("fishycode"), ramb = stamped("ramb")),
       provisional = list(landings = c(landing_last - 1L, landing_last), basis = "decision 192"),
       sources = sources, files = files)
}

# The changes ----------------------------------------------------------------------
# CHANGES.md of `new` against `old`, two published releases (plan 056 §2.4): per table the rows added, removed and
# changed by key, or the whole table's rows and content where it has no key; the catch tables' kg by year and species;
# the columns added or removed; and the causes, new data (a source's dump moved), method (the decisions recorded
# between the two commits) and corrections (given by hand, `corrections`). It opens with what may change a result.
compare_release <- function(old, new, corrections = character(), repo = ".") {
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  mo <- yaml::read_yaml(file.path(old, "manifest.yml")); mn <- yaml::read_yaml(file.path(new, "manifest.yml"))
  tabs <- function(d) { r <- sub(paste0("^", d, "/"), "", .release_files(d)); split(r, .table_of(r)) }
  to <- tabs(old); tn <- tabs(new)
  src <- function(d, files) sprintf("read_parquet([%s], hive_partitioning = false)",
                                    paste(sprintf("'%s'", file.path(d, files)), collapse = ", "))
  qi <- function(x) as.character(DBI::dbQuoteIdentifier(con, x))
  rows <- list(); moved <- character()
  for (t in sort(union(names(to), names(tn)))) {
    if (is.null(to[[t]]) || is.null(tn[[t]])) {
      rows[[t]] <- data.frame(table = t, change = if (is.null(to[[t]])) "new table" else "table removed")
      moved <- c(moved, t); next
    }
    a <- src(old, to[[t]]); b <- src(new, tn[[t]])
    ca <- DBI::dbGetQuery(con, paste("DESCRIBE SELECT * FROM", a))$column_name
    cb <- DBI::dbGetQuery(con, paste("DESCRIBE SELECT * FROM", b))$column_name
    common <- intersect(ca, cb); key <- RELEASE_KEYS[[t]]
    cols <- c(if (length(setdiff(cb, ca))) paste("columns added:", paste(setdiff(cb, ca), collapse = ", ")),
              if (length(setdiff(ca, cb))) paste("columns removed:", paste(setdiff(ca, cb), collapse = ", ")))
    if (!is.null(key) && all(key %in% common)) {
      on <- paste(sprintf("o.%1$s IS NOT DISTINCT FROM n.%1$s", qi(key)), collapse = " AND ")
      h <- function(x) sprintf("hash(%s)", paste(paste0(x, ".", qi(setdiff(common, key))), collapse = ", "))
      r <- DBI::dbGetQuery(con, sprintf("SELECT
          count(*) FILTER (WHERE o.k IS NULL) AS added, count(*) FILTER (WHERE n.k IS NULL) AS removed,
          count(*) FILTER (WHERE o.k AND n.k AND %s <> %s) AS changed
        FROM (SELECT *, true AS k FROM %s) o FULL JOIN (SELECT *, true AS k FROM %s) n ON %s",
        h("o"), h("n"), a, b, on))
      ch <- c(if (r$added) sprintf("%s rows added", format(r$added, big.mark = ",")),
              if (r$removed) sprintf("%s removed", format(r$removed, big.mark = ",")),
              if (r$changed) sprintf("%s changed", format(r$changed, big.mark = ",")), cols)
    } else {
      w <- function(s) DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n, sum(hash(%s))::VARCHAR AS h FROM %s",
                                                     paste(qi(common), collapse = ", "), s))
      ra <- w(a); rb <- w(b)
      ch <- c(if (ra$n != rb$n) sprintf("rows %s -> %s", format(ra$n, big.mark = ","), format(rb$n, big.mark = ","))
              else if (!identical(ra$h, rb$h)) "same rows, content changed", cols)
    }
    if (length(ch)) { rows[[t]] <- data.frame(table = t, change = paste(ch, collapse = "; ")); moved <- c(moved, t) }
  }
  # The catch tables' kg by year and species, the cells that moved.
  kg <- function(d, catch, by, date, key) sprintf(
    "SELECT year(b.\"date\") AS year, c.sid, sum(c.catch) AS kg FROM read_parquet('%s') c
     JOIN read_parquet('%s') b USING (%s) GROUP BY ALL", file.path(d, catch), file.path(d, by), key)
  kg_moves <- lapply(list(logbook = c("logbook/catch.parquet", "logbook/station.parquet", "\".sid\", schema"),
                          landing = c("landing/catch.parquet", "landing/landing.parquet", "\".lid\", schema")),
                     function(x) {
    if (!all(file.exists(file.path(c(old, old, new, new), x[c(1, 2, 1, 2)])))) return(NULL)
    DBI::dbGetQuery(con, sprintf("SELECT coalesce(o.year, n.year) AS year, coalesce(o.sid, n.sid) AS sid,
        round(o.kg) AS kg_old, round(n.kg) AS kg_new FROM (%s) o FULL JOIN (%s) n ON o.year = n.year AND o.sid = n.sid
        WHERE round(o.kg) IS DISTINCT FROM round(n.kg) ORDER BY abs(coalesce(n.kg, 0) - coalesce(o.kg, 0)) DESC",
        kg(old, x[1], x[2], "date", x[3]), kg(new, x[1], x[2], "date", x[3])))
  })
  # The causes.
  dumps <- function(m) stats::setNames(vapply(m$sources, \(s) s$dumped %or% NA_character_, ""),
                                       vapply(m$sources, `[[`, "", "source"))
  dold <- dumps(mo); dnew <- dumps(mn)
  new_data <- names(dnew)[vapply(names(dnew), \(n) !identical(unname(dnew[n]), unname(dold[n])), TRUE)]
  added <- suppressWarnings(system2("git", c("-C", shQuote(repo), "log", "--diff-filter=A", "--format=", "--name-only",
                                              paste0(mo$code$fishycode, "..", mn$code$fishycode), "--",
                                              "curate/decisions/"), stdout = TRUE, stderr = FALSE))
  added <- sort(unique(added[grepl("^curate/decisions/[0-9]{3}-.*[.]md$", added)]))
  titles <- vapply(added, \(f) sub("^#\\s*", "", readLines(file.path(repo, f), n = 1, warn = FALSE)), "")
  out <- c(sprintf("# Changes in release %s, against %s", mn$id, mo$id), "",
           if (!identical(mo$schema_version, mn$schema_version))
             sprintf("**The schema version moved from %s to %s.** See the notes below on what it breaks.",
                     mo$schema_version, mn$schema_version),
           "", "## What may change a result", "",
           if (length(moved)) "Tables whose rows or content changed; the causes are listed below." else "Nothing.",
           "", if (length(rows)) c("| table | change |", "|---|---|",
                                   sprintf("| `%s` | %s |", vapply(rows, `[[`, "", "table"),
                                           vapply(rows, `[[`, "", "change"))), "")
  for (n in names(kg_moves)) {
    m <- kg_moves[[n]]
    if (is.null(m) || !nrow(m)) next
    out <- c(out, sprintf("**%s catch, kg by year and species:** %d cells moved; the ten largest:", n, nrow(m)), "",
             "| year | sid | kg before | kg after |", "|---:|---:|---:|---:|",
             sprintf("| %s | %s | %s | %s |", m$year[1:min(10, nrow(m))], m$sid[1:min(10, nrow(m))],
                     format(m$kg_old[1:min(10, nrow(m))], big.mark = ","),
                     format(m$kg_new[1:min(10, nrow(m))], big.mark = ",")), "")
  }
  c(out, "## Causes", "",
    "**New data** (a source's dump moved):", "",
    if (length(new_data)) sprintf("- %s: %s -> %s", new_data, dold[new_data], dnew[new_data]) else "- none", "",
    "**Method** (decisions recorded between the two releases' commits):", "",
    if (length(added)) sprintf("- %s", titles) else "- none", "",
    "**Corrections** (an error in an earlier release):", "",
    if (length(corrections)) sprintf("- %s", corrections) else "- none", "")
}

# The metadata ----------------------------------------------------------------------
# meta.yml in the data-dict format (plan 056 §4.1): the tool drafts each table from its file (types, ranges, examples),
# and every description is composed, the overlay's first, then docs/data-dict.yaml's for a column that is a curated
# one. A column with no description stops it. validate-spec must be clean; meta.html renders it.
# A column's description: the overlay's for its table, else the first of docs/data-dict.yaml's tables the overlay
# names in `from`. NULL where neither has one.
.release_describer <- function(overlay, dict) {
  ov <- .dd_read_yaml(overlay); dd <- .dd_read_draft(dict)
  dd_cols <- stats::setNames(lapply(dd$tables, \(t) stats::setNames(lapply(t$columns, \(c) c$description),
                                                                    vapply(t$columns, \(c) c$name, ""))),
                             vapply(dd$tables, \(t) t$name, ""))
  function(table, column) {
    o <- ov$tables[[table]]
    o$columns[[column]] %or% Reduce(`%or%`, lapply(o$from %or% character(), \(s) dd_cols[[s]][[column]]), NULL)
  }
}

# The release's tables and columns that have no description, as "table.column"; a table the overlay does not name is
# "table" alone.
release_undescribed <- function(dir, overlay = file.path("products", "repository", "meta.yml"),
                                dict = "docs/data-dict.yaml", folders = RELEASE_FOLDERS) {
  ov <- .dd_read_yaml(overlay); describe <- .release_describer(overlay, dict)
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  rel <- sub(paste0("^", dir, "/"), "", .release_files(file.path(dir, folders)))
  one <- rel[!duplicated(.table_of(rel))]
  unlist(lapply(one, function(r) {
    t <- .table_of(r)
    if (is.null(ov$tables[[t]])) return(t)
    n <- .columns(con, file.path(dir, r))
    n <- n[!vapply(n, \(c) !is.null(describe(t, c)), TRUE)]
    if (length(n)) paste0(t, ".", n)
  }))
}

# The tool's draft as data-dict reads it: .dd_read_yaml()'s booleans and lists, and an integer as a double, since R's
# reader makes one past 2^31 NA (a .lid, a .sid) and the range then fails the spec (S12).
.dd_read_draft <- function(path) {
  b <- function(x) if (tolower(x) %in% c("true", "false")) tolower(x) == "true" else x
  yaml::read_yaml(path, handlers = list("bool#yes" = b, "bool#no" = b, seq = function(x) as.list(x),
                                        int = function(x) as.numeric(x)))
}

release_meta <- function(dest, overlay, dict = "docs/data-dict.yaml", bin = .dd_bin(), folders = RELEASE_FOLDERS) {
  ov <- .dd_read_yaml(overlay); describe <- .release_describer(overlay, dict)
  rel <- sub(paste0("^", dest, "/"), "", .release_files(file.path(dest, folders)))
  one <- rel[!duplicated(.table_of(rel))]
  missing <- character()
  tables <- lapply(one, function(r) {
    t <- .table_of(r); o <- ov$tables[[t]]
    if (is.null(o)) stop("products/repository/meta.yml does not describe ", t, call. = FALSE)
    tf <- tempfile(fileext = ".yaml")
    system2(bin, c("draft", "-o", shQuote(tf), shQuote(file.path(dest, r))), stdout = FALSE, stderr = FALSE,
            env = "LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8")
    d <- .dd_read_draft(tf)$tables[[1]]
    d$name <- gsub("/", "_", t)
    d$source$parquet <- r
    d$description <- o$description
    d$todo <- NULL
    d$columns <- lapply(d$columns, function(c) {
      desc <- describe(t, c$name)
      if (is.null(desc)) missing <<- c(missing, paste0(t, ".", c$name))
      c$description <- desc
      c
    })
    d
  })
  if (length(missing)) stop(length(missing), " release columns have no description:\n",
                            paste(missing, collapse = "\n"), call. = FALSE)
  m <- list(`$version` = "0.1.0", name = ov$name, description = ov$description, tables = tables)
  out <- file.path(dest, "meta.yml")
  yaml::write_yaml(m, out, precision = 17)
  sp <- .dd_problems(.dd_json(bin, c("validate-spec", out))$problems)
  errs <- sp[sp$severity %in% "error", ]
  if (nrow(errs)) stop("meta.yml: ", nrow(errs), " spec errors, the first: ", errs$code[1], " ", errs$table[1], " ",
                       errs$columns[1], " ", errs$message[1], call. = FALSE)
  system2(bin, c("render", shQuote(out), "-o", shQuote(file.path(dest, "meta.html"))), stdout = FALSE, stderr = FALSE,
          env = "LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8")
  invisible(out)
}

# Publishing ------------------------------------------------------------------------
# Freezes the candidate as release `id` under `root` (plan 056 §6). It refuses unless the tree is clean, ramb was
# installed from a commit, the candidate and its check are not outdated, the check passed, every file is stamped clean
# and with ramb (a frozen once fix excepted), and the id is new. `check = FALSE` skips the tree, targets and check
# (tests only); `meta` and `render` the tool and Quarto.
publish_release <- function(id = next_release_id(root), candidate = fd_path("products", "v0"),
                            root = fd_published(), folders = RELEASE_FOLDERS,
                            repository = file.path("products", "repository"), check = TRUE, meta = TRUE,
                            render = TRUE, corrections = character()) {
  stopifnot("an id is YYYY.MM.DD.n" = grepl("^[0-9]{4}[.][0-9]{2}[.][0-9]{2}[.][0-9]+$", id))
  dest <- file.path(root, "releases", id)
  if (file.exists(dest)) stop("release ", id, " exists: a release is never rewritten", call. = FALSE)
  if (check) {
    if (length(.git("status", "--porcelain"))) stop("the tree is not clean: commit first", call. = FALSE)
    if (is.na(.ramb_info()) || grepl("@none$", .ramb_info()))
      stop("ramb has no commit: install it with remotes::install_git()", call. = FALSE)
    od <- targets::tar_outdated(names = c("user_tables", "user_tables_check"), callr_function = NULL)
    if (length(od)) stop("outdated: ", paste(od, collapse = ", "), call. = FALSE)
    ck <- duckdbfs::open_dataset(fd_curated("check", "user_tables.parquet")) |> dplyr::collect()
    if (!all(ck$pass)) stop("user_tables_check failed: ", paste(ck$check[!ck$pass], collapse = ", "), call. = FALSE)
  }
  con <- .duckdb_quiet()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  bad <- unlist(lapply(.release_files(file.path(candidate, folders)), function(f) {
    kv <- .kv(con, f); tab <- .table_of(sub(paste0("^", candidate, "/"), "", f))
    c(if (!identical(unname(kv["fd.dirty"]), "false")) paste(f, "built from a dirty tree"),
      if (.ramb_at(kv, tab)[["basis"]] == "unknown") paste(f, "has no fd.ramb, and was built before this ramb"))
  }))
  if (check && length(bad)) stop("the candidate is not ready:\n", paste(utils::head(bad, 20), collapse = "\n"),
                                 call. = FALSE)
  check_no_persons(file.path(candidate, folders))

  # The copy, every link followed.
  dir.create(dest, recursive = TRUE)
  for (f in folders) system2("cp", c("-R", "-L", shQuote(file.path(candidate, f)), shQuote(dest)))
  index <- file.path(repository, "releases.md")
  prev <- sort(setdiff(list.files(file.path(root, "releases")), id))
  previous <- if (length(prev)) utils::tail(prev, 1) else NULL
  ov <- .dd_read_yaml(file.path(repository, "meta.yml"))
  m <- .release_manifest(con, dest, id, ov$schema_version, previous)
  yaml::write_yaml(m, file.path(dest, "manifest.yml"))
  writeLines(if (is.null(previous)) c(sprintf("# Changes in release %s", id), "", "The first release: nothing to compare against.")
             else compare_release(file.path(root, "releases", previous), dest, corrections),
             file.path(dest, "CHANGES.md"))
  if (meta) release_meta(dest, file.path(repository, "meta.yml"))

  # The index, LATEST, and the READMEs.
  idx <- readLines(index)
  idx <- sub("\\| current \\|", "| superseded |", idx)
  idx <- c(idx, sprintf("| %s | %s | %s | %s | current | %s |", id, substr(m$published, 1, 10),
                        substr(m$code$fishycode, 1, 7), m$schema_version,
                        if (is.null(previous)) "the first release" else "see its CHANGES.md"))
  writeLines(idx, index)
  file.copy(index, file.path(root, "RELEASES.md"), overwrite = TRUE)
  writeLines(id, file.path(root, "LATEST"))
  if (render) {
    file.copy(file.path(repository, "release.qmd"), file.path(dest, "README.qmd"))
    file.copy(file.path(repository, "README.qmd"), file.path(root, "README.qmd"), overwrite = TRUE)
    for (d in c(dest, root)) {
      st <- system2("quarto", c("render", shQuote(file.path(d, "README.qmd")), "--to", "html", "--quiet"))
      if (st != 0) stop("quarto could not render ", file.path(d, "README.qmd"), call. = FALSE)
    }
    unlink(file.path(c(dest, root), "README_files"), recursive = TRUE)
  }
  system2("chmod", c("-R", "a-w", shQuote(dest)))
  message("release ", id, ": ", length(m$files), " files, ", dest)
  invisible(dest)
}
