# ais_ping_clean.R — L2 of the vessel-trail model: label whacky positions, keep the rest.
#
# Input:  staging/ais/ping_tagged   (merged pings + pid harbour tag + H3)
# Output: staging/ais/ping_clean    (same columns, whacky positions dropped)
#         staging/ais/ping_whacky   (the dropped pings, same columns plus `whack_stage`: "invalid",
#                                    "duplicate", "vmask", "spike" or "forward" - which step took them out)
# Pings with no `vid` are in neither: there is no vessel to judge them against (decision 067).
#
# A whacky point is an implausible POSITION - mostly from stk. Not to be confused with the
# "wacky coordinates" of the afli GPS loggers, which are a DDMMmm encoding fault; different
# defect, different source, different fix. See curate/corrections/afli_coords.yml.
#
# The filter is ramb::rb_whack_clean() (decisions 067, 069): vmask, a leg-speed spike test, then
# the forward scan, every speed on a time step of at least MIN_DT_S. Two kinds of ping go out
# before it, see below: placeholder positions ("invalid") and a second feed's copy of a report
# ("duplicate"). The filter LABELS; this script is where the labels are acted on, so ping_clean
# is the unflagged pings (its contract is unchanged) and ping_whacky keeps what was taken out,
# with the reason, so a flag can be reviewed or overruled. Before 2026-10-05 this was
# whack_fwdbwd (lazy, in DuckDB) followed by whack_forward (in R).
#
# rb_whack_clean() judges each vessel independently, so the year is cut into batches of whole
# vessels (BATCH_PINGS): exactly equivalent to doing the year at once, and what keeps R below
# a few GB. Splitting by time would not be equivalent - the forward scan carries the last
# kept ping across the cut.

library(duckdbfs)
library(tidyverse)
library(ramb)

KN_MAX   <- 25      # speed threshold, knots
MIN_DT_S <- 10      # shortest time step for a speed, seconds (rb_whack_clean's min_dt_s)
# Cross-feed duplicate: a lower-priority feed's ping within DUP_S and DUP_M of a higher one of the same vid.
# DUP_M is what KN_MAX allows in MIN_DT_S (128.6 m), so the pair is one the filter would itself call consistent.
DUP_S    <- MIN_DT_S
DUP_M    <- KN_MAX * 1852 / 3600 * MIN_DT_S
DUP_K    <- 3       # neighbours compared on each side, in time order
FEED     <- c(stk = 1, astd = 2, astdB = 3, emodnet = 4)   # priority; stk wins, as in ais_ping_trail.R
METHOD   <- "rb_whack_clean-2026-10-08+invalid+duplicate"   # part of the completion fingerprint: a new method re-cleans every year

ais   <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

out    <- fd_staging("ais", "ping_clean")
out_w  <- fd_staging("ais", "ping_whacky")
marks  <- fd_staging("ais", "ping_clean_marks")   # completion markers, outside
dir.create(marks, recursive = TRUE, showWarnings = FALSE)  # the dataset itself

# Target pings per in-memory batch. rb_whack_clean() runs in R on a collected frame, so
# this, not the size of a year, is what sets peak memory.
BATCH_PINGS <- 5e6

# A completion marker used to be an EMPTY file, so a year was skipped whenever a marker existed - whatever its
# input had become. After the key was rebuilt from the segment table (decision 053) the whole of ping_tagged
# changed and every year printed "already done, skipping": ping_clean stayed the 23 Sep output while targets
# reported it current. The marker now holds a fingerprint of that year's INPUT files (name, size, mtime) AND of
# the method (METHOD and every constant above); a year is skipped only when both still match, so a rebuilt
# ping_tagged, or a changed filter, is cleaned again and an old marker never matches. The ramb version is not in
# it: a change to the filter itself must change METHOD.
fingerprint <- function(yr) {
  f <- list.files(file.path(fd_staging("ais", "ping_tagged"), paste0("year=", yr)), full.names = TRUE, recursive = TRUE)
  i <- file.info(f)
  rlang::hash(paste(basename(f), i$size, as.numeric(i$mtime), METHOD, KN_MAX, MIN_DT_S, DUP_S, DUP_M, DUP_K,
                    paste(names(FEED), FEED, collapse = ","), collapse = ";"))
}

