# The user tables, version 0: the vessels, landings, logbooks and AIS in their current best state, as plain tables an
# end user opens without knowing how they were built (maintainer, 2026-10-24). A first cut to be used, so that what it
# lacks is found by using it; the improvements, and how a data product is versioned, are the next round.
#
# Input:  curated/vessel/{vessel,vessel_year}.parquet, curated/landing/{landings,catch}.parquet,
#         curated/logbook/{trip,station,fishing_sample,gear,catch,lid_map}.parquet, curated/link/trip_reconciled.parquet,
#         curated/ais/{trail,catch,voyage.parquet}, curated/reference/{species,gear,port}.parquet
# Output: $FISHYDATA/products/v0/
#           vessel/     vessel.parquet, vessel_year.parquet                       (links)
#           landing/    landing.parquet, catch.parquet                            (links)
#           logbook/    trip.parquet, station.parquet, catch.parquet              (written)
#           ais/        trail/, catch/, voyage.parquet                            (links)
#           reference/  species.parquet, gear.parquet, port.parquet               (links)
#
# Run from the repository root:  Rscript products/user_tables.R
#
# - A table taken as it is is a relative symlink into curated/, so v0 follows every rebuild: it is live, not a frozen
#   release, and costs no copy of the 26 GB of AIS tables.
# - Only the logbook tables are written, since no curated table is right for a user as it stands: duplicate twins
#   left out (decision 094); the trip's departure and return, times and ports, the reconciled ones (trip_reconciled,
#   decisions 173, 174), each with its basis and witness (`_from`), `T1_day`/`T2_day` TRUE where it is known to the
#   day only; the trip's landing (lid_map) on the trip; a station's fishing sample joined to it, with the vessel, and
#   its gear as the pipeline uses it: `gid_used`, the logbook's gear corrected by the landing's (gear.parquet, plan 014
#   3j), with `gid_basis`; `gid` and `gid_landing` as each records it; `gear`, `target`, `target2` those of `gid_used`,
#   the names the AIS trail gives them (decision 219, amended 2026-10-24).
# - Keys as in curated/: vid; a logbook record by (.tid, schema) or (.sid, schema), never the id alone; a landing by
#   (.lid, schema), on the trip (.lid, schema_land). The AIS trail carries .tid, .sid and schema.
# - write_curated_sql() writes under curated/ only, so the written tables are copied here with its stamps
#   (.curated_kv()).

source("R/paths.R")
source("R/write_curated.R")
suppressMessages({
  library(dplyr)
  library(duckdbfs)
})
Sys.setenv(TZ = "UTC")

OUT <- fd_path("products", "v0")
con <- duckdbfs::cached_connection()

# Links ------------------------------------------------------------------------
# A relative link, so moving $FISHYDATA keeps it working. An old link is removed with rm, never unlink(recursive = ):
# a link to a directory must not take the directory's contents with it.
link_curated <- function(to, ...) {
  link <- file.path(OUT, to)
  dir.create(dirname(link), recursive = TRUE, showWarnings = FALSE)
  if (nzchar(Sys.readlink(link))) system2("rm", c("-f", shQuote(link)))
  stopifnot(!file.exists(link), file.exists(fd_curated(...)))
  up <- paste(rep("..", lengths(strsplit(to, "/")) + 1L), collapse = "/")
  file.symlink(file.path(up, "curated", ...), link)
}

invisible(link_curated("vessel/vessel.parquet",       "vessel", "vessel.parquet"))
invisible(link_curated("vessel/vessel_year.parquet",  "vessel", "vessel_year.parquet"))
invisible(link_curated("landing/landing.parquet",     "landing", "landings.parquet"))
invisible(link_curated("landing/catch.parquet",       "landing", "catch.parquet"))
invisible(link_curated("ais/trail",                   "ais", "trail"))
invisible(link_curated("ais/catch",                   "ais", "catch"))
invisible(link_curated("ais/voyage.parquet",          "ais", "voyage.parquet"))
invisible(link_curated("reference/species.parquet",   "reference", "species.parquet"))
invisible(link_curated("reference/gear.parquet",      "reference", "gear.parquet"))
invisible(link_curated("reference/port.parquet",      "reference", "port.parquet"))

