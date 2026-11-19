# IS 50V's place names, every bearer, one row per feature as delivered: LMÍ's whole name set (plan 074 step 12, the names).
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow (plan 074 ask p);
# reference/names/marine_name.R reads it.
#
# Input:  raw/external/is50v/ornefni_all/ornefni_{punktar,linur,flakar}_<page>.json (dump/natt/ornefni.R: IS_50V's three
#         name layers whole, 45,289 points, 43,466 lines and 111,919 polygons on 2026-11-16; WGS 84)
# Output: staging/is50v/name.parquet - one row per feature (200,674), keyed on `uuid`: every attribute under an English
#         name, the layer it came in (point, line, polygon), WKB `geometry`, WGS 84
#
# Source-shaped. `source_ref` (heimild) is LMÍ's own, as LMÍ publishes it with the names (the maintainer, 2026-11-19: "the
# LMÍ data was obtained from source on the web"). The gazetteer's sources/ornefni/lmi_name.R stages an older derivative,
# the 2022 polygons alone. Open data of Náttúrufræðistofnun Íslands (IS 50V); cite "IS 50V, Náttúrufræðistofnun Íslands"
# where it is shown.
# Run from the repo root: Rscript sources/is50v/name.R. Written by Claude (AI), 2026-11-19.

library(dplyr)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'

DIR <- fd_raw("external", "is50v", "ornefni_all")
MAP <- c(id = "id", uuid = "uuid", name_raw = "ornefni", feature_code = "nafnberikenni", feature = "nafnberi",
         date_inserted = "dagsinnsetningar", date_corrected = "dagsleidrettingar", date_updated = "dagsuppfaerslu",
         source_ref = "heimild", status = "tilvist", owner = "gagnaeigandi", scale = "birtingarkvardi",
         name_alt = "tvinefni", description = "ornefnalysing", class = "ornefnaflokkur", class_code = "ornefnaflokkurkenni",
         dataset = "gagnasafn")
LAYER <- c(punktar = "point", linur = "line", flakar = "polygon")
day <- function(x) as.Date(substr(x, 1, 10))

files <- list.files(DIR, "^ornefni_(punktar|linur|flakar)_[0-9]+[.]json$", full.names = TRUE)
stopifnot(length(files) == 12L)
d <- do.call(rbind, lapply(files, function(f) {
  x <- sf::st_read(f, quiet = TRUE)
  stopifnot("a column is not mapped" = setequal(setdiff(names(x), attr(x, "sf_column")), MAP), sf::st_crs(x)$epsg == 4326)
  out <- sf::st_sf(tibble(layer = rep(unname(LAYER[sub("^ornefni_([a-z]+)_.*", "\\1", basename(f))]), nrow(x))),
                   geometry = sf::st_geometry(x))
  for (n in names(MAP)) out[[n]] <- x[[MAP[[n]]]]
  out
}))
d <- d |>
  mutate(name = gsub("\\s+", " ", trimws(name_raw)), .after = name_raw) |>
  mutate(across(starts_with("date_"), day), scale = suppressWarnings(as.integer(scale))) |>
  relocate(geometry, .after = last_col())

stopifnot(nrow(d) == 200674L, !anyDuplicated(d$uuid), !anyNA(d$uuid),
          identical(as.vector(table(d$layer)[c("point", "line", "polygon")]), c(45289L, 43466L, 111919L)))
print(knitr::kable(sf::st_drop_geometry(d) |> count(layer, name = "features") |>
  left_join(sf::st_drop_geometry(d) |> group_by(layer) |> summarise(no_name = sum(is.na(name) | name == ""),
                                                                      with_source = sum(!is.na(source_ref))), by = "layer"),
  caption = "staging/is50v/name"))
write_parquet_sf(d, fd_staging("is50v", "name.parquet"))
