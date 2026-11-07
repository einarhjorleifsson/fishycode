# adopt_studies.R — the timarit.is text of the studies of 2026-11-05 to -07, moved into raw/external/timarit/ (decision 295)
#
# Input:  $FISHYDATA/archive/<study>/text/ of the four studies that fetched timarit.is's text, and their fetch logs:
#         out/pages_had.csv (page views), out/fetched.csv (issue ZIPs, with the issue's page ids in order),
#         out/fetched_text.csv with out/hits.csv and its other page tables (the 2026-11-05 study's ZIPs and the
#         publication of each); the views
#         kept in out/issue_views/<issue id>.html and out/page_<page id>.html
# Output: raw/external/timarit/<issue id>/ (page_<page id>.txt, issue_view.html, issue.zip and the ZIP's own files);
#         raw/external/timarit/_manifest.csv; raw/external/timarit/README-provenance.txt; at each old path a relative
#         symbolic link to the file's new place, so the studies' scripts and READMEs still read it
# One-time, run by hand. A file is moved (rename within $FISHYDATA), its md5 checked before and after; a path that is
# already a link is skipped, so a second run moves nothing. It stops if a destination exists. Makes no request.
# The maintainer, 2026-11-07: "Can we make sure that the minded text is somewhere systematically stored - i foresee
# that we will accumulate more as time goes by. should this not be in fishydata/raw?"; then "Flat, by issue id" and
# "Text files and a parquet".
# Run from fishycode's root:
#   Rscript dump/timarit/adopt_studies.R
# Drafted by Claude (AI), 2026-11-07. Not checked by a person.

Sys.setenv(TZ = "UTC")
source("R/timarit.R")
FD <- normalizePath(fishydata_root())
STUDIES <- c("2026-11-05-timarit-ornefni", "2026-11-07-aegir-early", "2026-11-07-andvari-bjarni",
             "2026-11-07-seabed-landscape")
rd <- function(f) if (file.exists(f)) utils::read.csv(f, encoding = "UTF-8") else NULL
md5 <- function(f) unname(tools::md5sum(f))
when <- function(f) format(file.mtime(f), "%Y-%m-%d %H:%M:%S", tz = "UTC")

# A relative link from the old path to the new, both under $FISHYDATA
rel_link <- function(dest, src) {
  up <- length(strsplit(sub(paste0("^", FD, "/"), "", dirname(src)), "/")[[1]])
  paste(c(rep("..", up), sub(paste0("^", FD, "/"), "", dest)), collapse = "/")
}
move_in <- function(src, rel) {
  dest <- timarit_dir(rel)
  if (file.exists(dest)) stop("already in the store: ", rel, " (from ", src, ")")
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  m <- md5(src)
  stopifnot(file.rename(src, dest), md5(dest) == m)
  stopifnot(file.symlink(rel_link(dest, normalizePath(src, mustWork = FALSE)), src))
  m
}

