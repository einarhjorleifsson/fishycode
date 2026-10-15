# compare_dumps.R — two dumps of one Oracle schema, table by table: what differs, and where (decision 109).
#
# Input:  two directories written by dump_oracle_schema(): e.g. raw/oracle/<schema>/ through RJDBC on the Mac and the
#         same schema dumped through ROracle on the server
# Output: a data frame, one row per table (per year for a partitioned table); nothing is written
#
# Definitions only: targets sources R/ wholesale.
#
# For each table: whether each dump has it, its rows, the driver and dump time stamped in each file, the columns only
# one has, the columns whose types differ, and, where both have it, the rows of each that the other lacks (EXCEPT ALL
# over the columns both have) and the columns whose values differ. Where a column's types differ, two numbers are
# compared as DOUBLE, two date-times as TIMESTAMP in UTC (the April dumps made on the server hold TIMESTAMP WITH TIME
# ZONE, these dumps plain TIMESTAMP), and anything else as text. NULLs compare equal.
#
# Two dumps made at different times also differ wherever Oracle changed in between: a row only in the later one may
# be a new record, not the driver's doing. `digits` rounds DOUBLE columns before comparing, for a driver that converts
# NUMBER to double differently in the last bits.
#
#   d <- compare_dumps(fd_raw("oracle_server", "afli"), fd_raw("oracle", "afli"))
#   d[!d$same, ]
compare_dumps <- function(a, b, tables = NULL, max_rows = 5e7, digits = NULL, memory_limit = "8GB") {
  units <- function(dir) {
    f <- list.files(dir, pattern = "^[^_].*[.]parquet$")
    p <- list.dirs(dir, recursive = FALSE, full.names = FALSE)
    p <- p[!startsWith(p, "_")]
    y <- unlist(lapply(p, function(t) file.path(t, list.dirs(file.path(dir, t), recursive = FALSE, full.names = FALSE))))
    sort(c(sub("[.]parquet$", "", f), y))
  }
  path <- function(dir, u) if (grepl("/", u)) file.path(dir, u, "*.parquet") else file.path(dir, paste0(u, ".parquet"))
  ua <- units(a); ub <- units(b)
  all <- union(ua, ub)
  if (!is.null(tables)) all <- all[sub("/.*", "", all) %in% tables]

  con <- DBI::dbConnect(duckdb::duckdb())
  spill <- file.path(tempdir(), "compare_dumps_spill")
  on.exit({ DBI::dbDisconnect(con, shutdown = TRUE); unlink(spill, recursive = TRUE) }, add = TRUE)
  DBI::dbExecute(con, sprintf("SET temp_directory = %s", .sq(spill)))
  DBI::dbExecute(con, sprintf("SET memory_limit = %s", .sq(memory_limit)))
  DBI::dbExecute(con, "SET TimeZone = 'UTC'")   # a TIMESTAMP WITH TIME ZONE cast to TIMESTAMP gives UTC's clock
  q <- function(sql) DBI::dbGetQuery(con, sql)
  src <- function(dir, u) sprintf("read_parquet(%s, hive_partitioning = false)", .sq(path(dir, u)))
  stamp <- function(dir, u, key) {
    f <- Sys.glob(path(dir, u))[1]
    v <- q(sprintf("SELECT decode(value) AS v FROM parquet_kv_metadata(%s) WHERE decode(key) = %s", .sq(f), .sq(key)))$v
    if (length(v)) v[1] else NA_character_
  }
  time_type <- function(t) grepl("^TIMESTAMP", t)
  numeric_type <- function(t) grepl("^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|FLOAT|DOUBLE|DECIMAL)", t)

  rows <- lapply(all, function(u) {
    r <- list(table = u, in_a = u %in% ua, in_b = u %in% ub, rows_a = NA_real_, rows_b = NA_real_,
              driver_a = NA_character_, driver_b = NA_character_, dumped_a = NA_character_, dumped_b = NA_character_,
              only_a = NA_character_, only_b = NA_character_, type_differs = NA_character_,
              rows_only_a = NA_real_, rows_only_b = NA_real_, values_differ = NA_character_, compared = "no")
    for (s in c("a", "b")) if (r[[paste0("in_", s)]]) {
      dir <- if (s == "a") a else b
      r[[paste0("rows_", s)]] <- q(sprintf("SELECT count(*) AS n FROM %s", src(dir, u)))$n
      r[[paste0("driver_", s)]] <- stamp(dir, u, "fd.driver")
      r[[paste0("dumped_", s)]] <- stamp(dir, u, "fd.dumped")
    }
    if (!(r$in_a && r$in_b)) return(r)
    da <- q(sprintf("DESCRIBE SELECT * FROM %s", src(a, u)))
    db <- q(sprintf("DESCRIBE SELECT * FROM %s", src(b, u)))
    common <- intersect(da$column_name, db$column_name)
    r$only_a <- paste(setdiff(da$column_name, db$column_name), collapse = ", ")
    r$only_b <- paste(setdiff(db$column_name, da$column_name), collapse = ", ")
    ta <- da$column_type[match(common, da$column_name)]
    tb <- db$column_type[match(common, db$column_name)]
    diff <- ta != tb
    r$type_differs <- paste(sprintf("%s (%s / %s)", common[diff], ta[diff], tb[diff]), collapse = ", ")
    if (max(r$rows_a, r$rows_b) > max_rows) { r$compared <- "too big"; return(r) }
    expr <- vapply(seq_along(common), function(i) {
      cn <- sprintf('"%s"', gsub('"', '""', common[i]))
      x <- if (!diff[i]) cn
           else if (numeric_type(ta[i]) && numeric_type(tb[i])) sprintf("CAST(%s AS DOUBLE)", cn)
           else if (time_type(ta[i]) && time_type(tb[i])) sprintf("CAST(%s AS TIMESTAMP)", cn)
           else sprintf("CAST(%s AS VARCHAR)", cn)
      if (!is.null(digits) && (grepl("^(FLOAT|DOUBLE)", ta[i]) || grepl("^(FLOAT|DOUBLE)", tb[i])))
        x <- sprintf("round(CAST(%s AS DOUBLE), %d)", x, as.integer(digits))
      x
    }, "")
    lacks <- function(cols, x, y) q(sprintf("SELECT count(*) AS n FROM (SELECT %s FROM %s EXCEPT ALL SELECT %s FROM %s)",
                                            cols, x, cols, y))$n
    all_cols <- paste(expr, collapse = ", ")
    r$rows_only_a <- lacks(all_cols, src(a, u), src(b, u))
    r$rows_only_b <- lacks(all_cols, src(b, u), src(a, u))
    if (r$rows_only_a + r$rows_only_b > 0) {
      bad <- common[vapply(expr, function(e) lacks(e, src(a, u), src(b, u)) + lacks(e, src(b, u), src(a, u)) > 0, TRUE)]
      r$values_differ <- paste(bad, collapse = ", ")
    }
    r$compared <- "yes"
    r
  })
  out <- do.call(rbind, lapply(rows, as.data.frame))
  out$same <- out$in_a & out$in_b & out$compared == "yes" & out$rows_a == out$rows_b &
    !nzchar(out$only_a) & !nzchar(out$only_b) & !nzchar(out$type_differs) &
    out$rows_only_a == 0 & out$rows_only_b == 0
  out$same[is.na(out$same)] <- FALSE
  message(sprintf("%d tables: %d the same, %d only in a, %d only in b, %d differ, %d too big to compare by row",
                  nrow(out), sum(out$same), sum(out$in_a & !out$in_b), sum(out$in_b & !out$in_a),
                  sum(out$in_a & out$in_b & !out$same & out$compared == "yes"), sum(out$compared == "too big")))
  out
}

.sq <- function(x) paste0("'", gsub("'", "''", x), "'")
