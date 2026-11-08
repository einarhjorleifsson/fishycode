# ais_ping_clean.R — L2 of the vessel-trail model: label whacky positions, keep the rest; then the speed of the feeds
# that carry none.
# Side: flow, step 0. See plans 014 and 062.
#
# Input:  staging/ais/ping_tagged   (merged pings on one clock + pid harbour tag; curate/ais_ping_tag.R)
# Output: staging/ais/ping_clean    (same columns, whacky positions dropped; astd's and emodnet's speed derived here)
#         staging/ais/ping_whacky   (the dropped pings, same columns plus `whack_stage`: "invalid",
#                                    "duplicate", "vmask", "spike", "forward" or "tie" - which step took them out -
#                                    and the whack's evidence, `ping_flag_side` and the legs to the nearest kept
#                                    ping on each side, `ping_flag_{prev,next}_{dt_s,dist_m,feed}`: NA but for
#                                    vmask, spike and forward)
#         staging/ais/ping_limits   (year=<y>/limits.parquet: each vessel and stream's ceiling, clock and noise, with
#                                    their bases and counts; ramb::rb_create_ping_limits(); decision 299)
# Pings with no `vid` are in neither ping output: there is no vessel to judge them against (decision 067).
#
# A whacky point is an implausible POSITION - mostly from stk. Not to be confused with the
# "wacky coordinates" of the afli GPS loggers, which are a DDMMmm encoding fault; different
# defect, different source, different fix. See curate/corrections/afli_coords.yml.
#
# The filter is ramb::rb_flag_ping_impossible(method = "clean"), formerly rb_whack_clean()
# (decisions 067, 069): vmask, a leg-speed spike test, then
# the forward scan, every speed on a time step of at least MIN_DT_S. Two kinds of ping go out
# before it, see below: placeholder positions ("invalid") and a second feed's copy of a report
# ("duplicate"). The filter LABELS; this script is where the labels are acted on, so ping_clean
# is the unflagged pings (its contract is unchanged) and ping_whacky keeps what was taken out,
# with the reason, so a flag can be reviewed or overruled. Before 2026-10-05 this was
# whack_fwdbwd (lazy, in DuckDB) followed by whack_forward (in R).
#
# Both run on the harmonized time (plan 059 §3): astd's lag behind STK made a vessel jump back and forth along its
# track, and the whack took STK's good pings for it (decision 164). What alignment leaves between feeds, a few hundred
# metres, is a noise floor: a leg between two feeds no longer than NOISE_NM is never impossible (ramb 2026.11.01.2's
# `feed`, TODO 88). On aligned pings 0.3 nm frees 6,800 (2026) and 3,068 (2016) more false removals and takes back no
# true one (plan 059 step 6). The evidence of each whack flag is kept (the maintainer, 2026-11-01, TODO 88 §10 item 5).
#
# The year is a lazy table, and ramb batches it itself (plan 062 step 5): rb_flag_ping_duplicate() and
# rb_flag_ping_impossible() collect whole vessels in batches of 5 M pings, sort each in a total order, label it and write
# it whole (ramb 2026.11.04, plan 062 step 4g). Until then this script collected its own batches and called ramb on data
# frames. ramb keeps the files of each pass until the R session ends, so each year runs in its own R process (the
# script calls itself with CLEAN_YEAR set): one session would hold about 46 GB of them over a whole run.
#
# A vessel faster than KN_MAX is judged at its own ceiling (the maintainer, 2026-11-08: "Build it"; decision 299). The
# ceilings are ramb::rb_create_ping_limits()'s over the whole year, a vessel's the largest of its streams'; a vessel
# whose ceiling exceeds KN_MAX takes it as `kn_max` in the speed step, every other vessel KN_MAX. The duplicate rule
# stays at KN_MAX. rb_flag_ping_impossible(method = "clean") takes one kn_max a call, so the fast vessels' pings (about
# 1 M a year) are collected after the duplicate pass and judged in R, vessel by vessel, in the order this script used
# before (the maintainer, 2026-11-08, plan 062 step 5: "Yes, as proposed").
#
# The tie stays here: ramb has no rule for two pings of one vessel in one second (plan 062, Decided f, not built). It is
# a window in SQL, in the order the batches had: a recorded position over a reconstructed one, STK over the other
# feeds, then provider, lon, lat and every other column.
#
# The speed of astd and emodnet, which carry none, is derived here, after the flags, by ramb::rb_add_ping_speed() (plan
# 062 step 5; the union derived it before any flag until then, and 28,758 kept speeds of 2017 used a bad position as a
# neighbour). A flagged ping gets none; a copy ("duplicate") stays a neighbour in its stream (plan 062, Decided j). It
# is derived on `time_delivered`, by provider and MMSI, as the union did: on the harmonized time, a feed's copies of
# STK's reports are moved onto STK's clock one by one and their neighbours are not (2017: 116,452 astd and 79,306
# emodnet pings). Within a year: the first and last ping of a stream take the one side they have (643 astd in 2017,
# where the union read across New Year). Study: $FISHYDATA/archive/2026-11-08-plan062-step5/.

