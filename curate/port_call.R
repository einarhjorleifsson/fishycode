# port_call.R — port calls: elapsed time in port, from whatever evidence there is (harbour_stay.R until plan 014,
# port_stay.R until decision 149).
# Side: flow, step 1. See plan 014.
#
# Input:  staging/ais/ping_clean            (cleaned pings, every provider; recorded positions only, plan 014)
#         staging/aux/ports.fgb             (standard polygons; source == "einar", Iceland/Faroe)
#         staging/ais/stk_event.parquet     (STK's I/U events, its adapter's: port, position, marker, unit)
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
#   event_pair       an STK `I` then `U` at the same standard harbour, G hours or more apart, both good:
#                    judged as events by ramb::rb_flag_port_event() (plan 048 §2.3, decision 289), by position,
#                    sequence, the cleaned track (no ping either side, no witness, not good) and the sending unit.
#                    Until plan 048 an event was good if `io_ok` (sources/stk/event.R) and kept by step 0 as a ping,
#                    and only events from 2017 on were passed (decision 059); the pairs kept that cut until plan 048
#                    step 6, which lifted it with ramb's pair guard (STAY_PAIR_AWAY_M): a pair makes no call where
#                    a ping between its events, not at its port, lies more than 10 km from it, since the track
#                    shows the vessel left (2007-2016: 65-81 % of the pairs the logbook contradicts, 0.1-10 % of
#                    those a landing confirms; $FISHYDATA/archive/2026-11-07-plan048-step6/). Only the good events go
#                    to the pairs (STAY_EVENTS "good", the default since decision 290): passing every event ("all", as
#                    before plan 048), a bad one between two good ones breaks the pair, and on the scratch run of
#                    plan 048 step 3 12,868 more of today's port calls were lost
#   presence         every good event of every year, at its recorded position (a marker included), is a ping for
#                    the rules above (ramb::rb_create_port_calls(presence = TRUE), plan 048 §7.3): until plan 048
#                    STK's event rows were pings of the track and the port calls stood on them; out of the track,
#                    they stand on them again as judged events
# A seed is extended over the contiguous pings inside the same polygon on either side. Seeds at one
# harbour that overlap or touch are one stay. `rule` is the strongest evidence present (event_pair >
# tag_then_gap > tag_span > gap_near_harbour); `evidence` lists all of them. Where a stay has both ping
# and event evidence the two time ranges are kept (`*_ping`, `*_ev`) so their agreement can be read.
#
# The minimum stay G is one value for every port, 2 h (decision 074, plan 014): ports carry no class. Decision
# 063 measured a global 2 h against the class rule (+0.8 % stays, the same landing coverage).
#
# A port call's year is the year of T_in. The calls are made a year at a time (the whole series at once is the
# memory risk of decision 239). A year's pings are padded with each vessel's last ping before the year and first ping
# after it, from whichever years hold them, and each year keeps the calls that overlap it, so a call over New Year comes
# back from both years, each piece as far as that year's pings reach; ramb::rb_merge_port_calls() joins them (TODO 179).
# Until then the window kept only the calls begun in the year: the January part of a call begun in December was
# dropped, and its pings became voyage 1 (22.9 M pings of 2008-2026, $FISHYDATA/archive/2026-11-01-voyage-year-boundary/);
# and the padding came from the neighbouring years only, so a vessel silent for a whole year lost the call its pings
# either side make (297 calls against a run on the whole series, $FISHYDATA/archive/2026-11-01-port-call-new-year-fix/).
# What a run by year still misses against the whole series: a piece too short to be a call in its own year (under G,
# a call short by under G at New Year), and an STK pair whose events lie more than a year apart.
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
EVENTS     <- Sys.getenv("STAY_EVENTS", "good")   # "good" or "all": which judged events go to the pairs (above)
EVENT_FROM <- as.integer(Sys.getenv("STAY_EVENT_FROM", "0"))   # the first year whose events make pairs (above; 2017 until plan 048 step 6)
PAIR_AWAY_M <- as.numeric(Sys.getenv("STAY_PAIR_AWAY_M", "10000"))   # ramb's pair guard, metres (above; a test hook)
stopifnot("STAY_EVENTS is \"all\" or \"good\"" = EVENTS %in% c("all", "good"))
stopifnot("ramb 2026.11.07 or later: the event pairs' guard (plan 048 step 6)" = packageVersion("ramb") >= "2026.11.7")

