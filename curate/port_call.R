# port_call.R — port calls: elapsed time in port, from whatever evidence there is (harbour_stay.R until plan 014,
# port_stay.R until decision 148).
# Side: flow, step 1. See plan 014.
#
# Input:  staging/ais/ping_clean            (cleaned pings, every provider; recorded positions only, plan 014)
#         staging/aux/ports.fgb             (standard polygons; source == "einar", Iceland/Faroe)
#         staging/ais/stk_event.parquet     (STK I/U events tagged from STK alone; used from EVENT_FROM on)
#         curated/reference/port_radius.parquet (the departure radius per port; a frozen input)
# Output: curated/ais/port_call.parquet  one row per port call: vid, port_call_id (key, numbered per vessel by T_in), pid,
#         T_in, T_out, ...
#
# Plan 011 §3.0, §3.4, Phase 3. `ais_trip.R` (now ais_voyage.R) measured a harbour stay as the span of the pings in a
# polygon run, so one `I` ping followed by silence has span 0 and is bridged away. A stay here is
# elapsed time. curate/ais_voyage.R cuts voyages at it (Phase 4).
#
# The harbour of a ping is found HERE, against the current polygons, not read from `ping_clean$pid`:
# that tag comes from the previous polygon set and the chain is rebuilt once, after this phase
# (decision 058). `h` = the polygon the ping is inside, else the nearest polygon it lies within r_out of;
# `inside` and `near_in` (within the arrival radius R_M) say how close.
#
# The radius is asymmetric (decision 060). The arrival end of a gap (the last ping before the silence) must
# be within R_M of the harbour; the departure end (the first ping after it) within the harbour's own `r_out_m`
# (curated/reference/port_radius.parquet, a frozen input; 2 km where unmeasured, up to 6 km, Hornafjörður 3.4 km).
#
# Evidence, all providers, all years (the rules need no STK event):
#   tag_then_gap     two consecutive pings at the same harbour at least G hours apart (the first within
#                    R_M, the second within r_out), one of them inside the polygon
#   gap_near_harbour the same, neither inside (a vessel silent in port, never heard at the quay)
#   tag_span         consecutive pings inside one polygon spanning at least G hours
#   event_pair       an STK `I` then `U` at the same standard harbour, G hours or more apart, both
#                    `io_ok` (sources/stk/event.R) and kept by step 0 (their ping is in `ping_clean`, checked
#                    here, plan 014); only from EVENT_FROM (decision 059: events before
#                    2017 are mostly flicker and duplicate flags, so the general rules carry those years)
# A seed is extended over the contiguous pings inside the same polygon on either side. Seeds at one
# harbour that overlap or touch are one stay. `rule` is the strongest evidence present (event_pair >
# tag_then_gap > tag_span > gap_near_harbour); `evidence` lists all of them. Where a stay has both ping
# and event evidence the two time ranges are kept (`*_ping`, `*_ev`) so their agreement can be read.
#
# The minimum stay G is one value for every port, 2 h (decision 074, plan 014): ports carry no class. Decision
# 063 measured a global 2 h against the class rule (+0.8 % stays, the same landing coverage).
#
# A stay's year is the year of T_in. A year's pings are padded with the vessel's last ping of the year
# before and first ping of the year after, so a gap over New Year is seen; a stay that ends in the next
# year's first ping is cut there, not extended (`year_edge`).
#
# Not here: the pass-through guard for event pairs (they must be >= G hours, so a 1-60 min transit never
# qualifies), foreign harbours (no `einar`
# polygon, deferred in plan §3.6), and the vessels with two streams in one mid (2765, ...).

library(dplyr)
library(sf)
sf::sf_use_s2(FALSE)

# -- Parameters ----------------------------------------------------------------

G_H        <- as.numeric(Sys.getenv("STAY_G_H", "2"))   # a stay is at least this many hours, every port (decision 074; test hook)
R_M        <- as.numeric(Sys.getenv("STAY_R_M", "2000"))   # arrival end: this close to the polygon (Phase 0: 96 % of gap ends)
RADIUS_OUT <- Sys.getenv("STAY_RADIUS_OUT", "profile")     # "profile" = per-harbour r_out_m; "same" = R_M for every harbour (test)
EVENT_FROM <- as.integer(Sys.getenv("STAY_EVENT_FROM", "2017"))   # first year whose events are used

con <- duckdbfs::cached_connection()
duckdbfs::load_spatial()
q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) DBI::dbExecute(con, sql)

clean_dir <- file.path(fd_staging("ais", "ping_clean"), "year=*", "**", "*.parquet")
event_f   <- fd_staging("ais", "stk_event.parquet")
YEARS     <- as.integer(strsplit(Sys.getenv("STAY_YEARS", ""), ",")[[1]])
ALL       <- !length(YEARS)

