# Match merged logbook trips to landing register records.
# Side: preprocessing (logbook and landings). See plan 014.
# Builds a .tid → .lid crosswalk and writes it to lid_map.parquet.
#
# Input:  data/logbooks/{trip,station,fishing_sample,catch}.parquet
#         data/landings/{landings,catch}.parquet
#         data/gear/gear_mapping.parquet
# Output: curated/logbook/lid_map.parquet — .tid, schema, .lid, schema_land, date_land, hid_land, pid_land,
#         match_type, n_trips (trips on the landing; above 1 is a declared many-to-many)
#
# Does NOT write back into trip.parquet. It used to (left_join(lid_map) then
# overwrite trip.parquet in place) - that made logbook.R's own declared output
# a moving target from this script's side too, and the two targets fought over
# it: whichever ran last "won", so the other looked permanently outdated on
# every subsequent check regardless of whether any real input had changed. See
# curate/decisions/025-lid_map-stops-overwriting-trip-parquet.md. A consumer
# that wants .lid/match_type alongside trip.parquet joins lid_map.parquet
# onto it themselves, e.g. docs/landings-match.qmd already does.
#
# Eight-step cascade in decreasing key specificity.
# Each step operates only on trips/landings not consumed by earlier steps and
# accepts only unambiguous matches (exactly one .lid candidate per .tid).
#
#   Step 1 — exact (vid, date, hid)
#   Step 2 — (vid, date±1, hid): overnight trips / midnight-straddle
#   Step 3 — (vid, date): port dropped, same day
#   Step 4 — (vid, date±1): port dropped, one-day relaxation
#   Step 5 — (vid, date±2): systematic 2-day recording lag (~3,400 matches, 11:1 ratio)
#   Step 6 — demersal weight match: log-ratio ≤ WEIGHT_TOL_DEMERSAL, gap ≥ WEIGHT_MIN_GAP
#   Step 7 — pelagic weight match:  log-ratio ≤ WEIGHT_TOL_PELAGIC  (expect ~0 matches)
#   Step 8 — expected-date match: trips with recorded date > DATE_ERR_THRESHOLD days
#             from .tid-interpolated expected date; primarily a QA diagnostic

library(duckdbfs)
library(tidyverse)

# Parameters -------------------------------------------------------------------
WEIGHT_TOL_DEMERSAL <- log(1.3)   # accept if within ~30% of landing weight
WEIGHT_TOL_PELAGIC  <- log(2.0)   # accept if within ~100% (catch transfers)
WEIGHT_MIN_GAP      <- log(1.5)   # best must be ≥ 1.5× closer than runner-up
DATE_ERR_THRESHOLD  <- 35L        # days; larger deviation flags likely wrong-date entry
DATE_ERR_WINDOW     <- 3L         # ± days around expected date to search

## Landing register -------------------------------------------------------------
# One row per (vid × date × hid); catch summed across species. The collapse
# from multiple per-delivery records to one trip-level `.lid` (min of the raw
# id within the group, per source) happens upstream in curate/landing.R, not
# here - this script only reads the already-collapsed curated table.
#
# No upper date bound - the earlier `date <= ymd("2025-12-12")` was a literal
# carried over verbatim from the pre-restructuring codebase (git blame:
# bde740b, "Migrate code from both archives"), never revisited, and paired
# with nothing on the `trip` side below (which was always unbounded). It
# silently dropped every 2026 landings match once FS_DATE_MAX's handover to
# adb went live (curate/decisions/023) - measured 2026-09-23: 4,962 adb trips
# in trip.parquet, 0 reaching lid_map. See
# curate/decisions/027-lid_map-drops-upper-date-bound.md.
land <-
  duckdbfs::open_dataset(fd_curated("landing", "landings.parquet")) |> collect() |>
  filter(vid > 0, date >= ymd("2007-09-01")) |>
  # Renamed to schema_land: curate/plans/007 added a landings-side `schema`
  # (agf/lods), which otherwise collides with this script's own `schema`
  # (the logbook source system, afli/fs_afladagbok/adb) once trip and land
  # are joined below - dplyr would silently produce schema.x/schema.y and
  # every downstream `select(schema, ...)` would fail (measured 2026-09-26).
  # NOT a fix for the deeper issue this rename exposed: 104,192 `.lid`
  # values are shared between agf-schema and lods-schema rows, and every
  # uniqueness check in the cascade below (n_distinct(.lid), %in%) keys
  # on `.lid` alone, not `(.lid, schema_land)` - a loose match step
  # could in principle treat an agf and an unrelated lods candidate as one
  # unambiguous match. Flagged, not hardened, here (curate/plans/007 §4).
  rename(schema_land = schema) |>
  left_join(
    duckdbfs::open_dataset(fd_curated("landing", "catch.parquet")) |> collect() |>
      group_by(.lid) |>
      summarise(catch = sum(catch), .groups = "drop"),
    by = ".lid"
  )

