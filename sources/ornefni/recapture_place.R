# The finder's place text on tag recaptures, with the recapture position (Oracle fiskmerki.endurheimtur, 2022).
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/fiskmerki/ornefni_endurheimtur.csv (20,317 rows); the .gpkg (the same rows), checked
# Output: staging/ornefni/recapture_place.parquet - one row per recapture (20,317), keyed on `rid` and `recapture_id`
#
# Source-shaped, under English names: `text` is the finder's description of where the fish was caught, not a name. It
# is the ornefni repo's extract of 2022-11-02 (scripts/raw_ornefni_endurheimtur.R), which squeezed spaces and removed
# the first ".", ",", "(" and ")" from each text; the text as entered is in fiskmerki, not dumped (plan 043 ask f).
# `lon`/`lat` are the repo's conversion of `vlengd`/`nbreidd` (degrees-minutes); both are kept. `finder_id` is a
# person's id in fiskmerki: personal data, kept under $FISHYDATA only. The readings made by hand are recapture_reading.

library(dplyr)

FILE <- fd_raw("external", "ornefni", "fiskmerki", "ornefni_endurheimtur.csv")
GPKG <- fd_raw("external", "ornefni", "fiskmerki", "ornefni_endurheimtur.gpkg")

d <- read.csv(FILE, encoding = "UTF-8", check.names = FALSE)
stopifnot(setequal(names(d), c(".rid", "ornefni", "id", "merki_id", "finnandi_id", "vlengd", "nbreidd", "lon", "lat")))
g <- sf::st_drop_geometry(sf::st_read(GPKG, quiet = TRUE))
stopifnot("the GeoPackage holds the same rows" = setequal(g$.rid, d$.rid), nrow(g) == nrow(d))

out <- tibble(rid = d$.rid, recapture_id = d$id, tag_id = d$merki_id, finder_id = d$finnandi_id, text = d$ornefni,
              vlengd = d$vlengd, nbreidd = d$nbreidd, lon = d$lon, lat = d$lat, source = "fiskmerki",
              position_basis = if_else(is.na(d$lon) | is.na(d$lat), "none", "recorded"), position_kind = "point")

stopifnot(nrow(out) == 20317L, !anyDuplicated(out$rid), !anyDuplicated(out$recapture_id), !anyNA(out$text))
print(knitr::kable(tibble(rows = nrow(out), texts = n_distinct(out$text), tags = n_distinct(out$tag_id),
                          finders = n_distinct(out$finder_id), no_position = sum(out$position_basis == "none")),
                   caption = "staging/ornefni/recapture_place"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "recapture_place.parquet"))
