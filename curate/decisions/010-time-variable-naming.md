# 010 — Time variables: case is the level, and four event times stay four

*2026-09-22. Settles the two questions `curate/plans/002-the-last-mile.md` §3 raised as
blocking. Decided by the maintainer; nothing is renamed yet.*

## The decision

**Case encodes the level.**

| | means | examples |
|---|---|---|
| `T1`, `T2` | **trip / voyage level** — leaving and returning to harbour | AIS voyage start and end; logbook departure and landing |
| `t1` … `t4` | **event level** — one setting, haul or tow within a trip | deployment and fishing times |

**A harbour-to-harbour voyage is therefore `T1`/`T2`, not `t1`/`t2`.**
`curate/ais_trip.R:4` currently writes it lowercase, which is what forces
`curate/link_trip_voyage.R:59` to alias `v.t1 AS T1_ais` so the voyage times can sit
beside the logbook's `lb.T1`. That alias stops being a patch and becomes the name:
where an AIS voyage and a logbook trip meet in one table, the suffix `_ais`
distinguishes the source, and case already distinguishes the level.

**There are four event times, and that is not a defect to normalise away.**

| | Icelandic | |
|---|---|---|
| `t1` | kast hefst, lögn hefst | start of deployment |
| `t2` | veiðarfæri í botni, lögn lýkur | start of fishing |
| `t3` | veiðarfæri af botni, dráttur hefst | end of fishing |
| `t4` | kast lokið, dráttur lýkur | end of deployment |

**Which interval assigns a ping to fishing differs by gear**, and no single pair is
right for all of them. A towed gear fishes between `t2` and `t3`; a static gear's
relationship between its four times and the pings that matter is not the same. This is
accepted as a permanent property of the data, not a temporary mess.

## Why this, rather than collapsing to two

The collapse already happened once and cost information. `fishyweb`'s
`station-for-ais.parquet` carries only `t1`/`t2`, taken from `fishing_start` /
`fishing_end`, and every written post filters `between(time, t1, t2)` as though that
were *the* haul window for every gear. Two things are lost: which of the four times
each end actually is, and the fact that the answer moves with the gear.

Keeping four costs two columns. Collapsing to two costs the ability to ask the
question at all, and it does so silently.

## Consequences

- `curate/ais_trip.R` renames its output `t1`/`t2` to `T1`/`T2`; `link_trip_voyage.R`
  follows, and its `T1_ais`/`T2_ais` aliases become ordinary column names.
- The enrichment tail in plan 002 §2 carries event times as `t1`…`t4`, not a collapsed
  pair. Absent ones are absent, which is honest, rather than filled.
- **The per-gear interval rule belongs in the gear table.** `reference/gear/mapping.R`
  already exists for hand-maintained per-gear criteria and its header already carries
  `TODO: add criterion for maximum duration / maximum distance`. The fishing-interval
  rule is that same kind of criterion and goes beside them — *not* into each analysis.
  Measured while deciding this: that file does **not** yet carry the `s1`/`s2` speed
  windows; only `fishyweb/scripts/00_DATASET_gear.R`'s tribble does. They come across
  with the interval rule.

## Not settled here

**The whole-day fallback is a separate defect.** In
`fishyweb/scripts/12_DATASET_logbooks.R:883`, a station with no recorded
`fishing_start`/`fishing_end` is given `t1` = 00:00:00 and `t2` = 23:59:00 of its date.
`between(time, t1, t2)` then means "during the haul" for some rows and "anywhere that
day" for others, with nothing on the row saying which. That is a `basis` question —
`recorded` against `synthesised`, per the rule in `AGENTS.md` — and it wants its own
entry in `../corrections/`, not a naming rule. It is not fixed by this record and it
affects every published figure that filters on `t1`/`t2`.
