# Merge afli (legacy), fs_afladagbok, adb and the ERS catch reports (aflaskeyti) into unified logbook tables.
# Side: preprocessing (logbook). See plan 014.
# Input:  staging/{afli,fs_afladagbok,adb,aflaskeyti}/{trip,station,fishing_sample,catch}.parquet, and the side
#         tables named under "Load"; the dump stamps (fd.dumped, never the rows) of raw/oracle/{afli,fs_afli}/stofn,
#         adb/fishing_station and dw/dw_aflaskeyti, for the date caps; curated/reference/gear.parquet (gear_code)
# Output: curated/logbook/{trip,station,fishing_sample,catch}.parquet, and the fate of every staging station and trip:
#         curated/logbook/station_fate.parquet, trip_fate.parquet (plan 024)
#
# Decision rule (tiered priority):
#   Tier 1 — if (vid, date) present in afli                        → use afli
#   Tier 2 — not in afli, but present in fs_afladagbok             → use fs_afladagbok
#   Tier 2b — not in either, and an afli station read from fs_afli  → use it (decision 124)
#   Tier 3 — not in afli or fs_afladagbok, present in adb from ADB_DATE_MIN on → use adb
#   Tier 4 — in none of them, present in aflaskeyti                → use aflaskeyti (plan 026): the foreign
#            vessels' hauls of 2014-2018, and the Icelandic vessels' hauls on vessel-days their logbook lacks
#
# Rationale:
#   afli > fs_afladagbok: afli mobile-gear timing is derived from the on-bottom
#   clock; when fs_afladagbok was instigated, timestamps and/or duration were
#   missing in fs_afladagbok.
#   fs_afladagbok > adb: fs_afladagbok is the dump of the e-logbook; adb is
#   derived from it and from other schemas, with errors of its own, and is
#   read only for the dates the dump no longer covers (decision 160).
#
# Date bounds applied:
#   afli          — no lower bound; upper: <= AFLI_DATE_MAX, the day after its dump
#   fs_afladagbok — lower: >= FS_DATE_MIN; upper: <= FS_DATE_MAX (static dump)
#   adb           — lower: >= ADB_DATE_MIN, the day fs_afladagbok's dump starts
#                   to thin (decision 160); upper: <= ADB_DATE_MAX, the day after
#                   its dump. From that day the tier anti-join decides which of
#                   the two holds a vessel-day, since the dump goes on to 2025-11-28.
#   aflaskeyti    — no lower bound; upper: <= ERS_DATE_MAX, the day after its dump
#
# Depth: z1/z2 are converted to metres (curate/decisions/022), z1_raw/z2_raw
# keep the original recorded value, z1_basis/z2_basis says which happened: afli's by afli_depth_units.R, the
# e-logbook's by the unit each app sends (the app profile's rows D1-D5, plan 053 step 8), with z_unit.
# Longitude: adb's dropped west sign is fixed by curate/corrections/
# adb_vs_fs_afladagbok.R (lon1_raw/lon2_raw/lon1_basis/lon2_basis), and afli's end longitude where Oracle holds the
# end latitude by curate/corrections/afli_end_longitude.R (lon2_raw/lon2_basis). afli's stations east of 10.75° E south
# of 67.66° N carry coord_flag from overrides/afli_east_longitude_reviewed.csv, the track's judgment frozen as a reviewed
# list (decision 249): lon_sign_switched, lon_sign_unjudged, or none where the track puts the vessel east; lon1 as
# recorded.
# aflaskeyti: three corrections and the trips, each a side table (plan 026): the swapped positions
# (aflaskeyti_coordinates.R: lon1_raw, lat1_raw, lon2_raw, lat2_raw, coord_flag), the Faroese summer times
# (aflaskeyti_local_time.R: t_shift_min, time_basis), the state of each weight (aflaskeyti_weight.R:
# condition_basis), and the trips cut at landings in Iceland (curate/aflaskeyti_trip.R: T1_basis, T2_basis).
# App: station.parquet carries the app that wrote each e-logbook station (app, app_suffix, app_raw, app_version;
# plan 053 step 2), from the trip's source and the afli route's sent layer (staging/afli_sent/station.parquet).
# Station type: station.parquet carries station_type (operation / event) and
# station_type_basis, read per vessel, year and gear (decision 084).
# App profile: each app's habits found by rule (curate/corrections/logbook_app_profile.yml, R/logbook_app_profile.R;
# plan 053 steps 5 and 6), after the twins: every value as recorded, with t1_flag ... t4_flag in fishing_sample.parquet,
# T1_flag and T2_flag in trip.parquet, pos1_flag and pos2_flag in station.parquet, species_flag in catch.parquet, each
# with its rule and action. Until then a placeholder t1 was NA here (decision 157); t1_placeholder stays one release.
# Fate (plan 024): one row per staging station of every source and one per staging trip, kept or dropped, and why.
# Each date bound and tier keeps the stations it drops, so its rule is stated once; the merge checks that the account
# adds up (kg in = kept + dropped, per source) and stops otherwise.
#
# How it runs (the lean merge; rewritten by Claude (AI), 2026-10-30, not checked by a person): DuckDB reads the
# staged files where they lie, makes the tiers, the joins and the fate over narrow key tables, and writes each output
# by one query; no source table is loaded whole into R. R keeps the rules written in R (the twins' catch signature,
# the apps' names, the app profile's flags), each on the rows and columns it reads, and hands its result back as a
# registered table. A join matches a missing key to a missing key (IS NOT DISTINCT FROM), as dplyr's joins did, and
# each file keeps the row order the in-memory merge wrote: a source's rows in the order of its staged file (`.ord`),
# the sources in tier order. The six files are equal, row for row, to those of the in-memory merge (2026-10-30).

library(tidyverse)
library(DBI)

# Parameters -------------------------------------------------------------------
FS_DATE_MIN  <- as.Date("2020-01-01")
FS_DATE_MAX  <- as.Date("2025-12-31")
# Decision 160: adb only for the dates fs_afladagbok's dump no longer covers. The dump holds 99-100 % of adb's
# vessel-days up to 2025-11-19, then 95 % falling to 3 % on 11-28; what it lacks before 11-19 is strays.
ADB_DATE_MIN <- as.Date("2025-11-19")
# Decision 181: no haul is later than the copy it was read from. Each source is capped at the day after its dump began
# (fd.dumped; a dump can run past midnight), which leaves out the dates entered in the future (26 adb stations,
# 2027-2031) and lets each new year in, where the fixed 2026-12-31 that stood here would have dropped it.
dump_day_after <- function(schema, table) {
  m <- curated_provenance(fd_raw("oracle", schema, table))
  d <- as.Date(substr(m$value[m$key == "fd.dumped"], 1, 10))
  stopifnot("a logbook dump carries no fd.dumped stamp" = length(d) == 1 && !is.na(d))
  d + 1L
}
AFLI_DATE_MAX <- max(dump_day_after("afli", "stofn.parquet"), dump_day_after("fs_afli", "stofn.parquet"))
ADB_DATE_MAX  <- dump_day_after("adb", "fishing_station.parquet")
ERS_DATE_MAX  <- dump_day_after("dw", "dw_aflaskeyti.parquet")

con <- dbConnect(duckdb::duckdb())
dbExecute(con, "SET memory_limit = '8GB'")
q  <- function(s) as_tibble(dbGetQuery(con, s))
ex <- function(s) invisible(dbExecute(con, s))
stg <- function(source, table) fd_staging(source, paste0(table, ".parquet"))
pq  <- function(p) sprintf("read_parquet('%s')", p)
# A staged file with each row's place in it, `.ord`.
pqo <- function(p) sprintf("(SELECT * EXCLUDE (file_row_number), file_row_number AS \".ord\"
                             FROM read_parquet('%s', file_row_number = true))", p)
# A double as R holds it: a decimal literal would be DuckDB's DECIMAL, and its products are not R's.
dbl <- function(x) sprintf("'%.17g'::DOUBLE", x)
# Keys held twice, with a missing key one key, as dplyr's joins count them: every join below relies on none.
dup_keys <- function(from, key)
  q(sprintf("SELECT count(*) AS n FROM (SELECT %s FROM %s GROUP BY ALL HAVING count(*) > 1)", key, from))$n

