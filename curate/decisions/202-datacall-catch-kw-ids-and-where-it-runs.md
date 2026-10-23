# 202 — The datacall reads the curated catch and kW, keeps a stable vessel key, and runs by hand per delivery; its metier and first-run rules wait for a study

*2026-10-23. The maintainer's answers to plan 015 §4 (the ICES VMS datacall, TODO 27b), asked by Claude (AI) in a status
review of the repository. Nothing is built.*

## Answered

- **e, f. Catch and kW per fix from the curated products.** The datacall reads `curated/ais/catch` (decisions 101, 102,
  with its approach and raise factor) and the trail's kW with `kw_basis` (decision 144), so it is one product, not a
  datacall-only rule. 2025's equal shares are computed beside it for the comparison, and kWFishingHour's coverage is
  reported by `kw_basis`.
- **g. A stable vessel key:** vid → `ISnnnn` kept in `reference/vessels`, allocated append-only like the vid ledger
  (decision 115) and never renumbered, so a hull carries the same anonymised id in every delivery.
- **h. By hand per delivery:** a script run once per call into `$FISHYDATA/exports/ices_vms_datacall/<call year>/`,
  with a manifest (the commit, the inputs and their stamps, row counts). A delivery is a snapshot, not a product the
  flow rebuilds.

## Held

- **a. The metier 6.** 2025's lookup was typed by hand (`~/stasi/fishydata_2024-2026/scripts/00_DATASET_gear.R`, gear code
  → metier), "made upon the fly" (the maintainer), and the logbooks' mesh is "notorious". MFRI's own RDBES uploads assign
  metiers too (`raw/oracle/rdbes/`: the metier list, `allowed_metiers_in_areas`, the commercial effort and landing
  tables). A read-only study compares the three and proposes a rule with a basis, before the choice.
- **b, c, d, i. The first run's rules** (years, the effort interval rule, gear widths, untimed stations): held until the
  metier study, to be thought through together.
