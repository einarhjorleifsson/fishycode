# Plan 021 §2.2's table, rebuilt from the crosswalk, by year: which route reaches each ASTD MMSI, and what it carries.
# Side: preprocessing (vessels), check. See plan 021 §7.
#
# Input:  curated/vessel/vessel_ais_link.parquet (curate/vessel_ais_link.R), staging/astd/identity.parquet
# Output: curated/check/vessel_ais_link_routes.parquet - one row per year, route and flag: MMSIs, pings, hours, hours
#         in the box, and how many of the MMSIs are held out or have a vid
#
# The routes are §2.2's, in its order; an MMSI-year takes the first that reaches it. §2.2 counted MMSIs over all years
# from a one-off query (2026-10-15); this counts MMSI-years from the product. A year cut at a handover takes the first
# route of its segments. Route 0 (a reviewed link) and route 8
# (held out, no register reaches it) are new. The flag is the MID's. Hours are ASTD's `sec_nextpoint` capped at 1 h,
# and the box is plan 017's, 35 °W-0°, 58-71 °N (sources/astd/identity.R).

library(duckdb)
library(DBI)

con <- dbConnect(duckdb())
link <- fd_curated("vessel", "vessel_ais_link.parquet")
astd <- fd_staging("astd", "identity.parquet")

routes <- dbGetQuery(con, sprintf("
  WITH y AS (
    SELECT mmsi, year, sum(pings) AS pings, sum(hours) AS hours, sum(hours_box) AS hours_box
    FROM read_parquet('%s') GROUP BY mmsi, year),
  l AS (
    SELECT feed_id AS mmsi, coalesce(t1, TIMESTAMP '1900-01-01') AS s1, coalesce(t2, TIMESTAMP '2101-01-01') AS s2,
           vid, vid_reason,
           CASE WHEN link = 'override' THEN '0 reviewed (overrides/)'
                WHEN register IN ('isl', 'skb') OR vid_reason IN ('isl_gap', 'isl_unregistered') THEN '1 Icelandic lists'
                WHEN vid_reason = 'invalid_mmsi' THEN '9 invalid MMSI'
                WHEN register LIKE '%%eu%%' OR starts_with(hull, 'eu_') THEN '2 EU register (by MMSI)'
                WHEN register LIKE '%%fro%%' OR starts_with(hull, 'fro_') THEN '3 Faroese register (by MMSI)'
                WHEN imo_register THEN '4 IMO in a register'
                WHEN register LIKE '%%gfw%%' THEN '5 GFW only'
                WHEN link = 'feed_imo' THEN '6 the feed''s own IMO only'
                WHEN link = 'mmsi' THEN '7 nothing but the broadcast'
                WHEN vid_reason = 'held_out' THEN '8 held out'
           END AS route
    FROM read_parquet('%s') WHERE feed = 'mmsi'),
  my AS (
    SELECT y.mmsi, y.year, any_value(y.pings) AS pings, any_value(y.hours) AS hours, any_value(y.hours_box) AS hours_box,
           min(l.route) AS route, bool_or(l.vid_reason = 'held_out') AS held_out, bool_or(l.vid IS NOT NULL) AS has_vid
    FROM y JOIN l ON l.mmsi = y.mmsi
     AND l.s1 < make_timestamp(y.year::INT + 1, 1, 1, 0, 0, 0) AND l.s2 > make_timestamp(y.year::INT, 1, 1, 0, 0, 0)
    GROUP BY y.mmsi, y.year)
  SELECT year, route,
         CASE WHEN route = '9 invalid MMSI' THEN 'invalid'
              WHEN left(mmsi, 3) = '251' THEN 'ISL' WHEN left(mmsi, 3) = '231' THEN 'FRO'
              WHEN left(mmsi, 3) IN ('257', '258', '259') THEN 'NOR' WHEN left(mmsi, 3) = '273' THEN 'RUS'
              WHEN left(mmsi, 3) = '331' THEN 'GRL' WHEN left(mmsi, 1) = '2' THEN 'other Europe'
              ELSE 'rest of world' END AS flag,
         count(*) AS mmsis, sum(pings) AS pings, sum(hours) AS hours, sum(hours_box) AS hours_box,
         count(*) FILTER (WHERE held_out) AS mmsis_held_out, count(*) FILTER (WHERE has_vid) AS mmsis_with_vid
  FROM my GROUP BY ALL ORDER BY year, route, flag", astd, link))
dbDisconnect(con, shutdown = TRUE)

stopifnot(!anyNA(routes$route))
routes$year <- as.integer(routes$year)
for (k in c("mmsis", "mmsis_held_out", "mmsis_with_vid")) routes[[k]] <- as.integer(routes[[k]])

tot <- aggregate(cbind(pings, hours, hours_box) ~ route, routes, sum)
tot$pct_pings <- round(100 * tot$pings / sum(tot$pings), 1)
tot$pct_box_hours <- round(100 * tot$hours_box / sum(tot$hours_box), 1)
print(tot)

write_curated(routes, fd_curated("check", "vessel_ais_link_routes.parquet"),
              inputs = c(vessel_ais_link = link, astd_identity = astd))
