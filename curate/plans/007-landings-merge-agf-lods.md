# 007 — Merging `agf` and `lods` into one landings source

**status:** executed — §8 steps 1–6 all done, verified against real data,
2026-09-26. Step 1: grouping-bug fix. Step 2: target graph restructured
(`sources/lods/convert.R` added; `curate/landing.R` added as the precedence
merge; `aflagrunnur` now writes to `staging/`; `lid_map`/
`catch_by_species_trip`/the two `check_ais_key_*` targets depend on `landing`
instead; steps 4-5's `_targets.R` edges and rebuild verification were folded
in here rather than done separately). Step 3: `.tid_land` → `.lid` renamed
everywhere (§3), `landing_catch` collapsed to
`(.lid, schema, sid, gid, stid, kfteg)` (§5). Step 6: `docs/grammar.qmd`,
`docs/data-dict.yaml` and the `fishyweb` dictionary page all updated to match.
Final, current state after two in-flight corrections (below): `landing_landings`
2,166,537 rows (925,856 `agf` + 1,240,681 `lods`), `landing_catch` 8,078,568
rows with distinct-combo count exactly matching row count, zero `.lid`
collisions anywhere (cross-schema or within `lods`), `lid_map` 786,731 matched
trips, `catch_by_species_trip`'s cod control ratio median 1.017 (documented
expectation ~1.02). §6's questions 1 and 3 remain open (question 2 was resolved; TODO 74).
The decision record for the whole plan is decision 031.

**Two things found and fixed while building steps 2–3, neither previously
anticipated:**

1. `curate/link_lid_map.R` already used `schema` for the logbook source
   system; the new landings-side `schema` (agf/lods) collided with it once
   `land` and `trip` are joined, crashing every downstream
   `select(..., schema)`. Fixed by renaming the landings-side column to
   `schema_land` at the point `land` is built.
