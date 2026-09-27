# Candidate foreign identity for STK mobile-ids that never got an Icelandic vid.
#
# Input:  curated/vessel/vessel_ais_key.parquet, curated/vessel/vessel_identity_foreign.parquet,
#         raw/external/marinetraffic/*.xlsx (via reference/vessels/marinetraffic.R),
#         staging/ais/astd (restricted to the unmatched residual's MMSIs)
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
# Cascade, in order (plan 008 §5/§7 Phases 5-6), each stage only trying what
# the previous stage left unmatched:
#   1. marinetraffic - a direct mobileid join, already-matched candidates from
#      one person's manual review (reference/vessels/marinetraffic.R). No
#      registry dependency.
#   2. cs, time-aware, against vessel_identity_foreign - the primary key in
#      practice (plan 008 §5: more complete than mmsi for several flags).
#   3. mmsi, time-aware, for whatever glid itself parses as a 9-digit MMSI.
#   4. astd (Phase 6), for whatever's still unmatched and MMSI-shaped - a
#      single-source broadcast lookup, restricted to exactly the MMSIs this
#      stage needs, never a scan of ASTD's 2.77 billion pings. Lower
#      confidence than 2/3 (no registry corroboration, no time-aware window),
#      flagged needs_review = TRUE unconditionally.
# 2/3 reuse R/vid_match.R's match_time_aware(id_col = "external_id") (plan 008
# Phase 4) rather than a new matcher.

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

rest1a <- unmatched |> anti_join(stage1, by = ".rid")

## Stage 1b: SKB - Icelandic pleasure craft, direct sknr join --------------
## Not foreign at all - found 2026-09-27 while checking the residual's
## highest-ping mobile-ids: `SKB*` glid values (confirmed by the maintainer:
## Icelandic pleasure boats) are `sknr` codes in
## raw/vessels/mmsi_iceland_archieves.parquet, the same archive
## reference/vessels/registry.R reads - which excludes exactly this prefix
## (`filter(!str_starts(sknr, "SKB"))`) when building vessel.parquet. That
## exclusion has no decision record explaining it and looks mechanical, not a
## deliberate policy call: SKB codes are alphanumeric and do not fit the
## integer `vid` scheme vessel.parquet's join is built on, which is a reason
## to keep them out of THAT table, not a reason to leave them unidentifiable
## everywhere. 94 of 157 residual SKB mobile-ids resolve here (192,554 of
## 256,292 SKB pings) - including mid 134242 (`SKB011`, "Matthíasarborg -
## Prammi", 138,151 pings), one of the single largest entries in the whole
## residual. `vessel.parquet` itself is untouched; this only gives these
## mobile-ids an identity the same way the foreign cascade does, via their
## own external_id space (`isl_pleasure_<sknr>`), not the Icelandic `vid`
## registry's.
mmsi_isl <- read_parquet(fd_raw("vessels", "mmsi_iceland_archieves.parquet"))
skb <- mmsi_isl |>
  filter(grepl("^SKB", sknr)) |>
  arrange(sknr, desc(mmsi_t2)) |>
  distinct(sknr, .keep_all = TRUE) |>
  transmute(glid = sknr, .external_id = paste0("isl_pleasure_", sknr),
            .name = nafn, .mmsi = mmsi,
            .basis = "sknr_direct", .note = paste0("mmsi_cat=", mmsi_cat))

stage_skb <- rest1a |> inner_join(skb, by = "glid")
cat("stage 1b (isl pleasure craft, sknr direct):", nrow(stage_skb), "\n")

rest1 <- rest1a |> anti_join(stage_skb, by = ".rid")

## Stage 2: cs, time-aware ------------------------------------------------------
probe_cs <- rest1 |> transmute(.rid, val = glid, d1, d2)
hit_cs <- match_time_aware(probe_cs, identity_foreign, "cs", id_col = "external_id")
stage2 <- rest1 |>
  inner_join(hit_cs, by = ".rid") |>
  mutate(.basis = "cs", .note = "time-aware call-sign match")

rest2 <- rest1 |> anti_join(stage2, by = ".rid")

