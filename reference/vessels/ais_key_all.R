# *** TEMPORARY - scaffolding for plan 008 Phase 9, not a permanent target. ***
# One row per STK mid, whatever identity it now has - the combined lookup
# plan 008 Phase 9 (TODO item 22) needs before ais_ping_union.R/stk/convert.R
# can be generalized off `vid` alone. This script is a throwaway answer to
# "is there a full mid list yet" (2026-09-27) - once Phase 9's actual
# generalization lands (the join in stk/convert.R and ais_ping_union.R
# rewritten to key off identity_type/identity_id directly), THIS script and
# its output (curated/vessel/ais_key_all.parquet) should be deleted, not kept
# alongside it. Record that removal in curate/decisions/, not here.
#
# Input:  curated/vessel/vessel_ais_key.parquet, curated/check/ais_key_foreign_candidates.parquet,
#         overrides/stk_foreign_identity_reviewed.csv
# Output: curated/vessel/ais_key_all.parquet - one row per mid, identity_type/identity_id resolved
#         where possible, NA where not (still genuinely unresolved).
#
# Resolves nothing new - purely combines what ais_key.R (Icelandic) and
# ais_key_foreign.R (foreign candidates + overrides/) already decided. A
# flagged foreign candidate only resolves here if it has a "confirmed" row in
# overrides/ - per AGENTS.md's cycle rule, review is the only way a flagged
# external_id becomes trusted, this script does not do that reviewing itself.

library(dplyr)
library(nanoparquet)

key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet"))
candidates <- read_parquet(fd_curated("check", "ais_key_foreign_candidates.parquet"))
reviewed <- read.csv("overrides/stk_foreign_identity_reviewed.csv", colClasses = "character")

reviewed_confirmed <- reviewed |>
  filter(decision == "confirmed") |>
  transmute(mid = as.integer(mid), .override_external_id = external_id)

cand_lookup <- candidates |>
  select(mid, external_id, needs_review) |>
  left_join(reviewed_confirmed, by = "mid") |>
  transmute(mid, .cand_external_id = external_id, needs_review, .override_external_id)

ais_key_all <-
  key |>
  left_join(cand_lookup, by = "mid") |>
  mutate(
    identity_type = case_when(
      !is.na(vid) & vid > 0                                      ~ "vid",
      !is.na(.cand_external_id) & !needs_review                  ~ "external_id",
      !is.na(.override_external_id)                              ~ "external_id",
      .default = NA_character_),
    identity_id = case_when(
      identity_type == "vid"                                     ~ as.character(vid),
      !is.na(.override_external_id)                               ~ .override_external_id,
      identity_type == "external_id"                             ~ .cand_external_id,
      .default = NA_character_),
    identity_status = case_when(
      identity_type == "vid"                                     ~ "icelandic",
      !is.na(.cand_external_id) & !needs_review                  ~ "foreign_unflagged",
      !is.na(.override_external_id)                               ~ "foreign_reviewed",
      entity_class != "vessel"                                    ~ "not_vessel_class",
      !is.na(.cand_external_id) & needs_review                    ~ "foreign_flagged_unreviewed",
      .default = "unresolved")
  ) |>
  select(-.cand_external_id, -.override_external_id, -needs_review)

cat("total mids:", nrow(ais_key_all), "\n")
print(ais_key_all |> count(identity_status, sort = TRUE))

write_curated(ais_key_all, fd_curated("vessel", "ais_key_all.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         ais_key_foreign_candidates = fd_curated("check", "ais_key_foreign_candidates.parquet")))
