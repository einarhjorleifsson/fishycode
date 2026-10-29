# logbook_effort.R — the e-logbook's times in the grammar's slots, and the effort, for the logbook adapters.
#
# Input:  a fishing_sample-shaped frame with the new `gid` and its `gear` (ICES); elogbook_times() also the
#         e-logbook's three times as read into t1, t3, t4 (upphaf_timi, milli_timi, lok_timi) and gear_window
#         (curated/reference/gear_window.parquet); add_effort() also duration_m, effort_count and effort_count_basis
# Output: the same frame; elogbook_times() with t1-t4 in the grammar's slots, duration_m, duration_m_raw and
#         .duration_source; add_effort() with the units of the count and of the duration, effort_duration,
#         effort_unit and effort, and the count filled
#
# fs_afladagbok and adb are copies of one e-logbook, field for field (decision 171), so its times are read once
# here. Until plan 050 step 2 adb kept them as read, and curate/station_window.R moved its towed ones.
#
# The count is the grammar's `effort_count`: what fishes at once, hooks, nets, jigs, traps, and the trawls or
# dredges of a towed gear (plan 050 step 2). Each adapter reads its own and says how in `effort_count_basis`.
# add_effort() gives a towed gear or a seine that records none the one gear (basis "synthesised"), and leaves a
# passive gear's NA (basis "none"). The unit follows the gear, so a station without its gear table's row still has
# its unit and duration. afli, fs_afladagbok and adb share both.

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
    # Duration:
    #   Mobile (OTB/OTM/DRB/SDN): t3 − t2 (= lok_timi − upphaf_timi)
    #   Static (LLS/GNS/GND/LHM/FPO): t4 − t1 (approximate; true soak =
    #     t3 − t1, but including hauling is consistent with afli treatment)
    dplyr::mutate(duration_m = dplyr::case_when(
      gear %in% mobile ~ as.numeric(difftime(t3, t2, units = "mins")),
      gear %in% static ~ as.numeric(difftime(t4, t1, units = "mins")),
      .default = NA_real_)) |>
    # duration_m_raw is kept; an implausible duration becomes NA (R/duration_limit.R). The
    # end time that produced it is not believed either: a mobile tow's t3 and a static
    # set's t4 are set to NA with it, so no window is drawn from an impossible span.
    apply_duration_limit(gear_window) |>
    dplyr::mutate(t3 = dplyr::if_else(.duration_source == "implausible" & gear %in% mobile, LOGBOOK_NA_TIME, t3),
                  t4 = dplyr::if_else(.duration_source == "implausible" & gear %in% static, LOGBOOK_NA_TIME, t4))
}

add_effort <- function(d) {
  d |>
    dplyr::mutate(
      .one = is.na(effort_count) & gear %in% LOGBOOK_ONE_GEAR,
      effort_count = dplyr::if_else(.one, 1, as.numeric(effort_count)),
      effort_count_basis = dplyr::case_when(.one                ~ "synthesised",
                                            is.na(effort_count) ~ "none",
                                            .default            = effort_count_basis),
      # The count's unit and the duration's are columns of their own (maintainer, 2026-10-29), so the analyst can
      # recombine them: hook-hours as well as hook-days. effort_unit names their product, as before.
      effort_count_unit = dplyr::case_when(gear %in% c("OTB", "OTM")  ~ "trawls",
                                           gear == "DRB"              ~ "dredges",
                                           gear %in% c("SDN", "PS")   ~ "seines",
                                           gear == "LLS"              ~ "hooks",
                                           gear %in% c("GNS", "GND")  ~ "nets",
                                           gear == "LHM"              ~ "jigs",
                                           gear == "FPO"              ~ "traps"),
      effort_duration_unit = dplyr::case_when(gear %in% c("OTB", "OTM", "DRB")   ~ "minutes",
                                              gear %in% c("SDN", "PS")           ~ "settings",
                                              gear %in% c("LLS", "GNS", "GND")   ~ "days",
                                              gear %in% c("LHM", "FPO")          ~ "hours"),
      effort_duration = dplyr::case_when(effort_duration_unit == "minutes"  ~ duration_m,
                                         effort_duration_unit == "hours"    ~ duration_m / 60,
                                         effort_duration_unit == "days"     ~ duration_m / (60 * 24),
                                         effort_duration_unit == "settings" ~ 1),
      effort_unit = dplyr::case_when(gear %in% c("OTB", "OTM", "DRB") ~ "gear-minutes",
                                     gear %in% c("SDN", "PS")         ~ "setting",
                                     gear == "LLS"                    ~ "hook-days",
                                     gear %in% c("GNS", "GND")        ~ "net-days",
                                     gear == "LHM"                    ~ "jig-hours",
                                     gear == "FPO"                    ~ "trap-hours"),
      effort = effort_count * effort_duration) |>
    dplyr::select(-.one)
}

# A recorded count, or NA where it is none: 0 gear does not fish.
recorded_count <- function(n) dplyr::if_else(n > 0, as.numeric(n), NA_real_)
