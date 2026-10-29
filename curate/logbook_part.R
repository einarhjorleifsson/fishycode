# The logbook's gear, rigging and per-haul sensor values for the stations the merge keeps (plan 052)
# Side: preprocessing (logbook). See plan 014.
# Input:  staging/{afli,fs_afladagbok,adb}/{gear_part,rigging_part,sensor_summary,part_column}.parquet;
#         curated/logbook/station.parquet (the kept stations and their twins), curated/logbook/fishing_sample.parquet
#         (its gear and effort_count only, for the checks)
# Output: curated/logbook/{gear_part,rigging_part,sensor_summary}.parquet
#         curated/check/logbook_part_station.parquet  every kept station in one outcome per table, by schema, copy,
#                                                     year and gear; and effort_count read from rigging_part against
#                                                     fishing_sample's, by schema, gear and outcome
#         curated/check/logbook_part_column.parquet   every source column of every layer and what became of its
#                                                     values (the staging accounts, bound)
#
# Written by Claude (AI), 2026-10-29 (decision 244); not checked by a person.
#
# Keyed on (.sid, schema), for the stations curated/logbook/station.parquet holds, duplicate twins left out (decision
# 094). aflaskeyti records no gear detail, and fs_afladagbok and adb no sensor value: their stations are counted, with
# no rows. The tables carry no time and read none: they do not move with the set times (TODO 164). fishing_sample's
# g_* columns stay one release beside them (decision 210 item 3), effort_count is still the adapters' (checked here).

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
})

SOURCES <- c("afli", "fs_afladagbok", "adb")
TABLES  <- c("gear_part", "rigging_part", "sensor_summary")
con <- dbConnect(duckdb::duckdb())
dbExecute(con, "SET memory_limit = '12GB'; SET preserve_insertion_order = false")
q   <- function(s) dbGetQuery(con, s)
pq  <- function(p) sprintf("read_parquet('%s')", p)
staged <- function(t) paste(sprintf("SELECT * FROM %s", pq(sapply(SOURCES, \(s) fd_staging(s, paste0(t, ".parquet"))))),
                            collapse = " UNION ALL BY NAME ")

