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

apply_duration_limit <- function(d, limits) {
  stopifnot(all(c("gid", "duration_m") %in% names(d)),
            all(c("gid", "dur_max_min") %in% names(limits)))
  d |>
    dplyr::left_join(limits |> dplyr::select(gid, dur_max_min) |> dplyr::distinct(gid, .keep_all = TRUE),
                     by = "gid") |>
    dplyr::mutate(
      duration_m_raw   = duration_m,
      .duration_source = dplyr::case_when(
        is.na(duration_m)                              ~ "missing",
        !is.na(dur_max_min) & duration_m > dur_max_min ~ "implausible",
        .default                                       = "data"),
      duration_m       = dplyr::if_else(.duration_source == "implausible", NA_real_, duration_m)) |>
    dplyr::select(-dur_max_min)
}
