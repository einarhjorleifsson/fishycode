# 114 — The foreign registers and GFW v3 are built in the graph (plan 021 step 1)

*2026-10-17. Written by Claude (AI-assisted), on the maintainer's go ("start plan 021 step 1"). Plan 021 §6 e (GFW v3)
and plan 008 Phase 7 (the wiring). The maintainer downloaded GFW v3 the same morning.*

## What was done

- **Six targets and four raw inputs** in `_targets.R`, beside `vessel_identity`: `eu`, `fro`,
  `norway_vessel_registry` and `gfw` (each from its raw file, `format = "file"`), then `vessel_identity_foreign` and
  `vessel_identity_all`. The Faroese register is a file per vessel, so its 3,813 files are listed at the top of
  `_targets.R`, as decision 113 does for the feeds. Until now all six were built by hand (2026-09-26).
- **GFW v3.** `sources/gfw/convert.R` reads `raw/external/gfw/fishing-vessels-v3/` as it is: a row per MMSI and
  active year, 773,165 rows on 192,582 MMSIs, 2012-2024 (provenance in `raw/external/gfw/README-provenance.txt`).
  v2 is in `archive/gfw-fishing-vessels-v2/` (§6 e); nothing in fishycode read it after this, and the old
  `fishydata_2024-2026` reads its own copy.
- **GFW periods.** `identity_foreign.R` collapses an MMSI's years into periods where every kept attribute stays the
  same, as it does for Norway's yearly sheets. The release's own edges stay open (no t1 for a period in 2012, no t2
  for one in 2024); v2's rows were open at both ends. 200,899 periods: 4,815 open at both ends, 100,810 closed at
  both.
- **`identity_all.R`** leaves out `vessel_identity`'s 25 periods of an MMSI with no known hull (vid NA,
  `mmsi_broadcast_unregistered.yml`). They identify no vessel, and `paste0("isl_", NA)` made them one id, `isl_NA`.
- **The `# Side:` header** on the four adapters and the two identity scripts (preprocessing), and
  `sources/norway/vessel_registry.R` calls `purrr::map()`: under targets `duckdbfs` attaches `maps`, whose `map()`
  failed with "first argument has length > 1" (AGENTS.md's rule).

## Checked

Each target was built alone (`tar_make(names = )`, one session each), so the AIS chain that decision 113 marks
outdated was not touched. Against copies of the hand-built files (`EXCEPT ALL` both ways):

- staging `eu`, `fro`, `norway` and their rows in `vessel_identity_foreign`: identical (1,079,981, 3,813, 153,755
  and 25,220 rows);
- GFW: 114,191 rows of v2 replaced by 200,899 periods of v3;
- `vessel_identity_all`: the foreign rows as above; the Icelandic ones follow `vessel_identity` as rebuilt on
  2026-10-16 (decision 112): 5,177 `ISL` and 207 `SKB` rows, against 5,169 `ISL` in the copy of 2026-09-26.

The script's count of an MMSI on two external_ids at overlapping times went from 21 to 3,561. GFW's rows had no
dates before, so the check skipped them. 3,541 are an MMSI known to both the EU register and GFW: the same vessel
from two sources, which plan 021's crosswalk joins. 17 are EU with EU and 4 GFW with the Faroese register.

## Left

- `vessel_identity_foreign` and `vessel_identity_all` were written from an uncommitted tree (`fd.dirty` true,
  `fd.commit` 6d5738f). Rebuild both once this is committed: `tar_invalidate()` them first, since targets does not
  see a commit.
- `ais_key_foreign.R` (plan 008, run by hand) now sees GFW periods bounded by the active years. A rerun would no
  longer match a ping after an MMSI's last year in GFW, unless that year is 2024.
- The EU adapter reads `vesselRegistryListResults.csv`, downloaded 2024-02-19; the dated
  `2023-10-09_EU_vesselRegistryListResults.csv` beside it is read by nothing (plan 021 step 1: refresh the EU
  register).
