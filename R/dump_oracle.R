# dump_oracle.R — dump Oracle tables and views, as they are, to parquet under raw/.
#
# Input:  an open connection, mar::connect_mar(rjdbc = TRUE), and a schema (Oracle owner) or one table
# Output: <out_dir>/<name>.parquet for each table and view, plus
#           _overview_tables.parquet  one row per table and view: what Oracle holds, what was written, what
#                                     failed and why, and when, from which commit, with which driver
#           _overview_fields.parquet  one row per column: Oracle's type, precision, scale and comment
#
# Definitions only: targets sources R/ wholesale, so nothing here may connect at load.
#
# The table-and-view loop used to be copied into six scripts, three in dump/ and three beside the data under
# $FISHYDATA/raw/, and the copies drifted (decision 105). The dump scripts in dump/ call these instead.
#
# Integer columns are cast by the type Oracle declares, not by what the driver returns: RJDBC returns every
# NUMBER as a double, while the dumps made with ROracle on the servers hold NUMBER(p, 0) as integers. Casting
# NUMBER(p <= 9, 0) from all_tab_columns gives the same parquet whichever driver read it.

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

.oracle_integers <- function(d, fields) {
  int <- fields$column[fields$data_type %in% "NUMBER" &
                       fields$data_scale %in% 0 &
                       !is.na(fields$data_precision) & fields$data_precision <= 9]
  for (v in intersect(int, names(d))) if (is.double(d[[v]])) d[[v]] <- as.integer(d[[v]])
  d
}

.oracle_driver <- function(con) if (inherits(con, "JDBCConnection")) "RJDBC" else "ROracle"

# One table or view ("schema.name") to one parquet file. `drop` leaves columns out (e.g. Oracle user names).
# Reports and returns the rows written.
dump_oracle_table <- function(con, table, path, fields = NULL, drop = character()) {
  if (is.null(fields)) {
    x <- strsplit(table, ".", fixed = TRUE)[[1]]
    fields <- oracle_fields(con, x[1], x[2])
  }
  d <- mar::tbl_mar(con, table) |> dplyr::collect()
  d <- d[setdiff(names(d), drop)]
  d <- .oracle_integers(d, fields)
  write_parquet_group(d, path)
  message(sprintf("%s: %s rows", table, format(nrow(d), big.mark = ",")))
  nrow(d)
}

# Every table and view of a schema. A table that fails is recorded and the loop goes on; `skip` names
# objects deliberately left out (the caller says why). Returns the overview, invisibly.
dump_oracle_schema <- function(con, schema, out_dir, skip = character(), script = NA_character_) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  started <- Sys.time()
  ov_path <- file.path(out_dir, "_overview_tables.parquet")
  before  <- if (file.exists(ov_path)) nanoparquet::read_parquet(ov_path)$name else character()

  objects <- dplyr::bind_rows(
    mar::mar_tables(con, schema) |> dplyr::collect() |>
      dplyr::rename(name = table_name) |> dplyr::mutate(type = "table"),
    mar::mar_views(con, schema) |> dplyr::collect() |>
      dplyr::rename(name = view_name) |> dplyr::mutate(type = "view"))
  fields <- oracle_fields(con, schema)
  write_parquet_group(fields, file.path(out_dir, "_overview_fields.parquet"))

  n <- nrow(objects)
  rows <- rep(NA_integer_, n); status <- rep(NA_character_, n)
  error <- rep(NA_character_, n); seconds <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    nm <- objects$name[i]
    if (nm %in% skip) {
      status[i] <- "skipped"
      message(sprintf("%s.%s: skipped", schema, nm))
      next
    }
    t0 <- Sys.time()
    r <- tryCatch(
      dump_oracle_table(con, paste0(schema, ".", nm), file.path(out_dir, paste0(nm, ".parquet")),
                        fields = fields[fields$table == nm, ]),
      error = function(e) e)
    seconds[i] <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (inherits(r, "error")) {
      status[i] <- "failed"
      error[i]  <- conditionMessage(r)
      message(sprintf("%s.%s: FAILED - %s", schema, nm, error[i]))
    } else {
      rows[i] <- as.integer(r)
      status[i] <- "written"
    }
  }

  g <- .git_info()
  objects <- objects |>
    dplyr::mutate(rows = rows, status = status, error = error, seconds = seconds,
                  dumped = started, script = script, commit = g$commit, dirty = g$dirty,
                  driver = .oracle_driver(con))
  write_parquet_group(objects, ov_path)

  failed <- objects$name[objects$status == "failed"]
  # Files an earlier dump of this schema wrote that this one did not: dropped from Oracle, or failed now.
  # Left in place, since raw/ is never deleted by code; the overview says they are not from this dump.
  stale <- setdiff(before, objects$name[objects$status %in% c("written", "skipped")])
  stale <- stale[file.exists(file.path(out_dir, paste0(stale, ".parquet")))]
  message(sprintf("%s: %d written, %d failed, %d skipped -> %s",
                  schema, sum(status == "written"), length(failed), sum(status == "skipped"), out_dir))
  if (length(failed)) message("  failed: ", paste(failed, collapse = ", "))
  if (length(stale))  message("  not from this dump (older files kept): ", paste(stale, collapse = ", "))
  invisible(objects)
}