# The kept stations ----------------------------------------------------------------------------------------------------
dbExecute(con, sprintf("CREATE TABLE st AS
  SELECT s.\".sid\" sid, s.\"schema\", s.copy, s.twin, year(s.\"date\")::INTEGER \"year\", f.gear,
         f.effort_count, f.effort_count_basis
  FROM %s s LEFT JOIN %s f USING (\".sid\", \"schema\")",
  pq(fd_curated("logbook", "station.parquet")), pq(fd_curated("logbook", "fishing_sample.parquet"))))
stopifnot("a station twice" = q("SELECT count(*) - count(DISTINCT (sid, \"schema\")) d FROM st")$d == 0)
dbExecute(con, "CREATE TABLE kept AS SELECT sid, \"schema\" FROM st WHERE twin IS NULL OR twin <> 'duplicate'")

# The tables -----------------------------------------------------------------------------------------------------------
inputs <- c(unlist(lapply(SOURCES, \(s) sapply(c(TABLES, "part_column"), \(t) fd_staging(s, paste0(t, ".parquet"))))),
            fd_curated("logbook", "station.parquet"), fd_curated("logbook", "fishing_sample.parquet"))
order <- c(gear_part = "\".sid\", \"schema\", part", rigging_part = "\".sid\", \"schema\", part",
           sensor_summary = "\".sid\", \"schema\", quantity, place, moment, instrument")
for (t in TABLES) {
  n <- write_curated_sql(con, sprintf("SELECT x.* FROM (%s) x SEMI JOIN kept k ON k.sid = x.\".sid\" AND k.\"schema\" = x.\"schema\"",
                                      staged(t)),
                         fd_curated("logbook", paste0(t, ".parquet")), inputs = inputs, order_by = order[[t]])
  cat(sprintf("%-15s %s rows\n", t, format(n, big.mark = ",")))
}
key <- c(gear_part = "\".sid\", \"schema\", part", rigging_part = "\".sid\", \"schema\", part",
         sensor_summary = "\".sid\", \"schema\", quantity, place, moment, instrument")
for (t in TABLES)
  if (q(sprintf("SELECT count(*) - count(DISTINCT (%s)) d FROM %s", key[[t]],
                pq(fd_curated("logbook", paste0(t, ".parquet")))))$d != 0) stop(t, ": a key twice")

# Every kept station in one outcome per table --------------------------------------------------------------------------
# rows: the table holds some; duplicate: a twin left out (decision 094); not_in_source: the source records none of
# the kind (aflaskeyti any; fs_afladagbok and adb a sensor value); none: the source records them, this station holds
# none (no gear row, or only empty fields).
outcome <- paste(sprintf("
  SELECT '%1$s' \"table\", s.\"schema\", s.copy, s.\"year\", s.gear,
    CASE WHEN s.twin = 'duplicate' THEN 'duplicate'
         WHEN x.sid IS NOT NULL THEN 'rows'
         WHEN s.\"schema\" = 'aflaskeyti' OR ('%1$s' = 'sensor_summary' AND s.\"schema\" <> 'afli') THEN 'not_in_source'
         ELSE 'none' END outcome,
    count(*)::DOUBLE stations, sum(coalesce(x.n, 0))::DOUBLE \"rows\"
  FROM st s LEFT JOIN (SELECT \".sid\" sid, \"schema\", count(*) n FROM %2$s GROUP BY ALL) x
    ON x.sid = s.sid AND x.\"schema\" = s.\"schema\"
  GROUP BY ALL", TABLES, sapply(TABLES, \(t) pq(fd_curated("logbook", paste0(t, ".parquet"))))), collapse = " UNION ALL ")

# effort_count against rigging_part ----------------------------------------------------------------------------------
# The count plan 052 §5 would read: a towed gear's rig, a longline's hooks in all, the nets, jigs and traps. Where
# rigging_part has none, fishing_sample's synthesised one gear (R/logbook_effort.R) is its own outcome.
effort <- sprintf("
  WITH r AS (
    SELECT \".sid\" sid, \"schema\",
      max(n) FILTER (WHERE part = 'rig') rig, max(n) FILTER (WHERE part = 'hook_total') hooks,
      max(n) FILTER (WHERE part = 'unit' AND \"type\" = 'net') nets, max(n) FILTER (WHERE part = 'unit' AND \"type\" = 'jig') jigs,
      max(n) FILTER (WHERE part = 'unit' AND \"type\" = 'trap') traps
    FROM %s GROUP BY ALL),
  c AS (
    SELECT s.\"schema\", s.gear, s.effort_count, s.effort_count_basis,
      CASE WHEN s.gear IN ('OTB', 'OTM', 'DRB') THEN r.rig WHEN s.gear = 'LLS' THEN r.hooks
           WHEN s.gear IN ('GNS', 'GND') THEN r.nets WHEN s.gear = 'LHM' THEN r.jigs WHEN s.gear = 'FPO' THEN r.traps END from_rigging
    FROM st s LEFT JOIN r ON r.sid = s.sid AND r.\"schema\" = s.\"schema\"
    WHERE s.twin IS NULL OR s.twin <> 'duplicate')
  SELECT 'effort_count' \"table\", \"schema\", NULL::VARCHAR AS copy, NULL::INTEGER \"year\", gear,
    CASE WHEN from_rigging = effort_count THEN 'equal'
         WHEN from_rigging IS NOT NULL AND effort_count IS NOT NULL THEN 'differs'
         WHEN from_rigging IS NULL AND effort_count_basis = 'synthesised' THEN 'synthesised, no rigging count'
         WHEN from_rigging IS NULL AND effort_count IS NULL THEN 'neither'
         WHEN from_rigging IS NULL THEN 'fishing_sample only'
         ELSE 'rigging_part only' END outcome,
    count(*)::DOUBLE stations, NULL::DOUBLE \"rows\"
  FROM c GROUP BY ALL", pq(fd_curated("logbook", "rigging_part.parquet")))
write_curated_sql(con, sprintf("SELECT * FROM (%s) UNION ALL SELECT * FROM (%s)", outcome, effort),
                  fd_curated("check", "logbook_part_station.parquet"),
                  inputs = inputs, order_by = "\"table\", \"schema\", copy, \"year\", gear, outcome")
write_curated_sql(con, staged("part_column"), fd_curated("check", "logbook_part_column.parquet"), inputs = inputs,
                  order_by = "\"schema\", lr, \"table\", \"column\"")

# Summary ----------------------------------------------------------------------------------------------------------------
chk <- pq(fd_curated("check", "logbook_part_station.parquet"))
cat("\nKept stations by outcome, per table and schema:\n")
print(q(sprintf("SELECT \"table\", \"schema\", outcome, sum(stations)::BIGINT stations, sum(\"rows\")::BIGINT \"rows\"
                 FROM %s WHERE \"table\" <> 'effort_count' GROUP BY ALL ORDER BY ALL", chk)))
cat("\neffort_count read from rigging_part against fishing_sample's:\n")
print(q(sprintf("SELECT \"schema\", gear, outcome, sum(stations)::BIGINT stations FROM %s
                 WHERE \"table\" = 'effort_count' GROUP BY ALL ORDER BY ALL", chk)))
stopifnot("a kept station is not in one outcome per table" =
            q(sprintf("SELECT count(DISTINCT n) k FROM (SELECT \"table\", sum(stations) n FROM %s
                       WHERE \"table\" <> 'effort_count' GROUP BY 1)", chk))$k == 1)

dbDisconnect(con, shutdown = TRUE)
