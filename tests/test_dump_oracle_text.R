# test_dump_oracle_text.R — dump_oracle_schema() on text that is not valid UTF-8, on a stand-in for Oracle (decision 167).
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_dump_oracle_text.R")'
#
# Never reaches Oracle. The stand-in is DuckDB in memory, with a schema sys holding the five dictionary views
# dump_oracle_schema() reads, and dump_connect() refuses (decision 109). DuckDB cannot hold a byte that is not UTF-8,
# so the stand-in keeps it as the text \xED and hands it to R as the byte, as ROracle handed over the bytes Oracle
# holds: kvoti.kvotategundir_heiti_jn's insert of 2019-06-28, "Makr\xEDll" (hafdruna, 2026-10-16), whose file DuckDB
# refused whole, so that kvoti's _data-dict.yaml was never written.

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)

# the text \xNN as the byte NN, marked UTF-8 as a driver in a UTF-8 session marks it
as_stored <- function(x) {
  if (!is.character(x)) return(x)
  i <- which(grepl("\\x", x, fixed = TRUE))
  x[i] <- vapply(x[i], function(s) {
    p <- regmatches(s, gregexpr("\\\\x[0-9A-F]{2}|.", s, perl = TRUE))[[1]]
    b <- unlist(lapply(p, function(c) if (nchar(c) == 4 && startsWith(c, "\\x")) as.raw(strtoi(substr(c, 3, 4), 16L))
                                      else charToRaw(c)))
    r <- rawToChar(b)
    Encoding(r) <- "UTF-8"
    r
  }, "", USE.NAMES = FALSE)
  x
}

suppressPackageStartupMessages(library(duckdb))   # setClass() needs duckdb_connection in reach
methods::setClass("oracle_text_standin", contains = "duckdb_connection")
methods::setMethod("dbGetQuery", c("oracle_text_standin", "character"), function(conn, statement, ...) {
  d <- methods::callNextMethod()
  d[] <- lapply(d, as_stored)
  d
})
drv <- duckdb::duckdb()
con <- methods::new("oracle_text_standin", DBI::dbConnect(drv))
invisible(suppressMessages(DBI::dbGetQuery(con, "SELECT 1")))   # S4's note on the method it inherits, once
sql <- function(...) invisible(DBI::dbExecute(con, paste0(...)))

sql("CREATE TABLE dual (dummy VARCHAR)")
sql("INSERT INTO dual VALUES ('X')")
# a NUMBER with no scale comes through TO_CHAR, as through ROracle; else the dumper's query would be mar::tbl_mar(),
# whose in_schema() DuckDB's tbl() does not take
sql("CREATE MACRO to_char(v) AS v::VARCHAR")
sql("CREATE SCHEMA sys")
sql("CREATE TABLE sys.all_tables (OWNER VARCHAR, TABLE_NAME VARCHAR, TABLESPACE_NAME VARCHAR, NUM_ROWS INTEGER, ",
    "LAST_ANALYZED TIMESTAMP)")
sql("INSERT INTO sys.all_tables VALUES ('KVOTI', 'KVOTATEGUNDIR_HEITI', 'USERS', 2, NULL), ",
    "('KVOTI', 'KVOTATEGUNDIR_HEITI_JN', 'USERS', 3, NULL)")
sql("CREATE TABLE sys.all_views (OWNER VARCHAR, VIEW_NAME VARCHAR)")
sql("CREATE TABLE sys.all_tab_comments (OWNER VARCHAR, TABLE_NAME VARCHAR, COMMENTS VARCHAR)")
sql("INSERT INTO sys.all_tab_comments VALUES ('KVOTI', 'KVOTATEGUNDIR_HEITI', 'Heiti kv\\xF3tategunda'), ",
    "('KVOTI', 'KVOTATEGUNDIR_HEITI_JN', NULL)")
sql("CREATE TABLE sys.all_tab_columns (OWNER VARCHAR, TABLE_NAME VARCHAR, COLUMN_NAME VARCHAR, COLUMN_ID INTEGER, ",
    "DATA_TYPE VARCHAR, DATA_PRECISION INTEGER, DATA_SCALE INTEGER, NULLABLE VARCHAR)")
