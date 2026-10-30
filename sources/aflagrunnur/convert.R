# Objective ------------------------------------------------------------------
# Side: preprocessing (landings). See plan 014.
# Convert agf (aflagrunnur, the current landings system, live since 2007-09-01)
# into source-shaped staging tables. Merged with lods (curate/plans/007) in
# curate/landing.R, which also does the hid -> pid port join - not duplicated
# here since lods needs the same join.
#
# Input:  raw/oracle/agf/aflagrunnur.parquet
# Output: staging/landing/agf/landings.parquet
#         staging/landing/agf/catch.parquet
#         staging/landing/agf/catch_detail.parquet
#
# catch_detail keeps the state the fish were landed in and the weight as landed beside the ungutted equivalent (plan
# 051 step 5), so a factor can be read back and re-applied: per landing, gear, species, stock, `state` (astand,
# ask.astand's code) and `area` (veidisvaedi, IS for Iceland's waters), the weights `catch_landed` (magn, as landed),
# `catch_gutted` (magn_slaegt, its gutted equivalent) and `catch` (magn_oslaegt, the ungutted equivalent). The landing
# system's own factor is catch / catch_landed. catch.parquet is summed from the rows as before, not from catch_detail,
# so its sums keep their order to the last bit.

library(nanoparquet)
library(tidyverse)

SCHEMA <- "agf"

aflagrunnur <-
  read_parquet(fd_raw("oracle", "agf", "aflagrunnur.parquet")) |>
  select(.lid = londun_id, vid = skip_numer, date = londun_hefst,
         hid = hafnarnumer, gid = veidarfaeri, sid = fisktegund,
         stid = veidistofn, state = astand, area = veidisvaedi,
         catch_landed = magn, catch_gutted = magn_slaegt, catch = magn_oslaegt) |>
  mutate(date = as_date(date))

catch_detail <- aflagrunnur |>
  group_by(.lid, gid, sid, stid, state, area) |>
  summarise(catch_landed = sum(catch_landed, na.rm = TRUE), catch_gutted = sum(catch_gutted, na.rm = TRUE),
            catch = sum(catch, na.rm = TRUE), .groups = "drop") |>
  mutate(schema = SCHEMA)

aflagrunnur <- aflagrunnur |>
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

catch_detail <- catch_detail |>
  inner_join(aflagrunnur |> distinct(.lid, .tid_land), by = ".lid", relationship = "many-to-one") |>
  relocate(.tid_land)

landings    |> duckdbfs::write_dataset(fd_staging("landing", "agf", "landings.parquet"))
catch       |> duckdbfs::write_dataset(fd_staging("landing", "agf", "catch.parquet"))
catch_detail |> duckdbfs::write_dataset(fd_staging("landing", "agf", "catch_detail.parquet"))
