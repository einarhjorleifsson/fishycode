# Landings merged from `agf` and `lods`; `.tid_land` renamed `.lid`

*Decided and implemented 2026-09-26. Executes `curate/plans/
007-landings-merge-agf-lods.md` in full (all 6 steps) — the plan stays as the
design; this record says what actually happened, including two defects found
during the build that the plan did not anticipate.*

## What this supersedes

Refines `curate/decisions/028-join-key-naming-aligned.md`, which established
`.tid_land` as landings' reserved trip-key name (distinct from the logbook's
`.tid`). That reasoning about reservation is unchanged and still holds; only
the specific name changes, to `.lid`, because the pre-collapse per-delivery
grain `.tid_land` was invented to stay distinct from no longer exists in the
curated table at all, now that landings merges two source systems and
collapses down to one row per trip — see "The rename" below.

## What this is

`agf` (aflagrunnur, live since 2007-09-01) and `lods` (its legacy predecessor)
are two systems on the same landings database, not unrelated sources —
`dump/oracle/landings.R:24`, a predecessor-repo script, already said so and
never landed the comparison. This repo's pipeline converted `agf` only; `lods`
had no adapter. This work adds one, and merges the two by precedence: `agf`
wins wherever it has a `(vid, date, hid)` trip, on both presence and value;
`lods` fills in everywhere `agf` has nothing.

## The target graph

`aflagrunnur` (unchanged script, `sources/aflagrunnur/convert.R`) no longer
writes to `curated/landing/` directly — it writes source-shaped output to
`staging/landing/agf/`. A new `lods` target (`sources/lods/convert.R`) does
the same for `lods`, from `raw/landings/kvoti/lods_oslaegt.parquet`. A new
`curate/landing.R` → target `landing` depends on both, does the precedence
merge, and is the only thing that writes `curated/landing/{landings,catch}.parquet`.
`lid_map`, `catch_by_species_trip`, `check_ais_key_landings` and
`check_ais_key_reused_callsign` now depend on `landing` instead of
`aflagrunnur` directly — the last two read `raw/landings/agf/aflagrunnur.parquet`
directly regardless, so their content is unaffected, only their build-order
dependency changed.

