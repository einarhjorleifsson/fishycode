# afli_coords.R — recover the afli GPS logger coordinates.
#
# Input:  raw/logbooks/afli/sjalfvirkir_maelar.parquet       (28.2 M rows)
#         raw/logbooks/afli/rafr_sjalfvirkir_maelar.parquet  (23.6 M rows)
# Output: staging/afli/sensor_gps                            (hive, by year)
#
# Declaration and validation: curate/corrections/afli_coords.yml
#
# Positions were stored as DDMMmm integers where the last two digits are
# hundredths of a minute. Downstream software decoded them as seconds; where the
# value was >= 60 it rolled the minute up and subtracted 60, displacing roughly
# 40% of fixes by 741 m.
#
# The encoding is not uniquely invertible, but it collapses to exactly two
# decodings of the vessel's own reading:
#     A  dd + mm/60     + ss/6000        no rollover
#     B  dd + (mm-1)/60 + (ss+60)/6000   rollover
# and the truth is one of them. lat and lon carry independent rollover bits, so
# each fix has four candidates. A forward pass picks the one nearest a position
# dead-reckoned from the previous accepted fix using the logger's OWN recorded
# speed and heading, so nothing external is needed.
#
# This script deliberately does NOT read AIS. The previous implementation
# replaced the logger position with an AIS interpolation, which made the output
# AIS-derived and created a cycle: the AIS union consumed it as
# provider = "wacky" while this consumed the union. Keeping the recovery purely
# local breaks that. The AIS comparison now lives downstream in
# curate/checks/afli_coords_vs_ais.R, which retains both estimates side by side.
#
# Validated against AIS on 57 stations: median distance to the vessel's own AIS
# track falls from 718 m (wacky) to 329 m (recovered); 53 of 57 improve.

library(DBI)
library(duckdb)

# NB: no on.exit() here. At the top level of a source()d script it registers on
# the frame of the single eval() running that line, which exits immediately -
# closing the connection before anything uses it. Disconnect explicitly at the end.
con <- dbConnect(duckdb())

# -- candidate arithmetic and geometry, as SQL macros --------------------------

