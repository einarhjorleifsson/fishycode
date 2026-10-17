# aflaskeyti_trip.R — trips for the ERS catch reports: a vessel's hauls up to a landing in Iceland, else to a gap.
# Side: preprocessing (logbook and landings). See plan 014 and plan 026 §4.
#
# Input:  staging/aflaskeyti/{station,trip}.parquet   (.sid, .tid; the adapter's runs give the vid)
#         staging/aflaskeyti/time.parquet             (t1-t4 in UTC; curate/corrections/aflaskeyti_local_time.R)
#         curated/landing/{landings,catch}.parquet    (.lid, vid, date, hid, pid; kg)
#         staging/{afli,fs_afladagbok,adb}/trip.parquet (vid, T1, T2: the Icelandic logbook trips)
# Output: staging/aflaskeyti/trip_landing.parquet     (.tid, vid, T1, T1_basis, hid1, T2, T2_basis, hid2, pid2,
#                                                      source, schema) — replaces the adapter's trips
#         staging/aflaskeyti/station_trip.parquet     (.sid, .tid)
#
# The catch reports hold no trip. ais_catch.R takes one source per trip, and a landing that no logbook trip claims
# (lid_map) carries its own catch, so a foreign trip that missed its landing in Iceland would be counted twice. Here
# a trip ends at the landing, dated and placed by it, so that link_lid_map.R claims it at its first step (vid, date,
# port). Reconciling the logbook with the landings is preprocessing's (plan 014); no AIS is read.
#
# Rule, measured on the 2,778 hauls and the 918 landings of their vessels in Iceland (plan 026 §4):
#   1. a trip ends at a landing that falls between a haul's end date and the next haul's start date, and no more
#      than LANDING_MAX_D days after the haul: T2 its date, hid2 and pid2 its port, basis "reconstructed". A haul
#      with several such landings ends at the first. Landings are known to the day, so a landing on a day two hauls
#      share may fall in either's window: it goes to the haul followed by the longest gap, since a vessel lands
#      while it is not fishing. 73 of 435 Norwegian landings fall within 48 h of the next haul, so landings cut first;
#   2. otherwise a trip ends where the gap to the next haul is GAP_MAX hours or more: T2 empty, basis "none" (landed
#      abroad, or later than LANDING_MAX_D days);
#   3. T1 is the trip's first haul time, basis "synthesised": a bound on departure, never a departure.
# A landing of no weight (a changed or reversed landing, plan 025) does not cut a trip. Nor does a landing after a
# haul that lies inside an Icelandic logbook trip of the same vessel (staged afli, fs_afladagbok or adb; from T1 to
# the day after T2): the haul is a day that trip's logbook lacks, and the landing is that trip's. The first scratch
# merge had Icelandic vessel 2903's one haul of 2018-05-08 take, at lid_map's exact step, the landing its afli trip
# of 2018-05-05..10 matched at one day off (plan 026 §11).

library(dplyr)
library(lubridate)

SCHEMA        <- "aflaskeyti"
GAP_MAX       <- 48   # hours: 95 % of gaps without a landing are below 23.4 h (Faroese) and 32.5 h (Norwegian)
LANDING_MAX_D <- 7    # days: 454 of 460 Norwegian and 55 of 58 Faroese landings follow the last haul within 7 days

od <- function(...) duckdbfs::open_dataset(...) |> collect()

haul <- od(fd_staging("aflaskeyti", "station.parquet")) |>
  select(.sid, .tid) |>
  left_join(od(fd_staging("aflaskeyti", "trip.parquet")) |> select(.tid, vid), by = ".tid") |>
  left_join(od(fd_staging("aflaskeyti", "time.parquet")), by = ".sid", relationship = "one-to-one") |>
  transmute(.sid, vid, start = coalesce(t2, t1), end = coalesce(t3, t4, start)) |>
  arrange(vid, start, .sid) |>
  mutate(next_start = lead(start),
         gap_h      = as.numeric(difftime(next_start, end, units = "hours")),
         d0         = as_date(end),
         d1         = pmin(as_date(end) + days(LANDING_MAX_D), as_date(next_start), na.rm = TRUE),
         .by = vid)
