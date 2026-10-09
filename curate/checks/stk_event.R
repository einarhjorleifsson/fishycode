# stk_event.R — one row per STK harbour event (`I` in / `U` out), with tags that say which to distrust.
# Side: flow, step 1 (STK events; STK-only preprocessing from plan 014 phase 3). See plan 014.
#
# Input:  staging/ais/stk                  (vid, time, io, hid, lon, lat; the raw event rows)
#         staging/ais/ping_clean           (the cleaned track the neighbours are taken from)
#         staging/aux/ports.fgb            (standard harbour polygons; source == "einar")
#         curated/reference/stk_hid_pid.parquet   (STK code -> standard pid, with reviewed overrides)
# Output: curated/check/stk_event.parquet  one row per (vid, time, io)
#
# Plan 011 §3.1, §3.3, Phase 2. A check, not a correction: it flags and corrects nothing, and nothing
# reads it yet. Phase 3 (stays) decides which tags a stay may trust.
#
# One row per ping, not per source row. STK ships most `U` events twice, one row with the harbour code
# and one without (3.03 M of 4.39 M `U` pings, 2007-2025); `I` is nearly always one row. The plan's
# earlier event counts (6.77 M `U`, 40 % without `hid`, `U->U` 26 %) were counts of source rows, so the
# duplication inflated them. Rows are collapsed on (vid, time, io); `n_rows` keeps how many there were.
# Where one ping carries two different codes (`hid_conflict`) no code is chosen: `hid` is NA and
# `hid_all` lists them.
#
# Tags (TRUE = a defect was found; NA = could not be judged; `io_ok` = none fired):
#   io_pos    own / other_harbour / outside — the event's position against the polygon of the harbour its
#             code names (`hid_pid`); no_hid / no_pid where there is nothing to compare with. For a code
#             that cannot name a harbour (`resolve = position`, THH/THO) the harbour is the event's own
#             polygon, so such an event can only be `own` or `outside`. `pos_dist_m` is the distance to
#             that polygon, so a reader can apply a tolerance. Only an `I` is judged by it: a `U` is sent
#             after the vessel has left, 66 % lie outside every polygon, and the test for `U` is still
#             an open decision (plan 011 §5 c), so `U` position is reported and never makes `io_ok` false
#             except as `other_harbour`.
#   io_dup    the vessel's previous event has the same `io` (I after I, U after U)
#   io_short  `I` then `U` at the same code within SHORT_S seconds (both rows of the pair)
#   io_jump   inconsistent with BOTH neighbours on the cleaned track (implied speed above KN_MAX into and
#             out of the event) while the neighbours are consistent with each other (speed across
#             them at most KN_MAX). If the neighbours disagree the fault is theirs and the event is not
#             blamed. NA when a neighbour is missing. The neighbours are the nearest RETAINED pings that
#             are not themselves events, so an event is never judged against another event. A long gap
#             makes every position plausible; `gap_prev_h`/`gap_next_h` say how much a FALSE is worth.
#   in_clean  whether `ping_clean` kept the event ping. The jump test is run on events it dropped too,
#             which says whether the whack filter was right to drop them.
#
# The speed is the great-circle distance over elapsed time, as in whack_fwdbwd (ramb). ramb has no
# event-against-neighbours test, so that part lives here.

library(dplyr)
library(sf)
sf::sf_use_s2(FALSE)

# -- Parameters ----------------------------------------------------------------

KN_MAX  <- 25    # same threshold as ping_clean
SHORT_S <- 60    # I then U closer than this at one code is a flicker
PAD_D   <- 30    # days of neighbours read beyond each year's edges

KN_TO_MS <- 0.514444

con <- duckdbfs::cached_connection()
q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) DBI::dbExecute(con, sql)

stk_dir   <- file.path(fd_staging("ais", "stk"), "**", "*.parquet")
clean_dir <- fd_staging("ais", "ping_clean")
YEARS     <- as.integer(strsplit(Sys.getenv("STK_EVENT_YEARS", ""), ",")[[1]])  # test hook: a subset never writes
ALL       <- !length(YEARS)

# -- 1. Events, collapsed to one row per ping, with the sequence tags ---------------

