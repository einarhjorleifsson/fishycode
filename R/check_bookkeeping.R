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

  # -- 3b/6 TODO.md uses only the status vocabulary it declares -----------------
  stat <- grep("^\\*\\*status:\\*\\*", todo, value = TRUE)
  word <- tolower(trimws(sub("^\\*\\*status:\\*\\*[[:space:]]*([A-Za-z ]+).*$", "\\1", stat)))
  word <- sub("[[:space:]].*$", "", word)
  add("TODO.md uses only its declared statuses",
      setdiff(unique(word), c("open", "blocked", "parked", "in", "done")),
      "either use a declared status or amend the vocabulary in TODO.md's header")

  # -- 2b/6 TODO.md is a list of stubs, not a filing cabinet --------------------
  # Added 2026-09-23, at 871 lines. TODO.md's own header says "Not a diary" and
  # plans/README.md says an item needing sections and evidence IS a plan, with a
  # one-line stub here. Neither was enforced and both were ignored: four "Resume
  # note" sections held 211 lines of session diary, and seven items restated a plan
  # or correction that already said it better. Compressed to 377. These three
  # invariants are the only reason it will stay there.
  heads <- grep("^##[[:space:]]", todo)
  ends  <- c(heads[-1] - 1L, length(todo))
  titles <- sub("^##[[:space:]]+", "", todo[heads])

  add("TODO.md holds no session diary",
      titles[grepl("^resume note", tolower(titles))],
      "session state belongs in the git log - delete it")

  long <- sprintf("%s (%d lines)", titles, ends - heads)[(ends - heads) > 35L]
  add("no TODO.md item runs past 35 lines", long,
      "it is a plan or a correction - move the evidence there and leave the pointer")

  # An item with no check cannot be audited, only believed, which is the failure
  # this whole file exists to prevent.
  nocheck <- titles[vapply(seq_along(heads), function(i)
    !any(grepl("^\\*\\*check:\\*\\*", todo[heads[i]:ends[i]])), logical(1))]
  add("every TODO.md item states its check", nocheck,
      "TODO.md's header requires a check that decides when the item is closed")

  # -- 3c/6 no TODO item number appears twice ----------------------------------
  # Added 2026-09-22 after an edit that meant to REPLACE item 16 appended the new
  # text and left the old block above it. Both versions then sat in the file, the
  # stale one first, and every other invariant still passed.
  nums <- sub("^##[[:space:]]+([0-9]+[a-z]?)\\..*$", "\\1",
              grep("^##[[:space:]]+[0-9]+[a-z]?\\.", todo, value = TRUE))
  add("no TODO.md item number appears twice",
      unique(nums[duplicated(nums)]),
      "an item was appended instead of replaced - delete the stale block")

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

  # -- 4c/6 every corrections/*.yml is actually parseable ----------------------
  # Added 2026-09-23. Three of the fourteen did not parse - a plain scalar with a
  # colon in it, a literal block whose first line was its most indented, and a
  # sequence sharing a parent with a mapping key. The checks above grep for
  # `id:`/`title:`/`status:` at the start of a line, which every broken file still
  # satisfied, so a registry described as "declarative" had been unreadable by any
  # machine for as long as it had existed.
  #
  # AGENTS.md promises this file is pure base R with no dependencies, so the parse
  # is skipped rather than errored when yaml is absent - the invariant then reports
  # honestly that it could not run instead of passing quietly.
  if (requireNamespace("yaml", quietly = TRUE)) {
    unparseable <- character(0)
    for (y in ymls) {
      msg <- tryCatch({ yaml::yaml.load_file(file.path(cdir, y)); NA_character_ },
                      error = function(e) conditionMessage(e))
      if (!is.na(msg))
        unparseable <- c(unparseable, sprintf("%s - %s", y, sub("\n.*$", "", msg)))
    }
    add("every corrections/*.yml parses as YAML", unparseable,
        "a declaration no machine can read is prose in a .yml costume")
  } else {
    add("every corrections/*.yml parses as YAML", "SKIPPED - package 'yaml' not installed",
        "install.packages('yaml') to enable this invariant")
  }

  # -- 4b/6 nothing re-indexes corrections outside corrections/ -----------------
  # Added 2026-09-23. decisions/README.md carried a "Data defects" table listing a
  # subset of this directory. Nothing checked it and it drifted to 6 of 14 before
  # anyone looked. The check above asserts the corrections directory indexes
  # itself; a second table asserting the same thing is the drift AGENTS.md opens
  # by naming. Generate the list, never maintain it.
  dre  <- rd(p("curate", "decisions", "README.md"))
  hd   <- grep("^##[[:space:]]+Data defects", dre)
  rows <- character(0)
  if (length(hd)) {
    nxt  <- grep("^##[[:space:]]", dre)
    nxt  <- nxt[nxt > hd[1]]
    stop_at <- if (length(nxt)) nxt[1] - 1L else length(dre)
    sect <- dre[(hd[1] + 1L):stop_at]
    rows <- grep("^[[:space:]]*\\|", sect, value = TRUE)
  }
  add("no second index of corrections/ in decisions/README.md",
      substr(rows, 1, 60),
      "delete the table - corrections/*.yml carry id/title/status and index themselves")

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

  # -- 5b/6 CLAUDE.md is a loader and stays one ---------------------------------
  # AGENTS.md reaching a session is the assumption the record layer rests on.
  # CLAUDE.md is the filename the harness loads; it imports AGENTS.md and holds
  # no facts of its own. A loader that grows facts is a second AGENTS.md, which
  # is the drift this whole layer exists to prevent.
  cl <- rd(p("CLAUDE.md"))
  bad <- character(0)
  if (!length(cl))                       bad <- c(bad, "CLAUDE.md is missing")
  else {
    if (!grepl("^@AGENTS[.]md", cl[1]))  bad <- c(bad, "first line is not @AGENTS.md")
    if (length(cl) > 25)                 bad <- c(bad, sprintf("%d lines - it is accruing facts", length(cl)))
  }
  add("CLAUDE.md is a loader for AGENTS.md, and only that", bad,
      "keep it to the import plus the instruction to read AGENTS.md")

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

    # Not an invariant — a reminder. These cannot move without the maintainer,
    # so a session that does not see them either stalls or repeats them.
    w <- grep("needs: maintainer", todo)
    if (length(w)) {
      cat("\nwaiting on the maintainer:\n")
      for (i in w) {
        h <- rev(grep("^## ", todo[seq_len(i)], value = TRUE))[1]
        if (!is.na(h)) cat("  ", sub("^## ", "", h), "\n")
      }
    }
  }

  invisible(!any(vapply(res, function(r) length(r$bad) > 0, logical(1))))
}
