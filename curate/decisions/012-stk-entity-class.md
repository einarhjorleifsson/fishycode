# 012 — An STK mobile-id now says what it is, and the hand list left the script

*2026-09-22. Step 2 of `curate/plans/003-stk-vessel-identity.md`, built and gated.
Every number below is measured against the rebuilt
`curated/vessel/vessel_ais_key.parquet`.*

## What was done

`vessel_ais_key.parquet` carries two new columns, `entity_class` and `basis`. Nothing
else about it changed: all fourteen pre-existing columns — including `vid`, `step`,
`type` and `mmsi` — are identical to the previous build, row for row, checked column
by column on `.rid` order. The cascade was not touched.

The ~250 literals that were the `fixed`, `kvi`, `hafro`, `net_glid` and
`unknown_glid` vectors inside `reference/vessels/ais_key.R` are now
`overrides/stk_nonvessel_names.csv`, and the script reads them back. Membership is
unchanged, which is why `type` is unchanged.

## What it bought

Of the 289,986,540 pings in the trail, 109,026,889 acquire no `vid`. That number used
to be reported as a coverage gap in full. It splits:

| | pings | share of the unassigned |
|---|---|---|
| declared **non-vessel** | 82,290,460 | 75.5 % |
| a **vessel** that simply did not match | 23,739,797 | 21.8 % |
| genuinely **unknown** | 2,996,632 | 2.7 % |

Across the whole trail, `unknown` is **1.03 %** of pings on 2,098 of 31,791 mobile-ids.

| entity_class | mids | pings | % |
|---|---|---|---|
| vessel | 25,948 | 204,699,448 | 70.59 |
| shore_station | 275 | 55,438,434 | 19.12 |
| net_relay | 296 | 12,020,888 | 4.15 |
| navaid | 1,395 | 6,457,965 | 2.23 |
| aquaculture | 14 | 3,897,977 | 1.34 |
| unknown | 2,098 | 2,996,632 | 1.03 |
| institute | 14 | 2,977,350 | 1.03 |
| buoy | 9 | 1,025,589 | 0.35 |
| beacon | 273 | 312,288 | 0.11 |
| child_vessel | 810 | 103,503 | 0.04 |
| aircraft | 659 | 56,466 | 0.02 |

## Three choices that departed from the plan

**Eleven classes, not eight.** Plan 003 §4.2 proposed `vessel`, `shore_station`,
`aquaculture`, `institute`, `navaid`, `beacon`, `net_relay`, `unknown`. Three were
added because folding them in would have been a lie: `child_vessel` (MMSI 98x, a
tender of a parent vessel — 810 mids), `aircraft` (MMSI 111x SAR aircraft — 659 mids,
and not a "beacon" in any sense), and `buoy` (named `dufl`/`bauja` — 9 mids but 1.0 M
pings, and a drifting buoy is not a shore station).

**Call signs count as vessels.** Not in the plan, and it is the largest single
contribution: an id of 4–7 upper-case alphanumerics whose ITU prefix is allocated is a
vessel saying so, whether or not any registry here holds it. Without it, 19.2 M pings
of foreign call signs read as `unknown`; with it, `unknown` falls from 25.0 M to 3.0 M.

The prefix test tries two characters and then one. Ten of the 711 allocations are a
single character — `2 B F G I K M N R W` — and the cascade's own rule at
`ais_key.R:378` tests only two, so it cannot see a French, British or Italian call sign
at all. That defect (plan 003 §3.4) is *not* fixed here; the new rule sits beside it
and touches only `entity_class`.

The shape test is what keeps shore stations out. STK truncates its station names to
nine characters, so they fall outside the 4–7 window almost without exception: of the
246 reviewed override names, four match the shape, and all four are caught by the
override table first.

**`TF` is not excluded.** `ais_key.R:249` drops the Icelandic prefix from `cs.prefix`
because, in the script's own words, there is "a lot of mess with TF in stk localid and
globalid". That exclusion is about matching a call sign to a *particular vessel*. It
has no bearing on whether the thing is a vessel, so the entity classifier reads the
unfiltered table.

## Precedence, and the one thing that decides it

The rules are ordered by how much the evidence is worth, not by convenience:

1. **the reviewed override list** — a human looked, and that beats everything. It has
   to: the list carries two Icelandic MMSIs (`251999895`, `251990271`) whose number
   range says "vessel" and whose behaviour says otherwise.
2. **the MMSI number range** — an international allocation, so a 99x id *is* a
   navigational aid. `ramb::rb_mmsi_category()`, already used at
   `reference/vessels/mmsi.R:59` and never before pointed at `glid`.
3. **name patterns** — `_net`, `Kvi`, `Hafro`, `dufl`, the ` P`/` B` station suffix.
4. **an allocated call sign** — vessel.
5. a matched `vid`, applied last, which upgrades 2,147 rows to `vessel`.

`basis` records which tier answered: `synthesised` for 1, `recorded` for 2 and 5,
`reconstructed` for 3 and 4, `NA` for `unknown`.

**A matched vid outranks a name pattern but not an override or an MMSI range.** That
ordering is not cosmetic. The first version classed six *matched* vessels as shore
stations because the suffix rule read `[ _-][PB]$` and Norway and the Faroes write a
registration mark as `N-400-B`, `SF-5-B`, `SF-55-B`. Both halves were fixed — the
suffix rule now requires a space or underscore, and a matched vid overrides a pattern
— so the invariant holds twice over. It is asserted in the script: **no row carries a
vid outside `entity_class == "vessel"`**, and none does.

## What this does not do

It assigns no vid and repairs nothing. `curate/corrections/ais_key_callsign_reuse.yml`
and `stk_trail_time_outliers.yml` are still open, `d2` is still the 2028 sentinel on
31,791 of 31,859 rows, and the `AGENTS.md` claim that this table "carries confidence"
is still false — `basis` is the basis of the *class*, not of the vid match. Plan 003
steps 3–9 remain.

The residual 2,098 unknown mids are mostly nulls (`-`, `0A`, `9999`, `unkown`) and
two families that belong to step 3: names truncated past recognition, and ids whose
`loid` holds a vid the cascade never reads because it has no `vid_NA` rule.
