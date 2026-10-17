# What a non-Icelandic vessel was called, and when — the foreign counterpart
# to reference/vessels/identity.R.
# Side: preprocessing (vessels). See plan 014.
#
# Input:  staging/eu/vessel_event.parquet, staging/fro/vessel.parquet,
#         staging/norway/vessel_registry.parquet, staging/gfw/vessel.parquet
# Output: curated/vessel/vessel_identity_foreign.parquet — one row per
#         (source, external_id, period)
#
# Plan 008 §5.0: IMO is the keel identifier here, the same role `vid` plays in
# identity.R — assigned once, follows the hull. Measured against the EU file:
# 119 CFRs changed MMSI at least once, 2,369 changed call sign, 29,290
# changed name — so `external_id` is IMO wherever one exists (safe across
# sources) and the source's own registration id otherwise (safe only within
# that source; never merged across sources without an IMO). Deliberately kept
# as broad as each source supports (plan 008 §1) — this is a registry in its
# own right, not a table trimmed to whatever STK matching needs.
#
# NOT touched here: fishing-vessel-vs-not is decided downstream, by whether a
# row resolves against this table at all — never by a source's own category
# field (plan 008 §6's astd_cat finding: self-reported category is unreliable).

library(dplyr)
library(tidyr)
library(nanoparquet)

## Identity key ------------------------------------------------------------
is_valid_imo <- function(x) {
  ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  digs <- matrix(NA_integer_, length(x), 7)
  digs[ok, ] <- do.call(rbind, lapply(x[ok], function(s) as.integer(strsplit(s, "")[[1]])))
  checksum <- digs[, 1] * 7 + digs[, 2] * 6 + digs[, 3] * 5 +
              digs[, 4] * 4 + digs[, 5] * 3 + digs[, 6] * 2
  ok & (checksum %% 10) == digs[, 7]
}
ext_id <- function(source, native_id, imo) {
  if_else(is_valid_imo(imo), imo, paste0(source, "_", native_id))
}

## EU — the source's own event ledger already gives real per-attribute
## periods (plan 008 §5.0); nothing to infer -------------------------------
eu <- read_parquet(fd_staging("eu", "vessel_event.parquet")) |>
  transmute(
    source = "eu", external_id = ext_id("eu", cfr, imo), t1, t2,
    name, cs, mmsi, imo, flag, status = event,
    registration_number,
    loa, lbp,
    gross_tonnage, other_tonnage,
    engine_power_kw, engine_power_aux_kw,
    # the source's own "Year of construction" is a full date (e.g.
    # 1964-01-01) despite the name - reduced to a bare year to match
    # fro/nor's build_year
    year_of_build = suppressWarnings(as.integer(format(year_of_build, "%Y"))),
    # a numeric hull-material code in this source (EU fleet-register coding),
    # free text ("Stál") in fro - kept as its own type (character) for the
    # shared column, code preserved rather than guessed at
    hull_material = as.character(hull_material),
    segment, vessel_type,
    gear_main, gear_subsidiary_1, gear_subsidiary_2, gear_subsidiary_3,
    gear_subsidiary_4, gear_subsidiary_5
  )

## FRO — a single snapshot per vessel: one open period, t2 unbounded -------
fro <- read_parquet(fd_staging("fro", "vessel.parquet")) |>
  transmute(
    source = "fro", external_id = ext_id("fro", vid, imo),
    t1, t2 = as.Date(NA),
    name, cs, mmsi, imo, status,
    registration_number,
    loa, length,
    breadth, depth,
    gross_tonnage, net_tonnage, gross_register_tons, net_register_tons,
    engine_power_kw, engine_type, engine_maker,
    year_of_build = build_year, shipyard, hull_material,
    vessel_type,
    owner_name = owner, homeport
  )

## FRO reuses call signs across vessels the same way EU does (plan 008 §5.0),
## but a single snapshot per vessel has no event ledger to reveal it - found
## 2026-09-27 while investigating why STK's highest-ping unmatched mobile-ids
## kept turning up FRO call signs (e.g. mid 137182/OW2023, 58,699 pings).
## Leaving every row's t2 unbounded made ALL of them "open," so
## match_time_aware() correctly refused to pick one (plan 003 §1's own design:
## two equally plausible candidates is "don't know," not a coin flip) - but
## the ambiguity was manufactured, not real. 32 of 3,813 call signs are shared
## (65 rows).
##
## First version closed only the immediate predecessor of the CURRENT
## ("Í gildi") holder. Wrong for a 3-deep chain: XPRM's ODDNY (1947-2023,
## Sokkið) and SÆHRÍMNIR (2022-2023, Selt til útlandið) both got closed at
## MIÐENNI's (Í gildi, 2023-12-04) own t1 - but ODDNY and SÆHRÍMNIR then still
## overlapped EACH OTHER for 2022-05-31 to 2023-12-03, which is exactly the
## span an STK mobile-id's real ping (mid 102409, 2023-12-01) fell inside,
## still unresolvable. Fixed properly: order every row in a shared-cs group by
## its own t1 (ascending; a group's `Í gildi` row is usually last, since a
## call sign is reused only after its previous holder is gone) and close each
## row's t2 at the NEXT row's t1, same construction as NOR's year-diffing
## below. A row whose successor's t1 is itself unknown (4 of 32 groups, where
## the current holder's own registration date was never recorded) is left as
## it was - there is nothing to close it against.
fro <-
  fro |>
  group_by(cs) |>
  arrange(t1, .by_group = TRUE) |>
  mutate(.next_t1 = dplyr::lead(t1),
         t2 = if_else(!is.na(cs) & dplyr::n() > 1 & is.na(t2) & !is.na(.next_t1),
                      .next_t1 - 1, t2)) |>
  ungroup() |>
  select(-.next_t1)

