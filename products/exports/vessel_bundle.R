# The vessel overview as a folder for colleagues at MFRI: every vessel with data from a given year on, named, with no
# photos. Put on the institute's share, it opens with a double click: no R, no server, no shell (the bundle mode of
# decision 153, named).
#
# Input:  what products/vessel_overview/api.R reads, less the photos; products/vessel_overview/www/index.html and app.js
# Output: $FISHYDATA/exports/vessel_overview_<year>/ (index.html, data/*.js, README.md); a test build of a few vids
#         goes to vessel_overview_<year>_test/
#
# Run from the repository root:  Rscript products/exports/vessel_bundle.R [from_year] [vid,vid,...]
#   from_year defaults to 2024; the vids, if given, make a test build of those vessels only.
#
# - The vessels: those with a ping, a logbook trip (by its return) or a landing from from_year on.
# - Each answer is the service's own (api.R: its SQL and its column allowlist) for the years from_year to the trail's
#   last, so the page reads the bundle as it reads the service. The page loads a vessel's window whole and opens on it.
# - Kept: names, call signs, MMSI, the register and its history to 2023-12-19, owners' names included; never kennitala,
#   addresses or phones (api.R's PERSONAL). Left out: the photos. For use inside MFRI only, never sent out.
# - b64(), write_js(), read_text() and swap() are vessel_demo.R's; share them if a third builder comes.

source("R/paths.R")
source("products/vessel_overview/api.R")

args <- commandArgs(trailingOnly = TRUE)
FROM <- if (length(args) >= 1) as.integer(args[1]) else 2024L
TEST <- if (length(args) >= 2) as.integer(strsplit(args[2], ",")[[1]]) else NULL
stopifnot("from_year is a year" = !is.na(FROM) && FROM >= 2007, "the vids are whole numbers" = !anyNA(TEST))

con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(tempdir(), "duckdb_temp")))
get <- function(...) DBI::dbGetQuery(con, sprintf(...))

LAST <- get("SELECT max(year)::INTEGER AS y FROM %s", TRAIL())$y
LABEL <- sprintf("%d–%d", FROM, LAST)
NAME <- sprintf("vessel_overview_%d%s", FROM, if (is.null(TEST)) "" else "_test")
out <- fd_path("exports", NAME)

# The vessels ---------------------------------------------------------------------------------------------------------
vids <- get("SELECT DISTINCT vid FROM (
               SELECT vid FROM %s WHERE year >= %d
               UNION ALL SELECT vid FROM %s WHERE year(T2) >= %d AND (twin IS NULL OR twin <> 'duplicate')
               UNION ALL SELECT vid FROM %s WHERE year(date) >= %d)
             WHERE vid IS NOT NULL ORDER BY vid",
            TRAIL(), FROM, src("curated", "logbook", "trip.parquet"), FROM, src("curated", "landing", "landings.parquet"),
            FROM)$vid
if (!is.null(TEST)) vids <- intersect(vids, TEST)
cat(sprintf("%d vessels with data in %s\n", length(vids), LABEL))

# Each vessel's answers -----------------------------------------------------------------------------------------------
unlink(out, recursive = TRUE)
dir.create(file.path(out, "data"), recursive = TRUE)
b64 <- function(raw) gsub("[\r\n]", "", jsonlite::base64_enc(raw))
write_js <- function(file, x, name = file) {
  body <- paste0('"', names(x), '":"', vapply(x, b64, ""), '"', collapse = ",\n")
  cat(sprintf('(window.FD ??= {})["%s"] = {\n%s\n};\n', name, body), file = file.path(out, "data", paste0(file, ".js")),
      append = TRUE)
}

