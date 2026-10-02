# gear_speed_range.R — speed inside RECORDED logbook windows, per gear (plan 012, level 1)
#
# Input:  curated/ais/trail, curated/logbook/station_window.parquet, curated/reference/gear_window.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# Question: how fast are vessels going where the skipper recorded both haul times, and how does
# that compare with the declared [s1, s2] of reference/gear/windows.R? Fixes carry a gear only
# where n_sid == 1, so only unambiguous fixes are used.

library(dplyr)
library(duckdbfs)
source(here::here("R/paths.R"))

sw <- open_dataset(fd_curated("logbook", "station_window.parquet")) |> distinct(.sid, schema, gid)
decl <- open_dataset(fd_curated("reference", "gear_window.parquet")) |> select(gid, d1 = s1, d2 = s2)

x <- open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2008, year <= 2024, n_sid == 1, win_basis == "recorded",
         phase %in% c("tow", "haul", "jig"), !is.na(speed), speed < 15) |>
  inner_join(sw, by = c(".sid", "schema")) |>
  inner_join(decl, by = "gid")

q <- function(d) d |>
  summarise(n = n(), q025 = quantile(speed, .025), q05 = quantile(speed, .05), q25 = quantile(speed, .25),
            q50 = median(speed), q75 = quantile(speed, .75), q95 = quantile(speed, .95),
            q975 = quantile(speed, .975), .groups = "drop") |> collect()

# 1. quantiles per gear and the share the declared range keeps
x |> group_by(gid, phase) |> q() |> arrange(desc(n)) |> print(n = Inf)
x |> group_by(gid, phase) |>
  summarise(n = n(), inside = mean(as.numeric(speed >= d1 & speed <= d2)),
            below = mean(as.numeric(speed < d1)), above = mean(as.numeric(speed > d2)), .groups = "drop") |>
  collect() |> print(n = Inf)

# 2. by provider and by period, trawls only
x |> filter(gid %in% 6:9) |> group_by(gid, provider) |> q() |> print(n = Inf)
x |> filter(gid %in% 6:9) |> mutate(period = case_when(year <= 2013 ~ "2008-13", year <= 2018 ~ "2014-18", TRUE ~ "2019-24")) |>
  group_by(gid, period) |> q() |> print(n = Inf)

# 3. the GPS logger's speed at exactly 1 m/s (1.943846 kn): share of fish-trawl tow fixes, by provider
x |> filter(gid == 6, phase == "tow") |>
  group_by(provider) |>
  summarise(n = n(), at_1ms = mean(as.numeric(abs(speed - 1.943846) < 1e-4)),
            below = mean(as.numeric(speed < d1)), above = mean(as.numeric(speed > d2)), .groups = "drop") |>
  collect() |> print()

# 4. The 1 m/s value is a placeholder, not a speed (plan 012 §2f). Raw logger speed is m/s on a 0.1 kn grid;
#    exactly 1.000 m/s is off the grid. By year, then against the AIS speed at the same instant.
gps_raw <- open_dataset(fd_curated("logbook", "sensor_gps")) |> filter(year >= 2008, !is.na(speed))
gps_raw |> group_by(year) |>
  summarise(n = n(), share_1ms = mean(as.numeric(abs(speed - 1) < 1e-6))) |> arrange(year) |> collect() |> print(n = Inf)
gps_raw |> group_by(sensor_src) |>
  summarise(n = n(), share_1ms = mean(as.numeric(abs(speed - 1) < 1e-6))) |> collect() |> print()

open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2020, provider != "gps", !is.na(speed_gps), !is.na(speed)) |>
  mutate(one = abs(speed_gps - 1.943846) < 1e-4) |>
  group_by(one, provider) |>
  summarise(n = n(), ais_q25 = quantile(speed, .25), ais_q50 = median(speed), ais_q75 = quantile(speed, .75), .groups = "drop") |>
  collect() |> print()
