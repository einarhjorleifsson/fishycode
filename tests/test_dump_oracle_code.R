# test_dump_oracle_code.R — dump_oracle_code() on a stand-in for Oracle's data dictionary (decision 166).
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_dump_oracle_code.R")'
#
# Never reaches Oracle. The stand-in is DuckDB in memory, with a schema sys holding the nine dictionary views the
# dumper reads, and dump_connect() either refuses or opens another connection to the stand-in (decision 109).
# all_mviews refuses as Oracle refuses a privilege (ORA-01031), whatever is asked of it.

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)

drv <- duckdb::duckdb()
standin <- function() DBI::dbConnect(drv)
con <- standin()
sql <- function(...) invisible(DBI::dbExecute(con, paste0(...)))
q <- function(x) gsub("'", "''", x, fixed = TRUE)

sql("CREATE TABLE dual (dummy VARCHAR)")
sql("INSERT INTO dual VALUES ('X')")
sql("CREATE SCHEMA sys")
sql("CREATE TABLE sys.all_objects (OWNER VARCHAR, OBJECT_NAME VARCHAR, SUBOBJECT_NAME VARCHAR, OBJECT_TYPE VARCHAR, ",
    "STATUS VARCHAR, CREATED TIMESTAMP, LAST_DDL_TIME TIMESTAMP)")
sql("INSERT INTO sys.all_objects VALUES ",
    "('ADB', 'STATION_V', NULL, 'VIEW', 'VALID', '2019-03-01 10:00:00', '2021-05-04 08:00:00'), ",
    "('ADB', 'FISHING_STATION', NULL, 'TABLE', 'VALID', '2019-03-01 10:00:00', '2025-01-01 00:00:00'), ",
    "('ADB', 'GENGI', NULL, 'PACKAGE', 'VALID', '2019-03-01 10:00:00', '2019-03-01 10:00:00'), ",
    "('ADB', 'GENGI', NULL, 'PACKAGE BODY', 'VALID', '2019-03-01 10:00:00', '2019-03-01 10:00:00'), ",
    "('KVOTI', 'LODS', NULL, 'TABLE', 'VALID', '2001-01-01 00:00:00', '2020-01-01 00:00:00')")

# a view's text with a carriage return and Icelandic letters, one past 4,000 bytes, and one shorter than Oracle says
station_v <- paste0("SELECT station_id,\r\n       latlon2dec(LATITUDE, LONGITUDE, 'LAT') latitude, ",
                    "'þorskur æöð' AS heiti\r\n  FROM adb.fishing_station")
long_v <- paste0("SELECT ", paste(sprintf("c%04d", 1:800), collapse = ", "), " FROM adb.wide")
bytes <- function(x) nchar(x, type = "bytes")
sql("CREATE TABLE sys.all_views (OWNER VARCHAR, VIEW_NAME VARCHAR, TEXT_LENGTH INTEGER, TEXT VARCHAR)")
sql("INSERT INTO sys.all_views VALUES ",
    "('ADB', 'STATION_V', ", bytes(station_v), ", '", q(station_v), "'), ",
    "('ADB', 'WIDE_V', ", bytes(long_v), ", '", q(long_v), "'), ",
    "('ADB', 'CUT_V', 120, 'SELECT 1 FROM dual'), ",
    "('KVOTI', 'LODS_V', 21, 'SELECT * FROM kvoti.lods')")
sql("CREATE VIEW sys.all_mviews AS SELECT * FROM (SELECT error('ORA-01031: insufficient privileges') AS OWNER, ",
    "NULL AS MVIEW_NAME, NULL AS CONTAINER_NAME, NULL AS QUERY_LEN, NULL AS QUERY, NULL AS MASTER_LINK, ",
    "NULL AS REFRESH_MODE, NULL AS REFRESH_METHOD, NULL AS BUILD_MODE, NULL AS LAST_REFRESH_TYPE, ",
    "NULL AS LAST_REFRESH_DATE, NULL AS STALENESS, NULL AS COMPILE_STATE)")
sql("CREATE TABLE sys.all_source (OWNER VARCHAR, NAME VARCHAR, TYPE VARCHAR, LINE INTEGER, TEXT VARCHAR)")
sql("INSERT INTO sys.all_source VALUES ('ADB', 'GENGI', 'PACKAGE', 2, '  FUNCTION rate RETURN NUMBER;\n'), ",
    "('ADB', 'GENGI', 'PACKAGE', 1, 'PACKAGE gengi AS\n'), ('ADB', 'GENGI', 'PACKAGE', 3, 'END gengi;'), ",
    "('KVOTI', 'KVUTIL', 'PACKAGE', 1, 'PACKAGE kvutil AS')")