library(duckdbfs)
library(tidyverse)
library(ramb)

CHILD <- Sys.getenv("CLEAN_YEAR")   # set: clean that year only, in this process (see above)
if (nzchar(CHILD)) {
  Sys.setenv(TZ = "UTC")
  for (f in sort(list.files("R", "[.][Rr]$", full.names = TRUE))) source(f)
}

KN_MAX   <- 25      # speed threshold, knots
MIN_DT_S <- 10      # shortest time step for a speed, seconds (the filter's min_dt_s)
# Cross-feed duplicate: a lower-priority feed's ping within DUP_S and DUP_M of a higher one of the same vid.
# DUP_M is what KN_MAX allows in MIN_DT_S (128.6 m), so the pair is one the filter would itself call consistent.
# ramb::rb_flag_ping_duplicate() applies the rule; it derives DUP_M from KN_MAX and DUP_S itself (kept here for the fingerprint).
DUP_S    <- MIN_DT_S
DUP_M    <- KN_MAX * 1852 / 3600 * MIN_DT_S
DUP_K    <- 3       # neighbours compared on each side, in time order
FEED     <- c(stk = 1, astd = 2, astdB = 3, emodnet = 4)   # priority; stk wins, as in ais_ping_trail.R
NOISE_NM <- 0.3     # the whack's noise floor between feeds, nautical miles (TODO 88, plan 059 step 6)
LIM_MAX_STEP_S <- 300                           # the limits' time error on steps of at most 300 s (plan 065 step 5)
LAG_BASES <- c("copy", "receipt", "measured")   # plan 059's lags taken as measured for the limits' clock
DERIVED  <- c("astd", "emodnet")                # the feeds whose speed is derived here
SPEED_MAX <- 40     # a derived speed above this is no vessel speed: `speed` NA, `speed_raw` keeps it (the union's rule)
METHOD   <- "rb_flag_ping-2026-11-08b:harmonized-time+invalid+duplicate+clean(feed-floor,evidence,own-ceiling-over-kn_max),recorded-only+tie,total-order,lazy+speed-after(delivered-time,provider-mmsi)"   # part of the completion fingerprint: a new method re-cleans every year
# the columns of the two outputs, in this order
BASE <- c("vid", "mmsi", "time", "lon", "lat", "speed", "speed_raw", "speed_span_s", "heading", "cog", "provider",
          "pos_basis", "speed_basis", "dt_sec", "sid_gps", "n_sid_gps", "pid", "time_delivered", "lag_s", "lag_basis",
          "stream", "year")

tagged <- fd_staging("ais", "ping_tagged")
out    <- fd_staging("ais", "ping_clean")
out_w  <- fd_staging("ais", "ping_whacky")
out_l  <- fd_staging("ais", "ping_limits")
marks  <- fd_staging("ais", "ping_clean_marks")   # completion markers, outside
dir.create(marks, recursive = TRUE, showWarnings = FALSE)  # the dataset itself

# A completion marker used to be an EMPTY file, so a year was skipped whenever a marker existed - whatever its
# input had become. After the key was rebuilt from the segment table (decision 053) the whole of ping_tagged
# changed and every year printed "already done, skipping": ping_clean stayed the 23 Sep output while targets
# reported it current. The marker now holds a fingerprint of that year's INPUT files (name, size, mtime) AND of
# the method (METHOD and every constant above); a year is skipped only when both still match, so a rebuilt
# ping_tagged, or a changed filter, is cleaned again and an old marker never matches. The ramb version is not in
# it: a change to the filter itself must change METHOD.
fingerprint <- function(yr) {
  f <- list.files(file.path(tagged, paste0("year=", yr)), full.names = TRUE, recursive = TRUE)
  i <- file.info(f)
  rlang::hash(paste(basename(f), i$size, as.numeric(i$mtime), METHOD, KN_MAX, MIN_DT_S, DUP_S, DUP_M, DUP_K, NOISE_NM,
                    LIM_MAX_STEP_S, paste(LAG_BASES, collapse = ","), paste(DERIVED, collapse = ","), SPEED_MAX,
                    paste(names(FEED), FEED, collapse = ","), collapse = ";"))
}

