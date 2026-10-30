# logbook_nephrops_tails.R — Nephrops logged as tails: the stations whose whole weight is the tail weight times a factor.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curate/corrections/logbook_nephrops_tails.yml   (factor, guard, periods: the rule's parameters)
#         curated/logbook/{trip,station,catch}.parquet
#         curated/logbook/catch_by_species_trip.parquet  (vid, .tid, schema, .lid, sid, catch_logbook, catch_landings)
# Output: curated/logbook/nephrops_tails.parquet  one row per candidate station: .sid, schema, sid (40), .tid, vid,
#         trip_logged, landing_logged, landed, ratio, outcome, condition_corrected
#
# A trip of a declared vessel with a sid-40 station in a declared period is a candidate. Its ratio is the logged over
# the landed sid 40 of its landing: logged summed over every trip that landing ends, since a landing ending two trips
# would put a whole-weight trip near 0.5 alone. Every candidate trip takes one outcome: `tails` under the guard,
# `tails_no_landing` with no landing or none of sid 40 there, both named tails (condition_corrected = "tails"); `whole`
# at the guard or above (condition_corrected NA). calc_whole_weight() (R/whole_weight.R) reads the factor of the named
# state from the factor table, the landings' 3.25 (plan 051 step 4; plan 050 step 5 had held 3.3). A side table, as
# curate/corrections/logbook_gear.R: the guard reads lid_map, which is built from the merge, so the merge cannot take
# it. Declaration: curate/corrections/logbook_nephrops_tails.yml.

library(dplyr)

# Parameters -------------------------------------------------------------------
decl <- yaml::read_yaml("curate/corrections/logbook_nephrops_tails.yml")
SID <- 40L
periods <- bind_rows(lapply(decl$periods, \(p) tibble(vid = as.integer(p$vid), from = as.Date(p$from),
                                                      to = as.Date(if (is.null(p$to)) NA else p$to))))
stopifnot(is.numeric(decl$guard), nrow(periods) > 0, !anyNA(periods$from))

# Candidate stations -----------------------------------------------------------
# An open end stands in as a far date inside the computation only (AGENTS.md); nothing written carries it.
far <- as.Date("2999-12-31")
trip <- duckdbfs::open_dataset(fd_curated("logbook", "trip.parquet")) |>
  filter(vid %in% !!periods$vid) |> select(.tid, schema, vid) |> collect() |> mutate(vid = as.integer(vid))
station <- duckdbfs::open_dataset(fd_curated("logbook", "station.parquet")) |>
  filter(is.na(twin) | twin != "duplicate") |> select(.sid, .tid, schema, date) |> collect() |>
  mutate(date = as.Date(date)) |>                 # a date-time in station.parquet; a Date against Dates
  inner_join(trip, by = c(".tid", "schema"), relationship = "many-to-one")
neph <- duckdbfs::open_dataset(fd_curated("logbook", "catch.parquet")) |> filter(sid == !!SID) |>
  summarise(catch = sum(catch, na.rm = TRUE), .by = c(.sid, schema)) |> collect() |>
  inner_join(station, by = c(".sid", "schema"), relationship = "one-to-one")
cand <- neph |>
  inner_join(periods, by = "vid", relationship = "many-to-many") |>
  filter(date >= from, date <= coalesce(to, far)) |>
  distinct(.sid, schema, .tid, vid)
stopifnot("no candidate station: check the periods and the date type" = nrow(cand) > 0,
          !anyDuplicated(cand[c(".sid", "schema")]))

# The trip's ratio, at its landing -----------------------------------------------
cbt <- duckdbfs::open_dataset(fd_curated("logbook", "catch_by_species_trip.parquet")) |>
  filter(sid == !!SID, !is.na(.tid)) |> collect()
at_landing <- cbt |>
  summarise(landing_logged = sum(catch_logbook, na.rm = TRUE),
            landed = suppressWarnings(max(catch_landings, na.rm = TRUE)), .by = .lid)
trips <- cand |> distinct(.tid, schema, vid) |>
  left_join(neph |> summarise(trip_logged = sum(catch), .by = c(.tid, schema)), by = c(".tid", "schema")) |>
  left_join(cbt |> distinct(.tid, schema, .lid), by = c(".tid", "schema"), relationship = "one-to-one") |>
  left_join(at_landing, by = ".lid", relationship = "many-to-one") |>
  mutate(landed = if_else(is.finite(landed) & landed > 0, landed, NA_real_),
         ratio = landing_logged / landed,
         outcome = case_when(is.na(ratio) ~ "tails_no_landing",
                             ratio < decl$guard ~ "tails",
                             .default = "whole"),
         condition_corrected = if_else(outcome == "whole", NA_character_, "tails"))

# Account: every candidate trip in one outcome ----------------------------------
stopifnot(!anyDuplicated(trips[c(".tid", "schema")]), !anyNA(trips$outcome))
out <- cand |>
  inner_join(trips |> select(.tid, schema, trip_logged, landing_logged, landed, ratio, outcome, condition_corrected),
             by = c(".tid", "schema"), relationship = "many-to-one") |>
  mutate(sid = SID, .after = schema)
stopifnot(nrow(out) == nrow(cand))
period_of <- function(v, d) {
  p <- periods[periods$vid == v & d >= periods$from & d <= coalesce(periods$to, far), ]
  paste0(format(p$from[1], "%Y"), "-", if (is.na(p$to[1])) "" else format(p$to[1], "%Y"))
}
first_day <- out |> left_join(station |> select(.sid, schema, date), by = c(".sid", "schema")) |>
  summarise(date = min(date), .by = c(.tid, schema, vid))
print(trips |> left_join(first_day, by = c(".tid", "schema", "vid")) |>
        mutate(period = mapply(period_of, vid, date)) |>
        summarise(trips = n(), logged_t = round(sum(trip_logged) / 1000, 1), .by = c(vid, period, outcome)) |>
        arrange(vid, period, outcome), n = Inf)

out |> write_curated(
  fd_curated("logbook", "nephrops_tails.parquet"),
  inputs = c(fd_curated("logbook", "trip.parquet"), fd_curated("logbook", "station.parquet"),
             fd_curated("logbook", "catch.parquet"), fd_curated("logbook", "catch_by_species_trip.parquet")))
