# ais_catch.R — the catch on the fixes: each catch unit's catch shared over its fishing fixes, by effort.
# Side: flow, step 6. See plan 013 item 2.
#
# Input:  curated/ais/trail/year=*                  (vid, time, fishing, fishing_flow, hours; ais_trail.R)
#         curated/logbook/station_window.parquet    (the stations' windows)
#         curated/logbook/station.parquet           (twin)
#         curated/logbook/trip.parquet              (.tid, vid, T1, T2, twin)
#         curated/logbook/catch.parquet             (.sid, schema, sid = species, catch kg)
#         curated/logbook/lid_map.parquet           (the landings that have a logbook trip)
#         curated/landing/landings.parquet          (.lid, schema, vid, date)
#         curated/landing/catch.parquet             (.lid, schema, sid = species, catch kg)
#         curated/ais/voyage.parquet                (vid, year, voyage, T1, T2, pid2: the landings' voyages)
# Output: curated/ais/catch/year=Y/part_001.parquet
#         one row per (fishing fix, unit, species, approach): vid, time, unit_id, resolution, shared_unit_id,
#         shared_resolution, species, kg, catch_basis, approach, source, raise_factor
#
# The units (ramb::rb_build_catch_units(), decision 100), by level:
#   1  a station with a timed window (tow, haul, set, jig): its windows; overlapping ones would merge
#   2  a station with only a day window: the stations of one vessel-day are one unit
#   3  a logbook trip, T1 to the day after T2: it carries no catch of its own, only catch moved up to it
#   4  a landing with no logbook trip, linked to the voyages it ended (ramb::rb_link_trip_landings(): same day
#      and port first, then looser, then the vessel's next landing within 14 days; plan 013 item 5): those voyages,
#      resolution `landing_trip`. A landing it cannot link: from the vessel's previous landing to the day after it,
#      resolution `landing`. Every landing is an event, so such a period
#      never reaches past the vessel's last landing into another trip; only a landing with no logbook trip (most of
#      them foreign vessels, plan 013) carries catch. Without the others, a logbook trip with no fishing fix had its
#      catch moved into the period of an unrelated landing (11 kt in a 2023 dry run).
# One source per trip: a trip with a logbook takes the logbook's catch, and its landing is not an event. Both
# catch columns are kilograms (measured 2026-10-14: per trip the logbook's `catch` is 0.95-0.99 of the landed weight
# in every system; `catch_whole` is mostly empty). Duplicate twins are left out (decision 094).
#
# Raising is a column, not a choice (maintainer, plan 013 item 2): `raise_factor` is the trip's landed weight of the
# species over its logged weight (lid_map's landings), on the logbook's rows, NA where there is none; the raised
# value is kg × raise_factor. A unit's trip is that of its first station.
#
# Each approach to fishing in the trail is shared on its own (`approach`): `fishing` (the window alone) and
# `fishing_flow` (the window, else the voyage gear's speed). Under `fishing` a landing with no logbook trip has no
# fishing fix, so its catch goes to the vessel's month or is kept with basis none: the approaches differ there.
#
# A trip's twin filter is written `is.na(twin) | twin != "duplicate"`: dbplyr turns `!(twin %in% "duplicate")` into
# NOT (twin IN (...)), which is NULL for the trips with no twin value, and dropped them (found 2026-10-14: the first
# build of this table had most logbook trips missing as units, so catch moved to the vessel's month, decision 102).
#
# A year at a time: the units and the fixes of that year. A unit that crosses New Year is shared over its fixes of
# the year it starts in (its catch is kept whole). unit_id is unique within a year's file only. The kilograms
# written equal the kilograms in, per year and approach; the script stops if not.

library(dplyr)
con <- duckdbfs::cached_connection()
DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(tempdir(), "duckdb_spill")))
# a cap below the machine's 24 GB: the default (80 %) ran out of memory in 2015 on the first try (decision 102)
DBI::dbExecute(con, "SET memory_limit = '12GB'")
od <- function(...) duckdbfs::open_dataset(fd_curated(...))