con <- duckdbfs::cached_connection()
duckdbfs::load_spatial()
q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) DBI::dbExecute(con, sql)

clean_dir <- file.path(fd_staging("ais", "ping_clean"), "year=*", "**", "*.parquet")
# the years' own folders, never a filter on the year: DuckDB 2.0 estimates such a filter at about 1 row, and the joins
# below could then be built on the pings (decision 235, plan 049); a year with no folder is left out
clean_years <- function(ys) {
  ys <- ys[dir.exists(file.path(fd_staging("ais", "ping_clean"), paste0("year=", ys)))]
  if (!length(ys)) return(NULL)
  sprintf("read_parquet([%s])", paste0("'", file.path(fd_staging("ais", "ping_clean"), paste0("year=", ys), "**", "*.parquet"),
                                        "'", collapse = ", "))
}
event_f   <- fd_staging("ais", "stk_event.parquet")
YEARS     <- as.integer(strsplit(Sys.getenv("STAY_YEARS", ""), ",")[[1]])
ALL       <- !length(YEARS)

# -- Port polygons with their departure radius ---------------------------------------------------
# The rules themselves are ramb::rb_create_port_calls(method = "dwell") (plan 013, phase 2; a stay was renamed a port
# call by decision 147, and the table and its key by decision 149); this script supplies the Icelandic inputs and keeps
# the year-by-year processing.

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |> select(pid) |> sf::st_make_valid()
rad <- nanoparquet::read_parquet(fd_path("curated", "reference", "port_radius.parquet")) |> as_tibble()
# The radius is a frozen input (decision 075) and the polygons are not: a renamed port re-mints its pid (TODO 36)
# and would silently fall back to the default radius.
stopifnot("a frozen port radius names a pid with no polygon (TODO 36)" = all(rad$pid %in% P$pid))
r_out <- if (RADIUS_OUT == "profile") rad$r_out_m[match(P$pid, rad$pid)] else rep(R_M, nrow(P))
ports <- P |> mutate(port_id = pid, radius_out = pmax(coalesce(r_out, R_M), R_M))


# -- STK's events judged as events (plan 048 §2.3) ---------------------------------------
# Year by year: the events of Y-1 to Y+1 and each vessel's last event before them (so the sequence test sees every
# event's previous one, however far back), against the cleaned recorded pings of Y-1 to Y+1 (the track test); the
# events of Y kept. A marker's position is not the vessel's and goes in as NA; the unit is the STK mobile id.