## Stage 3: mmsi, time-aware, only where glid itself is a 9-digit MMSI ----------
## gfw is MMSI-only by construction (external_id = "gfw_<mmsi>" always, plan
## 008 §5.0), so for ANY mmsi a real registry (eu/fro/nor) also claims, gfw's
## own row is not competing evidence, it is the same vessel described a
## second time - but match_time_aware() cannot tell that apart from a genuine
## two-vessel collision, so it correctly refused both. Found 2026-09-27
## reviewing the top fishing-relevant ASTD candidate (mid 114277, BAKUR,
## MMSI 231009000): fro already had this exact MMSI, but gfw's own row for
## the same MMSI blocked the match, pushing it needlessly into the ASTD
## fallback. Measured: 6,306 of 6,322 mmsi values with more than one
## candidate external_id in vessel_identity_foreign.parquet are exactly this
## pattern (gfw plus exactly one real source) - only 16 are genuine
## multi-registry disagreements. Dropping gfw's row wherever a real source
## also claims the mmsi resolves the 6,306 outright and changes nothing about
## the 16 genuine ones.
mmsi_has_real_source <- identity_foreign |>
  filter(!is.na(mmsi), source != "gfw") |>
  distinct(mmsi) |>
  pull(mmsi)
identity_foreign_mmsi <- identity_foreign |>
  filter(!(source == "gfw" & mmsi %in% mmsi_has_real_source))
cat("\nidentity rows available for mmsi matching: ", nrow(identity_foreign),
    "->", nrow(identity_foreign_mmsi), "after dropping gfw's redundant rows\n")

probe_mmsi <- rest2 |>
  transmute(.rid, val = if_else(grepl("^[0-9]{9}$", glid), glid, NA_character_), d1, d2)
hit_mmsi <- match_time_aware(probe_mmsi, identity_foreign_mmsi, "mmsi", id_col = "external_id")
stage3 <- rest2 |>
  inner_join(hit_mmsi, by = ".rid") |>
  mutate(.basis = "mmsi", .note = "time-aware MMSI match")

rest3 <- rest2 |> anti_join(stage3, by = ".rid")

cat("stage 2 (cs):", nrow(stage2), "  stage 3 (mmsi):", nrow(stage3), "\n")

## Stage 4: ASTD, restricted to exactly the MMSIs still unmatched --------------
## Plan 008 Phase 6. Never a global scan of ASTD's 2.77 billion pings - pushed
## down to precisely the MMSIs this stage needs, same discipline as plan 003
## §4.5 always intended. astd_cat/flagcode etc. ride along as reference only,
## never a filter (plan 008 §6: the maintainer found astd_cat unreliable for a
## fishing/non-fishing split; the same caution applies to trusting any single
## ASTD-reported field as ground truth on its own). No time-aware matching
## against a per-mobile-id window here, unlike stages 2/3 - ASTD is used as a
## last-resort identity lookup (closer in confidence to ais_key.R's own
## "older"/hail-mary tier than to a registry match), which is why this is a
## separate, later stage rather than folded into the same time-aware cascade.
astd_mmsi <- rest3 |> filter(grepl("^[0-9]{9}$", glid)) |> distinct(glid) |> pull(glid)
cat("\nstage 4: residual mobile-ids with an MMSI-shaped glid:",
    sum(grepl("^[0-9]{9}$", rest3$glid)), " (", length(astd_mmsi), "distinct MMSIs)\n")

