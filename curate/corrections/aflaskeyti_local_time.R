# aflaskeyti_local_time.R — Faroese summer haul times in dw_aflaskeyti are local: move them to UTC.
# Side: preprocessing (aflaskeyti). See plan 014 and plan 026 §3b.
#
# Input:  staging/aflaskeyti/fishing_sample.parquet  (t1-t4 as reported)
#         raw/oracle/dw/dw_aflaskeyti.parquet        (upprunaland_cd, the flag: the station key is a row's id)
# Output: staging/aflaskeyti/time.parquet            (.sid, t1, t2, t3, t4, t_shift_min, time_basis) — a side
#         table, joined onto the fishing sample by curate/logbook.R and read by curate/aflaskeyti_trip.R.
#
# Declaration and evidence: curate/corrections/aflaskeyti_local_time.yml. Faroese summer time follows the EU rule,
# from 01:00 UTC on the last Sunday of March to 01:00 UTC on the last Sunday of October.

library(dplyr)
library(lubridate)

SHIFT_MIN <- -60L

last_sunday_0100 <- function(year, month) {
  d <- make_date(year, month + 1, 1) - days(1)
  make_datetime(year, month, mday(d - days((wday(d) - 1) %% 7)), 1, tz = "UTC")
}

fs <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "fishing_sample.parquet")) |>
  select(.sid, t1, t2, t3, t4) |>
  collect()
flag <- duckdbfs::open_dataset(fd_raw("oracle", "dw", "dw_aflaskeyti.parquet")) |>
  select(.sid = aflaskeyti_id, flag = upprunaland_cd) |>
  collect() |>
  mutate(.sid = as.numeric(.sid))

time <- fs |>
  left_join(flag, by = ".sid", relationship = "one-to-one") |>
  mutate(start  = coalesce(t2, t1),
         summer = start >= last_sunday_0100(year(start), 3) & start < last_sunday_0100(year(start), 10),
         t_shift_min = if_else(flag == "FRO" & summer, SHIFT_MIN, 0L),
         across(c(t1, t2, t3, t4), \(t) t + minutes(t_shift_min)),
         time_basis  = if_else(t_shift_min != 0L, "reconstructed", "recorded")) |>
  select(.sid, t1, t2, t3, t4, t_shift_min, time_basis)

stopifnot(!anyNA(flag$flag[match(fs$.sid, flag$.sid)]))
cat(sprintf("aflaskeyti local time: %d of %d hauls moved by %d min\n",
            sum(time$t_shift_min != 0L), nrow(time), SHIFT_MIN))

time |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "time.parquet"))
