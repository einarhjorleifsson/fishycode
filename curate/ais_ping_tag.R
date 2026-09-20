# The reason that a two step process is used is so that the union process in
#   script ais-data-cosolidation.R is separate from the allocation of pings
#   to space and trip creation

library(duckdbfs)
library(tidyverse)
library(tictoc)
library(h3)
duckdbfs::load_spatial()
ports <-
  open_dataset("data/aux/ports.fgb") |>
  select(pid, hid, geom)
h3 <- open_dataset("data/aux/h3_indices.parquet") |> select(h3, depth, bbht, fao)

# write out --------------------------------------------------------------------
# Partition by year so downstream queries can apply partition pruning.
# The loop materialises one year at a time to keep peak memory manageable.
if(TRUE) {
  ais <-
    open_dataset("data/trail")
  years <- 2007:2026
  for(y in 1:length(years)) {
    tic()
    YR <- years[y]
    print(YR)
    ais |>
      filter(year == YR) |>
      mutate(geom = ST_POINT(lon, lat)) |>
      duckdbfs::spatial_join(ports,     by = "st_intersect", join = "left") |>
      select(-geom_1) |>
      mutate(h3 = h3_latlng_to_cell_string(lat, lon, 8L)) |>
      left_join(h3) |>
      duckdbfs::write_dataset("data/trail2", partitioning = c("year"), format = "parquet")
    toc()
  }
}

# write out --------------------------------------------------------------------
# Partition by year so downstream queries can apply partition pruning.
# The loop materialises one year at a time to keep peak memory manageable.
ais <- open_dataset("data/trail") |> mutate(month = month(time))
years <- 2009:2025
months <- 1:12
for(y in 1:length(years)) {
  YR <- years[y]
  print(YR)
  for(m in 1:length(months)) {
    tic()
    MO <- months[m]
    print(MO)
    ais |>
      filter(year == YR, month == MO) |>
      mutate(geom = ST_POINT(lon, lat)) |>
      duckdbfs::spatial_join(ports,     by = "st_intersect", join = "left") |>
      select(-geom_1) |>
      mutate(h3 = h3_latlng_to_cell_string(lat, lon, 8L)) |>
      left_join(h3) |>
      duckdbfs::write_dataset("data/trail2", partitioning = c("year", "month"), format = "parquet")
    toc()
  }
}
