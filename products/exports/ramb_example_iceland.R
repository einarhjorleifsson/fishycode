# ramb_example_iceland.R — a census of the north-west of Iceland in the third quarter of 2017, for ramb's and ogis's
# examples, in the layout of ramb's example data: the national fleet's AIS, logbooks and landings in full, and every
# other ship in the area as a national AIS provider would deliver it. Anonymised. A candidate the maintainer decides on:
# nothing here is published or added to ramb (decision 329, TODO 202).
#
# Input:  staging/ais/ping_union/          the merged feeds before any flag (preprocessing, curate/ais_ping_union.R)
#         staging/ais/{astd,astdB}/         PAME's feeds as staged, for the ships no register vessel matches
#         curated/logbook/{trip,station,fishing_sample,gear,lid_map}.parquet, products/v0/logbook/catch.parquet
#           (the user tables' whole weight, catch_round), curated/reference/gear.parquet (the gear names)
#         curated/landing/{landings,catch}.parquet, curated/reference/species.parquet
#         curated/vessel/{vessel,vessel_year}.parquet, curated/vessel/register/{vessel_measurement_hist,
#           vessel_identification_hist}.parquet
#         staging/aux/ports.fgb             the harbour polygons the flow tags pings with (curate/ais_ping_tag.R)
#         staging/aux/{maritime_identification_digits,country_codes_ISO3166}.parquet  a foreign ship's flag from its MMSI
#         raw/external/is50v/strandlina_flakar.json  the IS 50V coastline (natt.is, open data)
#         curated/ais/voyage.parquet        to fill out the voyages that cross the period's edges (selection only)
#         and, for the summary's counts only, never shipped: staging/ais/ping_tagged, staging/ais/ping_whacky,
#         curated/ais/trail, curated/ais/port_call.parquet, curated/link/trip_reconciled.parquet
# Output: $FISHYDATA/exports/ramb_example_iceland/  iceland_<yyyy-mm>.parquet (the pings, one file a month of the
#                                                   period) and iceland_*.parquet (zstd 19, each stamped with its
#                                                   dictionary entry as ramb's data-raw/data_dict.R does),
#                                                   data-dict.yaml, summary.yml; its README.md (the report) is written
#                                                   by hand and left in place
#         $FISHYDATA/exports/ramb_example_iceland_key.parquet  the ids' key to the store; never goes with the folder
#
# Run from the repository root:  lockf -k /tmp/fishycode-heavy.lock Rscript products/exports/ramb_example_iceland.R
#
# The choices (decision 329; the maintainer's requirements and framing, 2026-11-18, Claude's measurements):
# - The year with the highest ping density in the trail, measured: 2017, 275 pings a vessel-day (220 at sea).
# - Two tiers, as a national institute holds its data (the maintainer: detailed data on "our own national NW fleet",
#   and from the national AIS provider all the other ships in its waters, with less detail; some land in our ports):
#   - national: every vessel registered in the north-west's districts (NATIONAL) that was active in the period
#     (a ping, a haul or a landing, anywhere). Everything it did in its window: the period widened until every voyage
#     and logbook trip overlapping it is whole, at most CAP_D days beyond it, then MARGIN_H more each side.
#   - other: every other register vessel with a ping in the AREA in the period, or a landing at a port in it. Its pings
#     inside the area and the period only, cut at both edges; its landings in the area's ports; no logbook.
#   - unmatched: every MMSI of PAME's feeds that no register vessel matches, with a ping in the area in the period:
#     foreign ships, Icelandic MMSIs the union never linked, aids to navigation and malformed numbers alike, as a
#     provider delivers them. Its pings inside the area and the period, with what PAME gives of it (category,
#     gross-tonnage class, class B length) and what its MMSI says (the kind of station, the flag): the MMSI itself goes.
# - The period, Q3: of the summer quarters, the one strongest in the gears rare in public examples (pots, dredges, sea
#   angling) and holding ASTD's missing July 2017 as a visible feed outage; every gear asked for has 49 trips or more,
#   sea angling 1,217 landings (decision 329). The area, the Westfjords, Breiðafjörður and Snæfellsnes's north coast.
# - Pings from every AIS and VMS feed, before any flag (copies, impossible positions, ties, port stays and gaps as
#   they are), less the GPS loggers' (provider gps): fishydata puts their positions back on the cleaned AIS track
#   (decision 196), so they are the flow's output, not a feed. A class B report's "not available" codes (heading 511,
#   course 360, speed 102.3) are empty, as the union makes them.
# - The logbook's catch as a total only: a haul's logged catch summed over species, whole weight (catch_round). The
#   landings by species (public in Iceland; the maintainer, 2026-11-18), with the species' names beside them.
# - Anonymised: every vessel and ship becomes 1-n in random order; trips, hauls and landings are numbered anew; MMSI,
#   IMO, call sign, name, registration and Fiskistofa's harbour code are left out. Positions, times, ports and the
#   national vessels' power, length, tonnage and home district are kept as recorded: a track can be matched to public
#   AIS whatever is done to the ids (README.md).

source("R/paths.R")

YEAR <- 2017L
P1 <- as.POSIXct("2017-07-01", tz = "UTC")
P2 <- as.POSIXct("2017-10-01", tz = "UTC") # exclusive
AREA <- c(xmin = -26.0, xmax = -20.5, ymin = 64.8, ymax = 67.2) # lon in [xmin, xmax), lat in [ymin, ymax)
NATIONAL <- c("ÍS", "ST", "BA", "SH", "DA") # home districts: Ísafjarðar-, Stranda-, Barðastrandar-, Snæfellsnes-, Dalasýsla
MARGIN_H <- 12
CAP_D <- 31
SEED <- 20170701
NAME <- "ramb_example_iceland"

