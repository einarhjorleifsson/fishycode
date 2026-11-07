# timarit.R — the text of timarit.is's pages, kept once under raw/external/timarit/ (decision 295)
#
# timarit.is (Landsbókasafn Íslands - Háskólabókasafn) serves each page's OCR text inside the page's view, /page/<id>,
# in //div[@id='hiddenNavIncl']/div[1]. robots.txt allows /page, /issue, /view and /search and disallows /files, /pdf,
# /api, /cover and /tbn, so the text is had one page view at a time, never as an issue's ZIP. The store, one folder
# per issue, keyed by timarit.is's own ids:
#   <issue id>/page_<page id>.txt   a page view's text as served (a BOM removed)
#   <issue id>/issue_view.html      one view of the issue, kept whole: it lists the issue's page ids in order and its
#                                   article menu
#   <issue id>/issue.zip, <issue id>/<date>i<n>p<k>.txt   an issue's text ZIP and its pages, fetched before robots.txt
#                                   was read (2026-11-05 to -07) and adopted from the studies; never fetched again
#   _manifest.csv                   one row per file: issue, publication, issued, page id, its place in the issue (idx),
#                                   file, how (page_view, zip_member, zip_archive, issue_view), bytes, md5, fetched,
#                                   study
#   _requests.csv                   one row per request made through timarit_fetch_*()
# Fetching (timarit_fetch_*) is called only by dump/timarit/fetch.R; reading (timarit_text(), timarit_article_text())
# by anyone. The text is published but under copyright: it stays under $FISHYDATA.
# Function definitions only: targets sources R/ wholesale.
# Drafted by Claude (AI), 2026-11-07. Not checked by a person.

timarit_dir <- function(...) fd_raw("external", "timarit", ...)

.timarit <- new.env()
.TIMARIT_UA <- "fishycode (Marine and Freshwater Research Institute, Iceland; page views one at a time, 10-30 s apart)"
.TIMARIT_COLS <- c(issue_id = "integer", publication = "character", issued = "character", page_id = "integer",
                   idx = "integer", file = "character", how = "character", bytes = "numeric", md5 = "character",
                   fetched = "character", study = "character")

# The manifest, empty with its columns when there is none yet
timarit_manifest <- function() {
  f <- timarit_dir("_manifest.csv")
  if (!file.exists(f)) return(as.data.frame(lapply(.TIMARIT_COLS, function(t) vector(t, 0))))
  utils::read.csv(f, encoding = "UTF-8", colClasses = .TIMARIT_COLS)
}

.timarit_append <- function(x, f) {
  utils::write.table(x, f, sep = ",", row.names = FALSE, qmethod = "double", append = file.exists(f),
                     col.names = !file.exists(f), fileEncoding = "UTF-8")
}

# A view's title, "Andvari - 01.01.1903 - Tímarit.is" or "Náttúrufræðingurinn - 1963 - Tímarit.is": the publication
# and the issue's date as ISO (or the year alone, as given)
timarit_title_parse <- function(title) {
  t <- sub("\\s*-\\s*Tímarit\\.is\\s*$", "", trimws(title))
  d <- sub("^.* - ", "", t)
  p <- sub(" - [^-]*$", "", t)
  iso <- ifelse(grepl("^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$", d),
                paste(substr(d, 7, 10), substr(d, 4, 5), substr(d, 1, 2), sep = "-"), d)
  list(publication = p, issued = iso)
}

# A page or issue view: its issue id, the issue's page ids in order, title, the page's OCR text and the article menu
timarit_parse_view <- function(html) {
  doc <- xml2::read_html(html)
  iss <- regmatches(html, regexpr("var issueId = [0-9]+;", html))
  ids <- unique(as.integer(sub('href="/page/', "", regmatches(html, gregexpr('href="/page/[0-9]+', html))[[1]])))
  tx <- xml2::xml_text(xml2::xml_find_first(doc, "//div[@id='hiddenNavIncl']/div[1]"))
  a <- xml2::xml_find_all(doc, "//div[@id='bsArtSelect']/a[@data-id!='']")
  list(issue_id = if (length(iss)) as.integer(gsub("[^0-9]", "", iss)) else NA_integer_, page_ids = ids,
       title = trimws(xml2::xml_text(xml2::xml_find_first(doc, "//title"))),
       text = if (is.na(tx)) NA_character_ else gsub("﻿", "", tx),
       menu = data.frame(article_id = xml2::xml_attr(a, "data-id"), title = trimws(xml2::xml_text(a))))
}

# One request to a path robots.txt allows, after a random pause since the last; any status but 200 stops
.timarit_get <- function(url, what, id, pause = c(10, 30)) {
  if (!grepl("^https://timarit\\.is/(page|issue)/[0-9]+$", url)) stop("only /page/<id> and /issue/<id> are asked: ", url)
  last <- if (is.null(.timarit$last)) Sys.time() - 3600 else .timarit$last
  w <- stats::runif(1, pause[1], pause[2]) - as.numeric(difftime(Sys.time(), last, units = "secs"))
  if (w > 0) Sys.sleep(w)
  r <- tryCatch(httr2::request(url) |> httr2::req_user_agent(.TIMARIT_UA) |> httr2::req_timeout(120) |>
                  httr2::req_error(is_error = function(r) FALSE) |> httr2::req_perform(), error = function(e) e)
  .timarit$last <- Sys.time()
  status <- if (inherits(r, "error")) NA_integer_ else httr2::resp_status(r)
  .timarit_append(data.frame(time = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"), what = what, id = id,
                             status = status), timarit_dir("_requests.csv"))
  if (is.na(status) || status != 200) stop(what, " ", id, ": status ", status, call. = FALSE)
  httr2::resp_body_string(r)
}