p <- list(from = FROM, to = LAST)
since <- sprintf("year >= %d", FROM)
key <- "concat(\".tid\", '|', schema)"
t0 <- Sys.time()
for (i in seq_along(vids)) {
  vid <- vids[i]
  # the trips from FROM on, for the answers that are not ranged: the last trip's hauls and the landings' links
  trips_since <- sprintf("%s IN (SELECT %s FROM %s WHERE vid = %d AND year(T2) >= %d)", key, key,
                         src("curated", "logbook", "trip.parquet"), vid, FROM)
  a <- c(list(
    trail_years = answer(con, "trail_years", vid, where = since),
    `landings/n1` = answer(con, "landings", vid, list(n = 1L), where = sprintf("year(date) >= %d", FROM)),
    `trips/n1` = answer(con, "trips", vid, list(n = 1L), where = sprintf("year(T2) >= %d", FROM)),
    `stations/n1` = answer(con, "stations", vid, list(n = 1L), where = trips_since),
    landing_trips = answer(con, "landing_trips", vid, where = trips_since),
    register = answer(con, "register", vid),
    trail = answer(con, "trail", vid, p),
    voyages = answer(con, "voyages", vid, p),
    port_calls = answer(con, "port_calls", vid, p),
    trips = answer(con, "trips", vid, p),
    stations = answer(con, "stations", vid, p),
    station_catch = answer(con, "station_catch", vid, p),
    windows = answer(con, "windows", vid, p),
    landings = answer(con, "landings", vid, p),
    trip_summary = answer(con, "trip_summary", vid, p),
    history_effort = answer(con, "history_effort", vid, list(time = since)),
    history_cells = answer(con, "history_cells", vid, list(time = since))),
    stats::setNames(lapply(names(HIST), function(t) answer(con, "hist", vid, list(table = t))), paste0("hist/", names(HIST))))
  write_js(paste0("v", vid), a)
  if (i %% 100 == 0 || i == length(vids))
    cat(sprintf("%d of %d vessels, %.0f min\n", i, length(vids), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}

# The vessel list and the photos' empty answer ------------------------------------------------------------------------
vessels <- answer(con, "vessels", 0L, inner = sprintf("SELECT * REPLACE (false AS photo) FROM (%s) WHERE vid IN (%s)",
                                                      SQL$vessels(0L, list()), paste(vids, collapse = ", ")))
write_js("vessels", list(vessels = vessels))
write_js("vessels", list(photos = answer(con, "photos", 0L, where = "FALSE")), name = "empty")

# The page and the README ---------------------------------------------------------------------------------------------
read_text <- function(f) paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
swap <- function(s, from, to) {   # once, literally, or stop: the page has changed under this script
  at <- gregexpr(from, s, fixed = TRUE)[[1]]
  if (length(at) != 1 || at < 0) stop("'", from, "' is not in the page once: update vessel_bundle.R", call. = FALSE)
  paste0(substr(s, 1, at - 1), to, substr(s, at + nchar(from), nchar(s)))
}
page <- read_text("products/vessel_overview/www/index.html") |>
  swap('<meta name="mapbox-token" content="%%MAPBOX_TOKEN%%">',
       sprintf('<meta name="mapbox-token" content="">\n<meta name="bundle" content="%s">\n<meta name="bundle-names" content="shown">',
               LABEL)) |>
  swap("<title>Vessel overview</title>", sprintf("<title>Vessel overview %s</title>", LABEL)) |>
  swap("<h1>Vessel overview</h1>", sprintf("<h1>Vessel overview %s</h1>", LABEL)) |>
  swap('<script type="module" src="/www/app.js"></script>',
       paste0('<script type="module">\n', read_text("products/vessel_overview/www/app.js"), "\n</script>"))
writeLines(enc2utf8(page), file.path(out, "index.html"), useBytes = TRUE)

commit <- system("git rev-parse --short HEAD", intern = TRUE)
dirty <- length(system("git status --porcelain --untracked-files=no", intern = TRUE)) > 0
readme <- c(
  sprintf("# Vessel overview %s", LABEL), "",
  sprintf("%d vessels, %s. Built %s from fishycode %s%s at MFRI (Hafrannsóknastofnun).", length(vids), LABEL,
          format(Sys.Date()), commit, if (dirty) " (with uncommitted changes)" else ""),
  "", "**For use inside MFRI only.** It holds vessel names and owners' names: do not send it out or publish it.",
  "", "## To open it", "",
  "Double-click `index.html`. It opens in your web browser (a recent Chrome, Edge or Firefox). Nothing to install.",
  "It needs the internet: the libraries come from cdn.jsdelivr.net and the map from Esri. Keep `index.html` and the",
  "`data` folder together.", "",
  "Choose a vessel; the page opens on its whole window. Move the time window with the slider, the chart or the trip",
  "table. Every panel folds to its bar: open a trip for its hauls, a haul for every field of its record.", "",
  "## What is in it", "",
  sprintf("- Every vessel with an AIS ping, a logbook trip or a landing in %s: the pings with speed, the fishing flag and", LABEL),
  "  effort; voyages and port calls; the logbook trips, hauls and catch; the landings, as MFRI's processing left them.",
  "- The register today and its history to 2023-12-19. No photos.", "",
  "This bundle and its README were prepared with the help of an AI coding assistant (Claude Code).")
writeLines(enc2utf8(readme), file.path(out, "README.md"), useBytes = TRUE)

# Checks ----------------------------------------------------------------------------------------------------------------
stopifnot("an answer may carry a personal column" = !any(PERSONAL %in% unlist(ALLOW)),
          "a vessel has no file" = all(file.exists(file.path(out, "data", paste0("v", vids, ".js")))))
cat(sprintf("%s: %d vessels, %.1f MB\n", out, length(vids),
            sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))) / 2^20))
