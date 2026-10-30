# trip_landing.R — every landing of a logbook trip: the declarations' match, and the further landings the track joins.
# Side: flow (it reads the AIS track). See plan 014.
#
# Input:  curated/logbook/{lid_map,trip,catch_by_species_trip}.parquet,
#         curated/landing/{landings,catch,catch_detail}.parquet, curated/link/trip_voyage.parquet,
#         curated/ais/{voyage,port_call}.parquet, curated/ais/trail (fishing per voyage)
# Output: curated/logbook/trip_landing.parquet   one row per logbook trip and landing: .tid schema .lid schema_land
#                                                basis n_trips disposition disposition_basis (the landing's)
#         curated/logbook/trip_disposition.parquet  one row per logbook trip (duplicates left out): .tid schema vid
#                                                n_landings kg_landed kg_<disposition> (six) disposition
#                                                disposition_basis disposition_from
#         curated/check/trip_landing.parquet     every landing in one outcome, with its kg, its disposition and the
#                                                claimed landing it was judged against
#
# Plan 027 §5, as plan 054 ask b answered it (decision 247 b). lid_map gives a trip one landing. A landing lid_map
# leaves unclaimed (U) is judged against the vessel's latest claimed landing (C) within 7 days before it, at any port:
#   export  U is at 159 (exported in a container), and C is at U's origin port on U's day or the day before (decision
#           208: the 159 landing joins through trip_landing);
#   track   no fishing between C's trip and U: no AIS voyage with fishing fixes starting after the end of C's trip's
#           voyage, and no logbook trip of the vessel starting after C's day, while the track sees the vessel (a
#           voyage or a port call in the window). Joined whatever the logbook's weight (ask c);
#   weight  the track does not see the vessel: joined if C's trips' logged kg is nearer C + U than C alone.
# Otherwise U stays its own: `fished_between`, `weight_not_nearer`, or `no_claimed_landing` within 7 days. A joined U
# joins every trip C ends. lid_map is not changed. The voyage rule for lid_map's own misses is a TODO of its own (ask b d).
#
# The disposition stops at the trip (decision 208 f). A landing's is its catch rows' (curate/landing.R): one value
# where its kilograms have one, `mixed` where they have several; its basis `recorded` only where every row's is. A
# trip's is its landings' kilograms by disposition, all of them, the further ones included; where it has no landing,
# the skipper's own 159 (`export_or_abroad`, basis recorded, from the logbook), the only witness for afli's trips of
# 1973-1991; else none.
#
# In DuckDB, lazily; the trail is read for four columns, one count per voyage.

con <- duckdbfs::cached_connection()
ex <- function(sql) invisible(DBI::dbExecute(con, sql))
pq <- function(...) sprintf("read_parquet('%s')", fd_curated(...))
WINDOW_D <- 7
EXPORT <- 159L

ex(sprintf("CREATE OR REPLACE TEMP VIEW lm AS SELECT \".tid\", schema, \".lid\", schema_land, n_trips FROM %s",
           pq("logbook", "lid_map.parquet")))
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE land AS
  SELECT l.".lid", l.schema AS schema_land, l.vid, l.date, l.hid, c.kg, c.hid_origin
  FROM %s l
  LEFT JOIN (SELECT ".lid", schema, sum(catch) AS kg, min(hid_origin) AS hid_origin FROM %s GROUP BY ALL) c
    ON c.".lid" = l.".lid" AND c.schema = l.schema]", pq("landing", "landings.parquet"), pq("landing", "catch.parquet")))
ex(r"[CREATE OR REPLACE TEMP TABLE claimed AS
  SELECT DISTINCT l.* FROM land l JOIN lm ON lm.".lid" = l.".lid" AND lm.schema_land = l.schema_land]")
ex(r"[CREATE OR REPLACE TEMP TABLE unclaimed AS
  SELECT l.* FROM land l ANTI JOIN lm ON lm.".lid" = l.".lid" AND lm.schema_land = l.schema_land]")

# The candidate C for each U: the latest claimed landing within the window, the lowest id on a tie; for U at 159 the
# claimed landing at its origin port on its day or the day before.
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE cand AS
  SELECT * FROM (
    SELECT u.".lid" AS lid_u, u.schema_land AS land_u, u.vid, u.date AS date_u, u.hid AS hid_u, u.kg AS kg_u,
           c.".lid" AS lid_c, c.schema_land AS land_c, c.date AS date_c, c.hid AS hid_c, c.kg AS kg_c,
           (u.hid = %d AND c.hid = u.hid_origin AND c.date >= u.date - 1) AS is_export,
           row_number() OVER (PARTITION BY u.".lid", u.schema_land
                              ORDER BY (u.hid = %d AND c.hid = u.hid_origin AND c.date >= u.date - 1) DESC,
                                       c.date DESC, c.".lid") AS k
    FROM unclaimed u JOIN claimed c ON c.vid = u.vid AND c.date BETWEEN u.date - %d AND u.date
      AND NOT (c.date = u.date AND c.hid IS NOT DISTINCT FROM u.hid))
  WHERE k = 1]", EXPORT, EXPORT, WINDOW_D))