# TRUE for a ping that a higher-priority feed also reported: same vid, within DUP_S seconds and DUP_M metres,
# among the DUP_K neighbours on each side in time order. stk is never one (curate/corrections/ais_cross_feed_duplicates.yml).
cross_feed_dup <- function(d) {
  pr <- unname(FEED[d$provider]); pr[is.na(pr)] <- length(FEED) + 1
  o <- order(d$vid, d$time, pr, d$lon, d$lat)
  v <- d$vid[o]; t <- as.numeric(d$time[o]); x <- d$lon[o]; y <- d$lat[o]; p <- pr[o]
  n <- length(o); dup <- logical(n)
  if (n < 2) return(dup)
  for (k in seq_len(min(DUP_K, n - 1))) {
    i <- seq_len(n - k); j <- i + k
    near <- v[i] == v[j] & abs(t[j] - t[i]) <= DUP_S & rb_distance(x[i], y[i], x[j], y[j]) <= DUP_M
    dup[j[near & p[i] < p[j]]] <- TRUE
    dup[i[near & p[j] < p[i]]] <- TRUE
  }
  dup[order(o)]
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

  # Explicit, not left to SQL: `vid %in% g` skips NA in DuckDB, but R's %in% matches NA to NA.
  base <- ais |>
    filter(year == yr, !is.na(vid)) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, h3,
           depth, bbht, fao, year)

  vid_n  <- base |> count(vid) |> collect() |> arrange(desc(n))
  groups <- split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)

  for (i in seq_along(groups)) {
    g <- groups[[i]]
    d <- base |> filter(vid %in% g) |> collect()
    # A placeholder, not a position: lon == lat (stk wrote the latitude into lon; (0, 0) is the same
    # rule). Out BEFORE rb_whack_clean(), which otherwise can keep it as an anchor and flag the good
    # track around it (curate/corrections/ais_invalid_position.yml).
    bad <- d$lon == d$lat
    # Then a second feed's copy of a report the higher-priority feed already has: the same fix twice,
    # a second or two and well under a metre apart in the median.
    dup <- logical(nrow(d)); dup[!bad] <- cross_feed_dup(d[!bad, ])
    keep <- !bad & !dup
    d <- bind_rows(d[keep, ] |> rb_whack_clean(kn_max = KN_MAX, min_dt_s = MIN_DT_S),
                   d[bad, ] |> mutate(whack_stage = "invalid", whack = TRUE),
                   d[dup, ] |> mutate(whack_stage = "duplicate", whack = TRUE))

    clean <- d |> filter(!whack) |> select(-whack, -whack_stage)
    whacky <- d |> filter(whack) |> select(-whack)

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

# Closing count -----------------------------------------------------------------
# Over the whole output, not this run: a skipped year counted as zero before, and the pings
# with no vid were in no total at all. Every year must reconcile: in = kept + flagged + no vid.
n_year <- function(x) x |> count(year) |> collect()
rec <- n_year(ais) |> rename(n_in = n) |>
  left_join(n_year(ais |> filter(is.na(vid))) |> rename(no_vid = n), by = "year") |>
  left_join(n_year(open_dataset(out)) |> rename(kept = n), by = "year") |>
  left_join(n_year(open_dataset(out_w)) |> rename(flagged = n), by = "year") |>
  mutate(across(-year, \(x) coalesce(as.numeric(x), 0)), off = n_in - kept - flagged - no_vid)
stage <- open_dataset(out_w) |> count(whack_stage) |> collect() |> deframe()
stage <- stage[intersect(c("invalid", "duplicate", "vmask", "spike", "forward"), names(stage))]
fmt <- function(x) format(sum(x), big.mark = ",")
message(sprintf(
  "%s pings in: kept %s; flagged %s whacky (%.2f%%) = %s; %s with no vid, in neither output",
  fmt(rec$n_in), fmt(rec$kept), fmt(rec$flagged), 100 * sum(rec$flagged) / sum(rec$kept + rec$flagged),
  paste(vapply(stage, fmt, ""), names(stage), collapse = " + "), fmt(rec$no_vid)))
if (any(rec$off != 0)) {
  stop("ping_clean + ping_whacky + no-vid pings do not add up to ping_tagged in ",
       paste(rec$year[rec$off != 0], collapse = ", "))
}