sql("CREATE TABLE sys.all_triggers (OWNER VARCHAR, TRIGGER_NAME VARCHAR, TRIGGER_TYPE VARCHAR, ",
    "TRIGGERING_EVENT VARCHAR, TABLE_OWNER VARCHAR, BASE_OBJECT_TYPE VARCHAR, TABLE_NAME VARCHAR, ",
    "COLUMN_NAME VARCHAR, REFERENCING_NAMES VARCHAR, WHEN_CLAUSE VARCHAR, STATUS VARCHAR, DESCRIPTION VARCHAR, ",
    "ACTION_TYPE VARCHAR, TRIGGER_BODY VARCHAR)")
sql("INSERT INTO sys.all_triggers VALUES ",
    "('ADB', 'STATION_TRG', 'BEFORE EACH ROW', 'INSERT', 'ADB', 'TABLE', 'FISHING_STATION', NULL, ",
    "'REFERENCING NEW AS NEW OLD AS OLD', NULL, 'ENABLED', 'station_trg', 'PL/SQL', ",
    "'BEGIN\n  :new.moddate := SYSDATE;\nEND;'), ",
    "('STK', 'ADB_WATCH_TRG', 'AFTER EACH ROW', 'UPDATE', 'ADB', 'TABLE', 'FISHING_STATION', NULL, NULL, NULL, ",
    "'DISABLED', 'adb_watch_trg', 'PL/SQL', NULL), ",
    "('KVOTI', 'LODS_TRG', 'BEFORE EACH ROW', 'INSERT', 'KVOTI', 'TABLE', 'LODS', NULL, NULL, NULL, 'ENABLED', ",
    "'lods_trg', 'PL/SQL', 'BEGIN NULL; END;')")
sql("CREATE TABLE sys.all_synonyms (OWNER VARCHAR, SYNONYM_NAME VARCHAR, TABLE_OWNER VARCHAR, TABLE_NAME VARCHAR, ",
    "DB_LINK VARCHAR)")
sql("INSERT INTO sys.all_synonyms VALUES ('ADB', 'LODS_S', 'KVOTI', 'LODS', NULL), ",
    "('PUBLIC', 'LATLON2DEC', 'ADB', 'LATLON2DEC', NULL), ('PUBLIC', 'KVUTIL', 'KVOTI', 'KVUTIL', NULL)")
sql("CREATE TABLE sys.all_dependencies (OWNER VARCHAR, NAME VARCHAR, TYPE VARCHAR, REFERENCED_OWNER VARCHAR, ",
    "REFERENCED_NAME VARCHAR, REFERENCED_TYPE VARCHAR, REFERENCED_LINK_NAME VARCHAR, DEPENDENCY_TYPE VARCHAR)")
sql("INSERT INTO sys.all_dependencies VALUES ",
    "('ADB', 'STATION_V', 'VIEW', 'ADB', 'FISHING_STATION', 'TABLE', NULL, 'HARD'), ",
    "('ADB', 'STATION_V', 'VIEW', 'ADB', 'LATLON2DEC', 'FUNCTION', NULL, 'HARD'), ",
    "('ADB', 'STATION_V', 'VIEW', 'PUBLIC', 'LATLON2DEC', 'SYNONYM', NULL, 'HARD'), ",
    "('KVOTI', 'LODS_V', 'VIEW', 'KVOTI', 'LODS', 'TABLE', NULL, 'HARD')")
# a default as Oracle keeps it, trailing space and line feed included; one shorter than DEFAULT_LENGTH says
sql("CREATE TABLE sys.all_tab_columns (OWNER VARCHAR, TABLE_NAME VARCHAR, COLUMN_NAME VARCHAR, COLUMN_ID INTEGER, ",
    "DATA_TYPE VARCHAR, DATA_TYPE_OWNER VARCHAR, DATA_LENGTH INTEGER, CHAR_LENGTH INTEGER, CHAR_USED VARCHAR, ",
    "DATA_PRECISION INTEGER, DATA_SCALE INTEGER, NULLABLE VARCHAR, IDENTITY_COLUMN VARCHAR, DEFAULT_ON_NULL VARCHAR, ",
    "DEFAULT_LENGTH INTEGER, DATA_DEFAULT VARCHAR)")
