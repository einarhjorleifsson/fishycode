# Decision records — index

Where work goes when it leaves `TODO.md`. That file holds only what is **not done
yet**; once an item is finished it is deleted from there and recorded here, or in
`../corrections/` if it is a data defect. Git history says *when*.

This index exists because the registry is otherwise only browsable by opening
every file, and because a deleted TODO item leaves no trace of having existed.

**When a record turns out to be wrong,** amend it in place — do not delete it and do
not renumber. Keep the superseded reasoning under an explicit heading (`## The earlier
theory was wrong` in 004, `## Superseded — kept for the reasoning` in 000) and date the
reversal in the italic line under the title; git history says when, so no changelog
inside the file. A *new* number is for a new decision that overturns an old one (006,
`## What this supersedes`), not for a record correcting itself. Update the row below,
which is the status surface.

**Invariant:** every `.md` in this directory has a row here. Checkable:

```r
setdiff(list.files("curate/decisions", "^[0-9]+.*[.]md$"),
        stringr::str_match(readLines("curate/decisions/README.md"), "\\((\\d{3}-[^)]+)\\)")[,2])
```

| # | record | what it settles |
|---|---|---|
| 000 | [restructuring](000-restructuring.md) | why this repo supersedes `logbooks` and `fishydata_2024-2026`, and the two committed boundaries |
| 001 | [file migration](001-file-migration.tsv) | where every script from the two predecessors landed |
| 002 | [missing GEBCO raster](002-missing-gebco-raster.md) | the raster was never missing — `h3_index.R` wanted a filename nobody created. **Closed 2026-09-23**: `astd_iseez.R` repointed to the same 2026 raster as `h3_index.R` |
| 003 | [undeclared dump inputs](003-undeclared-dump-inputs.md) | datasets named `year=YYYY` that were not partitioned |
| 004 | [issue 11, +70 rows](004-issue-11-seventy-extra-rows.md) | three harbours shared one polygon — a copy-pasted coordinate, not a join; measured at 21 AIS-era trips. **Closed** |
| 005 | [harbour geometry is a frozen input](005-harbour-geometry-is-a-frozen-input.md) | STK ships `harborid`, so deriving polygons from it and then using them to tag pings is a cycle; the artifact is frozen and the bootstrap kept as provenance. **Closed** |
| 006 | [absorb kaenugardr](006-absorb-kaenugardr.md) | why the port repo is merged in rather than consumed as an artifact, and what that costs. **All 4 steps done; kaenugardr read-only** |
| 007 | [hid maps to pid](007-hid-maps-to-pid.md) | `pid` is the standard harbour key across logbooks, landings and AIS; Icelandic `hid` maps onto it |
| 008 | [three-project rename](008-three-project-rename.md) | `_data`→`fishydata`, `fishydata`→`fishycode`; the hazards, and what `~/.claude.json` did that the plan did not predict. **Closed** |
| 009 | [CLAUDE.md is a loader](009-claude-md-is-a-loader.md) | `AGENTS.md` stays the map; `CLAUDE.md` imports it so reaching a session is guaranteed rather than assumed. Refines 000, does not overturn it. **Verified 2026-09-22: the map arrives** |
| 010 | [time variable naming](010-time-variable-naming.md) | case is the level: `T1`/`T2` is the harbour-to-harbour voyage, `t1`…`t4` the four event times, which stay four because the fishing interval moves with the gear |
| 011 | [H3 in storage is experimental](011-h3-in-storage-is-experimental.md) | a ping's `h3` column may be dropped; res 8 is where GEBCO depth gets quantised, and `002` means that grain cannot currently be revisited |
| 012 | [STK entity class](012-stk-entity-class.md) | a mobile-id now says what kind of thing it is; the hand list moved to `overrides/`; 75.5% of the unassigned pings are declared non-vessel |
| 013 | [derived ids are equipment](013-stk-derived-ids-are-equipment.md) | `TFBC2` is TFBC's buoy, not TFBC; `Afmáður` is the vessel after it leaves the Icelandic registry; and the `type` classifier cannot be corrected while the rules key on it |
| 014 | [vid-assignment checks](014-stk-vid-assignment-checks.md) | the check `_targets.R:123` promised now exists and reports 1,244 Icelandic hulls missing from the key, 144 of them trackable; 21 `kable` diagnostics had been printing into nothing |
| 015 | [identity is separate from the key](015-identity-is-separate-from-the-key.md) | the keel and its names are two tables; the commercial feeds were resolving MMSI with no time at all, misattributing 21 hulls; and `yh2` is stale often enough that the lifetime guard must flag rather than withdraw |
| 016 | [read_curated_sf left the WKB behind](016-read-curated-sf-left-the-wkb-behind.md) | decoding added a `geometry` column instead of replacing the blob, so `ports.fgb` carried two `geom`s and DuckDB refused it; one function, one caller, one file |
| 017 | [the clean undercounted its own drops](017-the-clean-undercounted-its-own-drops.md) | `dropped` counted only pass 2, so 831,621 pass-1 rejections went unreported and the drop rate read 0.43% instead of 0.58%; data correct, tally wrong |
| 018 | [a curated layer is not a dataset](018-a-curated-layer-is-not-a-dataset.md) | `open_dataset()` on a layer directory stacks unrelated tables under the first file's schema — `curated/logbook` returns 33.8 M rows and 4 of 71 columns, silently; `curated/ais` is the only one that errors |
| 019 | [the check layer exists](019-the-check-layer-exists.md) | `curated/check/` is real — three tables, and the contract a check owes its reader: report, never correct; one row per entity; carry your own verdict. Also why no `docs/` page had ever read `curated/` |
| 020 | [reused-callsign candidate review](020-reused-callsign-candidate-review.md) | 3 of 31 reused-callsign candidates fixed (`ais_key_callsign_reuse.yml`); the other 28, with why each was parked — 13 were already correctly keyed under a different mid the callsign search never found, a false-positive class worth checking for next time |
| 021 | [the cascade matches on evidence now](021-cascade-matches-on-evidence.md) | plan 003 step 5's last piece: the `type`-string cascade is replaced by time-aware joins against `vessel_identity`; six mobile-ids/441K pings now land on the vid their own window actually covers, and two large ones (`TFPH`, `TFUT`) surface as AIS/landings disagreements instead of silently guessing |
| 022 | [depth unit is metres](022-depth-unit-is-metres.md) | product-wide `z1`/`z2` = metres; every conversion carries `z1_raw`/`z2_raw` and `z1_basis`/`z2_basis`; GEBCO ratio test excludes pelagic gear. **Implemented and rebuilt 2026-09-23** — `curated/logbook/station.parquet` validated (median ratio 1.01–1.03, 1990–2023) |
| 023 | [adb wired into logbook](023-adb-wired-into-logbook.md) | three-tier merge (afli > fs_afladagbok > adb) closes TODO item 1; adb fills 2026 (20,530 stations) once its longitude sign and `_targets.R`'s incomplete `produces()` declaration are both fixed |
| 024 | [track interpolation moved into ramb](024-interpolate-track-in-ramb.md) | `logbook_sensor_gps.R`'s inline `group_modify()` was O(groups × track_rows) — 420s for 2013 alone; `ramb::rb_interpolate_track()` (compiled + DuckDB-ASOF dispatch, same shape as `whack_fwdbwd()`) gets the same year to 45.8s |
| 025 | [lid_map stops overwriting trip.parquet](025-lid_map-stops-overwriting-trip-parquet.md) | two targets writing the same file caused a perpetual `logbook`/`lid_map` rebuild ping-pong; `lid_map.parquet` already carried `.tid_land`/`match_type` independently, so the write-back was pure (and actively harmful) duplication |
| 026 | [TODO item 13's AIS chain gaps closed](026-item13-ais-chain-rebuilt.md) | `ping_tagged` = `ping_union` (543,152,274 rows, the +70 gone), `ping_clean` covers all 20 years, `curated/ais/*` built (720,281 trips); the `trip.parquet`/`.tid_land` check is retired, not satisfied — see 025 |

## Data defects

Not here — `../corrections/`, one `.yml` declaration per defect, paired with a
`.R` implementation where there is one. Each `.yml` carries `id`, `title`,
`status`, `applies_to`, a detection rule and the repair, so that directory is its
own index.

**There is no table of them here, deliberately.** One stood in this spot until
2026-09-23 and had drifted to 6 of 14 — it listed `adb_vs_fs_afladagbok`,
`afli_coords`, `afli_depth_units`, `fs_veidiferd_year`, `ports_iceland` and
`station_time_whole_day`, and had silently missed the eight added after it.
Nothing checked it, because `check_bookkeeping()` asserts the opposite: that the
corrections directory indexes itself. Two files stating the same fact is how the
record drifts, which is the sentence `AGENTS.md` opens with. Generate the list
instead of maintaining it:

```r
for (f in list.files("curate/corrections", "[.]yml$", full.names = TRUE)) {
  y <- yaml::read_yaml(f)
  cat(sprintf("%-34s %s\n", y$id, y$status))
}
```

`check_bookkeeping()` fails if this heading grows a table again.
