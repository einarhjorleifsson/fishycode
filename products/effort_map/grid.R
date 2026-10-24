# grid.R — the effort map's base grid: the trail's fishing effort summed by 0.001-degree cell, gear, year and preset,
# each fix's hours spread along the line to its next fix; or, with the argument `fixes`, each fix's hours in its own
# cell, the grid the page shows with its interpolation switch off.
# Decision 220; the second grid since the maintainer's ask of 2026-10-24 (the original data beside the interpolated).
#
# Input:  $FISHYDATA/products/v0/ais/trail (vid, voyage_id, time, lon, lat, fishing, fishing_flow, gid_used, gid_voyage,
#         hours, kw_hours)
# Output: $FISHYDATA/products/effort_map/grid.parquet
#         preset, gid, year, ix, iy (the cell's south-west corner in thousandths of a degree), h, kwh,
#         n (the fixes, each counted in the cell of its first step); grid_005.parquet, the same on 0.005-degree cells;
#         with `fixes`, grid_fixes.parquet and grid_fixes_005.parquet, the same with no spreading
#
# Run from the fishycode root, after a rebuild of the trail (about 4 min each):
#   Rscript products/effort_map/grid.R          # interpolated
#   Rscript products/effort_map/grid.R fixes    # each fix in its own cell
#
# The gear of a fix: `gid_used`, the haul's, under `fishing` (the haul window); `gid_used` or else `gid_voyage` under
# `fishing_flow`, whose fixes outside a window are judged by the voyage gear's speed range. `gid_used` is the logbook's
# gear corrected by the landing's (curate/corrections/logbook_gear.R, plan 014 3j), the gear the windows are built
# with; `gid`, the logbook's as recorded, showed sea cucumber dredging off the east coast as bottom trawl (2026-10-24).
#
# Spreading (maintainer, 2026-10-24): a fix stands for the time to its next fix (`hours`), so its hours and kW-hours
# are split evenly over STEP_MIN steps along the straight line to the next fix of the same vessel and voyage, each
# step at the middle of its stretch. A gap longer than MAX_GAP_MIN (7 % of the fishing hours, measured 2026-10-24),
# a fix with no next fix, or one outside a voyage stays where it is, in one step. MAX_GAP_MIN = 0 gives the grid of
# fixes alone. The hours per preset, gear and year are the trail's, or the script stops.

source("R/paths.R")

FIXES       <- identical(commandArgs(trailingOnly = TRUE)[1], "fixes")
STEP_MIN    <- 1
MAX_GAP_MIN <- if (FIXES) 0 else 30

con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(tempdir(), "duckdb_temp"))))
trail_dir <- fd_path("products", "v0", "ais", "trail")
out <- fd_path("products", "effort_map", if (FIXES) "grid_fixes.parquet" else "grid.parquet")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
years <- sort(as.integer(sub("^year=", "", list.files(trail_dir, pattern = "^year=[0-9]+$"))))

