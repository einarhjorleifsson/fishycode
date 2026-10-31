# test_release.R — publish_release(), compare_release() and check_no_persons() on a made-up candidate (plan 056).
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_release.R")'
#
# The candidate is a few rows written by DuckDB, one table a link into a made-up curated/, as v0 links its own.
# publish_release() runs with check = FALSE (no git, targets or check table), meta = FALSE (no data-dict tool) and
# render = FALSE (no Quarto), and with its own repository folder, so the repo's releases.md is never touched.

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)

tmp <- tempfile("release_test_")
dir.create(tmp)
con <- DBI::dbConnect(duckdb::duckdb())
withr::defer({ DBI::dbDisconnect(con, shutdown = TRUE); system2("chmod", c("-R", "u+w", shQuote(tmp)))
               unlink(tmp, recursive = TRUE) })
write <- function(sql, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  DBI::dbExecute(con, sprintf("COPY (%s) TO '%s' (FORMAT parquet)", sql, path))
}
trips <- function(ids, n) sprintf("SELECT * FROM (VALUES %s) t(\".tid\", schema, n_crew)",
                                  paste(sprintf("('%s', 'afli', %d)", ids, n), collapse = ", "))
candidate <- function(dir, ids, n) {
  write(trips(ids, n), file.path(dir, "logbook", "trip.parquet"))
  # A table taken as it is: a link into curated/, which a release must copy as a file.
  write("SELECT 1 AS vid, 'Sæbjörg' AS vessel", file.path(dir, "curated", "vessel.parquet"))
  dir.create(file.path(dir, "vessel"))
  file.symlink(file.path(dir, "curated", "vessel.parquet"), file.path(dir, "vessel", "vessel.parquet"))
  dir
}
repository <- file.path(tmp, "repository")
dir.create(repository)
file.copy(file.path(root, "products", "repository", c("meta.yml", "releases.md")), repository)
published <- file.path(tmp, "published")
publish <- function(id, cand, ...) suppressMessages(
  fd$publish_release(id, candidate = cand, root = published, folders = c("logbook", "vessel"),
                     repository = repository, check = FALSE, meta = FALSE, render = FALSE, ...))

testthat::test_that("a release copies a linked table as a file, with its md5 in the manifest", {
  dest <- publish("2026.10.31.1", candidate(file.path(tmp, "a"), c("1", "2", "3"), 4L))
  f <- file.path(dest, "vessel", "vessel.parquet")
  testthat::expect_true(file.exists(f))
  testthat::expect_identical(Sys.readlink(f), "")
  m <- yaml::read_yaml(file.path(dest, "manifest.yml"))
  v <- Filter(\(x) x$path == "vessel/vessel.parquet", m$files)[[1]]
  testthat::expect_identical(v$md5, unname(tools::md5sum(f)))
  testthat::expect_identical(m$schema_version, "1.0")
  testthat::expect_null(m$previous)
  testthat::expect_identical(readLines(file.path(published, "LATEST")), "2026.10.31.1")
  testthat::expect_match(readLines(file.path(dest, "CHANGES.md"))[3], "first release")
})

testthat::test_that("a release is never written twice", {
  testthat::expect_error(publish("2026.10.31.1", file.path(tmp, "a")), "never rewritten")
})

testthat::test_that("the next release's changes are counted by key, and the index moves on", {
  dest <- publish("2026.11.01.1", candidate(file.path(tmp, "b"), c("2", "3", "4"), c(4L, 5L, 4L)))
  ch <- readLines(file.path(dest, "CHANGES.md"))
  testthat::expect_true(any(grepl("`logbook/trip` \\| 1 rows added; 1 removed; 1 changed", ch)))
  testthat::expect_false(any(grepl("`vessel/vessel`", ch)))
  idx <- readLines(file.path(repository, "releases.md"))
  testthat::expect_length(grep("\\| current \\|", idx), 1)
  testthat::expect_match(grep("2026.10.31.1", idx, value = TRUE), "superseded")
  testthat::expect_identical(yaml::read_yaml(file.path(dest, "manifest.yml"))$previous, "2026.10.31.1")
})

testthat::test_that("a person's column stops the release", {
  write("SELECT 1 AS vid, '0101010101' AS kennitala", file.path(tmp, "p", "vessel", "owner.parquet"))
  testthat::expect_error(fd$check_no_persons(file.path(tmp, "p")), "kennitala")
  testthat::expect_true(fd$check_no_persons(file.path(tmp, "a", "logbook")))
})
