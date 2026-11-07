# fetch.R — timarit.is's pages into raw/external/timarit/, by page view (decision 295)
#
# Input:  page ids, an article's first page id and its number of pages, or an issue id; the study that asks
# Output: raw/external/timarit/<issue id>/page_<page id>.txt and issue_view.html; rows in _manifest.csv and
#         _requests.csv (R/timarit.R)
# The only way text enters the store. Only /page/<id> and /issue/<id> are asked, which robots.txt allows; one request
# at a time, 10-30 s apart at random; a status but 200 stops the run; a page already in the store is never asked again,
# so a run that stopped is resumed by running it again. Ask the maintainer before a bulk run (plan 067 ask c).
# Run from fishycode's root:
#   Rscript dump/timarit/fetch.R page <page id> [<page id> ...] --study <study folder name>
#   Rscript dump/timarit/fetch.R article <first page id> <n pages> --study <study folder name>
#   Rscript dump/timarit/fetch.R issue <issue id> --study <study folder name>
# Drafted by Claude (AI), 2026-11-07. Not checked by a person.

Sys.setenv(TZ = "UTC")
source("R/timarit.R")
a <- commandArgs(TRUE)
s <- match("--study", a)
if (is.na(s) || s == length(a)) stop("name the study that asks: --study <study folder name>", call. = FALSE)
study <- a[s + 1]
a <- a[-c(s, s + 1)]
what <- a[1]
n <- suppressWarnings(as.integer(a[-1]))
if (!length(n) || anyNA(n)) stop("ids must be integers: ", paste(a[-1], collapse = " "), call. = FALSE)

switch(what,
  page    = timarit_fetch_pages(n, study),
  article = { stopifnot("article <first page id> <n pages>" = length(n) == 2); timarit_fetch_article(n[1], n[2], study) },
  issue   = for (i in n) timarit_fetch_issue(i, study),
  stop("the first argument is page, article or issue", call. = FALSE))
m <- timarit_manifest()
message("store: ", length(unique(m$issue_id)), " issues, ", sum(m$how %in% c("page_view", "zip_member")), " pages")
