# write_parquet_group() — write one materialised frame to parquet, then let go.
#
# Why this exists rather than duckdbfs::write_dataset():
#
# write_dataset() registers the frame into duckdbfs's single CACHED connection
# and never releases it. That is fine once. In a loop it is not: across ~130
# month groups of ASTD class-B the cached connection accumulated close to a
# billion rows and spilled 48 GB to its temp directory before the run was
# stopped, and an earlier attempt died outright with
#   IO Error: Failed to create directory ".../duckdb/temp"
# after 37 groups - the same cause, reached from the other side.
#
# Every script here that collects a year (or a month) into memory and writes it
# inside a loop has this shape, so the fix belongs in one place.
#
# A fresh connection per call keeps the working set to a single group and spills
# nothing. An R POSIXct registered this way lands as TIMESTAMP, not TIMESTAMPTZ -
# measured, so the arrow/nanoparquet prohibition is not reintroduced.
#
# Use duckdbfs::write_dataset() for LAZY duckdb relations, where no materialised
# frame is registered and there is nothing to accumulate.
write_parquet_group <- function(d, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "grp", d)
  DBI::dbExecute(con, sprintf("COPY grp TO '%s' (FORMAT parquet)", path))
  invisible(path)
}

# write_parquet_sf() — an sf frame to a staging parquet: the geometry as WKB under its own column name, and that name
# and the CRS in the file's metadata (fd.geometry, fd.crs) as write_curated() records them, so read_curated_sf()
# reads it back. No provenance stamps: write_curated() keeps those, and its guard, for curated/ (plan 043).
write_parquet_sf <- function(d, path) {
  stopifnot(inherits(d, "sf"))
  geom <- attr(d, "sf_column")
  crs  <- sf::st_crs(d)$wkt
  wkb  <- unclass(sf::st_as_binary(sf::st_geometry(d)))
  d <- as.data.frame(sf::st_drop_geometry(d))
  d[[geom]] <- wkb
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  duckdb::duckdb_register(con, "grp", d)
  kv <- c("fd.geometry" = geom, "fd.crs" = crs)
  meta <- paste(sprintf("%s: %s", shQuote(names(kv), type = "sh"), shQuote(unname(kv), type = "sh")), collapse = ", ")
  DBI::dbExecute(con, sprintf("COPY grp TO %s (FORMAT parquet, KV_METADATA {%s})", shQuote(path, type = "sh"), meta))
  invisible(path)
}
