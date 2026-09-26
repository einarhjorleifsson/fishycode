# A small loader for the two hand-curated MarineTraffic match sheets.
#
# Input:  raw/external/marinetraffic/STK_MARINETRAFFIC_MATCTH.xlsx,
#         raw/external/marinetraffic/CS_MARINE_TRAFFIC_MATCH4.xlsx
# Output: `marinetraffic_matches` — one row per STK mobileid (in-memory; no
#         staging/ table, ~1,230 rows is not worth persisting a copy of)
#
# Not a sources/ adapter and not a row in vessel_identity_foreign.parquet
# (plan 008 §5, corrected 2026-09-27 while building Phase 5): these rows are
# already-matched STK-mobileid-keyed candidates from one person's manual
# lookups on marinetraffic.com (§6), not vessel-registry periods with a
# native id and a time window - forcing them into that table's shape would be
# artificial. This is a direct mobileid join, consumed by
# reference/vessels/ais_key_foreign.R, and it needs human review before any
# of it is trusted (AGENTS.md's cycle rule) - it is candidates, not fact.
#
# CS_MARINE_TRAFFIC_MATCH4.xlsx's 823 rows are a strict subset, by mobileid,
# of STK_MARINETRAFFIC_MATCTH.xlsx's 1,230 - the latter is used whole;
# n.vms (a rough confidence count from the STK trail itself) is carried over
# from the former where it exists.

library(readxl)
library(dplyr)

.load_marinetraffic <- function() {
  a <- suppressWarnings(read_excel(fd_raw("external", "marinetraffic", "STK_MARINETRAFFIC_MATCTH.xlsx")))
  b <- suppressWarnings(read_excel(fd_raw("external", "marinetraffic", "CS_MARINE_TRAFFIC_MATCH4.xlsx")))

  a |>
    transmute(mobileid, name, cs, imo = as.character(imo), mmsi = as.character(mmsi),
              class, vid_candidate = vid, date_recorded, comment) |>
    left_join(b |> transmute(mobileid, n_vms = n.vms), by = "mobileid") |>
    distinct(mobileid, .keep_all = TRUE)
}

marinetraffic_matches <- .load_marinetraffic()
cat("marinetraffic candidates:", nrow(marinetraffic_matches),
    " with a vid candidate:", sum(!is.na(marinetraffic_matches$vid_candidate)), "\n")