`lods_londun` (the separate header file `lods` also has) is deliberately not
read — `lods_oslaegt` already carries its own `skip_nr`/`hofn`/`l_dags` per
row, and the two files' distinct `komunr` counts don't fully agree
(1,189,262 vs 1,257,245), so joining through `lods_londun` would risk
orphaning rows `lods_oslaegt` alone does not. Consequence: `lods`'s practical
coverage starts 1992-09-01 (`lods_oslaegt`'s own range), not 1915-11-21
(`lods_londun`'s) — a 59-row, 52-vessel tail is not currently captured.
Flagged, not fixed.

## The rename: `.tid_land` → `.lid`

Landings' trip key is now `.lid` everywhere, not `.tid_land`. `.lid` was
already the reserved name for a landings delivery/trip identifier
(`docs/grammar.qmd` "Landings" section already used it that way, before
`sources/aflagrunnur/convert.R` ever introduced `.tid_land`); reusing it here
is safe specifically because the pre-collapse per-delivery grain no longer
exists as a competing thing to name in the curated table — `landing_catch`
collapses straight to `(.lid, schema, sid, gid, stid, kfteg)`, catch summed,
dropping only the raw per-delivery record id (species, gear and stock all
vary within a real multi-delivery trip and are kept).

Every reference updated: `sources/aflagrunnur/convert.R`, `sources/lods/convert.R`,
`curate/landing.R`, `curate/link_lid_map.R`, `curate/catch_by_species_trip.R`,
`docs/grammar.qmd`, `docs/data-dict.yaml`, and the `fishyweb` data-dictionary
page (`~/stasi/fishyweb/data-sources/data-dictionary.qmd`).

## Two defects found and fixed, neither anticipated by the plan

**1. A `schema` name collision.** `curate/link_lid_map.R` already used
`schema` for the logbook source system (`afli`/`fs_afladagbok`/`adb`). The new
landings-side `schema` (`agf`/`lods`) collided with it the moment `land` and
`trip` are joined — dplyr silently produces `schema.x`/`schema.y`, and every
downstream `select(..., schema)` failed. Fixed by renaming the landings-side
column to `schema_land` at the point `land` is built in that script. The two
`schema` columns are never the same value space and this is now documented in
`docs/data-dict.yaml`'s and the `fishyweb` page's `schema` glossary entry.

**2. `komunr` (lods's raw record id) is a recycled loading-batch code, not a
stable per-delivery id — a real correctness defect, not a naming
inconvenience.** `sources/lods/convert.R` originally derived `.lid` from
`min(komunr)`, mirroring how `agf`'s is `min(londun_id)`. Measured: common
`komunr` values repeat 140–158 times each across unrelated vessels, dates and
harbours (e.g. `930004` is shared by 41 real trips spanning 1992–1993) — the
value shape (`93`+`0046`, `98`+`02292`) and the `HLEDSLA` ("loading") operator
name seen in `lods_londun`'s own `gerandi` field both point to a batch/session
code, not a delivery id. Using it as `.lid`'s source produced 148,602
distinct values shared by more than one real trip *within `lods` alone*
(1,101,166 of 2,166,312 `lods` trip-rows, ~51%), on top of the 104,192-row
cross-schema collision already expected from the raw-domain overlap between
`londun_id` and `komunr` (70,173 overlapping integer values).

Fixed by minting `lods`'s `.lid` as a deterministic hash of `(vid, date, hid)`
instead (`rlang::hash()`, first 52 bits of the digest, split into ≤16-bit
chunks and combined via double arithmetic to avoid integer overflow — plain
base R, no new package dependency). `komunr` itself is kept, under its own
name, as an informational-only field on `landing_catch` (`NA` for `agf`
rows) — never destroy the original, even though it turned out unusable as a
key. Rebuilt and verified: zero `.lid` collisions remain, cross-schema or
within `lods`, versus 1,205,358 combined before the fix.

## A correction to the plan's own earlier measurements

Finding defect 2 required re-measuring `agf`-vs-`lods` trip overlap against
the real staging tables, which invalidated several numbers the plan had
stated as measured fact from an earlier, `lods_londun`-based comparison (the
adapter actually reads `lods_oslaegt`, a different file, and the two disagree
on trip grouping):

| Claim (wrong, superseded) | Real figure (staging tables, 2026-09-26) |
|---|---|
| 5,933 `agf`-only trips, 84.7% in a "May–June 2022 sync gap" | 225 `agf`-only, evenly spread 2007–2026 (5–28/year) — no incident, ordinary reporting lag |
| 25 `lods`-only trips (mostly zero-catch placeholders) | 1,240,681 `lods`-only — overwhelmingly the intended 1992–2006 history recovery, plus a real ~43,756-row post-2007 residual |

The post-2007 residual is concentrated almost entirely (6,282 of 6,307 within
the strict post-2007-09-01 window) at one harbour code, `hid = 159`, absent
from `reference_port`, `reference_harbour`, and even `agf`'s own raw
harbour-name view (`aflagrunnur_v`) — suggesting a retired or non-standard
code rather than a live `agf` coverage gap. Not diagnosed further.

## Verified against real data, not just a clean build

- `landing_landings`: 2,166,537 rows (925,856 `agf`, 1,240,681 `lods`).
- `landing_catch`: 8,078,568 rows, distinct-`(.lid, schema, sid, gid, stid, kfteg)`
  count matching row count exactly (no accidental duplication from the
  collapse).
- `kfteg`/`komunr` both `NA` for every `agf` row, as designed.
- `lid_map`: 786,731 matched trips across the cascade's 7 active match types.
- `catch_by_species_trip`: cod (`sid = 1`) logbook-vs-landings ratio median
  1.017 (documented baseline ≈1.02) — sane, and the small shift from the
  pre-fix value (1.028) reflects genuinely distinct trips that used to be
  wrongly merged by a collided key, not a regression.
- `check_bookkeeping()` clean throughout.

## Not done — left open, per `curate/plans/007-landings-merge-agf-lods.md` §6

- Whether a `curate/checks/` report should surface every trip where `agf` and
  `lods` disagree (the merge design makes disagreement invisible by
  construction — `agf` wins, so a future `agf`-side defect would be silently
  absorbed the same way a `lods`-side one is now).
- What `hid = 159` actually is.
- Hardening `link_lid_map.R`'s cascade and `catch_by_species_trip.R`'s join to
  key on `(.lid, schema_land)` structurally, rather than relying on the hash's
  currently-zero empirical collision rate — a hash reducing collisions to zero
  is not the same guarantee a composite key would be.
- Whether `check_ais_key_landings`/`check_ais_key_reused_callsign` should
  extend to cover `lods`-derived landings, or stay `agf`-only.
- The 59-row/52-vessel 1915–1992-08-31 tail in `lods_londun` that
  `lods_oslaegt` does not carry.