## Norway — no IMO column at all (plan 008 §4), no MMSI either (plan 008
## §2/§6): external_id is always source-local, cs is the only join key.
## 22 one-year snapshots collapsed into change periods here - the adapter
## stays literal, this is the one place that reasoning belongs (plan 008
## §7 Phase 2/3). A period ends where cs OR name changes; NA <-> non-NA
## counts as a change too, so a gap in the record does not silently merge
## two different identities either side of it. ------------------------
.differs <- function(a, b) (is.na(a) != is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
nor_raw <- read_parquet(fd_staging("norway", "vessel_registry.parquet"))
nor <- nor_raw |>
  arrange(fartoy_id, year) |>
  group_by(fartoy_id) |>
  mutate(.chg = .differs(cs, lag(cs)) | .differs(name, lag(name)),
         .chg = if_else(row_number() == 1, FALSE, .chg),
         .period = cumsum(.chg)) |>
  group_by(fartoy_id, .period) |>
  summarise(
    t1 = as.Date(paste0(min(year), "-01-01")),
    t2 = as.Date(paste0(max(year), "-12-31")),
    across(c(cs, name, loa, breadth, build_year, engine_power_kw,
             engine_build_year, owner_id, owner, ownership_share, org_form,
             registration_mark, county, municipality), last),
    .groups = "drop"
  ) |>
  transmute(
    source = "nor", external_id = paste0("nor_", fartoy_id),  # no imo column exists (plan 008 §4)
    t1, t2, name, cs,
    registration_number = registration_mark,
    loa, breadth, year_of_build = build_year,
    engine_power_kw, engine_build_year,
    owner_name = owner, owner_id, ownership_share, org_form,
    county, municipality
  )

## GFW — a row per MMSI and active year (v3, plan 021 §6 e); no dates beyond the
## year, no IMO column, no cs column. Every metric kept three ways (plan 008 §5)
## rather than collapsed to one - _registry is "recorded", _inferred is
## "reconstructed" (AGENTS.md's basis distinction), and losing that split was
## the thing worth not doing. Years collapse into periods where every kept
## attribute stays the same, as NOR's do above; a gap of inactive years does not
## end a period. The release's own edges stay open: a period in its first year
## (2012) has no t1 and one in its last (2024) no t2, since the release cannot
## say the vessel began or ended there - v2's rows were open at both ends. ----
gfw_cols <- c("flag",
              "vessel_class_inferred", "vessel_class_registry", "vessel_class_gfw",
              "length_m_inferred", "length_m_registry", "length_m_gfw",
              "engine_power_kw_inferred", "engine_power_kw_registry", "engine_power_kw_gfw",
              "tonnage_gt_inferred", "tonnage_gt_registry", "tonnage_gt_gfw",
              "note")
gfw_raw <- read_parquet(fd_staging("gfw", "vessel.parquet"))
gfw_y <- range(gfw_raw$year)
gfw <- gfw_raw |>
  mutate(flag = coalesce(flag_gfw, flag_registry, flag_ais), note = registries_listed) |>
  select(mmsi, year, all_of(gfw_cols)) |>
  arrange(mmsi, year) |>
  group_by(mmsi) |>
  mutate(across(all_of(gfw_cols), ~ .differs(.x, lag(.x)), .names = ".d_{.col}"),
         .chg = if_any(starts_with(".d_")),
         .chg = if_else(row_number() == 1, FALSE, .chg),
         .period = cumsum(.chg)) |>
  group_by(mmsi, .period) |>
  summarise(y1 = min(year), y2 = max(year), across(all_of(gfw_cols), first), .groups = "drop") |>
  mutate(
    source = "gfw", external_id = paste0("gfw_", mmsi),
    t1 = if_else(y1 == gfw_y[1], as.Date(NA), as.Date(paste0(y1, "-01-01"))),
    t2 = if_else(y2 == gfw_y[2], as.Date(NA), as.Date(paste0(y2, "-12-31")))
  ) |>
  select(source, external_id, t1, t2, mmsi, all_of(gfw_cols))

## Merge ---------------------------------------------------------------------
identity_foreign <- bind_rows(eu, fro, nor, gfw)

cat("rows:", nrow(identity_foreign), "\n")
print(identity_foreign |> count(source, name = "rows"))
cat("distinct external_id:", n_distinct(identity_foreign$external_id), "\n")
cat("external_id resolved to an imo (not source-local):",
    sum(!is.na(identity_foreign$imo) & is_valid_imo(identity_foreign$imo)), "\n")

## Assertions - the same shape as identity.R's own overlaps/gaps checks -----
## An MMSI resolving to two external_ids at once means a (mmsi, time) join
## would duplicate a ping across two identities.
overlaps <-
  identity_foreign |>
  filter(!is.na(mmsi)) |>
  arrange(mmsi, t1) |>
  group_by(mmsi) |>
  mutate(.next_t1 = lead(t1), .next_id = lead(external_id)) |>
  ungroup() |>
  filter(!is.na(.next_t1), !is.na(t2), t2 >= .next_t1, external_id != .next_id)
cat("\nMMSI resolving to two external_ids at an overlapping time (expect few/none):",
    nrow(overlaps), "\n")

write_curated(
  identity_foreign,
  fd_curated("vessel", "vessel_identity_foreign.parquet"),
  inputs = c(
    eu     = fd_staging("eu", "vessel_event.parquet"),
    fro    = fd_staging("fro", "vessel.parquet"),
    norway = fd_staging("norway", "vessel_registry.parquet"),
    gfw    = fd_staging("gfw", "vessel.parquet")
  )
)