out <- fd_path("exports", NAME)
keyfile <- fd_path("exports", paste0(NAME, "_key.parquet"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# README.md, the report, is written by hand from summary.yml and kept
unlink(list.files(out, pattern = "[.]parquet$|^data-dict[.]yaml$|^summary[.]yml$", full.names = TRUE))
spill <- file.path(tempdir(), "duckdb_spill")
dir.create(spill, showWarnings = FALSE)

con <- DBI::dbConnect(duckdb::duckdb())
run <- function(...) invisible(DBI::dbExecute(con, sprintf(...)))
get <- function(...) DBI::dbGetQuery(con, sprintf(...))
run("SET threads = 4; SET memory_limit = '5GB'; SET temp_directory = '%s'", spill)
run("INSTALL spatial; LOAD spatial")
pq <- function(...) sprintf("read_parquet('%s')", fd_path(...))
pqs <- function(paths) sprintf("read_parquet([%s], hive_partitioning = true)", paste(sprintf("'%s'", paths), collapse = ", "))
fmt_t <- function(x) format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC")
inarea <- function(x, y) {
  sprintf("(%1$s >= %3$f AND %1$s < %4$f AND %2$s >= %5$f AND %2$s < %6$f)", x, y, AREA[["xmin"]], AREA[["xmax"]],
          AREA[["ymin"]], AREA[["ymax"]])
}
in_p <- function(t = "time") sprintf("(%1$s >= TIMESTAMP '%2$s' AND %1$s < TIMESTAMP '%3$s')", t, fmt_t(P1), fmt_t(P2))
years <- (YEAR - 1L):(YEAR + 1L)
union_src <- pqs(fd_path("staging", "ais", "ping_union", sprintf("year=%d", years), "*.parquet"))
MID <- format(P1 + (P2 - P1) / 2, "%Y-%m-%d")
months <- format(seq(as.Date(P1), as.Date(P2) - 1, by = "month"), "%Y-%m")

# The records ----------------------------------------------------------------------------------------------------------
run("CREATE TEMP TABLE trip AS SELECT * FROM %s", pq("curated", "logbook", "trip.parquet"))
# a haul's time: its first logged time, else its date; its end: its last logged time, else the end of its day
run("CREATE TEMP TABLE haul AS
     SELECT s.*, t.vid, f.* EXCLUDE (\".tid\", \".sid\", schema, eytt_deleted, gid, gear, target, target2, gear_code),
       g.gid, g.gid_landing, g.gid_used, g.gid_basis, g.gear, g.gear_code,
       coalesce(f.t1, f.t2, f.t3, f.t4, s.date) AS h1,
       coalesce(f.t4, f.t3, f.t2, f.t1, s.date + INTERVAL 1 DAY) AS h2
     FROM %s s JOIN trip t USING (\".tid\", schema)
     LEFT JOIN %s f USING (\".sid\", schema) LEFT JOIN %s g USING (\".sid\", schema)",
    pq("curated", "logbook", "station.parquet"), pq("curated", "logbook", "fishing_sample.parquet"),
    pq("curated", "logbook", "gear.parquet"))
stopifnot(get("SELECT count(*) n FROM (SELECT \".sid\", schema FROM haul GROUP BY ALL HAVING count(*) > 1)")$n == 0)
# a trip's span: its declared dates (the return date's whole day) and its hauls' times
run("CREATE TEMP TABLE span AS
     SELECT t.\".tid\", t.schema, t.vid,
       least(t.T1, min(h.h1)) AS s1, greatest(t.T2 + INTERVAL 1 DAY, max(h.h2)) AS s2
     FROM trip t LEFT JOIN haul h USING (\".tid\", schema) GROUP BY t.\".tid\", t.schema, t.vid, t.T1, t.T2")
run("CREATE TEMP TABLE landing AS SELECT * FROM %s", pq("curated", "landing", "landings.parquet"))
run("CREATE TEMP TABLE voyage AS SELECT * FROM %s WHERE year BETWEEN %d AND %d",
    pq("curated", "ais", "voyage.parquet"), YEAR - 1L, YEAR + 1L)
dated <- function(f) sprintf("(SELECT * FROM %s WHERE valid_from <= DATE '%s' AND (valid_to IS NULL OR valid_to > DATE '%s')
                              QUALIFY row_number() OVER (PARTITION BY registration_no ORDER BY valid_from DESC) = 1)",
                             pq("curated", "vessel", "register", f), MID, MID)
run("CREATE TEMP TABLE dist AS SELECT registration_no AS vid, region_acronym AS district FROM %s",
    dated("vessel_identification_hist.parquet"))

# The harbours: the flow's polygons, one row per polygon
ports <- sf::read_sf(fd_staging("aux", "ports.fgb"))
stopifnot(identical(sf::st_crs(ports)$epsg, 4326L))
ports$geometry_wkb <- blob::as_blob(unclass(sf::st_as_binary(sf::st_geometry(ports))))
duckdb::duckdb_register(con, "ports_r", sf::st_drop_geometry(ports))
run("CREATE TEMP TABLE port AS SELECT * EXCLUDE (geometry_wkb), ST_GeomFromWKB(geometry_wkb) AS geom FROM ports_r")
duckdb::duckdb_unregister(con, "ports_r")
run("CREATE TEMP TABLE port_xy AS SELECT pid, ST_X(ST_Centroid(ST_Union_Agg(geom))) AS lon,
       ST_Y(ST_Centroid(ST_Union_Agg(geom))) AS lat FROM port GROUP BY pid")
run("CREATE TEMP TABLE area_port AS SELECT pid FROM port_xy WHERE %s", inarea("lon", "lat"))

# PAME's feeds as staged, in the area and the period, under the union's names
run("CREATE TEMP TABLE pame AS
     SELECT CAST(CAST(mmsi AS BIGINT) AS VARCHAR) AS mmsi, date_time_utc AS time, longitude AS lon, latitude AS lat,
            CAST(NULL AS DOUBLE) AS speed, CAST(NULL AS DOUBLE) AS heading, CAST(NULL AS DOUBLE) AS cog, 'astd' AS provider,
            astd_cat AS category, sizegroup_gt AS gt_class, CAST(NULL AS DOUBLE) AS length
     FROM %s WHERE %s AND %s
     UNION ALL
     SELECT CAST(CAST(mmsi AS BIGINT) AS VARCHAR), date_time_utc, lon, lat,
            CASE WHEN speed < 102.3 THEN speed END, CASE WHEN true_heading < 360 THEN true_heading END,
            CASE WHEN cog < 360 THEN cog END, 'astdB', NULL, NULL, CASE WHEN length > 0 THEN length END
     FROM %s WHERE %s AND %s",
    pqs(fd_path("staging", "ais", "astd", sprintf("year=%d", YEAR), "*", "*.parquet")), in_p("date_time_utc"),
    inarea("longitude", "latitude"),
    pqs(fd_path("staging", "ais", "astdB", sprintf("year=%d", YEAR), "*", "*.parquet")), in_p("date_time_utc"),
    inarea("lon", "lat"))

# The census -----------------------------------------------------------------------------------------------------------
run("CREATE TEMP TABLE u_p AS SELECT vid, mmsi, lon, lat FROM %s WHERE provider <> 'gps' AND %s", union_src, in_p())
run("CREATE TEMP TABLE active AS SELECT DISTINCT vid FROM (
       SELECT vid FROM u_p
       UNION ALL SELECT vid FROM haul WHERE h1 < '%2$s' AND h2 > '%1$s'
       UNION ALL SELECT vid FROM span WHERE s1 < '%2$s' AND s2 > '%1$s'
       UNION ALL SELECT vid FROM landing WHERE date >= DATE '%3$s' AND date < DATE '%4$s') WHERE vid IS NOT NULL",
    fmt_t(P1), fmt_t(P2), format(P1), format(P2))
run("CREATE TEMP TABLE national AS SELECT a.vid FROM active a JOIN dist d USING (vid) WHERE d.district IN (%s)",
    paste(sprintf("'%s'", NATIONAL), collapse = ", "))
run("CREATE TEMP TABLE other AS SELECT DISTINCT vid FROM (
       SELECT vid FROM u_p WHERE %s
       UNION ALL SELECT vid FROM landing WHERE date >= DATE '%s' AND date < DATE '%s' AND pid IN (SELECT pid FROM area_port))
     WHERE vid IS NOT NULL AND vid NOT IN (SELECT vid FROM national)", inarea("lon", "lat"), format(P1), format(P2))
# a ship of PAME's that no register vessel matches: its MMSI never on a vessel's ping in the union that year
run("CREATE TEMP TABLE known AS SELECT DISTINCT mmsi FROM %s WHERE mmsi IS NOT NULL",
    pqs(fd_path("staging", "ais", "ping_union", sprintf("year=%d", YEAR), "*.parquet")))
run("CREATE TEMP TABLE foreign_ship AS SELECT DISTINCT mmsi FROM pame WHERE mmsi IS NOT NULL AND mmsi NOT IN (SELECT mmsi FROM known)")
run("CREATE TEMP TABLE census AS
     SELECT concat('v', vid) AS vkey, vid AS vid_store, NULL::VARCHAR AS mmsi_store, 'national' AS tier FROM national
     UNION ALL SELECT concat('v', vid), vid, NULL, 'other' FROM other
     UNION ALL SELECT concat('m', mmsi), NULL, mmsi, 'unmatched' FROM foreign_ship")
print(get("SELECT tier, count(*) n FROM census GROUP BY 1 ORDER BY 1"))

# The national fleet's windows: the period, widened until every voyage and trip overlapping it is whole -----------------
run("CREATE TEMP TABLE win AS SELECT vid, TIMESTAMP '%s' AS w1, TIMESTAMP '%s' AS w2 FROM national", fmt_t(P1), fmt_t(P2))
# Each pass takes in what overlaps the window so far, clamped at the cap, so the passes end.
cap1 <- P1 - CAP_D * 86400
cap2 <- P2 + CAP_D * 86400
for (i in 1:100) {
  before <- get("SELECT sum(epoch(w2 - w1)) s FROM win")$s
  run("CREATE OR REPLACE TEMP TABLE win AS
       SELECT w.vid, greatest(least(w.w1, min(x.t1)), TIMESTAMP '%s') AS w1,
              least(greatest(w.w2, max(x.t2)), TIMESTAMP '%s') AS w2
       FROM win w LEFT JOIN (
         SELECT vid, T1 AS t1, T2 AS t2 FROM voyage UNION ALL SELECT vid, s1, s2 FROM span) x
         ON x.vid = w.vid AND x.t1 < w.w2 AND x.t2 > w.w1
       GROUP BY w.vid, w.w1, w.w2", fmt_t(cap1), fmt_t(cap2))
  if (get("SELECT sum(epoch(w2 - w1)) s FROM win")$s == before) break
}
stopifnot(i < 100)
n_capped <- get("SELECT count(*) n FROM win WHERE w1 = '%s' OR w2 = '%s'", fmt_t(cap1), fmt_t(cap2))$n
run("UPDATE win SET w1 = w1 - INTERVAL %d HOUR, w2 = w2 + INTERVAL %d HOUR", MARGIN_H, MARGIN_H)
cat(sprintf("windows: %d passes, %d at the cap of %d days beyond the period\n", i, n_capped, CAP_D))

# What goes in ---------------------------------------------------------------------------------------------------------
wr <- get("SELECT strftime(min(w1), '%%Y-%%m-%%d %%H:%%M:%%S') a, strftime(max(w2), '%%Y-%%m-%%d %%H:%%M:%%S') b FROM win")
# the union's pings: the national fleet's in its windows, the other vessels' in the area and the period
run("CREATE TEMP TABLE pu AS
     SELECT u.*, 'national' AS tier FROM %1$s u JOIN win w ON u.vid = w.vid AND u.time >= w.w1 AND u.time < w.w2
       WHERE u.time >= '%2$s' AND u.time < '%3$s' AND u.provider <> 'gps'
     UNION ALL BY NAME
     SELECT u.*, 'other' AS tier FROM %1$s u SEMI JOIN other o ON u.vid = o.vid
       WHERE u.provider <> 'gps' AND %4$s AND %5$s", union_src, wr$a, wr$b, in_p("u.time"), inarea("u.lon", "u.lat"))
stopifnot(get("SELECT count(*) n FROM pu WHERE sid_gps IS NOT NULL OR pos_basis <> 'recorded'")$n == 0)
run("CREATE TEMP TABLE tsel AS SELECT DISTINCT s.\".tid\", s.schema, s.vid FROM span s JOIN win w
       ON s.vid = w.vid AND s.s1 < w.w2 AND s.s2 > w.w1")
# the trip-landing match of the declarations (preprocessing); the further links fishycode's flow makes by the track
# (curated/logbook/trip_landing.parquet) are the flow's answers, left out
run("CREATE TEMP TABLE tl AS SELECT tl.* FROM %s tl SEMI JOIN tsel USING (\".tid\", schema)",
    pq("curated", "logbook", "lid_map.parquet"))
# landings: the national fleet's in its windows and those its trips link; the other vessels' in the area's ports
run("CREATE TEMP TABLE lsel AS
     SELECT DISTINCT l.\".lid\", l.schema FROM landing l JOIN win w ON l.vid = w.vid
       AND l.date >= CAST(w.w1 AS DATE) AND l.date <= CAST(w.w2 AS DATE)
     UNION SELECT \".lid\", schema_land FROM tl
     UNION SELECT \".lid\", schema FROM landing WHERE vid IN (SELECT vid FROM other)
       AND date >= DATE '%s' AND date < DATE '%s' AND pid IN (SELECT pid FROM area_port)", format(P1), format(P2))
stopifnot(get("SELECT count(*) n FROM lsel JOIN landing USING (\".lid\", schema)
               WHERE vid NOT IN (SELECT vid_store FROM census WHERE vid_store IS NOT NULL)")$n == 0)

# The key: new ids -----------------------------------------------------------------------------------------------------
set.seed(SEED)
v <- get("SELECT vkey FROM census ORDER BY vkey")$vkey
key_v <- data.frame(vkey = v, vid = sample.int(length(v)))
duckdb::duckdb_register(con, "key_v_r", key_v)
run("CREATE TEMP TABLE key_v AS SELECT k.*, c.vid_store, c.mmsi_store, c.tier FROM key_v_r k JOIN census c USING (vkey)")
duckdb::duckdb_unregister(con, "key_v_r")
run("CREATE TEMP TABLE key_t AS
     SELECT s.\".tid\", s.schema, row_number() OVER (ORDER BY k.vid, sp.s1, s.schema, s.\".tid\")::INTEGER AS trip_id
     FROM tsel s JOIN span sp USING (\".tid\", schema) JOIN key_v k ON k.vid_store = s.vid")
run("CREATE TEMP TABLE key_h AS
     SELECT h.\".sid\", h.schema, row_number() OVER (ORDER BY k.trip_id, h.h1, h.\".sid\")::INTEGER AS haul_id
     FROM haul h JOIN key_t k USING (\".tid\", schema)")
run("CREATE TEMP TABLE key_l AS
     SELECT l.\".lid\", l.schema, row_number() OVER (ORDER BY k.vid, l.date, l.schema, l.\".lid\")::INTEGER AS landing_id
     FROM landing l SEMI JOIN lsel USING (\".lid\", schema) JOIN key_v k ON k.vid_store = l.vid")

# The tables -----------------------------------------------------------------------------------------------------------
tabs <- list()
# pings: the union's columns less the identifiers, and PAME's for the foreign ships; one file a month of the period,
# the national fleet's pings before the period with its first month and after it with its last
fold <- paste0("CASE ", paste(sprintf("WHEN time < TIMESTAMP '%s' THEN '%s'",
                                      format(seq(as.Date(P1), by = "month", length.out = length(months))[-1]),
                                      months[-length(months)]), collapse = " "),
               sprintf(" ELSE '%s' END", months[length(months)]))
run("CREATE TEMP TABLE t_iceland AS
     SELECT *, %1$s AS file_month FROM (
       SELECT k.vid, p.time, p.lon, p.lat, p.speed, p.heading, p.cog, p.provider, p.stream, p.io, p.speed_basis
       FROM pu p JOIN key_v k ON k.vid_store = p.vid
       UNION ALL
       SELECT k.vid, p.time, p.lon, p.lat, p.speed, p.heading, p.cog, p.provider, NULL, NULL,
              CASE WHEN p.speed IS NULL THEN 'none' ELSE 'recorded' END
       FROM pame p JOIN key_v k ON k.mmsi_store = p.mmsi)
     ORDER BY vid, time, provider, stream, lon, lat", fold)
n_pame <- get("SELECT count(*) n FROM pame SEMI JOIN foreign_ship USING (mmsi)")$n
stopifnot(get("SELECT count(*) n FROM pu")$n + n_pame == get("SELECT count(*) n FROM t_iceland")$n)
for (m in months) {
  run("CREATE TEMP VIEW \"t_iceland_%1$s\" AS SELECT * EXCLUDE (file_month) FROM t_iceland WHERE file_month = '%1$s'", m)
  tabs[[paste0("iceland_", m)]] <- sprintf("\"t_iceland_%s\"", m)
}

run("CREATE TEMP TABLE t_trips AS
     SELECT kt.trip_id, kv.vid, t.schema AS source, t.T1, t.T2, t.T1_basis, t.T2_basis, t.pid1, t.pid2,
            t.twin, kt2.trip_id AS twin_of, t.n_crew
     FROM trip t JOIN key_t kt USING (\".tid\", schema) JOIN key_v kv ON kv.vid_store = t.vid
     LEFT JOIN key_t kt2 ON kt2.\".tid\" = t.twin_of AND kt2.schema = t.schema
     ORDER BY kt.trip_id")
tabs$iceland_trips <- "t_trips"

# a haul's total catch: whole weight over its species, released fish left out; the rows the store flags are counted
run("CREATE TEMP TABLE hc AS
     SELECT \".sid\", schema, sum(catch_round) FILTER (WHERE coalesce(condition, '') <> 'RELE') AS catch_kg,
            count(*) FILTER (WHERE flag IS NOT NULL) AS n_flagged, string_agg(DISTINCT flag, ', ' ORDER BY flag) AS flags
     FROM %s SEMI JOIN key_h USING (\".sid\", schema) GROUP BY ALL", pq("products", "v0", "logbook", "catch.parquet"))
run("CREATE TEMP TABLE t_hauls AS
     SELECT kh.haul_id, kt.trip_id, kv.vid, h.schema AS source, h.date, h.t1, h.t2, h.t3, h.t4, h.t1_placeholder,
            h.time_basis, h.duration_m, h.\".duration_source\" AS duration_source,
            h.lon1, h.lat1, h.lon2, h.lat2, h.lon1_basis, h.lon2_basis, h.sq, h.ssq, h.skiki AS area, h.z1, h.z2,
            h.gid, h.gid_landing, h.gid_used, h.gid_basis, h.gear, h.gear_code, h.station_type,
            h.effort_count, h.effort_count_basis, h.effort_count_unit, h.g_mesh, h.g_width, h.g_height, h.g_length,
            h.rig, h.mishap, h.eytt_deleted AS deleted, h.twin, kh2.haul_id AS twin_of,
            hc.catch_kg, coalesce(hc.n_flagged, 0)::INTEGER AS catch_n_flagged, hc.flags AS catch_flags
     FROM haul h JOIN key_h kh USING (\".sid\", schema) JOIN key_t kt USING (\".tid\", schema)
     JOIN key_v kv ON kv.vid_store = h.vid
     LEFT JOIN key_h kh2 ON kh2.\".sid\" = h.twin_of AND kh2.schema = h.schema
     LEFT JOIN hc USING (\".sid\", schema)
     ORDER BY kh.haul_id")
tabs$iceland_hauls <- "t_hauls"

# landings by species: public in Iceland (the maintainer, 2026-11-18: "landing records can contain species")
run("CREATE TEMP TABLE t_landings AS
     SELECT kl.landing_id, kv.vid, l.schema AS source, l.date, l.pid, c.gid, c.sid, sum(c.catch) AS catch_kg
     FROM landing l JOIN key_l kl USING (\".lid\", schema) JOIN key_v kv ON kv.vid_store = l.vid
     JOIN %s c USING (\".lid\", schema)
     GROUP BY ALL ORDER BY kl.landing_id, c.gid, c.sid", pq("curated", "landing", "catch.parquet"))
tabs$iceland_landings <- "t_landings"
run("CREATE TEMP TABLE t_species AS SELECT sid, name, name_en, name_sci, fao_3a, worms_id FROM %s
     WHERE sid IN (SELECT sid FROM t_landings) ORDER BY sid", pq("curated", "reference", "species.parquet"))
stopifnot(get("SELECT count(*) n FROM (SELECT DISTINCT sid FROM t_landings) WHERE sid NOT IN (SELECT sid FROM t_species)")$n == 0)
tabs$iceland_species <- "t_species"

run("CREATE TEMP TABLE t_trip_landing AS
     SELECT kt.trip_id, kl.landing_id, tl.match_type, tl.n_trips
     FROM tl JOIN key_t kt USING (\".tid\", schema) JOIN key_l kl ON kl.\".lid\" = tl.\".lid\" AND kl.schema = tl.schema_land
     ORDER BY kt.trip_id, kl.landing_id")
stopifnot(get("SELECT count(*) n FROM tl")$n == get("SELECT count(*) n FROM t_trip_landing")$n)
tabs$iceland_trip_landing <- "t_trip_landing"

# the vessels: the national fleet with the register's measures as of the middle of the period (power and length as the
# flow takes them); the other register vessels with their flag, length and type only; the foreign ships with what PAME
# gives and what its MMSI says (the kind of station, and the flag from its maritime identification digits, ITU's)
run("CREATE TEMP TABLE mid AS SELECT m.MID AS mid, any_value(coalesce(i.alpha_3, m.country)) AS flag
     FROM %s m LEFT JOIN %s i ON lower(i.name) = lower(m.country) GROUP BY m.MID",
    pq("staging", "aux", "maritime_identification_digits.parquet"), pq("staging", "aux", "country_codes_ISO3166.parquet"))
run("CREATE TEMP TABLE pame_static AS SELECT mmsi, mode(category) AS category, mode(gt_class) AS gt_class,
       median(length) AS length FROM pame SEMI JOIN foreign_ship USING (mmsi) GROUP BY mmsi")
# an MMSI's kind and its MID, by ITU-R M.585's layout: a ship's MID leads; an aid to navigation (99), a craft of a parent
# ship (98) and a coast station (00) carry it after two digits, a SAR aircraft (111) after three; a distress device (97)
# carries none
run("CREATE TEMP TABLE mmsi_kind AS SELECT mmsi,
       CASE WHEN NOT regexp_full_match(mmsi, '[0-9]{9}') THEN 'invalid'
            WHEN starts_with(mmsi, '99') THEN 'aid_to_navigation'
            WHEN starts_with(mmsi, '98') OR starts_with(mmsi, '111') OR starts_with(mmsi, '97') OR starts_with(mmsi, '0')
              THEN 'other_station'
            WHEN left(mmsi, 3) IN (SELECT mid FROM mid) THEN 'ship' ELSE 'invalid' END AS kind,
       CASE WHEN starts_with(mmsi, '99') OR starts_with(mmsi, '98') OR starts_with(mmsi, '00') THEN substr(mmsi, 3, 3)
            WHEN starts_with(mmsi, '111') THEN substr(mmsi, 4, 3)
            WHEN starts_with(mmsi, '97') THEN NULL ELSE left(mmsi, 3) END AS mid
     FROM foreign_ship")
run("CREATE TEMP TABLE t_vessels AS
     SELECT k.vid, k.tier, coalesce(v.flag, mid.flag) AS flag,
            CASE WHEN k.tier = 'national' THEN vy.kw END AS kw, CASE WHEN k.tier = 'national' THEN vy.kw_basis END AS kw_basis,
            coalesce(vy.loa, ps.length) AS loa, CASE WHEN k.tier = 'unmatched' AND ps.length IS NOT NULL THEN 'ais'
              ELSE vy.loa_basis END AS loa_basis,
            CASE WHEN k.tier = 'national' THEN m.brutto_weight_tons END AS gt, ps.gt_class,
            CASE WHEN k.tier = 'national' THEN i.region_acronym END AS home_district,
            vy.usage, CASE WHEN k.tier = 'national' THEN vy.mclass END AS mclass, ps.category AS ship_category,
            mk.kind AS mmsi_kind
     FROM key_v k
     LEFT JOIN %s vy ON vy.vid = k.vid_store AND vy.year = %d
     LEFT JOIN %s m ON m.registration_no = k.vid_store
     LEFT JOIN %s i ON i.registration_no = k.vid_store
     LEFT JOIN %s v ON v.vid = k.vid_store
     LEFT JOIN pame_static ps ON ps.mmsi = k.mmsi_store
     LEFT JOIN mmsi_kind mk ON mk.mmsi = k.mmsi_store
     LEFT JOIN mid ON mid.mid = mk.mid
     ORDER BY k.vid",
    pq("curated", "vessel", "vessel_year.parquet"), YEAR, dated("vessel_measurement_hist.parquet"),
    dated("vessel_identification_hist.parquet"), pq("curated", "vessel", "vessel.parquet"))
stopifnot(get("SELECT count(*) n FROM t_vessels")$n == length(v))
tabs$iceland_vessels <- "t_vessels"

# the harbours: every polygon of a port that comes within a cell (0.05 degrees, about 2-5 km here) of a ping, and every
# port the records name; a bounding box would take in every port from Belgium to Alaska, where single pings go
run("CREATE TEMP TABLE cell AS SELECT DISTINCT floor(lon * 20) / 20 AS x, floor(lat * 20) / 20 AS y FROM t_iceland
     WHERE lon BETWEEN -180 AND 180 AND lat BETWEEN -90 AND 90")
run("CREATE TEMP TABLE t_harbours AS
     SELECT pid, port, source, priority, geom AS geometry FROM port
     WHERE EXISTS (SELECT 1 FROM cell WHERE ST_Intersects(port.geom, ST_MakeEnvelope(x - 0.05, y - 0.05, x + 0.1, y + 0.1)))
        OR pid IN (SELECT pid1 FROM t_trips UNION SELECT pid2 FROM t_trips UNION SELECT pid FROM t_landings)
     ORDER BY pid, priority, source")
tabs$iceland_harbours <- "t_harbours"

# the coast: IS 50V's land and skerry polygons, whole
run("CREATE TEMP TABLE t_coast AS
     SELECT CASE eyjarsker WHEN 1 THEN 'land' WHEN 2 THEN 'skerry' END AS kind, geom AS geometry
     FROM ST_Read('%s') ORDER BY kind, ST_Area(geom) DESC", fd_raw("external", "is50v", "strandlina_flakar.json"))
stopifnot(get("SELECT count(*) n FROM t_coast WHERE kind IS NULL")$n == 0)
tabs$iceland_coast <- "t_coast"

# The key, beside the folder -------------------------------------------------------------------------------------------
run("COPY (SELECT 'vessel' AS kind, vid AS id, coalesce(CAST(vid_store AS VARCHAR), concat('mmsi ', mmsi_store)) AS store_key FROM key_v
           UNION ALL SELECT 'trip', trip_id, concat(\".tid\", '|', schema) FROM key_t
           UNION ALL SELECT 'haul', haul_id, concat(CAST(\".sid\" AS VARCHAR), '|', schema) FROM key_h
           UNION ALL SELECT 'landing', landing_id, concat(CAST(\".lid\" AS VARCHAR), '|', schema) FROM key_l
           ORDER BY kind, id) TO '%s' (FORMAT parquet, COMPRESSION zstd)", keyfile)

# The dictionary -------------------------------------------------------------------------------------------------------
source("products/exports/ramb_example_iceland_dict.R") # dict_tables(): the hand-written entries
commit <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)
dirty <- length(system2("git", c("status", "--porcelain"), stdout = TRUE)) > 0
origin <- "fishycode: products/exports/ramb_example_iceland.R"
g <- get("SELECT * FROM %s WHERE version = 'new' ORDER BY gid", pq("curated", "reference", "gear.parquet"))
entries <- dict_tables(P1 = P1, P2 = P2, AREA = AREA, NATIONAL = NATIONAL, MARGIN_H = MARGIN_H, CAP_D = CAP_D,
                       months = months, gear = data.frame(gid = g$gid, name = g[[3]], gear = g$gear)) # g[[3]]: the gear's Icelandic name
# the pings are one table of the dictionary in one file a month
entry_of <- function(nm) if (startsWith(nm, "iceland_2")) "iceland" else nm
stopifnot(setequal(names(entries), unique(vapply(names(tabs), entry_of, ""))))
# ranges, examples and values from the data, as ramb's dictionary gives them
describe_col <- function(tab, col) {
  ty <- get("SELECT typeof(\"%s\") t FROM %s LIMIT 1", col, tab)$t
  if (grepl("GEOMETRY", ty)) return(list())
  if (grepl("TIMESTAMP|DATE", ty)) {
    r <- get("SELECT strftime(min(\"%1$s\"), '%%Y-%%m-%%dT%%H:%%M:%%S') a, strftime(max(\"%1$s\"), '%%Y-%%m-%%dT%%H:%%M:%%S') b FROM %2$s", col, tab)
    if (grepl("DATE", ty) && !grepl("TIMESTAMP", ty)) r <- lapply(r, substr, 1, 10)
    return(list(range = c(r$a, r$b)))
  }
  if (grepl("BOOLEAN", ty)) return(list())
  if (grepl("INT|DOUBLE|DECIMAL|FLOAT", ty)) {
    r <- get("SELECT min(\"%1$s\") a, max(\"%1$s\") b FROM %2$s", col, tab)
    return(list(range = signif(c(r$a, r$b), 10)))
  }
  u <- get("SELECT DISTINCT \"%1$s\" x FROM %2$s WHERE \"%1$s\" IS NOT NULL ORDER BY 1", col, tab)$x
  if (length(u) <= 15) list(values = u) else list(examples = u[unique(round(seq(1, length(u), length.out = 5)))])
}
na_count <- function(tab, col) get("SELECT count(*) - count(\"%s\") n FROM %s", col, tab)$n
# a table's entry described from all its files: the pings' from every month at once
run("CREATE TEMP VIEW t_iceland_all AS SELECT * EXCLUDE (file_month) FROM t_iceland")
dd_tables <- list()
for (nm in names(entries)) {
  e <- entries[[nm]]
  tab <- if (nm == "iceland") "t_iceland_all" else tabs[[nm]]
  cols <- get("SELECT column_name FROM (DESCRIBE %s)", tab)$column_name
  stopifnot(identical(sort(cols), sort(vapply(e$columns, `[[`, "", "name"))))
  e$columns <- lapply(e$columns[match(cols, vapply(e$columns, `[[`, "", "name"))], function(cl) {
    d <- describe_col(tab, cl$name)
    if (!is.null(cl$values) || !is.null(cl$type) && cl$type == "enum") d$values <- NULL
    if (na_count(tab, cl$name) == 0 && !identical(cl$name, "geometry")) cl$constraints <- union(cl$constraints, "required")
    if (!is.null(cl$constraints)) cl$constraints <- as.list(unlist(cl$constraints))
    if (!is.null(d$values)) d$values <- as.list(d$values)
    if (!is.null(d$examples)) d$examples <- as.list(d$examples)
    c(cl, d)
  })
  e$source <- list(parquet = if (nm == "iceland") sprintf("iceland_%s.parquet", months) else paste0(nm, ".parquet"))
  e$origin <- origin
  dd_tables[[nm]] <- e
}
dd <- list(
  `$version` = "0.1.0",
  `$learn_more` = "https://data-dict.tidyverse.org/",
  name = "ramb_example_iceland",
  label = sprintf("A census of the north-west of Iceland, %s to %s: the national fleet in full, the other ships as AIS",
                  format(P1, "%B"), format(P2 - 1, "%B %Y")),
  description = sprintf(paste(
    "The fishing vessels registered in the north-west of Iceland (the Westfjords and Breiðafjörður), with every ping",
    "of every AIS and VMS feed, their logbooks and their landings, and every other ship in the area %.1f-%.1f W,",
    "%.1f-%.1f N as a national AIS provider delivers it, from %s to %s, with the harbours and the coast:",
    "a candidate for ramb's and ogis's example data, not released."),
    -AREA[["xmax"]], -AREA[["xmin"]], AREA[["ymin"]], AREA[["ymax"]], format(P1), format(as.Date(P2) - 1)),
  details = paste(
    "Positions are longitude and latitude in decimal degrees on WGS 84, times UTC. The vessel ids and the record ids",
    "are anonymised and consistent across the tables. Built by Claude (AI) for the maintainer; see README.md."),
  origin = origin,
  version = list(date = format(Sys.Date()), fishycode = paste0(commit, if (dirty) "-dirty")),
  tables = unname(dd_tables)
)
con_yaml <- file(file.path(out, "data-dict.yaml"), open = "w", encoding = "UTF-8")
yaml::write_yaml(dd, con_yaml, indent.mapping.sequence = TRUE)
close(con_yaml)

# The files: each stamped with its own entry -------------------------------------------------------------------------
sq <- function(x) gsub("'", "''", enc2utf8(x), fixed = TRUE)
for (nm in names(tabs)) {
  e <- dd_tables[[entry_of(nm)]]
  kv <- c(
    ramb.name = e$name, ramb.label = e$label, ramb.description = trimws(e$description),
    ramb.licence = "None: not released. MFRI's data, with Fiskistofa's logbooks and landings and the AIS feeds' own terms (README.md).",
    ramb.cite = "Marine and Freshwater Research Institute, Iceland (MFRI). Unpublished.",
    ramb.origin = e$origin, ramb.data_dict = yaml::as.yaml(e),
    fd.commit = commit, fd.dirty = tolower(as.character(dirty)), fd.script = "products/exports/ramb_example_iceland.R",
    fd.built = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  run("COPY (FROM %s) TO '%s' (FORMAT parquet, COMPRESSION zstd, COMPRESSION_LEVEL 19, KV_METADATA {%s})",
      tabs[[nm]], file.path(out, paste0(nm, ".parquet")), paste(sprintf("'%s': '%s'", names(kv), sq(kv)), collapse = ", "))
}

# The summary: what is in, and the problems, counted -------------------------------------------------------------------
# Some counts read the flow's own answers (the flags, port calls, voyages, the reconciled trip times); they are counted
# here and never shipped. The flow judges register vessels only: the unmatched MMSIs' pings have no flag of the store's.
n1 <- function(...) get(...)[[1]]
tg <- function(tier) sprintf("vid IN (SELECT vid FROM t_vessels WHERE tier = '%s')", tier)
years_w <- as.integer(substr(wr$a, 1, 4)):as.integer(substr(wr$b, 1, 4))
upath <- function(d) pqs(fd_path("staging", "ais", d, sprintf("year=%d", years_w), "*.parquet"))
run("CREATE TEMP TABLE pkey AS SELECT DISTINCT vid, provider, time, lon, lat FROM pu")
run("CREATE TEMP TABLE whacky AS SELECT w.* FROM %s w SEMI JOIN pkey p ON w.vid = p.vid AND w.time_delivered = p.time
       AND w.provider = p.provider AND w.lon = p.lon AND w.lat = p.lat", upath("ping_whacky"))
run("CREATE TEMP TABLE tagged AS SELECT g.* FROM %s g SEMI JOIN pkey p ON g.vid = p.vid AND g.time_delivered = p.time
       AND g.provider = p.provider AND g.lon = p.lon AND g.lat = p.lat WHERE g.lag_basis IN ('copy', 'receipt')", upath("ping_tagged"))
trail_src <- sprintf("read_parquet('%s', hive_partitioning = true)", fd_path("curated", "ais", "trail", "*", "*", "*.parquet"))
run("CREATE TEMP TABLE trl AS SELECT t.vid, t.time, t.port_call_id, t.voyage_id, t.year FROM %s t
     SEMI JOIN win w ON t.vid = w.vid AND t.time >= w.w1 AND t.time < w.w2 WHERE t.year BETWEEN %d AND %d",
    trail_src, YEAR - 1L, YEAR + 1L)
run("CREATE TEMP TABLE gaps AS SELECT vid, voyage_id, epoch(time - lag(time) OVER (PARTITION BY vid ORDER BY time)) AS dt,
       port_call_id IS NULL AND lag(port_call_id) OVER (PARTITION BY vid ORDER BY time) IS NULL
       AND voyage_id = lag(voyage_id) OVER (PARTITION BY vid ORDER BY time) AS at_sea FROM trl")
run("CREATE TEMP TABLE pc AS SELECT c.* FROM %s c JOIN win w ON c.vid = w.vid AND c.T_in < w.w2 AND c.T_out > w.w1",
    pq("curated", "ais", "port_call.parquet"))
run("CREATE TEMP TABLE rec AS SELECT r.* FROM %s r SEMI JOIN tsel USING (\".tid\", schema)",
    pq("curated", "link", "trip_reconciled.parquet"))
# pings on land: inside IS 50V's land, outside every harbour polygon. GEOS's prepared polygons in sf, on the distinct
# positions near Iceland, planar in degrees (a point's side of a coastline needs no sphere); DuckDB's join would test
# every point against the whole mainland's outline.
pos <- get("SELECT lon, lat, count(*) AS n FROM t_iceland WHERE lon BETWEEN -25 AND -13 AND lat BETWEEN 63 AND 67 GROUP BY ALL")
s2_was <- sf::sf_use_s2(FALSE)
pts <- sf::st_as_sf(pos, coords = c("lon", "lat"), crs = 4326)
geo <- function(tab, where = "TRUE") {
  d <- get("SELECT ST_AsWKB(geometry) AS wkb FROM %s WHERE %s", tab, where)
  sf::st_as_sfc(structure(d$wkb, class = "WKB"), crs = 4326)
}
on_land <- lengths(sf::st_intersects(pts, geo("t_coast", "kind = 'land'"))) > 0
in_harbour <- lengths(sf::st_intersects(pts[on_land, ], sf::st_make_valid(geo("t_harbours")))) > 0
invisible(sf::sf_use_s2(s2_was))
onland <- pos[on_land, ][!in_harbour, c("lon", "lat")]
duckdb::duckdb_register(con, "onland_r", onland)
run("CREATE TEMP TABLE onland AS SELECT p.vid, p.provider FROM t_iceland p SEMI JOIN onland_r o ON o.lon = p.lon AND o.lat = p.lat")
duckdb::duckdb_unregister(con, "onland_r")
static_gear <- "gear IN ('GNS', 'LLS', 'FPO')"

sizes <- file.size(file.path(out, paste0(names(tabs), ".parquet")))
summary <- list(
  built = format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"),
  fishycode = paste0(commit, if (dirty) "-dirty"),
  period = c(format(P1), format(as.Date(P2) - 1)), area = as.list(AREA), national = NATIONAL,
  margin_h = MARGIN_H, cap_d = CAP_D,
  census = list(
    by_tier = get("SELECT tier, count(*) AS vessels FROM census GROUP BY 1 ORDER BY 1"),
    national_never_in_area = n1("SELECT count(*) FROM national WHERE vid NOT IN (SELECT vid FROM u_p WHERE %s)", inarea("lon", "lat")),
    other_by_landing_only = n1("SELECT count(*) FROM other WHERE vid NOT IN (SELECT vid FROM u_p WHERE %s)", inarea("lon", "lat")),
    windows_capped = n_capped,
    window_days = as.list(get("SELECT round(min(epoch(w2 - w1)) / 86400, 1) min, round(median(epoch(w2 - w1)) / 86400, 1) median,
                               round(max(epoch(w2 - w1)) / 86400, 1) max FROM win")),
    windows_wider_than_period = n1("SELECT count(*) FROM win WHERE w1 < TIMESTAMP '%s' - INTERVAL %d HOUR OR
                                    w2 > TIMESTAMP '%s' + INTERVAL %d HOUR", fmt_t(P1), MARGIN_H, fmt_t(P2), MARGIN_H)),
  rows = as.list(vapply(tabs, function(t) n1("SELECT count(*) FROM %s", t), 0)),
  bytes = as.list(setNames(sizes, names(tabs))),
  pings = list(
    by_tier = get("SELECT v.tier, count(*) AS pings, count(DISTINCT p.vid) AS vessels FROM t_iceland p JOIN t_vessels v USING (vid) GROUP BY 1 ORDER BY 1"),
    by_provider_stream_month = get("SELECT provider, coalesce(stream, '') AS stream, strftime(time, '%%Y-%%m') AS month, count(*) AS n
                                    FROM t_iceland GROUP BY ALL ORDER BY 1, 2, 3"),
    national_outside_area = n1("SELECT count(*) FROM t_iceland WHERE %s AND NOT %s", tg("national"), inarea("lon", "lat")),
    national_outside_period = n1("SELECT count(*) FROM t_iceland WHERE %s AND NOT %s", tg("national"), in_p())),
  problems = list(
    invalid_positions = n1("SELECT count(*) FROM t_iceland WHERE lon NOT BETWEEN -180 AND 180 OR lat NOT BETWEEN -90 AND 90 OR (lon = 0 AND lat = 0)"),
    far_from_iceland = n1("SELECT count(*) FROM t_iceland WHERE lon NOT BETWEEN -45 AND 15 OR lat NOT BETWEEN 50 AND 75"),
    on_land_outside_harbours = get("SELECT v.tier, o.provider, count(*) AS n FROM onland o JOIN t_vessels v USING (vid) GROUP BY ALL ORDER BY 1, 2"),
    exact_repeats_in_a_feed = n1("SELECT sum(n - 1) FROM (SELECT count(*) AS n FROM t_iceland GROUP BY vid, provider, time, lon, lat HAVING count(*) > 1)"),
    same_vessel_second = n1("SELECT count(*) FROM (SELECT vid, time FROM t_iceland GROUP BY ALL HAVING count(*) > 1)"),
    no_speed = get("SELECT provider, count(*) FILTER (WHERE speed IS NULL) AS no_speed, count(*) AS n FROM t_iceland GROUP BY 1 ORDER BY 1"),
    flagged_by_store = get("SELECT whack_stage AS stage, count(*) AS n FROM whacky GROUP BY ALL ORDER BY n DESC, 1"),
    copies_and_receipt_by_store = get("SELECT stream, lag_basis, count(*) AS n, median(lag_s) AS median_lag_s FROM tagged
                                       GROUP BY ALL ORDER BY n DESC, 1"),
    astd_by_month = get("SELECT strftime(time, '%%Y-%%m') AS month, count(*) AS n FROM t_iceland WHERE provider = 'astd' GROUP BY 1 ORDER BY 1"),
    gps_logger_pings_left_out = n1("SELECT count(*) FROM %s u JOIN win w ON u.vid = w.vid AND u.time >= w.w1 AND u.time < w.w2
                                    WHERE u.provider = 'gps' AND u.time >= '%s' AND u.time < '%s'", union_src, wr$a, wr$b),
    national_gaps_at_sea_over_1h = n1("SELECT count(*) FROM gaps WHERE at_sea AND dt > 3600"),
    national_gaps_at_sea_over_6h = n1("SELECT count(*) FROM gaps WHERE at_sea AND dt > 21600"),
    national_port_calls = n1("SELECT count(*) FROM pc"),
    national_port_call_hours_median = n1("SELECT round(median(dur_h), 1) FROM pc"),
    national_port_calls_by_rule = get("SELECT rule, count(*) AS n FROM pc GROUP BY ALL ORDER BY n DESC, 1"),
    national_voyages = n1("SELECT count(DISTINCT (vid, year, voyage_id)) FROM trl WHERE voyage_id IS NOT NULL"),
    national_voyages_crossing_period_edge = n1("SELECT count(*) FROM voyage v JOIN win w USING (vid) WHERE v.T1 < w.w2 AND v.T2 > w.w1
                                                AND (v.T1 < '%1$s' AND v.T2 > '%1$s' OR v.T1 < '%2$s' AND v.T2 > '%2$s')", fmt_t(P1), fmt_t(P2)),
    trips_crossing_period_edge = n1("SELECT count(*) FROM span s SEMI JOIN tsel USING (\".tid\", schema)
                                     WHERE (s1 < '%1$s' AND s2 > '%1$s') OR (s1 < '%2$s' AND s2 > '%2$s')", fmt_t(P1), fmt_t(P2)),
    trips_with_hauls_in_and_out_of_area = n1("SELECT count(*) FROM (SELECT trip_id FROM t_hauls GROUP BY trip_id
                                               HAVING bool_or(%1$s) AND bool_or(NOT %1$s))", inarea("lon1", "lat1")),
    trips_with_an_ais_witness = n1("SELECT count(*) FROM rec WHERE T1_ais IS NOT NULL OR T2_ais IS NOT NULL"),
    trips_ais_departure_days_before_declared = get("SELECT datediff('day', CAST(r.T1_ais AS DATE), CAST(t.T1 AS DATE)) AS days,
                                                     count(*) AS n FROM rec r JOIN trip t USING (\".tid\", schema)
                                                     WHERE r.T1_ais IS NOT NULL GROUP BY ALL ORDER BY days"),
    trips_ais_return_not_on_declared_day = n1("SELECT count(*) FROM rec WHERE T2_ais IS NOT NULL AND T2_own IS NOT NULL
                                               AND CAST(T2_ais AS DATE) <> CAST(T2_own AS DATE)"),
    trips_with_both_returns = n1("SELECT count(*) FROM rec WHERE T2_ais IS NOT NULL AND T2_own IS NOT NULL")),
  logbook = list(
    trips = n1("SELECT count(*) FROM t_trips"),
    trips_twin = get("SELECT twin, count(*) AS n FROM t_trips WHERE twin IS NOT NULL GROUP BY 1 ORDER BY 1"),
    trips_without_hauls = n1("SELECT count(*) FROM t_trips t WHERE NOT EXISTS (SELECT 1 FROM t_hauls h WHERE h.trip_id = t.trip_id)"),
    trips_without_landing = n1("SELECT count(*) FROM t_trips t WHERE NOT EXISTS (SELECT 1 FROM t_trip_landing l WHERE l.trip_id = t.trip_id)"),
    trips_by_gear = get("SELECT g.gid, count(*) AS trips, count(DISTINCT g.vid) AS vessels FROM (
                           SELECT trip_id, vid, mode(gid_used) AS gid FROM t_hauls GROUP BY ALL) g GROUP BY ALL ORDER BY g.gid"),
    hauls = n1("SELECT count(*) FROM t_hauls"),
    hauls_twin = get("SELECT twin, count(*) AS n FROM t_hauls WHERE twin IS NOT NULL GROUP BY 1 ORDER BY 1"),
    hauls_with_clock_time = n1("SELECT count(*) FROM t_hauls WHERE coalesce(t1, t2, t3, t4) IS NOT NULL"),
    hauls_static_gear = n1("SELECT count(*) FROM t_hauls WHERE %s", static_gear),
    hauls_static_gear_set_and_haul_times = n1("SELECT count(*) FROM t_hauls WHERE %s AND t1 IS NOT NULL AND coalesce(t3, t4) IS NOT NULL", static_gear),
    hauls_local_time_moved = n1("SELECT count(*) FROM t_hauls WHERE time_basis = 'reconstructed'"),
    hauls_t1_placeholder = n1("SELECT count(*) FROM t_hauls WHERE t1_placeholder"),
    hauls_duration_implausible = n1("SELECT count(*) FROM t_hauls WHERE duration_source = 'implausible'"),
    hauls_gear_from_landing = n1("SELECT count(*) FROM t_hauls WHERE gid_basis = 'reconstructed'"),
    hauls_no_position = n1("SELECT count(*) FROM t_hauls WHERE lon1 IS NULL"),
    hauls_outside_trip_dates = n1("SELECT count(*) FROM t_hauls h JOIN t_trips t USING (trip_id)
                                   WHERE coalesce(h.t1, h.t2, h.t3, h.t4, h.date) < t.T1
                                      OR coalesce(h.t1, h.t2, h.t3, h.t4, h.date) >= t.T2 + INTERVAL 1 DAY"),
    hauls_catch_flagged = n1("SELECT count(*) FROM t_hauls WHERE catch_n_flagged > 0"),
    trips_beyond_their_pings = n1("SELECT count(*) FROM t_trips t JOIN (SELECT vid, min(time) AS w1, max(time) AS w2
                                   FROM t_iceland GROUP BY vid) w USING (vid) WHERE t.T1 < w.w1 - INTERVAL 1 DAY OR t.T2 > w.w2"),
    vessels_with_more_than_one_gear = n1("SELECT count(*) FROM (SELECT vid FROM t_hauls GROUP BY vid HAVING count(DISTINCT gid_used) > 1)")),
  landings = list(
    by_tier = get("SELECT v.tier, count(DISTINCT l.landing_id) AS landings, count(DISTINCT l.vid) AS vessels FROM t_landings l
                   JOIN t_vessels v USING (vid) GROUP BY 1 ORDER BY 1"),
    national_without_trip = n1("SELECT count(DISTINCT landing_id) FROM t_landings l WHERE %s AND NOT EXISTS
                                (SELECT 1 FROM t_trip_landing x WHERE x.landing_id = l.landing_id)", tg("national")),
    by_gear = get("SELECT l.gid, v.tier, count(DISTINCT l.landing_id) AS landings, count(DISTINCT l.vid) AS vessels,
                    round(sum(l.catch_kg)) AS kg FROM t_landings l JOIN t_vessels v USING (vid) GROUP BY ALL ORDER BY 1, 2"),
    links_by_match_type = get("SELECT match_type, count(*) AS n FROM t_trip_landing GROUP BY ALL ORDER BY n DESC, 1"),
    links_one_trip_several_landings = n1("SELECT count(*) FROM (SELECT trip_id FROM t_trip_landing GROUP BY 1 HAVING count(*) > 1)"),
    links_one_landing_several_trips = n1("SELECT count(*) FROM (SELECT landing_id FROM t_trip_landing GROUP BY 1 HAVING count(*) > 1)")),
  vessels = list(
    national_with_pings_no_record = n1("SELECT count(*) FROM t_vessels v WHERE tier = 'national'
                                        AND EXISTS (SELECT 1 FROM t_iceland p WHERE p.vid = v.vid)
                                        AND NOT EXISTS (SELECT 1 FROM t_trips t WHERE t.vid = v.vid)
                                        AND NOT EXISTS (SELECT 1 FROM t_landings l WHERE l.vid = v.vid)"),
    national_with_record_no_pings = n1("SELECT count(*) FROM t_vessels v WHERE tier = 'national'
                                        AND NOT EXISTS (SELECT 1 FROM t_iceland p WHERE p.vid = v.vid)"),
    other_landing_no_pings = n1("SELECT count(*) FROM t_vessels v WHERE tier = 'other'
                                 AND NOT EXISTS (SELECT 1 FROM t_iceland p WHERE p.vid = v.vid)"),
    by_tier_flag = get("SELECT tier, flag, count(*) AS n FROM t_vessels GROUP BY ALL ORDER BY 1, n DESC, 2"),
    unmatched_by_kind = get("SELECT v.mmsi_kind, count(*) AS n, sum(p.n) AS pings FROM t_vessels v
                             JOIN (SELECT vid, count(*) AS n FROM t_iceland GROUP BY vid) p USING (vid)
                             WHERE tier = 'unmatched' GROUP BY ALL ORDER BY n DESC, 1"),
    unmatched_ships_by_category = get("SELECT coalesce(ship_category, '(none: class B only)') AS category, count(*) AS n
                                       FROM t_vessels WHERE tier = 'unmatched' AND mmsi_kind = 'ship' GROUP BY ALL ORDER BY n DESC, 1"),
    unmatched_ships_iceland_flag_pings = get("SELECT count(*) AS ships, sum(p.n) AS pings, median(p.n) AS median_pings FROM t_vessels v
                                              JOIN (SELECT vid, count(*) AS n FROM t_iceland GROUP BY vid) p USING (vid)
                                              WHERE tier = 'unmatched' AND mmsi_kind = 'ship' AND flag = 'ISL'"),
    national_by_usage = get("SELECT coalesce(usage, '(none)') AS usage, count(*) AS n FROM t_vessels WHERE tier = 'national'
                             GROUP BY ALL ORDER BY n DESC, 1"),
    national_home_districts = get("SELECT home_district, count(*) AS n FROM t_vessels WHERE tier = 'national' GROUP BY ALL ORDER BY n DESC, 1"),
    national_no_kw = n1("SELECT count(*) FROM t_vessels WHERE tier = 'national' AND kw IS NULL"),
    national_no_gt = n1("SELECT count(*) FROM t_vessels WHERE tier = 'national' AND gt IS NULL"))
)
yaml::write_yaml(summary, file.path(out, "summary.yml"))
cat(sprintf("written: %s (%.1f MB; pings %s MB), key: %s\n", out, sum(sizes) / 1e6,
            paste(sprintf("%.1f", sizes[startsWith(names(tabs), "iceland_2")] / 1e6), collapse = " + "), keyfile))
DBI::dbDisconnect(con, shutdown = TRUE)
unlink(spill, recursive = TRUE)
