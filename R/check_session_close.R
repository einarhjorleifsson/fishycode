# check_session_close.R — does anything a session made hang on the session itself?
#
# Input:  the repo's code; the study folders a session touched under $FISHYDATA/archive/
# Output: one row per check: OK / FAIL, and what is wrong
#
# The maintainer, 2026-10-31: "one of the rule when closing a session properly is to include in the check script
# exactly this". A session's scratchpad, its scratch R library and its /tmp files go when it is archived, and whatever
# reads them can no longer be rerun. That evening plan 058's study session kept its notes in its scratchpad, and the
# scoping study told its reader to set R_LIBS to a scratch library.
#
# Two parts. `temp_paths()` reads the repo's code alone, in base R with no $FISHYDATA, so check_bookkeeping() runs it.
# `check_session_close()` adds the studies: every package their scripts load is in R's library, no README or script
# points into a temporary place or a scratch library, the README names every script, every file it cites exists, and
# no job of theirs is still running. Run it at a session's close, beside check_bookkeeping().

SESSION_TEMP <- "/tmp/|/private/tmp|/var/folders/|scratchpad/"
# The lock that parallel sessions take for heavy jobs: `lockf -k` makes it when needed, so it hangs on no session.
SHARED_LOCK <- "/tmp/fishycode-heavy.lock"

# Lines of the repo's code that point into a temporary place. Hidden and underscore folders at the top (.git, .claude's
# worktrees, _targets) and Quarto's output are not code; the two files that carry the pattern itself are left out.
temp_paths <- function(root = ".") {
  f <- list.files(root, "[.](R|qmd|Rmd|sh|py|js|ya?ml|json)$", recursive = TRUE)
  f <- f[!grepl("^[._]|/(_book|_freeze|[.]quarto|_site|node_modules)/", f)]
  f <- setdiff(f, c("R/check_session_close.R", "tests/test_check_session_close.R"))
  hits <- character(0)
  for (x in f) {
    l <- readLines(file.path(root, x), warn = FALSE)
    i <- grep(SESSION_TEMP, gsub(SHARED_LOCK, "", l, fixed = TRUE))
    if (length(i)) hits <- c(hits, sprintf("%s:%d  %s", x, i, substr(trimws(l[i]), 1, 70)))
  }
  hits
}

# The study folders under $FISHYDATA/archive/ whose README, scripts or notes changed within `days`.
touched_studies <- function(days = 2) {
  arch <- file.path(Sys.getenv("FISHYDATA"), "archive")
  if (!nzchar(Sys.getenv("FISHYDATA")) || !dir.exists(arch)) return(NULL)
  d <- list.dirs(arch, recursive = FALSE)
  d[vapply(d, function(x) {
    f <- c(file.path(x, "README.md"), list.files(file.path(x, c("scripts", "notes")), full.names = TRUE))
    any(difftime(Sys.time(), file.mtime(f), units = "days") < days, na.rm = TRUE)
  }, logical(1))]
}

# The terminal tokens from the `(` at row j of sorted parse data to the `)` that closes it.
paren_tokens <- function(pd, j) {
  d <- 0
  for (k in seq(j, nrow(pd))) {
    d <- d + (pd$token[k] == "'('") - (pd$token[k] == "')'")
    if (d == 0) break
  }
  pd[seq(j, k), ]
}

# The strings a for loop gives its variable v: `for (v in c("a", "b"))` gives "a" and "b".
loop_strings <- function(pd, v) {
  out <- character(0)
  for (j in which(pd$token == "FOR")) {
    if (j + 3 > nrow(pd) || pd$text[j + 2] != v || pd$token[j + 3] != "IN") next
    t <- paren_tokens(pd, j + 1)
    out <- c(out, gsub("^[\"']|[\"']$", "", t$text[t$token == "STR_CONST"]))
  }
  unique(out)
}

# The pids of this R process and of every process above it, read from `ps -o pid=,ppid=,command=` lines.
self_and_parents <- function(ps, pid = Sys.getpid()) {
  pp <- setNames(sub("^\\s*\\d+\\s+(\\d+).*", "\\1", ps), sub("^\\s*(\\d+).*", "\\1", ps))
  out <- character(0)
  p <- as.character(pid)
  while (!is.na(p) && p != "0" && !p %in% out) {
    out <- c(out, p)
    p <- unname(pp[p])
  }
  out
}

