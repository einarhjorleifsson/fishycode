# survey_tow_times.R — how well the track finds a tow's start and end, scored against the spring survey's tows.
# Side: flow (reads the AIS trail). See TODO 60, decision 104.
#
# Input:  $FISHYDATA/raw/survey/is_smb_stations.csv     (dump/survey/smb_stations.R; 2008-2019 overlap the AIS)
#         curated/ais/trail/year=*                      (vid, time, speed, stay)
#         curated/reference/gear_window.parquet         (bottom trawl's speed range, gid 6)
# Output: curated/check/survey_tow_times.parquet        one row per survey tow
#
# A REPORT, not a correction. The survey's tow times are recorded on the bridge under the survey protocol (one-hour
# tows), so they are the ground truth for the track's own tow boundaries that the commercial logbooks cannot be
# (decision 090). Each tow is paired with the vessel's towing stretch as decision 092 pairs commercial tows: the
# stretch at bottom trawl's speed range on the ±10 min median speed, the survey tows as the prior. Columns: the tow
# (id, vid, year, start, end), the paired stretch (s_start, s_end), dt_start_s and dt_end_s (stretch minus survey,
# seconds), n_fix (fixes inside the tow) and gap_med_min (the median fix spacing within 30 min of it).
# Where the same tow is in a logbook, the logbook's times equal the survey's (the same bridge entry): no independent
# check of the logbook, so it is not scored here.
suppressMessages(library(dplyr))
sv <- readr::read_csv(fd_raw("survey", "is_smb_stations.csv"), na = "NA", show_col_types = FALSE) |>
  filter(!is.na(t1), !is.na(t2), t2 > t1) |>
  transmute(id = as.character(id), vid = as.integer(vid), year = as.integer(year), start = t1, end = t2)
trail_years <- as.integer(sub("year=", "", list.files(fd_curated("ais", "trail"), pattern = "^year=")))
sv <- sv |> filter(year %in% trail_years)
gw <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> filter(gid == 6) |> collect()
out <- list()
for (y in sort(unique(sv$year))) {
  s <- sv |> filter(year == y)
  w0 <- min(s$start) - 6 * 3600; w1 <- max(s$end) + 6 * 3600
  p <- duckdbfs::open_dataset(file.path(fd_curated("ais", "trail"), paste0("year=", y))) |>
    filter(vid %in% !!unique(s$vid), time >= !!w0, time <= !!w1) |>
    select(vid, time, speed, stay) |> collect() |>
    mutate(speed_min = gw$s1, speed_max = gw$s2)
  st <- ramb::rb_cut_record_stretches(p, records = s, start = "start", end = "end", stay = "stay", window_s = 600)
  k <- ramb::rb_link_record_stretches(s, st, key = "id", start = "start", end = "end")
  gaps <- p |> arrange(vid, time) |> group_by(vid) |>
    mutate(dt = as.numeric(difftime(lead(time), time, units = "mins"))) |> ungroup()
  g <- s |> rowwise() |>
    mutate(n_fix = sum(gaps$vid == vid & gaps$time >= start & gaps$time < end),
           gap_med_min = median(gaps$dt[gaps$vid == vid & gaps$time >= start - 1800 & gaps$time < end + 1800], na.rm = TRUE)) |>
    ungroup() |> select(id, n_fix, gap_med_min)
  out[[length(out) + 1]] <- s |> select(id, vid, year, start, end) |>
    left_join(k |> select(id, stretch_id, s_start, s_end, dt_start_s, dt_end_s), by = "id") |>
    left_join(g, by = "id")
}
d <- bind_rows(out)
write_curated(d, fd_curated("check", "survey_tow_times.parquet"),
              inputs = c(fd_raw("survey", "is_smb_stations.csv"), fd_curated("reference", "gear_window.parquet")))
message(sprintf("survey_tow_times: %d tows, %d paired", nrow(d), sum(!is.na(d$stretch_id))))
