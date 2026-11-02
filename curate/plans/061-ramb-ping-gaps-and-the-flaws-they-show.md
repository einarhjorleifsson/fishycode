# 061 — The ping chapter's cases: flaws in approaches already in use (the ICES data call, Mendo et al., iapesca), on simulated data; no ramb change now

**status:** partly built — asks a-f answered 2026-11-02 as recommended (§Answers); "With ramb" and "Not yet in ramb"
written the same day; the cases still to measure and write. Rewritten 2026-11-02 at the maintainer's request, after the first version's four ramb items were
checked against the code. Supersedes the first version of this file (a `ping-gaps` branch of ramb): no ramb change is
warranted now. The maintainer's answers of the same day stand where they still apply (below). **see:** decision 273
(EM4SSF's methods against ramb), decision 234 (the recode yardstick), plan 060 (the clocks), `docs/flow_pings.qmd`, the
ICES flow in `~/stasi/ICES-VMS-and-Logbook-Data-Call/`, decision 232 (iapesca against ramb), decision 078 (the speed
benchmark), `curate/issues/iapesca.yml`, iapesca 1.3 at `~/R/Pakkar/r-packages_iapesca_gitlab` (`1882892`), TODO 183

Drafted with AI assistance (Claude) on 2026-11-02. No person has checked it. The choice of what to show is the
maintainer's; the checks and the measurements are Claude's, and each is labelled.

## Why no ramb change now

The first version proposed four ping-level functions for ramb. Each was checked against the code before any branch.

- **Exact copies within one feed (was M1).** Not a ramb function. The fishycode union keeps one of each set of rows equal
  in every column (plan 060's copies), and the ICES flow does the same with `duplicated()` (1.2.2). That is a one-line
  `distinct()`. No second consumer was found.
- **A land flag (was M2).** Not a ramb function now. `rb_detect_in_polygons()` already flags pings inside any polygon, so
  a land flag is that call with a coastline. The coastline is a data choice, and it is still open.
- **A regular time grid (was M3).** Not a ramb function. `rb_interpolate_track()` already places positions on a grid.
  Measured: on `dansk`'s EX_10 vessel-day of 2014-07-19 (3,159 pings), a grid of one ping a minute gave 740 steps, none
  missing. The only hand-built grid found is an archived comparison's time snap, to 60 or 900 seconds, for that study's
  input format (`$FISHYDATA/archive/2026-10-mendo-vs-iapesca/compare.R`, line 83). It is not Mendo's interpolation. The
  500 m split is a judgement that depends on the data (the maintainer, 2026-11-02), so it is not a default in any
  function.
- **An isolated-label smoother (was M4).** Out (the maintainer, 2026-11-02). It belongs to the fishing row, and without
  labelled ground truth it cannot be scored.
- **iapesca's ping steps** (decision 232; iapesca 1.3, `1882892`). No gap in ramb. iapesca removes rows where ramb labels
  them (`CleanSpuriousSpeeds()` against `rb_flag_ping_impossible()`), and `Resample_Traj()` (`trajr` in time, on an
  oblique Mercator) does what `rb_interpolate_track()` does, linearly. Neither has course-and-speed interpolation.

**What would reopen a ramb change:** a second consumer that needs one of these (no evidence yet: fishymodel is not in
this checkout, and no record says it needs a grid), or a case in the book showing that `rb_interpolate_track()` goes
wrong across long gaps. That last one is not checked. It is the first thing to test in step 1.

**One candidate, recorded, not built: one fix per vessel-second.** Every flow needs it before a speed can be derived.
iapesca does it in `CalcSpeed()` and fishycode in its own code (`curate/ais_ping_clean.R`, the `tie` step), not in ramb.
It is the only item so far that may pass the "warranted" test: generic, used in production, and done ad hoc in two
places. It waits for C7's comparison and its own plan.

## The cases the chapter shows

Each case has a flaw in an approach already in use, shown by its effect on data rather than as its authors' mistake
(memory: "describe tools by intent"). Each figure is built on **simulated data** (the maintainer, 2026-11-02): tracks
generated from fishycode's lessons learned, with parameters taken from the store's measured counts, and no real vessel.

**C1. Placeholders with latitude copied into longitude.** The ICES range test (1.2.3, `1_eflalo_tacsat_preprocessing.R`
lines 121-141) rejects only latitudes beyond ±90 and longitudes beyond ±180, so it keeps these.
*Measured on the store:* the invalid stage of `staging/ais/ping_whacky` holds 9,582 pings from 2007 to 2026, all with
lon = lat, 783 at (0, 0) and 8,799 near 64-66°.
*Source, not fishycode:* in the raw STK trail (`raw/oracle/stk/trail`, 303.8 M rows) 22,733 rows have `poslon = poslat`
in radians, 18,243 of them in 2012. Fishycode only converts units, and the dump keeps Oracle's values. So this is a
defect of the source. Its cause is not traced (the maintainer, 2026-11-02: "not now"). The simulation shows it as an
export or feed fault, not as a fishycode bug.
*Figure:* a vessel-day with planted placeholders, labelled by `rb_flag_ping_invalid()`, next to the ICES range test's
result (kept).

**C2. The ICES interval rule.** Step 1.2.4 keeps a ping only if at least five minutes have passed since the vessel's
previous ping (`intThres <- 5`, `0_global.R` line 71; the comment says "to prevent pseudo duplicates").
*Measured* (on ramb's example data; scratch script `ices_interval.R`, not in the repo): `dansk` holds 395,558 pings of 14
vessels, a median interval of 10 s, and the rule keeps 275 of them (0.07 %).
*Assumed:* the rule was set for a feed that reports every hour or two, as VMS does. The ICES annex calls its input VMS
data with an average polling interval in minutes, and states no rate. Not confirmed (ask c).
*Why it matters for the chapter:* the band in `flow_pings.qmd` says the ping rate sets how far down a track can go.
This is the same fact, with a rule that drops pings instead of labelling them.
*Figure:* a dense feed, a sparse feed, and what the rule keeps of each.

**C3. Exact copies within one feed.** The ICES exact-duplicate rule (1.2.2, lines 103-118) matches vessel, position and
time. Copies one second apart, or a few metres apart, pass it.
*To measure* (step 1): the copies it keeps on a store month, and the same-position pairs one second apart. The union's
own count is the comparison. Not yet run.
*Figure:* one vessel with a copy one second after its original, kept by the ICES rule and labelled by the union's rule.

**C4. Dense and sparse feeds interleaved.** Already in the chapter's duplicate section (`EX_10`, 19 July 2014). No change.

**C5. Mendo's speed rule drops a spike's neighbour** (decision 273). A single pass drops every ping reached too fast, and a
lone spike's next ping is measured from the spike, so it is dropped with the spike. This is a comparison, not a ramb
function: a scratch reprex of Mendo's rule against `rb_flag_ping_impossible(method = "clean")`, cited in the book (ask e).
*iapesca beside it:* `CleanSpuriousSpeeds()` also removes the pings over 25 kn rather than labelling them. On the 2022
code it was 55-60 times slower than ramb (decision 078). Its method has not changed since 2023 but for an NA fix (decision
232), and it has not been timed on 1.3.
*Figure:* a short simulated track with one spike, and what each rule keeps.

**C6. The regular grid, as a recipe.** Built from functions ramb already has: a per-vessel grid of minute times (`seq()`),
then `rb_interpolate_track(grid, track, by = "vid", time_var = "time", value_vars = c("lon", "lat"))`. The 500 m split is a
user rule on top, not a default. The simulation shows where a gap longer than 500 m is interpolated across, and what the
split changes.
*Figure:* a simulated track with one long gap, on the grid with and without the split.
*iapesca beside it:* `Resample_Traj()` resamples in time with `trajr`, on an oblique Mercator. It is another recipe for the
same grid, not a flaw.

**C7. One fix per vessel-second.** Two fixes of one vessel in the same second, at different places, are handled three ways.
- iapesca's `CalcSpeed()` sorts by time and drops every later fix in the same second, wherever it is, before any position
  test (`R/CalcSpeed.R`, around lines 60-72). Which one survives follows the input order. This rule is the author's change
  after an issue sent from here (`curate/issues/iapesca.yml`: "changed, not as suggested").
- The ICES flow keeps both when their positions differ, since its exact-duplicate rule matches position too (1.2.2). Its
  interval rule then drops the later one (1.2.4). From reading the code, not run.
- fishycode labels every fix after the first `tie`, after the position tests, in a stated order: recorded over
  reconstructed, STK over the other feeds, then provider, longitude and latitude (`curate/ais_ping_clean.R`, lines
  111-135). Between two good positions from one provider, the choice is still by order, not by evidence.
*Measured on the store:* `staging/ais/ping_whacky` holds 104,771 ties, 80,559 of them from the GPS logger.
*To run* (step 1): iapesca 1.3's `CalcSpeed()` on the simulated track, if the package installs; otherwise the rule as
written.
*Figure:* two feeds reporting one second at two places, and what each rule keeps.

## What the chapter's sections will say

- "Invalid: placeholders": add C1, lon = lat first, as the case the range test misses.
- "Duplicate: the second feed": add C3 and C7, copies and same-second fixes within one feed, next to the existing C4
  case.
- "The band: the ping rate": add C2 and C6.
- "Methods compared": C5 next to the five-method table.
- "What if a source is missing": iapesca's fallback when there is no port list, a coastline downloaded through `geodata`.
- "In the ICES data call": C1 to C3, each rule described by its effect.
- "Not yet in ramb": the four items are not ramb gaps now; the grid is a recipe (C6). The list keeps the Hermite and
  downsampling items, which remain true.

Out of this plan: iapesca's `Spatialize_FE()` gives a ping the time since the previous one in input order, unsorted and
uncapped (decision 232). It belongs to the effort chapter.

## Steps

1. **Measure, with no repo change** (scratch only): C3's near-copy count on a store month, and the gap behaviour of
   `rb_interpolate_track()` on a simulated track with a gap longer than 500 m, and iapesca 1.3's `CalcSpeed()` on C7's
   simulated track.
2. **The simulator** (ask a): tracks generated with a fixed seed, parameters from the measured counts above, each parameter
   with its source in a table in the chapter.
3. **Write the sections one at a time**, on request, as the book's working method says (`docs/` only; the book's pre-render
   copies images from `$FISHYDATA`, not into the repo).
4. **Render the chapter alone** (`cd docs && quarto render flow_pings.qmd`) and check it renders without error. No
   figure is read unless asked.
5. **Revisit ramb** only if a trigger above fires, with its own plan.

## Answers (2026-11-02, the maintainer: "Yes, start", taking Claude's recommendations)

a. **The simulator lives inline**, in the chapter's chunks, as the chapter already plants placeholders in a real day. A
   file in `docs/` only if a case grows large.
b. **The Icelandic counts stay in the text**, labelled as measured. The figures are simulated.
c. **The ICES feed is written as a stated assumption**, in the ICES annex's own words. Confirmation can wait for TODO 169's
   outside contacts.
d. **Claude drafts `AGENTS.md`'s docs row**: cases on ramb's example data or on simulated data, with measured Icelandic
   counts allowed in the text. The maintainer approves it before it is written.
e. **C5 goes in the book.**
f. **iapesca's rules are described without naming the package** until after Ancona. The ICES data call and Mendo et al.,
   public and published, are named.

## Bookkeeping

- The index row in `curate/plans/README.md` and TODO 183 are rewritten to match this plan.
- `check_bookkeeping()` before any commit.