# C's trips, the end of their voyage on the track, and their logged kg.
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE ctrip AS
  SELECT DISTINCT cand.lid_u, cand.land_u, lm.".tid", lm.schema, lm.n_trips FROM cand
  JOIN lm ON lm.".lid" = cand.lid_c AND lm.schema_land = cand.land_c]"))
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE cend AS
  SELECT t.lid_u, t.land_u, max(v.T2_ais) AS t_end, sum(w.kg) AS kg_logged
  FROM ctrip t
  LEFT JOIN (SELECT ".tid", schema, max(T2_ais) AS T2_ais FROM %s GROUP BY ALL) v
    ON v.".tid" = t.".tid" AND v.schema = t.schema
  LEFT JOIN (SELECT ".tid", schema, sum(catch_logbook) AS kg FROM %s GROUP BY ALL) w
    ON w.".tid" = t.".tid" AND w.schema = t.schema
  GROUP BY ALL]", pq("link", "trip_voyage.parquet"), pq("logbook", "catch_by_species_trip.parquet")))

# Fishing between: a voyage with fishing fixes that starts after C's trip's voyage ends and before U's day is out;
# a logbook trip of the vessel, not one C ends, starting after C's day; the track's witness, any voyage or port call
# of the vessel in the window.
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE vfish AS
  SELECT vid, year, voyage_id, count(*) FILTER (WHERE fishing OR fishing_flow) AS n_fishing
  FROM read_parquet('%s/**/*.parquet', hive_partitioning = true) GROUP BY ALL]", fd_curated("ais", "trail")))
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE judged AS
  SELECT c.*, e.t_end, e.kg_logged,
    EXISTS (SELECT 1 FROM %s v JOIN vfish f USING (vid, year, voyage_id)
            WHERE v.vid = c.vid AND f.n_fishing > 0 AND v.T1 > e.t_end AND v.T1 < c.date_u + INTERVAL 1 DAY) AS ais_fished,
    EXISTS (SELECT 1 FROM %s t WHERE t.vid = c.vid AND t.twin IS DISTINCT FROM 'duplicate'
            AND t.T1 >= c.date_c + INTERVAL 1 DAY AND t.T1 < c.date_u + INTERVAL 1 DAY
            AND NOT EXISTS (SELECT 1 FROM ctrip x WHERE x.lid_u = c.lid_u AND x.land_u = c.land_u
                            AND x.".tid" = t.".tid" AND x.schema = t.schema)) AS logbook_fished,
    e.t_end IS NOT NULL AND (
      EXISTS (SELECT 1 FROM %s v WHERE v.vid = c.vid AND v.T2 > e.t_end AND v.T1 < c.date_u + INTERVAL 1 DAY) OR
      EXISTS (SELECT 1 FROM %s p WHERE p.vid = c.vid AND p.T_out > e.t_end AND p.T_in < c.date_u + INTERVAL 1 DAY))
      AS witness
  FROM cand c JOIN cend e ON e.lid_u = c.lid_u AND e.land_u = c.land_u]",
  pq("ais", "voyage.parquet"), pq("logbook", "trip.parquet"), pq("ais", "voyage.parquet"), pq("ais", "port_call.parquet")))
ex(r"[CREATE OR REPLACE TEMP TABLE outcome AS
  SELECT u.".lid", u.schema_land, u.vid, u.date, u.hid, u.kg, j.lid_c, j.land_c, j.date_c, j.kg_c, j.kg_logged,
    CASE WHEN j.lid_u IS NULL THEN 'no_claimed_landing'
         WHEN j.is_export THEN 'export'
         WHEN j.ais_fished OR j.logbook_fished THEN 'fished_between'
         WHEN j.witness THEN 'track'
         -- a landed weight of 0 or less (a withdrawn copy, an export's negative surcharge row) is taken as 1 g
         WHEN j.kg_logged > 0 AND abs(ln(j.kg_logged / greatest(coalesce(j.kg_c, 0) + coalesce(u.kg, 0), 1e-3)))
                                < abs(ln(j.kg_logged / greatest(coalesce(j.kg_c, 0), 1e-3))) THEN 'weight'
         ELSE 'weight_not_nearer' END AS outcome
  FROM unclaimed u LEFT JOIN judged j ON j.lid_u = u.".lid" AND j.land_u = u.schema_land
  UNION ALL
  SELECT ".lid", schema_land, vid, date, hid, kg, NULL, NULL, NULL, NULL, NULL, 'lid_map' FROM claimed]")

ex(r"[CREATE OR REPLACE TEMP VIEW trip_landing AS
  SELECT ".tid", schema, ".lid", schema_land, 'lid_map' AS basis, n_trips FROM lm
  UNION ALL
  SELECT t.".tid", t.schema, o.".lid", o.schema_land, o.outcome AS basis, t.n_trips
  FROM outcome o JOIN ctrip t ON t.lid_u = o.".lid" AND t.land_u = o.schema_land
  WHERE o.outcome IN ('export', 'track', 'weight')]")

# The disposition: the landing's, then the trip's ---------------------------------------------------------------------
DISP <- c("home", "export", "abroad", "export_or_abroad", "transfer", "unknown")
one_of <- "CASE WHEN count(*) FILTER (WHERE kg > 0) = 1 THEN any_value(disposition) FILTER (WHERE kg > 0)
                WHEN count(*) FILTER (WHERE kg > 0) > 1 OR count(*) > 1 THEN 'mixed' ELSE any_value(disposition) END"
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE ldisp AS
  SELECT ".lid", schema AS schema_land, disposition, min(disposition_basis) AS basis, sum(catch) AS kg
  FROM %s GROUP BY ALL]", pq("landing", "catch_detail.parquet")))
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE land_disp AS
  SELECT ".lid", schema_land, %s AS disposition, min(basis) AS disposition_basis FROM ldisp GROUP BY ALL]", one_of))
