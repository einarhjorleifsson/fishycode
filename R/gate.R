# gate.R — compare a rebuilt dataset against a baseline.
#
# Input:  two paths (new, baseline) of the same kind
# Output: a one-row data frame per comparison, printed; TRUE/FALSE invisibly
#
# Byte comparison is the wrong test here. GeoPackage embeds creation metadata,
# and parquet encoding varies with writer version, so identical data routinely
# produces different bytes — `ices_areas.gpkg` rebuilt 3 MB smaller than its
# baseline while being feature-for-feature identical. These functions compare
# what the data says instead.

# Tabular: row count plus whatever aggregates the caller considers load-bearing.
gate_parquet <- function(new, base, extra_sql = NULL, label = basename(new)) {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  q <- function(p, sql) DBI::dbGetQuery(con, sprintf(sql, p))

  a <- q(new,  "select count(*) n from read_parquet('%s')")
  b <- q(base, "select count(*) n from read_parquet('%s')")
  ok <- identical(a$n, b$n)

  if (!is.null(extra_sql)) {
    ea <- q(new, extra_sql); eb <- q(base, extra_sql)
    ok <- ok && isTRUE(all.equal(ea, eb, tolerance = 1e-9))
  }
  cat(sprintf("  %-34s %14s %14s   %s\n", label,
              format(a$n, big.mark = ","), format(b$n, big.mark = ","),
              if (ok) "identical" else "*** DIFFERS ***"))
  invisible(ok)
}

# Spatial: feature count, schema, extent, validity and total area.
# Area is the sensitive one — it catches a geometry that was silently altered
# by a crop, a buffer or a make_valid pass.
gate_spatial <- function(new, base, label = basename(new)) {
  if (!file.exists(new) || !file.exists(base)) {
    cat(sprintf("  %-34s %s\n", label, "MISSING one side")); return(invisible(FALSE))
  }
  old_s2 <- sf::sf_use_s2(); sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(old_s2))

  a <- sf::read_sf(new); b <- sf::read_sf(base)
  bbox <- function(x) paste(round(as.numeric(sf::st_bbox(x)), 4), collapse = ",")
  area <- function(x) round(sum(as.numeric(sf::st_area(x))) / 1e6, 1)

  checks <- c(
    features = identical(nrow(a), nrow(b)),
    columns  = identical(sort(names(a)), sort(names(b))),
    extent   = identical(bbox(a), bbox(b)),
    valid    = all(sf::st_is_valid(a)),
    area     = isTRUE(all.equal(area(a), area(b), tolerance = 1e-6))
  )
  ok <- all(checks)
  cat(sprintf("  %-34s %8s feat  %14s km2   %s\n", label,
              format(nrow(a), big.mark = ","), format(area(a), big.mark = ","),
              if (ok) "identical" else
                paste("*** DIFFERS:", paste(names(checks)[!checks], collapse = ", "), "***")))
  if (!ok) {
    cat(sprintf("      new    features %s  area %s  bbox %s\n", nrow(a), area(a), bbox(a)))
    cat(sprintf("      base   features %s  area %s  bbox %s\n", nrow(b), area(b), bbox(b)))
  }
  invisible(ok)
}
