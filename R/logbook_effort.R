# logbook_effort.R — the e-logbook's times in the grammar's slots, the count, and the effort made from them.
#
# Input:  a fishing_sample-shaped frame with the new `gid` and its `gear` (ICES); elogbook_times() also the
#         e-logbook's three times as read into t1, t3, t4 (upphaf_timi, milli_timi, lok_timi) and gear_window
#         (curated/reference/gear_window.parquet); add_effort_count() also effort_count and effort_count_basis;
#         calc_effort() a fishing sample as curated/logbook/fishing_sample.parquet holds it, in memory
# Output: the same frame; elogbook_times() with t1-t4 in the grammar's slots as recorded, and duration_m NA with the
#         span's verdict in .duration_source and duration_m_raw; add_effort_count() with the count filled, its basis and
#         its unit; calc_effort() with effort_duration, effort_duration_unit, effort_duration_basis, effort and
#         effort_unit
#
# fs_afladagbok and adb are copies of one e-logbook, field for field (decision 171), so its times are read once
# here. Until plan 050 step 2 adb kept them as read, and curate/station_window.R moved its towed ones.
#
# The count is the grammar's `effort_count`: what fishes at once, hooks, nets, jigs, traps, and the trawls or
# dredges of a towed gear (plan 050 step 2). Each adapter reads its own and says how in `effort_count_basis`.
# add_effort_count() gives a towed gear or a seine that records none the one gear (basis "synthesised"), and leaves a
# passive gear's NA (basis "none").
#
# The effort is not stored (plan 050 ask e, maintainer, 2026-10-29). The times are the observation, and the count;
# which interval is the duration (a longline's t1 → t4 or t3 → t4), whether a twin tow counts twice, and in which
# unit, are the analyst's choices, which calc_effort() takes as arguments. A sample stores a duration only where its
# record gives one: afli's tow time, its jigs' hours or nights, aflaskeyti's haul length. The e-logbook gives times,
# so its duration_m is NA, and .duration_source says "times" (or "missing", or "implausible": the span of its times
# above the gear's limit, flagged and kept). duration_m_raw keeps that span.

LOGBOOK_ONE_GEAR <- c("OTB", "OTM", "DRB", "SDN", "PS")
LOGBOOK_NA_TIME <- .POSIXct(NA_real_, tz = "UTC")

elogbook_times <- function(d, gear_window) {
  towed  <- c("OTB", "OTM", "DRB")
  mobile <- c(towed, "SDN")
  static <- c("LLS", "GNS", "GND", "LHM", "FPO")
  d |>
    # Mobile (OTB/OTM/DRB/SDN):
    #   upphaf_timi = deployment ends (warp fully out / gear on bottom) → t2
    #   lok_timi    = retrieval starts (warp coming in)                 → t3
    #   t1 and t4 are not recorded                                      → NA
    #   SDN exception: if milli_timi ≠ upphaf_timi (3 distinct timestamps)
    #   interpret as t1=upphaf_timi, t2=milli_timi, t3=lok_timi.
    #   In current data milli_timi == upphaf_timi for 100% of SDN rows.
    #
    # Static (LLS/GNS/GND/LHM/FPO):
    #   upphaf_timi = deployment starts → t1
    #   milli_timi  = retrieval starts  → t3
    #   lok_timi    = retrieval ends    → t4
    #   t2 (deployment ends) not recorded → NA
    dplyr::mutate(
      .t1_raw  = t1,
      .t3_raw  = t3,
      .t4_raw  = t4,
      .mob_3ts = gear %in% mobile & !is.na(.t3_raw) & .t3_raw != .t1_raw,
      t1 = dplyr::case_when(gear %in% towed               ~ LOGBOOK_NA_TIME,
                            gear == "SDN" & !.mob_3ts      ~ LOGBOOK_NA_TIME,
                            gear == "SDN" &  .mob_3ts      ~ .t1_raw,
                            .default                       = .t1_raw),
      t2 = dplyr::case_when(gear %in% towed               ~ .t1_raw,
                            gear == "SDN" & !.mob_3ts      ~ .t1_raw,
                            gear == "SDN" &  .mob_3ts      ~ .t3_raw,
                            .default                       = LOGBOOK_NA_TIME),
      t3 = dplyr::case_when(gear %in% mobile ~ .t4_raw, .default = .t3_raw),
      t4 = dplyr::case_when(gear %in% mobile ~ LOGBOOK_NA_TIME, .default = .t4_raw)) |>
    dplyr::select(-c(.t1_raw, .t3_raw, .t4_raw, .mob_3ts)) |>
    # The span the limit judges: a tow t3 − t2, a set t4 − t1, its whole length.
    dplyr::mutate(duration_m = dplyr::case_when(
      gear %in% mobile ~ as.numeric(difftime(t3, t2, units = "mins")),
      gear %in% static ~ as.numeric(difftime(t4, t1, units = "mins")),
      .default = NA_real_)) |>
    # The span is judged against the gear's limit and flagged (R/duration_limit.R); the times stay as recorded, and
    # a consumer of them leaves out the end an implausible span ran to (judged_time_sql()).
    flag_duration_limit(gear_window, zero_ok = TRUE) |>
    dplyr::mutate(.duration_source = dplyr::if_else(.duration_source == "data", "times", .duration_source),
                  duration_m = NA_real_)
}