## Logbook trips with total catch -----------------------------------------------
trip <-
  duckdbfs::open_dataset(fd_curated("logbook", "trip.parquet")) |> collect() |>
  mutate(date = as_date(T2), hid = hid2) |>
  left_join(
    duckdbfs::open_dataset(fd_curated("logbook", "catch.parquet")) |> collect() |>
      left_join(
        duckdbfs::open_dataset(fd_curated("logbook", "station.parquet")) |> collect() |> select(.sid, .tid, schema),
        by = c(".sid", "schema")
      ) |>
      filter(!is.na(.tid)) |>
      group_by(.tid, schema) |>
      summarise(catch = sum(as.numeric(catch), na.rm = TRUE), .groups = "drop"),
    by = c(".tid", "schema")
  ) |>
  filter(catch > 0) |>
  # .tid is unique only within a schema (TODO 41): the trip is (.tid, schema), carried as one key .tk
  mutate(.tk = paste(schema, .tid, sep = "|")) |>
  select(.tk, .tid, vid, date, hid, port, catch, schema)

## Cascade helpers --------------------------------------------------------------
try_match <- function(unmatched, land_tbl, by, type) {
  unmatched |>
    inner_join(land_tbl, by = by) |>
    group_by(.tk) |>
    filter(n_distinct(.lid) == 1) |>
    slice(1) |>
    ungroup() |>
    mutate(match_type = type)
}

try_match_weight <- function(unmatched, land_tbl, consumed_land, tol, gap, type) {
  unmatched |>
    inner_join(
      land_tbl |> filter(!.lid %in% consumed_land),
      by = c("vid", "date")
    ) |>
    mutate(score = abs(log(catch / catch_land))) |>
    filter(is.finite(score), score <= tol) |>
    group_by(.tk) |>
    arrange(score, .by_group = TRUE) |>
    filter(n() == 1 | (score[2] - score[1]) >= gap) |>
    slice(1) |>
    ungroup() |>
    mutate(match_type = type)
}

## Steps 1–5: key-based matching -----------------------------------------------
# Step 1: exact key
m1 <- try_match(trip, land, c("vid", "date", "hid"), "01 exact")

# Shifted land tables reused across steps 2, 4, and weight matching
land_pm1 <- bind_rows(
  land |> mutate(date = date - 1),
  land |> mutate(date = date + 1)
)
land_pm2 <- bind_rows(
  land |> mutate(date = date - 2),
  land |> mutate(date = date + 2)
)

# Step 2: date ±1 day, port still required
m2 <- try_match(
  trip     |> filter(!.tk      %in% m1$.tk),
  land_pm1 |> filter(!.lid %in% m1$.lid),
  c("vid", "date", "hid"),
  "02 exact ±1 day"
)

# Step 3: same day, port dropped
m3 <- try_match(
  trip |> filter(!.tk      %in% c(m1$.tk,      m2$.tk)),
  land |> filter(!.lid %in% c(m1$.lid, m2$.lid)),
  c("vid", "date"),
  "03 vid_date"
)

# Step 4: ±1 day, port dropped
m4 <- try_match(
  trip     |> filter(!.tk      %in% c(m1$.tk,      m2$.tk,      m3$.tk)),
  land_pm1 |> filter(!.lid %in% c(m1$.lid, m2$.lid, m3$.lid)),
  c("vid", "date"),
  "04 vid_date ±1"
)

# Step 5: ±2 days, port dropped
# All newly resolved trips use exactly a 2-day offset (systematic recording lag).
# ±3 drops the signal-to-ambiguity ratio from 11:1 to ~2:1; not worth the risk.
m5 <- try_match(
  trip     |> filter(!.tk      %in% c(m1$.tk,      m2$.tk,      m3$.tk,      m4$.tk)),
  land_pm2 |> filter(!.lid %in% c(m1$.lid, m2$.lid, m3$.lid, m4$.lid)),
  c("vid", "date"),
  "05 vid_date ±2"
)

## Steps 6–7: catch-weight matching --------------------------------------------
# gear_mapping has multiple rows per gid (old/new code versions); derive the
# pelagic flag directly from the known gid set rather than joining on gear name.
pelagic_gids <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |>
  filter(gear %in% c("OTM", "PS", "HMS")) |>
  distinct(gid) |>
  pull(gid)

trip_gear <-
  duckdbfs::open_dataset(fd_curated("logbook", "fishing_sample.parquet")) |> collect() |>
  mutate(.tk = paste(schema, .tid, sep = "|")) |>
  count(.tk, gid) |>
  group_by(.tk) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(pelagic = gid %in% pelagic_gids) |>
  select(.tk, gid, pelagic)

# Combined land table covering date 0 and ±1 for weight steps
land_w <- bind_rows(land, land_pm1) |> rename(catch_land = catch)

consumed_so_far <- c(m1$.lid, m2$.lid, m3$.lid, m4$.lid, m5$.lid)

