# test_data_dict.R — the raw dictionaries: the writer's fixes, the overlay's merge, the rewrite and the adoption check.
#
# Input:  the functions in R/; no data, no $FISHYDATA, no Oracle
# Output: nothing kept: the dump it makes goes to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_data_dict.R")'
#
# A dump folder is made by hand, as dump_oracle_schema() leaves one: parquet files written by .write_raw(), a table by
# year, and the two overviews. The cases are the faults plan 040 measured on the dumps of 2026-10-22: a datetime range
# without T and Z (S12), text examples YAML 1.2 reads as numbers (S12), columns with no value or none in the first
# 10,000 rows (S07), an overview row whose file is gone (stk), and codes R's yaml reads as booleans (lods' veidisvaedi).
# The data-dict checks are skipped where the tool is not installed (datadict::dd_install()).

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)
Sys.setenv(TZ = "UTC")

dir <- file.path(tempfile("data_dict_"), "toy")
run <- list(dumped = "2026-10-22T00:00:00+0000", driver = "RJDBC", script = "tests/test_data_dict.R",
            commit = "0000000000", dirty = "false")
n <- 10005
landing <- data.frame(
  id = seq_len(n),
  t = as.POSIXct("2003-06-18 00:00:00", tz = "UTC") + c(0, 3600 * seq_len(n - 1)),
  area = rep(c("I", "Y", "N"), length.out = n),
  rect = rep(c("62E5", "58C2", "1e5"), length.out = n),
  kg = c(NaN, seq_len(n - 1) * 1.5),
  late = c(rep(NA, 10002), 9, 7, 8),                 # out of order: the examples come sorted
  empty = NA_character_, empty_id = NA_real_,
  lon = c(rep(1, 5), seq(6, n)), lat = c(rep(1, 5), seq(6, n) + 1))
fd$.write_raw(landing, file.path(dir, "landing.parquet"), "toy.landing", run)
for (y in 2001:2002)
  fd$.write_raw(data.frame(id = 1:3, io = c("I", "U", if (y == 2001) "X" else NA)),
                file.path(dir, "trail", paste0("year=", y), "data_0.parquet"), "toy.trail", run)
objects <- data.frame(owner = "toy", name = c("landing", "trail", "gone"), type = "table",
                      comments = c("Landings.", NA, "A table the overview keeps."), status = "written",
                      partitioned = c(FALSE, TRUE, FALSE), note = NA_character_)
fields <- data.frame(owner = "toy", table = "landing", column = names(landing), oracle_column = toupper(names(landing)),
                     column_id = seq_along(landing), data_type = c("NUMBER", "DATE", "VARCHAR2", "VARCHAR2", "NUMBER",
                                                                   "NUMBER", "VARCHAR2", "NUMBER", "NUMBER", "NUMBER"),
                     data_precision = c(9, NA, NA, NA, NA, 3, NA, 5, NA, NA),
                     data_scale = c(0, NA, NA, NA, NA, 0, NA, 0, NA, NA),
                     nullable = "Y", comments = c("Id.", "Landing time.", "Area.", "Rectangle.", "Kg.", NA, "Never used.",
                                                  "Never used either.", NA, NA))
fd$.write_raw(objects, file.path(dir, "_overview_tables.parquet"), "toy objects", run)
fd$.write_raw(fields, file.path(dir, "_overview_fields.parquet"), "toy columns", run)

overlay <- file.path(dirname(dir), "toy.yml")
writeLines(c(
  "$version: 0.1.0",
  "name: toy",
  "tables:",
  "  - name: landing",
  "    details: What this layer says.",
  "    definitions:",
  "      - name: kg_t",
  "        expr: kg / 1000",
  "    constraints:",
  "      - assert: lon <> lat",
  "        description: Placeholders. Expected false on 5 rows (made by the test).",
  "    columns:",
  "      - name: area",
  "        type: enum",
  "        values: {I: inside, Y: Russian zone, N: northern area}",
  "      - name: kg",
  "        type: number(quantity)",
  "        units: kg",
  "        constraints:",
  "          - assert: IS_NAN(kg) OR kg >= 0",
  "      - name: t",
  "        time_zone: UTC",
  "      - name: empty",
  "        type: number(quantity)",
  "        units: kg",
  "      - name: empty_id",
  "        type: number(id)",
  "      - name: nowhere",
  "        label: Not in the dump",
  "  - name: trail",
  "    columns:",
  "      - name: io",
  "        type: enum",
  "        values: {'I': into port, 'U': out of port}"), overlay)

col <- function(dd, table, column) {
  t <- dd$tables[[match(table, vapply(dd$tables, `[[`, "", "name"))]]
  t$columns[[match(column, vapply(t$columns, `[[`, "", "name"))]]
}

testthat::test_that("a date-time is ISO 8601 with Z, its fraction kept, midnight included", {
  x <- as.POSIXct(c("2003-06-18 00:00:00", "2003-06-18 17:56:20.5", NA), tz = "UTC")
  testthat::expect_equal(fd$.dd_datetime(x), c("2003-06-18T00:00:00Z", "2003-06-18T17:56:20.5Z", NA))
})

