# Objective ------------------------------------------------------------------
# Side: preprocessing (landings). See plan 014.
# Convert lods (the legacy landings system; still populated in parallel with
# agf, per curate/plans/007's measured trip-level agreement) into the same
# source-shaped staging tables agf produces. Merged with agf in
# curate/landing.R, which also does the hid -> pid port join.
#
# Input:  raw/oracle/kvoti/lods_oslaegt.parquet
# Output: staging/landing/lods/landings.parquet
#         staging/landing/lods/catch.parquet
#
# lods_londun (the separate header file) is not read here: lods_oslaegt
# already carries its own skip_nr/hofn/l_dags per row, and curate/plans/007
# measured that lods_londun's and lods_oslaegt's own distinct komunr counts
# don't fully agree (1,189,262 vs 1,257,245) - joining through lods_londun
# would risk orphaning rows lods_oslaegt alone does not.
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

library(nanoparquet)
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

lods <-
  read_parquet(fd_raw("oracle", "kvoti", "lods_oslaegt.parquet")) |>
  transmute(komunr, vid = skip_nr, date = as_date(l_dags),
            hid = hofn, gid = veidarf, sid = fteg, kfteg,
            stid = if_else(!is.na(kfteg) & kfteg == sid, kfteg, NA_integer_),
            catch = magn_oslaegt) |>
  group_by(vid, date, hid, gid, sid, stid, kfteg) |>
  summarise(catch = sum(catch, na.rm = TRUE),
            komunr = min(komunr),
            .groups = "drop") |>
  mutate(.tid_land = hash_id(vid, date, hid), .before = "vid") |>
  mutate(schema = SCHEMA)

landings <-
  lods |>
  distinct(.tid_land, vid, date, hid, schema)

catch <-
  lods |>
  select(.tid_land, komunr, gid, sid, stid, kfteg, catch, schema)

landings |> duckdbfs::write_dataset(fd_staging("landing", "lods", "landings.parquet"))
catch    |> duckdbfs::write_dataset(fd_staging("landing", "lods", "catch.parquet"))
