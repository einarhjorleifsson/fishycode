# app.R — the effort map's web app: the page, /meta and the vector tiles, as an httpuv app.
# Decision 220. Used by server.R (a terminal) and effort_map.R (an R session).
#
# Input:  the base grid `grid` (grid.R), the page in the folder `www`; $FISHYDATA/curated/reference/gear.parquet;
#         effort_tile() from tiles.R, sourced by the caller with this file
# Output: effort_map_app(con, grid, www), an httpuv app:
#   /                                   the page; its query string sets the first view (effort_map.R)
#   /meta                               the gears (with their hours), the years, the grid's version and the app's, as JSON
#   /tiles/{z}/{x}/{y}.pbf?preset=fishing|fishing_flow&gid=6,7&y1=2015&y2=2020&px=1
#                                       one vector tile (tiles.R); gid, y1/y2 and px may be left out

APP_VERSION <- 2L     # what effort_map.R asks of a server it finds on its port
PX <- c(0.5, 1, 2)    # the page's cell sizes, in screen pixels per cell

effort_map_app <- function(con, grid, www) {
  meta <- local({
    g <- DBI::dbGetQuery(con, sprintf(
      "SELECT g.gid, any_value(r.\"veiðarfæri\") AS name, any_value(r.gear) AS fao, sum(g.h) AS h
       FROM read_parquet('%s') g LEFT JOIN read_parquet('%s') r ON r.gid = g.gid AND r.version = 'new'
       WHERE g.preset = 'fishing' AND g.gid IS NOT NULL GROUP BY g.gid ORDER BY h DESC",
      grid, fd_curated("reference", "gear.parquet")))
    y <- DBI::dbGetQuery(con, sprintf("SELECT min(year) AS y1, max(year) AS y2 FROM read_parquet('%s')", grid))
    list(gears = g, y1 = y$y1, y2 = y$y2, app = APP_VERSION)
  })

  parse_query <- function(q) {
    kv <- strsplit(strsplit(sub("^[?]", "", q %||% ""), "&", fixed = TRUE)[[1]], "=", fixed = TRUE)
    stats::setNames(lapply(kv, function(x) httpuv::decodeURIComponent(if (length(x) > 1) x[2] else "")),
                    vapply(kv, `[`, "", 1))
  }
  whole <- function(x, lo, hi) {
    if (is.null(x) || !grepl("^[0-9]+$", x)) return(NULL)
    v <- as.integer(x)
    if (v < lo || v > hi) NULL else v
  }
  reply <- function(status, body, type = "text/plain; charset=utf-8", headers = list())
    list(status = status, headers = c(list(`Content-Type` = type), headers), body = body)

  list(call = function(req) {
    path <- req$PATH_INFO
    if (req$REQUEST_METHOD != "GET") return(reply(405L, "GET only"))
    if (path == "/") return(reply(200L, paste(readLines(file.path(www, "index.html"), warn = FALSE, encoding = "UTF-8"),
                                              collapse = "\n"), "text/html; charset=utf-8", list(`Cache-Control` = "no-store")))
    # v, the grid's write time, goes into the tile address, so a rebuilt grid is not hidden by the browser's cache
    if (path == "/meta") return(reply(200L, as.character(jsonlite::toJSON(c(meta, v = as.numeric(file.mtime(grid))),
                                                                         auto_unbox = TRUE, digits = NA)),
                                       "application/json; charset=utf-8", list(`Cache-Control` = "no-store")))
    m <- regmatches(path, regexec("^/tiles/([0-9]+)/([0-9]+)/([0-9]+)[.]pbf$", path))[[1]]
    if (length(m) != 4) return(reply(404L, "not found"))
    z <- whole(m[2], 0L, 16L)
    if (is.null(z)) return(reply(400L, "z is 0-16"))
    x <- whole(m[3], 0L, 2L^z - 1L); y <- whole(m[4], 0L, 2L^z - 1L)
    if (is.null(x) || is.null(y)) return(reply(400L, "x and y lie in the zoom's range"))
    a <- parse_query(req$QUERY_STRING)
    preset <- a$preset %||% "fishing"
    if (!preset %in% c("fishing", "fishing_flow")) return(reply(400L, "preset is fishing or fishing_flow"))
    gid <- if (!is.null(a$gid) && nzchar(a$gid)) {
      g <- strsplit(a$gid, ",", fixed = TRUE)[[1]]
      if (!all(grepl("^[0-9]{1,4}$", g))) return(reply(400L, "gid is whole numbers, comma separated"))
      as.integer(g)
    }
    y1 <- whole(a$y1, 1900L, 2100L); y2 <- whole(a$y2, 1900L, 2100L)
    if (xor(is.null(y1), is.null(y2))) return(reply(400L, "y1 and y2 are years, given together"))
    px <- suppressWarnings(as.numeric(a$px %||% "1"))
    if (!isTRUE(px %in% PX)) return(reply(400L, paste("px is one of", paste(PX, collapse = ", "))))
    t0 <- Sys.time()
    body <- effort_tile(con, grid, z, x, y, preset, gid, y1, y2, px)
    reply(200L, body, "application/vnd.mapbox-vector-tile",
          list(`Cache-Control` = "max-age=600",
               `X-Server-Ms` = sprintf("%.0f", 1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")))))
  })
}
