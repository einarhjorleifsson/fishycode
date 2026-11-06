# The place-name explorer's R service: fixed endpoints, a column allowlist, the gazetteer as JSON.
# Plan 045 step 1, its first part: read-only, no answers written. A consumer of curated/, run on demand, never a target.
#
# Input:  curated/place_name/{place_name, place, synonym, variant, evidence}.parquet (curate/place_name.R,
#         curate/place_name_evidence.R; plan 044), and name_group.parquet where it is built (curate/name_group.R, plan
#         045 §3.1: one name for the keys of one place); ramb's rb_map_basemaps() (the base maps' addresses, one home),
#         and LMÍ's sea charts (SEA_CHART, Icelandic, so not ramb's)
# Output: nothing written. Each endpoint answers JSON, columns as arrays; the footprints as GeoJSON.
#
# - Every endpoint names its columns in ALLOW, and the answer is `SELECT <those columns>`, so nothing else leaves the
#   service. NOT_SERVED lists the evidence's columns kept back: a finder's free text (`text`, which may name a person),
#   Trackwell's own vessel name (`vessel`; the vid is served) and the source's row id (`source_key`). check.R tests both.
# - The names, places, synonyms, spellings and footprints are read once, when the app is made, and held: the page loads
#   them whole and filters them itself. A name's occurrences are asked one name at a time (up to 30,642 rows, a
#   Trackwell ground).
# - The names from Trackwell's hauls and fishermen's plotters are not public: the service listens on 127.0.0.1 only,
#   and the page is never published (plan 045 §5).

# The service's version, sent with every answer. The page carries the same string and says so when they differ.
API_VERSION <- "2026-11-02.1"

# The sea charts of Sjómælingar Íslands (the Coast Guard's hydrography), as LMÍ's map viewer draws them, from the map
# cache of Náttúrufræðistofnun, which LMÍ joined in 2024: a WMS in web Mercator, one layer per chart scale, each chart
# clipped to its frame. A base of their own, stacked, the smallest scale below, each from the zoom where the chart is
# about at its own scale at 65° N (a MapLibre zoom z is 1:279,541,132 / 2^z at the equator), half a zoom early, to
# three zooms on, where it is drawn at 8 times its size and its tiles are no longer worth asking. The cache's
# all-scales layer (Sjokort_Sjomaelinga) switches by the Mercator scale, which at 65° N shows each chart at 2.4 times
# its size.
SEA_CHART <- local({
  scale <- c(sjokort_2milljon = 2e6, sjokort_1milljon = 1e6, sjokort_300thusund = 3e5, sjokort_K42 = 1.6e5,
             sjokort_100thusund = 1e5, sjokort_K44 = 7e4, sjokort_35_40_50thusund = 4e4, sjokort_15thusund = 1.5e4,
             sjokort_10thusund = 1e4)
  wms <- paste0("https://gis.natt.is/mapcache/sjokort/web-mercador/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
                "&FORMAT=image%2Fpng&TRANSPARENT=TRUE&STYLES=&TILED=true&CRS=EPSG%3A3857&WIDTH=256&HEIGHT=256",
                "&BBOX={bbox-epsg-3857}&LAYERS=Sjomaelingar%3A")
  own <- log2(279541132 * cos(65 * pi / 180) / scale)
  from <- c(0, round(own[-1] - 0.5, 1))   # the smallest from any zoom
  list(id = "sea_chart", label = "Sea charts (LMÍ)", maxzoom = 17,
       attribution = "Sjókort © Sjómælingar Íslands, Landhelgisgæslan; not for navigation",
       layers = unname(Map(function(id, a, b) list(id = id, tiles = paste0(wms, id), minzoom = a, maxzoom = b),
                           names(scale), from, round(own + 3, 1))))
})

NOT_SERVED <- c("text", "vessel", "source_key")

SOURCES <- c("trackwell", "plotter", "lmi", "sjokort", "fiskmerki", "channel", "oracle", "uv", "skjalfandi", "qgis",
             "vestmannaeyjar", "article", "isor")

ALLOW <- list(
  names = c("key", "name", "class", "n_spelling", "n_vessel", "year_first", "year_last", "in_lmi", "lmi_class", "region",
            paste0("n_", SOURCES), "precision", "n_positioned", "lon", "lat", "r80_km", "n_places", "depth_m",
            "slope_deg", "bpi_m", "gear", "gear_share", "parent_key", "parent_basis", "size_km", "min_zoom", "level",
            "families", "n_families", "n_text", "max_family_km", "outcome", "n_synonym", "label_lon", "label_lat",
            "terrain", "n_children"),
  places   = c("key", "place", "main", "lon", "lat", "n", "share", "support", "families"),
  synonyms = c("key_a", "name_a", "key_b", "name_b", "relation", "letters", "km", "n_a", "n_b"),
  variants = c("name", "key", "class", "rule", "repaired_to", "n", "n_positioned", "n_vessel", "sources", "reading",
               "synonym_of"),
  groups   = c("key", "group", "group_name", "basis", "locator", "km", "n_keys", "status"),
  evidence = c("source", "source_table", "name", "name_repaired", "class", "lon", "lat", "position_basis",
               "position_kind", "time", "vid", "gid", "gear", "summary", "square_w", "square_h", "position_flag",
               "region", "lmi_feature", "isor_group", "uv_type")
)

TABLE <- c(names = "place_name", places = "place", synonyms = "synonym", variants = "variant", groups = "name_group",
           evidence = "evidence")

# Where the inputs are: fd_path(), not fd_curated(), which would create a missing directory
src <- function(t) sprintf("read_parquet('%s')", fd_path("curated", "place_name", paste0(t, ".parquet")))
q <- function(x) paste0('"', x, '"')

