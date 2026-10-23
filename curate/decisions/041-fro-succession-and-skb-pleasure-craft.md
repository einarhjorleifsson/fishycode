# 041 — FRO's succession chains fixed properly; Icelandic pleasure craft get an identity

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7, refining Phase 3/6;
one finding (SKB) is Icelandic, outside plan 008's own scope.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person). `TFUT` (mid 133558)
is not a holder missing from our sources: it is vid 2173, TÓMAS ÞORVALDSSON, on MMSI 251017000, whose `yh2` of 1995
was stale (decisions 052, 117; 144 replaced `yh2` with the register's last year).*

## The FRO fix was too simple — a 3-way chain exposed it

Decision 040 closed each shared call sign's non-current row at the *current*
holder's own `t1`. Wrong for a chain more than two deep: `XPRM`'s `ODDNY`
(1947–2023, `Sokkið`) and `SÆHRÍMNIR` (2022–2023, `Selt til útlandið`) both
got closed at `MIÐENNI`'s (`Í gildi`, 2023-12-04) `t1` — but `ODDNY` and
`SÆHRÍMNIR` then still overlapped **each other** for 2022-05-31 to
2023-12-03, which is exactly the span a real STK ping (mid 102409,
2023-12-01) fell inside — still unresolvable.

Fixed properly in `reference/vessels/identity_foreign.R`: every row in a
shared-`cs` group, ordered by its own `t1`, gets its `t2` closed at the
**next** row's `t1` — the same construction already used for NOR's
year-diffing, just applied to an unordered set instead of consecutive years.
Verified: `XPRM`'s three periods now run cleanly end-to-end with no overlap
(`ODDNY` to 2022-05-30, `SÆHRÍMNIR` to 2023-12-03, `MIÐENNI` open).

**One residual left, and it's a different, already-understood class**: mid
102409's own STK window (2023-12-01 to the 2028 sentinel) straddles the
`SÆHRÍMNIR`→`MIÐENNI` handover itself (Dec 3→4, 2023). No amount of registry
cleanup fixes this — it is the same structural limit decision 021 already
named for the Icelandic `TFPH`/`TFUT` case: a single STK mobile-id carries one
`[d1,d2]` span, so when a physical device changes hands without STK splitting
the period, the split cannot be recovered from identifiers alone. Left as is,
same as that case.

## `XPQU`/`XPST`/`XPOP` — checked, not a bug

Three of the highest-ping residual mobile-ids carry Faroese-block (`XP`) call
signs entirely absent from our `fro` data (zero rows, any status) and absent
from the Icelandic MMSI archive too (checked both, on the maintainer's
suggestion). Real vessels, apparently, with no registry record we hold yet —
a genuine `fro` coverage gap, not a matching defect.

## Icelandic pleasure craft (`SKB`) get an identity — a new stage, not a plan 008 source

Not foreign. The maintainer identified `SKB`-prefixed `glid` values in the
residual as Icelandic pleasure boats, and asked to check the Icelandic MMSI
archive. They resolve there directly: `raw/vessels/mmsi_iceland_archieves.parquet`'s
`sknr` field carries the exact same codes — **94 of 157** residual `SKB`
mobile-ids match (192,554 of 256,292 `SKB` pings), including the single
largest entry anywhere in the residual (mid 134242, `SKB011`, "Matthíasarborg
- Prammi", 138,151 pings).

`reference/vessels/registry.R:35` already reads this same archive and
excludes exactly this prefix (`filter(!str_starts(sknr, "SKB"))`) when
building `vessel.parquet` — with no decision record explaining why. The
maintainer's own read, on seeing this: the exclusion looks mechanical, not a
deliberate policy call — `SKB` codes are alphanumeric and never fit
`vessel.parquet`'s integer `vid` join key, which is reason enough to keep them
out of *that* table, but not a reason to leave them unidentifiable
everywhere else.

**Built**: a new cascade stage in `ais_key_foreign.R` (stage 1b, a direct
`sknr` join, same shape as stage 1's `mobileid` join — both are
already-known, exact-match lookups, not inference), tagged
`source = "isl_pleasure_craft"`, `external_id = isl_pleasure_<sknr>` — its own
space, not the Icelandic `vid` registry's. `vessel.parquet` and its filter are
untouched.

**Still open, and it's the maintainer's call, not this session's**: whether
`registry.R`'s `SKB` exclusion itself should be revisited — e.g. whether
pleasure craft deserve their own `entity_class` (`R/entity_class.R`) rather
than defaulting to `"vessel"` and sitting in the unmatched residual looking
like a missed real vessel. Recorded as TODO item 23.

## Numbers, after this round

| | before this round | after |
|---|---|---|
| total candidates | 7,455 | **7,549** |
| unmatched residual | 5,132 | **5,038** |

## The three highest-ping non-`SKB` residual entries, checked individually

The maintainer asked whether `TFUT`/`THAE`/`TFRA` might just be recent call
signs our own data hasn't caught up with. Checked each, not assumed:

- **`TFUT`** (mid 133558, 253,112 pings, 2019–2026) — **confirmed stale
  source data, not a pipeline defect.** Both `raw/vessels/vessel_v.parquet`
  (the raw Oracle extract) and `raw/vessels/mmsi_iceland_archieves.parquet`
  (Fjarskiptastofa) show only the same two historical holders (`JÚLÍUS`,
  `TÓMAS ÞORVALDSSON`), both ending **1995** — 24 years before this mobile-id
  even starts pinging. Whoever holds `TFUT` today isn't in either source we
  have access to. Same class as TODO item 17's existing "88 unmatched
  Icelandic vids... Fiskistofa/Fjarskiptastofa lookup" ask — a fresher pull is
  needed, not more code.
- **`THAE`** (mid 101078, 185,887 pings, 2007–2016) — **mischaracterized in
  the previous message as Icelandic; it is not.** `TH` is France's ITU prefix
  (`TF` is Iceland's) — checked against `cs_prefix`. Genuinely absent from
  `staging/eu/vessel_event.parquet` (zero rows for any French vessel named
  `THAE`). Consistent with plan 008 §6's own finding: `eu` is the *fishing*
  fleet register only, so a non-fishing French vessel would not be there at
  all regardless of data freshness. In scope for plan 008, not resolvable
  from data currently on hand.
- **`TFRA`** (mid 101892) — **already adjudicated, nothing new to find.** Its
  second period (2021-11-24 onward) already carries `vid = -1511` from the
  `manuals` (duals-sheet) step — a person already reviewed this and
  explicitly rejected `vid 1511` without naming a replacement. This is a
  recorded human decision sitting in `raw/ais/stk/stk_mobile_match-and-duals.ods`,
  not an unexamined residual.
