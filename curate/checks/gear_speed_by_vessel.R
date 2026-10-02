# gear_speed_by_vessel.R — what explains towing speed beyond the gear? (plan 012, level 2)
#
# Input:  curated/ais/trail, curated/logbook/station_window.parquet, curated/vessel/vessel.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# Speed of fixes inside RECORDED tow windows (n_sid == 1) of the three OTB gears, 2008-2024, with the
# logger's 1.000 m/s placeholder excluded (plan 012 section 2f). Aggregated to (vid, year, gid, provider)
# in DuckDB; the variance decomposition is exact on those groups (total SS = within + between).
# Age is year - yh1, where yh1 is the year the hull first appears in the Hreidar registry: an upper bound
# on age, since a second-hand import appears later than it was built.

library(dplyr)
library(duckdbfs)
source(here::here("R/paths.R"))

sw <- open_dataset(fd_curated("logbook", "station_window.parquet")) |>
  filter(gid %in% 6:8) |> distinct(.sid, schema, gid)

grp <- open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2008, year <= 2024, n_sid == 1, win_basis == "recorded", phase == "tow",
         !is.na(speed), speed < 15, !(provider == "gps" & abs(speed - 1.943846) < 1e-4)) |>
  inner_join(sw, by = c(".sid", "schema")) |>
  group_by(vid, year, gid, provider) |>
  summarise(n = n(), m = mean(speed), s2 = sum(speed * speed), .groups = "drop") |>
  collect() |>
  mutate(ss = s2 - n * m^2)         # within-group sum of squares

v <- open_dataset(fd_curated("vessel", "vessel.parquet")) |>
  filter(flag == "ISL") |> select(vid, yh1, loa, kw, grt) |> collect() |>
  group_by(vid) |> slice(1) |> ungroup()

d <- grp |> left_join(v, by = "vid") |>
  mutate(age = year - yh1, lkw = log(kw), lloa = log(loa)) |>
  filter(n >= 200, !is.na(kw), !is.na(loa), !is.na(age), loa > 5, age >= 0)

# Share of the speed variance within a gear that each set of predictors explains
r2 <- function(g, f) {
  x <- d |> filter(gid == g)
  ss_tot <- sum(x$ss) + sum(x$n * (x$m - weighted.mean(x$m, x$n))^2)
  fit <- lm(f, data = x, weights = n)
  ss_mod <- sum(x$n * (fitted(fit) - weighted.mean(x$m, x$n))^2)
  ss_mod / ss_tot
}
forms <- list(
  "provider"                         = m ~ provider,
  "provider + log kW"                = m ~ provider + lkw,
  "provider + log LOA"               = m ~ provider + lloa,
  "provider + age"                   = m ~ provider + age,
  "provider + log kW + age"          = m ~ provider + lkw + age,
  "provider + log kW + log LOA + age"= m ~ provider + lkw + lloa + age,
  "provider + year"                  = m ~ provider + factor(year),
  "provider + vessel"                = m ~ provider + factor(vid))
res <- sapply(6:8, \(g) sapply(forms, r2, g = g))
colnames(res) <- c("6 fish", "7 nephrops", "8 shrimp")
print(round(res, 3))
# Of the speed variance that belongs to the vessel (provider + vessel, minus provider alone), the share that
# power, length and age together account for
cat("\nshare of the vessel-attributable variance explained by kW + LOA + age:\n")
print(round((res["provider + log kW + log LOA + age", ] - res["provider", ]) /
            (res["provider + vessel", ] - res["provider", ]), 2))

# Direction and size of the effects: change in mean tow speed (kn) per doubling of kW, and per 10 years of age
for (g in 6:8) {
  fit <- lm(m ~ provider + lkw + age, data = filter(d, gid == g), weights = n)
  cat("\ngid", g, ": per doubling of kW", round(coef(fit)["lkw"] * log(2), 3),
      "kn; per 10 years of age", round(coef(fit)["age"] * 10, 3), "kn; vessels", n_distinct(filter(d, gid == g)$vid), "\n")
}

# Do power and size separate the vessels? Mean tow speed by kW class (stk and astd only)
d |> filter(provider %in% c("stk", "astd")) |>
  mutate(kw_class = cut(kw, c(0, 300, 600, 1000, 1500, 3000, Inf))) |>
  group_by(gid, kw_class) |>
  summarise(vessels = n_distinct(vid), fixes = sum(n), mean_kn = weighted.mean(m, n), .groups = "drop") |>
  print(n = Inf)
