# Mobile-ids that are heard with TWO vessels at once, kept as a table.
#
# Input:  curated/check/ais_key_segments.parquet, curated/check/ais_key_audit_w1.parquet,
#         curated/ais/ping (other providers), curated/vessel/{vessel,vessel_identity}.parquet
# Output: curated/check/ais_key_twins.parquet - one row per (mobile-id, segment, vid, twin vid)
#
# The segment table gives a mobile-id ONE vid at a time, because it has to tile. When W1 (a vid's
# own other-provider AIS, co-located with the mobile-id) confirms a SECOND vid in >= 3 months of
# the same segment, the table records it as `twin_vid`. This check keeps every such case, says what
# kind it is, and is the place to look for the cases where AIS goes wrong: a mobile-id cannot sit
# within 2 km of two vessels that are far apart, so when it appears to, either the identifier
# labels are ambiguous or a clock or a feed is off.
#
# Kinds, in this order (a row gets the first that fits):
#   shared MMSI      the registry gives ONE MMSI to both vids over overlapping periods - a single
#                    transponder, two hulls on paper; the provider label alone cannot tell them apart;
#   apart, both     both are confirmed for the same months, yet their OWN tracks are more than 10 km
#   confirmed        apart in those months (median): the two hulls are together part of the time and
#                    apart the rest, so the mobile-id fits each at different moments. Measured: all
#                    three cases involve a tug (usage class 50) and its tow, i.e. towing. NOT an AIS
#                    fault; no case where an AIS position itself is wrong has been found. Still the
#                    cases where the STK label alone cannot say which hull it is, only the MMSI could;
#   travel together  their own tracks are within 2 km of each other for >= 80 % of matched pings and
#                    the MMSIs differ: two hulls in company (paired gear, a tender, a tow), or one hull
#                    with two transponders;
#   partial          both confirmed but neither pattern above (tracks agree only part of the time).
#
# This check REPORTS. It never writes a vid. Identifiers are vid and MMSI; names are not read.

library(dplyr)
library(tidyr)
library(nanoparquet)

PING_GLOB <- file.path(fd_path("curated", "ais", "ping"), "year=*", "*.parquet")
seg <- read_parquet(fd_curated("check", "ais_key_segments.parquet")) |>
  filter(!is.na(twin_vid), !is.na(vid)) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
w1 <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet")) |>
  filter(score >= .8) |>
  transmute(mid, vid, ym = y * 12L + m - 1L)
reg <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> select(vid, mmsi_reg = mmsi, mclass, loa)
ident <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  transmute(vid = as.integer(vid), mmsi, t1 = as.Date(t1), t2 = as.Date(t2)) |> filter(!is.na(mmsi))

ym_of <- function(d) { lt <- as.POSIXlt(d); (lt$year + 1900L) * 12L + lt$mon }

# Months in which BOTH vids are confirmed against this mobile-id, inside the segment
both <- seg |>
  select(mid, seg_no, vid, twin_vid, d1, d2) |>
  inner_join(w1, by = c("mid", "vid"), relationship = "many-to-many") |>
  inner_join(rename(w1, twin_vid = vid), by = c("mid", "twin_vid", "ym"), relationship = "many-to-many") |>
  filter(ym >= ym_of(d1), ym <= ym_of(d2)) |>
  group_by(mid, seg_no, vid, twin_vid) |>
  summarise(months_both = n(), months = list(ym), .groups = "drop")

# Does the registry give one MMSI to both vids over overlapping periods?
shared <- both |>
  select(mid, seg_no, vid, twin_vid) |>
  inner_join(ident, by = "vid", relationship = "many-to-many") |>
  inner_join(rename(ident, twin_vid = vid, t1b = t1, t2b = t2), by = c("twin_vid", "mmsi"), relationship = "many-to-many") |>
  filter(t1 <= t2b, t1b <= t2) |>
  distinct(mid, seg_no, vid, twin_vid) |> mutate(shared_mmsi = TRUE)

