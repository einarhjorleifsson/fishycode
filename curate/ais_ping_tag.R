# The reason that a two step process is used is so that the union process in
#   script ais-data-cosolidation.R is separate from the allocation of pings
#   to space and trip creation

library(duckdbfs)
library(tidyverse)
library(tictoc)
library(h3)
duckdbfs::load_spatial()
ports <-
  open_dataset(fd_staging("aux", "ports.fgb")) |>
  select(pid, hid, geom)
h3 <- open_dataset(fd_curated("reference", "area_h3.parquet")) |> select(h3, depth, bbht, fao)

# write out --------------------------------------------------------------------
# Partition by year so downstream queries can apply partition pruning.
# The loop materialises one year at a time to keep peak memory manageable.
# ONE write, partitioned by year.
#
# A SECOND copy of this entire loop used to follow, writing the same pings again
# to the same directory partitioned by c("year", "month"), while this block was
# held behind an `if(TRUE)` toggle. Both ran. The result was staging/ais/ping_tagged
# containing 2009-2025 twice in two incompatible layouts - 36 GB where 20 would
# do - and it made the directory unreadable outright:
#
#   Binder Error: Hive partition mismatch between file ".../year=2007/data_0.parquet"
#   and ".../year=2009/month=1/data_0.parquet"
#
# The month-partitioned block was the one dropped, because it covered only
# 2009:2025 and so silently omitted 2007, 2008 and 2026, all of which carry data.
# Nothing downstream filters on month: ais_ping_clean.R and ais_trip.R both work
# by year.

ais <-
  open_dataset(fd_staging("ais", "ping_union"))
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
    duckdbfs::write_dataset(fd_staging("ais", "ping_tagged"), partitioning = c("year"), format = "parquet")
  toc()
}
