# station_window.R — when is the vessel busy with each logbook station?
# Side: flow, step 2. See plan 014.
#
# Input:  curated/logbook/gear.parquet         (.sid, schema, gid_used, metier, gear, target, target2: every station;
#                                               logbook_gear.R). `metier` (gear_target2, e.g. OTB_NEP) is the label
#                                               the flow works from downstream; the window rules are still per gid
#         curated/logbook/fishing_sample.parquet  (.sid, .tid, schema, gear, gid, t1..t4, duration_m, and the app
#                                                  profile's t1_flag..t4_flag and t1_action..t4_action)
#         curated/logbook/trip.parquet            (.tid, schema, vid, T1, T2)
#         curated/logbook/station.parquet         (.sid, schema, date, twin)
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
#   derived      one end is a logbook time, the other comes from duration_m (the tour app's jig: its t1, made from
#                its spot time and its hours, .t1_source "synthesised")
#   synthesised  an end is an assumption: the typical haul length (per gear, median
#                of recorded t4 - t3), the set length (gear_window.set_max_min), or
#                the whole station date
#   capped       a tow, haul or jig end passed the vessel's next window and was cut
#                back to it (the raw times are kept beside the window, unchanged)
# A day window must never be treated as evidence of where the vessel was: the join
# in plan 010 §3 lets it claim only pings that no recorded window claims.
#
# One fix, one record (maintainer, decision 090; the rules are decision 091): apart
# from day windows, the windows of a vessel never overlap, and they are half-open,
# [w_start, w_end). A window ends where a later start that may cut it begins
# (win_closed_by = next_event): a tow, haul or jig with a recorded start cuts any
# window, a set (t1) only an earlier set. A set never cuts a haul: a gillnetter may
# set one net and go on hauling another (maintainer). A window that starts inside
# one it may not cut starts at that window's end (win_opened_by = previous_event);
# so do starts that are not logbook times (the typical haul before t4). Of two
# windows with the same start the shorter is cut to nothing (w_end = w_start, the
# row kept); of twins with the same times, the one with the higher (.sid, schema). A duplicate twin, the same
# record entered again, gets no window: its kept record stands for it (curate/corrections/logbook_twin.yml).
#
# The app profile (curate/corrections/logbook_app_profile.yml, plan 053 step 6): every time is read as
# judged_time_sql() reads it, so a time the profile flags opens and closes no window (a noted one does), and a station
# left with no usable time gets ramb's day window (row W1). Two of its rows give a window of their own:
#   trip_time  (T4, T10) the app wrote the trip's departure and return in the station's times. Where they are flagged,
#              the trip's departure and return stand in, the station's own value first, then the trip's T1 and T2: a
#              jig from departure to return, a haul from its own t3 (or the departure) to the return, a tow the same.
#              Such a window has basis derived where ramb's says recorded.
#   pressed    (T14) a tow or haul of 0-4 min: its end is left out and the window runs from its start to the gear's 95th
#              percentile span (span_p95_min, the e-logbook's recorded spans over 4 min, the placeholder stations'
#              hauls out, from 100 spans; plan 053 r07), or to the vessel's next station; basis synthesised. A pressed
#              haul enters ramb as two rows, its set and its haul drawn as a jig's window and named a haul after, so
#              its made-up end stays out of ramb's typical haul (the median recorded haul per gear).
# These ends enter ramb in the time slots and are not kept: the output's t1-t4, n_events and events are the judged
# times, as the windows read them.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
lb <- function(f) fd_curated("logbook", f)

dbExecute(con, sprintf("CREATE VIEW fs   AS SELECT * FROM read_parquet('%s')", lb("fishing_sample.parquet")))
dbExecute(con, sprintf("CREATE VIEW trip AS SELECT * FROM read_parquet('%s')", lb("trip.parquet")))
dbExecute(con, sprintf("CREATE VIEW st   AS SELECT * FROM read_parquet('%s')", lb("station.parquet")))
# the gear each station is fished with: the logbook's, or its landing's where that names one gear (plan 014,
# curate/corrections/logbook_gear.R)
dbExecute(con, sprintf("CREATE VIEW ag   AS SELECT * FROM read_parquet('%s')", lb("gear.parquet")))
dbExecute(con, sprintf("CREATE VIEW gw   AS SELECT * FROM read_parquet('%s')",
                       fd_curated("reference", "gear_window.parquet")))

# Base: one row per usable station --------------------------------------------

