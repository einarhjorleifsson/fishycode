# Are the dropped afli stations real? Asked of AIS, which knows nothing about the
# logbook merge.
#
# Input:  raw/logbooks/afli/{rafr_stofn,stofn}.parquet, curated/ais/{trip.parquet,ping},
#         curated/landing/landings.parquet, curated/vessel/vessel.parquet
# Output: curated/check/afli_rafr_stofn_corroboration.parquet - one row per station
#
# 23,570 live electronic submissions never reach stofn, the source system's own
# merged table - curate/corrections/afli_rafr_stofn_stations_dropped.yml. Why the
# merge drops them cannot be answered here and, per the maintainer 2026-09-23, will
# not be answered upstream either. So this asks the answerable question instead:
# were the vessel and the haul where the record says they were?
#
# Step 1 of curate/plans/005-recover-the-dropped-afli-stations.md. It REPORTS - no
# product changes and no rebuild is forced. Admission is steps 2-4.
#
# THE CONTROL IS NOT OPTIONAL. Every test here is loose enough to pass most things,
# so a number for the lost rows alone would mean nothing. Each test is applied
# identically to rows that DID merge, drawn from the same vessel-years, and the two
# are always reported together.

library(dplyr)
library(nanoparquet)
library(duckdbfs)

SEED          <- 1L
CONTROL_PER   <- 4L    # control rows drawn per lost row, within the same vessel-year
LANDING_DAYS  <- 5L

# breidd/lengd are DDMM INTEGERS - 6348 is 63 deg 48 min N - so the recorded
# position resolves to one arc-minute, about 1.9 km in latitude. pos_lat/pos_lon
# are 100% NA and cannot be used. Nothing finer than ~2 km is knowable about these
# positions, which is why no distance threshold is chosen a priori below: the
# control's own distribution sets the bar.
ddmm <- function(x) {
  d <- x %/% 100L
  m <- x - d * 100L
  ifelse(is.na(x) | m >= 60L, NA_real_, d + m / 60)
}

## Population -------------------------------------------------------------------
feed <-
  read_parquet(fd_raw("logbooks", "afli", "rafr_stofn.parquet")) |>
  select(visir, vid = skipnr, eytt, vedags, breidd, lengd)
merged_ids <- read_parquet(fd_raw("logbooks", "afli", "stofn.parquet"))$visir

live <-
  feed |>
  filter(eytt == 0L) |>                         # deleted rows are excluded by design
  transmute(visir, vid,
            date = as.Date(vedags),
            lat  =  ddmm(breidd),
            lon  = -ddmm(lengd),                # Iceland is west; the feed stores it unsigned
            lost = !visir %in% merged_ids) |>
  filter(!is.na(date))

lost <- live |> filter(lost)

# Matched control: for each vessel-year that lost rows, draw CONTROL_PER merged rows
# from THAT vessel-year. A plain random sample across the whole feed would differ
# from the lost rows in fleet and era, and the comparison would then be measuring
# the fleet rather than the defect.
set.seed(SEED)
want <-
  lost |> mutate(yr = as.integer(format(date, "%Y"))) |>
  count(vid, yr, name = "n_lost") |>
  mutate(n_want = n_lost * CONTROL_PER)

control <-
  live |> filter(!lost) |> mutate(yr = as.integer(format(date, "%Y"))) |>
  inner_join(want, by = c("vid", "yr")) |>
  group_by(vid, yr) |>
  slice_sample(prop = 1) |>                     # shuffle within the vessel-year
  filter(row_number() <= n_want) |>             # then take as many as that year owes
  ungroup() |>
  select(-yr, -n_lost, -n_want)

subj <- bind_rows(lost, control) |> mutate(route = if_else(lost, "rafr_stofn", "stofn"))

message(sprintf("subjects: %s lost, %s matched control",
                format(sum(subj$lost), big.mark = ","),
                format(sum(!subj$lost), big.mark = ",")))

## Test 1 - was the vessel on an AIS voyage that day? ---------------------------
trip <-
  read_parquet(fd_curated("ais", "trip.parquet")) |>
  transmute(vid, d1 = as.Date(T1), d2 = as.Date(T2))

on_voyage <-
  subj |> select(visir, vid, date) |>
  inner_join(trip, by = "vid", relationship = "many-to-many") |>
  filter(date >= d1, date <= d2) |>
  distinct(visir) |> pull(visir)

