# logbook_gear.R — the gear each logbook station is fished with: the logbook's, or the landing's.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curated/logbook/fishing_sample.parquet  (.sid, .tid, schema, gid, gear, target, target2)
#         curated/logbook/lid_map.parquet         (.tid, schema, .lid: the trip's landing)
#         curated/landing/catch.parquet           (.lid, gid, schema: agf in the new gear code, lods in the old)
#         curated/reference/gear.parquet          (new: gid, gear, target, target2; old: gid -> map, the new gid)
# Output: curated/logbook/gear.parquet  one row per station: .sid, schema, gid (the logbook's, never changed),
#         gid_landing, gid_used, metier, gear, target, target2 (of gid_used), gid_basis
#
# Plan 014 3j, the maintainer's rule (2026-10-09): the landing's gear is more often right and finer than the
# logbook's, so wherever the trip's landing names exactly one gear the station is fished with it. Two cautions
# from the maintainer the same day shape how "one gear" and "differs" are read:
#   * gear codes changed: agf landings carry the NEW code (they equal the logbook's new gid for 90-94 % of
#     trips), lods landings the OLD one (99.5 % equal to the logbook's gid_old). A lods gear is mapped to the new
#     code (gear.parquet, version old: map) before anything is compared.
#   * gears are compared as a metier label, gear + target2 (OTB_NEP, GNS_LUM, LLS_DEF), not as a code: Lína,
#     Landbeitt lína and Línutrekt are all LLS_DEF and do not disagree. A landing names one gear when its gears
#     share one label; the logbook's gid is kept when the labels agree. Where the landing names several gears, or there is no landing, the logbook's gear stays. A
# station with no gear of its own (adb: its code does not resolve, adb_vs_fs_afladagbok.yml) takes the landing's
# when there is one, as adb_gear.R did for adb alone until plan 014.
#   gid_basis  recorded       the logbook's own gear (agreeing with the landing, or no single landing gear)
#              reconstructed  the landing's gear, where the logbook's differs or is missing
#              none           no gear from either
#
# A side table, joined onto the station windows by curate/station_window.R. fishing_sample.parquet is untouched:
# it feeds lid_map, so writing back would make a cycle. Declaration: curate/corrections/logbook_gear.yml.
library(dplyr)
gref <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect()
gr <- gref |> filter(version == "new", !is.na(gear)) |> distinct(gid, .keep_all = TRUE) |>
  transmute(gid = as.integer(gid), gear, target, target2, metier = paste(gear, target2, sep = "_"))
old_new <- gref |> filter(version == "old", !is.na(map)) |> distinct(gid, .keep_all = TRUE) |>
  transmute(gid_old = as.integer(gid), gid_new = as.integer(map))
fs <- duckdbfs::open_dataset(fd_curated("logbook", "fishing_sample.parquet")) |>
  select(.sid, .tid, schema, gid, gear, target, target2) |> collect() |>
  mutate(gid = as.integer(gid)) |>
  left_join(gr |> select(gid, metier_lb = metier), by = "gid")
lm <- duckdbfs::open_dataset(fd_curated("logbook", "lid_map.parquet")) |> select(.tid, schema, .lid) |> collect()
# the landing's gears in the new code: lods carries the old one
lc <- duckdbfs::open_dataset(fd_curated("landing", "catch.parquet")) |> distinct(.lid, schema, gid) |> collect() |>
  mutate(gid = as.integer(gid)) |>
  left_join(old_new, by = c("gid" = "gid_old")) |>
  transmute(.lid, gid = if_else(schema == "lods", gid_new, gid)) |>
  inner_join(gr |> select(gid, metier), by = "gid")
# a trip's landing names one gear when its gears share one metier label; that label's lowest gid stands for it
trip_gear <- lm |>
  inner_join(lc, by = ".lid", relationship = "many-to-many") |>
  distinct(.tid, schema, gid, metier) |>
  filter(n_distinct(metier) == 1, .by = c(.tid, schema)) |>
  summarise(gid_landing = min(gid), metier_land = first(metier), .by = c(.tid, schema))
out <- fs |>
  left_join(trip_gear, by = c(".tid", "schema")) |>
  mutate(use_land  = !is.na(gid_landing) & (is.na(metier_lb) | metier_lb != metier_land),
         gid_used  = if_else(use_land, gid_landing, gid),
         gid_basis = case_when(is.na(gid_used) ~ "none", use_land ~ "reconstructed", .default = "recorded")) |>
  left_join(gr |> rename(gear_l = gear, target_l = target, target2_l = target2), by = c("gid_used" = "gid")) |>
  # the logbook's own labels where its gear is used, the reference's where the landing's is
  mutate(gear    = if_else(use_land, gear_l, gear),
         target  = if_else(use_land, target_l, target),
         target2 = if_else(use_land, target2_l, target2)) |>
  select(.sid, schema, gid, gid_landing, gid_used, metier, gear, target, target2, gid_basis)
stopifnot(!anyDuplicated(out[c(".sid", "schema")]))
print(count(out, schema, gid_basis))
chg <- fs |> select(.sid, schema, metier_lb) |> inner_join(out |> filter(gid_basis == "reconstructed"), by = c(".sid", "schema"))
print(chg |> count(schema, metier_lb, metier, sort = TRUE) |> head(15))
out |> write_curated(
  fd_curated("logbook", "gear.parquet"),
  inputs = c(fd_curated("logbook", "fishing_sample.parquet"), fd_curated("logbook", "lid_map.parquet"),
             fd_curated("landing", "catch.parquet"), fd_curated("reference", "gear.parquet")))
