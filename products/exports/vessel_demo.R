# The vessel overview as a demo to send: a folder that opens with a double click, on any system, with no R, no server
# and no shell command (maintainer, 2026-10-20). A sample of vessels, anonymised, with their data around one month.
#
# Input:  what products/vessel_overview/api.R reads, less the register, its history and the photos;
#         products/vessel_overview/www/index.html and app.js
# Output: $FISHYDATA/exports/vessel_demo_<month>/ (index.html, data/*.js, README.md), the same zipped beside it, and
#         vessel_demo_<month>_key.csv, the demo's vessel numbers to vids, which never goes with the folder
#
# Run from the repository root:  Rscript products/exports/vessel_demo.R
#
# - The vessels: those with a logbook trip on an AIS voyage that overlaps the month (the trail's .tid on the voyage's
#   pings), drawn at random within their main gear (the gear of most of their hauls on those trips), N_BY_GEAR of each.
# - A vessel's window runs from the start of its first voyage overlapping the month to the end of its last. Kept as
#   they are: the pings, voyages and port calls in it, the logbook trips overlapping it or on its pings, their hauls,
#   the hauls' windows and catch, and the landings in it or linked to those trips. Record ids (.tid, .sid, .lid) and ports are kept.
# - Anonymised: the vid becomes 1-n in random order and the name "Vessel <n>"; call sign, MMSI, IMO, the register, its
#   history and the photos are left out. A track can still be matched to public AIS: the folder goes to a colleague
#   under an agreement and is never published (plan 001).
# - Each answer is the service's own (api.R: its SQL and its column allowlist), narrowed to the window, so the page
#   reads the bundle as it reads the service (app.js, bundle mode). The answers are parquet as base64 in data/v<n>.js,
#   and the page's script is inlined: a page opened as a file may load a script, but may not fetch() or load a module.

source("R/paths.R")
source("products/vessel_overview/api.R")

MONTH <- as.Date("2018-06-01")
N_BY_GEAR <- c(LHM = 6, LLS = 5, GNS = 5, OTB = 5, SDN = 3, OTM = 2, PS = 2, DRB = 2)
SEED <- 20180601

NEXT <- seq(MONTH, by = "month", length.out = 2)[2]
MONTH_NAME <- paste(month.name[as.integer(format(MONTH, "%m"))], format(MONTH, "%Y"))
LABEL <- sprintf("%s, %d anonymised vessels", MONTH_NAME, sum(N_BY_GEAR))
NAME <- paste0("vessel_demo_", format(MONTH, "%Y-%m"))
out <- fd_path("exports", NAME)
zipfile <- fd_path("exports", paste0(NAME, ".zip"))
keyfile <- fd_path("exports", paste0(NAME, "_key.csv"))

con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(tempdir(), "duckdb_temp")))
run <- function(...) DBI::dbExecute(con, sprintf(...))
get <- function(...) DBI::dbGetQuery(con, sprintf(...))
# a record's key as one string, so a narrowing is a plain IN over a table of keys
TID <- "concat(\".tid\", '|', schema)"
SID <- "concat(\".sid\", '|', schema)"
LID <- "concat(\".lid\", '|', schema)"
W1 <- "(SELECT w1 FROM w)"
W2 <- "(SELECT w2 FROM w)"

# The vessels -------------------------------------------------------------------------------------------------------
run("CREATE TEMP TABLE vo AS SELECT * FROM %s WHERE T1 < DATE '%s' AND T2 >= DATE '%s'",
    src("curated", "ais", "voyage.parquet"), NEXT, MONTH)
years <- get("SELECT DISTINCT year FROM vo ORDER BY year")$year
run("CREATE TEMP TABLE jt AS SELECT DISTINCT vid, %s AS key FROM (%s) JOIN vo USING (vid, year, voyage_id)
     WHERE \".tid\" IS NOT NULL", TID,
    paste(sprintf("SELECT * FROM %s", vapply(years, TRAIL, "")), collapse = " UNION ALL BY NAME "))