# A trip id that still maps to two vessels inside one schema cannot place its
# stations; they are left out and counted rather than guessed.
dbExecute(con, "
CREATE TABLE trip_vid AS
SELECT \".tid\" AS tid, schema, any_value(vid) AS vid, min(T1) AS T1, max(T2) AS T2
FROM trip WHERE vid IS NOT NULL
GROUP BY 1, 2 HAVING count(DISTINCT vid) = 1")

dbExecute(con, sprintf("
CREATE TABLE base0 AS
SELECT f.\".sid\", f.schema, f.\".tid\", tv.vid, ag.metier, ag.gear, ag.target,
       ag.target2,
       CAST(ag.gid_used AS INTEGER) AS gid, g.gear_class, g.s1, g.s2, g.set_max_min,
       -- adb's towed start and end were moved to t2/t3 here until plan 050 step 2; its adapter reads them as
       -- fs_afladagbok's does now (R/logbook_effort.R). The end an implausible duration ran to, and every time the app
       -- profile flags, are left out here, not in the sample (R/duration_limit.R, plan 050 ask h, plan 053 step 6).
       %s AS t1, %s AS t2, %s AS t3, %s AS t4, %s AS duration_m,
       st.date,
       coalesce(f.t1_flag = 'trip_time' OR f.t4_flag = 'trip_time', false) AS trip_time,
       CASE WHEN f.t1_flag = 'trip_time' THEN f.t1 ELSE tv.T1 END AS trip_start,
       CASE WHEN f.t4_flag = 'trip_time' THEN f.t4 ELSE tv.T2 END AS trip_end,
       coalesce(f.t3_flag = 'pressed' OR f.t4_flag = 'pressed', false) AS pressed,
       coalesce(f.t1_flag = 'placeholder', false) AS t1_placeholder,
       coalesce(f.\".t1_source\" = 'synthesised', false) AS t1_synthesised
FROM fs f
JOIN trip_vid tv ON tv.tid = f.\".tid\" AND tv.schema = f.schema
JOIN st          ON st.\".sid\" = f.\".sid\" AND st.schema = f.schema
LEFT JOIN ag     ON ag.\".sid\" = f.\".sid\" AND ag.schema = f.schema
JOIN gw g        ON g.gid = CAST(ag.gid_used AS INTEGER)
WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NOT NULL AND st.twin IS DISTINCT FROM 'duplicate'",
  judged_time_sql("t1", "f"), judged_time_sql("t2", "f"), judged_time_sql("t3", "f"), judged_time_sql("t4", "f"),
  judged_time_sql("duration_m", "f")))

# The gear's typical maximum (row T14): the 95th percentile of the e-logbook's recorded spans over 4 min, a tow's t2 to
# t3 and a haul's t3 to t4, the placeholder stations' hauls out, as plan 053's evidence measured it (r07).
dbExecute(con, "
CREATE TABLE span95 AS
SELECT gear, round(quantile_cont(m, 0.95)) AS span_p95_min, count(*) AS n FROM (
  SELECT gear, epoch(t3 - t2) / 60 AS m FROM base0
  WHERE schema IN ('fs_afladagbok', 'adb') AND gear_class = 'towed' AND epoch(t3 - t2) > 240
  UNION ALL
  SELECT gear, epoch(t4 - t3) / 60 FROM base0
  WHERE schema IN ('fs_afladagbok', 'adb') AND gear_class = 'static' AND epoch(t4 - t3) > 240 AND NOT t1_placeholder)
GROUP BY gear HAVING count(*) >= 100")

# The ends ramb is given for the trip-time and pressed stations (above); j1-j4 keep the judged times.
dbExecute(con, "
CREATE TABLE base1 AS
SELECT b.* EXCLUDE (t1, t2, t3, t4, trip_start, trip_end, t1_placeholder),
       b.t1 AS j1, b.t2 AS j2, b.t3 AS j3, b.t4 AS j4,
       CASE WHEN b.trip_time AND b.gear_class = 'jigged' THEN coalesce(b.t1, b.trip_start) ELSE b.t1 END AS t1,
       CASE WHEN b.trip_time AND b.gear_class = 'towed' THEN coalesce(b.t2, b.trip_start) ELSE b.t2 END AS t2,
       CASE WHEN b.trip_time AND b.gear_class = 'towed' THEN coalesce(b.t3, b.trip_end)
            WHEN b.trip_time AND b.gear_class = 'static' THEN coalesce(b.t3, b.trip_start)
            WHEN b.pressed AND b.gear_class = 'towed' AND b.t3 IS NULL
              THEN b.t2 + to_minutes(CAST(p.span_p95_min AS BIGINT))
            ELSE b.t3 END AS t3,
       CASE WHEN b.trip_time AND b.gear_class IN ('static', 'jigged') THEN coalesce(b.t4, b.trip_end)
            WHEN b.pressed AND b.gear_class = 'static' AND b.t4 IS NULL
              THEN b.t3 + to_minutes(CAST(p.span_p95_min AS BIGINT))
            ELSE b.t4 END AS t4,
       b.pressed AND p.span_p95_min IS NOT NULL
         AND ((b.gear_class = 'towed' AND b.t3 IS NULL AND b.t2 IS NOT NULL)
              OR (b.gear_class = 'static' AND b.t4 IS NULL AND b.t3 IS NOT NULL)) AS pressed_end
FROM base0 b LEFT JOIN span95 p USING (gear)")
dbExecute(con, "
CREATE TABLE base AS
SELECT *, false AS pressed_haul FROM base1 WHERE NOT (pressed_end AND gear_class = 'static')
UNION ALL BY NAME
SELECT * REPLACE (CAST(NULL AS TIMESTAMP) AS t3, CAST(NULL AS TIMESTAMP) AS t4), false AS pressed_haul
FROM base1 WHERE pressed_end AND gear_class = 'static'
UNION ALL BY NAME
SELECT * REPLACE ('jigged' AS gear_class, j3 AS t1, CAST(NULL AS TIMESTAMP) AS t3), true AS pressed_haul
FROM base1 WHERE pressed_end AND gear_class = 'static'")

# Windows ----------------------------------------------------------------------------
# The rules - the phases, the typical haul (median recorded haul per gear, from 50 hauls), the one-record cuts
# above, the day fallback - are ramb::rb_create_record_windows() (plan 014 phase 2 ported what stood here; ramb
# 2026.10.14.2 made the windows exclusive, decision 091). This script supplies the Icelandic base: the vessel
# per trip, and adb's gear from the landing.

# The judged times back in the slots, and the station's events counted from them, as ramb counts them.
n_events_sql <- paste0("CAST(", paste(sprintf("CASE WHEN j%d IS NOT NULL THEN 1 ELSE 0 END", 1:4), collapse = " + "),
                       " AS TINYINT)")
events_sql <- paste0("concat_ws('+', ", paste(sprintf("CASE WHEN j%1$d IS NOT NULL THEN 't%1$d' END", 1:4),
                                              collapse = ", "), ")")
sw <- ramb::rb_create_record_windows(dplyr::tbl(con, "base"), key = c(".sid", "schema"), min_hauls = 50) |>
  dplyr::mutate(phase = dplyr::if_else(pressed_haul, "haul", phase),
                gear_class = dplyr::if_else(pressed_haul, "static", gear_class)) |>
  dplyr::mutate(
    win_basis = dplyr::case_when(pressed_end & phase %in% c("tow", "haul") ~ "synthesised",
                                 trip_time & phase != "day" & win_basis == "recorded" ~ "derived",
                                 # the tour app's jig: t4 its spot time, t1 that less its hours (.t1_source)
                                 t1_synthesised & phase == "jig" & win_basis == "recorded" ~ "derived",
                                 .default = win_basis),
    t1 = j1, t2 = j2, t3 = j3, t4 = j4,
    n_events = dplyr::sql(n_events_sql), events = dplyr::sql(events_sql)) |>
  dplyr::select(.sid, schema, .tid, vid, metier, gear, target, target2, gid, gear_class, phase, w_start, w_end,
                win_basis, win_closed_by, win_opened_by, t1, t2, t3, t4, duration_m, s1, s2, n_events, events)
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
   WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NULL
  UNION ALL
  SELECT 'a duplicate twin (its kept record has the window)', count(*) FROM st
   WHERE NOT coalesce(st.eytt_deleted, false) AND st.twin = 'duplicate'"))

message("\nthe app profile's windows: trip-time stations (T4, T10) and pressed records (T14), by phase and basis")
print(q("SELECT CASE WHEN b.trip_time THEN 'trip_time' ELSE 'pressed' END AS kind, w.phase, w.win_basis, count(*) n
         FROM station_window w JOIN (SELECT DISTINCT \".sid\", schema, trip_time, pressed FROM base) b
         USING (\".sid\", schema) WHERE b.trip_time OR b.pressed
         GROUP BY ALL ORDER BY 1, 2, 3"))
message("\nthe gears' typical maximum (span_p95_min, row T14)")
print(q("SELECT * FROM span95 ORDER BY gear"))

message("\nwindows cut to nothing (w_end = w_start), by phase and what cut them")
print(q("SELECT phase, coalesce(win_opened_by, win_closed_by) AS by, count(*) n FROM station_window
         WHERE w_end = w_start GROUP BY ALL ORDER BY 1, 2"))

bad <- q("SELECT count(*) n FROM station_window WHERE NOT (w_end >= w_start)")$n
if (bad > 0) stop("station_window: ", bad, " windows with w_end < w_start")
bad <- q("SELECT count(*) n FROM station_window WHERE w_end = w_start AND win_closed_by IS DISTINCT FROM 'next_event'
            AND win_opened_by IS DISTINCT FROM 'previous_event'")$n
if (bad > 0) stop("station_window: ", bad, " empty windows that nothing cut")
ovl <- q("SELECT count(*) n FROM (
            SELECT w_start, max(w_end) OVER (PARTITION BY vid ORDER BY w_start, w_end
                                             ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_end
            FROM station_window WHERE phase <> 'day' AND w_end > w_start) WHERE prev_end > w_start")$n
if (ovl > 0) stop("station_window: ", ovl, " windows overlap an earlier window of the vessel")
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
