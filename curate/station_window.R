# station_window.R — when is the vessel busy with each logbook station?
# Side: flow, step 2. See plan 014.
#
# Input:  curated/logbook/gear.parquet         (.sid, schema, gid_used, metier, gear, target, target2: every station;
#                                               logbook_gear.R). `metier` (gear_target2, e.g. OTB_NEP) is the label
#                                               the flow works from downstream; the window rules are still per gid
#         curated/logbook/fishing_sample.parquet  (.sid, .tid, schema, gear, gid, t1..t4, duration_m)
#         curated/logbook/trip.parquet            (.tid, schema, vid)
#         curated/logbook/station.parquet         (.sid, schema, date)
#         curated/reference/gear_window.parquet   (gear_class, s1, s2, set_max_min)
# Output: curated/logbook/station_window.parquet
#
# One row per (station, phase). A station is not one interval: a trawl has one
# (tow), a net or longline has two short ones (set, haul) with the soak between
# them NOT a window, a jigger has one long one (jig), and a station with no usable
# times gets the station date (day). The class and its rule come from
# reference/gear/windows.R; plan 010 §2 has the reasoning and the measurements.
#
# KEYS. `.sid` and `.tid` are unique only WITHIN a schema: afli and fs_afladagbok
# number their stations and trips independently, so 15,184 station ids and 6,565
# trip ids occur in both. Everything here joins on (id, schema); a downstream table
# that joins on `.sid` alone will attach one schema's pings to the other's station.
#
# Every row also lists the events its STATION recorded (`events`, `n_events`), so a
# longline's set start (t1), haul start (t3) and haul end (t4) stay visible beside
# whichever window was drawn from them.
#
# win_basis says where the interval came from and is never dropped:
#   recorded     both ends are logbook times
#   derived      one end is a logbook time, the other comes from duration_m
#   synthesised  an end is an assumption: the typical haul length (per gear, median
#                of recorded t4 - t3), the set length (gear_window.set_max_min), or
#                the whole station date
#   capped       a recorded end passed the vessel's next recorded event and was cut
#                back to it (the raw times are kept beside the window, unchanged)
# A day window must never be treated as evidence of where the vessel was: the join
# in plan 010 §3 lets it claim only pings that no recorded window claims.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
lb <- function(f) fd_curated("logbook", f)

dbExecute(con, sprintf("CREATE VIEW fs   AS SELECT * FROM read_parquet('%s')", lb("fishing_sample.parquet")))
dbExecute(con, sprintf("CREATE VIEW trip AS SELECT * FROM read_parquet('%s')", lb("trip.parquet")))
dbExecute(con, sprintf("CREATE VIEW st   AS SELECT * FROM read_parquet('%s')", lb("station.parquet")))
# the gear each station is fished with: the logbook's, or its landing's where that names one gear (plan 014,
# curate/corrections/logbook_gear.R); adb stations have none of their own
dbExecute(con, sprintf("CREATE VIEW ag   AS SELECT * FROM read_parquet('%s')", lb("gear.parquet")))
dbExecute(con, sprintf("CREATE VIEW gw   AS SELECT * FROM read_parquet('%s')",
                       fd_curated("reference", "gear_window.parquet")))

# Base: one row per usable station --------------------------------------------

