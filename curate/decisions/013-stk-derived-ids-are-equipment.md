# 013 — A vessel's identifier with a digit stuck on it is the vessel's buoy

*2026-09-22. Step 3 of `curate/plans/003-stk-vessel-identity.md`, built and gated.
The finding is the maintainer's; the measurements are against the rebuilt
`curated/vessel/vessel_ais_key.parquet`.*

## The correction that reshaped the step

Step 3 was going to add a rule that strips a trailing digit off `glid` and matches
the remainder against the registry — `TFPO2` → `TFPO`, and assign that vessel's vid.
It was drafted, measured at 13 mobile-ids and 62,856 pings, and was **wrong**.

> TFPO2, TFBY2, TFFY_2, TFMS_2 — pretty sure these are madeup and refer to buoy.
> — maintainer, 2026-09-22

STK carries the auxiliary equipment as well as the ships, and a net buoy is
registered under an id derived from its vessel's. The test that confirms it: of the
78 mobile-ids a suffix-stripping match would have handed a vid, **42 were
transmitting while the vessel's own mobile-id was also transmitting**. The rule would
have put a buoy's track on a ship that was somewhere else.

So the shape is a *classifier*, not a matcher. `entity_class` gains 34 mobile-ids and
118,351 pings as `buoy`, and none of them had a vid to lose. The family is bigger than
the four names above: `TFBC2`, `TFKT2`, `TFBJ2`, `TFAS2`, `TFGH2`, `TFQL2`, `TFQW1`,
`XPQE_1`, `OW2147_2`, `1516_2`, and the Norwegian `LAIJ8`, `LAMY8`, `LALU8`, `LAKF8`,
`LAQS8` — the same convention under a different flag.

The rule is deliberately narrow: one optional separator, exactly one trailing digit,
and the remainder must be an identifier the registry actually holds. Wider stripping
turns `V_2166` into `V_216` and `TFFM_2277` into `TFFM_227`, which is guesswork; those
are left unclassified.

**It had to be narrowed twice.** The first version stripped any trailing digit and
matched against call signs *and* vids, which turned `2800` into `280` — itself a
registered vessel — and classed **2,151 mobile-ids on 96 M pings** as buoys. The fix
is that the base must be distinguishable: either a separator before the digit, or a
base containing a letter. Caught because the gate compares against the previous build
rather than only reading the new one.

## "Afmáður" is the vessel, after it stops being Icelandic

> This is the Icelandic "ð". And it means "not in registry", in the sense of retired.
> It may be part of the last journey of the vessel under Icelandic registry.
> — maintainer, 2026-09-22

18 mobile-ids carry a `glid` beginning `afma`, with the old vid in `loid`. Against the
registry's own `note_date`:

| mid | vessel | note_fate | days after the note | days after its previous mobile-id fell silent |
|---|---|---|---|---|
| 140484 | GNÚPUR | Seldur | **+1** | 0 |
| 151544 | BJARNI SÆMUNDSSON | Seldur | +8 | 0 |
| 131099 | AMANDA | Seldur | +29 | +107 |
| 138882 | JÓN MAGNÚS | Seldur | +234 | +19 |
| 148512 | KAPPI | Afskráður | +895 | +93 |

GNÚPUR's `afmáður` transponder begins the day after the registry records *Seldur*.
That is not a coincidence, and it settles what the label means.

**The vid is still correct.** It is assigned to the keel and stays with the hull from
cradle to grave, whatever flag follows — so a vessel that has left the Icelandic
registry and goes on transmitting is still that vid. What changes is that no landing
or logbook record will corroborate it, because the vessel is no longer Icelandic.
Anything concluded about these from the fishing databases would be concluding from
their absence.

**Five of eighteen were assigned**, 68,721 pings. Ten were held back because the
vessel's own mobile-id overlaps in time, and three mobile-ids have no vid in `loid` at
all. Three of the ten — GNÚPUR, HERJA, BJARNI SÆMUNDSSON — are *same-day* handovers:
the previous transponder's last ping and the `afmáður` one's first fall on the same
date, and `d2` is stored as last-day-plus-one, so a clean handover is indistinguishable
from a genuine overlap at day resolution. That is ~10,700 pings left on the table on
purpose. Closing it needs sub-day windows, which is plan 003 step 6.

## What else was built, and what was withdrawn

**`loid_cs`** — the cascade has a `NA_vid` rule and never had `vid_NA`: when the
*left* field is the identifier and the right one is unrecognised, nothing fires, and
96 mobile-ids on 1.29 M pings sit in that hole. Only the undecorated agreement is
taken — `loid` is a registered vid and `glid` is that same vid's own call sign,
spelled plainly. **16 mobile-ids, 54,326 pings.**

**One-character call-sign prefixes: tried and reverted.** Ten of the 711 ITU
allocations are a single character (`2 B F G I K M N R W`), so `str_sub(x, 1, 2)`
cannot see a French, British or Italian call sign — 936 mobile-ids on 1.2 M pings.
Widening it changed `type` on 1,166 rows, assigned no vid at all, and **unmatched four
vessels**: `type` is pasted from both fields and the steps match it as a literal, so
`NA_cs` became `cs4_cs` and the `NA_cs` step stopped firing.

That is the most useful thing step 3 learned. **The classifier cannot be fixed while
the rules key on its output.** A correctness improvement anywhere in the `type`
vocabulary silently unmatches rows elsewhere, with no error and no warning — which is
an argument for plan 003 step 5 that is stronger than any made in the plan itself.
`entity_class` carries the same signal harmlessly, because nothing keys on it.

## The gate

Step 3 changes assignments, so the test is narrower than step 2's: **an existing
assignment may not change.** Measured against the previous build —

| | |
|---|---|
| rows where a vid changed | **0** |
| rows where a vid was lost | **0** |
| rows where a step changed | **0** |
| rows where an mmsi changed | **0** |
| rows that gained a vid | 21 — `afmadur` 5, `loid_cs` 16 |

Coverage, measured at mid-day grain and joined the way `sources/stk/convert.R` joins:
**vid 62.39 % → 62.43 %, mmsi 59.74 % → 59.77 %.**

## `.rid` is not a unique key

It looks like one — `.rid = 1:n()` at `ais_key.R:301` — but the duals join adds 68
rows *after* it is assigned, so 67 mobile-ids carry a duplicated `.rid`. A
`group_by(.rid) |> slice(1)` in the first draft of the `afmáður` step collapsed
exactly those 68 rows, and every gate column failed at once because the whole table
shifted by one. The step now loops over the handful of `afmáður` rows instead of
joining. Anything that treats `.rid` as a key will lose those 68 rows silently.
