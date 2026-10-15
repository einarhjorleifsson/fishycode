# oracle_scanner_trial.R — TRIAL: dump Oracle tables as they are through DuckDB's oracle_scanner extension, beside
# the python-oracledb trial (dump/trial/dump_oracle_trial.py), to compare the two (2026-10-15, maintainer's request).
#
# Input:  Oracle tables, schema.table on the command line
# Output: <out>/<schema>/<table>.parquet, with R/dump_oracle.R's types and fd.* stamps
#
# Run from the repo root, in the maintainer's terminal (the password is in the macOS keychain):
#   Rscript dump/trial/oracle_scanner_trial.R --out <dir> afli.afli adb.catch ...
#   Rscript dump/trial/oracle_scanner_trial.R --dry-run afli.afli ...   the SQL only, from the local catalogue copies
#
# oracle_scanner (community extension, 0.4.0 for DuckDB 1.5.6) speaks Oracle's protocol itself: no Oracle client, no
# JVM, no R in the data path. Each table goes in three steps:
#   1. Oracle to a temporary parquet, streamed by DuckDB (the time reported is this step);
#   2. a local check that a NUMBER which came as text (an unconstrained NUMBER, "exact only as text") converts;
#   3. a local rewrite with R/dump_oracle.R's types (NUMBER(p <= 9, 0) integer, other NUMBERs double) and the stamps.
# The secret is TEMPORARY: the password lives only in this R session, never in ~/.duckdb.

args <- commandArgs(trailingOnly = TRUE)
dry <- "--dry-run" %in% args
out <- if ("--out" %in% args) args[which(args == "--out") + 1] else NA_character_
tables <- setdiff(args, c("--dry-run", "--out", out))
if (!length(tables) || (!dry && is.na(out))) stop("usage: --out <dir> schema.table ... | --dry-run schema.table ...")

for (f in list.files("R", full.names = TRUE)) source(f)
lit <- function(x) paste0("'", gsub("'", "''", x), "'")

con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "LOAD oracle_scanner")
version <- DBI::dbGetQuery(con, "SELECT oracle_scanner_version() AS v")$v
if (!dry) {
  cr <- mar:::db_credentials()                     # MAR_USER/MAR_PASS, else the keychain's "mar", as connect_mar()
  DBI::dbExecute(con, sprintf(
    "CREATE TEMPORARY SECRET ora (TYPE oracle, HOST 'hafmey.hafro.is', PORT 1521, SERVICE_NAME 'sjor.hafro', USER %s, PASSWORD %s)",
    lit(cr$username), lit(cr$password)))
  rm(cr)
}
oq <- function(sql) sprintf("oracle_query('ora', %s)", lit(sql))
g <- .git_info()

columns <- function(owner, table) {
  if (dry) {                                       # the catalogue copy the last R dump wrote
    f <- as.data.frame(nanoparquet::read_parquet(fd_raw("oracle", tolower(owner), "_overview_fields.parquet")))
    f <- f[f$table == tolower(table), ]
    f <- f[order(f$column_id), ]
    return(data.frame(name = toupper(f$column), type = f$data_type, precision = f$data_precision, scale = f$data_scale))
  }
  x <- DBI::dbGetQuery(con, paste("SELECT * FROM", oq(sprintf(
    "SELECT column_name AS name, data_type AS type, data_precision AS precision, data_scale AS scale FROM all_tab_columns WHERE owner = '%s' AND table_name = '%s' ORDER BY column_id",
    owner, table))))
  names(x) <- tolower(names(x))
  x$precision <- as.numeric(x$precision); x$scale <- as.numeric(x$scale)
  x
}

text_form <- c(SDO_GEOMETRY = "TO_CHAR(SDO_UTIL.TO_WKTGEOMETRY(%s))", XMLTYPE = "XMLSERIALIZE(DOCUMENT %s AS CLOB)")

