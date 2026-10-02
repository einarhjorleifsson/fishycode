# vessel_speed_range_stability.R — is a vessel's towing-speed range stable across years? (plan 012, level 3)
#
# Input:  curated/ais/trail, curated/logbook/station_window.parquet, curated/reference/gear_window.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# Per (vid, gid, year): quantiles of speed in RECORDED tow windows (n_sid == 1), OTB gears 6-8, 2008-2024,
# the logger's 1.000 m/s placeholder excluded (plan 012 section 2f). A vessel-year needs MIN_N fixes.
#   A. How many vessels and vessel-years qualify, and how many have consecutive years.
#   B. Between- and within-vessel variance of the yearly median, after removing the provider offset (ICC).
#   C. The test that matters: apply the PREVIOUS year's [q05, q95] to this year's fixes and count the share
#      kept, against the same-year range (in-sample, nominally 90 %), the gear's declared range, and the
#      gear's pooled empirical q05-q95. The previous-year range never saw the fixes it is judged on.

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

# A. yearly ranges --------------------------------------------------------------
yr <- fx |> group_by(vid, gid, year) |>
  summarise(n = n(), q05 = quantile(speed, .05), q50 = median(speed), q95 = quantile(speed, .95), .groups = "drop") |>
  collect() |> filter(n >= MIN_N)

cat("vessel-years, vessels, and vessels with at least 3 / 5 qualifying years\n")
yr |> group_by(gid, vid) |> summarise(ny = n(), .groups = "drop") |>
  group_by(gid) |> summarise(vessels = n(), y3 = sum(ny >= 3), y5 = sum(ny >= 5), vessel_years = sum(ny)) |> print()

# B. between vs within vessel, provider offset removed ---------------------------
prov <- fx |> group_by(vid, gid, year, provider) |> summarise(n = n(), m = mean(speed), .groups = "drop") |> collect() |>
  inner_join(yr |> select(vid, gid, year), by = c("vid", "gid", "year")) |>
  group_by(vid, gid, year) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup()   # the year's main provider
adj <- yr |> inner_join(prov |> select(vid, gid, year, provider), by = c("vid", "gid", "year")) |>
  group_by(gid, provider) |> mutate(across(c(q05, q50, q95), \(z) z - mean(z), .names = "{.col}_adj")) |> ungroup()
icc <- function(x, g) {
  x <- x |> group_by(vid) |> filter(n() >= 3) |> ungroup()
  a <- anova(lm(reformulate("factor(vid)", g), data = x))
  k <- nrow(x) / n_distinct(x$vid)
  msb <- a$`Mean Sq`[1]; msw <- a$`Mean Sq`[2]
  c(vessels = n_distinct(x$vid), within_sd = sqrt(msw), between_sd = sqrt(max((msb - msw) / k, 0)),
    icc = max((msb - msw) / k, 0) / (max((msb - msw) / k, 0) + msw))
}
cat("\nyearly q05 / median / q95: within-vessel sd, between-vessel sd, ICC (kn; vessels with >= 3 years)\n")
for (g in 6:8) for (v in c("q05_adj", "q50_adj", "q95_adj")) {
  r <- icc(filter(adj, gid == g), v); cat(sprintf("gid %d %-8s vessels %3d  within %.2f  between %.2f  ICC %.2f\n", g, v, r[1], r[2], r[3], r[4]))
}

# C. previous year's range applied to this year's fixes -----------------------------
pooled <- fx |> group_by(gid) |>
  summarise(p05 = quantile(speed, .05), p95 = quantile(speed, .95), .groups = "drop") |> collect()
prev <- yr |> transmute(vid, gid, year = year + 1L, p1 = q05, p2 = q95)   # last year's range, keyed to this year
same <- yr |> transmute(vid, gid, year, s1 = q05, s2 = q95)
cov <- fx |>
  inner_join(as_dataset(prev), by = c("vid", "gid", "year")) |>
  inner_join(as_dataset(same), by = c("vid", "gid", "year")) |>
  inner_join(decl, by = "gid") |>
  inner_join(as_dataset(pooled), by = "gid") |>
  group_by(gid) |>
  summarise(fixes = n(),
            same_year   = mean(as.numeric(speed >= s1 & speed <= s2)),
            prev_year   = mean(as.numeric(speed >= p1 & speed <= p2)),
            declared    = mean(as.numeric(speed >= d1 & speed <= d2)),
            pooled_q05_95 = mean(as.numeric(speed >= p05 & speed <= p95))) |>
  collect()
cat("\nshare of tow fixes kept, vessels with a qualifying previous year\n"); print(cov)

# D. width: at equal coverage a narrower range excludes more non-tow speeds --------------
cat("\nwidth of the 5-95 % range in kn: mean over vessel-years vs the gear's pooled range and declared range\n")
yr |> group_by(gid) |> summarise(vessel_year_width = mean(q95 - q05), sd_of_width = sd(q95 - q05)) |>
  left_join(pooled |> transmute(gid, pooled_width = p95 - p05), by = "gid") |>
  left_join(decl |> collect() |> transmute(gid, declared_width = d2 - d1), by = "gid") |> print()
