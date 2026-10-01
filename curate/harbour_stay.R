# harbour_stay.R — stays: elapsed time at a harbour, from whatever evidence there is.
#
# Input:  staging/ais/ping_clean            (cleaned pings, every provider)
#         staging/aux/ports.fgb             (standard polygons; source == "einar", Iceland/Faroe)
#         curated/check/stk_event.parquet   (tagged STK I/U events; used from EVENT_FROM on)
# Output: curated/ais/harbour_stay.parquet  one row per stay: vid, pid, T_in, T_out, ...
#
# Plan 011 §3.0, §3.4, Phase 3. `ais_trip.R` measures a harbour stay as the span of the pings in a
# polygon run, so one `I` ping followed by silence has span 0 and is bridged away. A stay here is
# elapsed time. Nothing consumes this table yet; Phase 4 cuts voyages at it.
#
# The harbour of a ping is found HERE, against the current polygons, not read from `ping_clean$pid`:
# that tag comes from the previous polygon set and the chain is rebuilt once, after this phase
# (decision 058). `h` = the polygon the ping is inside, else the polygon it lies within R_M metres of;
# `inside` says which.
#
# Evidence, all providers, all years (the rules need no STK event):
#   tag_then_gap     two consecutive pings at the same harbour at least G hours apart, one of them
#                    inside the polygon
#   gap_near_harbour the same, neither inside (a vessel silent in port, never heard at the quay)
#   tag_span         consecutive pings inside one polygon spanning at least G hours
#   event_pair       an STK `I` then `U` at the same standard harbour, G hours or more apart, both
#                    `io_ok` and kept by `ping_clean`; only from EVENT_FROM (decision 059: events before
#                    2017 are mostly flicker and duplicate flags, so the general rules carry those years)
# A seed is extended over the contiguous pings inside the same polygon on either side. Seeds at one
# harbour that overlap or touch are one stay. `rule` is the strongest evidence present (event_pair >
# tag_then_gap > tag_span > gap_near_harbour); `evidence` lists all of them. Where a stay has both ping
# and event evidence the two time ranges are kept (`*_ping`, `*_ev`) so their agreement can be read.
#
# A stay's year is the year of T_in. A year's pings are padded with the vessel's last ping of the year
# before and first ping of the year after, so a gap over New Year is seen; a stay that ends in the next
# year's first ping is cut there, not extended (`year_edge`).
#
# Not here: the pass-through guard for event pairs (they must be >= G hours, so a 1-60 min transit never
# qualifies), the per-harbour radius and class (TODO 33; one R_M for all), foreign harbours (no `einar`
# polygon, deferred in plan §3.6), and the vessels with two streams in one mid (2765, ...).

library(dplyr)
library(sf)
sf::sf_use_s2(FALSE)

# -- Parameters ----------------------------------------------------------------

G_H        <- 4      # a stay is at least this many hours (the current MIN_HARBOUR_H)
R_M        <- 2000   # a ping this close to a polygon counts as at that harbour (Phase 0: 96 % of gap ends)
EVENT_FROM <- as.integer(Sys.getenv("STAY_EVENT_FROM", "2017"))   # first year whose events are used

con <- duckdbfs::cached_connection()
duckdbfs::load_spatial()
q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) DBI::dbExecute(con, sql)

clean_dir <- file.path(fd_staging("ais", "ping_clean"), "year=*", "**", "*.parquet")
event_f   <- fd_curated("check", "stk_event.parquet")
YEARS     <- as.integer(strsplit(Sys.getenv("STAY_YEARS", ""), ",")[[1]])
ALL       <- !length(YEARS)

# -- Polygons and their R_M buffers, in a temp table ---------------------------------

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |> select(pid) |> sf::st_make_valid()
near <- sf::st_transform(sf::st_buffer(sf::st_transform(P, 3575), R_M), 4326)
DBI::dbWriteTable(con, "harb_wkt", tibble(pid = P$pid,
                                          poly = sf::st_as_text(sf::st_geometry(P), digits = 15),
                                          near = sf::st_as_text(sf::st_geometry(near), digits = 15)),
                  overwrite = TRUE, temporary = TRUE)
