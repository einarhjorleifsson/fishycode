# ais_ping_tag.R — the feeds put on one clock, and every merged ping tagged with its port polygon.
# Side: flow, step 0. See plans 014 and 059.
#
# Input:  staging/ais/ping_union                  all pings, from curate/ais_ping_union.R
#         curated/check/ais_feed_clock.parquet    the lag per vessel, stream and month (curate/checks/ais_feed_clock.R)
#         raw/oracle/stk/trail                    its port event rows, to tell them from fixes
#         staging/aux/ports.fgb                   harbour polygons (pid, hid)
# Output: staging/ais/ping_tagged                 partitioned by year: the union's columns with `time` harmonized,
#                                                 beside it `time_delivered`, `lag_s`, `lag_basis` and `stream`; `pid`
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
#   measured    its vessel-stream-month's lag where the check's outcome is "offset" (rb_add_ping_time());
#   none        the reference, an aligned unit or a vessel with one stream: not moved;
#   unmeasured  every other ping, STK's port event rows and the logger among them: not moved, flagged by its basis.
# The delivered time stays beside the harmonized one, as w_lon/w_lat beside lon/lat. A ping is never dropped: every row
# of the union is in the output once. Tested as the study's candidate on 2015, 2016 and 2026 (plan 059 step 5).
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
# the check's lags as rb_create_ping_lags() gives them: one row per vessel, stream and month, `period` its first day
x("CREATE OR REPLACE TABLE lags AS SELECT vid, stream, make_date(CAST(year AS INT), CAST(month AS INT), 1) AS period,
     lag_s, outcome FROM read_parquet('%s')", fd_curated("check", "ais_feed_clock.parquet"))

# One write, partitioned by year, into an emptied folder. A second, month-partitioned copy of the loop once wrote
# 2009-2025 again beside it, which made the directory unreadable (Hive partition mismatch); nothing downstream filters
# on month.
unlink(fd_staging("ais", "ping_tagged"), recursive = TRUE)
for (YR in years) {
  tic()
  print(YR)
  x("CREATE OR REPLACE TEMP TABLE ev AS %s", stk_event_rows_sql(YR))
  # every row of the year, from the year's own folder (decision 235), the stream beside (R/stk_trail.R); a ping with no
  # vid or no position keeps its stream and is never moved
  x("CREATE OR REPLACE TEMP TABLE u AS
     SELECT u.*, %s AS stream FROM read_parquet('%s/year=%d/*.parquet') u
     LEFT JOIN ev e ON u.time = e.time AND u.lon = e.lon AND u.lat = e.lat", ping_stream_sql(), union_dir, YR)
  n_in <- DBI::dbGetQuery(con, "SELECT count(*) n FROM u")$n
  tbl(con, "u") |>
    rb_add_ping_own_lag(reference = REFERENCE, method = "copy", streams = JUDGED) |>
    rb_add_ping_time(lags = tbl(con, "lags")) |>
    select(-lag_own_s, -lag_own_basis) |>
    ramb::rb_flag_ping_port(ports, keep = "hid") |>
    rename(pid = port_id) |>
    # the delivered time's year, so that a ping moved across New Year stays in its partition
    mutate(year = as.integer(!!YR)) |>
    duckdbfs::write_dataset(fd_staging("ais", "ping_tagged"), partitioning = "year", format = "parquet")
  n_out <- open_dataset(file.path(fd_staging("ais", "ping_tagged"), paste0("year=", YR))) |> count() |> pull(n)
  stopifnot("every row of the union in the output once" = n_out == n_in)
  message(YR, ": ", format(n_in, big.mark = ","), " rows in and out")
  toc()
}
