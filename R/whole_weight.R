# whole_weight.R — the whole weight of the logbook catch, by one rule for every source.
#
# Input:  catch rows with curated/logbook/catch.parquet's columns (schema, condition, catch, catch_whole), as a data
#         frame or a lazy DuckDB table; `by`, the columns that make one group
# Output: none; calc_whole_weight() returns one row per group: `by`, any summaries passed in `...`, `whole_weight`
#         (kg) and `whole_weight_basis`
#
# The whole weight is the grammar's term (plan 037 §4): the catch as logged, with its state, is the observation, and
# the whole weight a measure made from it, which a consumer reads by name. The logbook records a weight in the state
# the fish were landed in (`condition`: GUTT, UNGU, RELE), and the whole weight (`catch_whole`) only until 2022:
# fs_afladagbok fills its `afli` for ~98 % of rows thereafter not at all. Measured on the 1.39 M (station, species)
# rows adb shares with fs_afladagbok: GUTT weight is 0.80 of the whole weight (5-95 % range 0.789-0.80), UNGU and RELE
# are 1.00 (decision 066).
#   whole_weight = catch_whole   where recorded                          basis "recorded"
#                = catch / 0.8   GUTT, no whole weight                   basis "reconstructed"
#                = catch         UNGU, RELE, or the old afli schema      basis "recorded"
#                = catch         no condition at all (adb bycatch rows)  basis "synthesised"
# afli records the whole weight: on the 167,320 (vessel, date, species) the afli and fs_afladagbok logbooks share, afli
# equals fs's whole weight (`afli`) in 99.6 % of 166,713 comparable cases, and equals the GUTT weight / 0.8 (median
# ratio 1.250) and the UNGU weight (1.000) otherwise (measured 2026-10-03). A group's basis is the weakest of its rows:
# synthesised > reconstructed > recorded.
#
# The one copy of the rule (plan 024 §4): curate/catch_by_species_station.R calls it per station and species in
# DuckDB, curate/logbook.R per station in memory for the fate table. Only verbs dbplyr translates, so both run the
# same rule. A sum in `...` takes na.rm = TRUE, as SQL does; in memory a group of only NA then sums to 0, not NA.

calc_whole_weight <- function(catch, by, ...) {
  catch |>
    dplyr::mutate(whole_weight = dplyr::case_when(!is.na(catch_whole) ~ catch_whole,
                                                  condition == "GUTT" ~ catch / 0.8,
                                                  .default = catch),
                  .basis_rank  = dplyr::case_when(!is.na(catch_whole) ~ 1L,
                                                  condition == "GUTT" ~ 2L,
                                                  is.na(condition) & schema != "afli" ~ 3L,
                                                  .default = 1L)) |>
    dplyr::summarise(..., whole_weight = sum(whole_weight, na.rm = TRUE), .basis_rank = max(.basis_rank, na.rm = TRUE),
                     .by = dplyr::all_of(by)) |>
    dplyr::mutate(whole_weight_basis = dplyr::case_when(.basis_rank == 1L ~ "recorded",
                                                        .basis_rank == 2L ~ "reconstructed",
                                                        .default = "synthesised")) |>
    dplyr::select(-".basis_rank")
}
