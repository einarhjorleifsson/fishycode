# The user tables, version 0: the vessels, landings, logbooks and AIS in their current best state, as plain tables an
# end user opens without knowing how they were built (maintainer, 2026-10-24). A first cut to be used, so that what it
# lacks is found by using it; the improvements, and how a data product is versioned, are the next round.
#
# Input:  curated/vessel/{vessel,vessel_year}.parquet, curated/landing/{landings,catch}.parquet,
#         curated/logbook/{trip,station,fishing_sample,gear,catch,lid_map,gear_part,rigging_part,sensor_summary,
#         nephrops_tails}.parquet, curated/logbook/sensor_gps/, curated/link/trip_reconciled.parquet,
#         curated/ais/{trail,catch,voyage.parquet}, curated/reference/{species,gear,port}.parquet
# Output: $FISHYDATA/products/v0/
#           vessel/     vessel.parquet, vessel_year.parquet                       (links)
#           landing/    landing.parquet, catch.parquet                            (links)
#           logbook/    trip.parquet, station.parquet, catch.parquet,             (written)
#                       environment.parquet
#                       gear_part.parquet, rigging_part.parquet, sensor_summary.parquet (links)
#                       sensor_gps/                                               (link)
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
#   3j), with `gid_basis`; `gid` and `gid_landing` as each records it; `gear`, `target`, `target2` and `gear_code` (its
#   letter twin, plan 050) those of `gid_used`, the names the AIS trail gives them (decision 219, amended 2026-10-24).
# - Keys as in curated/: vid; a logbook record by (.tid, schema) or (.sid, schema), never the id alone; a landing by
#   (.lid, schema), on the trip (.lid, schema_land). The AIS trail carries .tid, .sid and schema.
# - write_curated_sql() writes under curated/ only, so the written tables are copied here with its stamps
#   (.curated_kv()).

source("R/paths.R")
source("R/write_curated.R")
source("R/whole_weight.R")
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
# The AIS catch is built only when asked, and is not in the store since 2026-10-29 (decision 241). fd_path(), not
# fd_curated(), which would create the directory it names
if (length(list.files(fd_path("curated", "ais", "catch"), recursive = TRUE))) {
  invisible(link_curated("ais/catch", "ais", "catch"))
} else if (nzchar(Sys.readlink(file.path(OUT, "ais", "catch")))) {
  system2("rm", c("-f", shQuote(file.path(OUT, "ais", "catch")))) # a link left from a store that held it
}
invisible(link_curated("ais/voyage.parquet",          "ais", "voyage.parquet"))
# The gear, rigging and per-haul sensor tables (plan 052, decision 244): duplicates are already out
invisible(link_curated("logbook/gear_part.parquet",      "logbook", "gear_part.parquet"))
invisible(link_curated("logbook/rigging_part.parquet",   "logbook", "rigging_part.parquet"))
invisible(link_curated("logbook/sensor_summary.parquet", "logbook", "sensor_summary.parquet"))
# The afli GPS logger, a frozen once fix (decision 075): its own time, speed, heading, depths and temperatures, with
# lon/lat interpolated from the AIS track of 2026-10-09 (w_lon/w_lat the logger's own, faulty). afli only, so it
# carries .sid with no schema. Partitioned by year
invisible(link_curated("logbook/sensor_gps",             "logbook", "sensor_gps"))
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
  select(.sid, schema, gid_used, gid_basis, gid, gid_landing, gear, target, target2, gear_code)
sample <- open_dataset(lb("fishing_sample.parquet")) |>
  select(.sid, schema, t1, t2, t3, t4, t1_placeholder, time_basis, duration_m, duration_m_raw, .duration_source,
         effort_count, effort_count_basis, effort_count_unit, rig, mishap, g_mesh, g_width, g_height, g_length)

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
# Each row's whole weight by the one rule (R/whole_weight.R), at the landings' factor of the day (plan 051 ask a):
# `catch_round`, its `round_basis` and `round_factor`, the factor read, with the logbook's own whole weight beside it
# (`catch_round_logbook`). A correction may name the state (Nephrops logged as tails,
# curate/corrections/logbook_nephrops_tails.yml). A row is one (station, species, condition), so the rule's group is
# the row.
factors <- duckdbfs::open_dataset(fd_curated("reference", "whole_weight_factor.parquet")) |> collect()
tails <- open_dataset(lb("nephrops_tails.parquet")) |>
  filter(!is.na(condition_corrected)) |> select(.sid, schema, sid, condition_corrected)
station_day <- station |> select(.sid, schema, date)
catch_user <- open_dataset(lb("catch.parquet")) |>
  semi_join(station, by = c(".sid", "schema")) |>
  left_join(tails, by = c(".sid", "schema", "sid")) |>
  left_join(station_day, by = c(".sid", "schema")) |>
  # the summaries are named apart from `catch`, calc_whole_weight()'s first argument
  calc_whole_weight(by = c(".sid", "schema", "sid", "condition"), factors = factors,
                    logged = sum(catch, na.rm = TRUE), whole_recorded = sum(catch_whole, na.rm = TRUE)) |>
  select(.sid, schema, sid, catch = logged, catch_whole = whole_recorded, condition, catch_round = whole_weight,
         round_basis = whole_weight_basis, round_factor = whole_weight_factor, catch_round_logbook = whole_weight_logbook)
write_product(catch_user, "logbook/catch.parquet",
              c(lb("catch.parquet"), lb("station.parquet"), lb("nephrops_tails.parquet"),
                fd_curated("reference", "whole_weight_factor.parquet")))

## Environment ------------------------------------------------------------------
# The grammar's wide environment, a pivot of sensor_summary's readings of the sea and the air (plan 052 ask c): one row
# per station with any. A value flagged (implausible, unknown code) or a placeholder is left out; sensor_summary keeps
# it raw. The water depth is the station's (z1, z2), the headline's depth the gear's (sensor_summary, place "gear").
env_col <- c(temp1_bottom = "temperature|bottom|1", temp2_bottom = "temperature|bottom|2",
             temp1_headline = "temperature|headline|1", temp2_headline = "temperature|headline|2",
             temp1_surface = "temperature|surface|1", temp2_surface = "temperature|surface|2",
             temp1_air = "temperature|air|1", wind_direction = "wind_direction|air|1", wind_force = "wind_force|air|1",
             wind_speed = "wind_speed|air|1", sea_state = "sea_state|surface|1", bottom_type = "bottom_type|bottom|1")
env_user <- open_dataset(lb("sensor_summary.parquet")) |>
  filter(is.na(flag), !is.na(value)) |>
  mutate(k = paste(quantity, place, moment, sep = "|")) |>
  filter(k %in% !!unname(env_col)) |>
  group_by(.sid, schema) |>
  summarise(!!!lapply(env_col, \(k) rlang::expr(max(if_else(k == !!k, value, NA_real_), na.rm = TRUE))),
            .groups = "drop")
write_product(env_user, "logbook/environment.parquet", lb("sensor_summary.parquet"))
