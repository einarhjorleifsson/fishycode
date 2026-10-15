# dump_oracle.R — dump an Oracle schema, as it is, to raw/oracle/<schema>/ (plan 018).
#
# Input:  an open connection (dump_connect()) and a schema (Oracle owner)
# Output: <out_dir>/<name>.parquet for each table and view, as Oracle holds it: names, values and units unchanged.
#         A table named in `partition` goes to <out_dir>/<name>/year=<y>/data_0.parquet, by calendar year of a date.
#           _overview_tables.parquet  one row per table and view: Oracle's comment and row estimate, what was written,
#                                     what failed and why, and the dump's time, script, commit and driver
#           _overview_fields.parquet  one row per column: Oracle's type, precision, scale and comment
#           _data-dict.yaml           the schema in data-dict's format (https://data-dict.tidyverse.org/): Oracle's
#                                     comments, with types, ranges and examples from the files written
#         Every parquet file carries fd.* stamps in its key/value metadata, read by curated_provenance():
#         fd.source, fd.dumped (the dump's start, its version marker), fd.rows, fd.driver, fd.script, fd.commit, fd.dirty.
#
# Definitions only: targets sources R/ wholesale, so nothing here may connect at load.
#
# The table-and-view loop used to be copied into six scripts, three in dump/ and three beside the data under
# $FISHYDATA/raw/, and the copies drifted (decision 105). The scripts in dump/oracle/ call these instead.
#
# NUMBER columns are typed by what Oracle declares, not by what the driver returns, so the parquet is the same
# whichever driver read it. The dumps made with ROracle on the servers hold NUMBER(p <= 9, 0) as integers and other
# NUMBERs as doubles. RJDBC returns NUMBER(p, s) as a double, but a NUMBER with scale 0 and no precision (Oracle's
# INTEGER: adb's ids) as text - measured on the adb dump of 2026-10-15, where it broke the station-catch join.

# Columns of a schema (or of one table in it), with Oracle's declared types and comments.
oracle_fields <- function(con, schema, table = NULL) {
  s <- toupper(schema)
  cols <- mar::tbl_mar(con, "sys.all_tab_columns") |>
    dplyr::filter(owner == !!s)
  comm <- mar::tbl_mar(con, "sys.all_col_comments") |>
    dplyr::filter(owner == !!s)
  if (!is.null(table)) {
    t <- toupper(table)
    cols <- cols |> dplyr::filter(table_name == !!t)
    comm <- comm |> dplyr::filter(table_name == !!t)
  }
  cols <- cols |>
    dplyr::select(table = table_name, column = column_name, column_id,
                  data_type, data_precision, data_scale, nullable) |>
    dplyr::collect()
  comm <- comm |>
    dplyr::select(table = table_name, column = column_name, comments) |>
    dplyr::collect()
  cols |>
    dplyr::left_join(comm, by = c("table", "column")) |>
    dplyr::mutate(owner = tolower(schema), table = tolower(table), column = tolower(column),
                  column_id = as.integer(column_id)) |>
    dplyr::relocate(owner) |>
    dplyr::arrange(table, column_id)
}

# Tables and views of a schema, with Oracle's comment and (for tables) its row estimate. Read from the catalogue
# directly: mar::mar_views() calls sql() unqualified, so it fails under Rscript, where dplyr is not attached
# (2026-10-15).
oracle_objects <- function(con, schema) {
  s <- gsub("'", "''", toupper(schema))
  q <- function(cols, from) DBI::dbGetQuery(con, sprintf("SELECT %s FROM %s WHERE OWNER = '%s'", cols, from, s)) |>
    dplyr::rename_with(tolower)
  tabs <- q("OWNER, TABLE_NAME, TABLESPACE_NAME, NUM_ROWS, LAST_ANALYZED", "SYS.ALL_TABLES") |>
    dplyr::rename(name = table_name) |> dplyr::mutate(type = "table")
  views <- q("OWNER, VIEW_NAME", "SYS.ALL_VIEWS") |>
    dplyr::rename(name = view_name) |> dplyr::mutate(type = "view")
  comm <- q("OWNER, TABLE_NAME, COMMENTS", "SYS.ALL_TAB_COMMENTS")
  objects <- dplyr::bind_rows(tabs, views) |>
    dplyr::mutate(owner = tolower(owner), name = tolower(name))
  objects$comments <- comm$comments[match(objects$name, tolower(comm$table_name))]
  objects$num_rows <- as.numeric(objects$num_rows)
  objects |> dplyr::relocate(owner, name, type, comments)
}