years <- sort(as.integer(sub("year=", "", list.files(fd_curated("ais", "trail"), pattern = "^year="))))
if (nzchar(Sys.getenv("SCATCH_YEARS"))) years <- intersect(years, as.integer(strsplit(Sys.getenv("SCATCH_YEARS"), ",")[[1]]))
out_dir <- fd_curated("ais", "catch")
if (!nzchar(Sys.getenv("SCATCH_YEARS"))) unlink(out_dir, recursive = TRUE)

dup_s <- od("logbook", "station.parquet") |> filter(twin %in% "duplicate") |> select(.sid, schema)
lm <- od("logbook", "lid_map.parquet") |> distinct(.lid, schema = schema_land)
inputs <- c(fd_curated("logbook", "station_window.parquet"), fd_curated("logbook", "station.parquet"),
            fd_curated("ais", "voyage.parquet"),
            fd_curated("logbook", "trip.parquet"), fd_curated("logbook", "catch.parquet"),
            fd_curated("logbook", "lid_map.parquet"), fd_curated("landing", "landings.parquet"),
            fd_curated("landing", "catch.parquet"))

for (yr in years) {
  y0 <- as.POSIXct(sprintf("%d-01-01", yr), tz = "UTC")
  y1 <- as.POSIXct(sprintf("%d-01-01", yr + 1L), tz = "UTC")
  d0 <- as.Date(y0); d1 <- as.Date(y1)
  win <- od("logbook", "station_window.parquet") |>
    filter(w_start >= !!y0, w_start < !!y1) |>
    anti_join(dup_s, by = c(".sid", "schema")) |>
    mutate(timed = win_basis %in% c("recorded", "derived", "capped")) |>
    group_by(.sid, schema) |> mutate(timed = any(timed)) |> ungroup()
  ev_s <- win |> transmute(id = paste0("S|", schema, "|", as.character(.sid)), vid, start = w_start, end = w_end,
                           level = if_else(timed, 1L, 2L), resolution = phase)
  ev_t <- od("logbook", "trip.parquet") |>
    filter(T1 < !!y1, T2 >= !!y0, (is.na(twin) | twin != "duplicate")) |>
    transmute(id = paste0("T|", schema, "|", .tid), vid, start = T1, end = T2 + dbplyr::sql("INTERVAL 1 DAY"),
              level = 3L, resolution = "trip")
  # every landing is an event; December of the year before only gives the first landing its start
  ld_all <- od("landing", "landings.parquet") |> filter(date >= !!(d0 - 31), date < !!d1)
  ld <- ld_all |> anti_join(lm, by = c(".lid", "schema")) # the ones whose catch is shared
  # the landings with no logbook trip, linked to the voyages they ended
  vy <- od("ais", "voyage.parquet") |>
    filter(T2 >= !!(y0 - 31 * 86400), T1 < !!y1) |>
    transmute(vkey = paste(as.character(vid), as.character(year), as.character(voyage)), vid, T1, T2, pid2)
  lk <- ramb::rb_link_trip_landings(vy, ld |> select(.lid, schema, vid, date, pid), trip_key = "vkey",
                                    landing_key = c(".lid", "schema"), port_trip = "pid2", port_landing = "pid",
                                    since_previous_days = 14)
  lkv <- dplyr::copy_to(con, as.data.frame(lk[, c("vkey", ".lid", "schema")]), overwrite = TRUE,
                        name = paste0("lk_", yr))
  ev_lv <- vy |> inner_join(lkv, by = "vkey") |>
    transmute(id = paste0("L|", schema, "|", as.character(.lid)), vid, start = T1, end = T2, level = 4L,
              resolution = "landing_trip")
  ev_l <- ld_all |> anti_join(lkv, by = c(".lid", "schema")) |> transmute(id = paste0("L|", schema, "|", as.character(.lid)), vid,
                          start = dbplyr::sql("CAST(NULL AS TIMESTAMP)"),
                          end = dbplyr::sql("CAST(date AS TIMESTAMP) + INTERVAL 1 DAY"),
                          level = 4L, resolution = "landing")
  events <- union_all(ev_s, ev_t) |> union_all(ev_l) |> union_all(ev_lv)
  units <- ramb::rb_build_catch_units(events, key = "id") |> dplyr::compute()
  # an event in two units would count its catch twice (decision 102)
  twice <- units |> distinct(id, unit_id) |> count(id) |> filter(n > 1) |> count() |> pull(n)
  if (twice > 0) stop("ais_catch: ", yr, ": ", twice, " events fall in more than one unit")
  catch <- union_all(
    od("logbook", "catch.parquet") |>
      semi_join(win, by = c(".sid", "schema")) |>
      transmute(id = paste0("S|", schema, "|", as.character(.sid)), species = sid, kg = as.numeric(catch)),
    od("landing", "catch.parquet") |>
      semi_join(ld |> filter(date >= !!d0), by = c(".lid", "schema")) |>
      transmute(id = paste0("L|", schema, "|", as.character(.lid)), species = sid, kg = as.numeric(catch))
  ) |> filter(!is.na(kg)) |> dplyr::compute()
  kg_in <- catch |> summarise(kg = sum(kg)) |> pull(kg)
  pings <- duckdbfs::open_dataset(file.path(fd_curated("ais", "trail"), paste0("year=", yr))) |>
    select(vid, time, fishing, fishing_flow, hours)
  shared <- lapply(c("fishing", "fishing_flow"), function(a)
    ramb::rb_share_catch(pings, units, catch, key = "id", fishing = a))
  # the raising factor, per trip and species, onto the units of the logbook
  st <- od("logbook", "station.parquet") |> anti_join(dup_s, by = c(".sid", "schema")) |> select(.sid, schema, .tid)
  ut <- units |> filter(substr(id, 1, 2) == "S|") |>
    mutate(schema = dbplyr::sql("split_part(id, '|', 2)"),
           .sid = dbplyr::sql("CAST(split_part(id, '|', 3) AS DOUBLE)")) |>
    inner_join(st, by = c(".sid", "schema")) |>
    group_by(unit_id) |> summarise(.tid = min(.tid), schema = min(schema), .groups = "drop")
  logged <- od("logbook", "catch.parquet") |> inner_join(st, by = c(".sid", "schema")) |>
    group_by(.tid, schema, species = sid) |> summarise(kg_lb = sum(catch, na.rm = TRUE), .groups = "drop")
  landed <- od("logbook", "lid_map.parquet") |> select(.tid, schema, .lid, schema_land) |>
    inner_join(od("landing", "catch.parquet") |> select(.lid, schema_land = schema, species = sid, catch),
               by = c(".lid", "schema_land")) |>
    group_by(.tid, schema, species) |> summarise(kg_ld = sum(catch, na.rm = TRUE), .groups = "drop")
  rf <- ut |> inner_join(logged, by = c(".tid", "schema")) |>
    inner_join(landed, by = c(".tid", "schema", "species")) |>
    filter(kg_lb > 0) |> transmute(unit_id, species, raise_factor = kg_ld / kg_lb)
  res <- union_all(shared[[1]], shared[[2]]) |>
    mutate(source = if_else(substr(resolution, 1, 7) == "landing", "landing", "logbook")) |>
    left_join(rf, by = c("unit_id", "species"))
  sql <- as.character(dbplyr::sql_render(res))
  f <- file.path(out_dir, paste0("year=", yr), "part_001.parquet")
  part <- list.files(file.path(fd_curated("ais", "trail"), paste0("year=", yr)), "parquet$", recursive = TRUE,
                     full.names = TRUE)
  n <- write_curated_sql(con, sql, f, inputs = c(inputs, part), order_by = "vid, time, approach")
  kg_out <- DBI::dbGetQuery(con, sprintf("SELECT approach, sum(kg) AS kg FROM read_parquet('%s') GROUP BY approach", f))
  message(sprintf("%d: %s rows; kg in %.0f, out %s", yr, format(n, big.mark = ","), kg_in,
                  paste(sprintf("%s %.0f", kg_out$approach, kg_out$kg), collapse = ", ")))
  if (any(abs(kg_out$kg - kg_in) > 1e-6 * max(1, kg_in))) stop("ais_catch: ", yr, " kilograms out differ from kilograms in")
  # the year's temporary tables (computed units and catch, the landing links, ramb's islands) would pile up
  for (t in DBI::dbGetQuery(con, "SELECT table_name FROM duckdb_tables() WHERE temporary")$table_name)
    DBI::dbExecute(con, sprintf('DROP TABLE IF EXISTS "%s"', t))
}