report <- list()
for (spec in tables) {
  p <- toupper(strsplit(spec, ".", fixed = TRUE)[[1]]); owner <- p[1]; table <- p[2]
  cols <- columns(owner, table)
  if (!nrow(cols)) { message(spec, ": no columns"); next }
  q <- sprintf('"%s"', cols$name)
  f <- text_form[cols$type]
  sel <- ifelse(is.na(f), q, paste(sprintf(f, q), "AS", q))
  osql <- sprintf('SELECT %s FROM "%s"."%s"', paste(sel, collapse = ", "), owner, table)
  int <- cols$type == "NUMBER" & cols$scale %in% 0 & !is.na(cols$precision) & cols$precision <= 9
  num <- cols$type == "NUMBER" & !int
  if (dry) {
    cat(sprintf("\n%s\n  Oracle: %s\n  integer: %s\n  double:  %s\n", spec, osql, paste(tolower(cols$name[int]), collapse = " "),
                paste(tolower(cols$name[num]), collapse = " ")))
    next
  }
  path <- file.path(out, tolower(owner), paste0(tolower(table), ".parquet")); tmp <- paste0(path, ".partial")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  message(spec, ": fetching ...")
  t0 <- Sys.time()
  r <- tryCatch(DBI::dbExecute(con, sprintf("COPY (SELECT * FROM %s) TO %s (FORMAT parquet)", oq(osql), lit(tmp))),
                error = function(e) e)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(r, "error")) {
    message(spec, ": FAILED after ", round(secs), " s - ", conditionMessage(r))
    report[[spec]] <- data.frame(table = spec, rows = NA, seconds = round(secs), rows_per_s = NA, mb = NA, kept_as_text = NA, status = "failed")
    next
  }
  # 2. which numbers that came as text convert
  got <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet(%s)", lit(tmp)))
  textnum <- tolower(cols$name[num])[toupper(got$column_type[match(tolower(cols$name[num]), tolower(got$column_name))]) == "VARCHAR"]
  keep_text <- character()
  for (cn in textnum) {
    bad <- DBI::dbGetQuery(con, sprintf('SELECT count(*) AS n FROM read_parquet(%s) WHERE "%s" IS NOT NULL AND TRY_CAST("%s" AS DOUBLE) IS NULL',
                                        lit(tmp), cn, cn))$n
    if (bad > 0) keep_text <- c(keep_text, sprintf("%s (%d)", cn, bad))
  }
  # 3. R/dump_oracle.R's types and the stamps
  lc <- tolower(cols$name)
  expr <- ifelse(int, sprintf('CAST("%s" AS INTEGER) AS "%s"', lc, lc),
          ifelse(num & !lc %in% sub(" .*", "", keep_text), sprintf('CAST("%s" AS DOUBLE) AS "%s"', lc, lc),
                 sprintf('"%s" AS "%s"', lc, lc)))
  rows <- DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM read_parquet(%s)", lit(tmp)))$n
  kv <- c("fd.source" = tolower(spec), "fd.dumped" = format(t0, "%Y-%m-%dT%H:%M:%S%z"), "fd.rows" = rows,
          "fd.driver" = paste("duckdb oracle_scanner", version), "fd.script" = "dump/trial/oracle_scanner_trial.R",
          "fd.commit" = g$commit, "fd.dirty" = tolower(as.character(g$dirty)))
  meta <- paste(sprintf("%s: %s", lit(names(kv)), lit(kv)), collapse = ", ")
  DBI::dbExecute(con, sprintf('COPY (SELECT %s FROM read_parquet(%s)) TO %s (FORMAT parquet, KV_METADATA {%s})',
                              paste(expr, collapse = ", "), lit(tmp), lit(path), meta))
  unlink(tmp)
  mb <- file.size(path) / 1e6
  message(sprintf("%s: %s rows in %.0f s (%s rows/s, %.1f MB)%s", spec, format(rows, big.mark = ","), secs,
                  format(round(rows / secs), big.mark = ","), mb,
                  if (length(keep_text)) paste0("; kept as text: ", paste(keep_text, collapse = ", ")) else ""))
  report[[spec]] <- data.frame(table = spec, rows = rows, seconds = round(secs), rows_per_s = round(rows / secs),
                               mb = round(mb, 1), kept_as_text = paste(keep_text, collapse = ", "), status = "written")
}
if (!dry) { cat("\nsummary\n"); print(do.call(rbind, report), row.names = FALSE) }