gear <- get("SELECT vid, first(gear ORDER BY n DESC, gear) AS gear FROM (
               SELECT jt.vid, g.gear, count(*) AS n FROM jt
               JOIN %s s ON concat(s.\".tid\", '|', s.schema) = jt.key
               JOIN %s g ON g.\".sid\" = s.\".sid\" AND g.schema = s.schema
               WHERE (s.twin IS NULL OR s.twin <> 'duplicate') AND g.gear IS NOT NULL GROUP BY ALL)
             GROUP BY vid ORDER BY vid",
            src("curated", "logbook", "station.parquet"), src("curated", "logbook", "gear.parquet"))
set.seed(SEED)
pick <- do.call(rbind, lapply(names(N_BY_GEAR), function(g) {
  v <- sort(gear$vid[gear$gear == g])
  data.frame(vid = v[sample.int(length(v), min(N_BY_GEAR[[g]], length(v)))], gear = g)
}))
pick$n <- sample.int(nrow(pick))
pick <- pick[order(pick$n), ]
run("CREATE TEMP TABLE win AS SELECT vid, min(T1) AS w1, max(T2) AS w2 FROM vo GROUP BY vid")
run("CREATE TEMP TABLE stats (vid INTEGER, first_year INTEGER, last_ping DATE, last_landing DATE)")
cat(sprintf("%d vessels with a logbook trip on a voyage in %s; %d drawn\n", nrow(gear), format(MONTH, "%Y-%m"), nrow(pick)))

# Each vessel's answers, narrowed to its window -----------------------------------------------------------------------
unlink(c(out, zipfile), recursive = TRUE)
dir.create(file.path(out, "data"), recursive = TRUE)
b64 <- function(raw) gsub("[\r\n]", "", jsonlite::base64_enc(raw))
write_js <- function(file, x, name = file) {
  body <- paste0('"', names(x), '":"', vapply(x, b64, ""), '"', collapse = ",\n")
  cat(sprintf('(window.FD ??= {})["%s"] = {\n%s\n};\n', name, body), file = file.path(out, "data", paste0(file, ".js")),
      append = TRUE)
}
nrows <- function(raw) {
  f <- tempfile(fileext = ".parquet"); writeBin(raw, f); on.exit(unlink(f))
  get("SELECT count(*) AS n FROM read_parquet('%s')", f)$n
}

