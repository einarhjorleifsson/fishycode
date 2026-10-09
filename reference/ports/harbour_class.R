# harbour_class.R — what a harbour is, per year, from how long vessels stay there.
# Side: flow, step 1 (removed in plan 014 phase 3, decision 074). See plan 014.
#
# Input:  curated/check/stk_event.parquet   (tagged STK I/U events; used: io_ok, in_clean, hid_pid)
#         staging/ais/stk                   (speed of the event pings)
#         staging/aux/ports.fgb             (the harbour list; source == "einar")
#         overrides/harbour_class.csv       (reviewed: pid, year_from, year_to, class, reason)
# Output: curated/reference/harbour_class.parquet   one row per (pid, year), 2007-2026
#
# TODO 33, plan 011 §3.6. No external source carries a class for Iceland (OSM: 5 of 157), so it comes from the
# `I`->`U` pairs of STK, which exist from 2007-09-01. A harbour is not one thing forever (fishing ports declined,
# memory harbour-class-is-time-varying), so the class is per harbour AND year. Period design (PROVISIONAL, the
# maintainer has not settled it): each year pools the pairs of year-1, year and year+1, so a harbour with a few
# hundred pairs a year is judged on enough of them and a change shows with one year's lag at most.
#
# A pair is an adjacent `I`->`U` at one `hid_pid`, both `io_ok` and kept by ping_clean, any duration. Per
# (pid, year): n_pairs, p_ge4h (share of pairs lasting 4 h or more), med_min (median minutes), p_lt60 (share under
# an hour), p_fast (share of 1-60 min pairs... of ALL pairs, lasting 1-60 min with both ends above FAST_KN: a
# vessel passing through). Class, first cut of §3.6 and tuned against the anchors reported below:
#   sparse     fewer than MIN_N pairs in the window: not judged
#   landing    at least LANDING_P of pairs reach 4 h
#   marina     under 2 % reach 4 h, median under 30 min, at least half are fast pass-throughs
#   flicker    median under 10 min, under 10 % fast pass-throughs, 90 % under an hour: the in/out flag flaps
#              on a vessel at rest, so the events say little and the stay must come from the polygon and gap rules
#   transient  otherwise (a stop-off, a ferry end)
# `no_events` = a harbour with no pairs at all (no STK coverage; foreign harbours are not in the polygon set).
# A reviewed override wins and carries `basis = "recorded"`; the data rule runs first and re-enters nothing
# computed (AGENTS: cycles are broken by a human, outside the DAG). Classes the data cannot find (cargo,
# no_pier for Hornvik) can only enter through the override file.
#
# Not here: the minimum stay per class. That is a parameter of curate/harbour_stay.R until it has been tested.

library(dplyr)

MIN_N     <- 30
LANDING_P <- 0.25
FAST_KN   <- 4
CLASSES   <- c("landing", "marina", "transient", "flicker", "sparse", "no_events", "cargo", "no_pier", "mixed")

con <- DBI::dbConnect(duckdb::duckdb())
ev  <- fd_curated("check", "stk_event.parquet")
stk <- file.path(fd_staging("ais", "stk"), "**", "*.parquet")

