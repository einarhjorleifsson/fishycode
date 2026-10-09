# duration_limit.R — the one place a logbook duration is judged implausible.
#
# Input:  a fishing_sample-shaped frame with the NEW gid and duration_m (minutes), and
#         curated/reference/gear_window.parquet (dur_max_min per gid; reference/gear/windows.R)
# Output: the same frame with duration_m_raw, .duration_source and duration_m
#
# Replaces the cap tables that sources/afli/convert.R and sources/fs_afladagbok/convert.R
# each carried. Those capped a long duration AT the cap, which turned an error into a
# precise-looking value and cut real long operations short (plan 010 §12b). Here:
#   duration_m_raw   what the source said, always kept
#   .duration_source data (used as is) | missing | implausible (above dur_max_min)
#   duration_m       NA when implausible, otherwise the raw value
# A gid with no limit is never implausible.

# The rule is ramb::rb_limit_record_duration() (plan 014 phase 2); this keeps fishycode's column name.
apply_duration_limit <- function(d, limits) {
  ramb::rb_limit_record_duration(d, limits, gear = gid, duration = duration_m) |>
    dplyr::rename(.duration_source = duration_source)
}
