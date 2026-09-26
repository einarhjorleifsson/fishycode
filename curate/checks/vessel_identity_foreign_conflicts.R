# Invariants of the north-Atlantic vessel identity table, the foreign
# counterpart to reference/vessels/identity.R's own overlaps/gaps assertions.
#
# Input:  curated/vessel/vessel_identity_foreign.parquet
# Output: curated/check/vessel_identity_foreign_conflicts.parquet - one row
#         per violation
#
# This check REPORTS. It never resolves anything - per AGENTS.md, a foreign
# vid/external_id cycle is broken by a human, through overrides/, same as the
# Icelandic case in ais_key_registry.R.

library(dplyr)
library(nanoparquet)

d <- read_parquet(fd_curated("vessel", "vessel_identity_foreign.parquet"))

## 1. an MMSI resolving to two external_ids at an overlapping time ----------
## The whole point of a time-aware match is that (mmsi, time) resolves to
## one identity. GFW's rows carry no t1/t2 (a single snapshot) and are
## excluded here - they cannot overlap what they have no window to compare.
mmsi_overlap <-
  d |>
  filter(!is.na(mmsi), !is.na(t1)) |>
  arrange(mmsi, t1) |>
  group_by(mmsi) |>
  mutate(.next_t1 = lead(t1), .next_id = lead(external_id), .next_source = lead(source)) |>
  ungroup() |>
  filter(!is.na(.next_t1), !is.na(t2), t2 >= .next_t1, external_id != .next_id)

## 2. the same IMO under more than one source, disagreeing on flag ----------
## An IMO is the one thing meant to be safe across sources (plan 008 §5.0);
## if two sources disagree on something as basic as flag state for the same
## hull, that is worth a human's attention, not a silent pick.
imo_flag_conflict <-
  d |>
  filter(!is.na(imo), !is.na(flag)) |>
  distinct(imo, source, flag) |>
  group_by(imo) |>
  filter(n_distinct(flag) > 1) |>
  ungroup()

## 3. a call sign resolving to two external_ids at an overlapping time ------
## cs is the primary match key in practice (plan 008 §5 - more complete than
## mmsi for several flags), so it earns the same check mmsi gets.
cs_overlap <-
  d |>
  filter(!is.na(cs), !is.na(t1)) |>
  arrange(cs, t1) |>
  group_by(cs) |>
  mutate(.next_t1 = lead(t1), .next_id = lead(external_id)) |>
  ungroup() |>
  filter(!is.na(.next_t1), !is.na(t2), t2 >= .next_t1, external_id != .next_id)

out <- bind_rows(
  if (nrow(mmsi_overlap))
    mmsi_overlap |>
      transmute(check = "mmsi_overlap", key = mmsi, external_id, source, t1, t2,
                other_id = .next_id, other_source = .next_source),
  if (nrow(imo_flag_conflict))
    imo_flag_conflict |>
      transmute(check = "imo_flag_conflict", key = imo, external_id = NA_character_,
                source, t1 = as.Date(NA), t2 = as.Date(NA),
                other_id = flag, other_source = NA_character_),
  if (nrow(cs_overlap))
    cs_overlap |>
      transmute(check = "cs_overlap", key = cs, external_id, source, t1, t2,
                other_id = .next_id, other_source = NA_character_)
)
if (is.null(out)) out <- tibble::tibble(check = character(), key = character())

print(out |> count(check, name = "rows") |>
        knitr::kable(caption = "vessel_identity_foreign_conflicts"))

write_curated(out, fd_curated("check", "vessel_identity_foreign_conflicts.parquet"),
              inputs = c(vessel_identity_foreign =
                           fd_curated("vessel", "vessel_identity_foreign.parquet")))