x(glue::glue("CREATE OR REPLACE TEMP TABLE ev_in AS
  SELECT vid, time, io, CAST(year AS INTEGER) AS year, hid_pid AS port_id,
         CASE WHEN marker THEN NULL ELSE lon END AS lon, CASE WHEN marker THEN NULL ELSE lat END AS lat,
         CAST(mid AS VARCHAR) AS mid, lon AS raw_lon, lat AS raw_lat
  FROM read_parquet('{event_f}')"))
ports_ev <- P |> transmute(port_id = pid)
ev_years <- q("SELECT DISTINCT year FROM ev_in ORDER BY 1")$year
judged <- vector("list", length(ev_years))
for (k in seq_along(ev_years)) {
  y <- ev_years[k]; t0 <- Sys.time()
  e <- q(glue::glue("
    SELECT * FROM ev_in WHERE year BETWEEN {y - 1L} AND {y + 1L}
    UNION ALL
    SELECT * FROM (SELECT * FROM ev_in WHERE year < {y - 1L}
                   QUALIFY row_number() OVER (PARTITION BY vid ORDER BY time DESC, io DESC) = 1)")) |>
    as_tibble()
  attr(e$time, "tzone") <- "UTC"
  # a year with no track (an event's bad time, a year before the AIS) gets no pings, so its events have no witness
  pg <- dplyr::tbl(con, dplyr::sql(if (is.null(clean_years(y + -1:1)))
    "SELECT NULL::INTEGER AS vid, NULL::TIMESTAMP AS time, NULL::DOUBLE AS lon, NULL::DOUBLE AS lat WHERE false" else
    glue::glue("SELECT vid, time, lon, lat FROM {clean_years(y + -1:1)} WHERE pos_basis = 'recorded'")))
  r <- ramb::rb_flag_port_event(e, ports = ports_ev, pings = pg, unit = mid)
  judged[[k]] <- r[r$year == y, c("vid", "time", "io", "year", "port_id", "mid", "event_flag", "event_track_kn", "good",
                                  "raw_lon", "raw_lat")]
  message(sprintf("  events %d: %s judged, %s good, %s not judged, %.1f min", y, format(nrow(judged[[k]]), big.mark = ","),
                  format(sum(judged[[k]]$good, na.rm = TRUE), big.mark = ","), format(sum(is.na(judged[[k]]$good)), big.mark = ","),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
judged <- bind_rows(judged)
stopifnot("every event judged once" = nrow(judged) == q("SELECT count(*) AS n FROM ev_in")$n)
duckdb::duckdb_register(con, "ev_judged", as.data.frame(judged))
# for a reader that sources this script (a scratch run's account), the events as judged
assign("port_event_judged", judged, envir = globalenv())

# -- Each vessel's first and last ping of every year ---------------------------------------
# Once, as aggregates (no window over the pings): the padding of a year is taken from here. Ties in time go by lon, lat.

x(glue::glue("CREATE OR REPLACE TEMP TABLE pc_edge AS
  SELECT vid, year::INTEGER AS year, min(struct_pack(t := time, lon := lon, lat := lat)) AS first,
         max(struct_pack(t := time, lon := lon, lat := lat)) AS last
  FROM read_parquet('{clean_dir}', hive_partitioning = true) WHERE pos_basis = 'recorded' GROUP BY ALL"))

# -- One year ------------------------------------------------------------------------

stay_year <- function(yr) {
  # pings of the year, plus each vessel's last ping before it and first ping after it, from whichever years hold them
  own <- if (is.null(clean_years(yr))) NULL else
    glue::glue("SELECT vid, time, lon, lat FROM {clean_years(yr)} WHERE pos_basis = 'recorded'")
  pad <- glue::glue("
    SELECT vid, e.t AS time, e.lon, e.lat FROM (SELECT vid, arg_max(last, year) AS e FROM pc_edge WHERE year < {yr} GROUP BY vid)
    UNION ALL
    SELECT vid, e.t AS time, e.lon, e.lat FROM (SELECT vid, arg_min(first, year) AS e FROM pc_edge WHERE year > {yr} GROUP BY vid)")
  seq_yr <- dplyr::tbl(con, dplyr::sql(paste(c(own, pad), collapse = "\n    UNION ALL ")))
  # STK event pairs: I then U, adjacent in the vessel's events, same standard harbour, both good (judged above), from
  # EVENT_FROM on (an earlier event's port is withheld, so it makes no pair); the events of the year and either side,
  # since the window keeps a call that overlaps the year. Presence: every good event of the year itself, at its
  # recorded position. Only the year's own: its pings are the year's, and an event of the year either side with no
  # pings around it made consecutive events at a home port one stay over whole seasons (plan 048 step 3c's first run,
  # 22,005 calls of a median 6 months).
  ev <- dplyr::tbl(con, dplyr::sql(glue::glue("
    SELECT vid, time, io, CASE WHEN year >= {EVENT_FROM} THEN port_id END AS port_id, good,
           CASE WHEN year = {yr} THEN raw_lon END AS lon, CASE WHEN year = {yr} THEN raw_lat END AS lat
    FROM ev_judged
    WHERE year BETWEEN {yr - 1L} AND {yr + 1L}{if (EVENTS == 'good') ' AND good' else ''}")))
  win <- as.POSIXct(c(sprintf("%d-01-01", yr), sprintf("%d-01-01", yr + 1L)), tz = "UTC")
  ramb::rb_create_port_calls(seq_yr, ports, min_dwell_h = G_H, radius_in = R_M,
                           events = ev, presence = TRUE, pair_away_m = PAIR_AWAY_M, window = win) |>
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

# The pieces of a call over New Year joined, and the key a ping carries (plan 014) numbered per vessel over all years
# by T_in, so a call over New Year has one number
out <- bind_rows(res) |>
  ramb::rb_merge_port_calls(port_id = pid) |>
  transmute(vid, port_call_id = as.integer(port_call_id), pid, year = as.integer(format(T_in, "%Y")), T_in, T_out,
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