## Test 2 - how close is the nearest ping of that vessel that day? --------------
# Pushed to DuckDB: 539.9 M pings, narrowed first to the vessel-days in question.
# Great-circle distance; the recorded position's 1.9 km granularity makes anything
# more precise than that meaningless.
vd <-
  subj |> filter(!is.na(lat), !is.na(lon)) |>
  transmute(visir, vid, date, lat, lon, yr = as.integer(format(date, "%Y")))

con <- duckdbfs::cached_connection()
DBI::dbWriteTable(con, "subj_vd", as.data.frame(vd), overwrite = TRUE)

# curated/ais/ping is 539.9 M rows / 12 GB, hive-partitioned by year. It is read as
# a view and never materialised: the year list prunes partitions and the join to the
# vessel-days in question drops everything else, so only the few million pings that
# could possibly matter are ever pulled into memory. An earlier version of this
# script computed the whole dataset into a temp table and died.
DBI::dbExecute(con, sprintf(
  "CREATE OR REPLACE VIEW ping_all AS
     SELECT vid, time, lon, lat, year
     FROM read_parquet('%s/**/*.parquet', hive_partitioning = true)",
  fd_curated("ais", "ping")))

DBI::dbExecute(con, "CREATE OR REPLACE TEMP TABLE vd_key AS
  SELECT DISTINCT vid, date, yr FROM subj_vd")

DBI::dbExecute(con, "CREATE OR REPLACE TEMP TABLE ping_hit AS
  SELECT p.vid, p.time, CAST(p.time AS DATE) AS date, p.lon, p.lat
  FROM ping_all p
  JOIN vd_key k
    ON k.vid = p.vid AND k.date = CAST(p.time AS DATE)
  WHERE p.year IN (SELECT DISTINCT yr FROM vd_key)")

message(sprintf("pings on the vessel-days in question: %s",
                format(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM ping_hit")$n,
                       big.mark = ",")))

# Great-circle distance from the recorded position to the nearest ping that day.
near <- DBI::dbGetQuery(con, "
  SELECT s.visir,
         COUNT(p.lon)                                     AS pings_that_day,
         MIN(6371.0 * 2 * ASIN(SQRT(
             POWER(SIN(RADIANS(p.lat - s.lat) / 2), 2) +
             COS(RADIANS(s.lat)) * COS(RADIANS(p.lat)) *
             POWER(SIN(RADIANS(p.lon - s.lon) / 2), 2)))) AS ais_km
  FROM subj_vd s
  LEFT JOIN ping_hit p ON p.vid = s.vid AND p.date = s.date
  GROUP BY s.visir")

## Test 2b - the vessel's own GPS logger against AIS, at matched times ---------
# The station's recorded position is a DDMM integer: one arc-minute, ~1.9 km, no
# time. The logger is decimal degrees every ten minutes with a timestamp, so where
# a station has logger fixes the same question can be asked ~5x more sharply -
# were two independent physical devices, the vessel's GPS logger and its AIS
# transponder, in the same place at the same moment?
#
# WHICH logger derivation matters, and getting it wrong would have been fatal.
# curated/logbook/sensor_gps supplies lon/lat by INTERPOLATING FROM AIS. Comparing
# that to AIS measures nothing but the interpolation - it would have produced
# near-zero distances and looked like a triumph. staging/afli/sensor_gps is the
# other derivation (curate/corrections/afli_coords.R): it recovers the logger's own
# DDMMmm reading by dead-reckoning from the logger's OWN speed and heading and
# "deliberately does NOT read AIS". That is the one an AIS comparison may use.
# This is the cycle AGENTS.md warns about, one join away.
LOGGER_WINDOW_S <- 600L   # the logger's own sampling interval

# AND IT IS NOT CLEAN - but most of the damage is a dropped west sign, which is a
# notorious defect across the logbook databases generally (maintainer, 2026-09-23;
# TODO item 1 carries the same fault in adb, where 91.8% of its outlying stations
# have a positive longitude). Measured here on all 50,147,118 recovered fixes:
#
#     79.8%  land in Icelandic waters as recorded
#     16.7%  are impossible as recorded and valid with lon negated  - 8,389,194 fixes
#      3.5%  are unusable either way
#
# So the sign is 83% of the problem. An earlier version of this check DISCARDED
# every out-of-box fix, which threw away those 16.7% and did it UNEQUALLY - 55.2% of
# lost-station fixes dropped against 46.8% of control - so the two groups were being
# compared on different survivorship. Repairing the sign instead removes most of
# that asymmetry and keeps the comparison honest.
#
# This is a repair applied HERE, to a check's own working copy, and it corrects
# nothing in the product: staging/afli/sensor_gps still holds what it held. The
# finding is declared in curate/corrections/afli_coords.yml.
FIX_LON <- function(d) {
  d |>
    mutate(lon_fixed = dplyr::if_else(
             !(lat > 60 & lat < 70 & lon > -32 & lon < -5) &
              (lat > 60 & lat < 70 & -lon > -32 & -lon < -5),
             -lon, lon),
           lon = lon_fixed) |>
    select(-lon_fixed) |>
    filter(lat > 60, lat < 70, lon > -32, lon < -5)
}

lg_all <-
  duckdbfs::open_dataset(fd_staging("afli", "sensor_gps")) |>
  select(visir, timi, lat, lon) |>
  filter(!is.na(lat), !is.na(lon)) |>
  collect() |>
  inner_join(subj |> select(visir, vid, route), by = "visir")

print(knitr::kable(
  lg_all |>
    mutate(ok   = lat > 60 & lat < 70 & lon > -32 & lon < -5,
           flip = !ok & (lat > 60 & lat < 70 & -lon > -32 & -lon < -5)) |>
    group_by(route) |>
    summarise(fixes = n(),
              `as recorded` = sprintf("%.1f%%", 100 * mean(ok)),
              `sign repaired` = sprintf("%.1f%%", 100 * mean(flip)),
              `unusable` = sprintf("%.1f%%", 100 * mean(!ok & !flip)),
              .groups = "drop"),
  caption = "staging/afli/sensor_gps positions - the west sign is most of the damage"))

lg <- lg_all |> FIX_LON() |> select(visir, timi, lat, lon, vid)
message(sprintf("logger fixes on subject stations (usable): %s over %s stations",
                format(nrow(lg), big.mark = ","),
                format(dplyr::n_distinct(lg$visir), big.mark = ",")))

DBI::dbWriteTable(con, "logger", as.data.frame(lg), overwrite = TRUE)

# ASOF JOIN takes the nearest ping at or before each logger fix; the window keeps a
# fix whose nearest ping is hours away from being scored as if it were seconds.
logger_ais <- DBI::dbGetQuery(con, sprintf("
  WITH m AS (
    SELECT l.visir, l.timi, l.lat AS llat, l.lon AS llon,
           p.time AS ptime, p.lat AS plat, p.lon AS plon
    FROM logger l
    ASOF JOIN ping_hit p
      ON l.vid = p.vid AND l.timi >= p.time
  )
  SELECT visir,
         COUNT(*) AS logger_fixes,
         MEDIAN(1000.0 * 6371.0 * 2 * ASIN(SQRT(
             POWER(SIN(RADIANS(plat - llat) / 2), 2) +
             COS(RADIANS(llat)) * COS(RADIANS(plat)) *
             POWER(SIN(RADIANS(plon - llon) / 2), 2)))) AS logger_ais_m
  FROM m
  WHERE date_diff('second', ptime, timi) <= %d
  GROUP BY visir", LOGGER_WINDOW_S))

## Test 3 - a landing soon after. Reported, NOT graded. -------------------------
# The lost rows never reached curated, so they carry no .tid and a station cannot be
# tied to a specific landing without re-running the adapter's trip grouping. The
# cheap substitute - did this vessel land within LANDING_DAYS - is nearly
# uninformative for a vessel that fishes continuously, so it is emitted for the
# reader and deliberately kept out of the evidence grade below.
lnd <-
  read_parquet(fd_curated("landing", "landings.parquet")) |>
  transmute(vid, ldate = as.Date(date)) |> distinct()

landed <-
  subj |> select(visir, vid, date) |>
  inner_join(lnd, by = "vid", relationship = "many-to-many") |>
  filter(ldate >= date, ldate <= date + LANDING_DAYS) |>
  distinct(visir) |> pull(visir)

## Grade ------------------------------------------------------------------------
out <-
  subj |>
  left_join(near, by = "visir") |>
  left_join(logger_ais, by = "visir") |>
  mutate(pings_that_day  = coalesce(as.integer(pings_that_day), 0L),
         logger_fixes    = coalesce(as.integer(logger_fixes), 0L),
         ais_voyage      = visir %in% on_voyage,
         landed_within_5d = visir %in% landed)

# The bar is the control's own 90th percentile distance. Whatever spread genuine,
# merged records show against AIS - measurement error, the arc-minute grid, gear
# towed away from the logged point - the lost rows are held to the same number. It
# is computed, printed and stored, never typed in.
BAR <- out |> filter(!lost, pings_that_day > 0) |>
  summarise(q = quantile(ais_km, 0.90, na.rm = TRUE)) |> pull(q)

out <-
  out |>
  mutate(evidence = case_when(
           pings_that_day > 0 & ais_km <= BAR ~ "strong",
           pings_that_day > 0                 ~ "weak",
           ais_voyage                         ~ "voyage only",
           .default                           = "none")) |>
  select(visir, vid, route, date, lon, lat, ais_voyage, pings_that_day, ais_km,
         logger_fixes, logger_ais_m, landed_within_5d, evidence) |>
  arrange(route, date)

## Report - lost and control side by side, always -------------------------------
message(sprintf("\ncontrol p90 distance (the bar): %.2f km", BAR))

print(knitr::kable(
  out |> group_by(route) |>
    summarise(rows = n(),
              `on a voyage`   = sprintf("%.1f%%", 100 * mean(ais_voyage)),
              `has pings`     = sprintf("%.1f%%", 100 * mean(pings_that_day > 0)),
              `median km`     = round(median(ais_km, na.rm = TRUE), 2),
              `p90 km`        = round(quantile(ais_km, 0.9, na.rm = TRUE), 2),
              `landed <=5d`   = sprintf("%.1f%%", 100 * mean(landed_within_5d)),
              .groups = "drop"),
  caption = "afli_rafr_stofn_corroboration - lost rows against their matched control"))

print(knitr::kable(
  out |> count(route, evidence) |>
    tidyr::pivot_wider(names_from = route, values_from = n, values_fill = 0L),
  caption = "evidence grade"))

# The same table restricted to the STK era. Without this panel the 'on a voyage'
# figure above (90.6% of lost rows) reads as contradicting the 98.3% measured for
# plan 005, when in fact 1,808 lost rows predate AIS entirely and cannot be on a
# voyage at any price. Reporting the whole population and the answerable subset
# separately is the difference between a low score and an unanswerable question.
AIS_T1 <- as.Date("2007-06-01")
print(knitr::kable(
  out |> filter(date >= AIS_T1) |> group_by(route) |>
    summarise(rows = n(),
              `on a voyage` = sprintf("%.1f%%", 100 * mean(ais_voyage)),
              `has pings`   = sprintf("%.1f%%", 100 * mean(pings_that_day > 0)),
              `strong`      = sprintf("%.1f%%", 100 * mean(evidence == "strong")),
              `no AIS at all` = sprintf("%.1f%%", 100 * mean(evidence == "none")),
              .groups = "drop"),
  caption = "STK era only (>= 2007-06) - the rows AIS can actually speak to"))

print(knitr::kable(
  out |> filter(date < AIS_T1) |> count(route, name = "rows"),
  caption = "pre-AIS, corroboration impossible either way"))

# The sharp test. Metres, not the arc-minute grid.
print(knitr::kable(
  out |> filter(logger_fixes > 0, !is.na(logger_ais_m)) |> group_by(route) |>
    summarise(stations = n(),
              fixes = sum(logger_fixes),
              `median m` = round(median(logger_ais_m)),
              `p90 m`    = round(quantile(logger_ais_m, 0.9)),
              `within 500 m` = sprintf("%.1f%%", 100 * mean(logger_ais_m <= 500)),
              .groups = "drop"),
  caption = paste("INDICATIVE ONLY - GPS logger vs AIS at matched times.",
                  "Source is the unadopted afli_coords recovery, whose west-sign",
                  "defect is repaired in this script's working copy only.")))

write_curated(out, fd_curated("check", "afli_rafr_stofn_corroboration.parquet"),
              inputs = c(rafr_stofn = fd_raw("logbooks", "afli", "rafr_stofn.parquet"),
                         stofn      = fd_raw("logbooks", "afli", "stofn.parquet"),
                         ais_trip   = fd_curated("ais", "trip.parquet"),
                         landings   = fd_curated("landing", "landings.parquet")))
