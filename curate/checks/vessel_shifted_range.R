# vessel_shifted_range.R — a gear range shifted by the vessel's own offset, tested out of sample (plan 012, §2h)
#
# Input:  curated/ais/trail, curated/logbook/station_window.parquet, curated/reference/gear_window.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# A vessel's median towing speed is stable across years but its range is no narrower than the gear's. So keep
# the gear's shape and move it: for a fix of provider p on gear g,
#     range = [g05(g,p) + delta, g95(g,p) + delta]
# where g05/g95 are the gear x provider 5th/95th percentiles of recorded tow fixes (2008-2024, placeholder out)
# and delta is the vessel's median of (speed - gear x provider median) in the PREVIOUS year (>= MIN_N fixes).
# Judged on this year's fixes, which delta never saw, against: the gear x provider range unshifted, the same-year
# shift (in sample, an upper bound), and the declared range. Equal width by construction, so coverage is the measure.

library(dplyr)
library(duckdbfs)
source(here::here("R/paths.R"))

MIN_N <- 2000
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
DBI::dbExecute(duckdbfs::cached_connection(), sprintf("SET temp_directory = '%s'", spill))

sw <- open_dataset(fd_curated("logbook", "station_window.parquet")) |>
  filter(gid %in% 6:8) |> distinct(.sid, schema, gid)
decl <- open_dataset(fd_curated("reference", "gear_window.parquet")) |>
  filter(gid %in% 6:8) |> select(gid, d1 = s1, d2 = s2)

fx <- open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2008, year <= 2024, n_sid == 1, win_basis == "recorded", phase == "tow",
         !is.na(speed), speed < 15, !(provider == "gps" & abs(speed - 1.943846) < 1e-4)) |>
  inner_join(sw, by = c(".sid", "schema")) |>
  select(vid, year, gid, provider, speed)

gp <- fx |> group_by(gid, provider) |>
  summarise(n_gp = n(), g05 = quantile(speed, .05), g50 = median(speed), g95 = quantile(speed, .95), .groups = "drop") |>
  collect() |> filter(n_gp >= 50000)
print(gp)

# The vessel-year offset against its own provider's gear median
delta <- fx |> inner_join(as_dataset(gp), by = c("gid", "provider")) |>
  group_by(vid, gid, year) |>
  summarise(n = n(), d = median(speed - g50), .groups = "drop") |> collect() |> filter(n >= MIN_N)
cat("\nvessel offset delta (kn), per vessel-year\n"); print(summary(delta$d))

prev <- delta |> transmute(vid, gid, year = year + 1L, d_prev = d)
same <- delta |> transmute(vid, gid, year, d_same = d)

# Per vessel-year coverage of each rule on this year's fixes
vy <- fx |> inner_join(as_dataset(gp), by = c("gid", "provider")) |>
  inner_join(as_dataset(prev), by = c("vid", "gid", "year")) |>
  inner_join(as_dataset(same), by = c("vid", "gid", "year")) |>
  inner_join(decl, by = "gid") |>
  group_by(vid, gid, year) |>
  summarise(fixes = n(), d_prev = min(d_prev),
            gear_prov    = mean(as.numeric(speed >= g05 & speed <= g95)),
            shifted_prev = mean(as.numeric(speed >= g05 + d_prev & speed <= g95 + d_prev)),
            shifted_same = mean(as.numeric(speed >= g05 + d_same & speed <= g95 + d_same)),
            declared     = mean(as.numeric(speed >= d1 & speed <= d2)), .groups = "drop") |>
  collect()

cat("\nfix-weighted share of tow fixes kept\n")
vy |> group_by(gid) |>
  summarise(vessel_years = n(), total_fixes = sum(fixes),
            across(c(gear_prov, shifted_prev, shifted_same, declared), \(z) weighted.mean(z, fixes))) |> print()

cat("\nshare of vessel-years keeping less than 80 % / 85 % of their fixes\n")
vy |> group_by(gid) |>
  summarise(across(c(gear_prov, shifted_prev, shifted_same, declared),
                   list(lt80 = \(z) mean(z < .80), lt85 = \(z) mean(z < .85)))) |> t() |> print()

cat("\nvessels with a large previous-year offset (|delta| > 0.3 kn): where the shift should matter\n")
vy |> filter(abs(d_prev) > 0.3) |> group_by(gid) |>
  summarise(vessel_years = n(), across(c(gear_prov, shifted_prev, shifted_same, declared), \(z) weighted.mean(z, fixes))) |> print()
