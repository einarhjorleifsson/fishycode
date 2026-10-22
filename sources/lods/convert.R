# Objective ------------------------------------------------------------------
# Side: preprocessing (landings). See plan 014.
# Convert lods (the legacy landings system; still populated in parallel with
# agf, per curate/plans/007's measured trip-level agreement) into the same
# source-shaped staging tables agf produces. Merged with agf in
# curate/landing.R, which also does the hid -> pid port join.
#
# Input:  raw/oracle/kvoti/lods_slaegt.parquet
# Output: staging/landing/lods/landings.parquet
#         staging/landing/lods/catch.parquet
#
# The table, not the view lods_oslaegt on it, which drops upprunahofn and the
# gutted weight and rounds (decision 169). Its own rules, kept here:
# herring, capelin and blue whiting (fteg 30, 31, 34) are in tonnes, every
# other species in kg. Every gerd is summed: at hofn 159 (exports, to 2013)
# the K row is the weight sold abroad plus the export surcharge (x 1.15, later
# 1.10) and the negative A row takes the surcharge off again, so K + A is the
# container system's own sold weight (decision 169, amended); gerd 'V' (the
# 2 % water deduction) is fish too. upprunahofn is the port an export (hofn 159)
# was landed at, kept per catch row as hid_origin: a few export days have two.
#
# lods_londun (the separate header file) is not read here: lods_slaegt
# already carries its own skip_nr/hofn/l_dags per row, and curate/plans/007
# measured that lods_londun's and lods_oslaegt's own distinct komunr counts
# don't fully agree (1,189,262 vs 1,257,245) - joining through lods_londun
# would risk orphaning rows lods_slaegt alone does not.
#
# fteg -> sid, kfteg -> stid: curate/plans/007 §5. kfteg equals stid directly
# only where kfteg == fteg (the "default stock" convention both systems use,
# 76.43% of rows, measured 2026-09-26); kfteg == 0 or NA means unspecified
# (stid = NA); the remaining 0.78% carry a kfteg value that uses a different
# numbering scheme than agf's stid and is not translated (stid = NA, kfteg
# kept raw so a future crosswalk can still use it - never destroy the
# original, AGENTS.md).
#
# .tid_land is NOT derived from komunr (curate/plans/007, found 2026-09-26):
# komunr recycles across unrelated real trips - e.g. 930004 is shared by 41
# different (vid, date, hid) groups spanning 1992-1993, and common values
# each repeat 140-158 times across unrelated vessels/dates/harbours. It looks
# like a loading-batch code (matching the "HLEDSLA" loader account seen in
# lods_londun's own gerandi field), not a per-delivery id - min(komunr) would
# make ~51% of lods trip-rows share a `.tid_land` with some other, unrelated
# trip. Instead a stable id is minted directly from the (vid, date, hid) key
# itself, via a hash (deterministic: unaffected by row order, unaffected by
# new data appended elsewhere, so an id does not change across rebuilds).
# komunr itself is kept, under its own name, as an informational field only -
# never destroy the original, but it is not part of any key here.

library(tidyverse)

SCHEMA <- "lods"

# Deterministic 52-bit id from a (vid, date, hid) key: rlang::hash() gives a
# 128-bit MD5-style hex digest per element; take the first 13 hex digits
# (52 bits, safely exact as a double - R doubles are exact integers up to
# 2^53) and combine in four chunks of <=4 hex digits each to avoid any
# intermediate integer overflow. Collision probability across ~2.2M distinct
# groups at 52 bits is negligible (~5e-4 by the birthday bound) - far below
# komunr's own ~51% collision rate.
hash_id <- function(vid, date, hid) {
  h <- vapply(paste(vid, date, hid, sep = "|"), rlang::hash, character(1), USE.NAMES = FALSE)
  h13 <- substr(h, 1, 13)
  p1 <- strtoi(substr(h13, 1, 4), base = 16L)
  p2 <- strtoi(substr(h13, 5, 8), base = 16L)
  p3 <- strtoi(substr(h13, 9, 12), base = 16L)
  p4 <- strtoi(substr(h13, 13, 13), base = 16L)
  ((p1 * 65536 + p2) * 65536 + p3) * 16 + p4
}

TONNES <- c(30L, 31L, 34L)  # Oracle's own views lods_slaegt_v and lods_slaegt_kg_v multiply these by 1000

lods <-
  duckdbfs::open_dataset(fd_raw("oracle", "kvoti", "lods_slaegt.parquet")) |>
  select(skip_nr, hofn, upprunahofn, komunr, l_dags, fteg, kfteg, veidarf, magn, magn_oslaegt) |>
  collect() |>
  mutate(kg = if_else(fteg %in% TONNES, 1000, 1)) |>
  transmute(komunr, vid = skip_nr, date = as_date(l_dags),
            hid = hofn, hid_origin = upprunahofn, gid = veidarf, sid = fteg, kfteg,
            stid = if_else(!is.na(kfteg) & kfteg == sid, kfteg, NA_integer_),
            catch = magn_oslaegt * kg, catch_gutted = magn * kg) |>
  group_by(vid, date, hid, hid_origin, gid, sid, stid, kfteg) |>
  summarise(catch = sum(catch, na.rm = TRUE),
            catch_gutted = sum(catch_gutted, na.rm = TRUE),
            komunr = min(komunr),
            .groups = "drop") |>
  mutate(.tid_land = hash_id(vid, date, hid), .before = "vid") |>
  mutate(schema = SCHEMA)

landings <-
  lods |>
  distinct(.tid_land, vid, date, hid, schema)

catch <-
  lods |>
  select(.tid_land, komunr, gid, sid, stid, kfteg, hid_origin, catch, catch_gutted, schema)

landings |> duckdbfs::write_dataset(fd_staging("landing", "lods", "landings.parquet"))
catch    |> duckdbfs::write_dataset(fd_staging("landing", "lods", "catch.parquet"))
