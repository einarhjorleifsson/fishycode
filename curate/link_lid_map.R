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
# Twin records (curate/corrections/logbook_twin.yml): a resubmitted trip (trip `twin` "duplicate") is not matched,
# since its kept trip is the same trip, and a duplicate station's catch and gear are not counted twice in the
# trip's catch (steps 6-7) or its main gear.
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
# Nine-step cascade in decreasing key specificity.
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
#   Step 9 — the match by time: between two matched pairs of a vessel, the trips and landings left over, paired in
#             order where their numbers agree, within ORDER_MAX_DAYS
#
# A trip with no logbook catch takes part in the steps that read only vessel, date and port (1-5) and in step 9
# (plan 034 §7 d): after the trips with catch have been through steps 1-8, on the landings they left. The weight
# steps (6-7) need its catch, and step 8 keeps to trips with catch as before. Some sources log trips with no catch
# at all, e.g. 2020's hand-line trips entered in the app.

library(duckdbfs)
library(tidyverse)

# Parameters -------------------------------------------------------------------
WEIGHT_TOL_DEMERSAL <- log(1.3)   # accept if within ~30% of landing weight
WEIGHT_TOL_PELAGIC  <- log(2.0)   # accept if within ~100% (catch transfers)
WEIGHT_MIN_GAP      <- log(1.5)   # best must be ≥ 1.5× closer than runner-up
DATE_ERR_THRESHOLD  <- 35L        # days; larger deviation flags likely wrong-date entry
DATE_ERR_WINDOW     <- 3L         # ± days around expected date to search
ORDER_MAX_DAYS      <- 14L        # step 9: a pair at most this many days apart (2,227 of 2,524 pairs; plan 034 §3.3)

## Landing register -------------------------------------------------------------
# One row per (vid × date × hid); catch summed across species. The collapse
# from multiple per-delivery records to one trip-level `.lid` (min of the raw
# id within the group, per source) happens upstream in curate/landing.R, not
# here - this script only reads the already-collapsed curated table.
#
# No date bound. The upper one, `date <= ymd("2025-12-12")`, dropped every 2026 landing (decision 027). The lower one,
# `date >= ymd("2007-09-01")`, was agf's first day, from the old code that read agf alone; it stayed when lods came in
# from 1992-09-01 (decision 031), so no trip before it had a landing, and ais_catch.R shared January-August 2007's
# landings on the fixes beside their own trips' logged catch (decision 191, plan 038 step 1b).
land <-
  duckdbfs::open_dataset(fd_curated("landing", "landings.parquet")) |> collect() |>
  filter(vid > 0) |>
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

## Logbook trips with total catch (0 for a trip with no catch rows) -------------
trip <-
  duckdbfs::open_dataset(fd_curated("logbook", "trip.parquet")) |> collect() |>
  filter(is.na(twin) | twin != "duplicate") |>
  mutate(date = as_date(T2), hid = hid2) |>
  left_join(
    duckdbfs::open_dataset(fd_curated("logbook", "catch.parquet")) |> collect() |>
      left_join(
        duckdbfs::open_dataset(fd_curated("logbook", "station.parquet")) |> collect() |> select(.sid, .tid, schema, twin),
        by = c(".sid", "schema")
      ) |>
      filter(!is.na(.tid), is.na(twin) | twin != "duplicate") |>
      group_by(.tid, schema) |>
      summarise(catch = sum(as.numeric(catch), na.rm = TRUE), .groups = "drop"),
    by = c(".tid", "schema")
  ) |>
  mutate(catch = coalesce(catch, 0)) |>
  # .tid is unique only within a schema (TODO 41): the trip is (.tid, schema), carried as one key .tk
  mutate(.tk = paste(schema, .tid, sep = "|")) |>
  select(.tk, .tid, vid, T2, date, hid, port, catch, schema)

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
# Shifted land tables reused across steps 2, 4, and weight matching
shift_land <- function(ld, d) bind_rows(ld |> mutate(date = date - d), ld |> mutate(date = date + d))
land_pm1 <- shift_land(land, 1)

