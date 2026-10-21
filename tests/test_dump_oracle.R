# test_dump_oracle.R — dump_oracle_table() on geometries Oracle cannot write as VARCHAR2 WKT, on a stand-in for Oracle.
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_dump_oracle.R")'
#
# Never reaches Oracle. The stand-in is DuckDB in memory, and dump_connect() either refuses or opens another
# connection to the stand-in: a dumper test once reconnected through the real dump_connect() and the keychain
# (decision 109). The stand-in raises what Oracle raised on the server's channel dump (2026-10-21): TO_WKTGEOMETRY()
# ORA-13199 on a line whose element type is a polygon's (channel.station), TO_CHAR() ORA-22835 past 4,000 characters
# (channel.country). A geometry is a struct of SDO_GEOMETRY's attributes with its WKT beside them. The connection
# rewrites the three constructs of .oracle_parts() that DuckDB cannot read (TABLE(), LISTAGG and its ORDER BY ROWNUM),
# so the dumper's own SQL runs; that Oracle reads it was checked on channel.station and channel.country, read-only.

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)

suppressPackageStartupMessages(library(duckdb))   # setClass() needs duckdb_connection in reach
methods::setClass("oracle_standin", contains = "duckdb_connection")
to_duckdb <- function(s) {
  s <- gsub("LISTAGG(", "string_agg(", s, fixed = TRUE)
  s <- gsub(" WITHIN GROUP (ORDER BY ROWNUM)", "", s, fixed = TRUE)
  gsub("FROM TABLE\\(([^()]*)\\) e", "FROM (SELECT unnest(\\1) AS COLUMN_VALUE) e", s)
}
methods::setMethod("dbSendQuery", c("oracle_standin", "character"), function(conn, statement, ...)
  methods::callNextMethod(conn, to_duckdb(statement), ...))
drv <- duckdb::duckdb()
standin <- function() methods::new("oracle_standin", DBI::dbConnect(drv))
con <- standin()
invisible(suppressMessages(DBI::dbGetQuery(con, "SELECT 1")))   # S4's note on the method it inherits, once

sql <- function(...) invisible(DBI::dbExecute(con, paste0(...)))
sql("SET threads = 1")   # in order, so channel.mixed meets its long WKT before its invalid line
sql("CREATE TYPE sdo_geometry AS STRUCT(SDO_GTYPE INTEGER, SDO_SRID INTEGER, ",
    "SDO_POINT STRUCT(X DOUBLE, Y DOUBLE, Z DOUBLE), SDO_ELEM_INFO INTEGER[], SDO_ORDINATES DOUBLE[], WKT VARCHAR)")
sql("CREATE MACRO pt(x, y) AS {'SDO_GTYPE': 2001::INTEGER, 'SDO_SRID': 8307::INTEGER, ",
    "'SDO_POINT': {'X': x::DOUBLE, 'Y': y::DOUBLE, 'Z': NULL::DOUBLE}, 'SDO_ELEM_INFO': NULL::INTEGER[], ",
    "'SDO_ORDINATES': NULL::DOUBLE[], 'WKT': 'POINT (' || x || ' ' || y || ')'}::sdo_geometry")
sql("CREATE MACRO shape(gtype, elem, ords, wkt) AS {'SDO_GTYPE': gtype::INTEGER, 'SDO_SRID': 8307::INTEGER, ",
    "'SDO_POINT': NULL::STRUCT(X DOUBLE, Y DOUBLE, Z DOUBLE), 'SDO_ELEM_INFO': elem::INTEGER[], ",
    "'SDO_ORDINATES': ords::DOUBLE[], 'WKT': wkt::VARCHAR}::sdo_geometry")
sql("CREATE SCHEMA sdo_util")
sql("CREATE MACRO sdo_util.to_wktgeometry(g) AS CASE WHEN struct_extract(g, 'SDO_GTYPE') = 2002 AND ",
    "struct_extract(g, 'SDO_ELEM_INFO')[2] = 1003 THEN error('ORA-13199: curve: invalid element type found' || ",
    "chr(10) || 'ORA-06512: at \"MDSYS.SDO_UTIL\", line 2') ELSE struct_extract(g, 'WKT') END")