2. **A serious one, superseding several numbers this plan stated earlier as
   measured:** `lods`'s raw record id (`komunr`), which `.lid` was originally
   derived from the same way `agf`'s is from `londun_id`, turned out to be a
   recycled loading-batch code, not a stable per-delivery id — e.g. the value
   `930004` is shared by 41 real trips spanning different vessels, dates and
   harbours, and common values repeat 140–158 times across unrelated records.
   `min(komunr)`-derived `.lid` values collided across ~51% of `lods`
   trip-rows (148,602 distinct values, 1,101,166 affected rows), on top of the
   104,192-row cross-schema collision this plan already knew about. Fixed
   (maintainer's direction, 2026-09-26) by minting `lods`'s `.lid` as a
   deterministic hash of `(vid, date, hid)` instead of deriving it from
   `komunr` (`sources/lods/convert.R`) — `komunr` itself is kept, under its
   own name, as an informational-only field (never destroy the original).
   Rebuilt and re-verified: zero collisions remain, cross-schema or within
   `lods`.

   **This same discovery also invalidated the §1 "Measured" section's
   `agf`/`lods` trip-overlap numbers below** (5,933 `agf`-only concentrated in
   a "May–June 2022 gap", 25 `lods`-only) — they were computed by joining
   against `lods_londun`, not `lods_oslaegt` (the file the actual adapter
   reads), and the two files don't agree on trip grouping. Recomputed against
   the real staging tables (2026-09-26): **225 `agf`-only trip-groups**,
   spread evenly 2007–2026 (5–28/year, no pattern — ordinary reporting lag,
   the "2022 gap" does not exist in the real data) and **1,240,681
   `lods`-only trip-groups**, overwhelmingly the intended 1992–2006 history
   recovery, plus a real ~43,756-row post-2007 residual concentrated almost
   entirely (6,282 of 6,307 within the strict post-2007-09-01 window) at a
   single harbour code, `hid = 159` — which does not appear in `reference_port`,
   `reference_harbour`, or even `agf`'s own raw harbour-name lookup
   (`aflagrunnur_v`), suggesting a retired or non-standard code rather than a
   live `agf` coverage gap. Not diagnosed further; see §6.
· **2026-09-26** · **see:** `curate/decisions/
007-hid-maps-to-pid.md`, `028-join-key-naming-aligned.md`; `curate/plans/
006-trip-identity-and-catch-to-ais-pings.md` (names `.tid_land`, this plan renames
it again — §3); `docs/grammar.qmd` ("Landings"); `dump/oracle/landings.R` (the
predecessor repo's own comparison of the two systems, never finished);
`sources/aflagrunnur/convert.R`

**Measured** — 2026-09-26. First against the raw parquet, before any code
existed; superseded where noted by later measurements against the actual
built `staging/`/`curated/` output, which are authoritative:

- `agf/aflagrunnur.parquet`: 2007-09-01 → 2026-04-14, 5,261,093 rows. Species,
  buyer, condition, storage method and stock code are already columns on every
  row (`fisktegund`, `kaupandi`/`seljandi`/`vidtakandi`, `astand`,
  `geymsluadferd`, `veidistofn`).
- `kvoti/lods_londun.parquet` (header, unused — see `sources/lods/convert.R`'s
  own header comment) + `kvoti/lods_oslaegt.parquet` (species detail, the file
  actually read): the latter is 1992-09-01 → 2026-04-15; `lods_londun` alone
  goes back to 1915-11-21, but only 59 rows / 52 vessels of that fall before
  1992-09-01 — not a large loss, but the plan's original framing ("recovers
  1915-") overstated it. No buyer, condition, storage method or stock-code
  columns exist in either file.
- **Corrected 2026-09-26, against the real staging tables** (superseding an
  earlier `lods_londun`-based measurement that does not reflect what the code
  actually builds): `agf` 925,856 trip-groups, `lods` 2,166,312 trip-groups
  (all-time), 925,631 in both, **225 `agf`-only**, **1,240,681 `lods`-only**.
  `agf`-only is evenly spread 2007–2026 (5–28/year) — ordinary reporting lag,
  no incident. `lods`-only is overwhelmingly the intended 1992–2006 recovery,
  plus ~43,756 post-2007 trip-groups, 6,282 of which sit at a single harbour
  code (`hid = 159`) absent from every harbour reference table checked
  (`reference_port`, `reference_harbour`, `agf`'s own `aflagrunnur_v` label
  view) — not diagnosed further, see §6.
- **The pre-1990 tail (37 rows, back to 1915, in `lods_londun` only) is real,
  not stub data** — every one of the 37 has a matching, non-trivial
  `lods_oslaegt` catch record under the same `komunr` (e.g. 108,615 kg across
  39 species entries for a 1923-02-26 landing) — though see the `komunr`
  finding below for why that match is not itself trustworthy as identity, only
  as evidence the underlying weight figure is real.
- **The two systems' raw id domains overlap.** `agf`'s `londun_id`:
  6,439–981,357. `lods`'s `komunr`: −981,294–9,900,000 (measured against
  `lods_londun`'s `komunr`, not `lods_oslaegt`'s — see below, the two may
  differ slightly, not re-measured). 70,173 integer values exist in both
  domains.
- **`komunr` itself is not a stable per-delivery id — a real defect, not a
  naming inconvenience.** Common values repeat 140–158 times each across
  unrelated vessels/dates/harbours in the raw data (e.g. `930004` spans 41
  distinct real trips, 1992–1993). Using it as `.lid`'s source (mirroring
  `agf`'s `min(londun_id)`) produced real, not merely theoretical, collisions:
  148,602 distinct values shared by more than one trip *within `lods` alone*,
  affecting 1,101,166 of 2,166,312 `lods` trip-rows (~51%) — on top of the
  104,192-row cross-schema collision already expected from the raw-domain
  overlap above. Fixed: see status header and §5.
- `kfteg`/`fteg` in `lods_oslaegt` are the only species-adjacent columns `lods`
  carries; nothing in `lods` obviously corresponds to `agf`'s `stid` (stock
  code, `veidistofn`) as a direct value copy — resolved with nuance in §5/§6,
  not assumed from the name.

**Assumed** — that `agf`'s extra columns (buyer, condition, storage, stock) are
genuinely absent from `lods` rather than present under a column name not yet
checked; that the `hid = 159` post-2007 residual is a real (if unexplained)
`agf` gap rather than an artefact of how `lods`'s own harbour code maps
forward; that `komunr`'s repeating values really are a loading-batch code
(inferred from the repetition pattern and the `HLEDSLA`/"loading" operator
name seen in `lods_londun`) rather than something else that happens to look
similar — the fix (hash the natural key instead of trusting `komunr`) does not
depend on this guess being right, only on `komunr` being untrustworthy as an
id, which is measured.

## 1. What `agf` and `lods` actually are