x("CREATE OR REPLACE TEMP TABLE harb AS
   SELECT pid, ST_GeomFromText(poly) AS g, ST_GeomFromText(near) AS gn FROM harb_wkt")

# -- One year ------------------------------------------------------------------------

stay_year <- function(yr) {
  # pings of the year plus the neighbouring years' boundary pings, numbered per vessel
  x(glue::glue("
    CREATE OR REPLACE TEMP TABLE seq AS
    WITH c AS (SELECT vid, time, lon, lat, year FROM read_parquet('{clean_dir}', hive_partitioning = true)
               WHERE year BETWEEN {yr - 1L} AND {yr + 1L}),
    base AS (
      SELECT vid, time, lon, lat FROM c WHERE year = {yr}
      UNION ALL SELECT vid, time, lon, lat FROM c WHERE year = {yr - 1L}
                QUALIFY row_number() OVER (PARTITION BY vid ORDER BY time DESC) = 1
      UNION ALL SELECT vid, time, lon, lat FROM c WHERE year = {yr + 1L}
                QUALIFY row_number() OVER (PARTITION BY vid ORDER BY time) = 1)
    SELECT vid, time, lon, lat, row_number() OVER (PARTITION BY vid ORDER BY time) AS rn FROM base"))

  # harbour of each ping: nearest candidate polygon among those whose buffer holds it
  x("CREATE OR REPLACE TEMP TABLE tg AS
     SELECT s.vid, s.rn, any_value(s.time) AS time,
            arg_min(h.pid, ST_Distance(ST_Point(s.lon, s.lat), h.g)) AS h,
            min(ST_Distance(ST_Point(s.lon, s.lat), h.g)) = 0 AS inside
     FROM seq s JOIN harb h ON ST_Intersects(h.gn, ST_Point(s.lon, s.lat))
     GROUP BY s.vid, s.rn")

  x(glue::glue("
    CREATE OR REPLACE TEMP TABLE runs AS
    SELECT vid, h, min(rn) AS s, max(rn) AS e, min(time) AS t_s, max(time) AS t_e
    FROM (SELECT *, rn - row_number() OVER (PARTITION BY vid, h ORDER BY rn) AS grp FROM tg WHERE inside)
    GROUP BY vid, h, grp"))

  # seeds, extended over the contiguous inside pings at either end, then merged by ping index
  x(glue::glue("
    CREATE OR REPLACE TEMP TABLE pstay AS
    WITH a AS (
      SELECT *, lead(rn) OVER w AS nrn, lead(h) OVER w AS nh, lead(inside) OVER w AS nin, lead(time) OVER w AS nt
      FROM tg WINDOW w AS (PARTITION BY vid ORDER BY rn)),
    seeds AS (
      SELECT vid, h, rn AS s, nrn AS e, time AS t_s, nt AS t_e,
             CASE WHEN inside OR nin THEN 'tag_then_gap' ELSE 'gap_near_harbour' END AS rule
      FROM a WHERE nrn = rn + 1 AND nh = h AND epoch(nt - time) >= {G_H} * 3600
      UNION ALL
      SELECT vid, h, s, e, t_s, t_e, 'tag_span' FROM runs WHERE epoch(t_e - t_s) >= {G_H} * 3600),
    ext AS (
      SELECT sd.vid, sd.h, least(sd.s, coalesce(r1.s, sd.s)) AS s, greatest(sd.e, coalesce(r2.e, sd.e)) AS e,
             least(sd.t_s, coalesce(r1.t_s, sd.t_s)) AS t_s, greatest(sd.t_e, coalesce(r2.t_e, sd.t_e)) AS t_e, sd.rule
      FROM seeds sd
      LEFT JOIN runs r1 ON r1.vid = sd.vid AND r1.h = sd.h AND sd.s BETWEEN r1.s AND r1.e
      LEFT JOIN runs r2 ON r2.vid = sd.vid AND r2.h = sd.h AND sd.e BETWEEN r2.s AND r2.e),
    m AS (
      SELECT *, max(e) OVER (PARTITION BY vid, h ORDER BY s, e ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS pe
      FROM ext),
    g AS (
      SELECT *, sum(CASE WHEN pe IS NULL OR s > pe + 1 THEN 1 ELSE 0 END) OVER (PARTITION BY vid, h ORDER BY s, e) AS grp
      FROM m)
    SELECT vid, h AS pid, min(t_s) AS t_in, max(t_e) AS t_out, list_distinct(list(rule)) AS rules
    FROM g GROUP BY vid, h, grp"))

  # event pairs: I then U, adjacent in the vessel's event sequence, same standard harbour, both kept and ok
  ev_from <- if (yr >= EVENT_FROM) "TRUE" else "FALSE"
  x(glue::glue("
    CREATE OR REPLACE TEMP TABLE estay AS
    WITH e AS (
      SELECT vid, time, io, hid_pid, (io_ok AND in_clean) AS good,
             lead(io) OVER w AS nio, lead(time) OVER w AS nt, lead(hid_pid) OVER w AS nh, lead(io_ok AND in_clean) OVER w AS ngood
      FROM read_parquet('{event_f}') WHERE year BETWEEN {yr - 1L} AND {yr + 1L}
      WINDOW w AS (PARTITION BY vid ORDER BY time, io))
    SELECT vid, hid_pid AS pid, time AS t_in, nt AS t_out, ['event_pair'] AS rules
    FROM e WHERE {ev_from} AND io = 'I' AND nio = 'U' AND good AND ngood AND hid_pid IS NOT NULL AND nh = hid_pid
      AND epoch(nt - time) >= {G_H} * 3600 AND year(time) = {yr}"))

  # one time-based merge of ping stays and event stays
  q(glue::glue("
    WITH u AS (SELECT vid, pid, t_in, t_out, rules, 'ping' AS src FROM pstay WHERE year(t_in) = {yr}
               UNION ALL SELECT vid, pid, t_in, t_out, rules, 'ev' FROM estay),
    m AS (SELECT *, max(t_out) OVER (PARTITION BY vid, pid ORDER BY t_in, t_out ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS pe FROM u),
    g AS (SELECT *, sum(CASE WHEN pe IS NULL OR t_in > pe THEN 1 ELSE 0 END) OVER (PARTITION BY vid, pid ORDER BY t_in, t_out) AS grp FROM m)
    SELECT vid, pid, min(t_in) AS T_in, max(t_out) AS T_out,
           min(t_in) FILTER (src = 'ping') AS T_in_ping, max(t_out) FILTER (src = 'ping') AS T_out_ping,
           min(t_in) FILTER (src = 'ev')   AS T_in_ev,   max(t_out) FILTER (src = 'ev')   AS T_out_ev,
           list_sort(list_distinct(flatten(list(rules)))) AS evidence
    FROM g GROUP BY vid, pid, grp")) |>
    as_tibble() |>
    mutate(evidence_s = vapply(evidence, paste, "", collapse = "+"),
           rule = case_when(grepl("event_pair", evidence_s) ~ "event_pair",
                            grepl("tag_then_gap", evidence_s) ~ "tag_then_gap",
                            grepl("tag_span", evidence_s) ~ "tag_span",
                            TRUE ~ "gap_near_harbour"))
}

# -- Run -----------------------------------------------------------------------------

years <- if (ALL) q(glue::glue("SELECT DISTINCT year FROM read_parquet('{clean_dir}', hive_partitioning = true) ORDER BY 1"))$year else YEARS
res <- vector("list", length(years))
for (k in seq_along(years)) {
  yr <- years[k]; t0 <- Sys.time(); message("harbour_stay ", yr)
  res[[k]] <- stay_year(yr)
  message(sprintf("  %s stays, %.1f min", format(nrow(res[[k]]), big.mark = ","),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

out <- bind_rows(res) |>
  transmute(vid, pid, year = as.integer(format(T_in, "%Y")), T_in, T_out,
            dur_h = as.numeric(T_out - T_in, units = "hours"),
            rule, evidence = evidence_s, T_in_ping, T_out_ping, T_in_ev, T_out_ev,
            basis = "reconstructed") |>
  arrange(vid, T_in)
stopifnot(!anyDuplicated(out[c("vid", "pid", "T_in")]))

print(out |> count(year, rule) |> tidyr::pivot_wider(names_from = rule, values_from = n), n = Inf)

if (ALL) {
  out |> write_curated(
    fd_curated("ais", "harbour_stay.parquet"),
    inputs = c(fd_staging("aux", "ports.fgb"), event_f,
               list.files(fd_staging("ais", "ping_clean"), pattern = "parquet$", recursive = TRUE, full.names = TRUE)))
  message(sprintf("harbour_stay: %s stays", format(nrow(out), big.mark = ",")))
} else {
  assign("stay_test", out, envir = globalenv())
  message("subset run (STAY_YEARS): nothing written")
}
