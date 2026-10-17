# The STK vessel match, cross-checked against landings.
# Side: once (vessel key). See plan 014.
#
# Input:  curated/vessel/vessel_ais_key_cascade.parquet (the cascade's own claims, decision 053), vessel.parquet,
#         curated/landing/landings.parquet
# Output: curated/check/ais_key_landings.parquet  - one row per vessel in question
#
# The maintainer's own proposal, 2026-09-22: "One way to check coverage and
# potentially error for Icelandic fishing vessels is to check the landings and
# logbook databases. So those can kind of act as a double check."
#
# It works. On its first run it found that call sign TFBR sends 235,121 pings to
# vid 1473, which has never landed a fish, while vid 3047 - 3,770 landings in
# 2025-26 - has no AIS identity at all. That is declared as
# curate/corrections/ais_key_callsign_reuse.yml.
#
# This check REPORTS. Reasoning from landings back onto the vid assignment closes
# the AIS -> vid -> logbook -> AIS cycle AGENTS.md warns about; a reviewed
# conclusion re-enters through overrides/ as an input, never as a computed output.
#
# Extended to lods, 2026-09-26: reads the merged curated/landing/landings.parquet
# (curate/landing.R - agf where it exists, lods filling the gaps, curate/plans/007
# §2) rather than raw agf alone. lods does not push `no_ais` findings earlier -
# AIS (STK) itself only starts at AIS_T1, so a lods-only landing before 2007 is
# outside the AIS era regardless - but lods keeps running in parallel with agf
# past 2007 too (same plan, §1), so this does add real post-2007 trips agf alone
# would miss. `landings` is now a trip count (distinct .lid), not a raw delivery-row
# count - a finer distinction than aflagrunnur's own rows, not a coarser one.

library(dplyr)
library(nanoparquet)

AIS_T1 <- as.Date("2007-06-01")   # STK begins

key <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet"))
reg <- read_parquet(fd_curated("vessel", "vessel.parquet"))
lnd <-
  read_parquet(fd_curated("landing", "landings.parquet")) |>
  group_by(vid) |>
  reframe(landings = n_distinct(.lid),
          first_landing = as.Date(min(date)),
          last_landing  = as.Date(max(date))) |>
  filter(vid >= 5)

in_ais <- key |> filter(!is.na(vid)) |> distinct(vid)

## 1. landed inside the AIS era, but carries no AIS identity --------------------
# A vessel landing fish is at sea, so it should have a track. Most of the misses
# are foreign (3700-4999) landing into Iceland; those are expected and are marked
# rather than dropped, because the Icelandic ones are the finding.
no_ais <-
  lnd |>
  filter(last_landing >= AIS_T1, !vid %in% in_ais$vid) |>
  left_join(reg |> select(vid, vessel, cs, uid, mmsi, mclass, loa), by = "vid") |>
  transmute(check = "landed_but_no_ais",
            note = case_when(
              vid %in% 3700:4999 ~ "foreign vid - expected, landing into Iceland",
              # 9999, 9908, 9928 and friends carry landings but no registry row at
              # all: they are placeholders in the landings database, not hulls.
              is.na(vessel)      ~ "not a registered vessel - landings placeholder",
              .default = "ICELANDIC vessel with landings and no AIS identity"),
            vid, vessel, cs, uid, mmsi, landings, first_landing, last_landing,
            pings = NA_integer_, mids = NA_integer_)

## 2. carries an AIS identity, but has never landed -----------------------------
# The other direction, and the one that caught TFBR. A vid tracked for years with
# no landing at all is either a vessel that does not fish - which is legitimate,
# and mclass says so - or a match pointed at the wrong hull.
no_lnd <-
  key |>
  filter(!is.na(vid), vid > 0, !vid %in% 3700:4999) |>
  group_by(vid) |>
  summarise(pings = sum(pings), mids = n_distinct(mid), .groups = "drop") |>
  anti_join(lnd, by = "vid") |>
  left_join(reg |> select(vid, vessel, cs, uid, mmsi, mclass, loa), by = "vid") |>
  transmute(check = "ais_but_never_landed",
            note = "tracked in AIS, no landing on record",
            vid, vessel, cs, uid, mmsi,
            landings = 0L, first_landing = as.Date(NA), last_landing = as.Date(NA),
            pings = as.integer(pings), mids = as.integer(mids))

## 3. tracked long before the first landing, or long after the last -------------
# A softer signal than either of the above and the one most likely to surface a
# reused call sign: the AIS period and the fishing period disagree by years.
window <-
  key |>
  # Icelandic only: by the register's `foreign` flag, not `vid < 3700`, which dropped every vid from 5000 up
  # until the key redo of 2026-10-17 (decision 119)
  filter(!is.na(vid), vid > 0, !vid %in% reg$vid[reg$foreign], coalesce(step, "") != "afmadur") |>
  group_by(vid) |>
  summarise(ais_from = as.Date(min(d1)), pings = sum(pings),
            mids = n_distinct(mid), .groups = "drop") |>
  inner_join(lnd, by = "vid") |>
  mutate(years_early = as.numeric(difftime(first_landing, ais_from, units = "days")) / 365.25) |>
  filter(years_early > 3) |>
  left_join(reg |> select(vid, vessel, cs, uid, mmsi), by = "vid") |>
  transmute(check = "ais_precedes_landings",
            note = paste0("tracked from ", ais_from, ", first landing ",
                          first_landing, " - ", round(years_early, 1), " years later"),
            vid, vessel, cs, uid, mmsi, landings, first_landing, last_landing,
            pings = as.integer(pings), mids = as.integer(mids))

## Emit -------------------------------------------------------------------------
out <- bind_rows(no_ais, no_lnd, window)

# print(): source() does not echo top-level values, which is why the 21
# knitr::kable diagnostics in ais_key.R have never once been seen by anyone.
print(out |> count(check, name = "vessels") |>
        knitr::kable(caption = "ais_key_landings"))
print(out |> filter(check == "landed_but_no_ais") |> count(note, name = "vessels") |>
        arrange(-vessels) |> knitr::kable(caption = "landed but no AIS identity"))
print(out |>
        filter(check == "landed_but_no_ais", startsWith(note, "ICELANDIC")) |>
        arrange(desc(landings)) |>
        select(vid, vessel, cs, uid, mmsi, landings, last_landing) |>
        head(15) |>
        knitr::kable(caption = "Icelandic vessels that land fish and have no AIS identity"))

write_curated(out, fd_curated("check", "ais_key_landings.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key_cascade.parquet"),
                         vessel         = fd_curated("vessel", "vessel.parquet"),
                         landing        = fd_curated("landing", "landings.parquet")))
