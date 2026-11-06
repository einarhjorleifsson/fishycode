# The names on the map "Vestmannaeyjar, fiskimið og örnefni", as read and georeferenced: one row per name read.
# Side: preprocessing (ornefni). See decision 286; plan 043.
#
# Input:  raw/external/ornefni/readings/vestmannaeyjar_map_names.csv (the reading of documents/Vestmannaeyjar-Fiskimið_og_
#         örnefni.pdf, frozen from $FISHYDATA/archive/2026-11-06-vestmannaeyjar-map/, made by Claude (AI), not checked
#         by a person)
# Output: staging/ornefni/map_name.parquet - one row per name read, keyed on (`half`, `row`)
#
# The map is two scans, a north and a south half, read by eye: each name at its "+" (`at` merki), at its label where
# no mark is drawn (nafn), or an island's centre (eyja); placed on 15 of LMÍ's islands, about 90 m (the study's
# 02_georef.R). `position_basis` is "reconstructed": the map records the place, its lon/lat is fitted on another
# source. Every row in one `outcome`:
# - "staged": a name, to the gazetteer;
# - "control island": one of the 15 islands the fit was made on. Its position agrees with LMÍ's by construction, so it
#   is no witness for it, and it is left out;
# - "the same place in the other half": a name drawn in both halves within 500 m, kept once, in the half with a "+".

library(dplyr)

f <- fd_raw("external", "ornefni", "readings", "vestmannaeyjar_map_names.csv")
r <- utils::read.csv(f, encoding = "UTF-8", stringsAsFactors = FALSE)
SAME_M <- 500
km_m <- function(lon1, lat1, lon2, lat2) sqrt(((lon1 - lon2) * 111120 * cos(lat1 * pi / 180))^2 + ((lat1 - lat2) * 111120)^2)

out <- r |>
  mutate(row = row_number(), name_raw = name, name = gsub("\\s+", " ", trimws(name)), source = "vestmannaeyjar",
         position_basis = "reconstructed", position_kind = "point",
         control = grepl("^control", note))
# a name drawn in both halves: the same place where its two points lie within SAME_M, two places (homonyms) otherwise
pair <- out |> filter(!control) |> group_by(name) |> filter(n_distinct(half) == 2) |>
  mutate(apart_m = km_m(lon[1], lat[1], lon[2], lat[2]), keep = row == row[order(at != "merki", half)][1]) |> ungroup()
dropped <- pair$row[pair$apart_m < SAME_M & !pair$keep]
out <- out |>
  mutate(outcome = case_when(control ~ "control island", row %in% dropped ~ "the same place in the other half", TRUE ~ "staged")) |>
  select(row, half, name_raw, name, kind, at, x, y, note, athugasemd, lon, lat, source, position_basis, position_kind, outcome)

stopifnot("a name on every row" = !anyNA(out$name) && all(nzchar(out$name)),
          "a position on every row, off Vestmannaeyjar" = all(out$lat > 63.2 & out$lat < 63.6 & out$lon > -20.7 & out$lon < -19.9),
          "15 control islands, Álsey in both halves" = sum(out$outcome == "control island") == 16 &&
            n_distinct(out$name[out$outcome == "control island"]) == 15,
          "every row in one outcome" = !anyNA(out$outcome))
print(knitr::kable(count(out, outcome, half), caption = "staging/ornefni/map_name"))
nanoparquet::write_parquet(out, fd_staging("ornefni", "map_name.parquet"))
