# audit_witnesses.R — the witnesses used to audit the STK mid -> vid match.
#
# Function definitions only (targets sources R/ wholesale). Used by
# curate/checks/ais_key_audit.R; the design and every threshold below are argued in
# curate/plans/009-independent-audit-of-the-mid-vid-match.md and measured in
# curate/decisions/047-independent-audit-of-the-mid-vid-match.md.
#
# None of these reads the key's verdict. W1 reads other-provider AIS keyed by MMSI,
# W2 the logbook, W3 the landings; each is scored per (mid, vid, year) and a
# contradiction needs a second witness, because a single one fails in known ways
# (a ferry that "lands" at every port it calls at; placeholder mids that live days).

# Lat/lon window and a month's bounds, shared by the SQL below -----------------------
.audit_bounds <- function(y, m) {
  t0 <- sprintf("%d-%02d-01", y, m)
  t1 <- if (m == 12) sprintf("%d-01-01", y + 1) else sprintf("%d-%02d-01", y, m + 1)
  list(t0 = t0, t1 = t1)
}

# W1: co-location -----------------------------------------------------------------
# An STK ping of mid M is a hit for vid V when another provider's ping labelled V
# (via MMSI) lies within dt_s seconds and dist_km. Blocked on a 10-minute bucket x
# 0.1 deg lat x 0.25 deg lon; the STK side is replicated into a neighbouring block
# only when it lies within the tolerance of that block's edge.
#
# score = hits / opportunity, where opportunity = STK pings of M that had ANY ping of
# V within dt_s (anywhere). Dividing by all STK pings instead makes a sparse provider
# look like a failed match: measured, tier-A confirmation was 96-100 % when the
# provider was at least as dense as STK and 3 % when it was not.
#
# stk: the trail's SELECT (stk_trail_sql()); ping_glob: a parquet glob. kp: (mid, vid) pairs of the key to test in
# this month, so a key pair with zero hits still gets an opportunity count.
audit_w1_month <- function(con, y, m, stk, ping_glob, kp, dt_s = 300,
                           dist_km = 2, vmin = 1) {
  b <- .audit_bounds(y, m)
  win <- sprintf("time >= timestamp '%s' - interval 10 minute and time < timestamp '%s' + interval 10 minute and speed >= %g and lat between 60 and 70 and lon between -35 and -5",
                 b$t0, b$t1, vmin)
  my <- 0.1; mx <- 0.25; hb <- 600
  ft_m <- dt_s / hb
  fy_m <- dist_km / 111.2 / my
  fx_m <- dist_km / (111.32 * cos(65 * pi / 180)) / mx
  DBI::dbExecute(con, sprintf("create or replace temp table ob as select vid, time, lon, lat, floor(epoch(time)/%d)::bigint hb, floor(lat/%g)::int cy, floor(lon/%g)::int cx from read_parquet('%s') where provider NOT IN ('stk', 'gps') and %s",
                              hb, my, mx, ping_glob, win))
  DBI::dbExecute(con, sprintf("create or replace temp table sb as select mid, time, lon, lat, epoch(time)/%d - floor(epoch(time)/%d) ft, lat/%g - floor(lat/%g) fy, lon/%g - floor(lon/%g) fx, floor(epoch(time)/%d)::bigint hb, floor(lat/%g)::int cy, floor(lon/%g)::int cx from (%s) where %s",
                              hb, hb, my, my, mx, mx, hb, my, mx, stk, win))
  DBI::dbExecute(con, "create or replace temp table d as select unnest([-1,0,1]) n")
  hits <- DBI::dbGetQuery(con, sprintf("
    with sx as (
      select sb.mid, sb.time, sb.lon, sb.lat, sb.hb + h.n hb, sb.cy + y.n cy, sb.cx + x.n cx
      from sb, d h, d y, d x
      where (h.n = 0 or (h.n = -1 and ft < %g) or (h.n = 1 and ft > 1 - %g))
        and (y.n = 0 or (y.n = -1 and fy < %g) or (y.n = 1 and fy > 1 - %g))
        and (x.n = 0 or (x.n = -1 and fx < %g) or (x.n = 1 and fx > 1 - %g))),
    p as (
      select distinct sx.mid, sx.time st, ob.vid,
             abs(epoch(sx.time) - epoch(ob.time)) dt,
             111.2 * sqrt(power(sx.lat - ob.lat, 2) + power((sx.lon - ob.lon) * cos(radians(sx.lat)), 2)) km
      from sx join ob on ob.hb = sx.hb and ob.cy = sx.cy and ob.cx = sx.cx
      where abs(epoch(sx.time) - epoch(ob.time)) <= %d)
    select mid, vid, count(distinct st) filter (where km <= %g) hit_pings
    from p group by mid, vid having count(*) filter (where km <= %g) > 0",
    ft_m, ft_m, fy_m, fy_m, fx_m, fx_m, dt_s, dist_km, dist_km))
  n_mid <- DBI::dbGetQuery(con, sprintf("select mid, count(*) n_stk from sb where time >= timestamp '%s' and time < timestamp '%s' group by 1", b$t0, b$t1))
  pr <- dplyr::distinct(dplyr::bind_rows(
    kp, dplyr::transmute(dplyr::filter(hits, hit_pings >= 3), mid, vid)))
  pr$mid <- as.numeric(pr$mid); pr$vid <- as.integer(pr$vid)
  DBI::dbWriteTable(con, "pr", pr, overwrite = TRUE)
  DBI::dbExecute(con, "create or replace temp table obx as select vid, time, hb + n as hb2 from ob, (select unnest([-1,0,1]) n)")
  opp <- DBI::dbGetQuery(con, sprintf("
    select pr.mid, pr.vid, count(distinct sb.time) opp
    from pr join sb on sb.mid = pr.mid and sb.time >= timestamp '%s' and sb.time < timestamp '%s'
            join obx on obx.vid = pr.vid and obx.hb2 = sb.hb and abs(epoch(obx.time) - epoch(sb.time)) <= %d
    group by 1, 2", b$t0, b$t1, dt_s))
  list(hits = hits, n_mid = n_mid, opp = opp, y = y, m = m)
}

# W2: logbook stations --------------------------------------------------------------
# Station (vid, day, x, y) is a hit for mid M when M has any ping within R km on that
# day. Stations carry a date only. Per month this discriminates poorly on crowded
# grounds; per YEAR it does (audit_score_year), so only year-level use is meaningful.
audit_w2_month <- function(con, y, m, stk, station, trip, R = 10) {
  b <- .audit_bounds(y, m)
  cy <- 0.2; cx <- 0.5
  fy_m <- R / 111.2 / cy; fx_m <- R / (111.32 * cos(65 * pi / 180)) / cx
  pt <- function(lon, lat) sprintf("select s.\".sid\" sid, t.vid, cast(s.date as date) d, %s lon, %s lat from read_parquet('%s') s join read_parquet('%s') t on s.\".tid\"=t.\".tid\" where s.date >= timestamp '%s' and s.date < timestamp '%s' and %s is not null and %s is not null and coalesce(s.eytt_deleted,false)=false",
                                   lon, lat, station, trip, b$t0, b$t1, lon, lat)
  DBI::dbExecute(con, sprintf("create or replace temp table stn as
    select sid, vid, d, lon, lat, floor(lat/%g)::int cy, floor(lon/%g)::int cx, lat/%g - floor(lat/%g) fy, lon/%g - floor(lon/%g) fx
    from (%s union all %s) where lat between 60 and 70 and lon between -35 and -5 and vid is not null",
    cy, cx, cy, cy, cx, cx, pt("lon1", "lat1"), pt("lon2", "lat2")))
  DBI::dbExecute(con, sprintf("create or replace temp table pg as select mid, cast(time as date) d, lon, lat, floor(lat/%g)::int cy, floor(lon/%g)::int cx from (%s) where time >= timestamp '%s' and time < timestamp '%s' and lat between 60 and 70 and lon between -35 and -5",
                              cy, cx, stk, b$t0, b$t1))
  DBI::dbExecute(con, "create or replace temp table dd as select unnest([-1,0,1]) n")
  hits <- DBI::dbGetQuery(con, sprintf("
    with sx as (select stn.sid, stn.vid, stn.d, stn.lon, stn.lat, stn.cy + y.n cy, stn.cx + x.n cx from stn, dd y, dd x
      where (y.n=0 or (y.n=-1 and fy < %g) or (y.n=1 and fy > 1-%g)) and (x.n=0 or (x.n=-1 and fx < %g) or (x.n=1 and fx > 1-%g))),
    p as (select distinct sx.sid, sx.vid, pg.mid from sx join pg on pg.d = sx.d and pg.cy = sx.cy and pg.cx = sx.cx
          where 111.2*sqrt(power(sx.lat-pg.lat,2)+power((sx.lon-pg.lon)*cos(radians(sx.lat)),2)) <= %g)
    select mid, vid, count(*) hits from p group by 1,2", fy_m, fy_m, fx_m, fx_m, R))
  n_st <- DBI::dbGetQuery(con, "select vid, count(distinct sid) n_st from stn group by 1")
  list(hits = hits, n = n_st, y = y, m = m)
}

# W3: landings ----------------------------------------------------------------------
# STK carries its own harbour events (`hid`, io = 'I' entering) on ~3 % of pings, in
# a 3-letter code that is not the landings' `hid`. The crosswalk hid -> pid is LEARNED
# from mid-months W1 has already confirmed (mid = vid known), not guessed: for each STK
# code, the landing port that co-occurs with it most often within +-1 day.
audit_w3_crosswalk <- function(con, truth, min_obs = 20) {
  DBI::dbWriteTable(con, "tr", truth, overwrite = TRUE)
  cw <- DBI::dbGetQuery(con, "select ev.hid, ld.pid, count(distinct ld.lid) n from tr join ld on ld.vid=tr.vid and year(ld.d)=tr.y and month(ld.d)=tr.m join ev on ev.mid=tr.mid and abs(datediff('day', ev.d, ld.d))<=1 group by 1,2")
  cw <- dplyr::as_tibble(cw) |>
    dplyr::group_by(hid) |>
    dplyr::mutate(tn = sum(n)) |>
    dplyr::slice_max(n, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::filter(tn >= min_obs)
  DBI::dbWriteTable(con, "cw", cw[, c("hid", "pid")], overwrite = TRUE)
  cw
}

# Year-level scoring of a monthly (pairs, denominator) table ---------------------------
# For every key (mid, vid, year): the share of the vid's evidence the mid explains
# (s_key) against the best OTHER mid over the same months (s_imp). `grid` is the key
# expanded to (mid, K, y, m) so a mid is only scored in months the key assigns it.
audit_score_year <- function(grid, Hm, Nm, min_n) {
  A <- grid |>
    dplyr::inner_join(dplyr::rename(Nm, K = vid), by = c("K", "y", "m")) |>
    dplyr::left_join(dplyr::rename(Hm, K = vid), by = c("mid", "K", "y", "m")) |>
    dplyr::mutate(hits = dplyr::coalesce(hits, 0L))
  AY <- A |>
    dplyr::group_by(mid, K, y, step, tier) |>
    dplyr::summarise(months = dplyr::n(), n = sum(n), hits = sum(hits), .groups = "drop") |>
    dplyr::mutate(s_key = hits / n)
  imp <- A |>
    dplyr::select(mid_key = mid, K, y, m) |>
    dplyr::inner_join(dplyr::rename(Hm, K = vid, mid_imp = mid, h_imp = hits),
                      by = c("K", "y", "m"), relationship = "many-to-many") |>
    dplyr::filter(mid_imp != mid_key) |>
    dplyr::group_by(mid_key, K, y, mid_imp) |>
    dplyr::summarise(h = sum(h_imp), .groups = "drop") |>
    dplyr::inner_join(dplyr::select(AY, mid_key = mid, K, y, n), by = c("mid_key", "K", "y")) |>
    dplyr::mutate(s = h / n) |>
    dplyr::group_by(mid_key, K, y) |>
    dplyr::slice_max(s, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::select(mid = mid_key, K, y, mid_imp, s_imp = s)
  AY |>
    dplyr::left_join(imp, by = c("mid", "K", "y")) |>
    dplyr::mutate(
      s_imp = dplyr::coalesce(s_imp, 0),
      cov = n >= min_n,
      v = dplyr::case_when(
        !cov                              ~ "uncovered",
        s_key >= .8 & s_key - s_imp >= .1 ~ "support",
        s_key >= .8                       ~ "ambiguous",   # fits, but so does another mid
        s_key < .5 & s_imp >= .8          ~ "contradict",
        s_key < .5                        ~ "weak",
        .default = "middling"))
}
