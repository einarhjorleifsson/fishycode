# adb_gear.R — give adb stations a gear, from the landing their trip matched.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curated/logbook/fishing_sample.parquet  (adb rows: .sid, .tid, schema)
#         curated/logbook/lid_map.parquet         (.tid, schema, .lid)
#         curated/landing/catch.parquet           (.lid, gid)
#         curated/reference/gear.parquet          (version "new": gid, gear, target, target2)
# Output: curated/logbook/adb_gear.parquet  (.sid, schema, gid, gear, target, target2, gid_basis)
#
# A side table, joined onto the station windows by curate/station_window.R. fishing_sample.parquet is
# untouched (it feeds lid_map, so writing back would make a cycle) and adb's own code stays in `gid_old`.
# Declaration: curate/corrections/adb_gear.yml.
#
# Rule: a station takes the gear of the landing its trip matched, but only when that landing names exactly one
# gear and the gear is in the "new" code list. A trip with no landing, or whose landing names several gears, gets
# no row: the station stays NA rather than guessed. gid_basis = "reconstructed" (the gear is the landing's, not
# the logbook's). Rows appear as landings arrive; a rerun after lid_map fills more of them.

library(dplyr)

fs <- duckdbfs::open_dataset(fd_curated("logbook", "fishing_sample.parquet")) |>
  filter(schema == "adb") |> select(.sid, .tid, schema) |> collect()
lm <- duckdbfs::open_dataset(fd_curated("logbook", "lid_map.parquet")) |> select(.tid, schema, .lid) |> collect()
lc <- duckdbfs::open_dataset(fd_curated("landing", "catch.parquet")) |> distinct(.lid, gid) |> collect()
gr <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |>
  filter(version == "new") |> select(gid, gear, target, target2)

# one gear per trip, or none
trip_gear <- lm |>
  inner_join(lc, by = ".lid") |>
  filter(!is.na(gid)) |>
  distinct(.tid, schema, gid) |>
  group_by(.tid, schema) |> filter(n() == 1) |> ungroup()

adb_gear <- fs |>
  inner_join(trip_gear, by = c(".tid", "schema")) |>
  inner_join(gr, by = "gid") |>
  filter(!is.na(gear)) |>
  mutate(gid_basis = "reconstructed") |>
  select(.sid, schema, gid, gear, target, target2, gid_basis)

message(sprintf("adb_gear: %d of %d adb stations get a gear", nrow(adb_gear), nrow(fs)))
stopifnot(!anyDuplicated(adb_gear[c(".sid", "schema")]))

adb_gear |> write_curated(
  fd_curated("logbook", "adb_gear.parquet"),
  inputs = c(fd_curated("logbook", "fishing_sample.parquet"), fd_curated("logbook", "lid_map.parquet"),
             fd_curated("landing", "catch.parquet"), fd_curated("reference", "gear.parquet")))
