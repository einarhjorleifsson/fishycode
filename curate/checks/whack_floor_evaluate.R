# whack_floor_evaluate.R — rb_whack_clean(min_dt_s = 10) against the production labels, whole AIS record.
#
# Input:  staging/ais/ping_tagged (pings with a vid and lon != lat, as curate/ais_ping_clean.R does),
#         staging/ais/ping_whacky (production flags) and ping_clean (production kept track); read-only.
#         Needs ramb >= 2026.10.08 (rb_whack_clean() with min_dt_s).
# Output: tempdir()/whack_floor_year.csv   one row per year
#         tempdir()/whack_floor_stage.csv  production stage x new stage, per year
#         Env var YEARS="2016" (comma separated) runs only those years.
#
# "Production" is whatever ping_whacky / ping_clean hold when this runs. On 2026-10-08 that was the
# old method (ramb 81cef38: sda adds 1 s to every step, the forward scan floors at 1e-6 s), so the
# comparison isolates the time-step floor. After ais_ping_clean is rebuilt with the new ramb the two
# sides agree and the script only shows that they do.
# Since decision 069 production also takes out cross-feed duplicates before the filter, so after that
# rebuild the two sides differ by those 6.57 M pings; the result below is the run before it.
#
# Kept-track legs are computed in R a month at a time (a whole year of DuckDB windows ran out of
# memory at 6 GB); a leg across a month boundary is left out on both sides.
#
# Result 2026-10-08, 543,638,789 pings 2007-2026, 16 min, 8.1 GB peak:
#   flagged 2,873,631 (0.53 %) -> 1,448,373 (0.27 %)
#   given back 1,466,001: 96 % between two feeds, 92 % within 50 m of the ping before, 9 real jumps
#     (> 200 m at > 25 kn); 95 % of them had been flagged by the forward scan
#   newly flagged 40,743: mostly interleaved streams (two transmitters on one id, decision 047);
#     14 of them were real jumps the production track kept
#   kept legs > 1 km at > 25 kn 716 -> 706; kept track 220,744,966 -> 220,738,196 km (-0.003 %)
#   2007-2012 (one feed) barely change; 2017-2024 (two feeds merged) change most

source(here::here("R", "paths.R"))
source(here::here("R", "duckdb_temp.R"))
source(here::here("curate/checks", "whack_shims.R"))  # adapters for ramb functions removed 2026-10-11
suppressMessages({library(dplyr); library(duckdbfs); library(ramb)})
con <- cached_connection()
invisible(DBI::dbExecute(con, "SET memory_limit = '6GB'"))
invisible(DBI::dbExecute(con, "SET threads = 4"))
configure_duckdb_temp()
st <- function(...) open_dataset(fd_staging("ais", ...))
MS_MAX <- 25 * 0.514444
key <- c("vid", "time", "lon", "lat", "provider")

hav <- function(lon1, lat1, lon2, lat2) {
  r <- pi / 180
  a <- sin((lat2 - lat1) * r / 2)^2 + cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  2 * 6371000 * asin(sqrt(pmin(1, a)))
}
# Step from the previous ping of the same vessel, for every ping of a kept track (in R, one month
# at a time: a whole year in DuckDB windows ran out of memory). First ping of a vessel: NA.
steps <- function(x) {
  x <- arrange(x, vid, time, lon, lat); n <- nrow(x)
  first <- c(TRUE, x$vid[-1] != x$vid[-n])
  i0 <- c(NA, seq_len(n - 1)); i0[first] <- NA
  x$dist <- hav(x$lon[i0], x$lat[i0], x$lon, x$lat)
  x$dt <- as.numeric(x$time) - as.numeric(x$time[i0])
  x$mixed <- x$provider[i0] != x$provider
  x
}
wrong <- function(x, m) !is.na(x$dist) & x$dist > m & x$dist / pmax(x$dt, 1) > MS_MAX
track_sum <- function(x) tibble(km = sum(x$dist, na.rm = TRUE) / 1000,
                                wrong_1km = sum(wrong(x, 1000)), wrong_200m = sum(wrong(x, 200)))
desc_sum <- function(x) tibble(n = nrow(x), mixed = sum(x$mixed, na.rm = TRUE),
                               under_50m = sum(x$dist < 50, na.rm = TRUE),
                               wrong_200m = sum(wrong(x, 200)), dist = list(x$dist))

