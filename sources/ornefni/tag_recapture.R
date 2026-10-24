# The finder's place text on tag recaptures, with the recapture's position or square, from the dump of fiskmerki.
# Side: preprocessing (ornefni). See plan 044 §4.1; plan 043 ask f.
#
# Input:  raw/oracle/fiskmerki/endurheimtur.parquet (42,484 recaptures), endurheimtur_otengt.parquet (401, not matched
#         to a tag)
# Output: staging/ornefni/tag_recapture.parquet - one row per recapture with a place text (35,108), keyed on
#         (`recapture_table`, `recapture_id`)
#
# Source-shaped, under English names. `text_raw` is ORNEFNI as entered; `text` squeezes its spaces. It is the
# finder's description of where the fish was caught, mostly not a name ("Innan við Fiskasker"), the name inflected
# after a preposition. Picked in the app from orri.ornefni it reads "NAFN-HEITI"; a number is an orri row.
# recapture_place is the ornefni repo's extract of 2022 from the same table (its 20,317 ids are all here), and the
# hand readings in recapture_reading read those. The finder, the vessel and the reward are not read.
# - Position: NBREIDD and VLENGD are degrees and minutes, DDMM.mm, a minus longitude east (three Barents Sea
#   recaptures): `lat`, `lon`, kind `point`, basis `recorded`. They are not squares' centres (63 of 24,332 sit on one),
#   and the recorded square agrees with them on 99 %. One whose minutes reach 60, or outside 40-85 N and 70 W-60 E, is
#   unread (`position_note`).
# - Without a read position, the recorded square (REITUR, 0 = none) and quarter (SMAREITUR 1-4; 0 and 5-8 are not
#   quarters) give the centre: kind `square`, basis `derived`, with its size (`square_w`, `square_h`, degrees).
# merki.endurheimt, the older system's recaptures, is not read: 26,370 of its 26,470 place texts are here with the same
# position.

library(dplyr)

R <- function(t) nanoparquet::read_parquet(fd_raw("oracle", "fiskmerki", paste0(t, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }
dm <- function(x) sign(x) * (abs(x) %/% 100 + (abs(x) %% 100) / 60)

need <- c("id", "ornefni", "nbreidd", "vlengd", "reitur", "smareitur", "dags_fundid", "dypi", "veidarfaeri_id")
e <- R("endurheimtur"); o <- R("endurheimtur_otengt")
stopifnot("fiskmerki's recapture tables have the columns read" = all(need %in% names(e)), all(need %in% names(o)))
d <- bind_rows(e[c(need, "merki_id")] |> mutate(recapture_table = "endurheimtur"),
               o[need] |> mutate(recapture_table = "endurheimtur_otengt")) |>
  filter(!is.na(squeeze(ornefni)))

lat <- dm(d$nbreidd); lon <- -dm(d$vlengd)
read <- !is.na(lat) & !is.na(lon) & abs(d$nbreidd) %% 100 < 60 & abs(d$vlengd) %% 100 < 60 &
  lat >= 40 & lat <= 85 & lon >= -70 & lon <= 60
part <- ifelse(d$smareitur %in% 1:4, d$smareitur, NA_integer_)
has_sq <- !is.na(d$reitur) & d$reitur > 0
sqc <- matrix(NA_real_, nrow(d), 2)
if (any(has_sq)) { s <- geo::r2d(d$reitur[has_sq]); sqc[has_sq, ] <- cbind(s$lat, s$lon) }
off_lat <- ifelse(part %in% c(1, 2), 0.125, ifelse(part %in% c(3, 4), -0.125, 0))
off_lon <- ifelse(part %in% c(1, 3), -0.25, ifelse(part %in% c(2, 4), 0.25, 0))
square <- !read & has_sq

out <- tibble(recapture_table = d$recapture_table, recapture_id = d$id, tag_id = d$merki_id, time = d$dags_fundid,
              text_raw = d$ornefni, text = squeeze(d$ornefni),
              nbreidd = d$nbreidd, vlengd = d$vlengd, reitur = d$reitur, smareitur = d$smareitur,
              depth = d$dypi, gear_fiskmerki = d$veidarfaeri_id,
              lat = case_when(read ~ lat, square ~ sqc[, 1] + off_lat), lon = case_when(read ~ lon, square ~ sqc[, 2] + off_lon),
              position_basis = case_when(read ~ "recorded", square ~ "derived", TRUE ~ "none"),
              position_kind = case_when(read ~ "point", square ~ "square", TRUE ~ NA_character_),
              square_w = ifelse(square, ifelse(is.na(part), 1, 0.5), NA_real_), square_h = square_w / 2,
              position_note = ifelse(!is.na(d$nbreidd) & !read, paste("position unread:", d$nbreidd, d$vlengd), NA_character_),
              source = "fiskmerki")

stopifnot(!anyDuplicated(out[c("recapture_table", "recapture_id")]), !anyNA(out$text),
          "a square's centre lies in the sea area read" = all(between(out$lat[square], 55, 80)))
print(knitr::kable(out |> count(recapture_table, position_kind) |>
  left_join(out |> group_by(recapture_table) |> summarise(texts = n_distinct(text), unread = sum(!is.na(position_note))),
            by = "recapture_table"), caption = "staging/ornefni/tag_recapture"))

write_parquet_group(out, fd_staging("ornefni", "tag_recapture.parquet"))
