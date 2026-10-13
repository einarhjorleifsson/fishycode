# whack_shims.R — adapters for the whack filters removed from ramb on
# 2026-10-11, so the evaluation scripts in this directory keep running
# unchanged. Not for production code: new work uses rb_flag_ping_impossible()
# directly.
#
# Data-frame calls go through the public rb_flag_ping_impossible(). The lazy
# fwdbwd calls stay on the internal SQL branch (ramb:::.rb_whack_fwdbwd):
# whack_corrupt_axis.R composes the rendered SQL into a larger query and
# ais_residual_whacks.R relies on the NA edge rows — both are properties of
# that branch, not of the flag layer.
#
# Column mapping: the flag layer labels rows in ping_flag (NA = usable, else
# the stage). The old columns are rebuilt from it:
#   whack, whack2  <- !is.na(ping_flag)
#   whack_stage, whack_sda <- ping_flag        (NA, "vmask", "spike", "forward")
#
# Row order: the flag layer keeps the input order; the old functions sorted
# by (vid, time). The scripts here arrange by (vid, time) before calling, so
# the results are identical.

rb_whack_clean <- function(x, kn_max = 25, max_gap_h = 4, min_dt_s = 10,
                           batch_pings = 5e6, ...) {
  r <- ramb::rb_flag_ping_impossible(x, method = "clean", kn_max = kn_max,
                                     max_gap_h = max_gap_h, min_dt_s = min_dt_s,
                                     batch_pings = batch_pings, ...)
  if (inherits(r, "tbl_lazy")) {
    r |>
      dplyr::mutate(whack_stage = ping_flag, whack = !is.na(ping_flag)) |>
      dplyr::select(-ping_flag)
  } else {
    r$whack_stage <- r$ping_flag
    r$whack <- !is.na(r$ping_flag)
    r$ping_flag <- NULL
    r
  }
}

rb_whack_sda <- function(x, kn_max = 25, ...) {
  r <- ramb::rb_flag_ping_impossible(x, method = "sda", kn_max = kn_max, ...)
  r$whack_sda <- r$ping_flag
  r$ping_flag <- NULL
  r
}

rb_whack_forward <- function(x, kn_max = 25, max_gap_h = 4, min_dt_s = 10, ...) {
  r <- ramb::rb_flag_ping_impossible(x, method = "forward", kn_max = kn_max,
                                     max_gap_h = max_gap_h,
                                     min_dt_s = min_dt_s, ...)
  r$whack2 <- !is.na(r$ping_flag)
  r$ping_flag <- NULL
  r
}

rb_whack_fwdbwd <- function(x, kn_max = 25, min_dt_s = 10, ...) {
  if (inherits(x, "tbl_lazy")) {
    return(ramb:::.rb_whack_fwdbwd(x, kn_max = kn_max, min_dt_s = min_dt_s, ...))
  }
  r <- ramb::rb_flag_ping_impossible(x, method = "fwdbwd", kn_max = kn_max,
                                     min_dt_s = min_dt_s, ...)
  r$whack <- !is.na(r$ping_flag)
  r$ping_flag <- NULL
  r
}
