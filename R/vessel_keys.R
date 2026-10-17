# vessel_keys.R — what an IMO number and an MMSI are, as the crosswalk reads them (plan 021).
#
# Input:  character vectors of IMO numbers or MMSIs
# Output: is_valid_imo() a logical; mmsi_kind() the kind of station an MMSI names
#
# is_valid_imo() is the check of plan 008 §5.0: seven digits, the last the sum of the first six weighted 7..2, mod 10.
# Four scripts carry their own copy (sources/eu/convert.R, reference/vessels/identity_foreign.R, identity_all.R,
# ais_key_foreign.R); this one is for the scripts written since.

is_valid_imo <- function(x) {
  x  <- as.character(x)
  ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  d  <- matrix(0L, length(x), 7)
  if (any(ok)) d[ok, ] <- do.call(rbind, lapply(strsplit(x[ok], ""), as.integer))
  ok & (d[, 1] * 7 + d[, 2] * 6 + d[, 3] * 5 + d[, 4] * 4 + d[, 5] * 3 + d[, 6] * 2) %% 10 == d[, 7]
}

# The kind of station an MMSI names, by its form (ITU-R M.585). Only a `ship` - nine digits whose first three are an
# assigned MID - names a vessel; every other kind gets no vid (plan 021 §6 b). `mid` is the set of assigned MIDs
# (staging/aux/maritime_identification_digits.parquet). The feeds store MMSI as a number, so the leading zeros of a
# coast station or a group call are lost before this sees them: those fall under `malformed`.
mmsi_kind <- function(x, mid) {
  x <- as.character(x)
  dplyr::case_when(
    is.na(x) | !grepl("^[0-9]{9}$", x)  ~ "malformed",
    startsWith(x, "00")                 ~ "coast_station",
    startsWith(x, "0")                  ~ "group_call",
    startsWith(x, "111")                ~ "sar_aircraft",
    substr(x, 1, 3) %in% c("970", "972", "974") ~ "distress_beacon",
    startsWith(x, "98")                 ~ "craft_associated",
    startsWith(x, "99")                 ~ "aid_to_navigation",
    startsWith(x, "8")                  ~ "handheld",
    substr(x, 1, 3) %in% as.character(mid) ~ "ship",
    TRUE                                ~ "unassigned_mid")
}
