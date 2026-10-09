# fingerprint.R — what a rebuild changed: rows, schema and order-free hashes of every output file.
#
# Input:  the file and directory paths a targets store records (targets::tar_meta()), or any paths
# Output: fingerprint_outputs() returns list(files = one row per file, cols = one row per (file, column))
#
# Decision 073 compared two full builds this way, by hand in scratch, and lost the scripts with a restart; this
# keeps the method. Each parquet file is read whole by DuckDB: count(*), the column names and types (schema),
# sum(hash(every column)) as a row hash and sum(hash(column)) per column. Sums make the hashes independent of row
# order, so a file written in another order fingerprints the same. A partitioned dataset is fingerprinted file by
# file, without the partition columns its path adds. Other files (gpkg, fgb) get an md5 only; a GeoPackage stores
# its write time, so its md5 changes on every write (decision 073). Function definitions only.

fingerprint_outputs <- function(paths = NULL) {
  if (is.null(paths)) {
    m <- targets::tar_meta(fields = "path", targets_only = TRUE)
    paths <- unique(unlist(m$path))
  }
  paths <- paths[!is.na(paths) & file.exists(paths)]
  files <- unique(unlist(lapply(paths, function(p)
    if (dir.exists(p)) list.files(p, recursive = TRUE, full.names = TRUE) else p)))
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  fl <- vector("list", length(files)); cl <- vector("list", length(files))
  for (i in seq_along(files)) {
    f <- files[i]
    if (!grepl("[.]parquet$", f)) {
      fl[[i]] <- data.frame(file = f, rows = NA_real_, schema = NA_character_, row_hash = NA_character_,
                            md5 = unname(tools::md5sum(f)))
      next
    }
    src <- sprintf("read_parquet('%s', hive_partitioning = false)", f)
    d <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM %s", src))
    q <- as.character(DBI::dbQuoteIdentifier(con, d$column_name))
    r <- DBI::dbGetQuery(con, sprintf("SELECT count(*)::DOUBLE AS n, CAST(sum(hash(%s)) AS VARCHAR) AS rh, %s FROM %s",
                                      paste(q, collapse = ", "),
                                      paste(sprintf("CAST(sum(hash(%s)) AS VARCHAR) AS c%d", q, seq_along(q)), collapse = ", "),
                                      src))
    fl[[i]] <- data.frame(file = f, rows = r$n, schema = paste(d$column_name, d$column_type, collapse = ";"),
                          row_hash = r$rh, md5 = NA_character_)
    cl[[i]] <- data.frame(file = f, column = d$column_name, type = d$column_type,
                          hash = unlist(r[1, paste0("c", seq_along(q))], use.names = FALSE))
  }
  list(files = do.call(rbind, fl), cols = do.call(rbind, cl))
}
