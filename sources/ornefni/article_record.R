# Hand-written records of ground names, one file each, mostly from newspaper articles (the ornefni repo's data-md/).
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/data-md/*.md (152 files: 151 records and the template, 2023-11-16 and 2023-12-07)
# Output: staging/ornefni/article_record.parquet - one row per record (151), keyed on `file`
#
# Each file is a list of "## section" headings with text under them. Source-shaped: one column per section, the text
# as written (lines joined with "\n", leading and trailing blank lines dropped): name, synonyms, description, comment,
# class (`class`, or `flokkur` in one file), quotations, person, url, reference. A heading's trailing colon is
# ignored ("## person:"). `_ORNEFNI_TEMPLATE.md` is the template, not a record. No position: kind `text`.
# `person` and `quotations` name skippers quoted in published articles: kept under $FISHYDATA only.

library(dplyr)

DIR <- fd_raw("external", "ornefni", "data-md")
FILES <- sort(list.files(DIR, "[.]md$"), method = "radix")
SECTIONS <- c("name", "synonyms", "description", "comment", "class", "quotations", "person", "url", "reference")
ALIAS <- c(flokkur = "class")

read_record <- function(f) {
  x <- readLines(file.path(DIR, f), warn = FALSE, encoding = "UTF-8")
  h <- grepl("^##", x)
  stopifnot("text before the first heading" = all(!nzchar(trimws(x[seq_len(which(h)[1] - 1)]))))
  key <- tolower(trimws(sub(":\\s*$", "", sub("^##\\s*", "", x[h]))))
  key <- ifelse(key %in% names(ALIAS), ALIAS[key], key)
  if (!all(key %in% SECTIONS)) stop(f, ": a heading outside the known sections: ", paste(setdiff(key, SECTIONS), collapse = ", "))
  body <- split(x, cumsum(h))[as.character(seq_along(key))]
  val <- vapply(body, function(v) { v <- v[-1]; t <- paste(v, collapse = "\n"); t <- gsub("^\\s+|\\s+$", "", t)
                                    if (nzchar(t)) t else NA_character_ }, "")
  if (anyDuplicated(key)) val <- tapply(val, key, function(v) paste(na.omit(v), collapse = "\n\n"))[unique(key)]
  as_tibble(as.list(setNames(val, unique(key))))
}

recs <- FILES[FILES != "_ORNEFNI_TEMPLATE.md"]
out <- bind_rows(lapply(recs, function(f) tibble(file = f, read_record(f))))
for (s in setdiff(SECTIONS, names(out))) out[[s]] <- NA_character_
out <- out |>
  mutate(name_raw = name, name = gsub("\\s+", " ", trimws(name)), source = "article", position_basis = "none",
         position_kind = "text") |>
  select(file, name_raw, name, all_of(setdiff(SECTIONS, "name")), source, position_basis, position_kind)

stopifnot(length(FILES) == 152L, nrow(out) == 151L, !anyDuplicated(out$file))
print(knitr::kable(tibble(records = nrow(out), named = sum(!is.na(out$name)), names = n_distinct(out$name, na.rm = TRUE),
  with_url = sum(!is.na(out$url)), with_quotation = sum(!is.na(out$quotations)), with_person = sum(!is.na(out$person))),
  caption = "staging/ornefni/article_record"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "article_record.parquet"))