# How far apart are the two vids' OWN tracks in the months both are confirmed?
con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
track_gap <- function(v, w, months) {
  DBI::dbExecute(con, sprintf("create or replace temp table a as select time, lat, lon from read_parquet('%s') where provider <> 'stk' and vid = %d and year(time) * 12 + month(time) - 1 in (%s)",
                              PING_GLOB, v, paste(months, collapse = ",")))
  DBI::dbExecute(con, sprintf("create or replace temp table b as select time, lat, lon from read_parquet('%s') where provider <> 'stk' and vid = %d and year(time) * 12 + month(time) - 1 in (%s)",
                              PING_GLOB, w, paste(months, collapse = ",")))
  r <- DBI::dbGetQuery(con, "with p as (select a.time, a.lat, a.lon, b.time bt, b.lat bla, b.lon blo from a asof join b on a.time >= b.time),
      q as (select a.time, a.lat, a.lon, b.time bt, b.lat bla, b.lon blo from a asof join b on a.time <= b.time),
      u as (select * from p union all select * from q),
      m as (select time, lat, lon, bla, blo, abs(epoch(time) - epoch(bt)) dt, row_number() over (partition by time, lat, lon order by abs(epoch(time) - epoch(bt))) rn from u where bt is not null)
    select count(*) n, median(111.2 * sqrt(power(lat - bla, 2) + power((lon - blo) * cos(radians(lat)), 2))) med_km,
           avg(case when 111.2 * sqrt(power(lat - bla, 2) + power((lon - blo) * cos(radians(lat)), 2)) <= 2 then 1.0 else 0 end) within2
    from m where rn = 1 and dt <= 600")
  tibble::as_tibble(r)
}
gaps <- bind_rows(lapply(seq_len(nrow(both)), function(i) {
  g <- track_gap(both$vid[i], both$twin_vid[i], both$months[[i]])
  bind_cols(both[i, c("mid", "seg_no", "vid", "twin_vid")], g) }))
DBI::dbDisconnect(con, shutdown = TRUE)

out <- seg |>
  select(mid, seg_no, vid, twin_vid, d1, d2, source, pings, startup_phase) |>
  left_join(select(both, -months), by = c("mid", "seg_no", "vid", "twin_vid")) |>
  left_join(shared, by = c("mid", "seg_no", "vid", "twin_vid")) |>
  left_join(rename(gaps, matched_pings = n, own_tracks_median_km = med_km, own_tracks_within2 = within2),
            by = c("mid", "seg_no", "vid", "twin_vid")) |>
  left_join(rename(reg, mmsi_a = mmsi_reg, mclass_a = mclass, loa_a = loa), by = "vid") |>
  left_join(rename(reg, twin_vid = vid, mmsi_b = mmsi_reg, mclass_b = mclass, loa_b = loa), by = "twin_vid") |>
  mutate(shared_mmsi = coalesce(shared_mmsi, FALSE),
         tug_involved = mclass_a %in% c(50, 65) | mclass_b %in% c(50, 65),
         months_both = coalesce(months_both, 0L),
         kind = case_when(
           shared_mmsi                                                          ~ "shared MMSI",
           !is.na(own_tracks_median_km) & matched_pings >= 30 & own_tracks_median_km > 10 ~ "apart, both confirmed",
           !is.na(own_tracks_within2) & matched_pings >= 30 & own_tracks_within2 >= .8    ~ "travel together",
           .default = "partial")) |>
  arrange(desc(kind == "apart, both confirmed"), desc(pings))

print(out |> group_by(kind) |> summarise(segments = n(), mids = n_distinct(mid), pings = sum(pings), .groups = "drop") |>
        knitr::kable(caption = "ais_key_twins"))

write_curated(out, fd_curated("check", "ais_key_twins.parquet"),
              inputs = c(segments = fd_curated("check", "ais_key_segments.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         vessel = fd_curated("vessel", "vessel.parquet")))
