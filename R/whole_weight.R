# whole_weight.R — the whole weight of the logbook catch, by one rule for every source.
#
# Input:  catch rows with curated/logbook/catch.parquet's columns (schema, sid, condition, catch, catch_whole), as a
#         data frame or a lazy DuckDB table; `by`, the columns that make one group; `factors`, the factor table
#         (curated/reference/whole_weight_factor.parquet), and then also `date`, the station's day, and where a
#         correction names another state, `condition_corrected`
# Output: none; calc_whole_weight() returns one row per group: `by`, any summaries passed in `...`, `whole_weight`
#         (kg) and `whole_weight_basis`; with `factors` also `whole_weight_logbook` and `whole_weight_factor`
#
# The whole weight is the grammar's term (plan 037 §4): the catch as logged, with its state, is the observation, and
# the whole weight a measure made from it, which a consumer reads by name. The logbook records a weight in the state
# the fish were landed in (`condition`: GUTT, UNGU, RELE), and the whole weight (`catch_whole`) only until 2022:
# fs_afladagbok fills its `afli` for ~98 % of rows thereafter not at all.
#
# With `factors` (plan 051 step 4), the whole weight is the landings' factor of the day for the species and the
# state (plan 051 ask a): logged and landed whole weights of the same gutted fish then agree.
#   whole_weight = catch x factor   a correction names the state (Nephrops tails)    basis "reconstructed"
#                = catch x factor   GUTT: the species' gutted factor on the day       basis "reconstructed"
#                = catch_whole      where recorded, no factor read                    basis "recorded"
#                = catch            UNGU, RELE, or the old afli schema                basis "recorded"
#                = catch            no condition at all (adb bycatch rows)            basis "synthesised"
# The factor is the table's `logbook` row for (sid, condition) on the day, in Iceland's waters: the landings' own
# gutted factor (cod 1.1905 since 1997-09-01, the flatfish 1.087), roe's for lumpfish logged gutted, and the logbooks'
# own 1.25 (decision 066) for a species the landings give no gutted factor. `whole_weight_factor` is the largest
# factor read in the group. afli's weight has no state in the merge (condition NA) and stays as stored, round(GUTT x
# 1.25) + UNGU, until plan 037 phase 1 carries afli_sent's (TODO 115).
#
# Without `factors`, and always as `whole_weight_logbook` beside it, the logbook's own whole weight (decision 066):
# the recorded `catch_whole`, else GUTT / 0.8 (basis "reconstructed"), else the weight as logged. Measured on the
# 1.39 M (station, species) rows adb shares with fs_afladagbok: GUTT weight is 0.80 of the whole weight (5-95 % range
# 0.789-0.80), UNGU and RELE are 1.00. afli equals fs's whole weight (`afli`) in 99.6 % of 166,713 comparable cases
# (measured 2026-10-03). A group's basis is the weakest of its rows: synthesised > reconstructed > recorded.
#
# The one copy of the rule (plan 024 §4): curate/catch_by_species_station.R calls it per station and species in
# DuckDB with the factor table, products/user_tables.R per catch row, and curate/logbook.R per station in memory for
# the fate table, without it. Only verbs dbplyr translates, so every caller runs the same rule. A sum in `...` takes
# na.rm = TRUE, as SQL does; in memory a group of only NA then sums to 0, not NA.

calc_whole_weight <- function(catch, by, ..., factors = NULL) {
  catch <- catch |>
    dplyr::mutate(.whole_logbook = dplyr::case_when(!is.na(catch_whole) ~ catch_whole,
                                                    condition == "GUTT" ~ catch / 0.8,
                                                    .default = catch),
                  .rank_logbook = dplyr::case_when(!is.na(catch_whole) ~ 1L,
                                                   condition == "GUTT" ~ 2L,
                                                   is.na(condition) & schema != "afli" ~ 3L,
                                                   .default = 1L))
  basis <- function(x) x |>
    dplyr::mutate(whole_weight_basis = dplyr::case_when(.basis_rank == 1L ~ "recorded",
                                                        .basis_rank == 2L ~ "reconstructed",
                                                        .default = "synthesised")) |>
    dplyr::select(-".basis_rank")
  if (is.null(factors)) {
    return(catch |>
             dplyr::summarise(..., whole_weight = sum(.whole_logbook, na.rm = TRUE),
                              .basis_rank = max(.rank_logbook, na.rm = TRUE), .by = dplyr::all_of(by)) |>
             basis())
  }

  # The factor of the day: a row for the species first, the fallback for any species after. An open end is a far
  # date inside the join only.
  f <- factors |>
    dplyr::filter(scope == "logbook") |>
    dplyr::transmute(.fsid = sid, .fcond = condition, .from = dplyr::coalesce(from, as.Date("1900-01-01")),
                     .to = dplyr::coalesce(to, as.Date("2999-12-31")), .factor = factor) |>
    dplyr::collect()
  if (inherits(catch, "tbl_lazy")) {
    f <- dplyr::copy_to(dbplyr::remote_con(catch), f, name = "whole_weight_factor_logbook", overwrite = TRUE)
  }
  if (!"condition_corrected" %in% colnames(catch)) catch <- dplyr::mutate(catch, condition_corrected = NA_character_)
  own <- dplyr::filter(f, !is.na(.fsid))
  any <- dplyr::filter(f, is.na(.fsid)) |> dplyr::select(-".fsid") |> dplyr::rename(.factor_any = .factor)
  catch |>
    dplyr::mutate(.cond = dplyr::coalesce(condition_corrected, condition), .day = as.Date(date)) |>
    dplyr::left_join(own, by = dplyr::join_by(sid == .fsid, .cond == .fcond, between(.day, .from, .to))) |>
    dplyr::select(-".from", -".to") |>
    dplyr::left_join(any, by = dplyr::join_by(.cond == .fcond, between(.day, .from, .to))) |>
    dplyr::mutate(.factor = dplyr::coalesce(.factor, .factor_any),
                  whole_weight = dplyr::if_else(!is.na(.factor), catch * .factor, .whole_logbook),
                  .basis_rank = dplyr::case_when(!is.na(.factor) ~ 2L,
                                                 !is.na(catch_whole) ~ 1L,
                                                 is.na(condition) & schema != "afli" ~ 3L,
                                                 .default = 1L)) |>
    dplyr::summarise(..., whole_weight = sum(whole_weight, na.rm = TRUE),
                     whole_weight_logbook = sum(.whole_logbook, na.rm = TRUE),
                     whole_weight_factor = max(.factor, na.rm = TRUE),
                     .basis_rank = max(.basis_rank, na.rm = TRUE), .by = dplyr::all_of(by)) |>
    # in memory a group with no factor gives max() = -Inf, in SQL NULL: NA in both
    dplyr::mutate(whole_weight_factor = dplyr::if_else(whole_weight_factor >= 0, whole_weight_factor, NA_real_)) |>
    basis()
}
