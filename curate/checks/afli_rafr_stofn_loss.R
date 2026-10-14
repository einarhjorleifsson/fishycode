# Electronic logbook submissions the source system's own merge did not carry
# through, reported per vessel.
#
# Input:  raw/logbooks/afli/{rafr_stofn,stofn}.parquet, curated/vessel/vessel.parquet
# Output: curated/check/afli_rafr_stofn_loss.parquet - one row per vessel
#
# rafr_stofn is the electronic feed from the vessels; stofn is the source
# system's merged bookkeeping table, and the adapter reads stofn. 23,570 rows are
# live in the feed (eytt = 0) and absent from the merge, so they are absent from
# everything this repo builds. Declared as
# curate/corrections/afli_rafr_stofn_stations_dropped.yml.
#
# They are not admitted (decision 098): the landings show their trips complete
# without them, and most are the same hauls submitted again. So a high share here
# does NOT mean a vessel's figures are wrong, from 2007-09 on. This reports where
# the feed and the merge differ, per vessel and year; before 2007-09 no landing
# link can say whether the absent rows are copies.
#
# It REPORTS and corrects nothing.
#
# Bounded to 2003-2019: rafr_stofn stops being populated around 2019, and 163,233
# negative visir appear in stofn over 2020-2022 with no counterpart in the feed.
# After that the loss can be neither measured nor ruled out.

library(dplyr)
library(nanoparquet)

feed <-
  read_parquet(fd_raw("logbooks", "afli", "rafr_stofn.parquet")) |>
  select(visir, vid = skipnr, eytt, vedags) |>
  # One row carries a 1899 fishing date and eight carry 2000, before electronic
  # reporting existed. They are kept in the counts - they are real rows - but
  # excluded from a vessel's reported year range, where one of them made vid 1134
  # read "1899-2020".
  mutate(year = as.integer(format(as.Date(vedags), "%Y")),
         year = if_else(year %in% 2003:2030, year, NA_integer_))

merged <- read_parquet(fd_raw("logbooks", "afli", "stofn.parquet")) |> select(visir)

# eytt = 1 is a deleted submission, and the merge excludes those by design: only
# 327 of 16,912 reach stofn. Deleted rows are not the finding and are dropped
# here rather than reported as loss.
live <-
  feed |>
  filter(eytt == 0L) |>
  mutate(lost = !visir %in% merged$visir)

## Per vessel -------------------------------------------------------------------
by_vessel <-
  live |>
  group_by(vid) |>
  summarise(stations_electronic = n(),
            stations_lost       = sum(lost),
            pct_lost            = 100 * mean(lost),
            first_year          = suppressWarnings(min(year, na.rm = TRUE)),
            last_year           = suppressWarnings(max(year, na.rm = TRUE)),
            .groups = "drop")

# A vessel with a handful of electronic stations can read 50% on one lost row.
# The threshold is a reporting floor, not a claim about the vessel: below it the
# percentage is noise, so it is marked rather than dropped.
MIN_STATIONS <- 50L

out <-
  by_vessel |>
  left_join(
    read_parquet(fd_curated("vessel", "vessel.parquet")) |> select(vid, vessel, cs, loa),
    by = "vid") |>
  mutate(
    share_absent = case_when(
      stations_electronic < MIN_STATIONS ~ "too few stations to judge",
      pct_lost >= 25                     ~ "a quarter or more absent",
      pct_lost >= 10                     ~ "10-25 % absent",
      pct_lost >= 5                      ~ "5-10 % absent",
      .default                           = "under 5 % absent")) |>
  arrange(desc(pct_lost)) |>
  select(vid, vessel, cs, loa, stations_electronic, stations_lost, pct_lost,
         first_year, last_year, share_absent)

## By year ----------------------------------------------------------------------
# pct is computed from n() and sum(), not from mean(lost): summarise() evaluates
# left to right, so a `pct = 100 * mean(lost)` written after `lost = sum(lost)`
# averages the SUM and reports 2700% for 2003. It did, until this line.
by_year <- live |> group_by(year) |> summarise(electronic = n(), lost = sum(lost),
                                               pct = 100 * lost / electronic,
                                               .groups = "drop")

## Report -----------------------------------------------------------------------
print(knitr::kable(
  tibble(measure = c("live electronic submissions", "absent from stofn",
                     "overall loss", "vessels with 50+ stations",
                     "losing 5% or more", "losing 10% or more",
                     "losing 25% or more"),
         value = c(format(nrow(live), big.mark = ","),
                   format(sum(live$lost), big.mark = ","),
                   sprintf("%.2f%%", 100 * mean(live$lost)),
                   sum(out$stations_electronic >= MIN_STATIONS),
                   sum(out$share_absent %in% c("5-10 % absent", "10-25 % absent", "a quarter or more absent")),
                   sum(out$share_absent %in% c("10-25 % absent", "a quarter or more absent")),
                   sum(out$share_absent == "a quarter or more absent"))),
  caption = "afli_rafr_stofn_loss"))

print(knitr::kable(by_year, digits = 2, caption = "loss by year"))

print(knitr::kable(
  out |> filter(stations_electronic >= MIN_STATIONS) |> head(20),
  digits = 1, caption = "vessels with the largest share absent from stofn"))

write_curated(out, fd_curated("check", "afli_rafr_stofn_loss.parquet"),
              inputs = c(rafr_stofn = fd_raw("logbooks", "afli", "rafr_stofn.parquet"),
                         stofn      = fd_raw("logbooks", "afli", "stofn.parquet"),
                         vessel     = fd_curated("vessel", "vessel.parquet")))
