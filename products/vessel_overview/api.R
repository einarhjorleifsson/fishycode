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
# - The register history stops on 2023-12-19 (plan 028 step 6 is not built); the page labels it (ask g).
# - The photos are a newspaper's images, for internal use only: served to the page, from the files the index lists.
# - The page is www/index.html with the Mapbox token put in as it is served, and its script under /www.

PERSONAL <- c("national_identity_no", "national_identity_no_source", "identity_no", "address", "postal_no", "town",
              "phone", "website", "operator", "exif_copyright")

ALLOW <- list(
  vessels  = c("vid", "vessel", "cs", "mmsi", "imo", "status"),
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
               "station_type", "gid", "gear", "target", "duration_m", "effort", "effort_unit"),
  station_catch = c(".sid", "schema", "sid", "catch", "catch_whole", "condition"),
  trail_years = c("year", "n", "time_first", "time_last"),
  trail    = c("time", "lon", "lat", "speed", "heading", "provider", "voyage", "stay", ".tid", "schema", ".sid", "gear",
               "phase", "fishing_flow"),
  photos   = c("image_no", "kind", "file", "width", "height", "exif_date", "exif_artist", "best", "use")
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

# The SQL of each endpoint, for one vid; `p` holds the query string's other values, already checked
SQL <- list(
  vessels  = function(vid, p) sprintf("SELECT * FROM %s", src("curated", "vessel", "vessel.parquet")),
  register = function(vid, p) sprintf("SELECT * FROM %s WHERE vid = %d", src("curated", "vessel", "vessel.parquet"), vid),
  hist     = function(vid, p) {
    by <- if (p$table == "events") "date DESC" else "valid_from DESC"
    sprintf("SELECT * FROM %s WHERE registration_no = %d ORDER BY %s",
            src("curated", "vessel", "skipaskra", paste0(HIST[[p$table]], ".parquet")), vid, by)
  },
  landings = function(vid, p) sprintf(
    "WITH l AS (SELECT * FROM %s WHERE vid = %d ORDER BY date DESC LIMIT %d)
     SELECT l.\".lid\", l.schema, l.date, l.pid, pt.port, c.gid, g.gear, g.\"veiðarfæri\" AS gear_name, c.sid,
            sum(c.catch) AS catch
     FROM l JOIN %s c USING (\".lid\", schema)
     LEFT JOIN (SELECT pid, any_value(port) AS port FROM %s GROUP BY pid) pt USING (pid)
     LEFT JOIN %s g ON g.gid = c.gid AND g.version = CASE WHEN l.schema = 'lods' THEN 'old' ELSE 'new' END
     GROUP BY ALL ORDER BY l.date DESC, l.\".lid\", catch DESC",
    src("curated", "landing", "landings.parquet"), vid, p$n, src("curated", "landing", "catch.parquet"),
    src("curated", "reference", "port.parquet"), src("curated", "reference", "gear.parquet")),
  trips    = function(vid, p) sprintf(
    "SELECT * FROM %s WHERE vid = %d AND (twin IS NULL OR twin <> 'duplicate') ORDER BY T2 DESC LIMIT %d",
    src("curated", "logbook", "trip.parquet"), vid, p$n),
  stations = function(vid, p) sprintf(
    "WITH t AS (%s)
     SELECT s.*, f.t1, f.t2, f.t3, f.t4, f.gid, f.gear, f.target, f.duration_m, f.effort, f.effort_unit
     FROM %s s JOIN t USING (\".tid\", schema) LEFT JOIN %s f USING (\".sid\", schema)
     WHERE s.twin IS NULL OR s.twin <> 'duplicate' ORDER BY s.date DESC",
    SQL$trips(vid, p), src("curated", "logbook", "station.parquet"), src("curated", "logbook", "fishing_sample.parquet")),
  station_catch = function(vid, p) sprintf(
    "WITH s AS (%s) SELECT c.* FROM %s c JOIN (SELECT \".sid\", schema FROM s) USING (\".sid\", schema)",
    SQL$stations(vid, p), src("curated", "logbook", "catch.parquet")),
  trail_years = function(vid, p) sprintf(
    "SELECT year::INTEGER AS year, count(*) AS n, min(time) AS time_first, max(time) AS time_last FROM %s
     WHERE vid = %d GROUP BY year ORDER BY year", TRAIL(), vid),
  trail    = function(vid, p) sprintf("SELECT * FROM %s WHERE vid = %d ORDER BY time", TRAIL(p$year), vid),
  photos   = function(vid, p) sprintf(
    "SELECT *, regexp_extract(path, '[^/]+$') AS file FROM %s WHERE vid = %d AND kind <> 'missing'
     ORDER BY best DESC, kind, image_no", src("staging", "mbl", "photo.parquet"), vid)
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
  list(status = status, headers = list(`Content-Type` = type, `Cache-Control` = "no-store"), body = body)

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
    if (endpoint == "hist") {
      if (is.null(a$table) || !a$table %in% names(HIST)) return(reply(400L, paste("table is one of", paste(names(HIST), collapse = ", "))))
      p$table <- a$table
    }
    if (endpoint == "trail") {
      p$year <- if (is.null(a$year)) latest_year(con, vid) else int_arg(a$year, 1990L, 2100L)
      if (is.null(p$year)) return(reply(404L, "no trail for this vid"))
    }
    t0 <- Sys.time()
    body <- answer(con, endpoint, vid, p)
    r <- reply(200L, body, "application/vnd.apache.parquet")
    r$headers$`X-Server-Ms` <- sprintf("%.0f", 1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")))
    r
  }
  list(call = call, staticPaths = if (dir.exists(www)) list(`/www` = httpuv::staticPath(www, indexhtml = FALSE, headers = list(`Cache-Control` = "no-store"))) else list())
}