# A view into the store: the page's text (an issue view shows its first page), the issue's view if it has none yet
.timarit_store <- function(html, page_id, study) {
  v <- timarit_parse_view(html)
  if (is.na(v$issue_id)) stop("no issue id in the view of page ", page_id, call. = FALSE)
  if (is.na(page_id)) page_id <- v$page_ids[1]
  d <- timarit_dir(v$issue_id)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  meta <- timarit_title_parse(v$title)
  row <- function(file, how, pid, idx) {
    f <- file.path(d, file)
    data.frame(issue_id = v$issue_id, publication = meta$publication, issued = meta$issued, page_id = pid, idx = idx,
               file = file.path(v$issue_id, file), how = how, bytes = file.size(f), md5 = unname(tools::md5sum(f)),
               fetched = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"), study = study)
  }
  if (!file.exists(file.path(d, "issue_view.html"))) {
    writeLines(html, file.path(d, "issue_view.html"), useBytes = TRUE)
    .timarit_append(row("issue_view.html", "issue_view", page_id, match(page_id, v$page_ids)), timarit_dir("_manifest.csv"))
  }
  f <- paste0("page_", page_id, ".txt")
  writeLines(if (is.na(v$text)) "" else v$text, file.path(d, f), useBytes = TRUE)
  .timarit_append(row(f, "page_view", page_id, match(page_id, v$page_ids)), timarit_dir("_manifest.csv"))
  invisible(v)
}

# Page ids of an issue in order: from its stored view, else from a whole issue had as a ZIP
timarit_issue_pages <- function(issue_id) {
  f <- timarit_dir(issue_id, "issue_view.html")
  if (file.exists(f)) return(timarit_parse_view(paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n"))$page_ids)
  m <- timarit_manifest()
  m <- m[m$issue_id == issue_id & m$how == "zip_member", ]
  if (nrow(m) && !anyNA(m$page_id)) return(m$page_id[order(m$idx)])
  stop("issue ", issue_id, " has no stored view: fetch it first (dump/timarit/fetch.R issue ", issue_id, ")", call. = FALSE)
}

# Fetching: pages not yet in the store, one at a time; never a page already had (by page id)
timarit_fetch_pages <- function(page_ids, study, pause = c(10, 30)) {
  stopifnot("name the study that asks" = is.character(study) && nzchar(study))
  want <- setdiff(unique(as.integer(page_ids)), timarit_manifest()$page_id)
  for (pid in want) {
    v <- .timarit_store(.timarit_get(paste0("https://timarit.is/page/", pid), "page", pid, pause), pid, study)
    message(format(Sys.time(), "%H:%M:%S", tz = "UTC"), " UTC  page ", pid, " (issue ", v$issue_id, ", ",
            nchar(v$text), " chars)")
  }
  invisible(want)
}
timarit_fetch_issue <- function(issue_id, study, pause = c(10, 30)) {
  if (!file.exists(timarit_dir(issue_id, "issue_view.html")))
    .timarit_store(.timarit_get(paste0("https://timarit.is/issue/", issue_id), "issue", issue_id, pause), NA, study)
  invisible(timarit_issue_pages(issue_id))
}
# An article: its first page and the n - 1 pages after it in the issue
timarit_fetch_article <- function(first_page_id, n, study, pause = c(10, 30)) {
  timarit_fetch_pages(first_page_id, study, pause)
  m <- timarit_manifest()
  ids <- timarit_issue_pages(m$issue_id[match(first_page_id, m$page_id)])
  k <- match(first_page_id, ids)
  want <- ids[k:min(length(ids), k + n - 1)]
  timarit_fetch_pages(want, study, pause)
  invisible(want)
}

# Reading: the stored text of pages, by page id; a page not in the store stops with how to fetch it
timarit_text <- function(page_ids) {
  m <- timarit_manifest()
  m <- m[m$how %in% c("page_view", "zip_member") & !is.na(m$page_id), ]
  i <- match(as.integer(page_ids), m$page_id)
  if (anyNA(i)) stop("not in raw/external/timarit: ", paste(page_ids[is.na(i)], collapse = ", "),
                     "; fetch with dump/timarit/fetch.R", call. = FALSE)
  stats::setNames(vapply(m$file[i], function(f)
    paste(readLines(timarit_dir(f), encoding = "UTF-8", warn = FALSE), collapse = "\n"), ""), page_ids)
}
# Pages as one text, each opened by "=== [p. <place in issue>] https://timarit.is/page/<id>"
timarit_article_text <- function(page_ids) {
  m <- timarit_manifest()
  idx <- m$idx[match(as.integer(page_ids), m$page_id)]
  paste0("=== [p. ", idx, "] https://timarit.is/page/", page_ids, "\n", timarit_text(page_ids), collapse = "\n")
}
