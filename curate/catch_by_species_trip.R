# Catch summed by species, one row per (logbook trip, species), with the
# matching landed catch of that species alongside it.
#
# Input:  curated/logbook/{trip,station,catch}.parquet, curated/logbook/lid_map.parquet
#         curated/landing/catch.parquet
# Output: curated/logbook/catch_by_species_trip.parquet
#         columns: vid, tid (logbook trip), tid_land (landing trip), sid,
#         catch_logbook, catch_landings
#
# Built to test a specific hypothesis (2026-09-25): does logbook sid 445 show
# up in the landings under a different code? It doesn't appear in landings at
# all directly, so trips reporting 445 were checked against sid 40 in the
# same landing and the two track tightly (correlation 0.94, ratio ~2.8-3.9x
# consistently) - see curate/decisions/ for the writeup. That check needed
# this same shape more generally, and it's useful beyond one hypothesis: for
# a species whose logbook and landings codes already agree, catch_logbook and
# catch_landings on this table land close to a 1:1 ratio directly (spot-check
# below, sid 1/cod: median ratio 1.02) - which is what "codes already line
# up" looks like, and any (vid, sid) that only ever appears on one side or
# whose ratio drifts far from that is a lead worth an actual crosswalk or
# correction, the way 445 -> 40 turned out to be.
#
# Deliberately built via two separate aggregations, each collected before the
# join, rather than one lazy duckdb chain ending in `full_join() |> collect()`
# - the naive version spilled 200GB+ trying to fully materialise both catch
# tables (16.8M logbook rows, 3.8M landings rows) before applying the join.
# Aggregating first collapses each side to ~3-4M (trip, species) rows, and
# the full join of those two runs in-process in under two seconds.

library(duckdbfs)
library(tidyverse)

## Logbook catch, summed by species per trip -------------------------------------
logbook_by_trip_species <-
  open_dataset(fd_curated("logbook", "trip.parquet")) |>
  inner_join(open_dataset(fd_curated("logbook", "station.parquet")), by = c(".tid", "schema")) |>
  inner_join(open_dataset(fd_curated("logbook", "catch.parquet")), by = c(".sid", "schema")) |>
  left_join(open_dataset(fd_curated("logbook", "lid_map.parquet")), by = c(".tid", "schema")) |>
  filter(!is.na(.tid_land)) |>
  group_by(vid, .tid, .tid_land, sid) |>
  summarise(catch_logbook = sum(catch, na.rm = TRUE), .groups = "drop") |>
  collect()

## Landed catch, summed by species per landing trip -------------------------------
landings_by_trip_species <-
  open_dataset(fd_curated("landing", "catch.parquet")) |>
  rename(.tid_land = .tid, sid = .sid) |>
  group_by(.tid_land, sid) |>
  summarise(catch_landings = sum(catch, na.rm = TRUE), .groups = "drop") |>
  collect()

## Join, in-process (both sides are already small post-aggregation) --------------
out <-
  logbook_by_trip_species |>
  full_join(landings_by_trip_species, by = c(".tid_land", "sid")) |>
  rename(tid = .tid, tid_land = .tid_land) |>
  select(vid, tid, tid_land, sid, catch_logbook, catch_landings) |>
  arrange(vid, tid, sid)

## Spot-check: a species whose codes are believed to already align (cod, sid 1) --
control <- out |>
  filter(sid == 1, !is.na(catch_logbook), !is.na(catch_landings)) |>
  mutate(ratio = catch_landings / catch_logbook)
print(summary(control$ratio))

write_curated(out, fd_curated("logbook", "catch_by_species_trip.parquet"),
              inputs = c(trip     = fd_curated("logbook", "trip.parquet"),
                         station  = fd_curated("logbook", "station.parquet"),
                         catch    = fd_curated("logbook", "catch.parquet"),
                         lid_map  = fd_curated("logbook", "lid_map.parquet"),
                         landing_catch = fd_curated("landing", "catch.parquet")))
