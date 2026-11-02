# Checks the place-name explorer's R service: the column allowlist, every endpoint's answer and the time it takes, and
# the requests it must refuse. Stops at the first failure.
#
# Input:  what products/place_names/api.R reads
# Output: a printed table; nothing written
#
# Run from the repository root:  Rscript products/place_names/check.R
# It calls the app in this process, with no server: the same code a request reaches. The occurrences are asked for the
# name with the most (a Trackwell ground), one with several places, and one with no position.

source("R/paths.R")
source("R/write_curated.R")
source("products/place_names/api.R")

con <- DBI::dbConnect(duckdb::duckdb())
t0 <- Sys.time()
app <- place_names_app(con, "products/place_names/www")
cat(sprintf("app made in %.1f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
get <- function(path, query = "", method = "GET")
  app$call(list(REQUEST_METHOD = method, PATH_INFO = path, QUERY_STRING = query))

# 1. Nothing kept back is allowlisted, and every allowlisted column exists ----------------------------------------------
stopifnot("a column kept back is allowlisted" = !any(unlist(ALLOW) %in% NOT_SERVED))
built <- file.exists(fd_path("curated", "place_name", "name_group.parquet"))   # the groups, once curate/name_group.R has run
for (e in names(ALLOW)) {
  if (e == "groups" && !built) next
  have <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM %s", src(TABLE[[e]])))$column_name
  miss <- setdiff(ALLOW[[e]], have)
  if (length(miss)) stop(e, ": no column ", paste(miss, collapse = ", "))
}

# 2. Every endpoint: columns exactly as allowlisted, rows and time ------------------------------------------------------
pick <- DBI::dbGetQuery(con, sprintf(
  "(SELECT key, 'most occurrences' AS why FROM %1$s ORDER BY n_positioned DESC LIMIT 1)
   UNION ALL (SELECT key, 'several places' FROM %1$s WHERE n_places > 2 ORDER BY n_positioned DESC LIMIT 1)
   UNION ALL (SELECT key, 'no position' FROM %1$s WHERE n_positioned = 0 ORDER BY key LIMIT 1)", src("place_name")))
asks <- c(as.list(c("names", "places", "synonyms", "variants", "groups")), lapply(pick$key, function(k) c("evidence", k)))
out <- do.call(rbind, lapply(asks, function(a) {
  t1 <- Sys.time()
  r <- get(paste0("/api/", a[1]), if (length(a) > 1) paste0("key=", utils::URLencode(a[2], reserved = TRUE)) else "")
  ms <- 1000 * as.numeric(difftime(Sys.time(), t1, units = "secs"))
  if (r$status != 200L) stop(a[1], " answered ", r$status, ": ", r$body)
  if (!identical(r$headers$`X-Place-Names-Api`, API_VERSION)) stop(a[1], ": no version header")
  d <- jsonlite::fromJSON(r$body)
  if (!identical(names(d), ALLOW[[a[1]]])) stop(a[1], ": columns differ from the allowlist")
  if (any(names(d) %in% NOT_SERVED)) stop(a[1], ": a column kept back left the service")
  data.frame(endpoint = a[1], key = if (length(a) > 1) a[2] else "", rows = length(d[[1]]),
             kb = round(nchar(r$body, "bytes") / 1024), ms = round(ms))
}))
print(out, row.names = FALSE)

# 3. The footprints and the base maps --------------------------------------------------------------------------------
f <- get("/api/footprints")
fp <- jsonlite::fromJSON(f$body, simplifyVector = FALSE)
stopifnot(f$status == 200L, identical(fp$type, "FeatureCollection"),
          all(vapply(fp$features, function(x) identical(names(x$properties), "key"), logical(1))))
cat(sprintf("footprints: %d features, %.1f MB\n", length(fp$features), nchar(f$body, "bytes") / 1e6))
stopifnot(get("/api/basemaps")$status == 200L, get("/")$status == 200L)
# the keys drawn aside, placed by Oracle's squares alone: keys only, each a name, the coarse grounds among them
s <- jsonlite::fromJSON(get("/api/square_only")$body)
keys <- DBI::dbGetQuery(con, sprintf("SELECT key FROM %s", src("place_name")))$key
stopifnot(identical(names(s), "key"), all(s$key %in% keys), c("skaftskeidarardjup", "skerjaogrindvikurdjup") %in% s$key)
cat(sprintf("square_only: %d keys\n", length(s$key)))

# 4. What it must refuse --------------------------------------------------------------------------------------------------
refuse <- list(c("/api/evidence", "", "GET", 404L), c("/api/evidence", "key=nosuchkey", "GET", 404L),
               c("/api/evidence", "key=x'%20OR%201=1", "GET", 404L), c("/api/nothing", "", "GET", 404L),
               c("/api/names", "", "POST", 405L), c("/etc/passwd", "", "GET", 404L))
for (x in refuse) {
  s <- get(x[1], x[2], x[3])$status
  if (s != as.integer(x[4])) stop(sprintf("%s %s?%s answered %d, not %s", x[3], x[1], x[2], s, x[4]))
}
cat("all checks passed\n")