sql("INSERT INTO sys.all_tab_columns VALUES ",
    "('ADB', 'FISHING_STATION', 'STATION_ID', 1, 'NUMBER', NULL, 22, 0, NULL, 10, 0, 'N', 'NO', 'NO', NULL, NULL), ",
    "('ADB', 'FISHING_STATION', 'MODDATE', 2, 'DATE', NULL, 7, 0, NULL, NULL, NULL, 'Y', 'NO', 'NO', 8, 'SYSDATE '), ",
    "('ADB', 'FISHING_STATION', 'NOTE', 3, 'VARCHAR2', NULL, 40, 40, 'B', NULL, NULL, 'Y', 'NO', 'NO', 7, ",
    "'''none''' || chr(10)), ",
    "('ADB', 'FISHING_STATION', 'CUT', 4, 'VARCHAR2', NULL, 1, 1, 'B', NULL, NULL, 'Y', 'NO', 'NO', 30, '''x'''), ",
    "('KVOTI', 'LODS', 'L_DAGS', 1, 'DATE', NULL, 7, 0, NULL, NULL, NULL, 'Y', 'NO', 'NO', 7, 'SYSDATE')")
sql("CREATE TABLE sys.all_col_comments (OWNER VARCHAR, TABLE_NAME VARCHAR, COLUMN_NAME VARCHAR, COMMENTS VARCHAR)")
sql("INSERT INTO sys.all_col_comments VALUES ('ADB', 'FISHING_STATION', 'STATION_ID', 'Au\u00f0kenni'), ",
    "('ADB', 'FISHING_STATION', 'MODDATE', NULL), ('KVOTI', 'LODS', 'L_DAGS', 'L\u00f6ndunardagur')")

run_out <- tempfile("dump_oracle_code_")
refuse <- function(...) stop("a test never connects to Oracle")
fd$dump_connect <- refuse
read <- function(dir, f) as.data.frame(nanoparquet::read_parquet(file.path(dir, paste0(f, ".parquet"))))
stamp <- function(dir, f, key) {
  p <- fd$curated_provenance(file.path(dir, paste0(f, ".parquet")))
  p$value[p$key == key]
}

out <- file.path(run_out, "adb", "_code")
dir.create(out, recursive = TRUE)
# an earlier run's file of a dictionary view that now refuses stays as it was
fd$.write_raw(data.frame(owner = "ADB", mview_name = "OLD_MV"), file.path(out, "all_mviews.parquet"), "adb all_mviews",
              list(dumped = "2026-10-01T00:00:00+0000", driver = "RJDBC", script = "earlier", commit = NA, dirty = NA))
ov <- suppressMessages(fd$dump_oracle_code(con, "adb", out, script = "tests/test_dump_oracle_code.R", connect = refuse))

test_that("each dictionary view is read for the schema only, its names in lower case", {
  expect_setequal(list.files(out), c(paste0(setdiff(names(fd$.oracle_code), "all_mviews"), ".parquet"),
                                     "all_mviews.parquet", "_overview.parquet"))
  v <- read(out, "all_views")
  expect_named(v, c("owner", "view_name", "text_length", "text"))
  expect_equal(v$view_name, c("CUT_V", "STATION_V", "WIDE_V"))
  expect_equal(unique(read(out, "all_objects")$owner), "ADB")
  expect_s3_class(read(out, "all_objects")$last_ddl_time, "POSIXct")
  expect_equal(read(out, "all_dependencies")$referenced_name, c("FISHING_STATION", "LATLON2DEC", "LATLON2DEC"))
})

test_that("a column's default comes whole, joined on its table and column, and none where there is none", {
  tc <- read(out, "all_tab_columns")
  expect_named(tc, c(tolower(fd$.oracle_code$all_tab_columns$cols), "data_default"))
  expect_equal(tc$column_name, c("STATION_ID", "MODDATE", "NOTE", "CUT"))
  expect_equal(tc$data_default, c(NA, "SYSDATE ", "'none'\n", "'x'"))
  expect_type(tc$default_length, "double")
  cc <- read(out, "all_col_comments")
  expect_named(cc, c("owner", "table_name", "column_name", "comments"))
  expect_equal(enc2utf8(cc$comments), c(NA, "Au\u00f0kenni"))
})

test_that("a view's text is kept whole: carriage returns, Icelandic letters, past 4,000 bytes", {
  v <- read(out, "all_views")
  expect_identical(enc2utf8(v$text[v$view_name == "STATION_V"]), station_v)
  expect_identical(v$text[v$view_name == "WIDE_V"], long_v)
  expect_gt(bytes(long_v), 4000)
  expect_type(v$text_length, "double")
})

test_that("stored code comes line by line, in order", {
  s <- read(out, "all_source")
  expect_equal(s$line, c(1, 2, 3))
  expect_equal(paste(s$text, collapse = ""), "PACKAGE gengi AS\n  FUNCTION rate RETURN NUMBER;\nEND gengi;")
})