# The connection every dump uses. rJava starts the JVM with a 0.5 GB heap under Rscript (measured 2026-10-15), and
# adb's tables exhausted it; java.parameters takes effect only before the JVM starts, so it is set here, first.
dump_connect <- function(heap = "8g") {
  options(java.parameters = paste0("-Xmx", heap))
  con <- mar::connect_mar(rjdbc = TRUE)
  rt <- rJava::.jcall("java/lang/Runtime", "Ljava/lang/Runtime;", "getRuntime")
  message(sprintf("JVM heap: %.1f GB", rJava::.jcall(rt, "J", "maxMemory") / 2^30))
  con
}

.oracle_numbers <- function(d, fields) {
  num <- fields$column[fields$data_type %in% "NUMBER"]
  int <- fields$column[fields$data_type %in% "NUMBER" &
                       fields$data_scale %in% 0 &
                       !is.na(fields$data_precision) & fields$data_precision <= 9]
  for (v in intersect(num, names(d))) {
    x <- d[[v]]
    if (is.character(x)) {
      y <- suppressWarnings(as.numeric(x))
      # a double holds integers exactly up to 2^53; past that, or if a value does not parse, the text is kept
      if (any(is.na(y) & !is.na(x)) || any(abs(y) > 2^53, na.rm = TRUE)) {
        message("  ", v, ": NUMBER returned as text and kept as text (not every value converts exactly)")
        next
      }
      x <- y
    }
    if (v %in% int && is.double(x)) x <- as.integer(x)
    d[[v]] <- x
  }
  d
}

.oracle_driver <- function(con) if (inherits(con, "JDBCConnection")) "RJDBC" else "ROracle"

# What every file of one dump is stamped with. `dumped` is the dump's start: the version marker.
.dump_run <- function(con, script) {
  g <- .git_info()
  list(dumped = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), driver = .oracle_driver(con),
       script = script, commit = g$commit, dirty = tolower(as.character(g$dirty)))
}

# Write a frame as parquet (plain TIMESTAMP) with fd.* stamps in its key/value metadata.
.write_raw <- function(d, path, source, run) {
  kv <- c("fd.source" = source, "fd.dumped" = run$dumped, "fd.rows" = as.character(nrow(d)),
          "fd.driver" = run$driver, "fd.script" = run$script, "fd.commit" = run$commit, "fd.dirty" = run$dirty)
  kv <- kv[!is.na(kv)]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "d", d)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"), shQuote(unname(kv), type = "sh")),
                collapse = ", ")
  DBI::dbExecute(con, sprintf("COPY d TO %s (FORMAT parquet, KV_METADATA {%s})", shQuote(path, type = "sh"), meta))
  invisible(path)
}

# Columns the driver cannot fetch are read as text in Oracle's own form: SDO_GEOMETRY as WKT, XMLTYPE as the document.
# adb.fishing_station's location (SDO_GEOMETRY) failed every earlier dump; afli's XML table needed its own query.
# The WKT is cast to VARCHAR2: as a CLOB, each of fishing_station's 690,912 rows left a temporary LOB in the session,
# and the next query waited on Oracle for over 15 min (2026-10-15), most likely while it freed them. A geometry whose
# WKT passes 4,000 characters then fails loudly (ORA-22835) rather than being cut. An XML document is longer than
# that, so it stays a CLOB, read on a connection of its own that is closed before the LOBs are released.
.oracle_text <- c(SDO_GEOMETRY = "TO_CHAR(SDO_UTIL.TO_WKTGEOMETRY(%s))", XMLTYPE = "XMLSERIALIZE(DOCUMENT %s AS CLOB)")
.oracle_lob <- "XMLTYPE"

