# voyage_sharing.R — what is left of the shared-voyage problem after the stays? (plan 011 §6, Phase 4)
#
# Input:  curated/link/trip_voyage.parquet, curated/ais/trip.parquet, curated/logbook/trip.parquet   (now)
#         $FISHYDATA/archive/pre-phase4_2026-10-01/{trip,trip_voyage}.parquet                         (before)
# Output: curated/check/voyage_sharing.parquet   one row per (version, schema, year)
#
# `shared`: a logbook trip whose AIS voyage is also the best-overlap voyage of another logbook trip of the
# vessel. That is the failure the stays are for (one voyage over many day trips). Measured before (the
# archived pre-Phase-4 files) and after (the current ones), with the same definition, from 2008 on.
# Logbook is the yardstick only: the voyages are built from AIS alone.
#   linked        share of logbook trips with any voyage
#   shared        share of logbook trips whose voyage carries more than one logbook trip
#   arr_match     share of linked trips whose voyage arrival harbour (hid2_ais) is the logbook landing pid (pid2)
# plus, from the voyage tables, how many voyages last more than 3 and 7 days (one row per version, year).

library(dplyr)

arch <- file.path(fishydata_root(), "archive", "pre-phase4_2026-10-01")
con  <- DBI::dbConnect(duckdb::duckdb())
now  <- list(tv = fd_curated("link", "trip_voyage.parquet"), v = fd_curated("ais", "trip.parquet"))
bef  <- list(tv = file.path(arch, "trip_voyage.parquet"),    v = file.path(arch, "trip.parquet"))
lb   <- fd_curated("logbook", "trip.parquet")

one <- function(f, version) DBI::dbGetQuery(con, glue::glue("
  WITH l AS (SELECT \".tid\" AS tid, vid, schema, year(T1) AS year, pid2 FROM read_parquet('{lb}') WHERE vid IS NOT NULL AND year(T1) >= 2008),
  k AS (SELECT \".tid\" AS tid, vid, year AS vyear, trip, hid2_ais FROM read_parquet('{f$tv}')),
  j AS (SELECT l.*, k.vyear, k.trip, k.hid2_ais, count(k.tid) OVER (PARTITION BY l.vid, k.vyear, k.trip) AS n_on_voyage
        FROM l LEFT JOIN k USING (tid, vid))
  SELECT '{version}' AS version, schema, year, count(*) AS n_trips,
         avg((trip IS NOT NULL)::INT) AS linked,
         avg(CASE WHEN trip IS NOT NULL THEN (n_on_voyage > 1)::INT END) AS shared,
         avg(CASE WHEN trip IS NOT NULL AND pid2 IS NOT NULL THEN (hid2_ais = pid2)::INT END) AS arr_match
  FROM j GROUP BY ALL")) |> as_tibble()

dur <- function(f, version) DBI::dbGetQuery(con, glue::glue("
  SELECT '{version}' AS version, year, count(*) AS n_voyages,
         avg((epoch(T2 - T1) > 3 * 86400)::INT) AS gt3d, avg((epoch(T2 - T1) > 7 * 86400)::INT) AS gt7d,
         median(epoch(T2 - T1) / 3600.0) AS med_h
  FROM read_parquet('{f$v}') WHERE year >= 2008 GROUP BY ALL")) |> as_tibble()

out  <- bind_rows(one(bef, "before"), one(now, "after"))
dout <- bind_rows(dur(bef, "before"), dur(now, "after"))

res <- out |> left_join(dout |> select(version, year, n_voyages, gt3d, gt7d, med_h), by = c("version", "year"),
                        relationship = "many-to-many")
res |> write_curated(fd_curated("check", "voyage_sharing.parquet"), inputs = unlist(c(now, bef, lb)))

pool <- out |> filter(year <= 2025) |> group_by(version, schema) |>
  summarise(n = sum(n_trips), linked = weighted.mean(linked, n_trips), shared = weighted.mean(shared, n_trips, na.rm = TRUE),
            arr_match = weighted.mean(arr_match, n_trips, na.rm = TRUE), .groups = "drop")
print(pool)
print(dout |> filter(year <= 2025) |> group_by(version) |>
  summarise(voyages = sum(n_voyages), gt3d = weighted.mean(gt3d, n_voyages), gt7d = weighted.mean(gt7d, n_voyages), .groups = "drop"))
