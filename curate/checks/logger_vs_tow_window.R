# logger_vs_tow_window.R — do the GPS logger's fixes start and end at the logbook's t2 / t3? (plan 012)
#
# Input:  curated/logbook/sensor_gps, curated/logbook/station_window.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# The logger belongs to the logbook system (afli schema, .sid < 0). If its recording is switched on and off with
# the tow, its fixes carry no evidence of their own about when the tow happened or how fast: their span would
# equal the recorded window, and judging them against that window is circular. Per OTB station with a recorded
# tow window: first and last logger fix against the window start/end, and the share of fixes inside the window.

library(dplyr)
library(duckdbfs)
source(here::here("R/paths.R"))

w <- open_dataset(fd_curated("logbook", "station_window.parquet")) |>
  filter(schema == "afli", gear == "OTB", phase == "tow", win_basis == "recorded", gid %in% 6:8) |>
  select(.sid, gid, w_start, w_end, t1, t4)

st <- open_dataset(fd_curated("logbook", "sensor_gps")) |>
  filter(year >= 2008) |> distinct(.sid, time) |>
  inner_join(w, by = ".sid") |>
  group_by(.sid, gid, w_start, w_end, t1, t4) |>
  summarise(n = n(), first = min(time), last = max(time),
            inside = sum(as.numeric(time >= w_start & time <= w_end)),
            inside_t1_t4 = sum(as.numeric(time >= coalesce(t1, w_start) & time <= coalesce(t4, w_end))), .groups = "drop") |>
  collect() |>
  mutate(d_start = as.numeric(difftime(first, w_start, units = "mins")),
         d_end   = as.numeric(difftime(last,  w_end,   units = "mins")),
         dur     = as.numeric(difftime(w_end, w_start, units = "mins")),
         d_t1    = as.numeric(difftime(first, t1, units = "mins")),
         d_t4    = as.numeric(difftime(last,  t4, units = "mins")),
         t1_to_t4 = as.numeric(difftime(t4, t1, units = "mins")))

cat("stations with a logger and a recorded tow window:", nrow(st), "\n\n")
q <- \(x) round(quantile(x, c(.05, .25, .5, .75, .95)), 1)
cat("first logger fix minus window start (min):\n"); print(q(st$d_start))
cat("last logger fix minus window end (min):\n");    print(q(st$d_end))
cat("\nshare of stations whose first fix is within 1 / 5 / 15 min of the start, last within the same of the end\n")
print(sapply(c(1, 5, 15), \(m) c(start = mean(abs(st$d_start) <= m), end = mean(abs(st$d_end) <= m))))
cat("\nshare of all logger fixes inside the window:", round(sum(st$inside) / sum(st$n), 4), "\n")
cat("median window length (min):", median(st$dur), "  median logger span (min):", median(as.numeric(difftime(st$last, st$first, units = "mins"))), "\n")
cat("\nlogger fixes per station (median) and per hour of window (median):", median(st$n), round(median(st$n / (st$dur / 60)), 1), "\n")

# The window is t2 - t3 (on the bottom). The logger may run from t1 (shot) to t4 (haul finished).
cat("\nwhere t1 and t4 are recorded (", sum(!is.na(st$d_t1) & !is.na(st$d_t4)), "stations):\n", sep = "")
cat("first logger fix minus t1 (min):\n"); print(q(st$d_t1[!is.na(st$d_t1)]))
cat("last logger fix minus t4 (min):\n");  print(q(st$d_t4[!is.na(st$d_t4)]))
cat("share within 15 min of t1, of t4:", round(mean(abs(st$d_t1) <= 15, na.rm = TRUE), 3), round(mean(abs(st$d_t4) <= 15, na.rm = TRUE), 3), "\n")
cat("share of logger fixes inside [t1, t4] (t2/t3 where missing):", round(sum(st$inside_t1_t4) / sum(st$n), 4), "\n")
cat("median t1 to t4 (min):", median(st$t1_to_t4, na.rm = TRUE), "\n")

# Speed of the logger, by minutes since the window start / end (fish trawl) -------------------------------------
fx <- open_dataset(fd_curated("logbook", "sensor_gps")) |> filter(year >= 2008, !is.na(speed), abs(speed - 1) > 1e-6) |>
  distinct(.sid, time, speed) |>
  inner_join(w |> filter(gid == 6), by = ".sid") |>
  mutate(rel_start = date_diff("second", w_start, time) / 60, rel_end = date_diff("second", w_end, time) / 60)
cat("\nlogger speed (kn, from m/s) by minutes after window END (negative = before the end), fish trawl\n")
fx |> filter(rel_end >= -60, rel_end < 180) |> mutate(b = floor(rel_end / 15) * 15) |>
  group_by(b) |> summarise(fixes = n(), mean_kn = mean(speed * 1.943844), q25 = quantile(speed * 1.943844, .25), q75 = quantile(speed * 1.943844, .75)) |>
  arrange(b) |> collect() |> print(n = Inf)
cat("\nlogger speed by minutes after window START (negative = before), fish trawl\n")
fx |> filter(rel_start >= -60, rel_start < 60) |> mutate(b = floor(rel_start / 15) * 15) |>
  group_by(b) |> summarise(fixes = n(), mean_kn = mean(speed * 1.943844)) |> arrange(b) |> collect() |> print(n = Inf)

# Last tow of a trip against the others: does the logger keep towing speed past the recorded end? ---------------
wl <- open_dataset(fd_curated("logbook", "station_window.parquet")) |>
  filter(schema == "afli", gear == "OTB", phase == "tow", win_basis == "recorded", gid == 6) |>
  group_by(.tid) |> mutate(pos = row_number(w_start), n_tows = n()) |> ungroup() |>
  filter(n_tows >= 2) |> mutate(is_last = pos == n_tows) |> select(.sid, w_end, is_last)
open_dataset(fd_curated("logbook", "sensor_gps")) |> filter(year >= 2008, !is.na(speed), abs(speed - 1) > 1e-6) |>
  distinct(.sid, time, speed) |>
  inner_join(wl, by = ".sid") |>
  mutate(rel_end = date_diff("second", w_end, time) / 60, kn = speed * 1.943844) |>
  filter(rel_end >= 0, rel_end < 120) |>
  mutate(b = floor(rel_end / 15) * 15) |>
  group_by(is_last, b) |>
  summarise(fixes = n(), mean_kn = mean(kn), at_tow_speed = mean(as.numeric(kn >= 2.625 & kn <= 4.7)),
            steaming_over_6 = mean(as.numeric(kn > 6)), .groups = "drop") |>
  arrange(b, is_last) |> collect() |> print(n = Inf)
