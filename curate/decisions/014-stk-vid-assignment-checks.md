# 014 — The vid-assignment check `_targets.R` promised now exists, and it is not empty

*2026-09-22. Step 4 of `curate/plans/003-stk-vessel-identity.md`, built and run.
Every number below is the first run's output.*

## What `_targets.R` used to say

> NOT a registry: a fitted model with residual error … Wrong vid assignment is a
> known error class — see `curate/checks/`.

`curate/checks/` held one script, about whacky positions, which writes nothing and is
not a target. The comment had been true as an intention and false as a statement since
it was written. Two checks now make it true.

Both **report**. Neither writes a vid. Reasoning from landings back onto the vid
assignment closes the AIS → vid → logbook → AIS cycle `AGENTS.md` warns about, so a
reviewed conclusion re-enters through `overrides/` as an input, never as a computed
output. Both are targets depending on `vessel_ais_key`, so they run after any rebuild
of it — a check outside the graph is a check nobody runs.

## `curate/checks/ais_key_registry.R` → `curated/check/ais_key_registry.parquet`

| check | rows |
|---|---|
| `icelandic_vessel_not_in_ais` | **1,244** |
| `two_mids_open` | 137 |
| `outside_vessel_lifetime` | 111 |
| `negative_vid` | 15 |
| `vid_not_in_registry` | 1 |

The first four of these were already asserted inside `ais_key.R` as
`knitr::kable(caption = "Expect none")`. **None of those 21 diagnostics has ever been
seen by anyone**: `source()` does not echo the value of a top-level expression, and
`produces()` runs every script through `source()`. They printed into nothing. The
checks call `print()` explicitly.

`outside_vessel_lifetime` exempts the `afmadur` step by construction — that step exists
to assign a vessel that has left the registry, so a `d1` after `yh2` is its expected
shape rather than a violation (decision 013).

## The completeness target, made measurable

> We still want all icelandic vid (i.e. not the 3700-4999) to be assigned to STK, of
> course the limit is the time period of the STK — the vessel registry contains some
> really old vessels that were no longer in existence when the STK began.
> — maintainer, 2026-09-22

So the population is Icelandic hulls whose registry lifetime reaches into the STK era.
1,873 vessels have `yh2 < 2007` and are correctly absent; they are excluded rather than
counted as a gap. Of the 3,882 that remain, **2,638 are in the key and 1,244 are not**,
stratified because the strata mean different things:

| why it stands out | vessels |
|---|---|
| no `yh2` in the registry, so "alive in the STK era" is an assumption | 959 |
| **has an MMSI — should be trackable** | **92** |
| **15 m or over — should be trackable** | **52** |
| mclass 33 / 62 / 60 / 54 / 55 — may legitimately carry no transponder | 141 |

**144 vessels is the actionable number.** A small open boat with no transponder is not
a defect; a 94 m vessel with an MMSI and no mobile-id is. The largest absentees are
`ÞÓR` (TFIA, 93.9 m, MMSI 251604000, 2011–2021), `ÁSGRÍMUR HALLDÓRSSON` (TFAC SF250,
75.3 m) and `HERJÓLFUR` (TFBK, 71.7 m, 2019–2021).

The 959 with no `yh2` are a registry gap rather than an AIS gap, and they are the
reason this check reports a range rather than a number.

## `curate/checks/ais_key_landings.R` → `curated/check/ais_key_landings.parquet`

The maintainer's own proposal — the fishing databases as an independent witness.

| check | vessels |
|---|---|
| `ais_but_never_landed` | 813 |
| `landed_but_no_ais` | 253 |
| `ais_precedes_landings` | 39 |

`landed_but_no_ais` splits three ways: 156 foreign vids landing into Iceland
(expected), 11 landings-database placeholders with no registry row at all (`9999`,
`9908`, `9928` and friends — not hulls), and **86 Icelandic vessels that land fish and
have no AIS identity**. Headed by vid 3047 HILDUR SH777, 3,770 landings ending
2026-04-14, whose call sign TFBR *is* in STK and is assigned to vid 1473 — a vessel
with zero landings. That is `curate/corrections/ais_key_callsign_reuse.yml`, and this
check is how it was found.

`ais_but_never_landed` is the reverse direction and is not by itself a defect: a vessel
that does not fish will not land. It is a list to read against `mclass`, not a fault
count.

`ais_precedes_landings` is the softest and the most likely to surface another reused
call sign — 39 vids tracked more than three years before their first landing. The
extreme is a vid tracked from `1970-01-01`, which is not a match error at all but
`curate/corrections/stk_trail_time_outliers.yml` showing through: a Unix epoch zero in
the trail sets `d1`, because `d1 = min(time)`. One check finding another correction's
footprint is the argument for having them in the graph.

## What this does not do

Nothing is repaired. `d2` is still the sentinel on 31,791 of 31,859 rows, which is what
`two_mids_open` is counting; the 15 negative vids are still undocumented; and the
`AGENTS.md` claim that this table "carries confidence" is still false. Plan 003 steps
5–9 remain.