rows <- list(); left <- character(0)
for (st in STUDIES) {
  S <- file.path(FD, "archive", st)
  had <- rd(file.path(S, "out", "pages_had.csv"))
  zips <- rd(file.path(S, "out", "fetched.csv"))
  ztxt <- rd(file.path(S, "out", "fetched_text.csv"))
  # the publication of each page the 2026-11-05 study met, from every table of it that has one
  hits <- do.call(rbind, lapply(c("hits", "candidates", "night_candidates", "phrase_candidates", "phrase_hits",
                                  "reading_list", "triage", "spot_test", "phrase_subject"), function(t) {
    x <- rd(file.path(S, "out", paste0(t, ".csv")))
    if (!is.null(x) && all(c("page_id", "publication") %in% names(x))) x[, c("page_id", "publication")] }))
  if (!is.null(hits)) hits <- hits[!duplicated(hits$page_id), ]
  files <- list.files(file.path(S, "text"), recursive = TRUE, full.names = TRUE)
  files <- files[!nzchar(Sys.readlink(files))]                       # links: moved before
  for (f in files) {
    r <- sub(paste0("^", S, "/text/"), "", f)
    meta <- list(publication = NA_character_, issued = NA_character_, page_id = NA_integer_, idx = NA_integer_,
                 fetched = when(f))
    if (grepl("^[0-9]+\\.zip$", r)) {                                  # an issue's text ZIP
      iss <- as.integer(sub("\\.zip$", "", r)); how <- "zip_archive"; new <- file.path(iss, "issue.zip")
    } else if (grepl("^[0-9]+/[0-9]{3}_[0-9]+\\.txt$", r)) {            # a page view's text
      iss <- as.integer(dirname(r)); how <- "page_view"
      pid <- as.integer(sub("^[0-9]{3}_([0-9]+)\\.txt$", "\\1", basename(r)))
      new <- file.path(iss, paste0("page_", pid, ".txt"))
      meta$page_id <- pid; meta$idx <- as.integer(substr(basename(r), 1, 3))
      h <- had[match(pid, had$page_id), ]
      if (!is.null(had) && !is.na(h$page_id)) { meta[c("publication", "issued")] <- timarit_title_parse(h$title)
                                                meta$fetched <- h$fetched }
    } else if (grepl("^[0-9]+/.+i[0-9]+p[0-9]+\\.txt$", r)) {           # a page of an issue's ZIP, as the ZIP named it
      iss <- as.integer(dirname(r)); how <- "zip_member"; new <- file.path(iss, basename(r))
      meta$idx <- as.integer(sub("^.*p([0-9]+)\\.txt$", "\\1", basename(r)))
      meta$issued <- sub("^([0-9]{4}-[0-9]{2}-[0-9]{2}).*$", "\\1", basename(r))
    } else { left <- c(left, file.path(st, "text", r)); next }
    if (how != "page_view") {                                           # the issue's ZIP: its log
      z <- if (!is.null(zips)) zips[match(iss, zips$issue_id), ] else NULL
      if (!is.null(z) && !is.na(z$issue_id)) {
        meta$publication <- timarit_title_parse(z$title)$publication
        if (how == "zip_member") meta$page_id <- as.integer(strsplit(z$page_ids, " ")[[1]])[meta$idx]
        meta$fetched <- z$fetched
      }
      t <- if (!is.null(ztxt)) ztxt[match(iss, ztxt$issue_id), ] else NULL
      if (!is.null(t) && !is.na(t$issue_id)) {
        meta$fetched <- t$fetched
        if (!is.null(hits)) meta$publication <- hits$publication[match(t$page_id, hits$page_id)]
      }
    }
    m <- move_in(f, new)
    rows[[length(rows) + 1]] <- data.frame(issue_id = iss, publication = meta$publication, issued = meta$issued,
      page_id = meta$page_id, idx = meta$idx, file = new, how = how, bytes = file.size(timarit_dir(new)), md5 = m,
      fetched = meta$fetched, study = st)
  }
  # The views a study kept whole: one per issue as issue_view.html
  views <- c(list.files(file.path(S, "out", "issue_views"), "\\.html$", full.names = TRUE),
             list.files(file.path(S, "out"), "^page_[0-9]+\\.html$", full.names = TRUE))
  views <- views[!nzchar(Sys.readlink(views))]
  for (f in views) {
    v <- timarit_parse_view(paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
    if (is.na(v$issue_id) || file.exists(timarit_dir(v$issue_id, "issue_view.html"))) {
      left <- c(left, sub(paste0("^", FD, "/archive/"), "", f)); next
    }
    new <- file.path(v$issue_id, "issue_view.html")
    meta <- timarit_title_parse(v$title)
    pid <- if (grepl("^page_", basename(f))) as.integer(gsub("[^0-9]", "", basename(f))) else v$page_ids[1]
    fetched <- when(f)
    m <- move_in(f, new)
    rows[[length(rows) + 1]] <- data.frame(issue_id = v$issue_id, publication = meta$publication, issued = meta$issued,
      page_id = pid, idx = match(pid, v$page_ids), file = new, how = "issue_view",
      bytes = file.size(timarit_dir(new)), md5 = m, fetched = fetched, study = st)
  }
}

# The manifest: rows already there kept, the new added, sorted by issue and place in it ----------------------------------
new <- do.call(rbind, rows)
if (!is.null(new)) {
  # an issue's publication and date where some of its files carry them and others not
  for (k in c("publication", "issued")) {
    known <- stats::aggregate(new[[k]], list(issue_id = new$issue_id), function(x) { x <- x[!is.na(x)]
      if (length(x)) x[which.max(nchar(x))] else NA_character_ })
    i <- is.na(new[[k]]); new[[k]][i] <- known$x[match(new$issue_id[i], known$issue_id)]
  }
  m <- rbind(timarit_manifest(), new)
  m <- m[order(m$issue_id, m$how != "issue_view", m$idx, m$file), ]
  utils::write.csv(m, timarit_dir("_manifest.csv"), row.names = FALSE, fileEncoding = "UTF-8")
}
m <- timarit_manifest()

# README-provenance.txt, written here, never by hand ----------------------------------------------------------------------
n_by <- table(m$how)
writeLines(c(
  "# raw/external/timarit/ - the text of timarit.is's pages, kept once (decision 295)",
  "#",
  "# What: the OCR text of pages of Icelandic journals and papers on timarit.is (Landsbókasafn Íslands -",
  "#  Háskólabókasafn), one folder per issue, keyed by timarit.is's own ids. Published text under copyright: kept",
  "#  under $FISHYDATA only, never in the repo or anything published.",
  "# How text enters: only through dump/timarit/fetch.R (R/timarit.R), by page view (/page/<id>, /issue/<id>, which",
  "#  robots.txt allows), one request at a time, 10-30 s apart; a page already here is never asked again.",
  "# What was here first: adopted on 2026-11-07 by dump/timarit/adopt_studies.R from the four studies that fetched",
  paste0("#  it (", paste(STUDIES, collapse = ", "), "); each old path is now a relative link here."),
  "#  The issue ZIPs (how = zip_archive, zip_member) were fetched from /files before robots.txt was read; /files is",
  "#  disallowed and is never asked again. A ZIP's own pages keep the ZIP's names (<date>i<n>p<k>.txt, k = idx);",
  "#  their page ids are known where the study logged the issue's page ids (Ægir, Andvari), not for the",
  "#  2026-11-05 study's issues.",
  "# Files:",
  "#  <issue id>/page_<page id>.txt   a page view's text (how = page_view)",
  "#  <issue id>/issue_view.html      one view of the issue, whole: its page ids in order, its article menu",
  "#  <issue id>/issue.zip, <issue id>/<date>i<n>p<k>.txt   an adopted ZIP and its pages",
  "#  _manifest.csv                   one row per file: issue_id, publication, issued, page_id, idx (place in the",
  "#                                  issue), file, how, bytes, md5, fetched (UTC), study",
  "#  _requests.csv                   one row per request made through dump/timarit/fetch.R",
  "# The table: sources/timarit/page.R reads the text files into staging/timarit/page.parquet.",
  paste0("# Counts when written (", format(Sys.time(), "%Y-%m-%d %H:%M UTC"), "): ", length(unique(m$issue_id)),
         " issues; ", paste(names(n_by), n_by, sep = " ", collapse = ", "), "."),
  "# Written by dump/timarit/adopt_studies.R; drafted by Claude (AI), 2026-11-07."),
  timarit_dir("README-provenance.txt"), useBytes = TRUE)

message(nrow(if (is.null(new)) data.frame() else new), " files moved; the store: ", length(unique(m$issue_id)),
        " issues; ", paste(names(n_by), n_by, sep = " ", collapse = ", "))
if (length(left)) message("left where they are (", length(left), "): ", paste(utils::head(left, 20), collapse = ", "))
miss <- m[m$how %in% c("page_view", "zip_member") & (is.na(m$publication) | is.na(m$issued)), ]
if (nrow(miss)) message("pages with no publication or date: ", nrow(miss), " in issues ",
                        paste(unique(miss$issue_id), collapse = ", "))
