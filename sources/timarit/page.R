# The text of timarit.is's pages, one row per page as it was fetched (raw/external/timarit/, decision 295).
# Side: preprocessing (timarit). See decision 295; plan 067.
#
# Input:  raw/external/timarit/_manifest.csv and the page files it lists: page views (page_<page id>.txt) and the pages
#         of issue ZIPs adopted from the studies of 2026-11-05 to -07 (<date>i<n>p<k>.txt)
# Output: staging/timarit/page.parquet - one row per page file, keyed on `file`: issue_id, publication, issued (ISO
#         date, or the year alone where timarit.is gives only that), page_id (NA for a ZIP's page whose issue's page ids
#         were not logged), idx (its place in the issue), how, fetched (UTC, as text), study, md5, chars, text
#
# Source-shaped: the text as timarit.is's OCR gives it, old spelling and OCR errors kept, lines joined with "\n". Every
# file's md5 is checked against the manifest: the store is never edited. Published text under copyright: kept under
# $FISHYDATA only. Nothing in the flow reads it; studies search it and plan 067's readings will cite it.

library(dplyr)

M <- utils::read.csv(fd_raw("external", "timarit", "_manifest.csv"), encoding = "UTF-8",
                     colClasses = c(issue_id = "integer", page_id = "integer", idx = "integer", issued = "character"))
pages <- M[M$how %in% c("page_view", "zip_member"), ]
stopifnot("a page file listed twice" = !anyDuplicated(pages$file),
          "a page view listed twice" = !anyDuplicated(na.omit(pages$page_id)))

path <- fd_raw("external", "timarit", pages$file)
bad <- pages$file[unname(tools::md5sum(path)) != pages$md5]
if (length(bad)) stop("files changed since the manifest was written: ", paste(head(bad, 10), collapse = ", "))

text <- vapply(path, function(f) paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n"), "",
               USE.NAMES = FALSE)
out <- tibble(file = pages$file, issue_id = pages$issue_id, publication = pages$publication, issued = pages$issued,
              page_id = pages$page_id, idx = pages$idx, how = pages$how, fetched = pages$fetched,
              study = pages$study, md5 = pages$md5, chars = nchar(text), text = text) |>
  arrange(issue_id, idx, file)

stopifnot(nrow(out) == sum(M$how %in% c("page_view", "zip_member")), !anyNA(out$publication), !anyNA(out$issued))
print(knitr::kable(out |> group_by(publication) |>
  summarise(issues = n_distinct(issue_id), pages = n(), with_page_id = sum(!is.na(page_id)),
            from = min(issued), to = max(issued), .groups = "drop"),
  caption = "staging/timarit/page"))

nanoparquet::write_parquet(out, fd_staging("timarit", "page.parquet"))
