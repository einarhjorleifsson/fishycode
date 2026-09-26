# Objective ------------------------------------------------------------------
# Convert agf (aflagrunnur, the current landings system, live since 2007-09-01)
# into source-shaped staging tables. Merged with lods (curate/plans/007) in
# curate/landing.R, which also does the hid -> pid port join - not duplicated
# here since lods needs the same join.
#
# Input:  raw/landings/agf/aflagrunnur.parquet
# Output: staging/landing/agf/landings.parquet
#         staging/landing/agf/catch.parquet

library(nanoparquet)
library(tidyverse)

SCHEMA <- "agf"

aflagrunnur <-
  read_parquet(fd_raw("landings", "agf", "aflagrunnur.parquet")) |>
  select(.lid = londun_id, vid = skip_numer, date = londun_hefst,
         hid = hafnarnumer, gid = veidarfaeri, sid = fisktegund,
         stid = veidistofn,
         catch = magn_oslaegt) |>
  mutate(date = as_date(date)) |>
  group_by(.lid, vid, date, hid, gid, sid, stid) |>
  summarise(catch = sum(catch, na.rm = TRUE),
            .groups = "drop") |>
  group_by(date, vid, hid) |>
  mutate(.tid_land = min(.lid),
         .before = ".lid") |>
  ungroup() |>
  mutate(schema = SCHEMA)

landings <-
  aflagrunnur |>
  distinct(.tid_land, vid, date, hid, schema)

catch <-
  aflagrunnur |>
  select(.tid_land, .lid, gid, sid, stid, catch, schema)

landings |> duckdbfs::write_dataset(fd_staging("landing", "agf", "landings.parquet"))
catch    |> duckdbfs::write_dataset(fd_staging("landing", "agf", "catch.parquet"))
