# Every STK ping of a mobile-id that has a vessel must have a vessel.
#
# Input:  curated/vessel/vessel_ais_key.parquet, raw/ais/stk/trail
# Output: curated/check/ais_key_coverage.parquet - one row per stretch of pings no period covers
#
# The maintainer's invariant (2026-09-29): when a mobile-id is assigned to any vessel, a vessel is
# assigned for its FULL period, first ping to last, so no ping is unassigned. The key assigns
# pings with between(time, d1, d2) (sources/stk/convert.R), so a ping outside every period, or
# inside a period whose vid is negative (the ODS's `drop` rows), is silently lost.
#
# Measured 2026-09-29: 36 mobile-ids leave 35,468 pings outside every period, and 8 ODS `drop`
# rows leave more on negative vids. The largest single cause is a typo: mid 101097's first row
# has d1 = 2008-06-04 after d2 = 2008-05-20 (the mid's first ping is 2007-06-04), so it covers
# nothing and 34,307 pings go unassigned.
#
# This check REPORTS and PROPOSES a fill. It never writes a vid. The fill is deterministic:
#   * before the first period: the first period's vid, extended back to the first ping;
#   * between two periods of the SAME vid: that vid;
#   * between two periods of DIFFERENT vids: the gap is cut at its largest silence (nobody
#     transmits there, so nothing moves); with no silence it is cut at the midpoint and flagged
#     ambiguous for a person to place;
#   * a negative vid (a deliberate drop) is listed for a decision, never filled by a rule.
# Stretches that begin in STK's start-up years (before 2009) are flagged `startup_phase`: the
# earliest pings of a mid may predate a stable identity, so a person confirms those fills.
# The script asserts that applying its own proposals leaves no ping unassigned.

library(dplyr)
library(tidyr)
library(nanoparquet)

STK_GLOB <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))

con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
days <- dplyr::as_tibble(DBI::dbGetQuery(con, sprintf(
  "select mid, cast(time as date) d, count(*) n from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1, 2 order by 1, 2", STK_GLOB)))
DBI::dbDisconnect(con, shutdown = TRUE)

# A mobile-id "has a vessel" when any of its rows carries a positive vid. Periods are the
# positive-vid rows whose dates are valid (d1 <= d2); an invalid row covers nothing.
has_vessel <- key |> filter(!is.na(vid), vid > 0) |> distinct(mid) |> pull(mid)
periods <- key |>
  filter(mid %in% has_vessel, !is.na(vid), vid > 0) |>
  transmute(mid, vid, d1, d2, valid = d1 <= d2) |>
  arrange(mid, d1)
inv <- periods |> filter(!valid)

dd <- days |> filter(mid %in% has_vessel)
covered <- dd |>
  inner_join(filter(periods, valid), by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  distinct(mid, d) |>
  mutate(covered = TRUE)
gapdays <- dd |>
  left_join(covered, by = c("mid", "d")) |>
  filter(is.na(covered)) |>
  arrange(mid, d) |>
  group_by(mid) |>
  # a run is consecutive PING days that no period covers; a silence between two ping days splits it
  mutate(run = cumsum(is.na(lag(d)) | as.numeric(d - lag(d)) > 1)) |>
  ungroup()

runs <- gapdays |>
  group_by(mid, run) |>
  summarise(from = min(d), to = max(d), pings = sum(n), .groups = "drop")

vp <- filter(periods, valid)
fill <- runs |>
  rowwise() |>
  mutate(
    before = { p <- vp[vp$mid == mid & vp$d2 < from, ]; if (nrow(p)) p[which.max(p$d2), ] else NULL } |> list(),
    after  = { p <- vp[vp$mid == mid & vp$d1 > to, ];   if (nrow(p)) p[which.min(p$d1), ] else NULL } |> list(),
    vid_before = if (is.null(before)) NA_integer_ else as.integer(before$vid),
    vid_after  = if (is.null(after))  NA_integer_ else as.integer(after$vid),
    position = case_when(is.na(vid_before) ~ "before the first period",
                         is.na(vid_after)  ~ "after the last period",
                         vid_before == vid_after ~ "between two periods of one vid",
                         .default = "between periods of different vids"),
    vid_fill = case_when(is.na(vid_before) ~ vid_after, is.na(vid_after) ~ vid_before,
                         vid_before == vid_after ~ vid_before, .default = NA_integer_),
    ambiguous = position == "between periods of different vids") |>
  ungroup() |>
  select(-before, -after)

# The run lies inside ONE silence-free stretch of ping days, so a two-vid gap can only be cut at
# its midpoint here; the wider silence (if any) sits between the runs, and each run is already
# bounded by it. Tell the reviewer how big the ambiguity is.
fill <- fill |>
  mutate(split_at = if_else(ambiguous, from + as.integer((to - from) / 2), as.Date(NA)),
         rule = case_when(!ambiguous ~ "fill with the neighbouring vid",
                          .default = "two different vids: cut at the midpoint of the pings, a person places it"),
         # STK's start-up years are untrustworthy: a mid's earliest pings may predate a stable
         # identity (back-filled history, test transmissions, a device not yet on its vessel)
         startup_phase = from < as.Date("2009-01-01"),
         invalid_row = mid %in% inv$mid & position == "before the first period",
         note = if_else(invalid_row, "the mid's first row has d1 after d2: probable date typo, extend it back to the first ping", NA_character_))

# Deliberate drops: a negative vid puts the pings on nothing
neg <- key |> filter(!is.na(vid), vid <= 0) |> select(mid, vid, d1, d2) |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  group_by(mid, vid, d1, d2) |>
  summarise(pings = sum(n), .groups = "drop") |>
  transmute(mid, run = NA_integer_, from = d1, to = d2, pings, vid_before = NA_integer_, vid_after = NA_integer_,
            position = "a negative vid (a deliberate drop)", vid_fill = NA_integer_, ambiguous = FALSE,
            split_at = as.Date(NA), rule = "a person decides which vessel, or that it is not one",
            startup_phase = from < as.Date("2009-01-01"), invalid_row = FALSE, note = paste0("key vid ", vid))

out <- bind_rows(fill, neg) |> arrange(mid, from)

# The proposal must close every gap: apply it to a copy of the periods and count again
fixed <- bind_rows(
  vp |> select(mid, d1, d2),
  fill |> filter(!ambiguous) |> transmute(mid, d1 = from, d2 = to),
  fill |> filter(ambiguous) |> transmute(mid, d1 = from, d2 = to))
left <- dd |>
  inner_join(fixed, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |> distinct(mid, d)
still <- anti_join(dd, left, by = c("mid", "d"))
stopifnot("the proposed fill leaves pings unassigned" = nrow(still) == 0)

print(out |> group_by(position, startup_phase) |> summarise(mids = n_distinct(mid), stretches = n(), pings = sum(pings), .groups = "drop") |>
        knitr::kable(caption = "ais_key_coverage"))
print(tibble(mids_with_a_vessel = length(has_vessel), pings_on_them = sum(dd$n),
             pings_outside_every_period = sum(fill$pings), after_the_proposed_fill = sum(still$n)) |>
        knitr::kable(caption = "the invariant"))

write_curated(out, fd_curated("check", "ais_key_coverage.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet")))
