# Candidate foreign identity for STK mobile-ids that never got an Icelandic vid.
#
# Input:  curated/vessel/vessel_ais_key.parquet, curated/vessel/vessel_identity_foreign.parquet,
#         raw/external/marinetraffic/*.xlsx (via reference/vessels/marinetraffic.R)
# Output: curated/check/ais_key_foreign_candidates.parquet - one row per candidate
#
# This is plan 008's Phase 5. A SEPARATE script from reference/vessels/ais_key.R
# on purpose - that file is already ~700 lines and a rewrite that changes
# behaviour and shape at once cannot be reviewed (plan 003's own closing note).
# The Icelandic cascade is untouched; this reads its finished output and adds a
# second-pass candidate list downstream.
#
# THIS SCRIPT ASSIGNS NOTHING. Per AGENTS.md's cycle rule, a foreign
# external_id becomes trusted only through a human reviewing this candidate
# list and re-entering the confirmed rows through overrides/ - same as
# curate/checks/ais_key_reused_callsign.R's own candidates.
#
# Cascade, in order (plan 008 §5/§7 Phase 5), each stage only trying what the
# previous stage left unmatched:
#   1. marinetraffic - a direct mobileid join, already-matched candidates from
#      one person's manual review (reference/vessels/marinetraffic.R). No
#      registry dependency.
#   2. cs, time-aware, against vessel_identity_foreign - the primary key in
#      practice (plan 008 §5: more complete than mmsi for several flags).
#   3. mmsi, time-aware, for whatever glid itself parses as a 9-digit MMSI.
# Both 2/3 reuse R/vid_match.R's match_time_aware(id_col = "external_id")
# (plan 008 Phase 4) rather than a new matcher.

library(dplyr)
library(nanoparquet)

key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet"))
identity_foreign <- read_parquet(fd_curated("vessel", "vessel_identity_foreign.parquet"))
source("reference/vessels/marinetraffic.R")  # provides marinetraffic_matches

unmatched <-
  key |>
  filter(is.na(vid) | vid <= 0, entity_class == "vessel") |>
  mutate(.rid = row_number())

cat("unmatched vessel-class mobile-ids:", nrow(unmatched),
    " pings:", sum(unmatched$pings), "\n")

## Stage 1: marinetraffic, direct mobileid join --------------------------------
is_valid_imo <- function(x) {
  ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  digs <- matrix(NA_integer_, length(x), 7)
  digs[ok, ] <- do.call(rbind, lapply(x[ok], function(s) as.integer(strsplit(s, "")[[1]])))
  checksum <- digs[, 1] * 7 + digs[, 2] * 6 + digs[, 3] * 5 +
              digs[, 4] * 4 + digs[, 5] * 3 + digs[, 6] * 2
  ok & (checksum %% 10) == digs[, 7]
}
mt <- marinetraffic_matches |>
  transmute(mid = mobileid,
            .external_id = if_else(is_valid_imo(imo), imo, paste0("marinetraffic_", mobileid)),
            .name = name, .cs = cs, .mmsi = mmsi,
            .basis = "mobileid_direct", .note = paste0("marinetraffic, vid_candidate=", vid_candidate))

stage1 <- unmatched |> inner_join(mt, by = "mid")
cat("stage 1 (marinetraffic direct):", nrow(stage1), "\n")

rest1 <- unmatched |> anti_join(stage1, by = ".rid")

## Stage 2: cs, time-aware ------------------------------------------------------
probe_cs <- rest1 |> transmute(.rid, val = glid, d1, d2)
hit_cs <- match_time_aware(probe_cs, identity_foreign, "cs", id_col = "external_id")
stage2 <- rest1 |>
  inner_join(hit_cs, by = ".rid") |>
  mutate(.basis = "cs", .note = "time-aware call-sign match")

rest2 <- rest1 |> anti_join(stage2, by = ".rid")

## Stage 3: mmsi, time-aware, only where glid itself is a 9-digit MMSI ----------
probe_mmsi <- rest2 |>
  transmute(.rid, val = if_else(grepl("^[0-9]{9}$", glid), glid, NA_character_), d1, d2)
hit_mmsi <- match_time_aware(probe_mmsi, identity_foreign, "mmsi", id_col = "external_id")
stage3 <- rest2 |>
  inner_join(hit_mmsi, by = ".rid") |>
  mutate(.basis = "mmsi", .note = "time-aware MMSI match")

cat("stage 2 (cs):", nrow(stage2), "  stage 3 (mmsi):", nrow(stage3), "\n")

## Combine, attach identity context for the reviewer ----------------------------
## One row per external_id for display purposes - the same external_id can
## carry several periods (a name/cs/mmsi change over time, plan 008 §5.0), and
## the reviewer needs one representative row, not a fan-out. The most recent
## period is shown; the full history is still in vessel_identity_foreign.parquet.
ident_lookup <- identity_foreign |>
  arrange(external_id, desc(t2)) |>
  distinct(external_id, .keep_all = TRUE) |>
  select(external_id, source, name, cs, mmsi, flag) |>
  rename(.src_name = name, .src_cs = cs, .src_mmsi = mmsi, .src_flag = flag)

candidates <-
  bind_rows(
    stage1 |> transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                        external_id = .external_id, basis = .basis, note = .note,
                        candidate_name = .name, candidate_cs = .cs, candidate_mmsi = .mmsi,
                        source = "marinetraffic"),
    stage2 |> left_join(ident_lookup, by = "external_id") |>
      transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                external_id, basis = .basis, note = .note,
                candidate_name = .src_name, candidate_cs = .src_cs, candidate_mmsi = .src_mmsi,
                source = source),
    stage3 |> left_join(ident_lookup, by = "external_id") |>
      transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                external_id, basis = .basis, note = .note,
                candidate_name = .src_name, candidate_cs = .src_cs, candidate_mmsi = .src_mmsi,
                source = source)
  ) |>
  select(-.rid)

cat("\ntotal candidates:", nrow(candidates),
    " distinct mobile-ids:", n_distinct(candidates$mid),
    " pings covered:", sum(candidates$pings), "\n")
print(candidates |> count(basis, name = "rows"))

still_unmatched <- nrow(unmatched) - n_distinct(candidates$mid)
cat("\nstill unmatched after all three stages:", still_unmatched,
    "mobile-ids - plan 008 Phase 6's ASTD residual pass\n")

write_curated(candidates, fd_curated("check", "ais_key_foreign_candidates.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         vessel_identity_foreign = fd_curated("vessel", "vessel_identity_foreign.parquet")))