testthat::test_that("the writer's S12 and S07 faults are gone, without an overlay", {
  s <- fd$.write_data_dict(dir, "toy", objects, fields, run, overlay = NULL)
  y <- readLines(file.path(dir, "_data-dict.yaml"))
  dd <- fd$.dd_read_yaml(file.path(dir, "_data-dict.yaml"))
  testthat::expect_equal(unlist(col(dd, "landing", "t")$range), fd$.dd_datetime(range(landing$t)))
  testthat::expect_true(any(grepl('^ *- "62E5"$', y)))        # quoted, so YAML 1.2 reads text
  testthat::expect_true(any(grepl('^ *- "1e5"$', y)))
  e <- col(dd, "landing", "empty")
  testthat::expect_null(e$type)
  testthat::expect_match(e$details, "Oracle declares VARCHAR2")
  testthat::expect_match(e$todo, "No value in this dump")
  testthat::expect_equal(unlist(col(dd, "landing", "late")$examples), 7:9)   # past the first 10,000 rows, in order
  testthat::expect_false(any(is.nan(unlist(col(dd, "landing", "kg")$range))))
  testthat::expect_false("gone" %in% vapply(dd$tables, `[[`, "", "name"))
  testthat::expect_match(dd$todo, "not on disk, so left out: gone")
  testthat::expect_equal(dd$tables[[2]]$source$parquet, "trail/*/*.parquet")
  testthat::expect_equal(s$values[s$column == "late"], 3)
  testthat::expect_false(s$in_head[s$column == "late"])
})

testthat::test_that("the overlay wins on what it sets, and what the dump lacks goes to the todo", {
  fd$.write_data_dict(dir, "toy", objects, fields, run, overlay = overlay)
  dd <- fd$.dd_read_yaml(file.path(dir, "_data-dict.yaml"))
  a <- col(dd, "landing", "area")
  testthat::expect_equal(a$type, "enum")
  testthat::expect_equal(unlist(a$values), c(I = "inside", Y = "Russian zone", N = "northern area"))
  testthat::expect_null(a$examples)
  testthat::expect_equal(a$description, "Area.")                 # Oracle's comment stays
  k <- col(dd, "landing", "kg")
  testthat::expect_equal(c(k$type, k$units), c("number(quantity)", "kg"))
  testthat::expect_equal(unlist(col(dd, "landing", "t")$range), sub("Z$", "", fd$.dd_datetime(range(landing$t))))
  e <- col(dd, "landing", "empty")
  testthat::expect_equal(c(e$type, e$units), c("number(quantity)", "kg"))   # an ordered type: an open range
  testthat::expect_equal(unlist(e$range), c(-Inf, Inf))
  testthat::expect_match(e$todo, "No value in this dump")
  e <- col(dd, "landing", "empty_id")
  testthat::expect_null(e$type)                                    # needs examples it cannot have: typed in the todo
  testthat::expect_match(e$details, "Oracle declares NUMBER\\(5,0\\)")
  testthat::expect_match(e$todo, "The overlay types it number\\(id\\)")
  testthat::expect_match(dd$todo, "landing.nowhere")
  testthat::expect_equal(dd$tables[[1]]$definitions[[1]]$name, "kg_t")
})

testthat::test_that("a faulty overlay costs the dictionary nothing but the overlay", {
  bad <- tempfile(fileext = ".yml")
  writeLines(c("$version: 0.1.0", "name: toy", "tables:", "  - name: landing", "    columns:", "      - name: area",
               "        type: enum", "        values: {I: 1}"), bad)
  fd$.write_data_dict(dir, "toy", objects, fields, run, overlay = bad)
  dd <- fd$.dd_read_yaml(file.path(dir, "_data-dict.yaml"))
  testthat::expect_match(dd$todo, "could not be laid over")
  testthat::expect_equal(col(dd, "landing", "area")$type, "string")
})

testthat::test_that("rewrite_data_dict() rebuilds the dictionary from the dump's own files and stamps", {
  fd$rewrite_data_dict(dir, overlay = overlay)
  dd <- fd$.dd_read_yaml(file.path(dir, "_data-dict.yaml"))
  testthat::expect_match(dd$description, "2026-10-22T00:00:00\\+0000 \\(tests/test_data_dict.R, commit 0000000\\)")
  testthat::expect_match(dd$details, "Rewritten from the dump's files")
  testthat::expect_equal(col(dd, "landing", "area")$type, "enum")
})

bin <- tryCatch(fd$.dd_bin(), error = function(e) "")

testthat::test_that("the merged dictionary validates, and the adoption check counts each assertion", {
  testthat::skip_if_not(nzchar(bin), "no data-dict binary")
  fd$rewrite_data_dict(dir, overlay = overlay)
  r <- suppressMessages(fd$check_data_dict(dir, bin = bin))
  sp <- attr(r, "spec")
  testthat::expect_equal(sum(sp$severity == "error"), 0)
  a <- r[r$assertion == "lon <> lat", ]
  testthat::expect_equal(c(a$rows, a$failed, a$expected), c(n, 5, 5))
  testthat::expect_false(a$news)
  testthat::expect_false(r$news[r$assertion == "IS_NAN(kg) OR kg >= 0"])
  io <- r[r$table == "trail" & r$code == "D04", ]
  testthat::expect_equal(c(io$rows, io$failed), c(6, 1))           # both year files, summed
  testthat::expect_true(io$news)                                   # X is outside the enum
  testthat::expect_equal(nrow(attr(r, "files")[attr(r, "files")$table == "trail" & attr(r, "files")$code == "D04", ]), 2)
})