cols <- function(t, extra = character()) {
  x <- c(extra, "KVOTATEGUND", "HEITI", "VEFHEITI", "RODUN")
  type <- c(if (length(extra)) c("CHAR", "DATE"), "NUMBER", "VARCHAR2", "VARCHAR2", "NUMBER")
  whole <- x == "KVOTATEGUND"
  paste(sprintf("('KVOTI', '%s', '%s', %d, '%s', %s, %s, 'Y')", t, x, seq_along(x), type,
                ifelse(whole, "3", "NULL"), ifelse(whole, "0", "NULL")), collapse = ", ")
}
sql("INSERT INTO sys.all_tab_columns VALUES ", cols("KVOTATEGUNDIR_HEITI"), ", ",
    cols("KVOTATEGUNDIR_HEITI_JN", c("JN_OPERATION", "JN_DATETIME")))
# comments with a stray byte too (the table's above): the overviews are written as the tables are, and
# _data-dict.yaml takes the comments from memory, where yaml::write_yaml() would abort R on them
sql("CREATE TABLE sys.all_col_comments (OWNER VARCHAR, TABLE_NAME VARCHAR, COLUMN_NAME VARCHAR, COMMENTS VARCHAR)")
sql("INSERT INTO sys.all_col_comments VALUES ('KVOTI', 'KVOTATEGUNDIR_HEITI', 'HEITI', 'Heiti tegundar'), ",
    "('KVOTI', 'KVOTATEGUNDIR_HEITI', 'VEFHEITI', 'Heiti \\xE1 vef')")

sql("CREATE SCHEMA kvoti")
sql("CREATE TABLE kvoti.kvotategundir_heiti (kvotategund INTEGER, heiti VARCHAR, vefheiti VARCHAR, rodun DOUBLE)")
sql("INSERT INTO kvoti.kvotategundir_heiti VALUES (36, 'Makríll', 'Makríll', 20), (1, 'Þorskur', NULL, 1)")
sql("CREATE TABLE kvoti.kvotategundir_heiti_jn (jn_operation VARCHAR, jn_datetime TIMESTAMP, kvotategund INTEGER, ",
    "heiti VARCHAR, vefheiti VARCHAR, rodun DOUBLE)")
sql("INSERT INTO kvoti.kvotategundir_heiti_jn VALUES ('INS', '2013-03-12 08:57:14', 1, 'Þorskur', NULL, 1), ",
    "('INS', '2019-06-28 08:20:24', 36, 'Makr\\xEDll', 'Makr\\xEDll', 20), ",
    "('UPD', '2019-06-28 09:37:21', 36, 'Makríll', 'Makríll', 20)")

run_fields <- function() fd$oracle_fields(con, "kvoti")
out <- tempfile("dump_oracle_text_")
refuse <- function(...) stop("a test never connects to Oracle")
whole <- function(path) {   # DuckDB reads every value, as a reader of the dump does
  dk <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(dk, shutdown = TRUE))
  DBI::dbGetQuery(dk, sprintf("SELECT * FROM read_parquet('%s')", path))
}
note_of <- function(path) { p <- fd$curated_provenance(path); p$value[p$key == "fd.note"] }

test_that("the stand-in hands over the bytes as stored, as ROracle did", {
  x <- DBI::dbGetQuery(con, "SELECT heiti FROM kvoti.kvotategundir_heiti_jn WHERE kvotategund = 36")$heiti
  expect_identical(charToRaw(x[1]), charToRaw("Makr\xEDll"))
  expect_false(validUTF8(x[1]))
  expect_true(validUTF8(x[2]))
})