# A trip id that still maps to two vessels inside one schema cannot place its
# stations; they are left out and counted rather than guessed.
dbExecute(con, "
CREATE TABLE trip_vid AS
SELECT \".tid\" AS tid, schema, any_value(vid) AS vid
FROM trip WHERE vid IS NOT NULL
GROUP BY 1, 2 HAVING count(DISTINCT vid) = 1")

dbExecute(con, "
CREATE TABLE base AS
SELECT f.\".sid\", f.schema, f.\".tid\", tv.vid, ag.metier, ag.gear, ag.target,
       ag.target2,
       CAST(ag.gid_used AS INTEGER) AS gid, g.gear_class, g.s1, g.s2, g.set_max_min,
       -- adb keeps the raw start/end as t1/t4 whatever the gear (its gear is unknown in the adapter). For a
       -- towed gear fs_afladagbok maps them to t2/t3 and leaves t1/t4 NA; the same on the 1.4 M shared
       -- stations (adb t1 = fs t2, adb t4 = fs t3, 100 %). Without this every 2026 tow was a day window.
       CASE WHEN f.schema = 'adb' AND g.gear_class = 'towed' THEN NULL ELSE f.t1 END AS t1,
       CASE WHEN f.schema = 'adb' AND g.gear_class = 'towed' THEN f.t1 ELSE f.t2 END AS t2,
       CASE WHEN f.schema = 'adb' AND g.gear_class = 'towed' THEN f.t4 ELSE f.t3 END AS t3,
       CASE WHEN f.schema = 'adb' AND g.gear_class = 'towed' THEN NULL ELSE f.t4 END AS t4, f.duration_m,
       st.date
FROM fs f
JOIN trip_vid tv ON tv.tid = f.\".tid\" AND tv.schema = f.schema
JOIN st          ON st.\".sid\" = f.\".sid\" AND st.schema = f.schema
LEFT JOIN ag     ON ag.\".sid\" = f.\".sid\" AND ag.schema = f.schema
JOIN gw g        ON g.gid = CAST(ag.gid_used AS INTEGER)
WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NOT NULL")

# Windows ----------------------------------------------------------------------------
# The rules - the phases, the typical haul (median recorded haul per gear, from 50 hauls), capping at the
# vessel's next recorded event, the day fallback - are ramb::rb_build_record_windows() (plan 014 phase 2, an
# exact port of what stood here). This script supplies the Icelandic base: the vessel per trip, adb's gear
# from the landing, and adb's t1/t4 moved to t2/t3 for towed gear.

sw <- ramb::rb_build_record_windows(dplyr::tbl(con, "base"), key = c(".sid", "schema"), min_hauls = 50) |>
  dplyr::select(.sid, schema, .tid, vid, metier, gear, target, target2, gid, gear_class, phase, w_start, w_end,
                win_basis, win_closed_by, t1, t2, t3, t4, duration_m, s1, s2, n_events, events)
dbExecute(con, paste("CREATE TABLE station_window AS", dbplyr::sql_render(sw), "ORDER BY vid, w_start"))

# Report ----------------------------------------------------------------------------

q <- function(s) dbGetQuery(con, s)
message("\nstation_window: rows by class, phase and basis")
print(q("SELECT gear_class, phase, win_basis, count(*) n,
                round(median(epoch(w_end - w_start) / 60), 0) AS med_min
         FROM station_window GROUP BY ALL ORDER BY 1, 2, 3"))

message("\nstations left out, by reason")
print(q("
  SELECT 'no unambiguous vessel for the trip' AS reason, count(*) AS n FROM fs f
   WHERE NOT coalesce(f.eytt_deleted, false)
     AND NOT EXISTS (SELECT 1 FROM trip_vid tv WHERE tv.tid = f.\".tid\" AND tv.schema = f.schema)
  UNION ALL
  SELECT 'gear with no code (farm cage, mussel line)', count(*) FROM fs f
   JOIN gw g ON g.gid = CAST(f.gid AS INTEGER)
   WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NULL"))

bad <- q("SELECT count(*) n FROM station_window WHERE NOT (w_end > w_start)")$n
if (bad > 0) stop("station_window: ", bad, " windows with w_end <= w_start")
lost <- q("SELECT count(*) n FROM base b WHERE NOT EXISTS (
            SELECT 1 FROM station_window w WHERE w.\".sid\" = b.\".sid\" AND w.schema = b.schema)")$n
if (lost > 0) stop("station_window: ", lost, " stations produced no window")
dup <- q("SELECT count(*) n FROM (SELECT \".sid\", schema, phase FROM station_window
          GROUP BY ALL HAVING count(*) > 1)")$n
if (dup > 0) stop("station_window: ", dup, " (station, phase) pairs are not unique")

out <- dbGetQuery(con, "SELECT * FROM station_window")
out |> write_curated(lb("station_window.parquet"),
                     inputs = c(lb("fishing_sample.parquet"), lb("trip.parquet"),
                                lb("station.parquet"),
                                fd_curated("reference", "gear_window.parquet")))
dbDisconnect(con, shutdown = TRUE)