check_session_close <- function(studies = touched_studies(), root = ".", quiet = FALSE) {

  res <- list()
  add <- function(name, bad, hint) {
    res[[length(res) + 1]] <<- list(name = name, bad = bad, hint = hint)
  }
  rd <- function(f) if (file.exists(f)) readLines(f, warn = FALSE) else character(0)

  add("no repo code points into a temporary place", temp_paths(root),
      "write it under $FISHYDATA, or make it at run time (tempfile(), git show) inside the script")

  if (is.null(studies)) {
    add("the studies", "SKIPPED - $FISHYDATA not set, and no study given", "pass `studies =` the study folders")
    studies <- character(0)
  }
  pkgs <- temp <- unnamed <- gone <- running <- character(0)
  ps <- tryCatch(system2("ps", c("ax", "-o", "pid=,ppid=,command="), stdout = TRUE, stderr = FALSE),
                 error = function(e) character(0))
  # the check itself and the processes that started it (the shell, Rscript) name the study on their command line too
  ps <- ps[!sub("^\\s*(\\d+).*", "\\1", ps) %in% self_and_parents(ps)]
  for (s in studies) {
    id <- basename(s)
    sc <- list.files(file.path(s, "scripts"), "[.](R|sh|py)$", full.names = TRUE)
    readme <- rd(file.path(s, "README.md"))

    # every package an R script loads, from R's own parser (a regular expression takes SQL's `vid::INT` in a string for
    # a package): pkg:: and pkg:::, and the first argument of library(), require(), requireNamespace(), loadNamespace().
    # A variable there (`library(p, character.only = TRUE)`, `requireNamespace(p)`) is no package: the strings of the
    # for loop that sets it are, and a variable no loop sets is reported (2026-11-07, `run_step.R` of TODO 192's night).
    p <- character(0)
    for (f in sc[grepl("[.]R$", sc)]) {
      pd <- tryCatch(utils::getParseData(parse(f, keep.source = TRUE)), error = function(e) NULL)
      if (is.null(pd)) { p <- c(p, sprintf("(%s does not parse)", basename(f))); next }
      pd <- pd[pd$terminal, ]; pd <- pd[order(pd$line1, pd$col1), ]
      p <- c(p, pd$text[pd$token == "SYMBOL_PACKAGE"])
      for (i in which(pd$token == "SYMBOL_FUNCTION_CALL" &
                      pd$text %in% c("library", "require", "requireNamespace", "loadNamespace"))) {
        a <- pd[seq(i + 1, length.out = min(3, nrow(pd) - i)), ]
        a <- a[a$token %in% c("SYMBOL", "STR_CONST"), ]
        if (!nrow(a)) next
        arg <- paren_tokens(pd, i + 1)
        by_name <- pd$text[i] %in% c("requireNamespace", "loadNamespace") ||
          "character.only" %in% arg$text[arg$token == "SYMBOL_SUB"]
        if (a$token[1] == "SYMBOL" && by_name) {
          v <- loop_strings(pd, a$text[1])
          p <- c(p, if (length(v)) v else sprintf("(%s loads a package by the variable %s)", basename(f), a$text[1]))
        } else p <- c(p, gsub("^[\"']|[\"']$", "", a$text[1]))
      }
    }
    p <- unique(p)
    miss <- p[startsWith(p, "(") | !nzchar(vapply(p, function(x) c(find.package(x, quiet = TRUE), "")[1], ""))]
    if (length(miss)) pkgs <- c(pkgs, sprintf("%s: %s", id, paste(miss, collapse = ", ")))

    # a README or script that points into a temporary place, or wants a scratch library on R_LIBS
    for (f in c(file.path(s, "README.md"), sc)) {
      l <- rd(f); i <- grep(paste0(SESSION_TEMP, "|R_LIBS"), gsub(SHARED_LOCK, "", l, fixed = TRUE))
      if (length(i)) temp <- c(temp, sprintf("%s/%s:%d  %s", id, basename(f), i, substr(trimws(l[i]), 1, 60)))
    }

    # the README names every script, and every file it cites under the study exists
    txt <- paste(readme, collapse = "\n")
    nm <- basename(sc)[!vapply(sub("[.][A-Za-z]+$", "", basename(sc)), grepl, logical(1), x = txt, fixed = TRUE)]
    if (length(nm)) unnamed <- c(unnamed, sprintf("%s: %s", id, paste(nm, collapse = ", ")))
    cited <- unique(unlist(regmatches(txt, gregexpr(
      "(scripts|results|figures|report|notes)/[A-Za-z0-9_./-]*[A-Za-z0-9_-][.][A-Za-z0-9]+", txt))))
    cited <- cited[!file.exists(file.path(s, cited)) & !grepl("NN|XX|YYYY", basename(cited))]   # a placeholder, not a file
    if (length(cited)) gone <- c(gone, sprintf("%s: %s", id, cited))

    # a job still running from the study
    r <- ps[grepl(s, ps, fixed = TRUE)]
    if (length(r)) running <- c(running, sprintf("%s: %s", id, substr(sub("^\\s*(\\d+)\\s+\\d+", "\\1", r), 1, 70)))
  }
  if (length(studies)) {
    add("every package a study's scripts load is in R's library", pkgs,
        "install it in R's library, not a scratch R_LIBS, and say so in the study's README")
    add("no study README or script points into a temporary place", temp,
        "move the file into the study (notes/, scripts/), or drop the scratch library")
    add("every study script is named in its README", unnamed, "name it where its result is described")
    add("every file a study's README cites exists", gone, "rerun the script that writes it, or fix the citation")
    add("no job of a study is still running", running, "wait for it, or stop it and say so in the README")
  }

  if (!quiet) {
    cat(sprintf("studies: %s\n", if (length(studies)) paste(basename(studies), collapse = ", ") else "none"))
    cat(sprintf("%-52s %s\n", "check", "status"))
    cat(strrep("-", 74), "\n")
    for (r in res) {
      cat(sprintf("%-52s %s\n", r$name, if (!length(r$bad)) "OK" else sprintf("FAIL (%d)", length(r$bad))))
      for (b in r$bad) cat("      ", b, "\n")
      if (length(r$bad)) cat("      -> ", r$hint, "\n")
    }
    cat(strrep("-", 74), "\n")
  }
  failed <- vapply(Filter(function(r) length(r$bad) > 0, res), `[[`, "", "name")
  if (!quiet) cat(if (length(failed)) sprintf("%d check(s) FAILED\n", length(failed)) else "nothing hangs on the session\n")
  invisible(structure(!length(failed), failed = failed))
}
