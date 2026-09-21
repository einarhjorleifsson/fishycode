# ASTD class-B ZIP → Hive-partitioned Parquet
#
# Input:  raw/ais/astdB/astd_classb_2014-01-01_2024-12-31.zip
#         one .csv.gz per UTC day, 4,017 days, 17.9 GB uncompressed
# Output: staging/ais/astdB/year=YYYY/month=M/
#
# Read by curate/ais_ping_union.R, which takes cc_iso3 == "ISL" and keeps
# date_time_utc, mmsi, lon, lat, speed, cog, true_heading. The year/month
# directories are a storage choice only - the union recomputes year from time.
#
# THIS SCRIPT HAD NEVER RUN. Three faults, all found on first execution
# (2026-09-21); see curate/decisions/003-undeclared-dump-inputs.md.
#   1. filter_out(file, str_detect("...")) split str_detect's two arguments
#      across the call, so dplyr::filter_out got a character vector as a
#      condition: "`..1` must be a logical vector, not a character vector".
#   2. year/month were extracted as CHARACTER ("01") and compared against
#      integer m, so filter(month == m) matched nothing - every group would
#      have been empty even once fault 1 was fixed.
#   3. col_types named a column "cod" that does not exist; the feed has "cog",
#      and "speed", which col_types omitted. Both are needed downstream.
#
# Two days are excluded: their files are corrupt in the delivery.

library(tidyverse)
library(duckdbfs)
library(DBI)
library(duckdb)

BAD_DAYS <- c("date_utc=2019-02-12", "date_utc=2021-06-12")

zip <- fd_raw("ais", "astdB", "astd_classb_2014-01-01_2024-12-31.zip")
out <- fd_staging("ais", "astdB")

# Extract to a STABLE directory, not tempfile()/tempdir().
#
# The first attempt extracted into the session temp dir and died after 37 of the
# ~130 month groups with:
#   Invalid Error: IO Error: Failed to create directory ".../RtmpjAzMgQ/duckdb/temp"
# DuckDB spills through <tempdir>/duckdb/, so anything that disturbs the session
# temp dir mid-run takes the whole job with it - and 17.9 GB of extracted input
# is thrown away with it. A stable path removes both problems, and lets a rerun
# skip the extraction entirely.
#
# Not cleaned up on exit, deliberately: it is 17.9 GB of decompressed delivery
# that makes a rerun cheap. Delete it by hand once staging/ais/astdB is trusted.
extract_dir <- fd_staging("ais", "astdB_extract")

if (length(dir(extract_dir, recursive = TRUE, pattern = "[.]gz$")) > 0) {
  message("reusing existing extraction in ", extract_dir)
} else {
  message("extracting ", basename(zip), " ...")
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  unzip(zip, exdir = extract_dir)
}
tmpdir <- extract_dir

# Writes go through write_parquet_group() (R/write_parquet.R), one duckdb
# connection per month group. duckdbfs::write_dataset() would register every
# frame into one cached connection and never release it; see that file.

directory <-
  tibble(file = dir(tmpdir, recursive = TRUE, full.names = TRUE, pattern = "[.]gz$")) |>
  # integer, not character - see fault 2 above
  mutate(year  = as.integer(str_extract(file, "(?<=date_utc=)\\d{4}")),
         month = as.integer(str_extract(file, "(?<=date_utc=\\d{4}-)\\d{2}")),
         .before = file) |>
  filter_out(str_detect(file, BAD_DAYS[1])) |>
  filter_out(str_detect(file, BAD_DAYS[2]))

message(nrow(directory), " daily files, ",
        min(directory$year), "-", max(directory$year))

ctypes <- list(
  dsrc          = col_character(),
  ais_class     = col_character(),
  cc_iso3       = col_character(),
  mmsi          = col_double(),
  maneuvre      = col_double(),
  lon           = col_double(),
  lat           = col_double(),
  status        = col_double(),
  rot           = col_double(),
  speed         = col_double(),
  cog           = col_double(),
  true_heading  = col_double(),
  length        = col_double(),
  breadth       = col_double(),
  draught       = col_double(),
  date_time_utc = col_datetime())

for (y in sort(unique(directory$year))) {
  for (m in 1:12) {
    fils <- directory |> filter(year == y, month == m) |> pull(file)
    if (!length(fils)) next          # not every (year, month) is delivered
    dst <- file.path(out, paste0("year=", y), paste0("month=", m))
    # resumable: a completed group is left alone, so a failure part-way through
    # costs only the groups that had not been written
    if (file.exists(file.path(dst, "data_0.parquet"))) {
      message(sprintf("  %d-%02d  already written, skipping", y, m)); next
    }
    d <- read_csv(fils, col_types = ctypes, progress = FALSE)
    # An explicit per-group directory rather than partitioning = c("year","month").
    # write_dataset passes OVERWRITE_OR_IGNORE, which clears the partitions it
    # writes; since groups are selected by FILE date but partitioned by TIMESTAMP,
    # a ping near a month boundary would land in a partition that a later group
    # then wipes. Writing each group to its own directory removes the hazard.
    #
    # Note the trailing filename. write_dataset with a bare path writes a single
    # FILE at that path, not a directory - so file.path(out, "year=2014") yields
    # a file NAMED "year=2014", which is not a hive directory and contributes no
    # partition column on read. Elsewhere in the repo that is harmless because
    # year is also a data column; here it is not, so the directory is explicit.
    write_parquet_group(d, file.path(dst, "data_0.parquet"))
    message(sprintf("  %d-%02d  %d files  %s rows", y, m, length(fils),
                    format(nrow(d), big.mark = ",")))
  }
}
