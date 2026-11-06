# ais_ping_tag.R — the feeds put on one clock, and every merged ping tagged with its port polygon.
# Side: flow, step 0. See plans 014 and 059.
#
# Input:  staging/ais/ping_union                  all pings, from curate/ais_ping_union.R
#         curated/check/ais_feed_clock.parquet    the lag per vessel, stream and month (curate/checks/ais_feed_clock.R)
#         curated/check/ais_feed_clock_usual.parquet  the usual lag of STK's own-stamped VMS pings, by year (the same)
#         staging/ais/stk_receipt                 STK's receipt and unit of each ping of its VMS stream (the union)
#         staging/aux/ports.fgb                   harbour polygons (pid, hid)
# Output: staging/ais/ping_tagged                 partitioned by the year of `time`: the union's columns with `time`
#                                                 harmonized, beside it `time_delivered`, `lag_s`, `lag_basis` and
#                                                 `stream`; `pid`
#
# Two scripts, union then tag, on purpose: the union is 44 GB, and the tagging must be rerunnable
# without redoing it (AGENTS.md, Script naming).
#
# The clocks (plan 059 §3, asks a-f; curate/corrections/ais_feed_clock_offset.yml). Every stage after this one derives
# across pings (the duplicate flag, the whack, port calls, the trail's windows), and astd ran 10-86 s behind STK in
# 2014-2016 and 2025-2026, so the feeds are harmonized here, against STK's streams, with ramb's step 0 (2026.11.01).
# Each ping, in this order:
#   copy        an astd, astdB or emodnet ping that is a copy of a report STK's streams also hold (within 2 m and
#               180 s, the vessel moving): its own gap (rb_add_ping_own_lag()); the logger is not judged, its positions
#               being reconstructed from the track;
#   receipt     a ping of STK's VMS stream, its time judged from STK's receipt (plan 060 §1, rb_add_ping_own_lag()):
#               stamped at its receipt, lag 0; else the year's usual lag (about a minute), or, where its unit's level
#               departs from the usual by more than 2 min over the day and over the week around, the usual lag less
#               the departure (a unit's clock that drifts, up to two hours); STK's own units get none (plan 060 ask d);
#   measured    its vessel-stream-month's lag where the check's outcome is "offset" (rb_add_ping_time());
#   none        the reference, an aligned unit or a vessel with one stream: not moved;
#   unmeasured  every other ping, STK's arrivals kept as fixes (plan 048) and the logger among them: not moved, flagged by
#               its basis.
# The delivered time stays beside the harmonized one, as w_lon/w_lat beside lon/lat. A ping is never dropped: every row
# of the union is in the output once. The receipt and the unit are read here and not written: no column of STK's receipt
# is carried through the AIS layers (decision 196). Tested as the study's candidate on 2015, 2016 and 2026 (plan 059 step 5).
#
# The port tag is ramb::rb_flag_ping_port() (plan 013 phase 2, renamed in plan 014): a ping inside two polygons takes the
# smaller one, where the spatial join it replaced kept both and doubled the ping. The point geometry the join
# left in every row (`geom`) is no longer written; nothing read it. The H3 cell's depth, habitat and ICES area were
# put on every ping here until plan 049; they are the ICES datacall's (products/ices_vms_datacall/).

library(duckdbfs)
library(dplyr)
library(ramb)
library(tictoc)
duckdbfs::load_spatial()
# DuckDB's defaults: ramb 2026.10.28.3's port flag takes 1-4 GB a year where its window took 15-23 GB, so decision 235's
# cap is gone (plan 049); a spill folder that exists, as duckdbfs's does not
configure_duckdb_temp()