match_dates <- function(tr, ld) {
  ld_pm1 <- shift_land(ld, 1)
  ld_pm2 <- shift_land(ld, 2)

  # Step 1: exact key
  m1 <- try_match(tr, ld, c("vid", "date", "hid"), "01 exact")

  # Step 2: date ±1 day, port still required
  m2 <- try_match(
    tr     |> filter(!.tk  %in% m1$.tk),
    ld_pm1 |> filter(!.lid %in% m1$.lid),
    c("vid", "date", "hid"),
    "02 exact ±1 day"
  )

  # Step 3: same day, port dropped
  m3 <- try_match(
    tr |> filter(!.tk  %in% c(m1$.tk,  m2$.tk)),
    ld |> filter(!.lid %in% c(m1$.lid, m2$.lid)),
    c("vid", "date"),
    "03 vid_date"
  )

  # Step 4: ±1 day, port dropped
  m4 <- try_match(
    tr     |> filter(!.tk  %in% c(m1$.tk,  m2$.tk,  m3$.tk)),
    ld_pm1 |> filter(!.lid %in% c(m1$.lid, m2$.lid, m3$.lid)),
    c("vid", "date"),
    "04 vid_date ±1"
  )

  # Step 5: ±2 days, port dropped
  # All newly resolved trips use exactly a 2-day offset (systematic recording lag).
  # ±3 drops the signal-to-ambiguity ratio from 11:1 to ~2:1; not worth the risk.
  m5 <- try_match(
    tr     |> filter(!.tk  %in% c(m1$.tk,  m2$.tk,  m3$.tk,  m4$.tk)),
    ld_pm2 |> filter(!.lid %in% c(m1$.lid, m2$.lid, m3$.lid, m4$.lid)),
    c("vid", "date"),
    "05 vid_date ±2"
  )
  list(m1, m2, m3, m4, m5)
}

# Trips with catch first, through every step to 8, as before plan 034. Let into the same pass, a trip with no catch
# took a landing at an earlier step from a trip with catch a day off: 67 trips with catch lost their landing in a
# trial (e.g. 42 t logged against 39 t landed, taken by a trip of the same day with none).
ms <- match_dates(trip |> filter(catch > 0), land)
m1 <- ms[[1]]; m2 <- ms[[2]]; m3 <- ms[[3]]; m4 <- ms[[4]]; m5 <- ms[[5]]

## Steps 6–7: catch-weight matching --------------------------------------------
# gear_mapping has multiple rows per gid (old/new code versions); derive the
# pelagic flag directly from the known gid set rather than joining on gear name.
pelagic_gids <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |>
  filter(gear %in% c("OTM", "PS", "HMS")) |>
  distinct(gid) |>
  pull(gid)

trip_gear <-
  duckdbfs::open_dataset(fd_curated("logbook", "fishing_sample.parquet")) |> collect() |>
  anti_join(duckdbfs::open_dataset(fd_curated("logbook", "station.parquet")) |> filter(twin == "duplicate") |>
              select(.sid, schema) |> collect(), by = c(".sid", "schema")) |>
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
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk), catch > 0) |>
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
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk), catch > 0) |>
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

# trips with catch only, as before plan 034 let trips with no catch into steps 1-5
matched_trip <- trip |>
  filter(.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk, m7$.tk), catch > 0)

approx_afli_pos <- build_approx(matched_trip |>
  filter(schema == "afli", as.numeric(.tid) > 0))
approx_afli_neg <- build_approx(matched_trip |>
  filter(schema == "afli", as.numeric(.tid) < 0, as.numeric(.tid) > -1e9))
approx_fs <- build_approx(matched_trip |>
  filter(schema == "fs_afladagbok"))