sql("CREATE MACRO to_char(v) AS CASE WHEN length(v::VARCHAR) > 4000 THEN error('ORA-22835: Buffer too small for ",
    "CLOB to CHAR or BLOB to RAW conversion (actual: ' || length(v::VARCHAR) || ', maximum: 4000)') ",
    "ELSE v::VARCHAR END, (v, fmt, nls) AS CASE WHEN v = trunc(v) THEN v::BIGINT::VARCHAR ELSE v::VARCHAR END")
sql("CREATE SCHEMA channel")
long <- paste0("POLYGON ((", paste(rep("-20.5 65.5", 420), collapse = ", "), "))")   # 5,050 characters
sql("CREATE TABLE channel.harbour (harbour_no INTEGER, location sdo_geometry)")
sql("INSERT INTO channel.harbour VALUES (1, pt(-21.94, 64.15)), (2, ",
    "shape(2003, [1, 1003, 3], [-22, 64, -21, 65], 'POLYGON ((-22 64, -21 64, -21 65, -22 65, -22 64))')), (3, NULL)")
sql("CREATE TABLE channel.country (country_no INTEGER, name VARCHAR, location sdo_geometry)")
sql("INSERT INTO channel.country VALUES (1, 'a', pt(-21, 64)), (2, 'b', shape(2003, [1, 1003, 1], [], '", long, "')), ",
    "(3, 'c', NULL)")
sql("CREATE TABLE channel.station (station_id INTEGER, latitude INTEGER, location sdo_geometry, note VARCHAR)")
sql("INSERT INTO channel.station VALUES (1, 641500, pt(-22.5, 64.25), 'point'), ",
    "(2, 641230, shape(2002, [1, 1003, 1], [-23.658, 64.205, -23.693, 64.1745], NULL), 'line'), ",
    "(3, 640000, shape(2003, [1, 1003, 3], [-22, 64, -21, 65], 'POLYGON ((-22 64, -21 64, -21 65, -22 65, -22 64))'), ",
    "'rectangle'), (4, NULL, NULL, 'none')")
sql("CREATE TABLE channel.mixed AS SELECT i::INTEGER AS station_id, CASE WHEN i = 0 THEN shape(2003, [1, 1003, 1], [], ",
    "'", long, "') WHEN i = 2500 THEN shape(2002, [1, 1003, 1], [-23, 64, -24, 65], NULL) ELSE pt(-22, 64) END ",
    "AS location FROM range(3000) r(i)")

fields_of <- function(table, column, data_type)
  tibble::tibble(table = table, column = column, oracle_column = toupper(column), column_id = seq_along(column),
                 data_type = data_type, data_precision = ifelse(data_type == "NUMBER", 9, NA),
                 data_scale = ifelse(data_type == "NUMBER", 0, NA))
run <- list(dumped = "2026-10-21T00:00:00+0000", driver = "ROracle", script = "tests/test_dump_oracle.R",
            commit = NA_character_, dirty = NA_character_)
out <- tempfile("dump_oracle_")
refuse <- function(...) stop("a test never connects to Oracle")
opened <- list()
open_standin <- function(...) {
  lc <- standin()
  opened[[length(opened) + 1]] <<- lc
  lc
}
dump <- function(table, fields, connect = refuse) {
  fd$dump_connect <- connect
  opened <<- list()
  path <- file.path(out, paste0(table, ".parquet"))
  r <- suppressMessages(fd$dump_oracle_table(con, paste0("channel.", table), path, fields, run))
  p <- fd$curated_provenance(path)
  list(rows = as.numeric(r), note = attr(r, "note"), d = as.data.frame(nanoparquet::read_parquet(path)),
       fd_note = p$value[p$key == "fd.note"])
}
parts <- c("gtype", "srid", "x", "y", "z", "elem_info", "ordinates")

test_that("a geometry Oracle writes as WKT is read as WKT, with no note and no second connection", {
  x <- dump("harbour", fields_of("harbour", c("harbour_no", "location"), c("NUMBER", "SDO_GEOMETRY")))
  expect_equal(x$rows, 3)
  expect_equal(x$d$location, c("POINT (-21.94 64.15)", "POLYGON ((-22 64, -21 64, -21 65, -22 65, -22 64))", NA))
  expect_true(is.na(x$note))
  expect_length(x$fd_note, 0)
})