# Written tables ---------------------------------------------------------------
write_product <- function(d, to, inputs) {
  path <- file.path(OUT, to)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  sql <- dbplyr::sql_render(d)
  ds <- DBI::dbGetQuery(con, sprintf("DESCRIBE %s", sql))
  sh <- substr(digest_string(paste(ds$column_name, ds$column_type, collapse = "|")), 1, 16)
  n <- DBI::dbGetQuery(con, sprintf("SELECT count(*) n FROM (%s)", sql))$n
  kv <- .curated_kv("products/user_tables.R", n, sh, inputs)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"), shQuote(unname(kv), type = "sh")), collapse = ", ")
  unlink(path)
  DBI::dbExecute(con, sprintf("COPY (%s) TO %s (FORMAT parquet, KV_METADATA {%s})", sql,
                              shQuote(path, type = "sh"), meta))
  message(to, ": ", format(n, big.mark = ","), " rows")
  invisible(n)
}

lb <- function(f) fd_curated("logbook", f)
not_duplicate <- function(d) filter(d, is.na(twin) | twin != "duplicate")

## Trip ------------------------------------------------------------------------
trip <- open_dataset(lb("trip.parquet")) |> not_duplicate()
reconciled <- open_dataset(fd_curated("link", "trip_reconciled.parquet"))
landing_of <- open_dataset(lb("lid_map.parquet")) |> select(.tid, schema, .lid, schema_land)

trip_user <- reconciled |>
  select(.tid, schema, vid,
         T1, T1_basis, T1_from, T1_day, pid1, pid1_basis, pid1_from,
         T2, T2_basis, T2_from, T2_day, pid2, pid2_basis, pid2_from) |>
  left_join(trip |> select(.tid, schema, n_crew), by = c(".tid", "schema")) |>
  left_join(landing_of, by = c(".tid", "schema"))
stopifnot(count(trip_user) |> pull(n) == count(trip) |> pull(n))
write_product(trip_user |> arrange(vid, T2), "logbook/trip.parquet",
              c(lb("trip.parquet"), fd_curated("link", "trip_reconciled.parquet"), lb("lid_map.parquet")))

## Station ---------------------------------------------------------------------
station <- open_dataset(lb("station.parquet")) |> not_duplicate()
gear <- open_dataset(lb("gear.parquet")) |>
  select(.sid, schema, gid_used, gid_basis, gid, gid_landing, gear, target, target2)
sample <- open_dataset(lb("fishing_sample.parquet")) |>
  select(.sid, schema, t1, t2, t3, t4, t1_placeholder, time_basis, duration_m,
         effort, effort_unit, effort_count, effort_duration, n_units, g_mesh, g_width, g_height, g_length)

station_user <- station |>
  select(.sid, .tid, schema, date, lon1, lat1, lon2, lat2, lon1_basis, lon2_basis, sq, ssq,
         z1, z2, z1_basis, z2_basis, station_type, station_type_basis, eytt_deleted) |>
  inner_join(trip |> select(.tid, schema, vid), by = c(".tid", "schema")) |>
  left_join(gear, by = c(".sid", "schema")) |>
  left_join(sample, by = c(".sid", "schema")) |>
  relocate(vid, .after = schema)
stopifnot(count(station_user) |> pull(n) == count(station) |> pull(n))
write_product(station_user |> arrange(vid, date, t1), "logbook/station.parquet",
              c(lb("station.parquet"), lb("gear.parquet"), lb("fishing_sample.parquet"), lb("trip.parquet")))

## Catch -----------------------------------------------------------------------
catch_user <- open_dataset(lb("catch.parquet")) |>
  semi_join(station, by = c(".sid", "schema")) |>
  select(.sid, schema, sid, catch, catch_whole, condition)
write_product(catch_user, "logbook/catch.parquet", c(lb("catch.parquet"), lb("station.parquet")))
