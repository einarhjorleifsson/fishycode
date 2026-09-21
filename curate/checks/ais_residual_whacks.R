# 25 knots == 12.861 m/s  (kn x 0.514444)

library(tictoc)
library(tidyverse)
library(duckdbfs)
library(ramb)
KN_MAX <- 25
MS_MAX <- KN_MAX * 0.514444   # 12.861 m/s


# Lazy DuckDB path examples ---------------------------------------------------
ais <- open_dataset(fd_staging("ais", "ping_union"))

# Wack detection ---------------------------------------------------------------
# test if any remaining whacks after first round using whack_fwdbwd
tic()
res <- list()
q <- open_dataset(fd_staging("ais", "ping_union"))
years <- 2015:2025
for(y in 1:length(years)) {
  YR <- years[y]
  step1 <-
    q |>
    filter(year == YR) |>
    group_by(vid) |>
    whack_fwdbwd(kn_max = KN_MAX) |>
    mutate(whack = ifelse(is.na(whack), TRUE, whack))
  step2 <-
    step1 |>
    filter(whack == FALSE) |>
    select(-whack) |>
    whack_fwdbwd(kn_max = KN_MAX) |>
    mutate(whack = ifelse(is.na(whack), TRUE, whack))
  res[[y]] <-
    bind_rows(step1 |> count(whack) |> collect() |> mutate(step = 1, year = YR),
              step2 |> count(whack) |> collect() |> mutate(step = 2, year = YR))
}
toc()
bind_rows(res) |> spread(step, n) |> arrange(year, whack) |> knitr::kable()

ais |>
  group_by(vid) |>
  whack_fwdbwd(kn_max = KN_MAX) |>
  mutate(whack = ifelse(is.na(whack), FALSE, whack)) |>
  filter(whack == TRUE) |>
  count(vid) |>
  arrange(desc(n))

d <-
  ais |>
  filter(vid == 2765) |>
  whack_fwdbwd(kn_max = KN_MAX) |>
  mutate(whack = ifelse(is.na(whack), FALSE, whack)) |>
  collect() |>
  arrange(vid, time)
d |> count(whack, provider)
d |>
  select(lon, lat, speed = whack) |>
  ramb::rb_mapdeck()
# should really do test using whack_sequential_fast (what a misnomer) on some
#  subsamples, but the one step process above seems sufficient


# ins-and-outs -----------------------------------------------------------------
#  In the datacall process there are QC filters on the ais pings
#  Here do some feasability/speed testing on joins

# the setting of the crs
iceland <- open_dataset("/Volumes/fishydata/data/auxillary/shoreline.gpkg")
iceland <- open_dataset("shoreline.parquet")
ais |>
  filter(year == 2024,
         month(time) == 1) |>
  compute()

ports <- duckdbfs::open_dataset(fd_staging("ports", "ports_all.gpkg")) |> filter(source == "einar") |> select(port, geom)
open_dataset(fd_staging("ais", "ping_union")) |>
  duckdbfs::spatial_join(ports, by = "st_intersects", join = "left") |>
  count(pid, port, provider) |>
  collect() ->
  pid_check
pid_check |>
  filter(is.na(pid))

ais |>
  duckdbfs::spatial_join(ports, by = "st_intersects", join = "left") |>
  filter(port == "Hofsós") |>
  collect() ->
  test
test |> count(pid)
test |> count(pid, provider)
test |> filter(is.na(pid)) |> select(lon, lat, speed = pid) |> ramb::rb_mapdeck()


library(duckspatial)