# Load -------------------------------------------------------------------------
# Each source's tables as views over the staged files, the corrections joined in; nothing is read until a query
# needs it. afli's and fs_afladagbok's .tid is a double, and the merge writes it as R's as.character() does, which
# for a round number is scientific (3 afli trips and 2 fs_afladagbok trips, e.g. "1e+05"): the map is made by R.
tid_num <- q(paste(sprintf("SELECT DISTINCT \".tid\" FROM %s", pq(c(
  stg("afli", "trip"), stg("afli", "station"), stg("afli", "fishing_sample"),
  stg("fs_afladagbok", "trip"), stg("fs_afladagbok", "station"), stg("fs_afladagbok", "fishing_sample")))),
  collapse = " UNION "))
tid_map <- tibble(.tid = tid_num$.tid, tid = as.character(tid_num$.tid))
duckdb::duckdb_register(con, "tid_map", tid_map)
AFLI_EAST_LON <- "overrides/afli_east_longitude_reviewed.csv"
afli_east_lon <- read.csv(AFLI_EAST_LON, colClasses = "character") |>
  transmute(.sid = as.numeric(.sid), coord_flag = na_if(coord_flag, ""))
duckdb::duckdb_register(con, "afli_east_lon", afli_east_lon)
tid_char <- function(from) sprintf("(SELECT s.* REPLACE (m.tid AS \".tid\") FROM %s s
                                    LEFT JOIN tid_map m ON m.\".tid\" IS NOT DISTINCT FROM s.\".tid\")", from)

ex(sprintf("CREATE TEMP VIEW afli_trip AS SELECT * FROM %s", tid_char(pqo(stg("afli", "trip")))))
ex(sprintf("CREATE TEMP VIEW fs_trip AS SELECT * FROM %s", tid_char(pqo(stg("fs_afladagbok", "trip")))))
ex(sprintf("CREATE TEMP VIEW adb_trip AS SELECT * FROM %s", pqo(stg("adb", "trip"))))
# aflaskeyti's trips and station keys come from curate/aflaskeyti_trip.R, not from the adapter's runs.
ex(sprintf("CREATE TEMP VIEW ers_trip AS SELECT * FROM %s", pqo(stg("aflaskeyti", "trip_landing"))))
for (s in c("afli", "fs_afladagbok", "adb", "aflaskeyti"))
  stopifnot("a staged trip twice" =
              dup_keys(pq(stg(s, if (s == "aflaskeyti") "trip_landing" else "trip")), "\".tid\"") == 0)