years <- if (nzchar(Sys.getenv("YEARS"))) as.integer(strsplit(Sys.getenv("YEARS"), ",")[[1]]) else 2007:2026
out <- list(); stages <- list()
for (yr in years) {
  t0 <- Sys.time()
  tagged <- st("ping_tagged") |> filter(year == yr, !is.na(vid), lon != lat) |>
    select(vid, time, lon, lat, provider)
  new <- rb_whack_clean(tagged, kn_max = 25, min_dt_s = 10, batch_pings = 2e6)
  f_new <- new |> filter(whack) |> select(all_of(key), whack_stage) |> collect() |>
    distinct(across(all_of(key)), .keep_all = TRUE)
  f_old <- st("ping_whacky") |> filter(year == yr, whack_stage != "invalid") |>
    select(all_of(key), whack_stage) |> collect() |> distinct(across(all_of(key)), .keep_all = TRUE)

  both <- inner_join(f_old, f_new, by = key, suffix = c("_old", "_new"))
  stages[[as.character(yr)]] <- both |> count(old = whack_stage_old, new = whack_stage_new) |>
    bind_rows(anti_join(f_old, f_new, by = key) |> count(old = whack_stage) |> mutate(new = "kept")) |>
    bind_rows(anti_join(f_new, f_old, by = key) |> count(new = whack_stage) |> mutate(old = "kept")) |>
    mutate(year = yr)

  gb_keys <- anti_join(f_old, f_new, by = key) |> select(all_of(key))   # flagged before, kept now
  nf_keys <- anti_join(f_new, f_old, by = key) |> select(all_of(key))   # kept before, flagged now
  sn <- so <- gbs <- nfs <- list()
  for (m in 1:12) {
    tg <- tagged |> filter(month(time) == !!m) |> collect()
    if (nrow(tg) == 0) next
    kn <- steps(anti_join(tg, f_new, by = key))
    ko <- steps(st("ping_clean") |> filter(year == yr, month(time) == !!m) |> select(all_of(key)) |> collect())
    sn[[m]] <- track_sum(kn); so[[m]] <- track_sum(ko)
    gbs[[m]] <- desc_sum(semi_join(kn, gb_keys, by = key))   # their step in the NEW kept track
    nfs[[m]] <- desc_sum(semi_join(ko, nf_keys, by = key))   # their step in the OLD kept track
  }
  s_new <- bind_rows(sn) |> summarise(across(everything(), sum))
  s_old <- bind_rows(so) |> summarise(across(everything(), sum))
  gb <- bind_rows(gbs); nf <- bind_rows(nfs)
  gb_d <- unlist(gb$dist); nf_d <- unlist(nf$dist)
  gb <- gb |> select(-dist) |> summarise(across(everything(), sum)) |> mutate(med_m = median(gb_d, na.rm = TRUE))
  nf <- nf |> select(-dist) |> summarise(across(everything(), sum)) |> mutate(med_m = median(nf_d, na.rm = TRUE))

  out[[as.character(yr)]] <- tibble(
    year = yr, pings = dplyr::pull(dplyr::count(tagged)),
    flagged_old = nrow(f_old), flagged_new = nrow(f_new),
    given_back = nrow(gb_keys), gb_found = gb$n, gb_mixed = gb$mixed, gb_under_50m = gb$under_50m,
    gb_med_m = gb$med_m, gb_wrong_200m = gb$wrong_200m,
    new_flags = nrow(nf_keys), nf_found = nf$n, nf_mixed = nf$mixed, nf_med_m = nf$med_m,
    nf_wrong_200m = nf$wrong_200m,
    km_old = s_old$km, km_new = s_new$km,
    wrong_1km_old = s_old$wrong_1km, wrong_1km_new = s_new$wrong_1km,
    wrong_200m_old = s_old$wrong_200m, wrong_200m_new = s_new$wrong_200m,
    min = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1))
  print(out[[as.character(yr)]], width = 250)
  write.csv(bind_rows(out), file.path(tempdir(), "whack_floor_year.csv"), row.names = FALSE)
  write.csv(bind_rows(stages), file.path(tempdir(), "whack_floor_stage.csv"), row.names = FALSE)
}
message("written to ", tempdir())