test_that("a trigger on the schema's table and a public synonym to its object are the schema's", {
  t <- read(out, "all_triggers")
  expect_equal(t$trigger_name, c("STATION_TRG", "ADB_WATCH_TRG"))
  expect_equal(t$owner, c("ADB", "STK"))
  expect_equal(t$trigger_body[1], "BEGIN\n  :new.moddate := SYSDATE;\nEND;")
  y <- read(out, "all_synonyms")
  expect_equal(paste(y$owner, y$synonym_name), c("ADB LODS_S", "PUBLIC LATLON2DEC"))
})

test_that("the overview gives rows, the refusal with Oracle's code, and the notes", {
  o <- read(out, "_overview")
  expect_equal(o$source, names(fd$.oracle_code))
  expect_equal(o$status[o$source == "all_mviews"], "failed")
  expect_equal(o$error[o$source == "all_mviews"], "ORA-01031: insufficient privileges")
  expect_true(is.na(o$rows[o$source == "all_mviews"]))
  expect_equal(o$rows[o$source != "all_mviews"], c(4, 4, 2, 3, 3, 2, 2, 3))
  expect_match(o$note[o$source == "all_tab_columns"],
               "data_default not as long as DEFAULT_LENGTH on 1 of 3: FISHING_STATION.CUT (3 bytes of 30)",
               fixed = TRUE)
  expect_match(o$note[o$source == "all_views"], "text not as long as TEXT_LENGTH on 1 of 3: CUT_V (18 bytes of 120)",
               fixed = TRUE)
  expect_match(o$note[o$source == "all_source"],
               paste("source of 1 code objects; no line for 2 that all_objects lists or the schema's objects",
                     "depend on: GENGI (PACKAGE BODY), LATLON2DEC (FUNCTION)"),
               fixed = TRUE)
  expect_match(o$note[o$source == "all_triggers"], "no body on 1 of 2: ADB_WATCH_TRG", fixed = TRUE)
  expect_true(all(o$dumped == o$dumped[1]))
  expect_equal(stamp(out, "all_views", "fd.dumped"), o$dumped[1])
  expect_equal(stamp(out, "all_views", "fd.source"), "adb all_views")
  expect_equal(stamp(out, "all_views", "fd.note"), o$note[o$source == "all_views"])
})

test_that("a refused dictionary view writes nothing, and the earlier file stays", {
  expect_equal(read(out, "all_mviews")$mview_name, "OLD_MV")
  expect_equal(stamp(out, "all_mviews", "fd.dumped"), "2026-10-01T00:00:00+0000")
})

test_that("a schema with nothing in a dictionary view gets a file of no rows, with the columns", {
  e <- file.path(run_out, "uv", "_code")
  o <- suppressMessages(fd$dump_oracle_code(con, "uv", e, connect = refuse))
  expect_equal(o$rows[o$status == "written"], rep(0, 8))
  expect_named(read(e, "all_tab_columns"), c(tolower(fd$.oracle_code$all_tab_columns$cols), "data_default"))
  v <- read(e, "all_views")
  expect_equal(nrow(v), 0)
  expect_named(v, c("owner", "view_name", "text_length", "text"))
  expect_true(all(is.na(o$note)))
})

test_that("a connection lost is replaced once, and the rest is read on the new one", {
  dead <- standin()
  DBI::dbDisconnect(dead)
  opened <- list()
  open_standin <- function(...) { lc <- standin(); opened[[length(opened) + 1]] <<- lc; lc }
  e <- file.path(run_out, "lost", "_code")
  o <- suppressMessages(fd$dump_oracle_code(dead, "adb", e, connect = open_standin))
  expect_length(opened, 1)
  expect_equal(o$status, c(rep("written", 4), "failed", rep("written", 4)))
  expect_equal(nrow(read(e, "all_views")), 3)
})

test_that("Oracle's message is kept without the driver's wrapper", {
  e <- simpleError(paste0("Unable to retrieve JDBC result set\n  JDBC ERROR: ORA-00942: table or view does not exist\n",
                          "\n  Statement: SELECT 1 FROM SYS.DBA_VIEWS"))
  expect_equal(fd$.oracle_error(e), "ORA-00942: table or view does not exist")
  expect_equal(fd$.oracle_error(simpleError("unsupported column type\n  in TEXT")),
               "unsupported column type in TEXT")
})

DBI::dbDisconnect(con)
duckdb::duckdb_shutdown(drv)
unlink(run_out, recursive = TRUE)