x(glue::glue("
  CREATE OR REPLACE TEMP TABLE ev AS
  WITH g AS (
    SELECT vid, time, io,
           count(*)                                       AS n_rows,
           count(DISTINCT hid)                            AS n_hid,
           string_agg(DISTINCT hid, '|' ORDER BY hid)     AS hid_all,
           min(hid)                                       AS hid_one,
           min(lon) AS lon, min(lat) AS lat,
           count(DISTINCT (lon, lat))                     AS n_pos
    FROM read_parquet('{stk_dir}', hive_partitioning = true)
    WHERE io IN ('I', 'U') AND vid IS NOT NULL AND lon IS NOT NULL AND lat IS NOT NULL
    GROUP BY vid, time, io
  )
  SELECT vid, time, io, year(time) AS year, n_rows, n_pos,
         CASE WHEN n_hid = 1 THEN hid_one END             AS hid,
         hid_all, n_hid > 1                               AS hid_conflict,
         lon, lat,
         lag(io)    OVER w                                AS prev_io,
         lead(io)   OVER w                                AS next_io,
         lag(time)  OVER w                                AS prev_time,
         lead(time) OVER w                                AS next_time,
         lag(CASE WHEN n_hid = 1 THEN hid_one END)  OVER w AS prev_hid,
         lead(CASE WHEN n_hid = 1 THEN hid_one END) OVER w AS next_hid
  FROM g
  WINDOW w AS (PARTITION BY vid ORDER BY time, io)
"))

ev_keys <- "(SELECT DISTINCT vid, time FROM ev)"

# -- 2. Per year: neighbours on the cleaned track ----------------------------------

jump_year <- function(yr) {
  t0 <- sprintf("%d-01-01", yr - 0L); t1 <- sprintf("%d-01-01", yr + 1L)
  q(glue::glue("
    WITH e AS (SELECT vid, time, io, lon, lat FROM ev WHERE year = {yr}),
    nb AS (
      SELECT vid, time, lon, lat
      FROM read_parquet('{clean_dir}/year=*/**/*.parquet', hive_partitioning = true)
      WHERE year BETWEEN {yr - 1L} AND {yr + 1L}
        AND time >= TIMESTAMP '{t0}' - INTERVAL {PAD_D} DAY
        AND time <  TIMESTAMP '{t1}' + INTERVAL {PAD_D} DAY
        AND (vid, time) NOT IN {ev_keys}
    ),
    p AS (SELECT e.vid, e.time, e.io, e.lon, e.lat, nb.time AS t0, nb.lon AS lon0, nb.lat AS lat0
          FROM e ASOF LEFT JOIN nb ON e.vid = nb.vid AND e.time > nb.time),
    n AS (SELECT p.*, nb.time AS t2, nb.lon AS lon2, nb.lat AS lat2
          FROM p ASOF LEFT JOIN nb ON p.vid = nb.vid AND p.time < nb.time)
    SELECT n.vid, n.time, n.io,
           (c.vid IS NOT NULL) AS in_clean,
           epoch(n.time - n.t0) / 3600.0 AS gap_prev_h,
           epoch(n.t2 - n.time) / 3600.0 AS gap_next_h,
           {hav('lat0', 'lon0', 'lat', 'lon')} / GREATEST(epoch(n.time - n.t0), 1) / {KN_TO_MS} AS v_prev_kn,
           {hav('lat', 'lon', 'lat2', 'lon2')} / GREATEST(epoch(n.t2 - n.time), 1) / {KN_TO_MS} AS v_next_kn,
           {hav('lat0', 'lon0', 'lat2', 'lon2')} / GREATEST(epoch(n.t2 - n.t0), 1) / {KN_TO_MS} AS v_span_kn
    FROM n
    LEFT JOIN (SELECT DISTINCT vid, time FROM read_parquet('{clean_dir}/year=*/**/*.parquet', hive_partitioning = true)
               WHERE year BETWEEN {yr - 1L} AND {yr + 1L}) c
      USING (vid, time)
  "))
}

hav <- function(la1, lo1, la2, lo2)
  glue::glue("2 * 6371000 * asin(sqrt(power(sin(radians(({la2} - {la1}) / 2)), 2) +
              cos(radians({la1})) * cos(radians({la2})) * power(sin(radians(({lo2} - {lo1}) / 2)), 2)))")

# -- 3. Position against the polygon of the harbour the code names ------------------

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |>
  select(pid) |>
  sf::st_make_valid()
P_m <- sf::st_transform(P, 3575)

xw <- nanoparquet::read_parquet(fd_curated("reference", "stk_hid_pid.parquet")) |>
  as_tibble() |>
  transmute(hid, pid_code = pid, resolve, hid_status = status)

position_year <- function(d) {
  # distinct coordinates only: a vessel at a quay repeats one fix thousands of times
  u <- d |> distinct(lon, lat)
  pts <- sf::st_as_sf(u, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  hit <- sf::st_intersects(pts, P)
  u$hits <- lapply(hit, function(h) P$pid[h])
  d <- d |> left_join(u, by = c("lon", "lat"))
  d |>
    left_join(xw, by = "hid") |>
    mutate(
      hid_pid = case_when(resolve %in% "position" ~ vapply(hits, \(h) if (length(h)) h[1] else NA_character_, ""),
                          TRUE ~ pid_code),
      inside  = purrr::map2_lgl(hits, hid_pid, \(h, p) !is.na(p) && p %in% h),
      pid_pos = purrr::map2_chr(hits, hid_pid, \(h, p) if (!is.na(p) && p %in% h) p else if (length(h)) h[1] else NA_character_),
      io_pos  = case_when(is.na(hid) & !(resolve %in% "position") ~ "no_hid",
                          is.na(hid_pid) & !(resolve %in% "position") ~ "no_pid",
                          inside ~ "own",
                          lengths(hits) > 0 ~ "other_harbour",
                          TRUE ~ "outside"))
}

dist_to_own <- function(d) {
  d$pos_dist_m <- NA_real_
  d$pos_dist_m[d$inside] <- 0
  todo <- which(!d$inside & !is.na(d$hid_pid))
  for (p in unique(d$hid_pid[todo])) {
    i <- todo[d$hid_pid[todo] == p]
    pts <- sf::st_transform(sf::st_as_sf(d[i, ], coords = c("lon", "lat"), crs = 4326), 3575)
    d$pos_dist_m[i] <- as.numeric(sf::st_distance(pts, P_m[P_m$pid == p, ]))[seq_along(i)]
  }
  d
}

# -- 4. Run -------------------------------------------------------------------------

years <- if (ALL) q("SELECT DISTINCT year FROM ev ORDER BY 1")$year else YEARS
res <- vector("list", length(years))

for (k in seq_along(years)) {
  yr <- years[k]; message("stk_event ", yr)
  d <- q(glue::glue("SELECT * FROM ev WHERE year = {yr}")) |> as_tibble()
  j <- jump_year(yr) |> as_tibble()
  d <- d |>
    left_join(j, by = c("vid", "time", "io")) |>
    position_year() |>
    dist_to_own() |>
    mutate(
      io_dup   = !is.na(prev_io) & prev_io == io,
      io_short = (io == "I" & next_io %in% "U" & next_hid %in% hid & !is.na(hid) &
                    as.numeric(next_time - time, units = "secs") < SHORT_S) |
                 (io == "U" & prev_io %in% "I" & prev_hid %in% hid & !is.na(hid) &
                    as.numeric(time - prev_time, units = "secs") < SHORT_S),
      io_jump  = if_else(is.na(v_prev_kn) | is.na(v_next_kn), NA,
                         v_prev_kn > KN_MAX & v_next_kn > KN_MAX & v_span_kn <= KN_MAX),
      bad_pos  = (io == "I" & io_pos %in% c("other_harbour", "outside")) |
                 (io == "U" & io_pos == "other_harbour"),
      io_ok    = !bad_pos & !io_dup & !io_short & !coalesce(io_jump, FALSE)) |>
    select(vid, time, io, year, hid, hid_all, hid_conflict, n_rows, n_pos, lon, lat,
           hid_pid, resolve, hid_status, pid_pos, io_pos, pos_dist_m,
           io_dup, io_short, in_clean, gap_prev_h, gap_next_h, v_prev_kn, v_next_kn, v_span_kn,
           io_jump, io_ok)
  res[[k]] <- d
}
out <- bind_rows(res) |> arrange(vid, time, io)
stopifnot(!anyDuplicated(out[c("vid", "time", "io")]))

# -- 5. Share of each tag by year (plan §4, Phase 2: report before anything consumes it) -------

shares <- out |>
  group_by(year, io) |>
  summarise(n = n(),
            pos_own = mean(io_pos == "own"), pos_other = mean(io_pos == "other_harbour"),
            pos_outside = mean(io_pos == "outside"), pos_untested = mean(io_pos %in% c("no_hid", "no_pid")),
            dup = mean(io_dup), short = mean(io_short), jump = mean(io_jump, na.rm = TRUE),
            jump_judged = mean(!is.na(io_jump)), in_clean = mean(in_clean, na.rm = TRUE),
            ok = mean(io_ok), .groups = "drop")
print(shares, n = Inf, width = Inf)

if (ALL) {
  out |> write_curated(
    fd_curated("check", "stk_event.parquet"),
    inputs = c(fd_staging("aux", "ports.fgb"), fd_curated("reference", "stk_hid_pid.parquet"),
               list.files(fd_staging("ais", "stk"), pattern = "parquet$", recursive = TRUE, full.names = TRUE),
               list.files(clean_dir, pattern = "parquet$", recursive = TRUE, full.names = TRUE)))
  message(sprintf("stk_event: %s events, %.1f %% io_ok", format(nrow(out), big.mark = ","), 100 * mean(out$io_ok)))
} else {
  assign("stk_event_test", out, envir = globalenv())
  message("subset run (STK_EVENT_YEARS): nothing written")
}