ex(sprintf(r"[CREATE OR REPLACE TEMP TABLE trip_disp AS
  WITH k AS (SELECT DISTINCT ".tid", schema, ".lid", schema_land FROM trip_landing),
  d AS (SELECT k.".tid", k.schema, l.disposition, sum(l.kg) AS kg, min(l.basis) AS basis
        FROM k JOIN ldisp l USING (".lid", schema_land) GROUP BY ALL),
  w AS (SELECT ".tid", schema, sum(kg) AS kg_landed, %s, %s AS disposition, min(basis) AS disposition_basis
        FROM d GROUP BY ALL),
  n AS (SELECT ".tid", schema, count(*) AS n_landings FROM k GROUP BY ALL),
  t AS (SELECT ".tid", schema, any_value(vid) AS vid, bool_or(hid2 = %d) AS hid2_export FROM %s
        WHERE twin IS DISTINCT FROM 'duplicate' GROUP BY ALL)
  SELECT t.".tid", t.schema, t.vid, coalesce(n.n_landings, 0) AS n_landings, w.* EXCLUDE (".tid", schema, disposition,
         disposition_basis),
         CASE WHEN w.disposition IS NOT NULL THEN w.disposition WHEN t.hid2_export THEN 'export_or_abroad' END
           AS disposition,
         CASE WHEN w.disposition IS NOT NULL THEN w.disposition_basis WHEN t.hid2_export THEN 'recorded' ELSE 'none' END
           AS disposition_basis,
         CASE WHEN w.disposition IS NOT NULL THEN 'landings' WHEN t.hid2_export THEN 'logbook' END AS disposition_from
  FROM t LEFT JOIN n USING (".tid", schema) LEFT JOIN w USING (".tid", schema)]",
  paste(sprintf("sum(kg) FILTER (WHERE disposition = '%s') AS kg_%s", DISP, DISP), collapse = ", "), one_of,
  EXPORT, pq("logbook", "trip.parquet")))
print(DBI::dbGetQuery(con, "SELECT disposition_from, disposition, disposition_basis, count(*) AS n,
                                   round(sum(kg_landed) / 1e6, 1) AS kt FROM trip_disp GROUP BY ALL ORDER BY ALL"))

# Account: every landing in one outcome, kg in = kg out --------------------------------------------------------------
acct <- DBI::dbGetQuery(con, "SELECT outcome, count(*) AS n, round(sum(kg) / 1e6, 1) AS kt FROM outcome GROUP BY 1 ORDER BY 1")
print(acct)
tot <- DBI::dbGetQuery(con, "SELECT (SELECT count(*) FROM land) AS n_land, (SELECT count(*) FROM outcome) AS n_out,
                              (SELECT sum(kg) FROM land) AS kg_land, (SELECT sum(kg) FROM outcome) AS kg_out")
stopifnot(tot$n_land == tot$n_out, abs(tot$kg_land - tot$kg_out) < 1)

inputs <- c(fd_curated("logbook", "lid_map.parquet"), fd_curated("landing", "landings.parquet"),
            fd_curated("landing", "catch.parquet"), fd_curated("link", "trip_voyage.parquet"),
            fd_curated("logbook", "catch_by_species_trip.parquet"), fd_curated("ais", "voyage.parquet"),
            fd_curated("ais", "port_call.parquet"), fd_curated("logbook", "trip.parquet"),
            fd_curated("landing", "catch_detail.parquet"))
write_curated_sql(con, "SELECT tl.*, d.disposition, d.disposition_basis FROM trip_landing tl
                        LEFT JOIN land_disp d USING (\".lid\", schema_land)",
                  fd_curated("logbook", "trip_landing.parquet"), inputs = inputs, order_by = "schema, \".tid\", \".lid\"")
write_curated_sql(con, "SELECT * FROM trip_disp", fd_curated("logbook", "trip_disposition.parquet"), inputs = inputs,
                  order_by = "schema, \".tid\"")
write_curated_sql(con, "SELECT o.*, d.disposition, d.disposition_basis FROM outcome o
                        LEFT JOIN land_disp d USING (\".lid\", schema_land)",
                  fd_curated("check", "trip_landing.parquet"), inputs = inputs, order_by = "schema_land, \".lid\"")