test_that("a WKT past 4,000 characters is read again as a CLOB, on a connection of its own (channel.country)", {
  x <- dump("country", fields_of("country", c("country_no", "name", "location"), c("NUMBER", "VARCHAR2", "SDO_GEOMETRY")),
            open_standin)
  expect_equal(x$rows, 3)
  expect_equal(nchar(x$d$location), c(14, 5050, NA))
  expect_identical(x$d$location[2], long)
  expect_equal(x$d$name, c("a", "b", "c"))
  expect_match(x$note, "location (longest 5,050 characters) read as WKT in a CLOB", fixed = TRUE)
  expect_match(x$note, "ORA-22835", fixed = TRUE)
  expect_identical(x$fd_note, x$note)
  expect_length(opened, 1)
  expect_false(DBI::dbIsValid(opened[[1]]))   # closed before its LOBs are released
  expect_true(DBI::dbIsValid(con))
})

test_that("a geometry Oracle cannot write as WKT is read as stored (channel.station)", {
  fl <- fields_of("station", c("station_id", "latitude", "location", "note"),
                  c("NUMBER", "NUMBER", "SDO_GEOMETRY", "VARCHAR2"))
  q <- dbplyr::sql_render(fd$.oracle_query(con, "channel.station", fl, geometry = "parts"))
  expect_match(q, 'FROM "CHANNEL"."STATION" t', fixed = TRUE)
  expect_match(q, "WITHIN GROUP (ORDER BY ROWNUM) FROM TABLE(t.\"LOCATION\".SDO_ORDINATES) e", fixed = TRUE)
  expect_match(q, "'NLS_NUMERIC_CHARACTERS=''.,'''", fixed = TRUE)   # a decimal comma would split the lists

  x <- dump("station", fl)
  expect_equal(x$rows, 4)
  expect_named(x$d, c("station_id", "latitude", paste0("location_", parts), "note"))
  expect_type(x$d$location_gtype, "integer")
  expect_type(x$d$location_srid, "integer")
  for (p in c("x", "y", "z")) expect_type(x$d[[paste0("location_", p)]], "double")
  expect_equal(x$d$location_gtype, c(2001L, 2002L, 2003L, NA))
  expect_equal(x$d$location_srid, c(8307L, 8307L, 8307L, NA))
  expect_equal(x$d$location_x, c(-22.5, NA, NA, NA))
  expect_equal(x$d$location_y, c(64.25, NA, NA, NA))
  expect_equal(x$d$location_z, rep(NA_real_, 4))
  expect_equal(x$d$location_elem_info, c(NA, "1,1003,1", "1,1003,3", NA))
  expect_equal(x$d$location_ordinates, c(NA, "-23.658,64.205,-23.693,64.1745", "-22,64,-21,65", NA))
  expect_equal(x$d$note, c("point", "line", "rectangle", "none"))
  expect_match(x$note, "Oracle cannot write location as WKT (ORA-13199: curve: invalid element type found): read as",
               fixed = TRUE)
  expect_no_match(x$note, "ORA-06512")
  expect_identical(x$fd_note, x$note)
})

test_that("a CLOB fetch that meets a geometry Oracle cannot write goes on to the stored parts", {
  x <- dump("mixed", fields_of("mixed", c("station_id", "location"), c("NUMBER", "SDO_GEOMETRY")), open_standin)
  expect_equal(x$rows, 3000)
  expect_named(x$d, c("station_id", paste0("location_", parts)))
  expect_equal(x$d$location_ordinates[x$d$station_id == 2500], "-23,64,-24,65")
  expect_equal(sum(x$d$location_gtype == 2001L), 2998)
  expect_match(x$note, "^Oracle cannot write location as WKT \\(ORA-13199")
  expect_length(opened, 1)
  expect_false(DBI::dbIsValid(opened[[1]]))
})

DBI::dbDisconnect(con)
duckdb::duckdb_shutdown(drv)
unlink(out, recursive = TRUE)