# One year -------------------------------------------------------------------------------------------------------
clean_year <- function(yr) {
  ydir <- file.path(out, paste0("year=", yr))
  wdir <- file.path(out_w, paste0("year=", yr))
  ldir <- file.path(out_l, paste0("year=", yr))
  unlink(c(ydir, wdir, ldir), recursive = TRUE)   # any partial output from a failed attempt
  message("Year ", yr)
  t_year <- Sys.time()
  lap <- function(what) message(sprintf("  %-34s %6.0f s", what, as.numeric(difftime(Sys.time(), t_year, units = "secs"))))

  work <- file.path(tempdir(), "clean_work"); dir.create(work, showWarnings = FALSE)
  spill <- file.path(tempdir(), "spill"); dir.create(spill, showWarnings = FALSE)
  duckdbfs::duckdb_config(threads = 4, memory_limit = "5GB", temp_directory = spill)
  con <- duckdbfs::cached_connection()
  x <- function(...) invisible(DBI::dbExecute(con, sprintf(...)))
  q <- function(v) DBI::dbQuoteIdentifier(con, v)
  # a lazy table to one parquet file; paste0, not sprintf: the SQL may hold a % (a modulo)
  copy_to_file <- function(t, path) invisible(DBI::dbExecute(con, paste0("COPY (", dbplyr::sql_render(t), ") TO '", path,
                                                                          "' (FORMAT parquet)")))
  types_of <- function(t) {
    d <- DBI::dbGetQuery(con, paste("DESCRIBE", dbplyr::sql_render(t)))
    setNames(d$column_type, d$column_name)
  }

  ## The limits over the whole year ---------------------------------------------------------------------------------
  # every ping with a vid that is not invalid, the recorded speed, the measured lags. A vessel's ceiling is the largest
  # of its streams'; over KN_MAX it is the vessel's own `kn_max` below.
  x("CREATE OR REPLACE TEMP TABLE lp AS
     SELECT vid, time, lon, lat, CASE WHEN speed_basis = 'recorded' THEN speed END AS speed_rec, stream,
            CASE WHEN lag_basis IN (%s) THEN lag_s END AS lag_m
     FROM read_parquet('%s')
     WHERE vid IS NOT NULL AND time IS NOT NULL AND lon IS NOT NULL AND lat IS NOT NULL AND lon <> lat",
    paste0("'", LAG_BASES, "'", collapse = ", "), file.path(tagged, paste0("year=", yr), "*.parquet"))
  lim <- rb_create_ping_limits(dplyr::tbl(con, "lp"), stream = stream, speed = speed_rec, lag = lag_m,
                               max_step_s = LIM_MAX_STEP_S) |>
    collect() |> as.data.frame()
  x("DROP TABLE lp")
  write_parquet_group(lim, file.path(ldir, "limits.parquet"))
  fast <- lim |> filter(!is.na(ceiling_kn)) |> summarise(kn = max(ceiling_kn), .by = vid) |> filter(kn > KN_MAX)
  fast <- setNames(fast$kn, as.character(fast$vid))
  fast_v <- as.integer(names(fast))
  lap(sprintf("limits: %d vessels over %g kn", length(fast), KN_MAX))

  ## The flags ------------------------------------------------------------------------------------------------------
  # Step 0 of the flow, in order; each flagger tests only pings not yet flagged (ramb, plan 013):
  #   invalid    a placeholder, not a position: lon == lat (stk wrote the latitude into lon; (0, 0) is
  #              the same rule). Out first, so the filter cannot keep it as an anchor
  #              (curate/corrections/ais_invalid_position.yml).
  #   duplicate  a second feed's copy of a report the higher-priority feed already has: the same fix
  #              twice, a second or two and well under a metre apart in the median (decision 069).
  #   impossible rb_whack_clean's two stages: vmask, spike, then forward (decision 067).
  # Only RECORDED positions are tested for duplicates and impossible jumps (plan 014): the gps logger's
  # positions are reconstructed from the AIS track itself, so they take the invalid test only.
  base <- open_dataset(tagged) |>
    filter(year == yr, !is.na(vid)) |>
    select(all_of(BASE))

  dup <- base |>
    filter(pos_basis == "recorded") |>
    rb_flag_ping_invalid(rules = "lon_eq_lat") |>
    rb_flag_ping_duplicate(feed = provider, priority = names(FEED), max_dt_s = DUP_S, kn_max = KN_MAX, n_neighbours = DUP_K)
  lap("duplicate pass")
  ord <- (if (length(fast_v)) dup |> filter(!vid %in% !!fast_v) else dup) |>
    rb_flag_ping_impossible(method = "clean", kn_max = KN_MAX, min_dt_s = MIN_DT_S,
                            feed = provider, noise_nm = NOISE_NM, evidence = TRUE)
  lap("impossible pass, the vessels at KN_MAX")
  types <- types_of(ord)

  # the fast vessels, each at its own ceiling, in the order the batches had before (a total order: DuckDB returns the
  # rows in no fixed order, and two pings of one vessel, second, feed and position can differ in speed or heading;
  # decision 086, TODO 55), written with the lazy part's types
  rec <- ord
  if (length(fast_v)) {
    fd <- dup |> filter(vid %in% !!fast_v) |> collect() |> as.data.frame() |>
      arrange(vid, time, pos_basis != "recorded", provider != "stk", provider, lon, lat, pick(all_of(BASE)))
    fl <- bind_rows(unname(lapply(split(fd, fd$vid), \(v)
      rb_flag_ping_impossible(v, method = "clean", kn_max = fast[[as.character(v$vid[1])]], min_dt_s = MIN_DT_S,
                              feed = provider, noise_nm = NOISE_NM, evidence = TRUE))))
    duckdb::duckdb_register(con, "fast_flagged", fl[, names(types)])
    x("COPY (SELECT %s FROM fast_flagged) TO '%s' (FORMAT parquet)",
      paste(sprintf("CAST(%s AS %s) AS %s", q(names(types)), types, q(names(types))), collapse = ", "),
      file.path(work, "fast.parquet"))
    duckdb::duckdb_unregister(con, "fast_flagged")
    rec <- union_all(ord, dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet('%s')", file.path(work, "fast.parquet")))))
    rm(fd, fl)
    lap(sprintf("impossible, %d fast vessels in R", length(fast_v)))
  }

  # the reconstructed positions: the invalid test alone, the evidence columns empty, typed as the recorded rows have them
  rcn <- base |>
    filter(pos_basis != "recorded") |>
    rb_flag_ping_invalid(rules = "lon_eq_lat")
  for (v in setdiff(names(types), colnames(rcn))) rcn <- rcn |> mutate(!!v := dplyr::sql(sprintf("CAST(NULL AS %s)", types[[v]])))

  # the tie: among the unflagged pings, every one after the first at its (vid, time), in the order above. Two feeds can
  # report one second at places more than DUP_M apart; one of them is set aside.
  lab_file <- file.path(work, "labelled.parquet")
  labelled <- union_all(rec, rcn |> select(all_of(names(types)))) |>
    mutate(.u = is.na(ping_flag), .o1 = pos_basis != "recorded", .o2 = provider != "stk") |>   # window_order() takes columns only
    group_by(vid, time, .u) |>
    dbplyr::window_order(.o1, .o2, provider, lon, lat, mmsi, speed, speed_raw, speed_span_s, heading, cog, pos_basis,
                         speed_basis, dt_sec, sid_gps, n_sid_gps, pid, time_delivered, lag_s, lag_basis, stream) |>
    mutate(.rn = row_number()) |>
    ungroup() |>
    dbplyr::window_order() |>
    mutate(ping_flag = if_else(.u & .rn > 1, "tie", ping_flag)) |>
    select(-.u, -.rn, -.o1, -.o2)
  copy_to_file(labelled, lab_file)
  lap("tie, the year written labelled")

  ## The speed of the feeds that carry none -------------------------------------------------------------------------
  lab <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet('%s')", lab_file)))
  der <- lab |>
    filter(provider %in% !!DERIVED) |>
    # ramb reads `time` and `stream`: the delivered time and the feed's MMSI take their names for the call
    mutate(speed_stream = paste0(provider, ":", mmsi)) |>
    rename(time_harmonized = time, time = time_delivered, stream_tagged = stream, stream = speed_stream) |>
    rb_add_ping_speed(stream = stream) |>
    select(-stream) |>
    rename(time_delivered = time, time = time_harmonized, stream = stream_tagged) |>
    mutate(speed_raw = speed_derived,
           speed = if_else(speed_derived >= 0 & speed_derived <= !!SPEED_MAX, speed_derived, NA_real_),
           speed_span_s = speed_derived_span_s,
           speed_basis = speed_derived_basis) |>
    select(all_of(colnames(lab)))
  fin_file <- file.path(work, "final.parquet")
  copy_to_file(union_all(lab |> filter(!provider %in% !!DERIVED), der), fin_file)
  unlink(lab_file)
  lap("speed of astd and emodnet")

  ## The two outputs ------------------------------------------------------------------------------------------------
  # the types the batches' R frames wrote before: n_sid_gps and year as doubles
  sel <- paste(ifelse(BASE %in% c("n_sid_gps", "year"), sprintf("CAST(%s AS DOUBLE) AS %s", q(BASE), q(BASE)), q(BASE)),
               collapse = ", ")
  ev <- setdiff(names(types), c(BASE, "ping_flag", "ping_flag_basis"))
  dir.create(ydir, recursive = TRUE); dir.create(wdir, recursive = TRUE)
  fin <- sprintf("read_parquet('%s')", fin_file)
  x("COPY (SELECT %s FROM %s WHERE ping_flag IS NULL ORDER BY vid, time) TO '%s' (FORMAT parquet)",
    sel, fin, file.path(ydir, "part_001.parquet"))
  x("COPY (SELECT %s, ping_flag AS whack_stage, ping_flag_basis, %s FROM %s WHERE ping_flag IS NOT NULL ORDER BY vid, time)
     TO '%s' (FORMAT parquet)", sel, paste(q(ev), collapse = ", "), fin, file.path(wdir, "part_001.parquet"))
  n <- DBI::dbGetQuery(con, sprintf("SELECT count(*) FILTER (WHERE ping_flag IS NULL) AS kept, count(*) AS n FROM %s", fin))
  unlink(fin_file)
  lap(sprintf("%s pings in, %s kept", format(n$n, big.mark = ","), format(n$kept, big.mark = ",")))
  writeLines(fingerprint(yr), file.path(marks, as.character(yr)))
}

if (nzchar(CHILD)) {
  clean_year(as.integer(CHILD))
  quit(save = "no")
}

# Every year, each in its own R process ----------------------------------------------------------------------------
ais   <- open_dataset(tagged)
years <- ais |> distinct(year) |> collect() |> pull(year) |> as.integer() |> sort()
for (yr in years) {
  marker <- file.path(marks, as.character(yr)); fp <- fingerprint(yr)
  if (file.exists(marker) && identical(readLines(marker, warn = FALSE)[1], fp)) {
    message("Year ", yr, " already done for this input, skipping"); next
  }
  unlink(marker)
  st <- system2(file.path(R.home("bin"), "Rscript"), "curate/ais_ping_clean.R", env = c(sprintf("CLEAN_YEAR=%d", yr), "TZ=UTC"))
  if (st != 0 || !file.exists(marker) || !identical(readLines(marker, warn = FALSE)[1], fp)) {
    stop("the clean of ", yr, " stopped (exit ", st, ")")
  }
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
stage <- stage[intersect(c("invalid", "duplicate", "vmask", "spike", "forward", "tie"), names(stage))]
fmt <- function(x) format(sum(x), big.mark = ",")
message(sprintf(
  "%s pings in: kept %s; flagged %s whacky (%.2f%%) = %s; %s with no vid, in neither output",
  fmt(rec$n_in), fmt(rec$kept), fmt(rec$flagged), 100 * sum(rec$flagged) / sum(rec$kept + rec$flagged),
  paste(vapply(stage, fmt, ""), names(stage), collapse = " + "), fmt(rec$no_vid)))
if (any(rec$off != 0)) {
  stop("ping_clean + ping_whacky + no-vid pings do not add up to ping_tagged in ",
       paste(rec$year[rec$off != 0], collapse = ", "))
}
