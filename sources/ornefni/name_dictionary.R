# The ornefni repo's two hand-made name lists: the dictionary across sources, and the words of the recapture texts.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/dictionary/dictonary.xlsx (9,285 rows, 2022-11-03), its machine twin dictonary.csv;
#         fiskmerki/tag_ornefni.xlsx, sheet tag_ornefni (2,439 rows, 2022-09-15), its machine twin tag_ornefni.csv
# Output: staging/ornefni/name_dictionary.parquet - one row per dictionary row (9,285), keyed on `row`
#         staging/ornefni/tag_word.parquet - one row per word (2,439), keyed on `word_id`
#
# Each is a person's reading, staged as written:
# - name_dictionary: a name as a source spells it (`name_raw`), the source (trackwell, endurheimtur; empty for LMÍ's sea
#   names, kept empty), its count, and the reading by hand: `reading` (ornefni), `reading2`, `comment` (cmt), `feature`
#   and `class` (LMÍ's nafnberi and ornefnaflokkur).
# - tag_word: a word of the recapture texts, its count, whether it was judged a correct spelling (`correct`), the name
#   it reads as (`reading`, on), whether to use it (`use`: y/n) and LMÍ's class where the name is LMÍ's (`lmi`).
# - The workbooks are their csv twins with the hand columns added: the twins are checked, not staged. The workbook's
#   sheet `lmi` is lmi/lmi_ornefni.csv again (lmi_name).

library(dplyr)

R <- fd_raw("external", "ornefni")
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(as.character(x))); x[x %in% ""] <- NA; x }

d <- readxl::read_excel(file.path(R, "dictionary", "dictonary.xlsx"), guess_max = 1e6)
stopifnot(setequal(names(d), c("name", "ornefni", "ornefni2", "cmt", "n", "source", "nafnberi", "ornefnaflokkur")))
dc <- read.csv(file.path(R, "dictionary", "dictonary.csv"), encoding = "UTF-8")
stopifnot("the workbook is its csv twin, row for row" = nrow(dc) == nrow(d), identical(as.character(dc$name), d$name))
dict <- tibble(row = seq_len(nrow(d)), name_raw = d$name, name = squeeze(d$name), source_list = d$source,
               n = as.integer(d$n), reading = squeeze(d$ornefni), reading2 = squeeze(d$ornefni2), comment = squeeze(d$cmt),
               feature = squeeze(d$nafnberi), class = squeeze(d$ornefnaflokkur))

w <- readxl::read_excel(file.path(R, "fiskmerki", "tag_ornefni.xlsx"), sheet = "tag_ornefni")
stopifnot(setequal(names(w), c(".id", "correct", "n", "word", "on", "use", "lmi")))
wc <- read.csv(file.path(R, "fiskmerki", "tag_ornefni.csv"), check.names = FALSE)
stopifnot("the workbook holds its csv twin's words" = setequal(wc$.id, w$.id), nrow(wc) == nrow(w))
word <- tibble(word_id = as.integer(w$.id), word = w$word, n = as.integer(w$n), correct = as.logical(w$correct),
               reading = squeeze(w$on), use = squeeze(w$use), lmi = squeeze(w$lmi)) |> arrange(word_id)

stopifnot(nrow(dict) == 9285L, nrow(word) == 2439L, !anyDuplicated(word$word_id))
print(knitr::kable(dict |> group_by(source_list) |> summarise(rows = n(), read = sum(!is.na(reading)),
  readings = n_distinct(reading, na.rm = TRUE)), caption = "staging/ornefni/name_dictionary"))
print(knitr::kable(tibble(words = nrow(word), read = sum(!is.na(word$reading)), readings = n_distinct(word$reading, na.rm = TRUE),
  use_y = sum(word$use %in% "y")), caption = "staging/ornefni/tag_word"))

nanoparquet::write_parquet(dict, fd_staging("ornefni", "name_dictionary.parquet"))
nanoparquet::write_parquet(word, fd_staging("ornefni", "tag_word.parquet"))
