# vid_match.R — time-aware evidence matching for STK mobile-ids.
#
# Input:  a probe (one row per mobile-id/loid/glid period, with .rid, d1, d2, and
#         the field being tested) and vessel_identity (vid, t1, t2, cs, uid, mmsi
#         periods)
# Output: .rid, vid — one row per probe row that resolved to exactly one vid
#
# ais_key.R matched a call sign, uid or mmsi against ONE row per vid — the
# vessel's current value, from vessel.parquet / v_mmsi. A call sign that moved
# keel therefore matched without reference to when: TFBR was stamped on vid 1473
# (HÓLMBERG, struck 2006) for a mobile-id first transmitting in 2011, because
# vessel.parquet's cs column still read TFBR for 1473 even though the registry
# had since given the same call sign to two other hulls (plan 003 §3.1).
#
# vessel_identity carries the history instead of one current row, so a match
# here requires the mobile-id's own [d1,d2] window to overlap the period that
# actually held the identifier. And where two vids' periods both qualify — TFBR
# in 2011 genuinely fits both 2815 DÍSA and 3047 HILDUR — this returns neither.
# The old cascade had no way to say "don't know"; picking one of two equally
# plausible hulls is not an improvement on picking the wrong one.
#
# id_col (plan 008 §7 Phase 4): the identity key column defaults to "vid", so
# every call site above is unchanged. Passing id_col = "external_id" runs the
# identical logic against vessel_identity_foreign.parquet's external_id
# instead — generalizing the function rather than writing a second matcher
# for the foreign-vessel case (reference/vessels/ais_key_foreign.R).

# A bare `a1 <= b2 & b1 <= a2` returns NA - filtered out, silently - whenever
# either identity bound is NA, and `identity_foreign.R` builds exactly that:
# FRO's single open snapshot leaves t2 NA (plan 008 §5.0/§7 Phase 2), GFW's
# leaves both t1 and t2 NA (no dates at all in that source). Found 2026-09-27
# via zero stage-2/3 matches ever resolving to source == "fro" or "gfw" in
# ais_key_foreign.R, despite both contributing rows to the identity table -
# an unbounded period is supposed to mean "matches any query window," not
# "never matches." Icelandic vessel_identity.parquet never has an NA bound
# (identity.R coalesces to a sentinel date instead), so this is a no-op there
# - verified by reproducing decision 037's ais_key.R baseline unchanged.
.overlaps <- function(a1, a2, b1, b2) {
  b1 <- dplyr::coalesce(b1, as.Date("1900-01-01"))
  b2 <- dplyr::coalesce(b2, as.Date("2100-12-31"))
  a1 <= b2 & b1 <= a2
}

# Subset identity to the columns this match needs, with the id column and
# evidence column(s) renamed to fixed internal names so the join/filter code
# below never has to know what id_col actually is.
.identity_cols <- function(identity, id_col, value_cols) {
  keep <- identity[, c(id_col, "t1", "t2", value_cols), drop = FALSE]
  names(keep)[names(keep) == id_col] <- "..id"
  keep
}

#' Match a single evidence field (cs, uid or mmsi) against vessel_identity.
#'
#' @param probe data frame with .rid, val (character, the field to test), d1, d2
#' @param identity vessel_identity (or vessel_identity_foreign)
#' @param evidence_col name of the column in `identity` to match `val` against
#' @param id_col name of the identity-key column in `identity` — "vid" for the
#'   Icelandic registry, "external_id" for the foreign one (plan 008)
match_time_aware <- function(probe, identity, evidence_col, id_col = "vid") {
  cand <- identity[!is.na(identity[[evidence_col]]), ]
  cand <- .identity_cols(cand, id_col, evidence_col)
  names(cand)[names(cand) == evidence_col] <- "val"
  out <- probe |>
    dplyr::filter(!is.na(.data$val)) |>
    dplyr::inner_join(cand, by = "val", relationship = "many-to-many") |>
    dplyr::filter(.overlaps(d1, d2, t1, t2)) |>
    dplyr::distinct(.rid, ..id) |>
    dplyr::add_count(.rid, name = "n_cand") |>
    dplyr::filter(n_cand == 1) |>
    dplyr::select(.rid, ..id)
  names(out)[names(out) == "..id"] <- id_col
  out
}

#' Confirm a vid already stated by one field against a corroborating field.
#'
#' The identifier field (e.g. loid parsing as a vid, or as a uid) names a
#' candidate vid outright; the corroborating field (e.g. glid, a call sign) must
#' belong to THAT SAME vid's own identity period, overlapping the mobile-id's
#' window. Unlike `match_time_aware`, this never has to choose among candidates
#' — the identifier already chose one — so it only ever confirms or rejects.
#'
#' @param probe data frame with .rid, a column named `id_col` (the candidate),
#'   val (corroborating value), d1, d2
#' @param identity vessel_identity (or vessel_identity_foreign)
#' @param evidence_col name of the column in `identity` to match `val` against
#' @param id_col name of the candidate-id column in both `probe` and `identity`
confirm_vid <- function(probe, identity, evidence_col, id_col = "vid") {
  cand <- identity[!is.na(identity[[evidence_col]]), ]
  cand <- .identity_cols(cand, id_col, evidence_col)
  names(cand)[names(cand) == evidence_col] <- "val"
  probe <- probe
  names(probe)[names(probe) == id_col] <- "..id"
  out <- probe |>
    dplyr::filter(!is.na(.data$..id), !is.na(.data$val)) |>
    dplyr::inner_join(cand, by = c("..id", "val")) |>
    dplyr::filter(.overlaps(d1, d2, t1, t2)) |>
    dplyr::distinct(.rid, ..id)
  names(out)[names(out) == "..id"] <- id_col
  out
}

#' Confirm a vid stated by one field against TWO corroborating fields at once
#' (e.g. loid is a uid and glid is a call sign — both must belong to the same
#' vid's identity period, overlapping the window). Stronger than two separate
#' `match_time_aware` calls, which could each resolve to a different vid.
#'
#' @param probe data frame with .rid, val1, val2, d1, d2
#' @param identity vessel_identity (or vessel_identity_foreign)
#' @param col1,col2 names of the columns in `identity` to match val1/val2 against
#' @param id_col name of the identity-key column in `identity`
match_identity_pair <- function(probe, identity, col1, col2, id_col = "vid") {
  cand <- identity[!is.na(identity[[col1]]) & !is.na(identity[[col2]]), ]
  cand <- .identity_cols(cand, id_col, c(col1, col2))
  names(cand)[names(cand) == col1] <- "val1"
  names(cand)[names(cand) == col2] <- "val2"
  out <- probe |>
    dplyr::filter(!is.na(.data$val1), !is.na(.data$val2)) |>
    dplyr::inner_join(cand, by = c("val1", "val2")) |>
    dplyr::filter(.overlaps(d1, d2, t1, t2)) |>
    dplyr::distinct(.rid, ..id) |>
    dplyr::add_count(.rid, name = "n_cand") |>
    dplyr::filter(n_cand == 1) |>
    dplyr::select(.rid, ..id)
  names(out)[names(out) == "..id"] <- id_col
  out
}