unmatched_post7 <- trip |>
  filter(!.tk %in% c(m1$.tk, m2$.tk, m3$.tk, m4$.tk, m5$.tk, m6$.tk, m7$.tk), catch > 0) |>
  # Kept when the landings' lower bound went (plan 038 step 1b). A trip with no landing in reach looks misdated: with
  # the bound, 188 trips of January-August 2007 took landings 37 to 1,726 days later here, 187 of which have their own.
  # Over every year, 93 trips from before 1992-09, where no landing is held, would do the same to later landings.
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

## Steps 1-5 for trips with no catch --------------------------------------------
# On the landings no trip with catch took (plan 034 §7 d), with the same labels and the same uniqueness rule; the
# trip's catch of 0 tells them apart.
m1_8 <- bind_rows(m1, m2, m3, m4, m5, m6, m7, m8)
m1_8 <- bind_rows(m1_8, match_dates(trip |> filter(catch == 0), land |> filter(!.lid %in% m1_8$.lid)))

## Step 9: the match by time ---------------------------------------------------
# The maintainer, 2026-10-20: match a vessel's trips and landings in order, not each record by its date alone (plan
# 034 §7 c). The pairs of steps 1-8 are anchors, at their landing's date. Between two anchors of a vessel, the trips
# left unmatched (by their T2 date, with or without catch) and the landings left unmatched (with weight) are paired
# in order, the first with the first, where their numbers agree and the order is defined: no two of the landings on
# one date, no two of the trips with one T2. A pair more than ORDER_MAX_DAYS apart is not kept. Where the numbers
# differ nothing is paired: a full alignment, with skips, is a later step, measured first.
anchor <- m1_8 |>
  distinct(vid, .lid) |>
  inner_join(land |> select(.lid, a0 = date), by = ".lid") |>
  distinct(vid, a0) |>
  arrange(vid, a0) |>
  mutate(a1 = lead(a0), .by = vid) |>
  filter(!is.na(a1))
gap_trip <- trip |>
  filter(!.tk %in% m1_8$.tk, !is.na(date), !is.na(vid)) |>
  inner_join(anchor, by = join_by(vid, between(date, a0, a1, bounds = "()")))
gap_land <- land |>
  filter(!.lid %in% m1_8$.lid, catch > 0) |>
  select(.lid, vid, date_land = date) |>
  inner_join(anchor, by = join_by(vid, between(date_land, a0, a1, bounds = "()")))
gap_ok <- full_join(
  gap_trip |> summarise(nt = n(), nt_distinct = n_distinct(T2), .by = c(vid, a0)),
  gap_land |> summarise(nl = n(), nl_distinct = n_distinct(date_land), .by = c(vid, a0)),
  by = c("vid", "a0")) |>
  filter(nt == nl, nt_distinct == nt, nl_distinct == nl) |>
  select(vid, a0)
m9 <- gap_trip |>
  semi_join(gap_ok, by = c("vid", "a0")) |>
  arrange(vid, a0, T2) |>
  mutate(k = row_number(), .by = c(vid, a0)) |>
  inner_join(gap_land |> semi_join(gap_ok, by = c("vid", "a0")) |>
               arrange(vid, a0, date_land) |>
               mutate(k = row_number(), .by = c(vid, a0)) |>
               select(vid, a0, k, .lid, date_land),
             by = c("vid", "a0", "k")) |>
  filter(abs(as.numeric(date_land - date)) <= ORDER_MAX_DAYS) |>
  mutate(match_type = "09 order")

## Assemble lid_map -------------------------------------------------------------
# A trip takes at most one landing (each step keeps only unambiguous trips), but one landing can be taken by
# several trips of a vessel on one day or around it - e.g. two day trips landed together. That is kept and
# declared: n_trips counts the trips on the landing (TODO 43). The landing's own date, port code and port id
# come from the landings table, not from the shifted copies the cascade matched against (plan 014: the logbook
# carries its landing link, date and port).
lid_map <- bind_rows(m1_8, m9) |>
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