test_that("a stray byte is read as Windows-1252, valid UTF-8 is kept, and the note gives the bytes", {
  six <- rawToChar(as.raw(c(0x48, 0x65, 0xFC, 0xBE, 0x8C, 0xA3, 0xA4, 0xBC, 0x73)))   # ops_einarhj.ices_landed_catch
  mixed <- rawToChar(c(charToRaw("þ"), as.raw(0xED)))   # R refuses \u and \x in one literal
  d <- data.frame(n = 1:6, a = c("Makr\xEDll", "Þorskur", NA, mixed, six, "\x81 \xC3"), b = "ok")
  d$a <- vapply(d$a, function(s) { Encoding(s) <- "UTF-8"; s }, "", USE.NAMES = FALSE)
  v <- fd$.utf8_valid(d)
  expect_identical(v$a[1], "Makríll")
  expect_identical(v$a[2], "Þorskur")
  expect_true(is.na(v$a[3]))
  expect_identical(v$a[4], "þí")                               # a valid sequence beside a stray byte
  expect_identical(v$a[5], "Heü¾Œ£¤¼s")    # 0x8C is 1252's Œ, not Latin-1's control
  expect_identical(v$a[6], "\u0081 Ã")                              # 0x81: no 1252 character, so Latin-1; C3 cut off
  expect_true(all(validUTF8(v$a[!is.na(v$a)])))
  expect_identical(v$b, d$b)
  expect_identical(attr(v, "note"), paste("text not valid UTF-8, as Oracle holds it, in a (4 values; bytes 81 8C A3 A4",
                                          "BC BE C3 ED FC) - each byte outside a valid UTF-8 sequence read as Windows-1252"))
  expect_null(attr(fd$.utf8_valid(d[2:3, ]), "note"))
})

test_that("a table with a stray byte is dumped readable and noted, and the schema's _data-dict.yaml is written", {
  fd$dump_connect <- refuse
  ov <- suppressMessages(fd$dump_oracle_schema(con, "kvoti", out, script = "tests/test_dump_oracle_text.R",
                                               connect = refuse, resume = FALSE))
  expect_equal(ov$status, c("written", "written"))
  jn <- file.path(out, "kvotategundir_heiti_jn.parquet")
  d <- whole(jn)
  expect_equal(d$heiti, c("Þorskur", "Makríll", "Makríll"))
  expect_equal(d$vefheiti, c(NA, "Makríll", "Makríll"))
  want <- paste("text not valid UTF-8, as Oracle holds it, in heiti (1 value; bytes ED), vefheiti (1 value; bytes ED)",
                "- each byte outside a valid UTF-8 sequence read as Windows-1252")
  expect_identical(ov$note[ov$name == "kvotategundir_heiti_jn"], want)
  expect_identical(note_of(jn), want)
  expect_true(is.na(ov$note[ov$name == "kvotategundir_heiti"]))
  expect_length(note_of(file.path(out, "kvotategundir_heiti.parquet")), 0)

  fl <- whole(file.path(out, "_overview_fields.parquet"))
  expect_identical(fl$comments[fl$column == "vefheiti" & fl$table == "kvotategundir_heiti"], "Heiti á vef")
  expect_match(note_of(file.path(out, "_overview_fields.parquet")), "comments (1 value; bytes E1)", fixed = TRUE)

  ot <- whole(file.path(out, "_overview_tables.parquet"))
  expect_identical(ot$comments[ot$name == "kvotategundir_heiti"], "Heiti kv\u00f3tategunda")
  expect_match(note_of(file.path(out, "_overview_tables.parquet")), "comments (1 value; bytes F3)", fixed = TRUE)

  dd <- yaml::read_yaml(file.path(out, "_data-dict.yaml"))
  expect_equal(vapply(dd$tables, `[[`, "", "name"), c("kvotategundir_heiti", "kvotategundir_heiti_jn"))
  expect_identical(dd$tables[[1]]$description, "Heiti kv\u00f3tategunda")
  expect_identical(dd$tables[[1]]$columns[[3]]$description, "Heiti \u00e1 vef")
  expect_identical(dd$tables[[2]]$details, want)
  expect_true("Makríll" %in% unlist(dd$tables[[2]]$columns[[4]]$examples))
})

DBI::dbDisconnect(con)
duckdb::duckdb_shutdown(drv)
unlink(out, recursive = TRUE)