## A fresh DBI connection, not duckdbfs's single cached one - R/write_parquet.R's
## own header explains why: a shared connection accumulates state across a
## session's worth of scripts and has already spilled its temp directory into
## not existing (measured here, not assumed - the first version of this stage
## hit exactly that). QUALIFY does the "latest row per mmsi" filter in one pass
## inside DuckDB, so nothing but one row per MMSI is ever collected to R.
## Alongside the latest snapshot, aggregate this MMSI's WHOLE observed ASTD
## history (total pings, distinct years, how consistently one name dominates)
## in the same query - a single-broadcast MMSI and one with 800K consistent
## pings across 12 years (mid 114277/BAKUR, decision 042) are not the same
## strength of evidence, and until now nothing distinguished them. Feeds a
## tier (below), not a filter - astd_cat stays reference-only per §6.
astd_hit <- data.frame()
if (length(astd_mmsi)) {
  con <- DBI::dbConnect(duckdb::duckdb())
  astd_path <- fd_staging("ais", "astd")
  mmsi_list <- paste0("'", astd_mmsi, "'", collapse = ",")
  astd_hit <- DBI::dbGetQuery(con, sprintf("
    WITH base AS (
      SELECT mmsi, vesselname, imonumber, flagcode, astd_cat, gross_tonnage,
             date_time_utc, year
      FROM read_parquet('%s/**/*.parquet', hive_partitioning = true)
      WHERE mmsi IN (%s)
    ),
    agg AS (
      SELECT mmsi, count(*) total_pings, count(DISTINCT year) distinct_years,
             count(vesselname) named_pings
      FROM base GROUP BY mmsi
    ),
    top_name AS (
      SELECT mmsi, vesselname, count(*) n,
             row_number() OVER (PARTITION BY mmsi ORDER BY count(*) DESC) rn
      FROM base WHERE vesselname IS NOT NULL GROUP BY mmsi, vesselname
    )
    SELECT b.mmsi, b.vesselname, b.imonumber, b.flagcode, b.astd_cat,
           b.gross_tonnage, b.date_time_utc,
           a.total_pings, a.distinct_years, a.named_pings, tn.n AS top_name_n
    FROM base b
    JOIN agg a USING (mmsi)
    LEFT JOIN top_name tn ON tn.mmsi = b.mmsi AND tn.rn = 1
    QUALIFY row_number() OVER (PARTITION BY b.mmsi ORDER BY b.date_time_utc DESC) = 1
  ", astd_path, mmsi_list))
  DBI::dbDisconnect(con, shutdown = TRUE)
  astd_hit$mmsi <- as.character(astd_hit$mmsi)
}
cat("resolved in ASTD:", nrow(astd_hit), "\n")

stage4 <- rest3 |>
  filter(grepl("^[0-9]{9}$", glid)) |>
  inner_join(astd_hit, by = c("glid" = "mmsi")) |>
  mutate(.external_id = if_else(is_valid_imo(as.character(imonumber)),
                                as.character(imonumber), paste0("astd_", glid)),
         .basis = "astd_mmsi",
         # evidence_tier D: a well-corroborated broadcast history, not a
         # one-off - thresholds are a starting point (100+ pings, 2+ years,
         # the dominant name in >=80% of named pings), not tuned beyond that.
         # Named .evidence_tier (not .tier) - .tier already carries the
         # unrelated Icelandic vessel_ais_key tier through this pipeline.
         .evidence_tier = if_else(total_pings >= 100 & distinct_years >= 2 &
                         !is.na(named_pings) & named_pings > 0 &
                         (coalesce(top_name_n, 0) / named_pings) >= 0.8,
                         "D", "E"),
         .note = paste0("astd_cat=", coalesce(astd_cat, "NA"),
                        "; ", total_pings, " pings/", distinct_years, "y",
                        "; last seen ", as.Date(date_time_utc)))

cat("stage 4 (astd):", nrow(stage4), "\n")

rest4 <- rest3 |> anti_join(stage4, by = ".rid")

## Stage 5: astdB, for whatever astd itself has no row for -----------------
## astdB carries no vesselname/imonumber at all (checked directly, not
## assumed) - only dimensions, flag (cc_iso3) and AIS class. That is not a
## reason to skip it: it still extends coverage (990 more MMSIs resolved here
## that astd has nothing for) and gives corroborating context - flag state
## and size - for a candidate that would otherwise be identified by MMSI
## alone. external_id can only ever be source-local here (astdb_<mmsi>) since
## there is no IMO to check against. Same restricted-MMSI-lookup discipline
## as stage 4, same fresh-connection reasoning.
astdb_mmsi <- rest4 |> filter(grepl("^[0-9]{9}$", glid)) |> distinct(glid) |> pull(glid)
cat("\nstage 5: still unmatched with an MMSI-shaped glid:", length(astdb_mmsi), "\n")

astdb_hit <- data.frame()
if (length(astdb_mmsi)) {
  con <- DBI::dbConnect(duckdb::duckdb())
  astdb_path <- fd_staging("ais", "astdB")
  mmsi_list_b <- paste0("'", astdb_mmsi, "'", collapse = ",")
  astdb_hit <- DBI::dbGetQuery(con, sprintf("
    SELECT mmsi, cc_iso3, ais_class, length, breadth, draught, date_time_utc
    FROM read_parquet('%s/**/*.parquet', hive_partitioning = true)
    WHERE mmsi IN (%s)
    QUALIFY row_number() OVER (PARTITION BY mmsi ORDER BY date_time_utc DESC) = 1
  ", astdb_path, mmsi_list_b))
  DBI::dbDisconnect(con, shutdown = TRUE)
  astdb_hit$mmsi <- as.character(astdb_hit$mmsi)
}
cat("resolved in astdB:", nrow(astdb_hit), "\n")

stage5 <- rest4 |>
  filter(grepl("^[0-9]{9}$", glid)) |>
  inner_join(astdb_hit, by = c("glid" = "mmsi")) |>
  mutate(.external_id = paste0("astdb_", glid),
         .basis = "astdb_mmsi",
         .note = paste0("flag=", coalesce(cc_iso3, "NA"),
                        ", ais_class=", coalesce(ais_class, "NA"),
                        ", length=", coalesce(as.character(length), "NA"),
                        "m; last seen ", as.Date(date_time_utc)))

cat("stage 5 (astdB):", nrow(stage5), "\n")

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
                        source = "marinetraffic", evidence_tier = "A"),
    if (nrow(stage_skb))
      stage_skb |> transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                             external_id = .external_id, basis = .basis, note = .note,
                             candidate_name = .name, candidate_cs = NA_character_,
                             candidate_mmsi = .mmsi, source = "isl_pleasure_craft",
                             evidence_tier = "A"),
    stage2 |> left_join(ident_lookup, by = "external_id") |>
      transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                external_id, basis = .basis, note = .note,
                candidate_name = .src_name, candidate_cs = .src_cs, candidate_mmsi = .src_mmsi,
                source = source, evidence_tier = "B"),
    stage3 |> left_join(ident_lookup, by = "external_id") |>
      transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                external_id, basis = .basis, note = .note,
                candidate_name = .src_name, candidate_cs = .src_cs, candidate_mmsi = .src_mmsi,
                source = source, evidence_tier = "B"),
    if (nrow(stage4))
      stage4 |>
        transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                  external_id = .external_id, basis = .basis, note = .note,
                  candidate_name = vesselname, candidate_cs = NA_character_,
                  candidate_mmsi = glid, source = "astd", evidence_tier = .evidence_tier),
    if (nrow(stage5))
      stage5 |>
        transmute(mid, loid, glid, d1, d2, pings, tier, .rid,
                  external_id = .external_id, basis = .basis, note = .note,
                  candidate_name = NA_character_, candidate_cs = NA_character_,
                  candidate_mmsi = glid, source = "astdb", evidence_tier = "E")
  ) |>
  select(-.rid)