# Depth unit ---------------------------------------------------------------
# afli: replace z1/z2 with the per-vessel-period corrected value from
# afli_depth_units.R; keep z1_raw/z2_raw/z1_basis/z2_basis (never overwrite the
# original - AGENTS.md).
# afli: the end longitude the logbook sent, where Oracle holds the end latitude in its place
# (curate/corrections/afli_end_longitude.R); lon2_raw/lon2_basis keep what happened.
stopifnot(dup_keys(pq(stg("afli", "end_longitude")), "\".sid\"") == 0, dup_keys("afli_east_lon", "\".sid\"") == 0)
ex(sprintf("CREATE TEMP VIEW afli_station AS
  SELECT s.* EXCLUDE (z1, z2, lon2, \".ord\"), d.* EXCLUDE (\".sid\"), e.* EXCLUDE (\".sid\"), o.coord_flag, s.\".ord\"
  FROM %s s LEFT JOIN %s d ON d.\".sid\" IS NOT DISTINCT FROM s.\".sid\"
  LEFT JOIN %s e ON e.\".sid\" IS NOT DISTINCT FROM s.\".sid\"
  LEFT JOIN afli_east_lon o ON o.\".sid\" IS NOT DISTINCT FROM s.\".sid\"",
  tid_char(pqo(stg("afli", "station"))), pq(stg("afli", "depth")), pq(stg("afli", "end_longitude"))))
stopifnot(q("SELECT count(coord_flag) AS n FROM afli_station")$n == sum(!is.na(afli_east_lon$coord_flag)))

# fs_afladagbok and adb: the depth as sent, read by the app that sent it once the station knows its app (section "Depth
# by app", below, plan 053 step 8): z1 and z2 are filled there.
depth_as_sent <- "REPLACE (NULL::DOUBLE AS z1, NULL::DOUBLE AS z2), s.z1 AS z1_raw, s.z2 AS z2_raw,
  NULL::VARCHAR AS z1_basis, NULL::VARCHAR AS z2_basis"
ex(sprintf("CREATE TEMP VIEW fs_station AS SELECT s.* EXCLUDE (\".ord\") %s, s.\".ord\" FROM %s s",
           depth_as_sent, tid_char(pqo(stg("fs_afladagbok", "station")))))

# adb: longitude: replace lon1/lon2 with adb_vs_fs_afladagbok.R's sign-corrected
# value, keep lon1_raw/lon2_raw/lon1_basis/lon2_basis (never overwrite the
# original - AGENTS.md).
ex(sprintf("CREATE TEMP VIEW adb_station AS
  SELECT s.* EXCLUDE (lon1, lon2, \".ord\") %s,
         l.lon1, l.lon2, l.lon1_raw, l.lon2_raw, l.lon1_basis, l.lon2_basis, s.\".ord\"
  FROM %s s LEFT JOIN %s l ON l.\".sid\" IS NOT DISTINCT FROM s.\".sid\"",
  depth_as_sent, pqo(stg("adb", "station")), pq(stg("adb", "lon_sign"))))

# aflaskeyti: positions swapped back, times in UTC, each weight's state, and the trips (plan 026). No depth.
stopifnot(dup_keys(pq(stg("aflaskeyti", "coordinates")), "\".sid\"") == 0,
          dup_keys(pq(stg("aflaskeyti", "station_trip")), "\".sid\"") == 0,
          dup_keys(pq(stg("aflaskeyti", "time")), "\".sid\"") == 0,
          dup_keys(pq(stg("aflaskeyti", "weight")), "\".sid\", sid") == 0)
ex(sprintf("CREATE TEMP VIEW ers_station AS
  SELECT s.* EXCLUDE (lon1, lat1, lon2, lat2, \".tid\", \".ord\"), c.* EXCLUDE (\".sid\"), k.\".tid\", s.\".ord\"
  FROM %s s LEFT JOIN %s c ON c.\".sid\" IS NOT DISTINCT FROM s.\".sid\"
  LEFT JOIN %s k ON k.\".sid\" IS NOT DISTINCT FROM s.\".sid\"",
  pqo(stg("aflaskeyti", "station")), pq(stg("aflaskeyti", "coordinates")), pq(stg("aflaskeyti", "station_trip"))))
stopifnot(q("SELECT count(*) AS n FROM ers_station s WHERE s.\".tid\" IS NULL OR s.lat1 IS NULL OR NOT EXISTS
             (SELECT 1 FROM ers_trip t WHERE t.\".tid\" = s.\".tid\")")$n == 0)

# The fishing samples and the catch, each source's as staged; aflaskeyti's times and weights from its side tables.
ex(sprintf("CREATE TEMP VIEW afli_sample AS SELECT * FROM %s", tid_char(pqo(stg("afli", "fishing_sample")))))
ex(sprintf("CREATE TEMP VIEW fs_sample AS SELECT * FROM %s", tid_char(pqo(stg("fs_afladagbok", "fishing_sample")))))
ex(sprintf("CREATE TEMP VIEW adb_sample AS SELECT * FROM %s", pqo(stg("adb", "fishing_sample"))))
ex(sprintf("CREATE TEMP VIEW ers_sample AS
  SELECT s.* EXCLUDE (t1, t2, t3, t4, \".tid\", \".ord\"), t.* EXCLUDE (\".sid\"), k.\".tid\", s.\".ord\"
  FROM %s s LEFT JOIN %s t ON t.\".sid\" IS NOT DISTINCT FROM s.\".sid\"
  LEFT JOIN %s k ON k.\".sid\" IS NOT DISTINCT FROM s.\".sid\"",
  pqo(stg("aflaskeyti", "fishing_sample")), pq(stg("aflaskeyti", "time")), pq(stg("aflaskeyti", "station_trip"))))
ex(sprintf("CREATE TEMP VIEW afli_catch AS SELECT * FROM %s", pqo(stg("afli", "catch"))))
ex(sprintf("CREATE TEMP VIEW fs_catch AS SELECT * FROM %s", pqo(stg("fs_afladagbok", "catch"))))
ex(sprintf("CREATE TEMP VIEW adb_catch AS SELECT * FROM %s", pqo(stg("adb", "catch"))))
ex(sprintf("CREATE TEMP VIEW ers_catch AS
  SELECT c.* EXCLUDE (condition, catch_whole, \".ord\"), w.condition, w.catch_whole, w.condition_basis, c.\".ord\"
  FROM %s c LEFT JOIN %s w ON w.\".sid\" IS NOT DISTINCT FROM c.\".sid\" AND w.sid IS NOT DISTINCT FROM c.sid",
  pqo(stg("aflaskeyti", "catch")), pq(stg("aflaskeyti", "weight"))))

# The four sources bound, as bind_rows() bound them: `src` is the source's place, 1-4, and a column one source lacks
# is NA in the others. Dates are timestamps, as afli's are.
bound <- function(views, extra = "") paste(sprintf("SELECT %d AS src, * %s FROM %s", seq_along(views), extra, views),
                                           collapse = " UNION ALL BY NAME ")
ex(sprintf("CREATE TEMP VIEW trip_u AS %s", bound(c("afli_trip", "fs_trip", "adb_trip", "ers_trip"))))
ex(sprintf("CREATE TEMP VIEW station_u AS %s", bound(c("afli_station", "fs_station", "adb_station", "ers_station"),
                                                    "REPLACE (\"date\"::TIMESTAMP AS \"date\")")))
ex(sprintf("CREATE TEMP VIEW sample_u AS %s", bound(c("afli_sample", "fs_sample", "adb_sample", "ers_sample"))))
ex(sprintf("CREATE TEMP VIEW catch_u AS %s", bound(c("afli_catch", "fs_catch", "adb_catch", "ers_catch"))))

# Fate: every staging station and trip -----------------------------------------
# The rows of station_fate and trip_fate, taken before any rule drops one: each station with its tier key (`vid` from
# its staging trip, `date`), each trip, and each station's catch as recorded (`kg`) and whole weight
# (R/whole_weight.R), summed from the whole staging catch, so a catch row no station carries shows as kg missing.
# aflaskeyti's trips are curate/aflaskeyti_trip.R's, the ones the merge reads. The station's key, (.sid, schema), is
# one per staging station, which every join of the fate relies on.
stopifnot("a staging station has no fate row, or two" = dup_keys("station_u", "\".sid\", schema") == 0)
fate_catch <- Reduce(union_all, list(
  tbl(con, sql("SELECT * FROM afli_catch")) |>
    transmute(.sid, schema, condition = NA_character_, catch, catch_whole = NA_real_),
  tbl(con, sql("SELECT * FROM fs_catch")) |> select(.sid, schema, condition, catch, catch_whole),
  tbl(con, sql("SELECT * FROM adb_catch")) |> select(.sid, schema, condition, catch, catch_whole),
  tbl(con, sql("SELECT * FROM ers_catch")) |> select(.sid, schema, condition, catch, catch_whole)))
fate_catch |>
  calc_whole_weight(by = c(".sid", "schema"), kg = sum(as.numeric(catch), na.rm = TRUE)) |>
  rename(kg_whole = whole_weight, kg_whole_basis = whole_weight_basis) |>
  compute(name = "fate_kg", temporary = TRUE)
staging_kg <- fate_catch |> summarise(staging = sum(as.numeric(catch), na.rm = TRUE), .by = schema) |> collect()

# Apply date bounds ------------------------------------------------------------
# A station outside its source's bounds goes, and `.reason` keeps it with the bound it broke. An NA bound is none.
# `st` is every staging station with its tier key, its tier (afli's own stations 1, fs_afladagbok 2, afli's read from
# fs_afli 3, adb 4, aflaskeyti 5) and the reason it went, if it did.
bounds <- function(lo, hi) sprintf("CASE WHEN \"date\" IS NULL THEN 'date_missing' WHEN \"date\" < %s THEN 'date_before'
                                     WHEN \"date\" > %s THEN 'date_after' END",
                                   if (is.na(lo)) "NULL" else sprintf("DATE '%s'", lo),
                                   if (is.na(hi)) "NULL" else sprintf("DATE '%s'", hi))
ex(sprintf("CREATE TEMP TABLE st AS
  SELECT s.src, s.\".ord\", s.\".sid\", s.\".tid\", s.schema, s.copy, s.\"date\", t.vid,
         CASE WHEN s.src = 1 AND s.copy = 'afli' THEN 1 WHEN s.src = 2 THEN 2
              WHEN s.src = 1 AND s.copy = 'fs_afli' THEN 3 WHEN s.src = 3 THEN 4 WHEN s.src = 4 THEN 5 END AS tier,
         CASE s.src WHEN 1 THEN %s WHEN 2 THEN %s WHEN 3 THEN %s WHEN 4 THEN %s END AS \".reason\"
  FROM station_u s LEFT JOIN trip_u t ON t.src = s.src AND t.\".tid\" IS NOT DISTINCT FROM s.\".tid\"",
  bounds(NA, AFLI_DATE_MAX), bounds(FS_DATE_MIN, FS_DATE_MAX), bounds(ADB_DATE_MIN, ADB_DATE_MAX),
  bounds(NA, ERS_DATE_MAX)))

# Tier 1-4: afli, fs_afladagbok, fs_afli, adb, aflaskeyti ----------------------
# A tier keeps the stations on vessel-days no tier above it holds; the others go as `vessel_day_held`, so one rule
# makes both. afli is tier 1, less the stations read from fs_afli. Where afli or fs_afladagbok has the vessel-day, an
# fs_afli station is the same haul entered again (decision 123): of the 17 such stations, 14 carry the same kg as a
# station already there, and one has no catch. fs_afladagbok and adb are copies of one e-logbook (the same station
# ids), so from ADB_DATE_MIN until the dump ends adb keeps only the vessel-days the dump never received, and after it
# almost all of adb. aflaskeyti is the ERS catch reports of 2014-2018 (plan 026): no foreign vessel-day is held above;
# of the Icelandic vessels' hauls, those on vessel-days their logbook holds are the same hauls again (4,716 of 5,050
# within a minute), and the rest fill days nothing else holds (plan 026 §7).
ex("CREATE TEMP TABLE held (vid INTEGER, \"date\" TIMESTAMP)")
for (k in 1:5) {
  ex(sprintf("UPDATE st SET \".reason\" = 'vessel_day_held' WHERE tier = %d AND \".reason\" IS NULL AND EXISTS
             (SELECT 1 FROM held h WHERE h.vid IS NOT DISTINCT FROM st.vid AND h.\"date\" = st.\"date\")", k))
  ex(sprintf("INSERT INTO held SELECT DISTINCT vid, \"date\" FROM st WHERE tier = %d AND \".reason\" IS NULL", k))
}
# The kept stations in the order the merge writes them: afli's own, then those read from fs_afli, then the other
# sources'. A trip is kept while one of its stations is, a sample and the catch with their station (by .sid).
ex("ALTER TABLE st ADD COLUMN kept BOOLEAN")
ex("UPDATE st SET kept = tier IS NOT NULL AND \".reason\" IS NULL")
ex("CREATE TEMP TABLE ks AS SELECT DISTINCT src, \".sid\" FROM st WHERE kept")
ex("CREATE TEMP TABLE kt AS SELECT DISTINCT src, \".tid\" FROM st WHERE kept")

# Merge ------------------------------------------------------------------------
ex("CREATE TEMP VIEW station_k AS
  SELECT u.*, CASE k.tier WHEN 3 THEN 2 WHEN 2 THEN 3 ELSE k.tier END AS grp
  FROM station_u u JOIN st k ON k.src = u.src AND k.\".ord\" = u.\".ord\" WHERE k.kept")
ex("CREATE TEMP VIEW trip_k AS SELECT * FROM trip_u u
    WHERE EXISTS (SELECT 1 FROM kt WHERE kt.src = u.src AND kt.\".tid\" IS NOT DISTINCT FROM u.\".tid\")")
ex("CREATE TEMP VIEW sample_k AS SELECT * FROM sample_u u
    WHERE EXISTS (SELECT 1 FROM ks WHERE ks.src = u.src AND ks.\".sid\" IS NOT DISTINCT FROM u.\".sid\")")
ex("CREATE TEMP VIEW catch_k AS SELECT * FROM catch_u u
    WHERE EXISTS (SELECT 1 FROM ks WHERE ks.src = u.src AND ks.\".sid\" IS NOT DISTINCT FROM u.\".sid\")")
# The merged tables' keys and the few columns the rules below read. Each key is one row (dplyr's joins checked it).
ex("CREATE TEMP TABLE mt AS SELECT src, \".ord\", \".tid\", schema, vid, T1, T2, source FROM trip_k")
ex("CREATE TEMP TABLE ms AS SELECT src, \".ord\", \".sid\", \".tid\", schema, \"date\", eytt_deleted, record_entered,
    lat1, lon1, lat2, lon2 FROM station_k")
ex("CREATE TEMP TABLE mf AS SELECT src, \".ord\", \".sid\", \".tid\", schema, eytt_deleted, gid, gear, t1, t2, t3, t4,
    effort_count, effort_count_basis FROM sample_k")
stopifnot("a merged trip twice" = dup_keys("mt", "\".tid\", schema") == 0,
          "a merged station twice" = dup_keys("ms", "\".sid\", schema") == 0,
          "a merged sample twice" = dup_keys("mf", "\".sid\", schema") == 0)

# The count -------------------------------------------------------------------
# One count, effort_count, with its basis from the adapters (R/logbook_effort.R, plan 050 step 2). The sources' own
# counts stay in staging: n_units (afli's twin flag, a longline's sets, fs's tvo_veidarf) and n_total (afli's hooks,
# now effort_count). aflaskeyti records none.
stopifnot("a count has a basis, and only a missing count has none" =
            q("SELECT count(*) AS n FROM mf WHERE (effort_count IS NULL OR isnan(effort_count)) <>
               (coalesce(effort_count_basis, 'none') = 'none')")$n == 0)

# Twin records -----------------------------------------------------------------
# One operation entered as two or more stations (curate/corrections/logbook_twin.yml, decision 094). A twin
# group is the stations of one vessel, in one schema, with identical t1-t4, at least one of them a time of day:
# all at 00:00 is a date, several untimed stations of one day, not a twin. In a group, stations with identical
# catch (every species, condition and weight; no catch counts as a catch) are one record entered more than once:
# the first (not deleted, then lowest .sid) is `kept`, the others `duplicate`, with `twin_of` the kept .sid. A
# member whose catch matches no other member's is `same_time`, a record of its own whose times equal another's.
# The landings decided the rule (maintainer, 2026-10-14): a trip's logbook catch is about twice its landing with
# every copy counted and equal to it with one, while dropping a same-time record does not bring a trip nearer.
# A trip all of whose stations are duplicates of one other trip's is that trip submitted again: trip `twin`
# "duplicate" and `twin_of` the other trip's .tid, which is "kept". Nothing is dropped here; every table that
# sums catch or effort, and every link, leaves the duplicates out. The groups are found in DuckDB, the signatures
# made in R, on the groups' stations alone.
tod <- function(t) sprintf("(f.%1$s IS NOT NULL AND f.%1$s <> date_trunc('day', f.%1$s))", t)
tw <- q(sprintf("SELECT f.\".sid\", f.\".tid\", f.schema, f.eytt_deleted, f.t1, f.t2, f.t3, f.t4, t.vid
  FROM mf f LEFT JOIN mt t ON t.\".tid\" IS NOT DISTINCT FROM f.\".tid\" AND t.schema IS NOT DISTINCT FROM f.schema
  WHERE t.vid IS NOT NULL AND (%s OR %s OR %s OR %s)
  QUALIFY count(*) OVER (PARTITION BY t.vid, f.schema, f.t1, f.t2, f.t3, f.t4) > 1
  ORDER BY f.src, f.\".ord\"", tod("t1"), tod("t2"), tod("t3"), tod("t4")))
duckdb::duckdb_register(con, "tw_key", tw |> distinct(.sid, schema))
tw_sig <- q("SELECT c.\".sid\", c.sid, c.condition, c.catch, c.schema FROM catch_k c
             SEMI JOIN tw_key k
               ON k.\".sid\" IS NOT DISTINCT FROM c.\".sid\" AND k.schema IS NOT DISTINCT FROM c.schema") |>
  arrange(sid, condition, catch) |>
  summarise(sig = paste(sid, condition, catch, sep = ":", collapse = ","), .by = c(.sid, schema))
tw <- tw |>
  left_join(tw_sig, by = c(".sid", "schema"), relationship = "one-to-one") |>
  mutate(sig = coalesce(sig, "")) |>
  arrange(coalesce(eytt_deleted, FALSE), .sid) |>
  mutate(n_same = n(), kept_sid = first(.sid), kept_tid = first(.tid), .by = c(vid, schema, t1, t2, t3, t4, sig)) |>
  mutate(twin    = case_when(n_same == 1 ~ "same_time", .sid == kept_sid ~ "kept", .default = "duplicate"),
         twin_of = if_else(twin == "duplicate", kept_sid, NA_real_))
tw_trip <- tw |>
  filter(twin == "duplicate") |>
  summarise(n_dup = n(), n_kept_tid = n_distinct(kept_tid), kept_tid = first(kept_tid), .by = c(.tid, schema))
duckdb::duckdb_register(con, "tw_dup_trip", tw_trip |> select(.tid, schema))
tw_trip <- tw_trip |>
  inner_join(q("SELECT s.\".tid\", s.schema, count(*)::INTEGER AS n_st FROM ms s SEMI JOIN tw_dup_trip d
                ON d.\".tid\" IS NOT DISTINCT FROM s.\".tid\" AND d.schema IS NOT DISTINCT FROM s.schema GROUP BY ALL"),
             by = c(".tid", "schema")) |>
  filter(n_dup == n_st) |>
  mutate(twin = "duplicate", twin_of = if_else(n_kept_tid == 1, kept_tid, NA_character_))
tw_trip <- bind_rows(
  tw_trip |> select(.tid, schema, twin, twin_of),
  tw_trip |> filter(!is.na(twin_of)) |> distinct(.tid = twin_of, schema) |> mutate(twin = "kept"))
stopifnot(!anyDuplicated(tw_trip[c(".tid", "schema")]))
tw <- tw |> select(.sid, schema, twin, twin_of)
duckdb::duckdb_register(con, "tw_station", tw)
duckdb::duckdb_register(con, "tw_trip", tw_trip)

# Station type -----------------------------------------------------------------
# What a station row covers (`station_type` in docs/grammar.qmd, decision 084): `operation`, one setting, tow
# or haul, or `event`, one record for the day. No logbook says which, and it varies by vessel and over time,
# so it is read per vessel, year and gear from the vessel's own pattern: the share of its fishing days with
# more than one record. Vessel-years pile up at 0 and near 1; below ST_MULTI_MIN is one record a day.
# Longlines are `operation` whatever the share (maintainer, 2026-10-09): one set a day is what a longliner
# does, so a single record a day says nothing. Here, on the merged tables, because the tiers mix schemas
# within a vessel-year; deleted records and duplicate twins are left out of the pattern. The share is one division
# of two counts, as R's mean() of a logical is.
ST_MULTI_MIN <- 0.1
ex(sprintf("CREATE TEMP TABLE station_type AS
  WITH base AS (
    SELECT s.\".sid\", s.schema, s.\"date\", s.eytt_deleted, w.twin, t.vid, f.gear, year(s.\"date\") AS yr
    FROM ms s
    LEFT JOIN mt t ON t.\".tid\" IS NOT DISTINCT FROM s.\".tid\" AND t.schema IS NOT DISTINCT FROM s.schema
    LEFT JOIN mf f ON f.\".sid\" IS NOT DISTINCT FROM s.\".sid\" AND f.schema IS NOT DISTINCT FROM s.schema
    LEFT JOIN tw_station w ON w.\".sid\" IS NOT DISTINCT FROM s.\".sid\" AND w.schema IS NOT DISTINCT FROM s.schema),
  pattern AS (
    SELECT vid, yr, gear, count(*) FILTER (WHERE n > 1)::DOUBLE / count(*)::DOUBLE AS multi_share
    FROM (SELECT vid, yr, gear, \"date\", count(*) AS n FROM base
          WHERE NOT coalesce(eytt_deleted, false) AND NOT coalesce(twin = 'duplicate', false) AND vid IS NOT NULL
            AND \"date\" IS NOT NULL
          GROUP BY ALL)
    GROUP BY ALL)
  SELECT b.\".sid\", b.schema,
         CASE WHEN p.multi_share >= %1$s THEN 'operation'
              WHEN b.gear = 'LLS' AND p.multi_share IS NOT NULL THEN 'operation'
              WHEN p.multi_share IS NOT NULL THEN 'event' END AS station_type,
         CASE WHEN p.multi_share >= %1$s THEN 'derived'
              WHEN b.gear = 'LLS' AND p.multi_share IS NOT NULL THEN 'synthesised'
              WHEN p.multi_share IS NOT NULL THEN 'derived' ELSE 'none' END AS station_type_basis
  FROM base b LEFT JOIN pattern p
    ON p.vid IS NOT DISTINCT FROM b.vid AND p.yr IS NOT DISTINCT FROM b.yr AND p.gear IS NOT DISTINCT FROM b.gear",
  dbl(ST_MULTI_MIN)))

# App --------------------------------------------------------------------------
# The app that wrote each e-logbook station (plan 053 step 2), as the profile names it
# (curate/corrections/logbook_app_profile.yml, vocabulary): fs_afladagbok's trip uppruni and adb's trip source, with
# the suffixes " - GAFL AUTO" and " - Skrifstofa VES" apart in app_suffix; on the afli route the message's software
# and its major.minor version, as the sent layer holds them (staging/afli_sent, decision 180), by .sid. app_raw is the
# string as written, app_version the sent message's whole version. A paper record and aflaskeyti's ERS reports have
# none.
APP_SUFFIX <- " - (GAFL AUTO|Skrifstofa VES)"
# Each name is read once, from the distinct strings, and joined to the trips and stations that carry it.
trip_app <- q("SELECT DISTINCT source FROM mt WHERE schema IN ('fs_afladagbok', 'adb')") |>
  transmute(source, app_raw = str_trim(source),
            app = str_trim(str_remove_all(app_raw, APP_SUFFIX)),
            app_suffix = str_remove(str_extract(app_raw, str_c("(", APP_SUFFIX, ")+$")), "^ - "))
sent_app <- q(sprintf("SELECT DISTINCT app, app_version FROM %s WHERE app IS NOT NULL",
                      pq(stg("afli_sent", "station")))) |>
  transmute(app_raw = app, app_version,
            app = str_squish(str_c(str_trim(str_extract(app_raw, "[^-]+$")), " ",
                                   coalesce(str_extract(app_version, "^[0-9]+\\.[0-9]+"), ""))))
duckdb::duckdb_register(con, "trip_app", trip_app)
duckdb::duckdb_register(con, "sent_app", sent_app)
ex(sprintf("CREATE TEMP VIEW sent_station AS SELECT \".sid\", 'afli' AS schema, app, app_version FROM %s
            WHERE app IS NOT NULL", pq(stg("afli_sent", "station"))))
stopifnot(dup_keys("sent_station", "\".sid\"") == 0)
ex("CREATE TEMP TABLE station_app AS
  SELECT s.\".sid\", s.schema, a.app_raw, a.app, a.app_suffix, NULL::VARCHAR AS app_version
  FROM ms s JOIN mt t ON t.\".tid\" IS NOT DISTINCT FROM s.\".tid\" AND t.schema IS NOT DISTINCT FROM s.schema
  JOIN trip_app a ON a.source IS NOT DISTINCT FROM t.source
  WHERE s.schema IN ('fs_afladagbok', 'adb')
  UNION ALL
  SELECT s.\".sid\", s.schema, a.app_raw, a.app, NULL::VARCHAR AS app_suffix, a.app_version
  FROM ms s JOIN sent_station x ON x.\".sid\" IS NOT DISTINCT FROM s.\".sid\" AND x.schema IS NOT DISTINCT FROM s.schema
  JOIN sent_app a ON a.app_raw IS NOT DISTINCT FROM x.app AND a.app_version IS NOT DISTINCT FROM x.app_version
  WHERE s.schema = 'afli'")

# Gear code --------------------------------------------------------------------
# The letter twin of the new gid, one each (curated/reference/gear.parquet, plan 050): of the logbook's own gear, as
# `gear` here is. The landing's correction carries the code of the gear it uses (curate/corrections/logbook_gear.R).
ex(sprintf("CREATE TEMP TABLE gear_code AS SELECT gid, gear_code FROM %s WHERE version = 'new'",
           pq(fd_curated("reference", "gear.parquet"))))
stopifnot(dup_keys("gear_code", "gid") == 0)

# App profile ------------------------------------------------------------------
# Each app's habits found by rule (curate/corrections/logbook_app_profile.yml, plan 053 steps 5 and 6;
# R/logbook_app_profile.R), after the twins, which compare the times as recorded. Every value stays as recorded:
# t1_flag ... t4_flag say what a time holds, *_rule the row, *_action what the flow does with it ("flag": left out of
# every window, link and duration, through judged_time_sql(); "note": kept). The rows read each station's app
# (decision 253), its gear class (gear_window, by the logbook's own gid), its trip's departure and landing (the afli
# route's departure from its sent layer, staging/afli_sent/trip.parquet), the record's entry time (record_entered, fs
# and adb) and, for Fontos raun's vessels, the vessel's previous station (row T7: duplicate twins out). They are tried
# on the e-logbook's stations and on afli's with a set time; no row applies to the others. Until plan 053 a placeholder
# t1 was set to NA here (decision 157); t1_placeholder stays one release, as t1_flag "placeholder". The frame is read
# from DuckDB in the merged order, and the flags go back keyed by the row (src, .ord).
profile <- app_profile()
ex(sprintf("CREATE TEMP TABLE app_gear AS SELECT gid::DOUBLE AS gid, gear_class FROM %s",
           pq(fd_curated("reference", "gear_window.parquet"))))
ex(sprintf("CREATE TEMP TABLE afli_departure AS SELECT s.\".sid\", 'afli' AS schema, t.T1 AS sent_departure
            FROM %s s JOIN %s t ON t.\".tid\" = s.\".tid\"",
           pq(stg("afli_sent", "station")), pq(stg("afli_sent", "trip"))))
stopifnot(dup_keys("app_gear", "gid") == 0, dup_keys("afli_departure", "\".sid\"") == 0)
AP_ROWS <- "f.schema IN ('fs_afladagbok', 'adb') OR (f.schema = 'afli' AND f.t1 IS NOT NULL)"
ap <- q(sprintf("SELECT f.src, f.\".ord\", f.\".sid\", f.\".tid\", f.schema, f.gid, f.gear, f.t1, f.t2, f.t3, f.t4,
                        g.gear_class, a.app, s.\"date\", w.twin, s.record_entered, s.lat1, s.lon1, s.lat2, s.lon2,
                        t.vid, t.T1, t.T2, d.sent_departure
  FROM mf f
  LEFT JOIN app_gear g ON g.gid IS NOT DISTINCT FROM f.gid
  LEFT JOIN ms s ON s.\".sid\" IS NOT DISTINCT FROM f.\".sid\" AND s.schema IS NOT DISTINCT FROM f.schema
  LEFT JOIN station_app a ON a.\".sid\" IS NOT DISTINCT FROM f.\".sid\" AND a.schema IS NOT DISTINCT FROM f.schema
  LEFT JOIN tw_station w ON w.\".sid\" IS NOT DISTINCT FROM f.\".sid\" AND w.schema IS NOT DISTINCT FROM f.schema
  LEFT JOIN mt t ON t.\".tid\" IS NOT DISTINCT FROM f.\".tid\" AND t.schema IS NOT DISTINCT FROM f.schema
  LEFT JOIN afli_departure d ON d.\".sid\" IS NOT DISTINCT FROM f.\".sid\" AND d.schema IS NOT DISTINCT FROM f.schema
  WHERE %s ORDER BY f.src, f.\".ord\"", AP_ROWS)) |>
  mutate(gear_class = app_gear_class(gear_class, gear), date = as.Date(date),
         departure  = if_else(schema == "afli", sent_departure, T1),
         landing    = if_else(schema == "afli", NA_POSIXct_, T2))
duckdb::duckdb_register(con, "fontos_vid", tibble(vid = unique(ap$vid[ap$app %in% "Fontos raun"])))
app_prev <- q("SELECT f.\".sid\", f.\".tid\", f.schema, f.t1, f.t2, f.t3, f.t4, t.vid, w.twin
  FROM mf f
  LEFT JOIN mt t ON t.\".tid\" IS NOT DISTINCT FROM f.\".tid\" AND t.schema IS NOT DISTINCT FROM f.schema
  LEFT JOIN tw_station w ON w.\".sid\" IS NOT DISTINCT FROM f.\".sid\" AND w.schema IS NOT DISTINCT FROM f.schema
  SEMI JOIN fontos_vid v ON v.vid IS NOT DISTINCT FROM t.vid") |>
  filter(!twin %in% "duplicate") |>
  arrange(vid, coalesce(t3, t1, t2), coalesce(t4, t3, t1, t2), .sid, schema) |>
  mutate(prev_t3 = lag(t3), prev_t4 = lag(t4), .by = vid) |>
  select(.sid, schema, prev_t3, prev_t4)
ap <- ap |> left_join(app_prev, by = c(".sid", "schema"), relationship = "one-to-one")
stopifnot("the app profile's frame is not the sample's rows" =
            nrow(ap) == q(sprintf("SELECT count(*) AS n FROM mf f WHERE %s", AP_ROWS))$n &&
              !anyDuplicated(ap[c("src", ".ord")]))
ap_times <- flag_app_times(ap, profile)
flagged <- function(d) d[rowSums(!is.na(d[setdiff(names(d), c("src", ".ord", ".sid", ".tid", "schema"))])) > 0, ]
duckdb::duckdb_register(con, "app_time", flagged(bind_cols(ap |> select(src, .ord), ap_times)))
duckdb::duckdb_register(con, "app_trip", flag_app_trips(ap, profile))
ap$t1_rule <- ap_times$t1_rule
duckdb::duckdb_register(con, "app_pos", bind_cols(ap |> select(.sid, schema), flag_app_positions(ap, profile)) |>
                          filter(!is.na(pos1_flag) | !is.na(pos2_flag)))
app_catch <- q("SELECT src, \".ord\", \".sid\", schema, sid FROM catch_k WHERE schema = 'adb' ORDER BY src, \".ord\"")
app_catch <- bind_cols(app_catch |> select(src, .ord),
                       app_catch |>
                         left_join(ap |> select(.sid, schema, app, date, gear, gear_class), by = c(".sid", "schema"),
                                   relationship = "many-to-one") |>
                         flag_app_catch(profile))
duckdb::duckdb_register(con, "app_catch", flagged(app_catch))

# Depth by app -----------------------------------------------------------------
# fs_afladagbok's and adb's depth in metres by the unit each app sends (the profile's rows D1-D5, plan 053 step 8;
# depth_by_app(), R/logbook_app_profile.R): Marína's and Taktikal's metres as sent (D2), every other app's fathoms x
# 1.8288 as before (D1, D3, and an app no row names, as the feed was read until now: decision 022). STOKKUR's depth of 0
# (D4) and Reiknistofa's copied end depth (D5) are flagged and read as none. z1_raw and z2_raw keep the value as sent,
# z_unit the unit read, z1_flag and z2_flag with their rule and action the flags. Until plan 053 every station of the
# two was read as fathoms here, Marína's and Taktikal's metres among them (decision 210).
app_depth <- q("SELECT k.\".sid\", k.schema, a.app, k.\"date\", k.z1_raw AS z1, k.z2_raw AS z2 FROM station_k k
  LEFT JOIN station_app a ON a.\".sid\" IS NOT DISTINCT FROM k.\".sid\" AND a.schema IS NOT DISTINCT FROM k.schema
  WHERE k.schema IN ('fs_afladagbok', 'adb')")
app_depth <- bind_cols(app_depth |> select(.sid, schema),
                       app_depth |> mutate(date = as.Date(date), gear = NA_character_, gear_class = NA_character_) |>
                         depth_by_app(profile) |> select(-z1_raw, -z2_raw))
stopifnot("an e-logbook station has two depth rows" = !anyDuplicated(app_depth[c(".sid", "schema")]))
duckdb::duckdb_register(con, "app_depth", app_depth)

# Station and trip fate --------------------------------------------------------
# Every staging station in one outcome (plan 024 §4). `in_curated` is read from the stations written, `reason` from
# the rule that dropped it. `held_by` is the tier whose kept stations hold the dropped station's vessel-day: the tiers'
# vessel-days are disjoint, so there is at most one, and a vessel-day with no vessel is never held. `day_match` sets
# the whole weight the source dropped on that vessel-day against the whole weight kept there, row against row: twins
# are judged only on the merged tables, so the kept side keeps its duplicates (decision 094) as the dropped side does.
# A record entered twice that both copies of the e-logbook hold is then equal; leaving duplicates out of the kept side
# only made 786 of adb's 799 such vessel-days against fs_afladagbok look like more dropped than kept (2026-10-23).
# The sums run in the stations' order, as R's sum() did.
DAY_MATCH_TOL <- 0.01
ex("CREATE TEMP TABLE sf AS
  SELECT st.src, st.\".ord\", st.\".sid\", st.\".tid\", st.schema, st.copy, st.vid, st.\"date\",
         k.kg::DOUBLE AS kg, k.kg_whole, coalesce(k.kg_whole_basis, 'none') AS kg_whole_basis,
         st.kept AS in_curated,
         CASE WHEN st.kept AND st.\".reason\" IS NULL THEN NULL WHEN NOT st.kept AND st.\".reason\" IS NOT NULL
              THEN st.\".reason\" ELSE 'other' END AS reason
  FROM st LEFT JOIN fate_kg k
    ON k.\".sid\" IS NOT DISTINCT FROM st.\".sid\" AND k.schema IS NOT DISTINCT FROM st.schema")
ex("CREATE TEMP TABLE kept_day AS
    SELECT DISTINCT vid, \"date\", CASE WHEN schema = 'afli' THEN copy ELSE schema END AS held_by
    FROM sf WHERE in_curated AND vid IS NOT NULL")
stopifnot("two tiers hold one vessel-day" = dup_keys("kept_day", "vid, \"date\"") == 0)
ex(sprintf("CREATE TEMP TABLE day_match AS
  WITH dropped AS (
    SELECT sf.schema, sf.copy, sf.vid, sf.\"date\",
           coalesce(sum(sf.kg_whole ORDER BY sf.src, sf.\".ord\"), 0) AS dropped_whole
    FROM sf JOIN kept_day d ON d.vid = sf.vid AND d.\"date\" = sf.\"date\"
    WHERE NOT sf.in_curated AND d.held_by IS NOT NULL GROUP BY ALL),
  held AS (
    SELECT sf.vid, sf.\"date\", coalesce(sum(sf.kg_whole ORDER BY sf.src, sf.\".ord\"), 0) AS held_whole
    FROM sf SEMI JOIN dropped d ON d.vid = sf.vid AND d.\"date\" = sf.\"date\"
    WHERE sf.in_curated GROUP BY ALL)
  SELECT d.schema, d.copy, d.vid, d.\"date\",
         CASE WHEN abs(d.dropped_whole - coalesce(h.held_whole, 0)) <=
                   %s * greatest(d.dropped_whole, coalesce(h.held_whole, 0)) THEN 'equal'
              WHEN coalesce(h.held_whole, 0) > d.dropped_whole THEN 'held_more' ELSE 'dropped_more' END AS day_match
  FROM dropped d LEFT JOIN held h ON h.vid IS NOT DISTINCT FROM d.vid AND h.\"date\" IS NOT DISTINCT FROM d.\"date\"",
  dbl(DAY_MATCH_TOL)))
STATION_FATE <- "SELECT sf.\".sid\", sf.\".tid\", sf.schema, sf.copy, sf.vid, sf.\"date\", sf.kg, sf.kg_whole,
         sf.kg_whole_basis, sf.in_curated, sf.reason, CASE WHEN NOT sf.in_curated THEN d.held_by END AS held_by,
         m.day_match
  FROM sf LEFT JOIN kept_day d ON d.vid = sf.vid AND d.\"date\" = sf.\"date\"
  LEFT JOIN day_match m ON m.schema IS NOT DISTINCT FROM sf.schema AND m.copy IS NOT DISTINCT FROM sf.copy
    AND m.vid IS NOT DISTINCT FROM sf.vid AND m.\"date\" IS NOT DISTINCT FROM sf.\"date\"
  ORDER BY sf.src, sf.\".ord\""

# A trip is kept while one of its stations is. A dropped trip takes its stations' reason, `mixed` when they went for
# different reasons, and `no_station` when it never had one.
ex("CREATE TEMP TABLE trip_station AS SELECT \".tid\", schema, count(*)::INTEGER AS n_station,
    sum(in_curated::INTEGER)::INTEGER AS n_kept, count(kg)::INTEGER AS n_catch, sum(kg) AS kg FROM sf GROUP BY ALL")
ex("CREATE TEMP TABLE trip_fate AS
  WITH trip_reason AS (
    SELECT \".tid\", schema, CASE WHEN count(DISTINCT reason) = 1 THEN min(reason) ELSE 'mixed' END AS \".reason\"
    FROM sf WHERE NOT in_curated GROUP BY ALL)
  SELECT u.src, u.\".ord\", u.\".tid\", u.schema, u.vid, u.T1, u.T2, coalesce(s.n_station, 0)::INTEGER AS n_station,
         coalesce(s.n_kept, 0)::INTEGER AS n_kept, CASE WHEN coalesce(s.n_catch, 0) > 0 THEN s.kg END AS kg,
         EXISTS (SELECT 1 FROM mt WHERE mt.\".tid\" IS NOT DISTINCT FROM u.\".tid\"
                 AND mt.schema IS NOT DISTINCT FROM u.schema) AS in_curated, r.\".reason\"
  FROM trip_u u
  LEFT JOIN trip_station s ON s.\".tid\" IS NOT DISTINCT FROM u.\".tid\" AND s.schema IS NOT DISTINCT FROM u.schema
  LEFT JOIN trip_reason r ON r.\".tid\" IS NOT DISTINCT FROM u.\".tid\" AND r.schema IS NOT DISTINCT FROM u.schema")
ex("ALTER TABLE trip_fate ADD COLUMN reason VARCHAR")
ex("UPDATE trip_fate SET reason = CASE WHEN in_curated AND n_kept > 0 THEN NULL WHEN NOT in_curated AND n_station = 0
    THEN 'no_station' WHEN NOT in_curated AND n_kept = 0 AND \".reason\" IS NOT NULL THEN \".reason\" ELSE 'other' END")
TRIP_FATE <- "SELECT \".tid\", schema, vid, T1, T2, n_station, n_kept, kg, in_curated, reason FROM trip_fate
  ORDER BY src, \".ord\""

# The fate's invariants: the merge stops rather than write an account that does not add up.
fate_kg_check <- q("SELECT schema, sum(kg) FILTER (WHERE in_curated) AS kept,
                           sum(kg) FILTER (WHERE NOT in_curated) AS dropped FROM sf GROUP BY ALL") |>
  full_join(staging_kg, by = "schema") |>
  full_join(q("SELECT schema, sum(catch::DOUBLE) AS curated FROM catch_k GROUP BY ALL"), by = "schema") |>
  mutate(across(c(kept, dropped, staging, curated), \(x) coalesce(x, 0)))
fate_n <- q("SELECT (SELECT count(*) FROM sf) AS station_fate, (SELECT count(*) FROM station_u) AS station_u,
               (SELECT count(*) FROM trip_fate) AS trip_fate, (SELECT count(*) FROM trip_u) AS trip_u,
               (SELECT count(*) FROM trip_station s WHERE NOT EXISTS (SELECT 1 FROM trip_u u WHERE
                  u.\".tid\" IS NOT DISTINCT FROM s.\".tid\" AND u.schema IS NOT DISTINCT FROM s.schema)) AS stray,
               (SELECT count(*) FILTER (WHERE in_curated) FROM sf) AS station_kept, (SELECT count(*) FROM ms) AS ms,
               (SELECT count(*) FILTER (WHERE in_curated) FROM trip_fate) AS trip_kept, (SELECT count(*) FROM mt) AS mt,
               (SELECT count(*) FILTER (WHERE reason = 'other') FROM sf) +
                 (SELECT count(*) FILTER (WHERE reason = 'other') FROM trip_fate) AS other")
stopifnot(
  "a staging station has no fate row, or two" =
    fate_n$station_fate == fate_n$station_u && dup_keys("sf", "\".sid\", schema") == 0,
  "a staging trip has no fate row, or two" =
    fate_n$trip_fate == fate_n$trip_u && dup_keys("trip_fate", "\".tid\", schema") == 0,
  "a station's trip is not a staging trip" = fate_n$stray == 0,
  "in_curated is not curated/logbook/station's keys" = fate_n$station_kept == fate_n$ms,
  "in_curated is not curated/logbook/trip's keys" = fate_n$trip_kept == fate_n$mt,
  "staging kg is not kept + dropped" = all(fate_kg_check$staging == fate_kg_check$kept + fate_kg_check$dropped),
  "kept kg is not curated/logbook/catch's" = all(fate_kg_check$kept == fate_kg_check$curated),
  "a station or trip is dropped by no rule (reason other)" = fate_n$other == 0)

# Summary ----------------------------------------------------------------------
cnt <- q("SELECT count(*) FILTER (WHERE kept AND src = 1) AS afli, count(*) FILTER (WHERE kept AND tier = 3) AS afli_fs,
                 count(*) FILTER (WHERE tier = 3 AND coalesce(\".reason\", '') IN ('', 'vessel_day_held'))
                   AS afli_fs_all,
                 count(*) FILTER (WHERE kept AND src = 2) AS fs, count(*) FILTER (WHERE kept AND src = 3) AS adb,
                 count(*) FILTER (WHERE kept AND src = 4) AS ers,
                 count(*) FILTER (WHERE src = 4 AND coalesce(\".reason\", '') IN ('', 'vessel_day_held')) AS ers_all,
                 count(*) FILTER (WHERE kept) AS merged FROM st")
cnt_trip <- unlist(q("SELECT count(*) FILTER (WHERE src = 1) AS \"1\", count(*) FILTER (WHERE src = 2) AS \"2\",
                             count(*) FILTER (WHERE src = 3) AS \"3\", count(*) FILTER (WHERE src = 4) AS \"4\"
                      FROM mt"))
cat(sprintf("afli stations (filtered):   %d\n", cnt$afli))
cat(sprintf("  of them read from fs_afli: %d of %d\n", cnt$afli_fs, cnt$afli_fs_all))
cat(sprintf("fs-only stations:           %d\n", cnt$fs))
cat(sprintf("adb-only stations:          %d\n", cnt$adb))
cat(sprintf("aflaskeyti-only stations:   %d of %d\n", cnt$ers, cnt$ers_all))
cat(sprintf("merged stations:            %d\n", cnt$merged))
cat(sprintf("afli trips (filtered):      %d\n", cnt_trip[["1"]]))
cat(sprintf("fs-only trips:              %d\n", cnt_trip[["2"]]))
cat(sprintf("adb-only trips:             %d\n", cnt_trip[["3"]]))
cat(sprintf("aflaskeyti-only trips:      %d\n", cnt_trip[["4"]]))
cat(sprintf("merged trips:               %d\n", sum(cnt_trip)))
cat(sprintf("merged catch:               %d\n", q("SELECT count(*) AS n FROM catch_k")$n))

cat("\nStation type by gear (stations):\n")
q("SELECT f.gear, y.station_type, y.station_type_basis, count(*) AS n FROM station_type y
   LEFT JOIN mf f ON f.\".sid\" IS NOT DISTINCT FROM y.\".sid\" AND f.schema IS NOT DISTINCT FROM y.schema
   GROUP BY ALL") |>
  arrange(gear, station_type, station_type_basis) |>
  pivot_wider(names_from = c(station_type, station_type_basis), values_from = n, values_fill = 0) |>
  print(n = 30)

cat("\nTwin records (curate/corrections/logbook_twin.yml), stations and trips:\n")
tw |> filter(!is.na(twin)) |> count(schema, twin) |>
  pivot_wider(names_from = twin, values_from = n, values_fill = 0L) |> print()
tw_trip |> count(schema, twin, has_twin_of = !is.na(twin_of)) |> print()

cat("\nApp profile (curate/corrections/logbook_app_profile.yml): the times flagged or noted, by field, rule and action:\n")
bind_rows(lapply(c("t1", "t2", "t3", "t4"), \(f) bind_cols(ap |> select(schema), ap_times) |>
  filter(!is.na(.data[[paste0(f, "_rule")]])) |>
  count(schema, field = f, rule = .data[[paste0(f, "_rule")]], flag = .data[[paste0(f, "_flag")]],
        action = .data[[paste0(f, "_action")]]))) |> print(n = 100)
cat("\nthe trips' departure and landing, the positions and the catch:\n")
q("SELECT schema, 'T1' AS field, T1_rule AS rule, T1_action AS action, count(*) AS n FROM app_trip
   WHERE T1_rule IS NOT NULL GROUP BY ALL
   UNION ALL SELECT schema, 'T2', T2_rule, T2_action, count(*) FROM app_trip WHERE T2_rule IS NOT NULL GROUP BY ALL
   UNION ALL SELECT schema, 'pos1', pos1_rule, pos1_action, count(*) FROM app_pos
   WHERE pos1_rule IS NOT NULL GROUP BY ALL
   UNION ALL SELECT schema, 'pos2', pos2_rule, pos2_action, count(*) FROM app_pos
   WHERE pos2_rule IS NOT NULL GROUP BY ALL
   UNION ALL SELECT 'adb', 'species', species_rule, species_action, count(*) FROM app_catch
   WHERE species_rule IS NOT NULL GROUP BY ALL") |> print(n = 50)

cat("\nStation fate (station_fate.parquet), stations and kt as recorded, by schema and reason:\n")
q(sprintf("SELECT schema, reason, held_by, count(*) AS stations, round(coalesce(sum(kg), 0) / 1e6, 2) AS kt FROM (%s)
           GROUP BY ALL ORDER BY schema, reason, held_by", STATION_FATE)) |> print(n = 50)
cat("\nTrip fate (trip_fate.parquet), trips by schema and reason:\n")
q("SELECT schema, reason, count(*) AS n FROM trip_fate GROUP BY ALL") |> arrange(reason) |>
  pivot_wider(names_from = schema, values_from = n, values_fill = 0) |> print()
print(fate_kg_check)

cat("\nYear-by-year station source (2018+):\n")
q("SELECT schema, year(\"date\") AS yr, count(*) AS n FROM ms GROUP BY ALL") |>
  pivot_wider(names_from = schema, values_from = n, values_fill = 0) |>
  arrange(yr) |>
  filter(yr >= 2018) |>
  print()

# Export -----------------------------------------------------------------------
# Each file by one query, in the merge's row order; the columns in bind_rows()'s order, then what each rule added.
logbook_inputs <- c(
  unlist(lapply(c("afli", "fs_afladagbok", "adb"), \(s)
    c(fd_staging(s, "trip.parquet"), fd_staging(s, "station.parquet"),
      fd_staging(s, "fishing_sample.parquet"), fd_staging(s, "catch.parquet")))),
  fd_staging("afli", "depth.parquet"), fd_staging("afli", "end_longitude.parquet"), fd_staging("adb", "lon_sign.parquet"),
  AFLI_EAST_LON, fd_staging("afli_sent", "station.parquet"), fd_staging("afli_sent", "trip.parquet"), APP_PROFILE,
  fd_curated("reference", "gear.parquet"), fd_curated("reference", "gear_window.parquet"),
  unlist(lapply(c("station", "fishing_sample", "catch", "trip_landing", "station_trip", "coordinates", "time",
                  "weight"), \(t) fd_staging("aflaskeyti", paste0(t, ".parquet")))))
by_key <- function(a, b, key) paste(sprintf("%1$s.%3$s IS NOT DISTINCT FROM %2$s.%3$s", a, b, key), collapse = " AND ")
sample_cols <- setdiff(q("DESCRIBE SELECT * FROM sample_u")$column_name, c("src", ".ord", "n_units", "n_total"))
sample_sel  <- sprintf("u.\"%s\"", sample_cols)
sample_sel[sample_cols == "effort_count_basis"] <- "coalesce(u.effort_count_basis, 'none') AS effort_count_basis"
sample_sel  <- append(sample_sel, "g.gear_code", after = match("target2", sample_cols))
write <- function(sql, table)
  write_curated_sql(con, sql, fd_curated("logbook", paste0(table, ".parquet")), inputs = logbook_inputs)
write(sprintf("SELECT u.* EXCLUDE (src, \".ord\"), w.twin, w.twin_of, a.* EXCLUDE (\".tid\", schema) FROM trip_k u
  LEFT JOIN tw_trip w ON %s LEFT JOIN app_trip a ON %s ORDER BY u.src, u.\".ord\"",
  by_key("w", "u", c("\".tid\"", "schema")), by_key("a", "u", c("\".tid\"", "schema"))), "trip")
write(sprintf("SELECT u.* EXCLUDE (src, \".ord\", grp)
                      REPLACE (CASE WHEN dp.\".sid\" IS NULL THEN u.z1 ELSE dp.z1 END AS z1,
                               CASE WHEN dp.\".sid\" IS NULL THEN u.z2 ELSE dp.z2 END AS z2,
                               CASE WHEN dp.\".sid\" IS NULL THEN u.z1_basis ELSE dp.z1_basis END AS z1_basis,
                               CASE WHEN dp.\".sid\" IS NULL THEN u.z2_basis ELSE dp.z2_basis END AS z2_basis),
                      w.twin, w.twin_of, y.station_type, y.station_type_basis,
                      a.app_raw, a.app, a.app_suffix, a.app_version, p.* EXCLUDE (\".sid\", schema),
                      dp.z_unit, dp.z1_flag, dp.z1_rule, dp.z1_action, dp.z2_flag, dp.z2_rule, dp.z2_action
  FROM station_k u LEFT JOIN tw_station w ON %s LEFT JOIN station_type y ON %s LEFT JOIN station_app a ON %s
  LEFT JOIN app_pos p ON %s LEFT JOIN app_depth dp ON %s ORDER BY u.grp, u.\".ord\"",
  by_key("w", "u", c("\".sid\"", "schema")), by_key("y", "u", c("\".sid\"", "schema")),
  by_key("a", "u", c("\".sid\"", "schema")), by_key("p", "u", c("\".sid\"", "schema")),
  by_key("dp", "u", c("\".sid\"", "schema"))), "station")
write(sprintf("SELECT %s, %s, coalesce(t.t1_flag = 'placeholder', false) AS t1_placeholder FROM sample_k u
  LEFT JOIN gear_code g ON g.gid IS NOT DISTINCT FROM u.gid
  LEFT JOIN app_time t ON t.src = u.src AND t.\".ord\" = u.\".ord\"
  ORDER BY u.src, u.\".ord\"", paste(sample_sel, collapse = ", "), paste0("t.", names(ap_times), collapse = ", ")),
  "fishing_sample")
write("SELECT u.* EXCLUDE (src, \".ord\"), c.species_flag, c.species_rule, c.species_action FROM catch_k u
  LEFT JOIN app_catch c ON c.src = u.src AND c.\".ord\" = u.\".ord\" ORDER BY u.src, u.\".ord\"", "catch")
write(STATION_FATE, "station_fate")
write(TRIP_FATE, "trip_fate")
dbDisconnect(con, shutdown = TRUE)