report <- list()
for (i in seq_len(nrow(pick))) {
  vid <- pick$vid[i]
  run("CREATE OR REPLACE TEMP TABLE w AS SELECT w1, w2 FROM win WHERE vid = %d", vid)
  p <- as.list(get("SELECT year(w1)::INTEGER AS \"from\", year(w2)::INTEGER AS \"to\" FROM w"))
  # the trips kept: overlapping the window, or on its pings; their hauls; the landings in it or from those trips
  run("CREATE OR REPLACE TEMP TABLE kt AS SELECT %s AS key, T2 FROM (%s)
       WHERE (T1 <= %s AND T2 >= %s) OR %s IN (SELECT key FROM jt WHERE vid = %d)", TID, SQL$trips(vid, p), W2, W1, TID, vid)
  run("CREATE OR REPLACE TEMP TABLE ks AS SELECT DISTINCT %s AS key FROM (%s) WHERE %s IN (SELECT key FROM kt)",
      SID, SQL$stations(vid, p), TID)
  run("CREATE OR REPLACE TEMP TABLE kl AS SELECT DISTINCT %s AS key, date FROM (%s)
       WHERE CAST(date AS DATE) BETWEEN CAST(%s AS DATE) AND CAST(%s AS DATE)
          OR %s IN (SELECT concat(\".lid\", '|', schema_land) FROM %s WHERE %s IN (SELECT key FROM kt))",
      LID, SQL$landings(vid, p), W1, W2, LID, src("curated", "logbook", "lid_map.parquet"), TID)
  in_win <- sprintf("time BETWEEN %s AND %s", W1, W2)
  in_kt <- sprintf("%s IN (SELECT key FROM kt)", TID)
  last_trip <- sprintf("%s = (SELECT key FROM kt ORDER BY T2 DESC NULLS LAST, key DESC LIMIT 1)", TID)
  a <- list(
    trail = answer(con, "trail", vid, p, in_win),
    trail_years = answer(con, "trail_years", vid, p, inner = sprintf(
      "SELECT year(time)::INTEGER AS year, count(*) AS n, min(time) AS time_first, max(time) AS time_last FROM (%s)
       WHERE %s GROUP BY 1 ORDER BY 1", SQL$trail(vid, p), in_win)),
    voyages = answer(con, "voyages", vid, p, sprintf("T1 >= %s AND T2 <= %s", W1, W2)),
    port_calls = answer(con, "port_calls", vid, p, sprintf("T_out >= %s AND T_in <= %s", W1, W2)),
    trips = answer(con, "trips", vid, p, in_kt),
    stations = answer(con, "stations", vid, p, in_kt),
    station_catch = answer(con, "station_catch", vid, p, sprintf("%s IN (SELECT key FROM ks)", SID)),
    windows = answer(con, "windows", vid, p, in_kt),
    landings = answer(con, "landings", vid, p, sprintf("%s IN (SELECT key FROM kl)", LID)),
    trip_summary = answer(con, "trip_summary", vid, p, in_kt),
    landing_trips = answer(con, "landing_trips", vid, p, in_kt),
    `trips/n1` = answer(con, "trips", vid, p, last_trip),
    `stations/n1` = answer(con, "stations", vid, p, last_trip),
    `landings/n1` = answer(con, "landings", vid, p, sprintf(
      "%s = (SELECT key FROM kl ORDER BY date DESC, key DESC LIMIT 1)", LID)))
  run("INSERT INTO stats SELECT %d, year(min(time))::INTEGER, CAST(max(time) AS DATE), (SELECT CAST(max(date) AS DATE) FROM kl)
       FROM (%s) WHERE %s", vid, SQL$trail(vid, p), in_win)
  write_js(paste0("v", pick$n[i]), a)
  report[[i]] <- data.frame(n = pick$n[i], gear = pick$gear[i], days = get(
    "SELECT round(date_diff('minute', w1, w2) / 1440, 1) AS d FROM w")$d, pings = nrows(a$trail), trips = nrows(a$trips),
    hauls = nrows(a$stations), landing_species = nrows(a$landings), kB = round(sum(lengths(a)) / 1024))
  cat(sprintf("vessel %2d of %d done\n", i, nrow(pick)))
}

# The vessel list and the register's empty answers -------------------------------------------------------------------
duckdb::duckdb_register(con, "pick", pick[c("vid", "n")])
vessels <- answer(con, "vessels", 0L, inner = sprintf(
  "SELECT k.n AS vid, 'Vessel ' || lpad(k.n::VARCHAR, 2, '0') AS vessel, nullif(v.cs, v.cs) AS cs,
          nullif(v.mmsi, v.mmsi) AS mmsi, nullif(v.imo, v.imo) AS imo, nullif(v.uid, v.uid) AS uid,
          nullif(v.names, v.names) AS names, nullif(v.status, v.status) AS status,
          s.first_year, s.last_ping, s.last_landing, false AS photo
   FROM (%s) v JOIN pick k ON k.vid = v.vid JOIN stats s ON s.vid = v.vid ORDER BY k.n", SQL$vessels(0L, list())))
empty <- c(list(photos = answer(con, "photos", 0L, where = "FALSE"), register = answer(con, "register", 0L, where = "FALSE")),
           stats::setNames(lapply(names(HIST), function(t) answer(con, "hist", 0L, list(table = t), where = "FALSE")),
                           paste0("hist/", names(HIST))))
write_js("vessels", list(vessels = vessels))
write_js("vessels", empty, name = "empty")

# The page, the README and the key -------------------------------------------------------------------------------------
read_text <- function(f) paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
swap <- function(s, from, to) {   # once, literally, or stop: the page has changed under this script
  at <- gregexpr(from, s, fixed = TRUE)[[1]]
  if (length(at) != 1 || at < 0) stop("'", from, "' is not in the page once: update vessel_demo.R", call. = FALSE)
  paste0(substr(s, 1, at - 1), to, substr(s, at + nchar(from), nchar(s)))
}
page <- read_text("products/vessel_overview/www/index.html") |>
  swap('<meta name="mapbox-token" content="%%MAPBOX_TOKEN%%">',
       sprintf('<meta name="mapbox-token" content="">\n<meta name="bundle" content="%s">', LABEL)) |>
  swap("<title>Vessel overview</title>", "<title>Vessel overview: demo</title>") |>
  swap("<h1>Vessel overview</h1>", "<h1>Vessel overview: demo</h1>") |>
  swap('<script type="module" src="/www/app.js"></script>',
       paste0('<script type="module">\n', read_text("products/vessel_overview/www/app.js"), "\n</script>"))
writeLines(enc2utf8(page), file.path(out, "index.html"), useBytes = TRUE)

commit <- system("git rev-parse --short HEAD", intern = TRUE)
dirty <- length(system("git status --porcelain --untracked-files=no", intern = TRUE)) > 0
readme <- c(
  "# Vessel overview: demo", "",
  sprintf("%s. Built %s from fishycode %s%s at the Marine and Freshwater Research Institute (MFRI, Hafrannsóknastofnun).",
          LABEL, format(Sys.Date()), commit, if (dirty) " (with uncommitted changes)" else ""),
  "", "**Confidential.** Shared under an agreement with MFRI: do not pass it on, publish it, or try to identify the vessels.",
  "", "## To open it", "",
  "Unzip the folder and double-click `index.html`. It opens in your web browser (a recent Chrome, Edge, Firefox or",
  "Safari). Nothing to install. It needs the internet: the libraries come from cdn.jsdelivr.net and the map from Esri.",
  "Keep `index.html` and the `data` folder together.", "",
  "Choose a vessel, then move the time window with the slider, the chart or the trip table. The cards under the map and",
  "chart give the window's activity, hauls and landings. Every panel folds to its bar: open the activity record under the",
  "chart, a trip for its hauls, a haul for every field of its record, where the logbook and the AIS track disagree.", "",
  "## What is in it", "",
  sprintf("- The vessels: %d of those with a logbook trip on an AIS voyage overlapping %s, drawn at random within",
          nrow(pick), MONTH_NAME),
  sprintf("  their main gear (%s).", paste(sprintf("%s %d", names(N_BY_GEAR), N_BY_GEAR), collapse = ", ")),
  "- Each vessel's window runs from the start of its first voyage overlapping the month to the end of its last. In it,",
  "  as MFRI's processing left them: the AIS pings with speed, the fishing flag and effort; voyages and port calls; the",
  "  logbook trips, hauls and catch; the landings.",
  "- Anonymised: vessel numbers and names are made up; no call sign, MMSI, IMO, register, owner or photo. Ports, positions",
  "  and the record ids of the logbook and landings are as recorded.", "",
  "This demo and its README were prepared with the help of an AI coding assistant (Claude Code).")
writeLines(enc2utf8(readme), file.path(out, "README.md"), useBytes = TRUE)

key <- merge(pick, get("SELECT vid, strftime(w1, '%%Y-%%m-%%d %%H:%%M') AS w1, strftime(w2, '%%Y-%%m-%%d %%H:%%M') AS w2 FROM win"))
utils::write.csv(key[order(key$n), c("n", "vid", "gear", "w1", "w2")], keyfile, row.names = FALSE)
invisible(processx::run("zip", c("-r9Xq", basename(zipfile), NAME), wd = dirname(out)))

# Checks ---------------------------------------------------------------------------------------------------------------
report <- do.call(rbind, report)
print(report, row.names = FALSE)
f <- tempfile(fileext = ".parquet"); writeBin(vessels, f)
v <- get("SELECT * FROM read_parquet('%s')", f)
stopifnot(
  "a vessel has no ping" = all(report$pings > 0),
  "a vessel has no logbook trip" = all(report$trips > 0),
  "the list is not the draw" = nrow(v) == nrow(pick) && setequal(v$vid, pick$n),
  "the list names a vessel" = all(is.na(v$cs) & is.na(v$mmsi) & is.na(v$imo) & is.na(v$uid) & is.na(v$names) & is.na(v$status)),
  "a register answer is not empty" = all(vapply(empty, nrows, 0) == 0),
  "a vessel's answer carries a vessel column" =
    !any(c("vid", "vessel", "cs", "mmsi", "imo", "uid", "name", "names", PERSONAL) %in%
           unlist(ALLOW[setdiff(names(ALLOW), c("vessels", "register", "photos", grep("^hist_", names(ALLOW), value = TRUE)))])))
cat(sprintf("%s: %.1f MB, zipped %.1f MB; the key is %s\n", out,
            sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))) / 2^20, file.size(zipfile) / 2^20, keyfile))
