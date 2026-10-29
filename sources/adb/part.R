# adb's gear and rigging values, by part (plan 052)
# Side: preprocessing (adb). See plan 014.
# Input:  raw/oracle/adb/{fishing_station,fishing_gear,trawl_and_seine_net,dredge,line_and_net,trap,surrounding_net,
#           diving}.parquet; curated/reference/{gear,gear_part_map,gear_part_code}.parquet
# Output: staging/adb/{gear_part,rigging_part,sensor_summary,part_column}.parquet
#
# Written by Claude (AI), 2026-10-29 (decision 244); not checked by a person.
#
# adb copies fs_afladagbok's gear tables field for field (decision 171), and the merge reads it only from 2025-11-19
# (decision 160). Every station is staged; curate/logbook_part.R keeps the merge's. No sensor value: sensor_summary is
# written empty. The tables carry no time and read none (TODO 164).

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
})

SCHEMA <- "adb"
con <- dbConnect(duckdb::duckdb())
q   <- function(s) dbGetQuery(con, s)
raw <- function(t) sprintf("read_parquet('%s')", fd_raw("oracle", SCHEMA, paste0(t, ".parquet")))

# The station's gear as sources/adb/convert.R reads it: adb's own code, through its crosswalk, to the new gid
dbWriteTable(con, "gear_new", duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |>
               filter(version == "new") |> select(gid, gear) |> collect())
dbExecute(con, sprintf("CREATE TABLE sg AS
  WITH c AS (SELECT DISTINCT fishing_gear_no::INTEGER gid_old, id::INTEGER gid FROM %s)
  SELECT s.fishing_station_id id, g.gear FROM %s s LEFT JOIN c ON c.gid_old = s.fishing_gear_no
  LEFT JOIN gear_new g ON g.gid = c.gid", raw("fishing_gear"), raw("fishing_station")))
stopifnot("a station twice in sg" = q("SELECT count(*) - count(DISTINCT id) d FROM sg")$d == 0)
part_init(con, SCHEMA)
# The gears each table describes: a row of another gear's station is counted, not carried (part_read())
FITS <- list(trawl_and_seine_net = c("OTB", "OTM", "SDN"), dredge = "DRB", line_and_net = c("LLS", "GNS", "GND", "LHM"),
             trap = "FPO", surrounding_net = "PS", diving = "DIV")
for (t in names(FITS)) {
  dbExecute(con, sprintf("CREATE VIEW %1$s AS SELECT t.fishing_station_id \".sid\", sg.gear,
                          t.* EXCLUDE (fishing_station_id) FROM %2$s t LEFT JOIN sg ON sg.id = t.fishing_station_id",
                         t, raw(t)))
  part_read(con, t, SCHEMA, t, paste0(SCHEMA, ".", t), 1L, FITS[[t]])
}
dbExecute(con, sprintf("CREATE VIEW fishing_station AS SELECT s.fishing_station_id \".sid\", sg.gear,
                        s.* EXCLUDE (fishing_station_id) FROM %s s LEFT JOIN sg ON sg.id = s.fishing_station_id",
                       raw("fishing_station")))
part_read(con, "fishing_station", SCHEMA, "fishing_station", paste0(SCHEMA, ".fishing_station"), 1L)
part_settle(con)
part_pick(con)
part_write(con, SCHEMA, "adb")

cat("Every value read, by outcome:\n")
print(q("SELECT coalesce(\"use\", '(gear outside)') AS \"use\", status, count(*) n FROM lp GROUP BY ALL ORDER BY ALL"))
dbDisconnect(con, shutdown = TRUE)
