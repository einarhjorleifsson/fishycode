# event.R — one row per STK port event (`I` in / `U` out), with tags from STK alone.
# Side: preprocessing (stk). See plan 014.
#
# Input:  staging/ais/stk                  (vid, time, io, hid, lon, lat; the raw event rows)
#         staging/aux/ports.fgb            (standard harbour polygons; source == "einar")
#         curated/reference/stk_hid_pid.parquet   (STK code -> standard pid, with reviewed overrides)
# Output: staging/ais/stk_event.parquet  one row per (vid, time, io)
#
# Plan 011 §3.1, §3.3, Phase 2; plan 014 phase 3 (b). STK preprocessing: it reads STK and the port polygons only,
# never the cleaned track, so it no longer depends on step 0. Until plan 014 it was curate/checks/stk_event.R and
# also tested each event against its neighbours on `ping_clean` (`io_jump`, `in_clean`); that test rejected only
# 40 of 3,400,403 events (2017+) that step 0 kept (decision 075). Which events a stay trusts is decided in the
# flow (curate/harbour_stay.R): `io_ok` here, and step 0 keeping the event's ping.
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

library(dplyr)
library(sf)
sf::sf_use_s2(FALSE)

# -- Parameters ----------------------------------------------------------------

SHORT_S <- 60    # I then U closer than this at one code is a flicker

con <- duckdbfs::cached_connection()
q <- function(sql) DBI::dbGetQuery(con, sql)
x <- function(sql) DBI::dbExecute(con, sql)

stk_dir   <- file.path(fd_staging("ais", "stk"), "**", "*.parquet")
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

# -- 2. Position against the polygon of the harbour the code names ------------------

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

# -- 3. Run -------------------------------------------------------------------------

years <- if (ALL) q("SELECT DISTINCT year FROM ev ORDER BY 1")$year else YEARS
res <- vector("list", length(years))

for (k in seq_along(years)) {
  yr <- years[k]; message("stk_event ", yr)
  d <- q(glue::glue("SELECT * FROM ev WHERE year = {yr}")) |> as_tibble()
  d <- d |>
    position_year() |>
    dist_to_own() |>
    mutate(
      io_dup   = !is.na(prev_io) & prev_io == io,
      io_short = (io == "I" & next_io %in% "U" & next_hid %in% hid & !is.na(hid) &
                    as.numeric(next_time - time, units = "secs") < SHORT_S) |
                 (io == "U" & prev_io %in% "I" & prev_hid %in% hid & !is.na(hid) &
                    as.numeric(time - prev_time, units = "secs") < SHORT_S),
      bad_pos  = (io == "I" & io_pos %in% c("other_harbour", "outside")) |
                 (io == "U" & io_pos == "other_harbour"),
      io_ok    = !bad_pos & !io_dup & !io_short) |>
    select(vid, time, io, year, hid, hid_all, hid_conflict, n_rows, n_pos, lon, lat,
           hid_pid, resolve, hid_status, pid_pos, io_pos, pos_dist_m,
           io_dup, io_short, io_ok)
  res[[k]] <- d
}
out <- bind_rows(res) |> arrange(vid, time, io)
stopifnot(!anyDuplicated(out[c("vid", "time", "io")]))

# -- 4. Share of each tag by year (plan §4, Phase 2: report before anything consumes it) -------

shares <- out |>
  group_by(year, io) |>
  summarise(n = n(),
            pos_own = mean(io_pos == "own"), pos_other = mean(io_pos == "other_harbour"),
            pos_outside = mean(io_pos == "outside"), pos_untested = mean(io_pos %in% c("no_hid", "no_pid")),
            dup = mean(io_dup), short = mean(io_short), ok = mean(io_ok), .groups = "drop")
print(shares, n = Inf, width = Inf)

if (ALL) {
  # staging is source-shaped and unstamped (write_curated() is for curated/ only)
  f <- fd_staging("ais", "stk_event.parquet")
  out |> duckdbfs::write_dataset(f)
  message(sprintf("stk_event: %s events, %.1f %% io_ok", format(nrow(out), big.mark = ","), 100 * mean(out$io_ok)))
} else {
  assign("stk_event_test", out, envir = globalenv())
  message("subset run (STK_EVENT_YEARS): nothing written")
}
