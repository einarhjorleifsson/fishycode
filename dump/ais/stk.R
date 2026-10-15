# stk — the STK vessel-monitoring trail, by year of receipt, and its mobile-id tables.
#
# Input:  Oracle stk.trail, stk.mobile, ops$einarhj.mobile_vid
# Output: raw/ais/stk/trail/year=<y>/data_0.parquet
#         raw/ais/stk/mobile.parquet
#         raw/ais/stk/einarhj_mobile-vid.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/ais/stk.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

library(duckdbfs)
library(tidyverse)
library(mar)

for (f in list.files("R", full.names = TRUE)) source(f)

con <- connect_mar(rjdbc = TRUE)

# Pull raw STK trail from Oracle -----------------------------------------------

q <-
  tbl_mar(con, "stk.trail") |>
  # poslon / poslat / heading are stored as radians in Oracle
  mutate(lon = poslon * 180/pi,
         lat = poslat * 180/pi, heading = heading * 180/pi,
         # speed in m/s → knots
         speed = speed * 3600/1852) |>
  select(.id = trailid, mid = mobileid,
         time = posdate, lon, lat, speed, heading, hid = harborid, io = in_out_of_harbor,
         recdate) |>
  mutate(year = year(recdate))

# Write by year ----------------------------------------------------------------

path <- fd_raw("ais", "stk", "trail")

# A year is complete once it holds a record from its last day: every year 2007-2025 has one within the last
# minute of 31 December (measured 2026-10-15). recdate is the receipt time, so a year dumped before it ended
# stops short of that and is fetched again. This replaces editing the first year by hand.
last_recdate <- function(y) {
  files <- Sys.glob(file.path(path, paste0("year=", y), "*.parquet"))
  if (!length(files)) return(as.POSIXct(NA))
  dc <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(dc, shutdown = TRUE))
  DBI::dbGetQuery(dc, sprintf("SELECT max(recdate) AS mx FROM read_parquet(['%s'])",
                              paste(files, collapse = "', '")))$mx
}

for (y in 2007:year(today())) {
  last <- last_recdate(y)
  if (!is.na(last) && as_date(last) >= make_date(y, 12, 31)) next
  message("stk.trail ", y, ": fetching (last record on disk: ", last, ")")
  q |>
    # filter on recdate (DB receipt timestamp), not posdate: recdate is indexed in the Oracle table, and it
    # puts each record in exactly one annual partition
    filter(recdate >= to_date(!!paste0(y, "-01-01"), "YYYY-MM-DD"),
           recdate <  to_date(!!paste0(y + 1, "-01-01"), "YYYY-MM-DD")) |>
    collect() |>
    # cast here, not in the query: with as.integer() in the query, year=2026 (dumped 2026-10-15 through RJDBC)
    # holds .id and mid as text, while 2007-2025 hold both as doubles
    mutate(.id = as.numeric(.id),
           mid = as.numeric(mid),
           year = as.integer(year)) |>
    duckdbfs::write_dataset(path = path,
                            overwrite = TRUE,
                            partitioning = c("year"))
}

# Lookup tables ----------------------------------------------------------------

tbl(con, dbplyr::in_schema("STK", "MOBILE")) |>
  select(mid = MOBILEID, loid = LOCALID, glid = GLOBALID) |>
  collect() |>
  duckdbfs::write_dataset(fd_raw("ais", "stk", "mobile.parquet"))

tbl_mar(con, "ops$einarhj.mobile_vid") |>
  collect() |>
  duckdbfs::write_dataset(fd_raw("ais", "stk", "einarhj_mobile-vid.parquet"))
