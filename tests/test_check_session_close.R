# test_check_session_close.R — check_session_close() and temp_paths() on a made-up repo and two made-up studies.
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept: the files go to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_check_session_close.R")'

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
sys.source(file.path(root, "R", "check_session_close.R"), envir = fd)

tmp <- tempfile("session_close_test_")
dir.create(tmp)
withr::defer(unlink(tmp, recursive = TRUE))
put <- function(path, ...) { dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE); writeLines(c(...), path) }

# a repo with one script reading a temporary file, and one hidden folder (a worktree) that is not looked at
repo <- file.path(tmp, "repo")
put(file.path(repo, "R", "ok.R"), "f <- function() tempfile()")
put(file.path(repo, "curate", "bad.R"), "x <- readLines('/tmp/before.R')")
put(file.path(repo, ".claude", "worktrees", "w", "curate", "bad.R"), "x <- readLines('/tmp/before.R')")
put(file.path(repo, "docs", "_book", "page.js"), "var a = '/tmp/x';")

# a clean study: a package that is installed, every script named, every cited file there
good <- file.path(tmp, "archive", "good")
put(file.path(good, "scripts", "01_data.R"), "suppressMessages(library(stats))", "x <- utils::head(1:3)  # notapkg::f in a comment")
put(file.path(good, "results", "a.csv"), "x")
put(file.path(good, "README.md"), "# Good", "`scripts/01_data.R` writes `results/a.csv`; `figures/x_<gear>.png` is a pattern.")

# a study that hangs on its session
bad <- file.path(tmp, "archive", "bad")
put(file.path(bad, "scripts", "01_data.R"), "library(notapkg123)", "y <- otherpkg456::f()", "z <- read.csv('/private/tmp/x.csv')")
put(file.path(bad, "scripts", "02_more.R"), "1")
put(file.path(bad, "README.md"), "# Bad", "`scripts/01_data.R` writes `results/missing.csv`.",
    "Run with R_LIBS set to a scratch library.")

testthat::test_that("temp_paths() finds a temporary path in the repo's code, not in hidden or output folders", {
  hits <- fd$temp_paths(repo)
  testthat::expect_length(hits, 1)
  testthat::expect_match(hits, "^curate/bad[.]R:1")
})

testthat::test_that("a clean study passes", {
  ok <- fd$check_session_close(studies = good, root = file.path(tmp, "repo", "R"), quiet = TRUE)
  testthat::expect_true(ok)
})

testthat::test_that("a study that hangs on its session fails each check it breaks", {
  ok <- fd$check_session_close(studies = c(good, bad), root = repo, quiet = TRUE)
  testthat::expect_false(ok)
  testthat::expect_setequal(attr(ok, "failed"), c(
    "no repo code points into a temporary place",
    "every package a study's scripts load is in R's library",
    "no study README or script points into a temporary place",
    "every study script is named in its README",
    "every file a study's README cites exists"))
})

testthat::test_that("no study and no $FISHYDATA is reported, not passed", {
  ok <- fd$check_session_close(studies = NULL, root = file.path(tmp, "repo", "R"), quiet = TRUE)
  testthat::expect_false(ok)
  testthat::expect_equal(attr(ok, "failed"), "the studies")
})

testthat::test_that("a SQL cast in a string is not a package, and a script that does not parse is reported", {
  s <- file.path(tmp, "archive", "sql")
  put(file.path(s, "scripts", "01_q.R"), "q <- 'SELECT vid::INT, NULL::VARCHAR FROM t'", "x <- stats::median(1)")
  put(file.path(s, "scripts", "02_broken.R"), "f <- function( {")
  put(file.path(s, "README.md"), "`scripts/01_q.R` and `scripts/02_broken.R`; `scripts/NN_name.R` is a placeholder.")
  ok <- fd$check_session_close(studies = s, root = file.path(tmp, "repo", "R"), quiet = TRUE)
  testthat::expect_equal(attr(ok, "failed"), "every package a study's scripts load is in R's library")
})