# The table as a lazy query: every column as it is, those in .oracle_text converted to text under their own name.
.oracle_query <- function(con, table, fields) {
  if (!any(fields$data_type %in% names(.oracle_text))) return(mar::tbl_mar(con, table))
  x <- strsplit(table, ".", fixed = TRUE)[[1]]
  fields <- fields[order(fields$column_id), ]
  cols <- vapply(seq_len(nrow(fields)), function(i) {
    q <- sprintf('"%s"', toupper(fields$column[i]))
    f <- .oracle_text[fields$data_type[i]]
    if (is.na(f)) q else paste(sprintf(f, q), "AS", q)
  }, "")
  dplyr::tbl(con, dplyr::sql(sprintf('SELECT %s FROM "%s"."%s"', paste(cols, collapse = ", "),
                                     toupper(x[1]), toupper(x[2])))) |>
    dplyr::rename_with(tolower)
}

# One table or view ("schema.name") to one parquet file, as it is. Reports and returns the rows written.
dump_oracle_table <- function(con, table, path, fields = NULL, run = NULL) {
  if (is.null(fields)) {
    x <- strsplit(table, ".", fixed = TRUE)[[1]]
    fields <- oracle_fields(con, x[1], x[2])
  }
  if (is.null(run)) run <- .dump_run(con, NA_character_)
  if (any(fields$data_type %in% .oracle_lob)) {
    lc <- dump_connect()
    d <- tryCatch(.oracle_query(lc, table, fields) |> dplyr::collect(),
                  finally = DBI::dbDisconnect(lc))
  } else {
    d <- .oracle_query(con, table, fields) |> dplyr::collect()
  }
  d <- .oracle_numbers(d, fields)
  .write_raw(d, path, table, run)
  message(sprintf("%s: %s rows", table, format(nrow(d), big.mark = ",")))
  nrow(d)
}

# A table too big for one collect(), by calendar year of `column`, to <dir>/year=<y>/data_0.parquet. A year is fetched
# again until its partition holds a value from 31 December: for STK's recdate (receipt time) every year 2007-2025
# does, within the last minute (measured 2026-10-15), so a year dumped before it ended is completed on the next run.
# Returns the rows written in this run.
dump_oracle_by_year <- function(con, table, dir, column, fields, run) {
  q <- .oracle_query(con, table, fields)
  span <- q |> dplyr::summarise(a = min(.data[[column]], na.rm = TRUE), b = max(.data[[column]], na.rm = TRUE)) |>
    dplyr::collect()
  years <- seq(as.integer(format(as.POSIXct(span$a), "%Y")), as.integer(format(as.POSIXct(span$b), "%Y")))
  n <- 0
  for (y in years) {
    f <- file.path(dir, paste0("year=", y), "data_0.parquet")
    if (file.exists(f)) {
      dc <- DBI::dbConnect(duckdb::duckdb())
      last <- DBI::dbGetQuery(dc, sprintf("SELECT max(%s) AS mx FROM read_parquet(%s)", column,
                                          shQuote(f, type = "sh")))$mx
      DBI::dbDisconnect(dc, shutdown = TRUE)
      if (!is.na(last) && as.Date(last) >= as.Date(sprintf("%d-12-31", y))) next
    }
    d <- q |>
      dplyr::filter(.data[[column]] >= to_date(!!sprintf("%d-01-01", y), "YYYY-MM-DD"),
                    .data[[column]] <  to_date(!!sprintf("%d-01-01", y + 1), "YYYY-MM-DD")) |>
      dplyr::collect()
    d <- .oracle_numbers(d, fields)
    .write_raw(d, f, table, run)
    message(sprintf("%s, %d: %s rows", table, y, format(nrow(d), big.mark = ",")))
    n <- n + nrow(d)
  }
  n
}