dbExecute(con, "
CREATE OR REPLACE MACRO cand_a(w) AS
  sign(w) * (trunc(abs(w))
    + floor((abs(w) - trunc(abs(w))) * 3600 / 60 + 1e-6) / 60
    + round((abs(w) - trunc(abs(w))) * 3600
            - floor((abs(w) - trunc(abs(w))) * 3600 / 60 + 1e-6) * 60) / 6000)")

dbExecute(con, "
CREATE OR REPLACE MACRO cand_b(w) AS
  sign(w) * (trunc(abs(w))
    + (floor((abs(w) - trunc(abs(w))) * 3600 / 60 + 1e-6) - 1) / 60
    + (round((abs(w) - trunc(abs(w))) * 3600
             - floor((abs(w) - trunc(abs(w))) * 3600 / 60 + 1e-6) * 60) + 60) / 6000)")

dbExecute(con, "
CREATE OR REPLACE MACRO hav(x1, y1, x2, y2) AS
  2 * 6371000 * asin(least(1, sqrt(
      pow(sin(radians(y2 - y1) / 2), 2)
    + cos(radians(y1)) * cos(radians(y2)) * pow(sin(radians(x2 - x1) / 2), 2))))")

dbExecute(con, "
CREATE OR REPLACE MACRO pred_lat(plat, sp, hd, dt) AS
  plat + CASE WHEN hd IS NULL OR dt IS NULL OR dt <= 0 THEN 0
              ELSE (coalesce(sp,0) * 0.514444 * dt * cos(radians(hd))) / 111320 END")

dbExecute(con, "
CREATE OR REPLACE MACRO pred_lon(plon, plat, sp, hd, dt) AS
  plon + CASE WHEN hd IS NULL OR dt IS NULL OR dt <= 0 THEN 0
              ELSE (coalesce(sp,0) * 0.514444 * dt * sin(radians(hd)))
                   / (111320 * cos(radians(plat))) END")

# -- the recovery -------------------------------------------------------------
# Two passes: the first predicts from the previous *wacky* fix, the second
# re-predicts from the first pass's own output.
#
# KNOWN BIAS, measured on the full run and not yet fixed. The wacky value sits
# ss/9000 degrees NORTH of candidate A (up to 742 m), so a prediction seeded from
# it leans toward the more northerly candidate, i.e. toward "no rollover". The
# effect shows up as asymmetric detection:
#     longitude   39.3% rollover detected against a true ~40%   - essentially exact
#     latitude    29.4% detected against a true ~40%            - a quarter missed
# (True rates derived from the seconds-field distribution: the model puts 80% of
# fixes in the 0-39 band and the data shows 81.9% / 81.8%.)
# Roughly 10% of all fixes therefore keep a 742 m latitude error. Candidates for
# fixing it: de-bias the pass-1 seed by the expected ss/9000 offset, or iterate
# to convergence rather than stopping at two passes. Neither is tested yet.

recover_sql <- function(src1, src2) sprintf("
WITH f AS (
  SELECT visir, timi, breidd, lengd, skip_hradi, skip_stefna,
         botndypi, hofudlinudypi, botnhiti, hofudlinuhiti, 'gps1' AS sensor_src
  FROM read_parquet('%s')
  WHERE timi IS NOT NULL AND year(timi) BETWEEN 1990 AND 2030
  UNION ALL
  SELECT visir, timi, breidd, lengd, skip_hradi, skip_stefna,
         botndypi, hofudlinudypi, botnhiti, hofudlinuhiti, 'gps2' AS sensor_src
  FROM read_parquet('%s')
  WHERE timi IS NOT NULL AND year(timi) BETWEEN 1990 AND 2030
),
c AS (
  SELECT *,
    cand_a(breidd) ay, cand_b(breidd) by_, cand_a(lengd) ax, cand_b(lengd) bx,
    lag(breidd)      OVER w plat0,
    lag(lengd)       OVER w plon0,
    lag(skip_hradi)  OVER w psp,
    lag(skip_stefna) OVER w phd,
    date_diff('second', lag(timi) OVER w, timi) dt
  FROM f WINDOW w AS (PARTITION BY visir, sensor_src ORDER BY timi)
),
p1 AS (
  SELECT *, pred_lat(plat0, psp, phd, dt) py, pred_lon(plon0, plat0, psp, phd, dt) px
  FROM c
),
p1k AS (
  SELECT *,
    CASE WHEN py IS NULL OR ay IS NULL THEN 1 ELSE list_position(
      [hav(px,py,ax,ay), hav(px,py,ax,by_), hav(px,py,bx,ay), hav(px,py,bx,by_)],
      least(hav(px,py,ax,ay), hav(px,py,ax,by_), hav(px,py,bx,ay), hav(px,py,bx,by_))) END k1
  FROM p1
),
p1v AS (
  SELECT *,
    CASE k1 WHEN 1 THEN ay WHEN 2 THEN by_ WHEN 3 THEN ay ELSE by_ END lat1,
    CASE k1 WHEN 1 THEN ax WHEN 2 THEN ax WHEN 3 THEN bx ELSE bx END lon1
  FROM p1k
),
p2 AS (
  SELECT *,
    pred_lat(lag(lat1) OVER w, psp, phd, dt) py2,
    pred_lon(lag(lon1) OVER w, lag(lat1) OVER w, psp, phd, dt) px2
  FROM p1v WINDOW w AS (PARTITION BY visir, sensor_src ORDER BY timi)
),
p2k AS (
  SELECT *,
    CASE WHEN py2 IS NULL OR ay IS NULL THEN 1 ELSE list_position(
      [hav(px2,py2,ax,ay), hav(px2,py2,ax,by_), hav(px2,py2,bx,ay), hav(px2,py2,bx,by_)],
      least(hav(px2,py2,ax,ay), hav(px2,py2,ax,by_), hav(px2,py2,bx,ay), hav(px2,py2,bx,by_))) END k2,
    CASE WHEN py2 IS NULL OR ay IS NULL THEN NULL ELSE
      list_sort([hav(px2,py2,ax,ay), hav(px2,py2,ax,by_),
                 hav(px2,py2,bx,ay), hav(px2,py2,bx,by_)])[2]
    - list_sort([hav(px2,py2,ax,ay), hav(px2,py2,ax,by_),
                 hav(px2,py2,bx,ay), hav(px2,py2,bx,by_)])[1] END margin_m
  FROM p2
)
SELECT
  visir, timi, sensor_src,
  breidd AS w_lat, lengd AS w_lon,
  CASE k2 WHEN 1 THEN ay WHEN 2 THEN by_ WHEN 3 THEN ay ELSE by_ END AS lat,
  CASE k2 WHEN 1 THEN ax WHEN 2 THEN ax WHEN 3 THEN bx ELSE bx END AS lon,
  margin_m,
  CASE WHEN breidd IS NULL OR lengd IS NULL THEN 'missing'
       WHEN py2 IS NULL                     THEN 'seed'
       WHEN k2 = 1                          THEN 'recovered_no_rollover'
       ELSE                                      'recovered_rollover' END AS basis,
  skip_hradi AS speed, skip_stefna AS heading,
  botndypi, hofudlinudypi, botnhiti, hofudlinuhiti,
  year(timi) AS year
FROM p2k", src1, src2)

out <- fd_staging("afli", "sensor_gps")
unlink(out, recursive = TRUE)

dbExecute(con, sprintf("COPY (%s) TO '%s' (FORMAT parquet, PARTITION_BY (year), OVERWRITE_OR_IGNORE)",
  recover_sql(fd_raw("logbooks", "afli", "sjalfvirkir_maelar.parquet"),
              fd_raw("logbooks", "afli", "rafr_sjalfvirkir_maelar.parquet")),
  out))

# -- report -------------------------------------------------------------------

s <- dbGetQuery(con, sprintf("
  SELECT basis, count(*) n, round(median(margin_m)) median_margin_m
  FROM read_parquet('%s/**/*.parquet') GROUP BY 1 ORDER BY 2 DESC", out))
print(s)
cat(sprintf("\ntotal rows: %s\n", format(sum(s$n), big.mark = ",")))

dbDisconnect(con, shutdown = TRUE)
