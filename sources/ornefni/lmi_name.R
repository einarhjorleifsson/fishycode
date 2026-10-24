# Landmælingar Íslands' place-name polygons (IS 50V, ornefni_flakar), as downloaded in 2022.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/lmi/ornefni_lmi.gpkg (5,821 polygons); lmi/lmi_ornefni.csv (538 sea names), checked
# Output: staging/ornefni/lmi_name.parquet - one row per polygon (5,821), keyed on `row`; WKB `geometry`, WGS 84
#
# Source-shaped, under English names, every column. The file is the ornefni repo's derivative of LMÍ's layer
# (scripts/raw_ornefni_lmi.R): invalid polygons and those touching the 30 largest land polygons removed, multipolygons
# cut into polygons (so `uuid` repeats), `valid`, `rid` and `area_m2` added. It holds land and lake names too: `class`
# says which (Sjávarörnefni = sea).
# - `in_sea_list`: the polygon's name and attributes are a row of lmi_ornefni.csv, the repo's list of sea names. 535 of
#   its 538 rows are here; the 3 others were removed with their polygons.
# - LMÍ's `source_ref` (heimild) names Trackwell for some fishing-ground names: counted below.

library(dplyr)

FILE <- fd_raw("external", "ornefni", "lmi", "ornefni_lmi.gpkg")
SEA  <- fd_raw("external", "ornefni", "lmi", "lmi_ornefni.csv")
MAP <- c(gml_id = "gml_id", uuid = "uuid", name_raw = "ornefni", feature_code = "nafnberikenni", feature = "nafnberi",
         date_inserted = "dagsinnsetningar", date_corrected = "dagsleidrettingar", date_updated = "dagsuppfaerslu",
         source_ref = "heimild", status = "tilvist", owner = "gagnaeigandi", scale = "birtingarkvardi",
         name_alt = "tvinefni", description = "ornefnalysing", class = "ornefnaflokkur", class_code = "ornefnaflokkurkenni",
         dataset = "gagnasafn", valid = "valid", rid = ".rid", area_m2 = "area")
day <- function(x) as.Date(sub("Z$", "", x))

d <- sf::st_read(FILE, quiet = TRUE)
stopifnot("a column is not mapped" = setequal(setdiff(names(d), attr(d, "sf_column")), MAP), sf::st_crs(d)$epsg == 4326)
sea <- read.csv(SEA, encoding = "UTF-8")
sea_key <- do.call(paste, c(sea[c("ornefni", "tvinefni", "ornefnalysing", "ornefnaflokkur", "ornefnaflokkurkenni")], sep = "\r"))

out <- sf::st_sf(tibble(row = seq_len(nrow(d))), geometry = sf::st_geometry(d))
for (n in names(MAP)) out[[n]] <- d[[MAP[[n]]]]
out <- out |>
  mutate(in_sea_list = do.call(paste, c(sf::st_drop_geometry(d)[c("ornefni", "tvinefni", "ornefnalysing", "ornefnaflokkur",
                                                                     "ornefnaflokkurkenni")], sep = "\r")) %in% sea_key,
         name = gsub("\\s+", " ", trimws(name_raw)), .after = name_raw) |>
  mutate(across(starts_with("date_"), day), source = "lmi", position_basis = "recorded", position_kind = "polygon") |>
  relocate(geometry, .after = last_col())

stopifnot(nrow(out) == 5821L, !anyNA(out$name), sum(sea_key %in% sea_key[sea_key %in% do.call(paste, c(
  sf::st_drop_geometry(d)[c("ornefni", "tvinefni", "ornefnalysing", "ornefnaflokkur", "ornefnaflokkurkenni")], sep = "\r"))]) == 535)
print(knitr::kable(sf::st_drop_geometry(out) |> mutate(kind = sub(" .*", "", class)) |> group_by(kind) |>
  summarise(polygons = n(), names = n_distinct(name), in_sea_list = sum(in_sea_list),
            trackwell_source = sum(grepl("trackwell", source_ref, ignore.case = TRUE))), caption = "staging/ornefni/lmi_name"))

write_parquet_sf(out, fd_staging("ornefni", "lmi_name.parquet"))
