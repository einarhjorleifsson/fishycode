# Silences in an STK mobile-id where a human would split it in two vids.
#
# Input:  curated/vessel/vessel_ais_key.parquet, vessel.parquet, vessel_identity.parquet,
#         raw/ais/stk/trail, raw/ais/stk/stk_mobile_match-and-duals.ods
# Output: curated/check/ais_key_split_candidates.parquet - one row per silence >= 180 d on
#         a mobile-id the key gives ONE Icelandic vid across
#
# The key holds one vid per period row, and a mobile-id can change hands under the same
# identifier strings. The manual match split some by hand. This emulates what the human
# read (R/audit_split_reader.R) and lists every silence with how many of four evidence
# families fire: >= 3 is strong (all 19 silences W1 could check were real vessel changes,
# decision 047), exactly 2 is worth a look (7 of 22). `ods_split` marks the splits the
# human already made, so what remains is the human-style split the key does not have.
#
# This check REPORTS. It never writes a vid. A reviewed conclusion re-enters through
# overrides/ as an input (AGENTS.md: the loop is broken by a human, not computed).
# Icelandic vessels are the target; foreign vids (3700-4999) are excluded here.

library(dplyr)
library(nanoparquet)

STK_GLOB <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
key_v <- key |>
  filter(!is.na(vid), vid > 0, vid < 3700, entity_class == "vessel") |>
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

# The human's own splits: consecutive recorded rows on one mid with different vids
ods <- readODS::read_ods(fd_raw("ais", "stk", "stk_mobile_match-and-duals.ods")) |>
  as_tibble() |>
  filter(basis == "recorded", !is.na(vid), vid > 0) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2), vid = as.integer(vid)) |>
  arrange(mid, d1) |>
  group_by(mid) |>
  mutate(nxt_vid = lead(vid), nxt_d1 = lead(d1)) |>
  ungroup() |>
  filter(!is.na(nxt_vid), nxt_vid != vid) |>
  transmute(mid, d_end = d2, d_start = nxt_d1)

ods_hit <- sil |>
  inner_join(ods, by = "mid") |>
  filter(d_end >= d_prev - 3, d_start <= d_next + 3)

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
  mutate(ods_split = sid %in% ods_hit$sid) |>
  select(mid, vid, d_prev, d_next, gap, lat_last, lon_last, lat_first, lon_first, shift_space, shift_speed,
         E_profile, E_abroad, E_registry_handover, E_registry_end, n_families, tier, ods_split)

print(out |> count(tier, ods_split, name = "silences") |> knitr::kable(caption = "ais_key_split_candidates"))
DBI::dbDisconnect(con, shutdown = TRUE)

write_curated(out, fd_curated("check", "ais_key_split_candidates.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         vessel = fd_curated("vessel", "vessel.parquet"),
                         vessel_identity = fd_curated("vessel", "vessel_identity.parquet")))
