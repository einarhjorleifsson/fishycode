# What a non-Icelandic vessel was called, and when — the foreign counterpart
# to reference/vessels/identity.R.
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

## GFW — a single snapshot, no dates at all; no IMO column, no cs column.
## Every metric kept three ways (plan 008 §5) rather than collapsed to one -
## _registry is "recorded", _inferred is "reconstructed" (AGENTS.md's basis
## distinction), and losing that split was the thing worth not doing. ------
gfw <- read_parquet(fd_staging("gfw", "vessel.parquet")) |>
  transmute(
    source = "gfw", external_id = paste0("gfw_", mmsi), t1 = as.Date(NA), t2 = as.Date(NA),
    mmsi, flag = coalesce(flag_gfw, flag_registry, flag_ais),
    vessel_class_inferred, vessel_class_registry, vessel_class_gfw,
    length_m_inferred, length_m_registry, length_m_gfw,
    engine_power_kw_inferred, engine_power_kw_registry, engine_power_kw_gfw,
    tonnage_gt_inferred, tonnage_gt_registry, tonnage_gt_gfw,
    note = registries_listed
  )

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