# One endpoint's allowlisted columns; the evidence's time as text, in UTC as stored
select_sql <- function(endpoint, where = "TRUE", order = "") {
  cols <- ALLOW[[endpoint]]
  cols <- ifelse(cols == "time", "strftime(\"time\", '%Y-%m-%d %H:%M') AS \"time\"", q(cols))
  sprintf("SELECT %s FROM %s WHERE %s %s", paste(cols, collapse = ", "), src(TABLE[[endpoint]]), where, order)
}
as_json <- function(d) enc2utf8(as.character(jsonlite::toJSON(as.list(d), dataframe = "columns", na = "null",
                                                              digits = 5, auto_unbox = FALSE)))

# The footprints: one feature per name that has one (1,783 of 9,281), its key the only property
footprints_geojson <- function() {
  p <- read_curated_sf(fd_path("curated", "place_name", "place_name.parquet"))
  p <- p[!sf::st_is_empty(p), "key"]
  tmp <- tempfile(fileext = ".geojson"); on.exit(unlink(tmp))
  sf::st_write(p, tmp, driver = "GeoJSON", quiet = TRUE, layer_options = "COORDINATE_PRECISION=4")
  paste(readLines(tmp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ramb's base maps, the sea charts before its last, 'none'
base_maps <- function() {
  b <- ramb::rb_map_basemaps()
  append(b, list(SEA_CHART), after = sum(vapply(b, function(x) x$id != "none", logical(1))))
}

# HTTP ---------------------------------------------------------------------------------------------------------------
reply <- function(status, body, type = "text/plain; charset=utf-8")
  list(status = status, headers = list(`Content-Type` = type, `Cache-Control` = "no-store",
                                       `X-Place-Names-Api` = API_VERSION), body = body)
json <- function(body) reply(200L, body, "application/json; charset=utf-8")

parse_query <- function(qs) {
  qs <- sub("^[?]", "", qs %||% "")
  if (!nzchar(qs)) return(list())
  kv <- strsplit(strsplit(qs, "&", fixed = TRUE)[[1]], "=", fixed = TRUE)
  stats::setNames(lapply(kv, function(x) httpuv::decodeURIComponent(if (length(x) > 1) x[2] else "")),
                  vapply(kv, function(x) x[1], ""))
}

# The app: httpuv's list(call = ...), with the page's own files under /www
place_names_app <- function(con, www) {
  held <- list(
    names    = as_json(DBI::dbGetQuery(con, select_sql("names", order = "ORDER BY n_positioned DESC NULLS LAST, key"))),
    places   = as_json(DBI::dbGetQuery(con, select_sql("places", order = "ORDER BY key, place"))),
    synonyms = as_json(DBI::dbGetQuery(con, select_sql("synonyms"))),
    variants = as_json(DBI::dbGetQuery(con, select_sql("variants", order = "ORDER BY key, n DESC"))),
    # the groups only where curate/name_group.R has run: else no rows, and the page shows no group
    groups   = if (file.exists(fd_path("curated", "place_name", "name_group.parquet")))
                 as_json(DBI::dbGetQuery(con, select_sql("groups", order = "ORDER BY \"group\", km")))
               else as_json(stats::setNames(rep(list(character()), length(ALLOW$groups)), ALLOW$groups)),
    # the keys placed by Oracle's squares alone, a position counted as the gazetteer counts one (curate/place_name.R,
    # `placed`): MFRI's coarse grounds (afli_skikar), some covering two places, and orri's and Breiðafjörður's names by
    # square. Anchors, not places: the page draws them aside (maintainer, 2026-11-02)
    square_only = as_json(DBI::dbGetQuery(con, sprintf(
      "SELECT key FROM %s WHERE position_basis <> 'none' AND NOT coalesce(summary, false) AND lon IS NOT NULL
         AND lat IS NOT NULL AND position_flag IS NULL
       GROUP BY key HAVING bool_and(source = 'oracle' AND position_kind = 'square') ORDER BY key", src("evidence")))),
    footprints = footprints_geojson(),
    basemaps = enc2utf8(as.character(jsonlite::toJSON(base_maps(), auto_unbox = TRUE)))
  )
  keys <- DBI::dbGetQuery(con, sprintf("SELECT key FROM %s", src("place_name")))$key
  call <- function(req) {
    path <- req$PATH_INFO
    if (req$REQUEST_METHOD != "GET") return(reply(405L, "GET only"))
    if (path == "/") return(reply(200L, paste(readLines(file.path(www, "index.html"), warn = FALSE, encoding = "UTF-8"),
                                              collapse = "\n"), "text/html; charset=utf-8"))
    if (!startsWith(path, "/api/")) return(reply(404L, "not found"))
    endpoint <- sub("^/api/", "", path)
    if (endpoint %in% names(held)) return(json(held[[endpoint]]))
    if (endpoint != "evidence") return(reply(404L, "no such endpoint"))
    key <- parse_query(req$QUERY_STRING)$key
    if (is.null(key) || !key %in% keys) return(reply(404L, "no such key"))
    t0 <- Sys.time()
    body <- tryCatch(as_json(DBI::dbGetQuery(con, select_sql("evidence", "key = ?", "ORDER BY source, \"time\""),
                                             params = list(key))), error = function(e) e)
    if (inherits(body, "error")) return(reply(500L, conditionMessage(body)))
    r <- json(body)
    r$headers$`X-Server-Ms` <- sprintf("%.0f", 1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")))
    r
  }
  list(call = call, staticPaths = list(`/www` = httpuv::staticPath(www, indexhtml = FALSE,
                                                                   headers = list(`Cache-Control` = "no-store"))))
}
