# harbour_radius.R — how far from a harbour polygon the first ping after a stay may lie.
#
# Input:  curated/check/stk_event.parquet   (tagged STK events; pos_dist_m of the `U` ping)
#         staging/aux/ports.fgb             (the harbour list; source == "einar")
# Output: curated/reference/harbour_radius.parquet   one row per Iceland/Faroe harbour
#
# Plan 011 §3.6 (the `r_m` of the harbour profile), decision 060. A real stay ends when the vessel
# leaves, and the first ping heard afterwards (STK's `U`) lies outside the polygon, usually just
# outside (median 94 m) but for some harbours far out: Hornafjörður's boat channel puts it 3.4 km
# away at p95. One radius for all harbours is wrong both ways (decision 060). The arrival end needs
# no such allowance (the `I` ping is inside the polygon), so the radius is only for the DEPARTURE end:
#   r_in_m   2000  the arrival end, for every harbour
#   r_out_m  p95 of the `U` distance over the harbour's real pairs, clamped to [R_FLOOR, R_CAP]; a distance
#            beyond R_CAP is treated as a bad event and left out of the quantile (`share_gt_cap` keeps it)
# A real pair is an adjacent `I`->`U` at one harbour, at least G_H hours apart, both `io_ok` and kept
# by `ping_clean`, 2008-2025. A harbour with fewer than MIN_PAIRS pairs, or none (no STK events),
# gets the floor and `basis = "synthesised"`; otherwise `basis = "reconstructed"`. The cap guards
# against event errors: with them in, p95 was 20-59 km at IS-DRN and IS-BLO, which is a bad event, not a
# harbour, and a cap alone would still have given those harbours a 6 km radius.
#
# No cycle: the pairs come from events and polygons, never from the stays this table is used for.
# A reviewed override (as for the harbour class, which goes: decision 074) is not built; add one when a value is
# judged wrong.

library(dplyr)

G_H       <- 4
R_IN      <- 2000
R_FLOOR   <- 2000
R_CAP     <- 6000
MIN_PAIRS <- 100
QUANTILE  <- 0.95

con <- DBI::dbConnect(duckdb::duckdb())
ev  <- fd_curated("check", "stk_event.parquet")

d <- DBI::dbGetQuery(con, glue::glue("
  WITH e AS (
    SELECT io, year, hid_pid, io_ok, in_clean, time,
           lead(io) OVER w AS nio, lead(time) OVER w AS nt, lead(hid_pid) OVER w AS nh,
           lead(io_ok) OVER w AS nok, lead(in_clean) OVER w AS ncl, lead(pos_dist_m) OVER w AS d_out
    FROM read_parquet('{ev}') WINDOW w AS (PARTITION BY vid ORDER BY time, io))
  SELECT hid_pid AS pid, count(*) AS n_pairs,
         quantile_cont(d_out, 0.5) FILTER (d_out <= {R_CAP}) AS d_p50,
         quantile_cont(d_out, 0.9) FILTER (d_out <= {R_CAP}) AS d_p90,
         quantile_cont(d_out, {QUANTILE}) FILTER (d_out <= {R_CAP}) AS d_p95,
         avg((d_out > {R_IN})::INT) AS share_gt_r_in, avg((d_out > {R_CAP})::INT) AS share_gt_cap
  FROM e WHERE io = 'I' AND nio = 'U' AND hid_pid IS NOT NULL AND nh = hid_pid AND io_ok AND nok AND in_clean AND ncl
    AND epoch(nt - time) >= {G_H} * 3600 AND year BETWEEN 2008 AND 2025 AND d_out IS NOT NULL
  GROUP BY hid_pid")) |> as_tibble()

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |> filter(source == "einar") |> sf::st_drop_geometry() |> select(pid, port)

out <- P |>
  left_join(d, by = "pid") |>
  mutate(n_pairs = coalesce(as.integer(n_pairs), 0L),
         measured = n_pairs >= MIN_PAIRS,
         r_in_m  = R_IN,
         r_out_m = if_else(measured, pmin(pmax(d_p95, R_FLOOR), R_CAP), R_FLOOR),
         basis   = if_else(measured, "reconstructed", "synthesised")) |>
  select(pid, port, r_in_m, r_out_m, basis, n_pairs, d_p50, d_p90, d_p95, share_gt_r_in, share_gt_cap) |>
  arrange(desc(r_out_m), desc(n_pairs))

stopifnot(!anyDuplicated(out$pid))
out |> write_curated(fd_curated("reference", "harbour_radius.parquet"),
                     inputs = c(ev, fd_staging("aux", "ports.fgb")))
message(sprintf("harbour_radius: %d harbours, %d measured, %d with r_out above the floor, %d at the cap",
                nrow(out), sum(out$basis == "reconstructed"), sum(out$r_out_m > R_FLOOR), sum(out$r_out_m >= R_CAP)))
