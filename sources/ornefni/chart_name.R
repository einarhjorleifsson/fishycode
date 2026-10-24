# Place names as lines, from MFRI's old GIS area (stasi/gis/sjokort, 2015).
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/sjokort/ornefni.shp (+ .dbf .prj .qpj .shx)
# Output: staging/ornefni/chart_name.parquet - one row per line (272), keyed on `row`; WKB `geometry`, WGS 84
#
# Source-shaped: `id` and `ref` (a chart number: IS31 ... IS81) as given; `id` repeats, so `row`, the order in the file,
# is the key. Probably label lines digitised from the nautical charts (nothing in the files says so): basis
# `recorded`, kind `line`.

library(dplyr)

FILE <- fd_raw("external", "ornefni", "sjokort", "ornefni.shp")

d <- sf::st_read(FILE, quiet = TRUE)
stopifnot(setequal(names(d), c("id", "name", "ref", "geometry")), sf::st_crs(d)$epsg == 4326,
          all(sf::st_geometry_type(d) == "LINESTRING"))
out <- d |>
  mutate(row = seq_len(n()), name_raw = name, name = gsub("\\s+", " ", trimws(name)), source = "sjokort",
         position_basis = "recorded", position_kind = "line") |>
  select(row, id, name_raw, name, ref, source, position_basis, position_kind, geometry)

stopifnot(nrow(out) == 272L, !anyNA(out$name), !any(grepl("Ã|Â", out$name)))
print(knitr::kable(tibble(rows = nrow(out), names = n_distinct(out$name), charts = n_distinct(out$ref),
                          ids_repeated = sum(duplicated(out$id))), caption = "staging/ornefni/chart_name"))

write_parquet_sf(out, fd_staging("ornefni", "chart_name.parquet"))