add_effort_count <- function(d) {
  d |>
    dplyr::mutate(
      .one = is.na(effort_count) & gear %in% LOGBOOK_ONE_GEAR,
      effort_count = dplyr::if_else(.one, 1, as.numeric(effort_count)),
      effort_count_basis = dplyr::case_when(.one                ~ "synthesised",
                                            is.na(effort_count) ~ "none",
                                            .default            = effort_count_basis),
      effort_count_unit = dplyr::case_when(gear %in% c("OTB", "OTM")  ~ "trawls",
                                           gear == "DRB"              ~ "dredges",
                                           gear %in% c("SDN", "PS")   ~ "seines",
                                           gear == "LLS"              ~ "hooks",
                                           gear %in% c("GNS", "GND")  ~ "nets",
                                           gear == "LHM"              ~ "jigs",
                                           gear == "FPO"              ~ "traps")) |>
    dplyr::select(-.one)
}

# A recorded count, or NA where it is none: 0 gear does not fish.
recorded_count <- function(n) dplyr::if_else(n > 0, as.numeric(n), NA_real_)

# The effort of each sample, by the analyst's choices:
#   from, to   the interval, as two of "t1".."t4" for every row; by default a mobile gear's t2 → t3 and a static
#              gear's t1 → t4, the whole set from shooting to the end of hauling (a longline's soak alone is t1 → t3)
#   by_count   TRUE multiplies the duration by effort_count (hook-hours; a twin tow twice its time), FALSE leaves the
#              gear's time alone
#   unit       "hours", "minutes" or "days"
#   implausible  FALSE leaves out what the duration limit flagged (.duration_source "implausible"): the end it ran to
#              and the duration, as the windows do (R/duration_limit.R); TRUE keeps them as recorded
#   flagged    FALSE leaves out the times the app profile flags (t1_action ... t4_action "flag",
#              R/logbook_app_profile.R), as the windows do; TRUE keeps them as recorded. A noted time is always kept
# Where the interval's times are missing, the record's own duration (duration_m) stands in, so afli's tows and jigs
# keep theirs. effort_duration_basis says which: "times", "recorded", or "none". A seine's setting is its row: count
# them for settings. In memory only (difftime is not translated to SQL): collect() a lazy table first.
calc_effort <- function(sample, from = NULL, to = NULL, by_count = TRUE, unit = c("hours", "minutes", "days"),
                        implausible = FALSE, flagged = FALSE) {
  unit <- match.arg(unit)
  per_minute <- c(minutes = 1, hours = 60, days = 1440)[[unit]]
  mobile <- c("OTB", "OTM", "DRB", "SDN")
  if (!implausible) {
    bad <- sample$.duration_source %in% "implausible"
    sample$t3[bad & sample$gear %in% mobile] <- NA
    sample$t4[bad & sample$gear %in% c("LLS", "GNS", "GND", "LHM", "FPO") & sample$schema %in% c("fs_afladagbok", "adb") &
                !is.na(sample$t1)] <- NA
    sample$duration_m[bad] <- NA
  }
  if (!flagged) {
    for (f in intersect(c("t1", "t2", "t3", "t4"), names(sample))) {
      act <- sample[[paste0(f, "_action")]]
      if (!is.null(act)) sample[[f]][act %in% "flag"] <- NA
    }
  }
  t_from <- if (is.null(from)) dplyr::if_else(sample$gear %in% mobile, sample$t2, sample$t1) else sample[[from]]
  t_to   <- if (is.null(to))   dplyr::if_else(sample$gear %in% mobile, sample$t3, sample$t4) else sample[[to]]
  span <- as.numeric(difftime(t_to, t_from, units = "mins"))
  span <- dplyr::if_else(span >= 0, span, NA_real_)
  sample |>
    dplyr::mutate(
      effort_duration_basis = dplyr::case_when(!is.na(span)       ~ "times",
                                               !is.na(duration_m) ~ "recorded",
                                               .default           = "none"),
      effort_duration = dplyr::coalesce(span, duration_m) / per_minute,
      effort_duration_unit = unit,
      effort = if (by_count) effort_count * effort_duration else effort_duration,
      effort_unit = if (by_count) paste0(sub("s$", "", effort_count_unit), "-", unit) else unit)
}
