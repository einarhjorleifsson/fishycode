# ais_ping_clean.R — L2 of the vessel-trail model: label whacky positions, keep the rest.
#
# Input:  staging/ais/ping_tagged   (merged pings + pid harbour tag + H3)
# Output: staging/ais/ping_clean    (same columns, whacky positions dropped)
#         staging/ais/ping_whacky   (the dropped pings, same columns plus `whack_stage`:
#                                    "vmask", "spike" or "forward" - which step flagged them)
#
# A whacky point is an implausible POSITION - mostly from stk. Not to be confused with the
# "wacky coordinates" of the afli GPS loggers, which are a DDMMmm encoding fault; different
# defect, different source, different fix. See curate/corrections/afli_coords.yml.
#
# The filter is ramb::whack_clean() (decision 067): vmask, a leg-speed spike test, then the
# forward scan. It LABELS; this script is where the labels are acted on, so ping_clean is
# the unflagged pings (its contract is unchanged) and ping_whacky keeps what was taken out,
# with the reason, so a flag can be reviewed or overruled. Before 2026-10-05 this was
# whack_fwdbwd (lazy, in DuckDB) followed by whack_forward (in R).
#
# whack_clean() judges each vessel independently, so the year is cut into batches of whole
# vessels (BATCH_PINGS): exactly equivalent to doing the year at once, and what keeps R below
# a few GB. Splitting by time would not be equivalent - the forward scan carries the last
# kept ping across the cut.

library(duckdbfs)
library(tidyverse)
library(ramb)

KN_MAX <- 25        # speed threshold, knots
METHOD <- "whack_clean-2026-10-05"   # part of the completion fingerprint: a new method re-cleans every year

ais   <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

out    <- fd_staging("ais", "ping_clean")
out_w  <- fd_staging("ais", "ping_whacky")
marks  <- fd_staging("ais", "ping_clean_marks")   # completion markers, outside
dir.create(marks, recursive = TRUE, showWarnings = FALSE)  # the dataset itself

# Target pings per in-memory batch. whack_clean() runs in R on a collected frame, so
# this, not the size of a year, is what sets peak memory.
BATCH_PINGS <- 5e6

kept <- 0
flagged <- c(vmask = 0, spike = 0, forward = 0)

# A completion marker used to be an EMPTY file, so a year was skipped whenever a marker existed - whatever its
# input had become. After the key was rebuilt from the segment table (decision 053) the whole of ping_tagged
# changed and every year printed "already done, skipping": ping_clean stayed the 23 Sep output while targets
# reported it current. The marker now holds a fingerprint of that year's INPUT files (name, size, mtime) AND of
# the method (METHOD, KN_MAX); a year is skipped only when both still match, so a rebuilt ping_tagged, or a
# changed filter, is cleaned again and an old marker never matches.
fingerprint <- function(yr) {
  f <- list.files(file.path(fd_staging("ais", "ping_tagged"), paste0("year=", yr)), full.names = TRUE, recursive = TRUE)
  i <- file.info(f)
  rlang::hash(paste(basename(f), i$size, as.numeric(i$mtime), METHOD, KN_MAX, collapse = ";"))
}

for (yr in years) {

  ydir <- file.path(out, paste0("year=", yr))
  wdir <- file.path(out_w, paste0("year=", yr))
  marker <- file.path(marks, as.character(yr)); fp <- fingerprint(yr)
  if (file.exists(marker) && identical(readLines(marker, warn = FALSE)[1], fp)) {
    message("Year ", yr, " already done for this input, skipping"); next
  }
  message("Year ", yr)
  unlink(c(ydir, wdir), recursive = TRUE)   # any partial output from a failed attempt

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, h3,
           depth, bbht, fao, year)

  vid_n  <- base |> count(vid) |> collect() |> arrange(desc(n))
  groups <- split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)

  for (i in seq_along(groups)) {
    g <- groups[[i]]
    d <- base |> filter(vid %in% g) |> collect() |> whack_clean(kn_max = KN_MAX)

    clean <- d |> filter(!whack) |> select(-whack, -whack_stage)
    whacky <- d |> filter(whack) |> select(-whack)

    kept <- kept + nrow(clean)
    flagged <- flagged + table(factor(whacky$whack_stage, names(flagged)))

    # One part file per batch. Several parquet files in one hive directory is
    # normal and reads back as a single partition.
    write_parquet_group(clean, file.path(ydir, sprintf("part_%03d.parquet", i)))
    if (nrow(whacky) > 0) write_parquet_group(whacky, file.path(wdir, sprintf("part_%03d.parquet", i)))
    message(sprintf("  batch %d/%d: %s vessels, %s pings in, %s kept",
                    i, length(groups), length(g),
                    format(nrow(d), big.mark = ","), format(nrow(clean), big.mark = ",")))
    rm(d, clean, whacky); gc(FALSE)
  }

  writeLines(fp, marker)
}

total_in <- kept + sum(flagged)
message(sprintf(
  "kept %s pings; flagged %s whacky (%.2f%%) = %s vmask + %s spike + %s forward",
  format(kept, big.mark = ","), format(sum(flagged), big.mark = ","),
  100 * sum(flagged) / total_in,
  format(flagged[["vmask"]], big.mark = ","), format(flagged[["spike"]], big.mark = ","),
  format(flagged[["forward"]], big.mark = ",")))
