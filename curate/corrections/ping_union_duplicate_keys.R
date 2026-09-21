# ping_union_duplicate_keys.R — detect duplicate position keys in the AIS union.
#
# Input:  staging/ais/ping_union/year=YYYY/   (527,960,318 rows, 2007-2026)
# Output: a data frame, one row per (year, provider-set), printed and returned
#
# Declaration and validation: curate/corrections/ping_union_duplicate_keys.yml
#
# Counts groups of rows agreeing on (vid, time, lon, lat) and reports, per
# group, how many distinct values of speed, heading and mmsi they carry. The
# provider set is carried as a sorted string so a cross-provider collision
# ("astd+emodnet") is distinguishable from a within-provider one ("astd").
#
# Two things about this query are deliberate:
#
#   * It reads year=YYYY/*.parquet directly rather than through
#     duckdbfs::open_dataset(). The dataset has BOTH a `year` data column and a
#     `year` hive column (TODO item 11), and reading the paths sidesteps it.
#
#   * It opens a fresh connection per year and disconnects after. A single
#     connection accumulates until the aggregate over 40-70 M rows exhausts the
#     memory limit; 2015-2020 all failed this way before the per-year teardown.
#     2017 (69 M rows) still exceeds it as one group and is split by month,
#     which is safe because time determines month, so no group spans two.
#
# Runtime: about 25 minutes over all 20 years on a 24 GB laptop.

library(duckdb)

MEM     <- "12GB"
THREADS <- 3

ping_union_duplicate_keys <- function(years = 2007:2026,
                                      split_by_month = 2017L,
                                      tmp_dir = tempdir()) {

  q <- function(src, extra_where = "", label) {
    sprintf("
WITH g AS (
  SELECT vid, time, lon, lat,
         COUNT(*) AS n,
         array_to_string(list_sort(array_distinct(list(provider))), '+') AS provs,
         COUNT(DISTINCT speed)   AS nsp,
         COUNT(DISTINCT heading) AS nhd,
         COUNT(DISTINCT mmsi)    AS nmm
  FROM read_parquet('%s') %s
  GROUP BY 1,2,3,4
  HAVING COUNT(*) > 1
)
SELECT %s AS part, provs,
       COUNT(*) AS groups,
       SUM(n) - COUNT(*) AS excess,
       SUM(CASE WHEN nsp > 1 THEN 1 ELSE 0 END) AS speed_differs,
       SUM(CASE WHEN nhd > 1 THEN 1 ELSE 0 END) AS heading_differs,
       SUM(CASE WHEN nmm > 1 THEN 1 ELSE 0 END) AS mmsi_differs
FROM g GROUP BY 1,2", src, extra_where, label)
    # NOTE: every alias needs its AS. `COUNT(*) groups` is a parser error -
    # GROUPS is reserved by DuckDB's window frame syntax.
  }

  out <- list()

  for (YR in years) {
    src   <- sprintf("%s/year=%d/*.parquet", fd_staging("ais", "ping_union"), YR)
    parts <- if (YR %in% split_by_month) 1:12 else NA_integer_

    for (M in parts) {
      # No on.exit() here: inside a loop it defers every teardown to function
      # exit, which is the accumulation this per-year connection exists to
      # avoid. tryCatch(finally=) closes at the end of each iteration instead.
      con <- dbConnect(duckdb())
      r <- tryCatch({
        dbExecute(con, sprintf("SET memory_limit='%s'", MEM))
        dbExecute(con, sprintf("SET threads=%d", THREADS))
        dbExecute(con, "SET preserve_insertion_order=false")
        dbExecute(con, sprintf("SET temp_directory='%s'", tmp_dir))
        where <- if (is.na(M)) "" else sprintf("WHERE month(time) = %d", M)
        dbGetQuery(con, q(src, where, YR))
      }, finally = dbDisconnect(con, shutdown = TRUE))

      if (nrow(r)) out[[length(out) + 1L]] <- r
      gc()
    }
  }

  res <- do.call(rbind, out)
  if (is.null(res)) {
    message("no duplicate position keys - the defect is repaired")
    return(invisible(NULL))
  }
  names(res)[1] <- "year"
  res <- aggregate(cbind(groups, excess, speed_differs, heading_differs, mmsi_differs) ~
                     year + provs, res, sum)
  res <- res[order(res$year, res$provs), ]
  print(res, row.names = FALSE)
  message("total groups: ", sum(res$groups), "  excess rows: ", sum(res$excess))
  invisible(res)
}

# The check TODO item 5 closes on: this returns NULL.
#   ping_union_duplicate_keys()
