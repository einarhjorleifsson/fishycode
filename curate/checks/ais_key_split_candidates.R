# Silences in an STK mobile-id where a human would split it in two vids.
# Side: once (vessel key). See plan 014.
#
# Input:  curated/vessel/vessel_ais_key.parquet, vessel.parquet, vessel_identity.parquet,
#         raw/ais/stk/trail
# Output: curated/check/ais_key_split_candidates.parquet - one row per silence >= 180 d on
#         a mobile-id the key gives ONE Icelandic vid across
#
# The key holds one vid per period row, and a mobile-id can change hands under the same
# identifier strings. The manual match split some by hand. This emulates what the human
# read (R/audit_split_reader.R) and lists every silence with how many of four evidence
# families fire: >= 3 is strong (all 19 silences W1 could check were real vessel changes,
# decision 047), exactly 2 is worth a look (7 of 22). `key_splits` marks the silences the key
# already gives two different vids across, so what remains is a split the key does not have.
#
# This check REPORTS. It never writes a vid. A reviewed conclusion re-enters through
# overrides/ as an input (AGENTS.md: the loop is broken by a human, not computed).
# Icelandic vessels are the target. Only 3700-4999 is foreign: Icelandic vids resume above 4999
# (small boats), so the filter excludes that range and nothing else.

library(dplyr)
library(nanoparquet)

STK_GLOB <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
key <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
key_v <- key |>
  filter(!is.na(vid), vid > 0, !vid %in% 3700:4999, entity_class == "vessel") |>
  select(mid, K = vid, d1, d2)
reg <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> select(vid, yh2)
identity <- read_parquet(fd_curated("vessel", "vessel_identity.parquet"))

con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
days <- dplyr::as_tibble(DBI::dbGetQuery(con, sprintf(
  "select mid, cast(time as date) d from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1, 2", STK_GLOB)))

sil <- split_silences(days, key_v)
pos <- split_end_positions(con, sil, STK_GLOB)

wk <- dplyr::as_tibble(local({
  bin <- function(col, e, pre) paste(sprintf("sum(case when %s >= %g%s then 1 else 0 end) %s%d", col, e,
                                             c(sprintf(" and %s < %g", col, e[-1]), ""), pre, seq_along(e) - 1), collapse = ", ")
  DBI::dbGetQuery(con, sprintf("
    with p as (select mid, time, lat, lon, speed, epoch(time) - epoch(lag(time) over (partition by mid order by time)) dt
               from read_parquet('%s') where time >= timestamp '2007-06-01' and speed is not null and lat between 55 and 75)
    select mid, cast(date_trunc('week', time) as date) wk, count(*) n, sum(lat) slat, sum(lon) slon, %s, %s
    from p where dt is null or dt > 0 group by 1, 2 order by 1, 2", STK_GLOB,
    bin("speed", c(0, .5, 1, 2, 3, 4, 6, 8, 10, 12, 15), "sp"), bin("dt", c(0, 120, 300, 600, 1200, 3600, 10800, 43200), "dt")))
}))
shift <- split_profile_shift(wk, sil)
hand  <- split_registry_handover(con, sil, key, identity)

# The key vid's own registry ends at the silence. yh2 never exceeds the snapshot horizon
# (corrections/vessel_registry_stale_lifetime.yml), so an end AT the horizon is not an end.
HORIZON <- max(reg$yh2, na.rm = TRUE)

# What the key already does across each silence: a different vid on either side means it splits
key_at <- function(mid_, d_) {
  tibble(mid = mid_, d = d_) |>
    left_join(key_v, by = "mid", relationship = "many-to-many") |>
    filter(d1 <= d, d2 >= d) |> group_by(mid, d) |> slice(1) |> ungroup() |> select(mid, d, k = K)
}
key_after <- key_at(sil$mid, sil$d_next) |> rename(d_next = d, k_after = k)

out <- sil |>
  left_join(pos, by = "sid") |>
  left_join(shift, by = "sid") |>
  left_join(hand, by = "sid") |>
  left_join(reg, by = "vid") |>
  mutate(E_abroad = coalesce(E_abroad, FALSE),
         E_profile = coalesce(E_profile, FALSE),
         E_registry_handover = coalesce(E_registry_handover, FALSE),
         E_registry_end = !is.na(yh2) & yh2 < HORIZON & abs(yh2 - as.integer(format(d_prev, "%Y"))) <= 1,
         n_families = E_profile + E_abroad + E_registry_handover + E_registry_end,
         tier = case_when(n_families >= 3 ~ "strong", n_families == 2 ~ "review", .default = "weak")) |>
  left_join(key_after, by = c("mid", "d_next")) |>
  mutate(key_splits = !is.na(k_after) & k_after != vid) |>
  select(mid, vid, d_prev, d_next, gap, lat_last, lon_last, lat_first, lon_first, shift_space, shift_speed,
         E_profile, E_abroad, E_registry_handover, E_registry_end, n_families, tier, key_splits)

print(out |> count(tier, key_splits, name = "silences") |> knitr::kable(caption = "ais_key_split_candidates"))
DBI::dbDisconnect(con, shutdown = TRUE)

write_curated(out, fd_curated("check", "ais_key_split_candidates.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key_cascade.parquet"),
                         vessel = fd_curated("vessel", "vessel.parquet"),
                         vessel_identity = fd_curated("vessel", "vessel_identity.parquet")))
