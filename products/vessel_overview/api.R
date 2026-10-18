# The vessel overview's R service: fixed endpoints, a column allowlist, one vessel's rows as parquet.
# Plan 030 step 3; decision 137 (asks a-h). A consumer of the sweep, run on demand, never a target.
#
# Input:  curated/vessel/vessel.parquet; curated/vessel/skipaskra/vessel_hist, vessel_identification_hist,
#         vessel_measurement_hist, vessel_owners_hist, vessel_fishery_hist, vessel_event; curated/landing/landings,
#         catch; curated/logbook/trip, station, fishing_sample, catch; curated/ais/trail/; curated/reference/gear, port;
#         staging/mbl/photo.parquet and the image files it lists
# Output: nothing written. Each endpoint answers as parquet (zstd), which DuckDB-WASM reads in the page (ask h).
#
# - Every endpoint names its columns in ALLOW, and the response is `SELECT <those columns>`, so nothing else leaves
#   the service. PERSONAL lists the columns that must never leave (decision 137, ask e): kennitala, addresses,
#   postal codes, towns, phones, web pages, and the EXIF copyright strings. check.R tests both.
# - Owners' and operators' names are served, as the register prints them (ask e).
# - A landing's gear code is the new one for agf and the old one for lods (curate/corrections/logbook_gear.R), so
#   its name comes from the version of the gear table that matches its schema.
# - Twin records (decision 094): trips and stations marked `duplicate` are left out.
# - A haul's gear is the settled one of curated/logbook/gear.parquet (`gid_used`, with `gid_basis` as `gear_basis`):
#   the fishing sample has none for adb, which the landings fill (curate/corrections/logbook_gear.R).
# - The register history stops on 2023-12-19 (plan 028 step 6 is not built); the page labels it (ask g).
# - The photos are a newspaper's images, for internal use only: served to the page, from the files the index lists.
# - The page is www/index.html with the Mapbox token put in as it is served, and its script under /www.

# The service's version, sent with every answer. The page carries the same string and says so plainly when they differ:
# a server started before its code changed answers the new page wrongly. Change both together (www/app.js, API).
API_VERSION <- "2026-10-18.4"

PERSONAL <- c("national_identity_no", "national_identity_no_source", "identity_no", "address", "postal_no", "town",
              "phone", "website", "operator", "exif_copyright")

ALLOW <- list(
  vessels  = c("vid", "vessel", "cs", "mmsi", "imo", "status", "first_year", "last_ping", "last_landing", "photo"),
  register = c("vid", "vessel", "cs", "mmsi", "imo", "uid", "flag", "status", "mclass", "loa", "kw", "n_engines",
               "kw_total", "grt", "bwt", "nwt", "yh1", "yh2", "mmsi_t1", "mmsi_t2", "note_date", "note_fate",
               "register", "source"),
  hist_vessel = c("valid_from", "valid_to", "window_from", "window_to", "source", "basis", "status", "rule",
                  "disputed", "name", "usage_category", "construction_year", "construction_country",
                  "construction_place", "construction_station", "hull_material", "horse_power", "power_kw", "imo_no",
                  "previous_name", "changes", "classification_society"),
  hist_identification = c("valid_from", "valid_to", "window_from", "window_to", "source", "basis", "status", "rule",
                          "disputed", "home_port", "region_acronym", "region_no", "call_sign"),
  hist_measurement = c("valid_from", "valid_to", "window_from", "window_to", "source", "basis", "status", "rule",
                       "disputed", "length", "max_length", "brutto_weight_tons", "brutto_grt", "netto_weight_tons",
                       "width", "depth", "draft"),
  hist_owners    = c("valid_from", "valid_to", "source", "basis", "name", "percentage"),
  hist_operators = c("valid_from", "valid_to", "window_from", "window_to", "source", "basis", "status", "rule", "name"),
  hist_events    = c("event", "date", "window", "year", "fate", "fate_class", "source", "basis"),
  landings = c(".lid", "schema", "date", "pid", "port", "gid", "gear", "gear_name", "sid", "catch"),
  trips    = c(".tid", "schema", "T1", "T2", "pid1", "pid2", "port", "n_crew", "source", "T1_basis", "T2_basis"),
  stations = c(".sid", ".tid", "schema", "date", "t1", "t2", "t3", "t4", "lon1", "lat1", "lon2", "lat2", "z1", "z2",
               "station_type", "gid", "gear", "gear_basis", "target", "duration_m", "effort", "effort_unit"),
  station_catch = c(".sid", "schema", "sid", "catch", "catch_whole", "condition"),
  trail_years = c("year", "n", "time_first", "time_last"),
  trail    = c("time", "lon", "lat", "speed", "heading", "provider", "voyage", "stay", ".tid", "schema", ".sid", "gear",
               "phase", "fishing_flow", "hours"),
  photos   = c("image_no", "kind", "file", "width", "height", "exif_date", "exif_artist", "best", "use"),
  landing_trips = c(".lid", "schema_land", ".tid", "schema", "match_type"),
  trip_summary  = c(".tid", "schema", "T1", "T2", "port", "stations", "catch")
)

