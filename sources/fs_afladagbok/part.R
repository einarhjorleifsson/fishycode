# fs_afladagbok's gear and rigging values, by part (plan 052)
# Side: preprocessing (fs_afladagbok). See plan 014.
# Input:  raw/oracle/fs_afladagbok/{ws_veidi,ws_dragnot_varpa,ws_plogur,ws_linanethandf,ws_gildra,ws_hringn,
#           ws_kofun}.parquet; curated/reference/{gear,gear_part_map,gear_part_code}.parquet
# Output: staging/fs_afladagbok/{gear_part,rigging_part,sensor_summary,part_column}.parquet
#
# Written by Claude (AI), 2026-10-29 (decision 244); not checked by a person.
#
# One layer: the e-logbook as the Directorate's dump holds it. It holds no sensor value (its depths are the station's
# z1, z2), so sensor_summary is written empty, with its columns. The tour app (fishing_spot) is not read: its stations
# are not in the merge (plan 019). The tables carry no time and read none (TODO 164).

suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
})

SCHEMA <- "fs_afladagbok"
con <- dbConnect(duckdb::duckdb())
q   <- function(s) dbGetQuery(con, s)
raw <- function(t) sprintf("read_parquet('%s')", fd_raw("oracle", SCHEMA, paste0(t, ".parquet")))

dbWriteTable(con, "gear_new", duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |>
               filter(version == "new") |> select(gid, gear) |> collect())
dbExecute(con, sprintf("CREATE TABLE sg AS SELECT v.id, g.gear FROM %s v LEFT JOIN gear_new g ON g.gid = v.veidarfaeri_id",
                       raw("ws_veidi")))
part_init(con, SCHEMA)
# The gears each table describes: a row of another gear's station is counted, not carried (part_read())
FITS <- list(ws_dragnot_varpa = c("OTB", "OTM", "SDN"), ws_plogur = "DRB", ws_linanethandf = c("LLS", "GNS", "GND", "LHM"),
             ws_gildra = "FPO", ws_hringn = "PS", ws_kofun = "DIV")
for (t in names(FITS)) {
  dbExecute(con, sprintf("CREATE VIEW %1$s AS SELECT t.veidi_id \".sid\", sg.gear, t.* EXCLUDE (veidi_id)
                          FROM %2$s t LEFT JOIN sg ON sg.id = t.veidi_id", t, raw(t)))
  part_read(con, t, SCHEMA, t, paste0(SCHEMA, ".", t), 1L, FITS[[t]])
}
dbExecute(con, sprintf("CREATE VIEW ws_veidi AS SELECT v.id \".sid\", sg.gear, v.* EXCLUDE (id)
                        FROM %s v LEFT JOIN sg USING (id)", raw("ws_veidi")))
part_read(con, "ws_veidi", SCHEMA, "ws_veidi", paste0(SCHEMA, ".ws_veidi"), 1L)
part_settle(con)
part_pick(con)
part_write(con, SCHEMA, "fs_afladagbok")

cat("Every value read, by outcome:\n")
print(q("SELECT coalesce(\"use\", '(gear outside)') AS \"use\", status, count(*) n FROM lp GROUP BY ALL ORDER BY ALL"))
dbDisconnect(con, shutdown = TRUE)