cells <- function(year, preset, gear) sprintf("
  WITH f AS (
    SELECT voyage_id, time, lon, lat, t.hours AS hrs, t.kw_hours AS kwh, %3$s AS gid, %2$s AS keep,
           lead(time) OVER w AS time2, lead(lon) OVER w AS lon2, lead(lat) OVER w AS lat2
    FROM read_parquet('%4$s/year=%1$d/*/*.parquet', hive_partitioning = false) t
    WHERE lon IS NOT NULL AND lat IS NOT NULL
    WINDOW w AS (PARTITION BY vid, voyage_id ORDER BY time)),
  s AS (
    SELECT gid, lon, lat, lon2, lat2, hrs, kwh,
           %5$d > 0 AND voyage_id IS NOT NULL AND time2 IS NOT NULL AND date_diff('second', time, time2) <= %5$d * 60 AS spread,
           CASE WHEN spread THEN greatest(1, CAST(ceil(date_diff('second', time, time2) / (%6$d * 60.0)) AS INTEGER))
                ELSE 1 END AS k
    FROM f WHERE keep),
  q AS (SELECT *, unnest(range(k)) AS i FROM s),
  p AS (
    SELECT gid, i, hrs / k AS h, kwh / k AS kwh,
           CASE WHEN spread THEN lon + (lon2 - lon) * (i + 0.5) / k ELSE lon END AS x,
           CASE WHEN spread THEN lat + (lat2 - lat) * (i + 0.5) / k ELSE lat END AS y
    FROM q)
  SELECT '%2$s' AS preset, gid, %1$d AS year, CAST(floor(x * 1000) AS INTEGER) AS ix, CAST(floor(y * 1000) AS INTEGER) AS iy,
         sum(h) AS h, sum(kwh) AS kwh, CAST(count(*) FILTER (WHERE i = 0) AS BIGINT) AS n
  FROM p GROUP BY ALL", year, preset, gear, trail_dir, MAX_GAP_MIN, STEP_MIN)

trail_hours <- function(year, preset, gear) sprintf("
  SELECT '%2$s' AS preset, %3$s AS gid, %1$d AS year, sum(t.hours) AS h, sum(t.kw_hours) AS kwh, count(*) AS n
  FROM read_parquet('%4$s/year=%1$d/*/*.parquet', hive_partitioning = false) t
  WHERE %2$s AND lon IS NOT NULL AND lat IS NOT NULL GROUP BY ALL", year, preset, gear, trail_dir)

presets <- list(fishing = "gid_used", fishing_flow = "coalesce(gid_used, gid_voyage)")
t0 <- Sys.time()
invisible(DBI::dbExecute(con, "CREATE TABLE grid (preset VARCHAR, gid INTEGER, year INTEGER, ix INTEGER, iy INTEGER,
                                                  h DOUBLE, kwh DOUBLE, n BIGINT)"))
invisible(DBI::dbExecute(con, "CREATE TABLE fix (preset VARCHAR, gid INTEGER, year INTEGER, h DOUBLE, kwh DOUBLE, n BIGINT)"))
for (y in years) for (p in names(presets)) {
  invisible(DBI::dbExecute(con, paste("INSERT INTO grid", cells(y, p, presets[[p]]))))
  invisible(DBI::dbExecute(con, paste("INSERT INTO fix", trail_hours(y, p, presets[[p]]))))
  message(y, " ", p, ": ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s")
}

# Every hour and fix of the trail is in the grid, per preset, gear and year
d <- DBI::dbGetQuery(con, "
  SELECT f.preset, f.gid, f.year, f.h AS h_trail, g.h AS h_grid, f.kwh AS kwh_trail, g.kwh AS kwh_grid, f.n AS n_trail, g.n AS n_grid
  FROM fix f FULL JOIN (SELECT preset, gid, year, sum(h) AS h, sum(kwh) AS kwh, sum(n) AS n FROM grid GROUP BY ALL) g
    ON f.preset = g.preset AND f.gid IS NOT DISTINCT FROM g.gid AND f.year = g.year")
off <- function(a, b) !(is.na(a) & is.na(b)) & (is.na(a) | is.na(b) | abs(a - b) > 1e-6 * pmax(1, abs(a)))
bad <- d[off(d$h_trail, d$h_grid) | off(d$kwh_trail, d$kwh_grid) | is.na(d$n_trail) | is.na(d$n_grid) | d$n_trail != d$n_grid, ]
if (nrow(bad)) { print(bad); stop("the grid does not hold the trail's hours", call. = FALSE) }
cat(sprintf("checked: %d preset-gear-years, the grid's hours, kW-hours and fixes are the trail's\n", nrow(d)))

partial <- paste0(out, ".partial")
invisible(DBI::dbExecute(con, sprintf("COPY (SELECT * FROM grid ORDER BY preset, gid, year, ix, iy) TO '%s' (FORMAT parquet)", partial)))
file.rename(partial, out)
print(DBI::dbGetQuery(con, sprintf("SELECT preset, count(*) AS cells, sum(h) AS h FROM '%s' GROUP BY 1 ORDER BY 1", out)))
cat(sprintf("%s: %.0f s, %.0f MB\n", out, as.numeric(difftime(Sys.time(), t0, units = "secs")), file.size(out) / 1e6))

# The coarse copy ----------------------------------------------------------------
# The same sums on 0.005-degree cells, from which tiles.R serves every cell size that is a multiple of 5 thousandths
# (zoomed out), exactly: a 0.005-degree cell lies whole inside such a cell.
out5 <- sub("[.]parquet$", "_005.parquet", out)
invisible(DBI::dbExecute(con, sprintf("COPY (
  SELECT preset, gid, year, CAST(floor(ix / 5) AS INTEGER) * 5 AS ix, CAST(floor(iy / 5) AS INTEGER) * 5 AS iy,
         sum(h) AS h, sum(kwh) AS kwh, CAST(sum(n) AS BIGINT) AS n
  FROM grid GROUP BY ALL ORDER BY preset, gid, year, ix, iy) TO '%s' (FORMAT parquet)", paste0(out5, ".partial"))))
file.rename(paste0(out5, ".partial"), out5)
cat(sprintf("%s: %s cells, %.0f MB\n", out5, format(DBI::dbGetQuery(con, sprintf("SELECT count(*) n FROM '%s'", out5))$n,
                                                   big.mark = ","), file.size(out5) / 1e6))
