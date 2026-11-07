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
put(file.path(good, "README.md"), "# Good", "`scripts/01_data.R` writes `results/a.csv`; `figures/x_<gear>.png` is a pattern.",
    "Heavy runs take the shared lock: `lockf -k /tmp/fishycode-heavy.lock Rscript scripts/01_data.R`.")

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

testthat::test_that("a package loaded by a variable is read from the loop that sets it, not taken as a package", {
  # the false positive of 2026-11-07: `library(p, character.only = TRUE)` read as a package named p
  s <- file.path(tmp, "archive", "loop")
  put(file.path(s, "scripts", "01_load.R"),
      "for (p in c('stats', 'utils')) suppressMessages(library(p, character.only = TRUE))",
      "for (q in c(\"tools\")) requireNamespace(q)")
  put(file.path(s, "README.md"), "`scripts/01_load.R`")
  ok <- fd$check_session_close(studies = s, root = file.path(tmp, "repo", "R"), quiet = TRUE)
  testthat::expect_true(ok)

  b <- file.path(tmp, "archive", "loop_bad")
  put(file.path(b, "scripts", "01_load.R"),
      "for (p in c('stats', 'notapkg789')) library(p, character.only = TRUE)",
      "library(x, character.only = TRUE)")
  put(file.path(b, "README.md"), "`scripts/01_load.R`")
  out <- capture.output(ok <- fd$check_session_close(studies = b, root = file.path(tmp, "repo", "R")))
  testthat::expect_equal(attr(ok, "failed"), "every package a study's scripts load is in R's library")
  line <- grep("loop_bad:", out, value = TRUE)
  testthat::expect_match(line, "notapkg789, [(]01_load.R loads a package by the variable x[)]")
  testthat::expect_no_match(line, "\\bp\\b")
})

testthat::test_that("the check and the shell that started it are not a running job; a job of the study is", {
  testthat::skip_on_os("windows")
  # the false positive of 2026-11-05: the shell running the check names the study on its command line
  rs <- file.path(R.home("bin"), "Rscript")
  code <- sprintf("source('%s'); ok <- check_session_close(studies = '%s', root = '%s', quiet = TRUE); cat(ok)",
                  file.path(root, "R", "check_session_close.R"), good, file.path(tmp, "repo", "R"))
  out <- system2("sh", c("-c", shQuote(sprintf("%s -e %s; : %s", rs, shQuote(code), good))), stdout = TRUE)
  testthat::expect_equal(out, "TRUE")

  # a job still running from the study is caught
  system2("sh", c("-c", shQuote(sprintf("sleep 20; : %s", good))), wait = FALSE)
  Sys.sleep(0.5)
  ps <- system2("ps", c("ax", "-o", "pid=,ppid=,command="), stdout = TRUE)
  job <- sub("^\\s*(\\d+).*", "\\1", ps[grepl(good, ps, fixed = TRUE)])
  kids <- sub("^\\s*(\\d+).*", "\\1", ps[sub("^\\s*\\d+\\s+(\\d+).*", "\\1", ps) %in% job])
  withr::defer(tools::pskill(as.integer(c(job, kids))))
  ok <- fd$check_session_close(studies = good, root = file.path(tmp, "repo", "R"), quiet = TRUE)
  testthat::expect_equal(attr(ok, "failed"), "no job of a study is still running")
})
