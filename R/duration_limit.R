# duration_limit.R — the one place a logbook duration is judged implausible.
#
# Input:  a fishing_sample-shaped frame with the NEW gid and duration_m (minutes), and
#         curated/reference/gear_window.parquet (dur_max_min per gid; reference/gear/windows.R)
# Output: flag_duration_limit() gives the same frame with duration_m_raw and .duration_source;
#         judged_time_sql() gives the SQL for t3, t4 or duration_m as a consumer of the times reads them
#
# Replaces the cap tables that sources/afli/convert.R and sources/fs_afladagbok/convert.R
# each carried. Those capped a long duration AT the cap, which turned an error into a
# precise-looking value and cut real long operations short (plan 010 §12b). Then (decision 057)
# a duration above the gear's limit became NA in the adapters, and the e-logbook's end time with it.
# Since plan 050 ask h (maintainer, 2026-10-29) the sample keeps what was recorded and only flags it:
#   duration_m_raw   the value judged, always kept
#   .duration_source data (a recorded duration) | times (the e-logbook's span) | missing | implausible
#                    (above dur_max_min; a recorded duration of 0 or less; a span below 0)
#   duration_m       as recorded
# A gid with no limit is never implausible. The limit is applied where the times are read: the windows
# (curate/station_window.R), the voyage links (curate/voyage_gear.R, curate/trip_reconciled.R), the audit
# (curate/checks/allocation_audit.R), through judged_time_sql(), and calc_effort() (R/logbook_effort.R). There the
# end a flagged duration made is not believed: a mobile gear's t3 (afli's is t2 + its tow time, the e-logbook's the
# span's end), the e-logbook's static t4, and the duration itself. afli's static times are recorded apart from its
# duration, and stand.

# The rule is ramb::rb_limit_record_duration() (plan 014 phase 2), which sets the duration NA; this keeps it. Below:
# a recorded duration of 0 or less is no duration (afli's tow times, hours and nights), so `zero_ok` is FALSE. A span
# of the e-logbook's times (`zero_ok = TRUE`) is implausible only when negative: a span of 0 is an app that wrote one
# time in each slot (2,199 handlines, about 200 nets, lines and traps, 2026-10-29), which the windows take with a
# typical haul; leaving its end out turned about 190 of them into day windows.
flag_duration_limit <- function(d, limits, zero_ok = FALSE) {
  ramb::rb_limit_record_duration(d, limits, gear = gid, duration = duration_m) |>
    dplyr::rename(.duration_source = duration_source) |>
    dplyr::mutate(duration_m = duration_m_raw,
                  .duration_source = dplyr::if_else(!is.na(duration_m) & (duration_m < 0 | (duration_m == 0 & !zero_ok)),
                                                    "implausible", .duration_source))
}

# `col` is "t3", "t4" or "duration_m"; `a` the fishing sample's alias in the query.
judged_time_sql <- function(col, a = "fs") {
  bad <- sprintf("%s.\".duration_source\" = 'implausible'", a)
  when <- switch(col,
    t3 = sprintf("%s AND %s.gear IN ('OTB', 'OTM', 'DRB', 'SDN')", bad, a),
    t4 = sprintf("%s AND %s.gear IN ('LLS', 'GNS', 'GND', 'LHM', 'FPO') AND %s.schema IN ('fs_afladagbok', 'adb')",
                 bad, a, a),
    duration_m = bad,
    stop("judged_time_sql(): col is t3, t4 or duration_m"))
  sprintf("CASE WHEN %s THEN NULL ELSE %s.%s END", when, a, col)
}