stopifnot(!anyNA(haul$vid), !anyNA(haul$start))

land_kg <- od(fd_curated("landing", "catch.parquet")) |> summarise(kg = sum(catch, na.rm = TRUE), .by = c(.lid, schema))
land <- od(fd_curated("landing", "landings.parquet")) |>
  filter(vid %in% haul$vid) |>
  inner_join(land_kg |> filter(kg > 0), by = c(".lid", "schema")) |>
  select(.lid, schema_land = schema, vid, date, hid, pid, kg)

# hauls inside an Icelandic logbook trip: they claim no landing -----------------------------------------------------
lb_trip <- bind_rows(lapply(c("afli", "fs_afladagbok", "adb"), \(s)
  duckdbfs::open_dataset(fd_staging(s, "trip.parquet")) |>
    filter(vid %in% !!unique(haul$vid), !is.na(T1), !is.na(T2)) |>
    select(vid, T1, T2) |>
    collect())) |>
  mutate(w1 = floor_date(T1, "day"), w2 = floor_date(T2, "day") + days(2))
inside <- haul |>
  inner_join(lb_trip, by = join_by(vid, start >= w1, start < w2)) |>
  distinct(.sid)

# 1. a landing in the window after a haul ------------------------------------------------------------------------
claim <- haul |>
  anti_join(inside, by = ".sid") |>
  inner_join(land, by = join_by(vid, d0 <= date, d1 >= date)) |>
  mutate(gap_rank = coalesce(gap_h, Inf)) |>
  slice_max(tibble(gap_rank, end), n = 1, with_ties = FALSE, by = c(.lid, schema_land))
first_claim <- claim |>
  slice_min(tibble(date, .lid), n = 1, with_ties = FALSE, by = .sid)

# 2. and 3. cut, number, date -------------------------------------------------------------------------------------
haul <- haul |>
  left_join(first_claim |> select(.sid, T2_date = date, hid2 = hid, pid2 = pid), by = ".sid",
            relationship = "one-to-one") |>
  mutate(cut     = !is.na(T2_date) | coalesce(gap_h >= GAP_MAX, TRUE),
         trip_no = cumsum(lag(cut, default = TRUE)),
         .by     = vid) |>
  mutate(.tid = as.character(first(.sid)), .by = c(vid, trip_no))

trip <- haul |>
  summarise(vid  = first(vid),
            T1   = min(start),
            T2   = as.POSIXct(last(T2_date, order_by = start)),
            hid2 = as.integer(last(hid2, order_by = start)),
            pid2 = last(pid2, order_by = start),
            .by  = .tid) |>
  transmute(.tid, vid, T1, T1_basis = "synthesised", hid1 = NA_integer_,
            T2, T2_basis = if_else(is.na(T2), "none", "reconstructed"), hid2, pid2,
            source = "ERS DCA (dw_aflaskeyti)", schema = SCHEMA)
station_trip <- haul |> select(.sid, .tid)

stopifnot(!anyDuplicated(trip$.tid), nrow(station_trip) == nrow(haul),
          all(station_trip$.tid %in% trip$.tid))

# report ----------------------------------------------------------------------------------------------------------
unclaimed <- claim |> anti_join(first_claim, by = c(".lid", "schema_land"))
cat(sprintf("aflaskeyti trips: %d (%d dated by a landing in Iceland, %d ended at a gap)\n",
            nrow(trip), sum(!is.na(trip$T2)), sum(is.na(trip$T2))))
cat(sprintf("  hauls inside an Icelandic logbook trip, claiming no landing: %d\n", nrow(inside)))
cat(sprintf("  landings after a haul but not ending a trip (a second landing of the same gap): %d, %.1f t\n",
            nrow(unclaimed), sum(unclaimed$kg) / 1e3))

trip         |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "trip_landing.parquet"))
station_trip |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "station_trip.parquet"))
