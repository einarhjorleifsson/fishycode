# The hand-made readings of the tag recaptures' place text: a standard name for the finder's description.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/fiskmerki/ornefni_endurheimtur.xlsx (20,317 rows, 2022-11-02);
#         fiskmerki/tag_ornefni-trial2.xlsx (20,256 rows, 2022-09-16); their .csv twins, checked
# Output: staging/ornefni/recapture_reading.parquet - one row per row of either workbook (40,573), keyed on
#         (`file`, `rid` or `recapture_id`)
#
# A person's reading, kept apart from the source it reads (recapture_place) and joined to it by key, never merged.
# - ornefni_endurheimtur.xlsx: `reading` (ornefni: a standard name, on 9,749 rows), `reading2`, `feature` (nafnberi),
#   `comment`; `text` is the finder's text as the workbook holds it (veidistadur).
# - tag_ornefni-trial2.xlsx: an earlier extract of the same recaptures; `fiskislod` (a trawl-ground name, on 8,006
#   rows); `text` is its `on`.
# Every row is kept, read or not: `read` says whether any hand column is filled.

library(dplyr)

R <- fd_raw("external", "ornefni", "fiskmerki")
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(as.character(x))); x[x %in% ""] <- NA; x }

a <- readxl::read_excel(file.path(R, "ornefni_endurheimtur.xlsx"), guess_max = 1e6)
stopifnot(setequal(names(a), c(".rid", "veidistadur", "ornefni", "comment", "ornefni2", "nafnberi", "id", "merki_id",
                               "finnandi_id", "vlengd", "nbreidd", "lon", "lat")))
b <- readxl::read_excel(file.path(R, "tag_ornefni-trial2.xlsx"), guess_max = 1e6)
stopifnot(setequal(names(b), c("id", "merki_id", "finnandi_id", "vlengd", "nbreidd", "lon", "lat", "on", "fiskislod")))
stopifnot("the workbooks hold the rows of their csv twins" =
            setequal(a$.rid, read.csv(file.path(R, "ornefni_endurheimtur.csv"), check.names = FALSE)$.rid),
          setequal(b$id, read.csv(file.path(R, "tag_ornefni-trial2.csv"))$id))

out <- bind_rows(
  tibble(file = "ornefni_endurheimtur.xlsx", rid = as.integer(a$.rid), recapture_id = a$id, text = a$veidistadur,
         reading = squeeze(a$ornefni), reading2 = squeeze(a$ornefni2), feature = squeeze(a$nafnberi),
         comment = squeeze(a$comment)),
  tibble(file = "tag_ornefni-trial2.xlsx", recapture_id = b$id, text = b$on, fiskislod = squeeze(b$fiskislod))) |>
  mutate(read = !is.na(reading) | !is.na(reading2) | !is.na(feature) | !is.na(comment) | !is.na(fiskislod),
         source = "fiskmerki")

stopifnot(nrow(out) == 20317L + 20256L, !anyDuplicated(out[c("file", "recapture_id")]))
print(knitr::kable(out |> group_by(file) |> summarise(rows = n(), read = sum(read), readings = n_distinct(reading, na.rm = TRUE),
  fiskislod = n_distinct(fiskislod, na.rm = TRUE)), caption = "staging/ornefni/recapture_reading"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "recapture_reading.parquet"))
