# The articles of each issue in the timarit.is store, as the issue's own menu lists them (raw/external/timarit/, decision 295).
# Side: preprocessing (timarit). See decision 295; plan 067.
#
# Input:  raw/external/timarit/<issue id>/issue_view.html, one per issue the store has a view of, and _manifest.csv
# Output: staging/timarit/issue_article.parquet - one row per entry of an issue's article menu, keyed on (issue_id,
#         gegnir_id): issue_id, publication, issued, n_pages (the issue's pages), article_id (timarit.is's; not
#         unique within an issue: errata share one), gegnir_id (the article's record in Gegnir, the Icelandic union
#         catalogue), title (as the menu gives it); an issue whose menu is empty has one row with article_id NA
#
# Source-shaped: what the menu shows. It gives no author and no page; in Andvari it lists the articles in the order
# of their pages (against the volumes' printed contents, 1895-1937). An article's pages and author are read from its
# pages or the volume's contents page. An issue the store has no view of is not here.

library(dplyr)

M <- utils::read.csv(fd_raw("external", "timarit", "_manifest.csv"), encoding = "UTF-8",
                     colClasses = c(issue_id = "integer", page_id = "integer", idx = "integer", issued = "character"))
V <- M[M$how == "issue_view", ]
stopifnot("an issue with two views" = !anyDuplicated(V$issue_id))

out <- bind_rows(lapply(seq_len(nrow(V)), function(i) {
  f <- fd_raw("external", "timarit", V$file[i])
  stopifnot(unname(tools::md5sum(f)) == V$md5[i])
  v <- timarit_parse_view(paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
  stopifnot(v$issue_id == V$issue_id[i])
  menu <- if (nrow(v$menu)) v$menu else data.frame(article_id = NA_integer_, gegnir_id = NA_character_, title = NA_character_)
  tibble(issue_id = V$issue_id[i], publication = V$publication[i], issued = V$issued[i], n_pages = length(v$page_ids),
         article_id = menu$article_id, gegnir_id = menu$gegnir_id, title = menu$title)
})) |> arrange(publication, issued, issue_id, article_id, gegnir_id)

stopifnot(!anyDuplicated(out[c("issue_id", "gegnir_id")]))
print(knitr::kable(out |> group_by(publication) |>
  summarise(issues = n_distinct(issue_id), articles = sum(!is.na(article_id)), from = min(issued), to = max(issued),
            .groups = "drop"), caption = "staging/timarit/issue_article"))

nanoparquet::write_parquet(out, fd_staging("timarit", "issue_article.parquet"))