HIST <- c(vessel = "vessel_hist", identification = "vessel_identification_hist",
          measurement = "vessel_measurement_hist", owners = "vessel_owners_hist", operators = "vessel_fishery_hist",
          events = "vessel_event")

# Where the inputs are: fd_path(), not fd_curated(), which would create a missing directory
src <- function(...) sprintf("read_parquet('%s')", fd_path(...))
TRAIL <- function(year = NULL) sprintf("read_parquet('%s', hive_partitioning = true)",
                                       fd_path("curated", "ais", "trail", if (is.null(year)) "*" else sprintf("year=%d", year),
                                               "*", "*.parquet"))
q <- function(x) paste0('"', x, '"')

# A time-based endpoint answers either a range of years (p$from, p$to) or the latest p$n records
ranged <- function(p) !is.null(p$from) && !is.null(p$to)
scope <- function(p, col, order) if (ranged(p)) sprintf("AND year(%s) BETWEEN %d AND %d", col, p$from, p$to) else
  sprintf("ORDER BY %s LIMIT %d", order, p$n)

# The SQL of each endpoint, for one vid; `p` holds the query string's other values, already checked
SQL <- list(
  # Every vessel the register or the trail knows, with what the list shows: first year and last ping on the trail,
  # last landing, and whether there is a photo. About a second; the app keeps the answer until it is restarted.
  vessels  = function(vid, p) sprintf(
    "WITH v AS (SELECT vid, vessel, cs, mmsi, imo, status FROM %s),
          tr AS (SELECT vid, min(year)::INTEGER AS first_year, CAST(max(time) AS DATE) AS last_ping FROM %s GROUP BY vid),
          l AS (SELECT vid, max(date) AS last_landing FROM %s GROUP BY vid),
          ph AS (SELECT vid, true AS photo FROM %s WHERE best GROUP BY vid)
     SELECT coalesce(v.vid, tr.vid) AS vid, v.vessel, v.cs, v.mmsi, v.imo, v.status, tr.first_year, tr.last_ping,
            l.last_landing, coalesce(ph.photo, false) AS photo
     FROM v FULL JOIN tr ON v.vid = tr.vid
     LEFT JOIN l ON l.vid = coalesce(v.vid, tr.vid) LEFT JOIN ph ON ph.vid = coalesce(v.vid, tr.vid)
     ORDER BY vid",
    src("curated", "vessel", "vessel.parquet"), TRAIL(), src("curated", "landing", "landings.parquet"),
    src("staging", "mbl", "photo.parquet")),
  register = function(vid, p) sprintf("SELECT * FROM %s WHERE vid = %d", src("curated", "vessel", "vessel.parquet"), vid),
  hist     = function(vid, p) {
    by <- if (p$table == "events") "date DESC" else "valid_from DESC"
    sprintf("SELECT * FROM %s WHERE registration_no = %d ORDER BY %s",
            src("curated", "vessel", "skipaskra", paste0(HIST[[p$table]], ".parquet")), vid, by)
  },
  landings = function(vid, p) sprintf(
    "WITH l AS (SELECT * FROM %s WHERE vid = %d %s)
     SELECT l.\".lid\", l.schema, l.date, l.pid, pt.port, c.gid, g.gear, g.\"veiðarfæri\" AS gear_name, c.sid,
            sum(c.catch) AS catch
     FROM l JOIN %s c USING (\".lid\", schema)
     LEFT JOIN (SELECT pid, any_value(port) AS port FROM %s GROUP BY pid) pt USING (pid)
     LEFT JOIN %s g ON g.gid = c.gid AND g.version = CASE WHEN l.schema = 'lods' THEN 'old' ELSE 'new' END
     GROUP BY ALL ORDER BY l.date DESC, l.\".lid\" DESC, catch DESC",
    src("curated", "landing", "landings.parquet"), vid, scope(p, "date", "date DESC, \".lid\" DESC"),
    src("curated", "landing", "catch.parquet"),
    src("curated", "reference", "port.parquet"), src("curated", "reference", "gear.parquet")),
  trips    = function(vid, p) sprintf(
    "SELECT * FROM %s WHERE vid = %d AND (twin IS NULL OR twin <> 'duplicate') %s",
    src("curated", "logbook", "trip.parquet"), vid, scope(p, "T2", "T2 DESC")),
  stations = function(vid, p) sprintf(
    "WITH t AS (%s)
     SELECT s.*, f.t1, f.t2, f.t3, f.t4, g.gid_used AS gid, g.gear, g.gid_basis AS gear_basis, g.target, f.duration_m,
            f.effort, f.effort_unit
     FROM %s s JOIN t USING (\".tid\", schema) LEFT JOIN %s f USING (\".sid\", schema) LEFT JOIN %s g USING (\".sid\", schema)
     WHERE s.twin IS NULL OR s.twin <> 'duplicate' ORDER BY s.date DESC",
    SQL$trips(vid, p), src("curated", "logbook", "station.parquet"), src("curated", "logbook", "fishing_sample.parquet"),
    src("curated", "logbook", "gear.parquet")),
  station_catch = function(vid, p) sprintf(
    "WITH s AS (%s) SELECT c.* FROM %s c JOIN (SELECT \".sid\", schema FROM s) USING (\".sid\", schema)",
    SQL$stations(vid, p), src("curated", "logbook", "catch.parquet")),
  trail_years = function(vid, p) sprintf(
    "SELECT year::INTEGER AS year, count(*) AS n, min(time) AS time_first, max(time) AS time_last FROM %s
     WHERE vid = %d GROUP BY year ORDER BY year", TRAIL(), vid),
  trail    = function(vid, p) sprintf("SELECT * FROM %s WHERE vid = %d AND year BETWEEN %d AND %d ORDER BY time",
                                      TRAIL(), vid, p$from, p$to),
  photos   = function(vid, p) sprintf(
    "SELECT *, regexp_extract(path, '[^/]+$') AS file FROM %s WHERE vid = %d AND kind <> 'missing'
     ORDER BY best DESC, kind, image_no", src("staging", "mbl", "photo.parquet"), vid),
  # Which logbook trip each of the vessel's landings came from (curate/logbook/lid_map.R), for the front tab
  landing_trips = function(vid, p) sprintf(
    "SELECT m.* FROM %s m JOIN (SELECT \".tid\", schema FROM %s WHERE vid = %d) t USING (\".tid\", schema)",
    src("curated", "logbook", "lid_map.parquet"), src("curated", "logbook", "trip.parquet"), vid),
  # One row per trip with its hauls counted and its catch summed: the history tab's list, without every haul
  trip_summary = function(vid, p) sprintf(
    "WITH t AS (%s),
          s AS (SELECT s.\".tid\", s.schema, s.\".sid\" FROM %s s JOIN t USING (\".tid\", schema)
                WHERE s.twin IS NULL OR s.twin <> 'duplicate'),
          n AS (SELECT \".tid\", schema, count(*) AS stations FROM s GROUP BY ALL),
          c AS (SELECT s.\".tid\", s.schema, sum(c.catch) AS catch FROM %s c JOIN s USING (\".sid\", schema) GROUP BY ALL)
     SELECT t.*, coalesce(n.stations, 0) AS stations, c.catch FROM t LEFT JOIN n USING (\".tid\", schema)
     LEFT JOIN c USING (\".tid\", schema) ORDER BY t.T2 DESC",
    SQL$trips(vid, p), src("curated", "logbook", "station.parquet"), src("curated", "logbook", "catch.parquet"))
)

# One endpoint's rows as parquet bytes: the allowlisted columns only
answer <- function(con, endpoint, vid, p = list()) {
  cols <- ALLOW[[if (endpoint == "hist") paste0("hist_", p$table) else endpoint]]
  inner <- SQL[[endpoint]](vid, p)
  tmp <- tempfile(fileext = ".parquet"); on.exit(unlink(tmp))
  DBI::dbExecute(con, sprintf("COPY (SELECT %s FROM (%s)) TO '%s' (FORMAT parquet, COMPRESSION zstd)",
                              paste(q(cols), collapse = ", "), inner, tmp))
  readBin(tmp, "raw", file.size(tmp))
}

# The latest year with pings, the trail endpoint's default
latest_year <- function(con, vid) {
  y <- DBI::dbGetQuery(con, sprintf("SELECT max(year)::INTEGER AS y FROM %s WHERE vid = %d", TRAIL(), vid))$y
  if (is.na(y)) NULL else y
}

# The basemap's token (decision 137, ask c): read from the environment (.Renviron) and put into the page as it is
# served, never into a file in the repository. A Mapbox public token is meant for the browser. Empty if unset or odd.
mapbox_token <- function() {
  tk <- Sys.getenv("MAPBOX_TOKEN")
  if (grepl("^pk[.][A-Za-z0-9._-]+$", tk)) tk else ""
}

# HTTP ---------------------------------------------------------------------------------------------------------------
reply <- function(status, body, type = "text/plain; charset=utf-8")
  list(status = status, headers = list(`Content-Type` = type, `Cache-Control` = "no-store", `X-Overview-Api` = API_VERSION),
       body = body)

parse_query <- function(qs) {
  qs <- sub("^[?]", "", qs %||% "")
  if (!nzchar(qs)) return(list())
  kv <- strsplit(strsplit(qs, "&", fixed = TRUE)[[1]], "=", fixed = TRUE)
  stats::setNames(lapply(kv, function(x) httpuv::decodeURIComponent(if (length(x) > 1) x[2] else "")),
                  vapply(kv, function(x) x[1], ""))
}
int_arg <- function(x, lo, hi) {
  v <- suppressWarnings(as.integer(x))
  if (length(v) != 1 || is.na(v) || v < lo || v > hi || !grepl("^[0-9]+$", x)) NULL else v
}

# The app: httpuv's list(call = ...), with the page's own files under /www
vessel_overview_app <- function(con, www) {
  cache <- new.env()
  call <- function(req) {
    path <- req$PATH_INFO
    a <- parse_query(req$QUERY_STRING)
    if (req$REQUEST_METHOD != "GET") return(reply(405L, "GET only"))
    if (path == "/") {
      f <- file.path(www, "index.html")
      if (!file.exists(f)) return(reply(200L, "vessel overview: the page comes in plan 030 step 4"))
      page <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      return(reply(200L, sub("%%MAPBOX_TOKEN%%", mapbox_token(), page, fixed = TRUE), "text/html; charset=utf-8"))
    }
    if (path == "/photo") {
      vid <- int_arg(a$vid, 1L, 999999L)
      if (is.null(vid) || is.null(a$file) || !grepl("^[0-9]{4}-[0-9]{4}(-thumb)?[.]jpg$", a$file)) return(reply(404L, "not found"))
      hit <- DBI::dbGetQuery(con, sprintf(
        "SELECT path FROM %s WHERE vid = %d AND kind <> 'missing' AND regexp_extract(path, '[^/]+$') = ?",
        src("staging", "mbl", "photo.parquet"), vid), params = list(a$file))
      if (nrow(hit) != 1) return(reply(404L, "not found"))
      f <- fd_path(hit$path)
      return(reply(200L, readBin(f, "raw", file.size(f)), "image/jpeg"))
    }
    if (!startsWith(path, "/api/")) return(reply(404L, "not found"))
    endpoint <- sub("^/api/", "", path)
    if (!endpoint %in% names(SQL)) return(reply(404L, "no such endpoint"))
    vid <- if (endpoint == "vessels") 0L else int_arg(a$vid, 1L, 999999L)
    if (is.null(vid)) return(reply(400L, "vid must be a whole number"))
    p <- list(n = int_arg(a$n %||% "20", 1L, 500L) %||% 20L)
    yr <- function(x) if (is.null(x)) NULL else int_arg(x, 1900L, 2100L)
    p$from <- yr(a$from); p$to <- yr(a$to)
    if (xor(is.null(a$from), is.null(a$to)) || (!is.null(a$from) && (is.null(p$from) || is.null(p$to))))
      return(reply(400L, "from and to are years, given together"))
    if (ranged(p) && p$from > p$to) { y <- p$from; p$from <- p$to; p$to <- y }
    if (endpoint == "hist") {
      if (is.null(a$table) || !a$table %in% names(HIST)) return(reply(400L, paste("table is one of", paste(names(HIST), collapse = ", "))))
      p$table <- a$table
    }
    if (endpoint == "trail" && !ranged(p)) {
      y <- if (is.null(a$year)) latest_year(con, vid) else int_arg(a$year, 1990L, 2100L)
      if (is.null(y)) return(reply(404L, "no trail for this vid"))
      p$from <- p$to <- y
    }
    t0 <- Sys.time()
    body <- if (endpoint == "vessels") (cache$vessels <- cache$vessels %||% answer(con, endpoint, vid, p))
            else answer(con, endpoint, vid, p)
    r <- reply(200L, body, "application/vnd.apache.parquet")
    r$headers$`X-Server-Ms` <- sprintf("%.0f", 1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")))
    r
  }
  list(call = call, staticPaths = if (dir.exists(www)) list(`/www` = httpuv::staticPath(www, indexhtml = FALSE, headers = list(`Cache-Control` = "no-store"))) else list())
}