# The schema in data-dict's format, beside the files: Oracle's comments, types from the files, ranges from the whole
# file and examples from its first 10,000 rows. Examples are data, so the yaml is handled as the data are.
.write_data_dict <- function(out_dir, schema, objects, fields, run) {
  dd_type <- function(t) {
    if (grepl("^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|FLOAT|DOUBLE|DECIMAL)", t)) "number"
    else if (grepl("^TIMESTAMP", t)) "datetime"
    else if (t == "DATE") "date"
    else if (t == "BOOLEAN") "boolean"
    else "string"
  }
  show <- function(x, type) {
    if (type == "number") {
      x <- as.numeric(x); w <- x[!is.na(x)]
      return(if (length(w) && all(w == round(w)) && all(abs(w) < 2^31)) as.integer(x) else x)
    }
    x <- as.character(x)
    ifelse(nchar(x) > 60, paste0(substr(x, 1, 57), "..."), x)
  }
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  written <- objects[objects$status %in% "written", ]
  tables <- lapply(seq_len(nrow(written)), function(i) {
    nm  <- written$name[i]
    src <- if (written$partitioned[i]) file.path(nm, "*", "*.parquet") else paste0(nm, ".parquet")
    rp  <- sprintf("read_parquet(%s, hive_partitioning = false)", shQuote(file.path(out_dir, src), type = "sh"))
    desc <- DBI::dbGetQuery(con, paste("DESCRIBE SELECT * FROM", rp))
    types <- vapply(desc$column_type, dd_type, "")
    ranged <- desc$column_name[types %in% c("number", "datetime", "date")]
    rng <- if (length(ranged)) DBI::dbGetQuery(con, sprintf("SELECT %s FROM %s", paste(
      sprintf("min(\"%s\") AS \"min_%s\", max(\"%s\") AS \"max_%s\"", ranged, ranged, ranged, ranged),
      collapse = ", "), rp)) else NULL
    head <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 10000", rp))
    fl <- fields[fields$table == nm, ]
    cols <- lapply(seq_len(nrow(desc)), function(j) {
      cn <- desc$column_name[j]; ty <- types[[j]]
      cm <- fl$comments[match(cn, fl$column)]
      e <- list(name = cn, type = ty)
      r <- if (cn %in% ranged && !is.null(rng)) c(rng[[paste0("min_", cn)]], rng[[paste0("max_", cn)]])
      if (length(r) && !anyNA(r)) e$range <- as.list(show(r, ty))
      ex <- unique(head[[cn]][!is.na(head[[cn]])])
      if (length(ex) && ty %in% c("number", "string")) e$examples <- as.list(show(utils::head(ex, 5), ty))
      e$description <- if (is.na(cm) || !nzchar(cm)) "No comment in Oracle." else cm
      e
    })
    list(name = nm, source = list(parquet = src),
         description = if (is.na(written$comments[i]) || !nzchar(written$comments[i])) "No comment in Oracle."
                       else written$comments[i],
         columns = cols)
  })
  dd <- list(`$version` = "0.1.0", `$learn_more` = "https://data-dict.tidyverse.org/",
             name = schema,
             description = sprintf("Oracle schema %s at MFRI, dumped as it is on %s (%s, commit %s).",
                                   schema, run$dumped, run$script, substr(run$commit, 1, 7)),
             details = paste("Written by dump_oracle_schema() (R/dump_oracle.R, plan 018). Descriptions are Oracle's own",
                             "table and column comments. Ranges cover the whole file; examples come from its first",
                             "10,000 rows and may hold personal data, so this file is handled as the data are."),
             tables = tables)
  yaml::write_yaml(dd, file.path(out_dir, "_data-dict.yaml"))
}