pairs <- DBI::dbGetQuery(con, glue::glue("
  WITH spd AS (SELECT vid, time, io, min(speed) AS speed
               FROM read_parquet('{stk}', hive_partitioning = true) WHERE io IN ('I', 'U') AND vid IS NOT NULL GROUP BY ALL),
  e AS (SELECT ev.vid, ev.time, ev.io, ev.year, ev.hid_pid, (ev.io_ok AND ev.in_clean) AS good, spd.speed
        FROM read_parquet('{ev}') ev LEFT JOIN spd USING (vid, time, io)),
  w AS (SELECT *, lead(io) OVER x AS nio, lead(time) OVER x AS nt, lead(hid_pid) OVER x AS nh,
               lead(good) OVER x AS ngood, lead(speed) OVER x AS nspeed
        FROM e WINDOW x AS (PARTITION BY vid ORDER BY time, io))
  SELECT hid_pid AS pid, year, epoch(nt - time) / 60.0 AS dur_min, speed AS s_in, nspeed AS s_out
  FROM w WHERE io = 'I' AND nio = 'U' AND good AND ngood AND hid_pid IS NOT NULL AND nh = hid_pid")) |>
  as_tibble() |>
  mutate(ge4h = dur_min >= 240, lt60 = dur_min < 60,
         fast = dur_min >= 1 & dur_min < 60 & coalesce(s_in > FAST_KN & s_out > FAST_KN, FALSE))

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |> filter(source == "einar") |> sf::st_drop_geometry() |> select(pid, port)
YEARS <- 2007:2026

stats <- purrr::map(YEARS, function(y) {
  pairs |> filter(year >= y - 1, year <= y + 1) |>
    group_by(pid) |>
    summarise(n_pairs = n(), p_ge4h = mean(ge4h), med_min = median(dur_min), p_lt60 = mean(lt60), p_fast = mean(fast),
              .groups = "drop") |>
    mutate(year = y)
}) |> bind_rows()

out <- tidyr::expand_grid(P, year = YEARS) |>
  left_join(stats, by = c("pid", "year")) |>
  mutate(n_pairs = coalesce(as.integer(n_pairs), 0L),
         class = case_when(n_pairs == 0 ~ "no_events",
                           n_pairs < MIN_N ~ "sparse",
                           p_ge4h >= LANDING_P ~ "landing",
                           p_ge4h < 0.02 & med_min < 30 & p_fast >= 0.5 ~ "marina",
                           med_min < 10 & p_fast < 0.10 & p_lt60 >= 0.9 ~ "flicker",
                           TRUE ~ "transient"),
         basis = "reconstructed", override_reason = NA_character_)

# -- Reviewed overrides re-enter here, as an input ------------------------------------------------------------
ov <- read.csv("overrides/harbour_class.csv", colClasses = "character")
if (nrow(ov)) {
  stopifnot(all(c("pid", "year_from", "year_to", "class", "reason") %in% names(ov)),
            all(ov$pid %in% P$pid), all(ov$class %in% CLASSES))
  for (i in seq_len(nrow(ov))) {
    y0 <- if (nzchar(ov$year_from[i])) as.integer(ov$year_from[i]) else min(YEARS)
    y1 <- if (nzchar(ov$year_to[i]))   as.integer(ov$year_to[i])   else max(YEARS)
    hit <- out$pid == ov$pid[i] & out$year >= y0 & out$year <= y1
    out$class[hit] <- ov$class[i]; out$basis[hit] <- "recorded"; out$override_reason[hit] <- ov$reason[i]
  }
}

out <- out |> select(pid, port, year, class, basis, n_pairs, p_ge4h, med_min, p_lt60, p_fast, override_reason)
stopifnot(!anyDuplicated(out[c("pid", "year")]))
out |> write_curated(fd_curated("reference", "harbour_class.parquet"),
                     inputs = c(ev, fd_staging("aux", "ports.fgb"), "overrides/harbour_class.csv"))

# -- Report: classes by year, stability, anchors -----------------------------------------------------------------
print(out |> filter(year %in% c(2008, 2012, 2016, 2020, 2024)) |> count(year, class) |> tidyr::pivot_wider(names_from = class, values_from = n, values_fill = 0), n = Inf)
chg <- out |> arrange(pid, year) |> group_by(pid) |>
  mutate(chg = class != lag(class) & !class %in% c("no_events", "sparse") & !lag(class) %in% c("no_events", "sparse")) |> ungroup()
message(sprintf("harbour_class: %d harbour-years; %.1f %% of judged year-to-year steps change class",
                nrow(out), 100 * mean(chg$chg[!is.na(chg$chg) & !chg$class %in% c("no_events", "sparse")])))
anch <- c(IS_REY = "IS-REY", VESTM = "IS-VES", AKU = "IS-AKU", OLV = "IS-OLV", DAL = "IS-DAL", HRI = "IS-HRI", ASS = "IS-ASS", NJA = "IS-NJA", HOR = "IS-HOR", KRI = "IS-KRI", HRN = "IS-HRN")
print(out |> filter(pid %in% anch, year %in% c(2010, 2016, 2022)) |> select(pid, year, class, n_pairs, p_ge4h, med_min, p_fast) |> arrange(pid, year) |> as.data.frame())
