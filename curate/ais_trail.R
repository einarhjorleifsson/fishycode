# ais_trail.R — the product: every fix with its voyage, its station and its logbook trip, as parquet.
# Side: flow, steps 2 and 4. See plan 014.
#
# Input:  curated/ais/ping/year=*           (AIS + GPS logger fixes, unique on vid, time; ais_voyage.R)
#         curated/logbook/station_window.parquet
#         curated/logbook/gear.parquet              (the station's gear codes; logbook_gear.R)
#         curated/link/trip_voyage.parquet
# Output: curated/ais/trail/year=Y/month=M/part_001.parquet         one row per fix
#         curated/ais/trail_match/year=Y/month=M/part_001.parquet   one row per (fix, station) match
#
# Plan 011 Phase 5, plan 010 §3. Replaces the `ais_trail()` function, a live join that ran out of memory on a
# year and that an analyst had to call instead of just reading the data: the deliverable is a parquet an
# analyst opens with `duckdbfs::open_dataset()` and works on in dplyr. The partition is year-month so that a new
# month, or a late logbook correction, rewrites that month's files and nothing else (`STAIL_YEARS`, `STAIL_MONTHS`
# restrict a run; a full run rewrites everything).
#
# Columns of `trail` (SQL in R/trail_sql.R; year and month are the partition keys, not columns in the file):
#   the fix       vid mmsi time lon lat speed speed_raw heading cog provider pos_basis speed_basis dt_sec
#   the voyage    stay (key into curated/ais/port_stay.parquet, NA at sea) voyage (key into curated/ais/voyage.parquet,
#                 within vid, year) .tid_voyage schema_voyage n_tid_voyage   the logbook trip of the voyage (only when exactly one)
#   the station   n_sid .sid schema .tid metier gear target target2 gid gid_landing gid_used gid_basis gear_class s1 s2
#                 phase phase_frac win_basis events fishing
#   the logger    sid_gps n_sid_gps
# `pid`, the polygon tag of the ping tables, is not carried: the port of a stay is in the stay table.
# `trail_match` holds all matches for the fixes whose `n_sid` is above 1 (and the single ones), so nothing is lost.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))

pt_dir <- fd_curated("ais", "ping")
years  <- sort(as.integer(sub("year=", "", list.files(pt_dir, pattern = "^year="))))
if (nzchar(Sys.getenv("STAIL_YEARS"))) years <- intersect(years, as.integer(strsplit(Sys.getenv("STAIL_YEARS"), ",")[[1]]))
months <- if (nzchar(Sys.getenv("STAIL_MONTHS"))) as.integer(strsplit(Sys.getenv("STAIL_MONTHS"), ",")[[1]]) else 1:12
ALL <- !nzchar(Sys.getenv("STAIL_YEARS")) && !nzchar(Sys.getenv("STAIL_MONTHS"))

out_trail <- fd_curated("ais", "trail")
out_match <- fd_curated("ais", "trail_match")
if (ALL) { unlink(out_trail, recursive = TRUE); unlink(out_match, recursive = TRUE) }

inputs <- c(fd_curated("logbook", "station_window.parquet"), fd_curated("logbook", "gear.parquet"),
            fd_curated("link", "trip_voyage.parquet"))
tot <- 0
for (yr in years) {
  pf <- list.files(file.path(pt_dir, paste0("year=", yr)), pattern = "parquet$", full.names = TRUE)
  n_year <- 0
  for (mo in months) {
    f1 <- file.path(out_trail, paste0("year=", yr), paste0("month=", mo), "part_001.parquet")
    f2 <- file.path(out_match, paste0("year=", yr), paste0("month=", mo), "part_001.parquet")
    # matches first: the wide row reads them back rather than computing them twice
    write_curated_sql(con, trail_month_sql(con, yr, mo, "match"), f2, inputs = c(pf, inputs), order_by = "vid, time, \".sid\"")
    n <- write_curated_sql(con, trail_month_sql(con, yr, mo, "wide", matches = f2), f1, inputs = c(pf, inputs, f2), order_by = "vid, time")
    if (n == 0) { unlink(dirname(f1), recursive = TRUE); unlink(dirname(f2), recursive = TRUE); next }
    n_year <- n_year + n
  }
  # every fix of the year must be in exactly one month of the product
  n_src <- dbGetQuery(con, sprintf("SELECT count(*) n FROM read_parquet([%s])", paste0("'", pf, "'", collapse = ", ")))$n
  message(sprintf("%d: %s fixes written, %s in ais/ping", yr, format(n_year, big.mark = ","), format(n_src, big.mark = ",")))
  if (identical(months, 1:12) && n_year != n_src) stop("ais_trail: ", yr, " lost or gained fixes")
  tot <- tot + n_year
}
message(sprintf("ais_trail: %s fixes", format(tot, big.mark = ",")))