Not two unrelated tables — the predecessor repo's own `dump/oracle/landings.R:24`
already says it: *"For each of the two versions of the landings database (`lods`
and `agf`) the data are consolidated by landing date."* `agf` (`aflagrunnur`) is
the system put in place September 2007; `lods` is the older system, and — per
the trip-level match rate above — was kept populated in parallel with `agf`
after 2007 rather than retired, almost certainly by an automated process
(dump/oracle/landings.R's own unfinished `wt_agf` vs `wt_lods` comparison was
reaching for exactly this question and never landed).

This repo's live pipeline currently converts `agf` only
(`sources/aflagrunnur/convert.R`); `lods` has no adapter and the only trace of
it is the abandoned comparison script in `dump/oracle/`. Keeping `agf`-only, as
decided in this conversation, means **no landings history before 2007-09-01
anywhere in `curated/`** unless `lods` is brought in.

## 2. Why the merge should be precedence-based, not a date cutoff

The two datasets are not partitioned into "before 2007" and "after 2007" in
practice — `lods` keeps going to the present, and neither direction is a clean
subset of the other (§ above, corrected 2026-09-26 against the real staging
tables: 225 `agf`-only trip-groups, 1,240,681 `lods`-only, both spanning past
2007). A hard cutoff (`lods` until 2007-09-01, `agf` after) would silently
drop the 225 `agf`-only trips' `lods` counterparts where they happen to exist
and, more importantly, would drop the real post-2007 `hid = 159` residual
(§1's "Measured", 6,282 rows) that only `lods` has.

The logbook merge already solves the identical shape of problem
(`afli`/`fs_afladagbok`/`adb`, three-tier **precedence**, not a date split) and
should be reused rather than re-derived:

> For each `(vid, date, hid)`, take the `agf` record if one exists; otherwise
> take `lods`.

**`agf` wins on value, not just on presence** (maintainer, 2026-09-26):
where both systems have a matching trip and their summed catch weight
disagrees, the merge takes `agf`'s figures whole, never an average or a
reconciled value between the two. This is a deliberate trust asymmetry, not
just "prefer whichever is present": `agf` is the operational system of
record, and where the two disagree on a trip both claim, the more likely
explanation is a `lods`-side issue rather than `agf` being wrong — though the
specific "May–June 2022 sync gap" case that originally motivated this
reasoning turned out not to exist once the comparison was redone against the
real `lods_oslaegt`-based data (§1's "Measured"); the trust-asymmetry
decision itself stands on its own merits regardless. This resolves to
`lods`-only wherever `agf` has nothing at all for a `(vid, date, hid)` key —
pre-1992-09-01 history, the `hid = 159` residual, and the 225 ordinary-lag
trips — without any special case.

One consequence worth flagging, not resolving: this makes it structurally
impossible for the merge itself to ever catch an `agf`-side defect against
`lods` — if `agf` is ever wrong instead of `lods`, "prefer `agf` on
disagreement" hides it rather than surfacing it. A `curate/checks/` report
comparing the two on the trips where they disagree (§6 item 1) would keep
that visible without changing which value the merge actually keeps.

## 3. `.tid_land` becomes `.lid`, everywhere

Decided in this conversation, superseding plan 006 §1's `.tid` → `.tid_land`
naming (itself already implemented by `curate/decisions/028`, ahead of plan
006's own header claiming "nothing built" — a bookkeeping staleness worth a
separate look, not fixed here). The landings-side synthetic trip key —
`min(.lid)` within `(vid, date, hid)`, i.e. `min(londun_id)` — is renamed
`.tid_land` → `.lid` in both `landing_landings` and `landing_catch`, on the
reasoning that its value is a genuine `.lid` (a real delivery id, chosen as the
group's representative), not a fabricated key needing its own name — see this
conversation's naming discussion for the `.tid`/`.sid` precedent weighed
against it.

This only avoids ambiguity if done together with §5's `landing_catch` collapse
(grouping out the per-delivery grain `.lid` used to carry) — otherwise
`landing_catch` would have two different-grain columns both named `.lid`. The
two changes land in the same commit.

## 4. The composite key is `(.lid, schema)`, not `.lid` alone

Raised in this conversation and confirmed against the data: `agf`'s `.lid`
(from `londun_id`) and `lods`'s `.lid` (from `komunr`) are separate id domains
that overlap by 70,173 values (§ above). Once both sources feed one table,
`.lid` alone cannot be a primary key — two rows from different schemas can
carry the identical value and mean unrelated landings. This mirrors
`logbook_trip`'s `(.tid, schema)` exactly (`.tid` is likewise not unique across
`afli`/`fs_afladagbok`/`adb`) and should be built the same way: every
`landing_*` table carries a `schema` column (`"agf"` / `"lods"`), and any join
or uniqueness check on `.lid` is actually on `(.lid, schema)`.

`lods`'s own record id, `komunr`, should be kept alongside `.lid` under its own
name (not overwritten) if it ever needs tracing back to the raw `lods_londun`
row — the same "keep both, never overwrite" treatment `hid`/`pid` already get
(`curate/decisions/007-hid-maps-to-pid.md`).

**Confirmed as a live risk, not just a theoretical one, once step 2 actually
built the merge (2026-09-26):** 104,192 `.tid_land` values are shared between
`agf`-schema and `lods`-schema rows in the real merged `landing_landings`
table (925,856 `agf` + 1,240,681 `lods` rows). `curate/link_lid_map.R`'s
matching cascade and `curate/catch_by_species_trip.R`'s join both key
uniqueness on `.tid_land` alone today — hardening both to
`(.tid_land, schema_land)` is a real open item (§6), not resolved by step 2's
build, which only fixed the immediate `schema` name collision the crash
surfaced (renamed to `schema_land` in `link_lid_map.R`).

## 5. `landing_catch` collapses `.lid` out, keeping species/gear/stock

Already agreed in this conversation, independent of the `agf`/`lods` merge:
group `landing_catch` by `(.lid, schema, sid, gid, stid, kfteg)` and sum
`catch`, dropping only the per-delivery `.lid` the raw record carried, not
species (`sid`), gear (`gid`) or stock (`stid`) — all three do vary within a
real multi-`.lid` trip (556 groups with >1 `gid`, 11,642 with >1 `stid`,
measured against `agf` alone) and would be lost by a coarser collapse.
`kfteg` sits in the grouping key alongside `stid` rather than as a bare
passthrough column, since the two are not always redundant (the 0.78%
residual above) — collapsing without it would silently merge rows that
`stid` alone treats as identical but the raw source did not.

For `lods`-sourced rows this needs `gid`/`stid` to exist at all — `lods_oslaegt`
has `veidarf` (gear, presumably maps to `gid`) and, per below, a *partial*
stand-in for `stid`.

**Resolved, not open, with a residual: `fteg`/`kfteg` → `sid`/`stid`, checked
2026-09-26.** `fteg` = `sid` directly (111 of 120 distinct `fteg` values fall
inside `agf`'s `sid` vocabulary, same 0–1128 range). `kfteg` = `stid`, but only
reliably for 76.43% of `lods_oslaegt`'s 9,864,998 rows — the share where
`kfteg == fteg`, i.e. the "default stock equals the species code" convention
`agf` also uses. A further 22.62% carry `kfteg == 0` (unspecified — should map
to `stid = NA`, not a guessed value) and 0.17% are `NA` outright. The remaining
**0.78% (77,080 rows) carry a genuine, differing sub-stock code that does not
use `agf`'s numbering** — checked against real cases: `agf`'s cod (`sid = 1`)
sub-stocks are `1010`/`1020`, `lods`'s are `45`/`46` for the same species;
`agf`'s `sid = 2` sub-stocks are `2010`/`2020`, `lods`'s is `48`. Two
incompatible numbering schemes for area/stock subdivisions, concentrated in a
handful of species (`fteg` 41, 30, 61, 14, 43, 11 cover nearly all 77,080
rows). **Action:** map `kfteg` → `stid` directly for the 76.43% default case
and `NA` for the 22.79% unspecified/missing case; the 0.78% residual needs a
hand-built per-species `kfteg`→`stid` crosswalk (not attempted here) or stays
`stid = NA` until one exists.

**`landing_catch` keeps `kfteg` alongside `stid`, for every `lods`-sourced row,
not only the unresolved 0.78%** (maintainer, 2026-09-26) — the translation is
lossy for that residual, so dropping the raw field would make the 77,080
diverging rows unrecoverable and any future crosswalk work impossible to
verify. Same "correction adds a column, never overwrites" treatment as
`z1_raw`/`z2_raw` beside `z1`/`z2`. `kfteg` is `NA` for `schema == "agf"`
rows — `agf`'s own raw field for this concept *is* `veidistofn` (`stid`)
already, no translation step exists to preserve the input of.

## 6. Open questions — need a maintainer answer, not an inference

1. **Is a `curate/checks/` report worth building, surfacing every trip where
   `agf` and `lods` disagree?** Not tied to any specific incident anymore (the
   "May–June 2022 sync gap" that originally motivated this turned out to be a
   measurement artefact, not real — §1's "Measured", corrected 2026-09-26) —
   the general point stands regardless: "`agf` wins on disagreement" (§2)
   means the merge itself can never surface a future `agf`-side defect against
   `lods`, so visibility has to come from somewhere else if it matters.
2. **Resolved, not open — `hid = 159` is a catch-all code, not one mislabeled
   harbour (checked 2026-09-26).** All 38,112 `hid = 159` rows are `lods`-only
   — zero appear in `agf` (confirming it is a code `agf` never uses at all,
   not a coverage gap in `agf`'s own data). Cross-checked two independent
   ways, both against the vessel's own trip end at/near the landing date
   (±2 days): AIS (`curated/ais/trip.parquet`'s `hid2`, matched 2,331 of the
   6,686 rows falling in the AIS era) and logbook (`curated/logbook/
   trip.parquet`'s `pid2`, matched 28,451 of all 38,112 rows, since the
   logbook trail reaches back before AIS does). Both agree: the vessels'
   actual arrival ports are spread across the whole country — 65 distinct
   ports by AIS, ~60 by logbook — with Vestmannaeyjar as a plurality (~39–41%
   of matches) but nowhere near a majority. A single retired/renamed harbour
   would show one destination, not sixty; this is `lods` using `hid = 159` as
   a generic "unspecified/other" value. The merge already handles it
   correctly regardless of cause (`lods` fills in where `agf` has nothing),
   so this closes the question without changing any code.
3. **Harden `link_lid_map.R`'s cascade and `catch_by_species_trip.R`'s join to
   key on `(.lid, schema_land)`, not `.lid` alone** — §4's composite-key
   requirement. The specific defect that made this concrete (`komunr`
   recycling, causing 104,192 cross-schema and 1,101,166 intra-`lods` real
   collisions) is now fixed at the source (§5: `lods`'s `.lid` is a hash of
   `(vid, date, hid)`, zero collisions observed) — but that is an empirical
   property of the hash, not a structural guarantee the way a composite key
   would be. Deliberately still deferred (maintainer, 2026-09-26): the
   immediate crash and its cause are both fixed; hardening the cascade itself
   changes matching correctness code, not just plumbing, and needs its own
   care.

**No longer meaningful, superseded:** the plan previously flagged "~23
month-end zero-catch `lods`-only rows (hid 150-heavy)" as a small, mostly
inert set worth keeping rather than filtering. That characterization came
from the same flawed `lods_londun`-based comparison as the "2022 gap" and "25
`lods`-only trips" claims (§1's "Measured") and doesn't describe the real
1,240,681-row `lods`-only population. The underlying design decision - keep
`catch = 0` rows honestly rather than filter them, unlike the predecessor
repo's own unresolved `wt > 0` filter in `dump/oracle/landings.R:55` ("lots of
zero records, why?") - still stands as general guidance, just not tied to that
specific (wrong) count.

Whether `dump/oracle/landings.R` itself is still runnable is explicitly out of
scope (maintainer, 2026-09-26) — `sources/lods/convert.R` reads from
`raw/landings/kvoti/`, same as every other adapter, regardless of that
script's status.

**Resolved, not open:** weight column is `magn_oslaegt` only (maintainer,
2026-09-26) — no change to `sources/aflagrunnur/convert.R`'s existing
`catch = magn_oslaegt`. Checked while resolving this: `magn_oslaegt` ≥
`magn_slaegt` in 99.97% of `agf` rows (median ratio ≈ 1.19), consistent with
round/ungutted vs. gutted weight, so the two candidate columns are not
interchangeable — worth recording so the choice reads as deliberate, not
overlooked. `lods_oslaegt` carries only an ungutted-equivalent weight anyway
(no gutted column exists there), so `agf`-only vs. both-source parity was never
actually a live concern here.

**Resolved, not open:** `agf` has no pre-built trip/header table analogous to
`lods_londun` (maintainer asked, checked 2026-09-26) — every raw `agf` file
(`aflagrunnur_v`/`_v2`, `medafli_v`, `astand_oslaegt_v`/`astand_slaegt_v`,
`target_assemblage_landing_v`) is at the delivery×species grain or finer, none
at trip grain. `landing_landings`'s `(vid, date, hid)` collapse is the only
place that grain exists for `agf` — not redundant with anything upstream.

## 7. The target graph needs restructuring, not an in-place edit

Checked against `_targets.R` (2026-09-26). Today `aflagrunnur` is a single
`format = "file"` target: `sources/aflagrunnur/convert.R` reads raw `agf` and
writes `fd_curated("landing", "landings.parquet"/"catch.parquet")` directly —
there is no merge step, because there was only ever one source. Adding `lods`
means this can no longer be one target; it needs the same three-tier shape
`logbook` already uses for `afli`/`fs_afladagbok`/`adb` (`curate/logbook.R`,
staging → curated, precedence decided in one place):

- `aflagrunnur` stays a source-only adapter, but writes to
  `fd_staging("landing", "agf")` instead of `curated/` directly.
- New `lods` target, `sources/lods/convert.R`, writes to
  `fd_staging("landing", "lods")` — same shape, `schema = "lods"`.
- New `curate/landing.R` → target `landing`, depending on
  `{aflagrunnur; lods}`, does the §2 precedence merge and is the only thing
  that produces `fd_curated("landing", "landings.parquet"/"catch.parquet")`.

**Direct dependents of today's `aflagrunnur` target** (`_targets.R:279-317`),
and what each actually needs:

| target | reads | needs |
|---|---|---|
| `lid_map` | curated `landing_landings`/`landing_catch` by name (`.tid_land`, `curate/link_lid_map.R:55-58`) | code change (`.lid` rename, `schema` awareness) + rebuild; dependency edge moves from `aflagrunnur` to `landing` |
| `catch_by_species_trip` | same, `curate/catch_by_species_trip.R:46` | same as above |
| `check_ais_key_landings` | **raw** `raw/landings/agf/aflagrunnur.parquet` directly, bypassing curated entirely (`curate/checks/ais_key_landings.R:28`) | no code change for the rename; dependency edge still moves to `landing` for correct build ordering, but output is unaffected. **Separate open question, not resolved here:** this check only ever sees `agf` — once `lods` covers a third of landings history, a landings-vs-AIS check blind to it may need extending, or may be fine as-is since AIS coverage itself only goes back to 2007 (STK era) anyway |
| `check_ais_key_reused_callsign` | same as `check_ais_key_landings` | same |

**Full rebuild order:** `aflagrunnur` (restructured) → `lods` (new) →
`landing` (new merge target) → `lid_map` → `catch_by_species_trip` →
`check_ais_key_landings` / `check_ais_key_reused_callsign` (edge updated,
content unaffected).

## 8. What this plan proposes doing now

Nothing yet — this is the design. In order:

1. Fix `sources/aflagrunnur/convert.R:14`'s grouping bug (the second `group_by`
   wrongly includes `.lid`, so `.tid_land` is currently a no-op — measured
   separately in this conversation, ~17,000 landing trips are over-split as a
   result). Do this before the restructuring below, since it's small and
   isolated and needed regardless of `lods`.
2. Restructure the target graph per §7: `aflagrunnur` → `staging/`, new `lods`
   target, new `curate/landing.R` → `landing` target doing the §2 precedence
   merge.
3. In that merge, rename `.tid_land` → `.lid` (§3) and collapse `landing_catch`
   to `(.lid, schema, sid, gid, stid, kfteg)` (§5).
4. Update `_targets.R` dependency edges for `lid_map` and
   `catch_by_species_trip` (`aflagrunnur` → `landing`), and their code for the
   `.lid` rename.
5. `tar_invalidate()` + `tar_make()` the full rebuild order from §7's table;
   confirm via `tar_outdated()` first that nothing outside that list is
   touched (same discipline as decision 028's own rebuild).
6. Update `docs/grammar.qmd`, `docs/data-dict.yaml`, and the `fishyweb` data
   dictionary page for the new `schema` column, the `.lid` rename, and the
   `(.lid, schema)` composite-key rule.

## 9. Not proposed

- Resolving §7's `check_ais_key_landings`/`check_ais_key_reused_callsign`
  scope question (extend to `lods` or leave `agf`-only) — named so it isn't
  lost, not answered here.
- Diagnosing the `hid = 159` post-2007 residual (§6 item 2).
- Any change to the logbook↔landings crosswalk (`logbook_lid_map`,
  `catch_by_species_trip`) beyond the mechanical `.tid_land` → `.lid` rename
  and `schema` awareness — both already join landings by the synthetic key,
  whichever name it carries.
- Auditing plan 006's own staleness (§3's parenthetical) — flagged, not fixed,
  here.
