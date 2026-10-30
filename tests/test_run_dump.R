# test_run_dump.R — .dump_finished(): when --resume may skip a schema, against the script's skips of today.
#
# Input:  the functions in R/, and dump/oracle/*.R read as text; no data, no $FISHYDATA, no Oracle
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_run_dump.R")'
#
# TODO 110: --resume skipped orri, uv and fs_afli although decision 159 had taken tables off their skip lists, since an
# overview counted a deliberate skip as finished. A schema whose overview lists as skipped an object its script no
# longer skips is unfinished, and is dumped again; resume then keeps every file already written (.dump_kept()).

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)

# A finished run of schema `demo`: its log with exit 0, its overview, and a script with the given call's arguments.
standin <- function(script_args, objects) {
  tmp <- tempfile("dump_"); dir.create(tmp)
  code <- file.path(tmp, "repo", "dump", "oracle"); dir.create(code, recursive = TRUE)
  writeLines(c("con <- dump_connect()",
               sprintf('dump_oracle_schema(con, "demo", fd_raw("oracle", "demo")%s)', script_args)),
             file.path(code, "demo.R"))
  logs <- file.path(tmp, "raw", "demo", "_logs"); dir.create(logs, recursive = TRUE)
  log <- file.path(logs, "20261030T120000_demo.log")
  writeLines("done", log); writeLines("0", paste0(log, ".exit"))
  writeLines(c("12345", log), file.path(logs, "current"))
  nanoparquet::write_parquet(objects, file.path(tmp, "raw", "demo", "_overview_tables.parquet"))
  list(root = file.path(tmp, "repo"), log_root = file.path(tmp, "raw"))
}
overview <- function(skipped, driver = "RJDBC")
  data.frame(name = c("t1", skipped), status = c("written", rep("skipped", length(skipped))), driver = driver)

testthat::test_that("a schema whose skips are all still the script's is finished", {
  x <- standin(', skip = c("a_v", "b_v"), skip_rjdbc = "lob_t"', overview(c("a_v", "lob_t")))
  testthat::expect_true(fd$.dump_finished("demo", x$log_root, "RJDBC", x$root))
})

testthat::test_that("an object taken off the skip list leaves the schema unfinished", {
  x <- standin(', skip_rjdbc = "lob_t"', overview(c("a_v", "lob_t")))
  testthat::expect_false(fd$.dump_finished("demo", x$log_root, "RJDBC", x$root))
})

testthat::test_that("a skip_rjdbc object skipped is unfinished through another driver, which dumps it", {
  x <- standin(', skip = "a_v", skip_rjdbc = "lob_t"', overview(c("a_v", "lob_t"), driver = "ROracle"))
  testthat::expect_false(fd$.dump_finished("demo", x$log_root, "ROracle", x$root))
  testthat::expect_identical(fd$.dump_script_skips("demo", "ROracle", x$root), "a_v")
  testthat::expect_identical(fd$.dump_script_skips("demo", "RJDBC", x$root), c("a_v", "lob_t"))
})

testthat::test_that("a script with no skips and an overview with none is finished", {
  x <- standin("", overview(character()))
  testthat::expect_true(fd$.dump_finished("demo", x$log_root, "RJDBC", x$root))
})

testthat::test_that("a skip that is not a constant leaves the schema unfinished", {
  x <- standin(", skip = my_skips", overview("a_v"))
  testthat::expect_null(fd$.dump_script_skips("demo", "RJDBC", x$root))
  testthat::expect_false(fd$.dump_finished("demo", x$log_root, "RJDBC", x$root))
})

testthat::test_that("every dump script's skips can be read, so --resume can skip a finished schema", {
  for (s in fd$.dump_schemas(root)) {
    testthat::expect_false(is.null(fd$.dump_script_skips(s, "RJDBC", root)), info = s)
    testthat::expect_false(is.null(fd$.dump_script_skips(s, "ROracle", root)), info = s)
  }
})