# Step 6: demersal weight match — tight tolerance
unmatched_dem <- trip |>
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk)) |>
  left_join(trip_gear |> select(.tk, pelagic), by = ".tk") |>
  # coalesce, not isTRUE(): isTRUE() of a whole column is one FALSE, so step 6 kept pelagic trips and step 7
  # got none (TODO 43). A trip with no gear counts as demersal, as before.
  filter(!coalesce(pelagic, FALSE))

m6 <- try_match_weight(
  unmatched_dem, land_w, consumed_so_far,
  tol = WEIGHT_TOL_DEMERSAL, gap = WEIGHT_MIN_GAP,
  type = "06 weight_dem"
)

# Step 7: pelagic weight match — loose tolerance; expect ~0 matches
unmatched_pel <- trip |>
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk)) |>
  left_join(trip_gear |> select(.tk, pelagic), by = ".tk") |>
  filter(coalesce(pelagic, FALSE))

m7 <- try_match_weight(
  unmatched_pel, land_w,
  c(consumed_so_far, m6$.lid),
  tol = WEIGHT_TOL_PELAGIC, gap = WEIGHT_MIN_GAP,
  type = "07 weight_pel"
)

## Step 8: expected-date match (wrong-date entries) ----------------------------
# Fit approxfun curves (tid_num → expected_date) per tid range from matched
# trips. Flag unmatched trips with large deviations; search for a landing on
# the expected date. Yield ~36 matches; primary value is the date_error_days
# QA column on unmatched trips.
date_origin <- as.Date("2007-01-01")

build_approx <- function(ref_trip) {
  approxfun(
    as.numeric(ref_trip$.tid),
    as.numeric(ref_trip$date - date_origin),
    rule = 2
  )
}

matched_trip <- trip |>
  filter(.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk, m7$.tk))

approx_afli_pos <- build_approx(matched_trip |>
  filter(schema == "afli", as.numeric(.tid) > 0))
approx_afli_neg <- build_approx(matched_trip |>
  filter(schema == "afli", as.numeric(.tid) < 0, as.numeric(.tid) > -1e9))
approx_fs <- build_approx(matched_trip |>
  filter(schema == "fs_afladagbok"))

unmatched_post7 <- trip |>
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk, m7$.tk)) |>
  filter(year(date) >= 2007) |>
  mutate(tid_num = as.numeric(.tid)) |>
  mutate(expected_date = date_origin + case_when(
    schema == "fs_afladagbok"                      ~ approx_fs(tid_num),
    schema == "afli" & tid_num > 0                 ~ approx_afli_pos(tid_num),
    schema == "afli" & tid_num < 0 & tid_num > -1e9 ~ approx_afli_neg(tid_num),
    TRUE                                           ~ NA_real_
  )) |>
  mutate(date_error_days = as.numeric(date - expected_date))

land_exp <- seq(-DATE_ERR_WINDOW, DATE_ERR_WINDOW) |>
  purrr::map(\(d) land |> mutate(exp_date = date + d)) |>
  list_rbind()

m8 <- unmatched_post7 |>
  filter(abs(date_error_days) > DATE_ERR_THRESHOLD, !is.na(expected_date)) |>
  rename(exp_date = expected_date) |>
  select(.tk, .tid, vid, schema, exp_date, catch) |>
  inner_join(
    land_exp |> filter(!.lid %in% c(consumed_so_far, m6$.lid, m7$.lid)),
    by = c("vid", "exp_date")
  ) |>
  group_by(.tk) |>
  filter(n_distinct(.lid) == 1) |>
  slice(1) |>
  ungroup() |>
  mutate(match_type = "08 expected_date")

## Assemble lid_map -------------------------------------------------------------
# A trip takes at most one landing (each step keeps only unambiguous trips), but one landing can be taken by
# several trips of a vessel on one day or around it - e.g. two day trips landed together. That is kept and
# declared: n_trips counts the trips on the landing (TODO 43). The landing's own date, port code and port id
# come from the landings table, not from the shifted copies the cascade matched against (plan 014: the logbook
# carries its landing link, date and port).
lid_map <- bind_rows(m1, m2, m3, m4, m5, m6, m7, m8) |>
  select(.tid, schema, .lid, match_type) |>
  left_join(land |> select(.lid, schema_land, date_land = date, hid_land = hid, pid_land = pid), by = ".lid") |>
  mutate(n_trips = n(), .by = .lid) |>
  select(.tid, schema, .lid, schema_land, date_land, hid_land, pid_land, match_type, n_trips)
stopifnot(!anyDuplicated(lid_map[c(".tid", "schema")]))

# Summary: matches per step and cumulative coverage
lid_map |>
  count(match_type) |>
  mutate(cumulative = cumsum(n)) |>
  print()

## Write output -----------------------------------------------------------------
lid_map |> write_curated(fd_curated("logbook", "lid_map.parquet"),
                        inputs = c(fd_curated("landing", "landings.parquet"), fd_curated("landing", "catch.parquet"),
                                   fd_curated("logbook", "trip.parquet"), fd_curated("logbook", "catch.parquet"),
                                   fd_curated("logbook", "station.parquet"), fd_curated("reference", "gear.parquet")))