REFERENCE <- c("stk_ais", "stk_vms", "stk_unit")   # a copy is of a report STK's own streams hold (plan 059 ask a)
JUDGED <- c("astd", "astdB", "emodnet")
con <- duckdbfs::cached_connection()
x <- function(...) invisible(DBI::dbExecute(con, sprintf(...)))
ports <- sf::read_sf(fd_staging("aux", "ports.fgb")) |> transmute(port_id = pid, hid)
union_dir <- fd_staging("ais", "ping_union")
# every year the union wrote (decision 181)
years <- sort(as.integer(sub("year=", "", list.files(union_dir, pattern = "^year="))))
# TAG_YEARS (unset: the whole run, as targets runs it): a list of years tags only those, each year's folder replaced and
# no move; "move" tags none and runs only the move across New Year below. So a run can go year by year in fresh
# processes, each freeing its DuckDB spill: a year of 72 M rows spills about 35 GB (plan 048 step 3's scratch run,
# which held a second union beside the live one).
TAG_YEARS <- Sys.getenv("TAG_YEARS", "")
TAG_ALL <- !nzchar(TAG_YEARS)
if (!TAG_ALL && TAG_YEARS != "move") {
  years <- intersect(years, as.integer(strsplit(TAG_YEARS, ",")[[1]]))
  stopifnot("TAG_YEARS names years of the union" = length(years) > 0)
}
if (TAG_YEARS == "move") years <- integer(0)
# the check's lags as rb_create_ping_lags() gives them: one row per vessel, stream and month, `period` its first day
x("CREATE OR REPLACE TABLE lags AS SELECT vid, stream, make_date(CAST(year AS INT), CAST(month AS INT), 1) AS period,
     lag_s, outcome FROM read_parquet('%s')", fd_curated("check", "ais_feed_clock.parquet"))
# the usual lag of STK's own-stamped VMS pings, by year, as rb_add_ping_own_lag(lag_usual = ) takes it
x("CREATE OR REPLACE TABLE usual AS SELECT stream, make_date(CAST(year AS INT), 1, 1) AS period, lag_s
   FROM read_parquet('%s')", fd_curated("check", "ais_feed_clock_usual.parquet"))
receipt_dir <- fd_staging("ais", "stk_receipt")

# One write, partitioned by year, into an emptied folder. A second, month-partitioned copy of the loop once wrote
# 2009-2025 again beside it, which made the directory unreadable (Hive partition mismatch); nothing downstream filters
# on month.
if (TAG_ALL) unlink(fd_staging("ais", "ping_tagged"), recursive = TRUE)
for (YR in years) {
  if (!TAG_ALL) unlink(file.path(fd_staging("ais", "ping_tagged"), paste0("year=", YR)), recursive = TRUE)
  tic()
  print(YR)
  # every row of the year, from the year's own folder (decision 235), the stream from the union's own columns
  # (ping_stream_sql(), R/stk_trail.R; plan 048), which replaces the union's STK stream and io; a ping with no vid or no
  # position keeps its stream and is never moved
  # STK's receipt and unit beside its VMS pings (no left-side condition in ON: it makes a nested loop; the stream in the
  # CASE). A year with no VMS receipts reads an empty table of the same columns.
  rcp <- if (dir.exists(file.path(receipt_dir, paste0("year=", YR)))) {
    sprintf("read_parquet('%s/year=%d/*.parquet')", receipt_dir, YR)
  } else {
    "(SELECT NULL::INT AS vid, NULL::TIMESTAMP AS time, NULL::DOUBLE AS lon, NULL::DOUBLE AS lat, NULL::DOUBLE AS mid,
             NULL::TIMESTAMP AS recdate WHERE false)"
  }
  x("CREATE OR REPLACE TEMP TABLE u AS
     SELECT u.*, CASE WHEN u.stream = 'stk_vms' THEN r.recdate END AS receipt, CASE WHEN u.stream = 'stk_vms' THEN r.mid END AS mid
     FROM (SELECT u.* EXCLUDE (stream, io), %s AS stream FROM read_parquet('%s/year=%d/*.parquet') u) u
     LEFT JOIN %s r ON r.vid = u.vid AND r.time = u.time AND r.lon = u.lon AND r.lat = u.lat",
    ping_stream_sql(), union_dir, YR, rcp)
  n_in <- DBI::dbGetQuery(con, "SELECT count(*) n FROM u")$n
  # each step into a table before the next: as one query, 2014 ran out of memory at 19 GB, and staged it takes 16 s
  # with the same rows (2013 compared; plan 059's rebuild, 2026-11-01)
  tbl(con, "u") |>
    rb_add_ping_own_lag(reference = REFERENCE, method = c("copy", "receipt"), streams = JUDGED,
                        receipt = receipt, unit = mid, lag_usual = tbl(con, "usual")) |>
    compute(name = "s1", overwrite = TRUE) |>
    rb_add_ping_time(lags = tbl(con, "lags")) |>
    select(-lag_own_s, -lag_own_basis, -receipt, -mid) |>
    compute(name = "s2", overwrite = TRUE) |>
    ramb::rb_flag_ping_port(ports, keep = "hid") |>
    rename(pid = port_id) |>
    compute(name = "s3", overwrite = TRUE) |>
    # the union's year; a ping moved across New Year changes partition below
    mutate(year = as.integer(!!YR)) |>
    duckdbfs::write_dataset(fd_staging("ais", "ping_tagged"), partitioning = "year", format = "parquet")
  n_out <- open_dataset(file.path(fd_staging("ais", "ping_tagged"), paste0("year=", YR))) |> count() |> pull(n)
  stopifnot("every row of the union in the output once" = n_out == n_in)
  n_all <- if (YR == years[1]) n_in else n_all + n_in
  message(YR, ": ", format(n_in, big.mark = ","), " rows in and out")
  toc()
}

# A ping moved across New Year by its lag goes to the partition of its harmonised year, so that every later stage
# agrees with `time` on its year: voyages are cut at New Year, and the trail joins a fix's voyage on year(time). 53 astd
# pings in 2014-2026, moved back 11-63 s; the trail's count check found them (plan 059's rebuild, 2026-11-01). A ping
# with no time stays where it is.
tagged_dir <- fd_staging("ais", "ping_tagged")
# a year's own run (TAG_YEARS a list) stops before the move, which comes last, once
if (TAG_ALL || TAG_YEARS == "move") {
if (TAG_YEARS == "move") years <- sort(as.integer(sub("year=", "", list.files(tagged_dir, pattern = "^year="))))
for (YR in years) {
  src <- file.path(tagged_dir, paste0("year=", YR))
  yr_of <- sprintf("coalesce(year(time), %d)", YR)
  to <- DBI::dbGetQuery(con, sprintf("SELECT %s AS y, count(*) AS n FROM read_parquet('%s/*.parquet') WHERE %s <> %d
                                      GROUP BY ALL ORDER BY y", yr_of, src, yr_of, YR))
  if (!nrow(to)) next
  for (i in seq_len(nrow(to))) {
    dir.create(file.path(tagged_dir, paste0("year=", to$y[i])), showWarnings = FALSE)
    x("COPY (SELECT * FROM read_parquet('%s/*.parquet') WHERE %s = %d)
       TO '%s/year=%d/moved_from_%d.parquet' (FORMAT parquet)", src, yr_of, to$y[i], tagged_dir, to$y[i], YR)
  }
  old <- list.files(src, full.names = TRUE)
  x("COPY (SELECT * FROM read_parquet('%s/*.parquet') WHERE %s = %d) TO '%s/kept.tmp' (FORMAT parquet)",
    src, yr_of, YR, src)
  unlink(old)
  file.rename(file.path(src, "kept.tmp"), file.path(src, "data_0.parquet"))
  message(YR, ": ", paste(sprintf("%d pings to %d", to$n, to$y), collapse = ", "))
}
n_after <- open_dataset(tagged_dir) |> count() |> pull(n)
if (TAG_ALL) stopifnot("every row of the union in the output once, after the move" = n_after == n_all) else
  message("tagged after the move: ", format(n_after, big.mark = ","), " rows (the year-by-year run checks the total itself)")
}