# -- Port polygons with their departure radius ---------------------------------------------------
# The rules themselves are ramb::rb_create_port_calls(method = "dwell") (plan 013, phase 2; a stay was renamed a port
# call by decision 147, and the table and its key by decision 148); this script supplies the Icelandic inputs and keeps
# the year-by-year processing.

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |> select(pid) |> sf::st_make_valid()
rad <- nanoparquet::read_parquet(fd_path("curated", "reference", "port_radius.parquet")) |> as_tibble()
# The radius is a frozen input (decision 075) and the polygons are not: a renamed port re-mints its pid (TODO 36)
# and would silently fall back to the default radius.
stopifnot("a frozen port radius names a pid with no polygon (TODO 36)" = all(rad$pid %in% P$pid))
r_out <- if (RADIUS_OUT == "profile") rad$r_out_m[match(P$pid, rad$pid)] else rep(R_M, nrow(P))
ports <- P |> mutate(port_id = pid, radius_out = pmax(coalesce(r_out, R_M), R_M))


# -- One year ------------------------------------------------------------------------

stay_year <- function(yr) {
  # pings of the year plus the neighbouring years' boundary pings
  seq_yr <- dplyr::tbl(con, dplyr::sql(glue::glue("
    WITH c AS (SELECT vid, time, lon, lat, year FROM read_parquet('{clean_dir}', hive_partitioning = true)
               WHERE year BETWEEN {yr - 1L} AND {yr + 1L} AND pos_basis = 'recorded')
    SELECT vid, time, lon, lat FROM c WHERE year = {yr}
    UNION ALL SELECT vid, time, lon, lat FROM c WHERE year = {yr - 1L}
              QUALIFY row_number() OVER (PARTITION BY vid ORDER BY time DESC) = 1
    UNION ALL SELECT vid, time, lon, lat FROM c WHERE year = {yr + 1L}
              QUALIFY row_number() OVER (PARTITION BY vid ORDER BY time) = 1")))
  # STK event pairs: I then U, adjacent in the vessel's events, same standard harbour, both ok and kept by step 0
  ev <- if (yr >= EVENT_FROM) dplyr::tbl(con, dplyr::sql(glue::glue("
    SELECT e.vid, e.time, e.io, e.hid_pid AS port_id, (e.io_ok AND c.vid IS NOT NULL) AS good
    FROM read_parquet('{event_f}') e
    LEFT JOIN (SELECT DISTINCT vid, time FROM read_parquet('{clean_dir}', hive_partitioning = true)
               WHERE year BETWEEN {yr - 1L} AND {yr + 1L}) c USING (vid, time)
    WHERE e.year BETWEEN {yr - 1L} AND {yr + 1L}"))) else NULL
  win <- as.POSIXct(c(sprintf("%d-01-01", yr), sprintf("%d-01-01", yr + 1L)), tz = "UTC")
  ramb::rb_create_port_calls(seq_yr, ports, min_dwell_h = G_H, radius_in = R_M,
                           events = ev, t_in_window = win) |>
    collect() |>
    rename(pid = port_id)
}

# -- Run -----------------------------------------------------------------------------

years <- if (ALL) q(glue::glue("SELECT DISTINCT year FROM read_parquet('{clean_dir}', hive_partitioning = true) ORDER BY 1"))$year else YEARS
res <- vector("list", length(years))
for (k in seq_along(years)) {
  yr <- years[k]; t0 <- Sys.time(); message("port_call ", yr)
  res[[k]] <- stay_year(yr)
  message(sprintf("  %s port calls, %.1f min", format(nrow(res[[k]]), big.mark = ","),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

out <- bind_rows(res) |>
  arrange(vid, T_in, pid) |>
  # the port call's key: a ping carries it, not the call's values (plan 014). Numbered here per vessel over all years,
  # so a call over New Year keeps one number; ramb's port_call_id is numbered within each year's window and is replaced
  mutate(port_call_id = row_number(), .by = vid) |>
  transmute(vid, port_call_id, pid, year = as.integer(format(T_in, "%Y")), T_in, T_out,
            dur_h = as.numeric(T_out - T_in, units = "hours"),
            rule, evidence, T_in_ping, T_out_ping, T_in_ev, T_out_ev,
            basis = "reconstructed") |>
  arrange(vid, T_in)
stopifnot(!anyDuplicated(out[c("vid", "pid", "T_in")]))

print(out |> count(year, rule) |> tidyr::pivot_wider(names_from = rule, values_from = n), n = Inf)

if (ALL) {
  out |> write_curated(
    fd_curated("ais", "port_call.parquet"),
    inputs = c(fd_staging("aux", "ports.fgb"), event_f,
               list.files(fd_staging("ais", "ping_clean"), pattern = "parquet$", recursive = TRUE, full.names = TRUE)))
  message(sprintf("port_call: %s port calls", format(nrow(out), big.mark = ",")))
} else {
  assign("stay_test", out, envir = globalenv())
  message("subset run (STAY_YEARS): nothing written")
}