# Every table and view of a schema, as it is. A table that fails is recorded and the loop goes on.
#   tables     dump only these (the overview still lists every object); for a schema that is not ours to dump whole
#   skip       objects deliberately left out; the caller says why
#   partition  list(table = "date column"): dumped by calendar year (dump_oracle_by_year())
#   max_rows   a table Oracle estimates bigger than this, and not partitioned, is listed but not dumped
# Returns the overview, invisibly.
dump_oracle_schema <- function(con, schema, out_dir, tables = NULL, skip = character(), partition = list(),
                               max_rows = 5e7, script = NA_character_) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  run <- .dump_run(con, script)
  ov_path <- file.path(out_dir, "_overview_tables.parquet")
  before  <- if (file.exists(ov_path)) nanoparquet::read_parquet(ov_path)$name else character()

  objects <- oracle_objects(con, schema)
  if (length(bad <- setdiff(c(tables, skip, names(partition)), objects$name)))
    stop("not in ", schema, ": ", paste(bad, collapse = ", "), call. = FALSE)
  fields <- oracle_fields(con, schema)
  .write_raw(fields, file.path(out_dir, "_overview_fields.parquet"), paste0(schema, " columns"), run)

  n <- nrow(objects)
  objects$partitioned <- objects$name %in% names(partition)
  rows <- rep(NA_real_, n); status <- rep(NA_character_, n)
  error <- rep(NA_character_, n); seconds <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    nm <- objects$name[i]
    why <- if (!is.null(tables) && !nm %in% tables) "listed"
           else if (nm %in% skip) "skipped"
           else if (!objects$partitioned[i] && isTRUE(objects$num_rows[i] > max_rows)) "too_big"
           else NA_character_
    if (!is.na(why)) {
      status[i] <- why
      if (why != "listed") message(sprintf("%s.%s: %s", schema, nm, why))
      next
    }
    t0 <- Sys.time()
    fl <- fields[fields$table == nm, ]
    r <- tryCatch(
      if (objects$partitioned[i])
        dump_oracle_by_year(con, paste0(schema, ".", nm), file.path(out_dir, nm), partition[[nm]], fl, run)
      else
        dump_oracle_table(con, paste0(schema, ".", nm), file.path(out_dir, paste0(nm, ".parquet")), fl, run),
      error = function(e) e)
    seconds[i] <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    invisible(gc(FALSE))   # an R reference holds its Java result until R's gc runs, whatever the Java heap
    if (inherits(r, "error")) {
      status[i] <- "failed"
      error[i]  <- gsub("\033\\[[0-9;]*m", "", conditionMessage(r))
      message(sprintf("%s.%s: FAILED - %s", schema, nm, error[i]))
    } else {
      rows[i] <- r
      status[i] <- "written"
    }
  }

  objects <- objects |>
    dplyr::mutate(rows = rows, status = status, error = error, seconds = seconds,
                  dumped = run$dumped, script = run$script, commit = run$commit, dirty = run$dirty,
                  driver = run$driver)
  .write_raw(objects, ov_path, paste0(schema, " objects"), run)
  dd <- tryCatch(.write_data_dict(out_dir, schema, objects, fields, run), error = function(e) e)
  if (inherits(dd, "error")) message("  _data-dict.yaml not written: ", conditionMessage(dd))

  failed <- objects$name[objects$status == "failed"]
  # Files an earlier dump of this schema wrote that this one did not: dropped from Oracle, or failed now.
  # Left in place, since raw/ is never deleted by code; the overview says they are not from this dump.
  stale <- setdiff(before, objects$name[objects$status %in% c("written", "skipped")])
  stale <- stale[file.exists(file.path(out_dir, paste0(stale, ".parquet"))) | dir.exists(file.path(out_dir, stale))]
  message(sprintf("%s: %d written, %d failed, %d skipped, %d too big, %d listed only -> %s",
                  schema, sum(status == "written"), length(failed), sum(status == "skipped"),
                  sum(status == "too_big"), sum(status == "listed"), out_dir))
  if (length(failed)) message("  failed: ", paste(failed, collapse = ", "))
  if (length(stale))  message("  not from this dump (older files kept): ", paste(stale, collapse = ", "))
  invisible(objects)
}
