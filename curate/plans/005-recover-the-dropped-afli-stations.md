# 005 — Recovering the dropped afli stations on evidence, not on explanation

**Status:** proposal — nothing built. *2026-09-23.*

**Measured** (all on 2026-09-23, reproducible from `curate/checks/afli_rafr_stofn_loss.R`
and the probe described in §2):

- 23,570 live electronic submissions are absent from `stofn`, over 416 vessels.
- 21,762 of them — **92.3%** — fall in the STK era, 2007-06 onward.
- **410 of those 416 vessels have AIS voyages**, covering 99.8% of the lost rows.
- **98.3%** of lost rows fall inside an AIS voyage for that vessel on that date,
  against **99.6%** for merged rows put through the identical test.
- `reference/vessels/ais_key.R` reads the registry, raw landings, raw STK and
  identity. It does **not** read `curated/logbook`.

**Assumed**, and to be tested in step 1, not before:

- That position-and-time proximity to an actual ping will separate the rows more
  sharply than "on a voyage that day" does. The probe is coarse by design.
- That the ~1.4-point excess of uncorroborated lost rows (roughly 300) is a
  distinct population and not noise.
- That landings give a third, independent signal. Untested.

## 1. Why this plan exists

`curate/corrections/afli_rafr_stofn_stations_dropped.yml` characterises the defect
fully and recommends recovery. On 2026-09-23 the maintainer decided to **hold** the
repair pending the source system's account of why its merge drops these rows, on the
reasoning that a repair built on a guess at an unobservable mechanism is a second
defect wearing a correction's clothes. That reasoning was right.

Later the same day the maintainer stated that no upstream answer is expected soon
**or likely ever**. That does not weaken the original reasoning — it removes the
event the reasoning was waiting for. Held indefinitely, the decision stops being
caution and becomes a permanent, silent hole: 23,570 real hauls absent, seven vessels
missing a quarter or more of their history, one missing 78.4%.

**The reframe.** *Why did the merge drop them?* is unanswerable here and now
unanswerable anywhere. *Are these rows true?* is answerable here, with the cross-source
evidence this project exists to apply. The mechanism was never what the data needed.

## 2. The evidence, and why the control is the whole point

For each live electronic submission, ask whether the vessel was on an AIS voyage
covering the station's date — and ask it of the **merged** rows too, restricted to
AIS-tracked vessels so the comparison measures corroboration rather than coverage:

```
group                                rows   at sea     rate
LOST (absent from stofn)            21,734  21,356    98.3%
KEPT (merged) — control, sampled    60,000  59,743    99.6%
```

Alone, 98.3% means nothing — a loose test passes everything. Beside a control that
scores 99.6% on the same test, it means the lost rows place the vessel at sea at
essentially the rate genuine records do. Fabrications, duplicates and clerical
phantoms do not do that. **Every number this plan produces carries its control, or it
is not reported.**

This is corroboration from a transponder system with no connection to the logbook
merge. It does not explain the defect and does not try to.

## 3. The cycle rule is satisfied, and this is why that was checked

`AGENTS.md`: *"Cycles are broken by a human, outside the DAG. Cross-checks are circular
(AIS → vid assignment → logbook activity → validates the vid assignment)."*

Using AIS to corroborate logbook stations runs that arrow in the dangerous direction
if the vid assignment then consumes the logbook. It does not: `ais_key.R` reads
`vessel.parquet`, `aflagrunnur.parquet`, raw STK and `vessel_identity.parquet`, and
never opens `curated/logbook`. Recovered stations therefore cannot re-enter the key.

**This must be re-checked if `ais_key.R` ever gains a logbook input.** At that point
the corroboration verdict becomes a reviewed input in `overrides/`, not a computed
output, exactly as the rule prescribes.

## 4. What gets built

### Step 1 — the corroboration check

`curate/checks/afli_rafr_stofn_corroboration.R` → `curated/check/afli_rafr_stofn_corroboration.parquet`,
one row per live electronic submission, lost and merged alike, carrying:

| | |
|---|---|
| `route` | `stofn` (merged) or `rafr_stofn` (lost) |
| `ais_voyage` | station date inside an AIS voyage for that vid |
| `ais_near` | a ping within *d* km of the station position within *t* hours |
| `ais_km`, `ais_dt` | the actual distance and time gap to the nearest ping |
| `landed` | the station's trip resolves to a landing record |
| `evidence` | `strong` / `weak` / `none`, from the above |

Thresholds are named constants with the reason beside them, per decision 019. They
are chosen from the **control distribution** — whatever distance and time gap the
merged rows meet, the lost rows are held to the same bar — never picked to make the
recovery look good.

Cost note: `ais_near` joins against `curated/ais/ping` (540 M rows). It is a DuckDB
range join per vessel-day, not a cross join, and this is one of the places
`AGENTS.md` sanctions SQL over dplyr for performance.

### Step 2 — admission

Decided by the maintainer, 2026-09-23: **corroborated rows join `curated/logbook`,
flagged.**

Following the rules already in force — *"a correction adds columns; it never
overwrites"*, precedent `w_lon`/`w_lat`:

- Every station in `curated/logbook` gains `route`. Existing rows are `stofn`.
- Recovered rows carry `route = "rafr_stofn"` plus their `evidence` grade.
- `basis` stays `recorded`: these rows were recorded by the vessel, as much as any
  merged row was. What is uncertain is the bookkeeping's treatment of them, not their
  provenance, and `route` is the column that says so.
- **The strict source-faithful view is permanently one filter away**:
  `filter(route == "stofn")` reproduces today's product exactly.

The implementation is `curate/corrections/afli_rafr_stofn_stations_dropped.R`, paired
with the existing `.yml`. **Not in the adapter** — `sources/afli/convert.R` goes on
reproducing `stofn` faithfully, which is an adapter's job.

Why include rather than exclude, in one line: including wrongly costs 2% of rows
carrying an identifiable, reversible flag; excluding costs 78% of one vessel's
history, invisibly, to everyone who does not know to look.

### Step 3 — the uncorroborated remainder

Roughly 300 rows show an excess of non-corroboration over the control. They are
**not** admitted silently and **not** discarded: they carry `evidence = "none"` and
stay in the check table. If step 1 shows they cluster — one vessel, one year, one
gear — that is a finding in its own right and gets its own record.

### Step 4 — the warning page turns around

`docs/afli-dropped-stations.qmd` currently says *"here are the vessels whose figures
are wrong."* After step 2 it says *"here is what was recovered, and how well each row
is corroborated"*, keeping the per-vessel table so anyone who needs the strict view
knows exactly what changes for their vessel.

## 5. What this does not claim

- **It does not explain the defect.** Nobody here knows why the merge drops these
  rows, and this plan is a way to stop needing to know.
- **It cannot reach the pre-AIS rows.** 1,808 lost rows sit before 2007-06 with no
  transponder to corroborate them. They are the years with the worst *rate* —
  19.1% in 2004 — and they will stay uncorroborated. Admitting them on the strength
  of the post-2007 result is an extrapolation and must be labelled as one.
- **It does not close the upstream question.** The report in the yml's
  `the_report_to_send` stays drafted and sendable. If an answer ever arrives it
  either confirms the recovery or overturns it, and `route` is what makes overturning
  it a one-line filter rather than a rebuild.

## 6. Sequencing

Step 1 is free-standing: it reads and reports, changes no product, and can run now.
Steps 2–4 force a rebuild of `staging/afli`, `curated/logbook` and
`curated/logbook/sensor_gps`, so they ride along with the next logbook rebuild —
which is also when `TODO.md` items 1 and 1b land — rather than triggering one.
