# ais_ping_tag.R — tag every merged ping with its harbour polygon and its H3 cell's depth, habitat and ICES area.
# Side: flow, step 0. See plan 014.
#
# Input:  staging/ais/ping_union              all pings, from curate/ais_ping_union.R
#         staging/aux/ports.fgb               harbour polygons (pid, hid)
#         curated/reference/area_h3.parquet   H3 resolution-8 cell -> depth, bbht, fao
# Output: staging/ais/ping_tagged             partitioned by year
#
# Two scripts, union then tag, on purpose: the union is 44 GB, and the tagging must be rerunnable
# without redoing it (AGENTS.md, Script naming).
#
# The port tag is ramb::rb_flag_ping_port() (plan 013 phase 2, renamed in plan 014): a ping inside two polygons takes the
# smaller one, where the spatial join it replaced kept both and doubled the ping. The point geometry the join
# left in every row (`geom`) is no longer written; nothing read it.

library(duckdbfs)
library(tidyverse)
library(tictoc)
library(h3)
duckdbfs::load_spatial()
ports <- sf::read_sf(fd_staging("aux", "ports.fgb")) |> transmute(port_id = pid, hid)
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
# Nothing downstream filters on month: ais_ping_clean.R and ais_voyage.R both work
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
    ramb::rb_flag_ping_port(ports, keep = "hid") |>
    rename(pid = port_id) |>
    mutate(h3 = h3_latlng_to_cell_string(lat, lon, 8L)) |>
    left_join(h3, by = "h3") |>
    duckdbfs::write_dataset(fd_staging("ais", "ping_tagged"), partitioning = c("year"), format = "parquet")
  toc()
}
