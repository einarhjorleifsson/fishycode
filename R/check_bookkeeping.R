# check_bookkeeping.R — is the written record still internally consistent?
#
# Input:  TODO.md, curate/decisions/, curate/plans/, curate/corrections/, AGENTS.md
# Output: one row per invariant: OK / FAIL, and what is wrong
#
# The bookkeeping conventions are instructions, and instructions drift — the repo's
# own rule is to prefer enforcement (000-restructuring.md, "Skills"). This is that
# enforcement: every rule the three README files assert, expressed as something that
# fails. Run it at the end of a session, before committing.
#
# Deliberately cheap: pure base R, no packages, no $FISHYDATA, so it runs anywhere
# and cannot be the reason a session stalls.

check_bookkeeping <- function(root = ".", quiet = FALSE) {

  res <- list()
  add <- function(name, bad, hint) {
    res[[length(res) + 1]] <<- list(name = name, bad = bad, hint = hint)
  }
  p  <- function(...) file.path(root, ...)
  rd <- function(f) if (file.exists(f)) readLines(f, warn = FALSE) else character(0)

  # -- 1/6 every numbered record is indexed in its own README -------------------
  for (slot in c("decisions", "plans")) {
    dir <- p("curate", slot)
    if (!dir.exists(dir)) next
    files <- setdiff(list.files(dir, "^[0-9]{3}-.*[.](md|tsv)$"), "README.md")
    idx   <- rd(file.path(dir, "README.md"))
    linked <- regmatches(idx, gregexpr("\\(([0-9]{3}-[^)]+)\\)", idx))
    linked <- gsub("^\\(|\\)$", "", unlist(linked))
    add(sprintf("every curate/%s/ record has a README row", slot),
        setdiff(files, linked),
        "add a row to that README, or delete the orphan file")
  }

  # -- 2/6 ... and every README row points at a file that exists ----------------
  for (slot in c("decisions", "plans")) {
    dir <- p("curate", slot)
    if (!dir.exists(dir)) next
    idx <- rd(file.path(dir, "README.md"))
    linked <- regmatches(idx, gregexpr("\\(([0-9]{3}-[^)]+)\\)", idx))
    linked <- gsub("^\\(|\\)$", "", unlist(linked))
    add(sprintf("every curate/%s/ README row resolves", slot),
        linked[!file.exists(file.path(dir, linked))],
        "the index names a file that is not there — renamed, or never written")
  }

  # -- 3/6 TODO.md holds only what is NOT done ---------------------------------
  # The convention: a finished item is deleted from TODO.md and recorded in
  # curate/decisions/. An item left behind wearing a done marker is the drift.
  todo <- rd(p("TODO.md"))
  hits <- grep("^\\*\\*status:\\*\\*[[:space:]]*(done|closed|complete)", todo,
               ignore.case = TRUE)
  add("TODO.md holds no finished item",
      if (length(hits)) sprintf("TODO.md:%d  %s", hits, substr(todo[hits], 1, 60)),
      "move it to curate/decisions/ and delete the item")

  # -- 4/6 corrections: paired, and each .yml declares the required fields ------
  cdir <- p("curate", "corrections")
  ymls <- list.files(cdir, "[.]yml$")
  rs   <- list.files(cdir, "[.]R$")
  add("every corrections/*.R has a .yml declaration",
      setdiff(sub("[.]R$", "", rs), sub("[.]yml$", "", ymls)),
      "an implementation with no declaration — write the .yml")
  missing <- character(0)
  for (y in ymls) {
    txt <- rd(file.path(cdir, y))
    need <- c("id", "title", "status")
    absent <- need[!vapply(need, function(k)
      any(grepl(sprintf("^%s:", k), txt)), logical(1))]
    if (length(absent))
      missing <- c(missing, sprintf("%s (no %s)", y, paste(absent, collapse = ", ")))
  }
  add("every corrections/*.yml declares id, title, status", missing,
      "the corrections registry is its own index; those three fields are what index it")

  # -- 5/6 AGENTS.md names no path that does not exist --------------------------
  # AGENTS.md is the only file guaranteed to reach a session, so a stale path in it
  # is worse than a stale path anywhere else.
  ag   <- rd(p("AGENTS.md"))
  cand <- unlist(regmatches(ag, gregexpr("`[A-Za-z_][A-Za-z0-9_./-]*`", ag)))
  cand <- gsub("`", "", cand)
  tops <- list.dirs(root, recursive = FALSE, full.names = FALSE)
  tops <- tops[!grepl("^[._]", tops)]
  cand <- unique(cand[!grepl("^[$~]|^/", cand)])
  # rooted in a real top-level directory of THIS repo, or a bare filename
  cand <- cand[grepl(sprintf("^(%s)/", paste(tops, collapse = "|")), cand) |
               (!grepl("/", cand) & grepl("[.](md|R|Rproj)$", cand))]
  cand <- cand[grepl("[.](R|md|qmd|yml|tsv|Rproj)$", cand)]

  # AGENTS.md names some files that are GONE ON PURPOSE, in prose explaining why.
  # Listing them here keeps the invariant strict: a genuinely stale path still fails.
  historical <- c(
    "R/oracle.R",                   # moved to dump/; cited as why R/ is definitions only
    "stk-mid_vessel-vid_match.R")   # old tree's bad naming, cited as a counter-example
  cand <- setdiff(cand, historical)

  # a bare filename resolves if it exists anywhere in the repo
  bare <- cand[!grepl("/", cand)]
  found <- basename(list.files(root, recursive = TRUE, pattern = "[.][A-Za-z]+$"))
  cand <- c(cand[grepl("/", cand)], setdiff(bare, found))
  add("every repo path named in AGENTS.md exists",
      cand[!file.exists(p(cand))],
      "AGENTS.md must not drift; fix the path or the file")

  # -- 6/6 the decisions index is where TODO says finished work goes ------------
  add("curate/decisions/README.md states the revision convention",
      if (!any(grepl("amend it in place", rd(p("curate/decisions/README.md")))))
        "README.md" else character(0),
      "the rule for a record that turns out wrong is missing from its index")

  # -- report ------------------------------------------------------------------
  if (!quiet) {
    cat(sprintf("%-52s %s\n", "invariant", "status"))
    cat(strrep("-", 74), "\n")
    for (r in res) {
      cat(sprintf("%-52s %s\n", r$name,
                  if (!length(r$bad)) "OK" else sprintf("FAIL (%d)", length(r$bad))))
      for (b in r$bad) cat("      ", b, "\n")
      if (length(r$bad)) cat("      -> ", r$hint, "\n")
    }
    n <- sum(vapply(res, function(r) length(r$bad) > 0, logical(1)))
    cat(strrep("-", 74), "\n")
    cat(if (n) sprintf("%d invariant(s) FAILED\n", n) else "all invariants hold\n")
  }

  invisible(!any(vapply(res, function(r) length(r$bad) > 0, logical(1))))
}