cat("\ntotal candidates:", nrow(candidates),
    " distinct mobile-ids:", n_distinct(candidates$mid),
    " pings covered:", sum(candidates$pings), "\n")
print(candidates |> count(basis, name = "rows"))

still_unmatched <- nrow(unmatched) - n_distinct(candidates$mid)
cat("\nstill unmatched after all five stages:", still_unmatched,
    "mobile-ids (no MMSI-shaped glid, or that MMSI never seen in ASTD/astdB)\n")

## needs_review: does an external_id this candidate resolves to also appear in
## curate/checks/vessel_identity_foreign_conflicts.R's own output? A blanket
## "every candidate awaits review" was more caution than the evidence
## supports - the Icelandic cascade's own tier A/B matches are auto-assigned
## on the same evidentiary bar (unique, unambiguous) with no per-row sign-off,
## and there is no principled reason to hold the foreign candidates to a
## stricter standard just because they are foreign. Only a candidate whose
## external_id sits inside a REAL flagged ambiguity - a call sign or MMSI the
## registry itself shows two vessels claiming - gets held for a person to look
## at; the rest are trusted the same way the Icelandic mechanical matches are.
conflicts <- read_parquet(fd_curated("check", "vessel_identity_foreign_conflicts.parquet"))
flagged_ids <- unique(conflicts$external_id[!is.na(conflicts$external_id)])
review_reason <- conflicts |>
  filter(!is.na(external_id)) |>
  distinct(external_id, check) |>
  group_by(external_id) |>
  summarise(review_reason = paste(unique(check), collapse = ", "), .groups = "drop")

candidates <-
  candidates |>
  mutate(needs_review = external_id %in% flagged_ids | basis %in% c("astd_mmsi", "astdb_mmsi")) |>
  left_join(review_reason, by = "external_id") |>
  mutate(review_reason = case_when(
           !is.na(review_reason) ~ review_reason,
           basis == "astd_mmsi" ~ "astd: single broadcast snapshot, no registry corroboration",
           basis == "astdb_mmsi" ~ "astdB: dims/flag only, no name or IMO at all",
           .default = review_reason),
         # tier C: a cs/mmsi match that IS flagged (its external_id sits
         # inside a real registry conflict) - same basis as tier B, weaker
         # standing because the identity itself is contested, not just the
         # broadcast evidence for it.
         evidence_tier = if_else(evidence_tier == "B" & needs_review, "C", evidence_tier))

cat("\nevidence_tier:\n")
print(candidates |> count(evidence_tier))

cat("\nneeds_review:\n")
print(candidates |> count(needs_review))

write_curated(candidates, fd_curated("check", "ais_key_foreign_candidates.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         vessel_identity_foreign = fd_curated("vessel", "vessel_identity_foreign.parquet"),
                         vessel_identity_foreign_conflicts = fd_curated("check", "vessel_identity_foreign_conflicts.parquet")))
