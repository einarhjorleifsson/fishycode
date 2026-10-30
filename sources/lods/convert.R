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
#         staging/landing/lods/catch_detail.parquet  the same catch by area (plan 051 step 5): the landing system's
#                                                   factor to the ungutted weight depends on it; lods holds no state,
#                                                   its `magn` being "gutted where it applies" (catch_gutted)
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


SCHEMA <- "lods"

# Deterministic 52-bit id from a (vid, date, hid) key: rlang::hash() gives a
# 128-bit MD5-style hex digest per element; take the first 13 hex digits
# (52 bits, safely exact as a double - R doubles are exact integers up to
# 2^53) and combine in four chunks of <=4 hex digits each to avoid any
# intermediate integer overflow. Collision probability across ~2.2M distinct
# groups at 52 bits is negligible (~5e-4 by the birthday bound) - far below
# komunr's own ~51% collision rate.
#
# In DuckDB, lazily: the 10 M rows never enter R, only the 2.2 M (vid, date, hid)
# keys the id is minted from (rlang::hash has no SQL twin). DuckDB runs on one
# thread here, so each sum adds its rows in the file's order, as R's sum over the
# collected rows did, and every total is the same to the last bit (on four
# threads about 0.2 % differ in it).
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

con <- duckdbfs::cached_connection()
threads <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS n")$n
DBI::dbExecute(con, "SET threads = 1")
q <- function(sql) dplyr::tbl(con, dplyr::sql(sql))
DBI::dbExecute(con, sprintf(r"[
  CREATE OR REPLACE TEMP VIEW lods_rows AS
  SELECT komunr, skip_nr AS vid, CAST(l_dags AS DATE) AS date, hofn AS hid,
         upprunahofn AS hid_origin, veidarf AS gid, fteg AS sid, kfteg, veidisvaedi AS area,
         CASE WHEN kfteg IS NOT NULL AND kfteg = fteg THEN kfteg END AS stid,
         magn_oslaegt * CASE WHEN fteg IN (%s) THEN 1000.0 ELSE 1.0 END AS catch,
         magn * CASE WHEN fteg IN (%s) THEN 1000.0 ELSE 1.0 END AS catch_gutted
  FROM read_parquet('%s')]",
  toString(TONNES), toString(TONNES), fd_raw("oracle", "kvoti", "lods_slaegt.parquet")))

# One id per (vid, date, hid), minted in R from the distinct keys and joined back.
keys <- q("SELECT DISTINCT vid, date, hid FROM lods_rows") |> dplyr::collect()
keys$.tid_land <- hash_id(keys$vid, keys$date, keys$hid)
duckdb::duckdb_register(con, "lods_key", keys, overwrite = TRUE)
key_join <- "JOIN lods_key k ON k.vid IS NOT DISTINCT FROM g.vid AND k.date IS NOT DISTINCT FROM g.date
             AND k.hid IS NOT DISTINCT FROM g.hid"

DBI::dbExecute(con, sprintf(r"[
  CREATE OR REPLACE TEMP TABLE lods_catch AS
  SELECT k.".tid_land", g.*, 'lods' AS schema
  FROM (SELECT vid, date, hid, hid_origin, gid, sid, stid, kfteg, coalesce(sum(catch), 0) AS catch,
               coalesce(sum(catch_gutted), 0) AS catch_gutted, min(komunr) AS komunr
        FROM lods_rows GROUP BY vid, date, hid, hid_origin, gid, sid, stid, kfteg) g
  %s]", key_join))

landings <- q(r"[SELECT DISTINCT ".tid_land", vid, date, hid, schema FROM lods_catch]")
catch <- q(r"[SELECT ".tid_land", komunr, gid, sid, stid, kfteg, hid_origin, catch, catch_gutted, schema FROM lods_catch
              ORDER BY vid, date, hid, hid_origin, gid, sid, stid, kfteg]")
catch_detail <- q(sprintf(r"[
  SELECT k.".tid_land", g.gid, g.sid, g.stid, g.kfteg, g.hid_origin, g.area, g.catch, g.catch_gutted, 'lods' AS schema
  FROM (SELECT vid, date, hid, hid_origin, gid, sid, stid, kfteg, area, coalesce(sum(catch), 0) AS catch,
               coalesce(sum(catch_gutted), 0) AS catch_gutted
        FROM lods_rows GROUP BY vid, date, hid, hid_origin, gid, sid, stid, kfteg, area) g
  %s
  ORDER BY g.vid, g.date, g.hid, g.hid_origin, g.gid, g.sid, g.stid, g.kfteg, g.area]", key_join))

landings     |> duckdbfs::write_dataset(fd_staging("landing", "lods", "landings.parquet"))
catch        |> duckdbfs::write_dataset(fd_staging("landing", "lods", "catch.parquet"))
catch_detail |> duckdbfs::write_dataset(fd_staging("landing", "lods", "catch_detail.parquet"))
DBI::dbExecute(con, sprintf("SET threads = %d", threads))
