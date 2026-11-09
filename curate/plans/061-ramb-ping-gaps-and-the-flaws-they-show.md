# 061 — The ping chapter: the best approach to step 0, each rule shown with the fault it catches, on planted faults

**status:** partly built — rewritten a second time on 2026-11-02 at the maintainer's word: the book describes the best
approach, not the EM4SSF meeting; the comparisons with Mendo et al. and iapesca go to `~/stasi/em4ssf/me_code`;
the simulated data come from ramb (plan 062). "With ramb", "Not yet in ramb" and C1 written; the
other cases still to measure and write. **see:** plan 062 (the ramb revision), decision 275, decision 273 (EM4SSF's
methods against ramb), decision 234 (the recode yardstick), plan 060 (the clocks), `docs/flow_pings.qmd`, the ICES flow
in `~/stasi/ICES-VMS-and-Logbook-Data-Call/`, decision 232 (iapesca against ramb), decision 078 (the speed benchmark),
TODO 183, the study `$FISHYDATA/archive/2026-11-02-ping-chapter-cases/` (its README: every measured number here, with
the script that made it)

Drafted with AI assistance (Claude) on 2026-11-02. No person has checked it. The choice of what to show is the
maintainer's; the checks and the measurements are Claude's, and each is labelled.

## What changed on 2026-11-02 (the second rewrite)

- **The chapter is about the best approach** (the maintainer: the book "should not focus on the upcoming em4ssf
  meeting, but the best approach"). Step 0 is shown in order: the clocks, placeholders, copies, impossible positions
  with direction as evidence, then ties decided on evidence. Each rule comes with the fault it catches. Another
  workflow appears only where a choice needs the contrast, in a line or two; the ICES data call is named in those
  contrasts, since the book is written for WGSFD.
- **The systematic comparisons leave the book.** Mendo et al.'s speed rule (was C5) and iapesca's same-second rule (the
  iapesca side of C7) are items 3 and 4 of `me_code`'s `TODO.md` (decision 275).
- **ramb changes after all** (plan 062): copies within a feed and same-second ties are labelled in ramb, ties decided
  on evidence; a lazy speed per stream; direction as evidence in the whack. The first version of this plan's "no ramb
  change now" stood for the four items it checked, and is superseded by the maintainer's request of the same day.
- **The cases are planted faults from ramb** (plan 062 step 2), not a simulator inline in the chapter (was ask a).

## The cases the chapter shows

Each case is shown on planted-fault data from ramb's example sets. Measured Icelandic counts may appear in the text,
labelled as measured.

**C1. Placeholders with latitude copied into longitude.** Written. The ICES range test (1.2.3,
`1_eflalo_tacsat_preprocessing.R` lines 121-141) rejects only latitudes beyond ±90 and longitudes beyond ±180, so it
keeps these; `rb_flag_ping_invalid()` flags them.
*Measured on the store:* the invalid stage of `staging/ais/ping_whacky` holds 9,582 pings from 2007 to 2026, all with
lon = lat, 783 at (0, 0) and 8,799 elsewhere, 98 % of them between 62.3° and 70.1° (the range 0° to 76.4°).
*Source, not fishycode:* in the raw STK trail (`raw/oracle/stk/trail`, 303.8 M rows) 22,733 rows have `poslon = poslat`
in radians, 18,243 of them in 2012. Fishycode only converts units, and the dump keeps Oracle's values. Its cause is not
traced (the maintainer, 2026-11-02: "not now").

**C2. A floor on the time step, not an interval rule.** A contrast for one choice. The ICES data call keeps a ping
only if five minutes have passed since the vessel's previous one (`intThres <- 5`, `0_global.R` line 71, "to prevent
pseudo duplicates"); ramb counts a short step as `min_dt_s` long and drops nothing.
*Measured* (on ramb's example data; `scripts/ices_interval.R` in the study): `dansk` holds 395,558 pings of 14 vessels,
a median interval of 10 s, and the rule keeps 275 of them (0.07 %).
*Assumed:* the rule was set for a feed that reports every hour or two, as VMS does. The ICES annex calls its input VMS
data with an average polling interval in minutes, and states no rate.

**C3. Copies within one feed.** ramb labels them (plan 062 step 4a): exact copies, and near ones a second or a few
metres apart. Contrast: the ICES exact-duplicate rule (1.2.2, lines 103-118) matches vessel, position and time, so a
near copy passes it.
*Written* 2026-11-08 ("One feed, one report twice"), on ramb's planted near and shifted copies, with the reload's
counts measured in plan 062's step 3 study (decision 276) as the Icelandic case, not a store month: production runs
the copy rule without the recorded speed, so the store holds no pairs to count.

**C4. Dense and sparse feeds interleaved.** Already in the chapter's duplicate section (`EX_10`, 19 July 2014). No
change.

**C5. Impossible positions, with direction as evidence.** The whack as plan 062 step 4c leaves it: the speed, the turn
at the ping and the detour, the agreement with a recorded speed and course, and where a turn means nothing (legs within
the noise, intervals too long). Shown on the planted spike, run, out-and-back under 25 kn and interleaved copy, with
fishing turns as the ping that must stay. Was Mendo et al.'s speed rule, now `me_code`'s item 3.
*Written* 2026-11-08 ("Judged against the vessel's own speed"), on ramb as built: direction was not built (plan 062
step 4c), so the case is `"local"` with the recorded speed, the vessels' own limits and the vote against `"clean"` and
`"forward"` on `dansk_planted`'s faults at four rates, with the Icelandic night runs (decisions 287, 297) as the
measured counterpoint: over long silences the angle of `"clean"`'s first stage still earns its place.

**C6. The regular grid, as a recipe.** Built from functions ramb already has: a per-vessel grid of minute times
(`seq()`), then `rb_interpolate_track(grid, track, by = "vid", time_var = "time", value_vars = c("lon", "lat"))`. The
500 m split is a user rule on top, not a default (the maintainer, 2026-11-02). Shown on a track with one long gap, with
and without the split. iapesca's `Resample_Traj()` (`trajr` in time, on an oblique Mercator) is another recipe for the
same grid.

**C7. One ping per vessel and second.** ramb keeps the position that fits the track (plan 062 step 4a). Contrasts, in
a line each: iapesca's `CalcSpeed()` drops every later fix in the same second, wherever it is, in input order; the ICES
flow keeps both when their positions differ (1.2.2) and its interval rule then drops the later (1.2.4, from reading the
code).
*Measured on the store:* `staging/ais/ping_whacky` holds 104,771 ties, 80,559 of them from the GPS logger.

**C8. A written time that is off.** Added 2026-11-08 at the maintainer's word ("The time flag"), since ramb now has
`rb_flag_ping_time()` (plan 065 step 4), between the copies and the impossible positions. *Written* the same day
("Time: a written time that is off"), on `dansk_truth`'s four clocks of a single stream. Found there: on these slow
tracks no speed rule blames a late ping's neighbour, so the flag's gain is the times it labels, not positions saved;
a ping written a minute late on a clock that writes whole minutes is within the grain and is not labelled.

## What the chapter's sections will say

- "Invalid: placeholders": C1, lon = lat first, as the case the range test misses.
- "Duplicate: the second feed": C3 and C7 beside the existing C4.
- "The band: the ping rate": C2 and C6.
- "Impossible": C5.
- "Methods compared": ramb's own scores on the planted faults (plan 062 step 3), the tables in an appendix chapter.
- "What if a source is missing": iapesca's fallback when there is no port list, a coastline downloaded through
  `geodata`.
- "Not yet in ramb": rewritten when plan 062's release lands (copies and ties leave it). Land stays out of ramb by
  choice (`rb_detect_in_polygons()` with a coastline the analyst trusts), the grid stays a recipe, Hermite
  interpolation and downsampling stay wishes.

Out of this plan: iapesca's `Spatialize_FE()` gives a ping the time since the previous one in input order, unsorted and
uncapped (decision 232). It belongs to the effort chapter.

## Steps

1. **Measure, with no repo change** (scratch only): C3's near copies on a store month, and `rb_interpolate_track()`
   across a gap longer than 500 m.
2. **The planted faults**: plan 062 step 2, in ramb.
3. **Write the sections one at a time**, on request, as the book's working method says (`docs/` only; the book's
   pre-render copies images from `$FISHYDATA`, not into the repo). C3, C5 and C7 show ramb as plan 062 leaves it, so
   they wait for its release.
4. **Render the chapter alone** (`cd docs && quarto render flow_pings.qmd`) and check it renders without error. No
   figure is read unless asked.
5. **The scores' appendix** after plan 062 step 3.

## Answers (2026-11-02, the maintainer: "Yes, start", taking Claude's recommendations; two revised the same day)

a. ~~The simulator lives inline, in the chapter's chunks.~~ Revised: the planted faults are ramb's example data (plan
   062 step 2), so the book, ramb's tests and `me_code` share them.
b. **The Icelandic counts stay in the text**, labelled as measured. The figures are planted faults.
c. **The ICES feed is written as a stated assumption**, in the ICES annex's own words. Confirmation can wait for TODO
   169's outside contacts.
d. **`AGENTS.md`'s docs row**, drafted by Claude and approved by the maintainer: cases on ramb's example data or on
   simulated data, with measured Icelandic counts allowed in the text. Still true.
e. ~~C5 goes in the book.~~ Revised: Mendo et al.'s rule goes to `me_code`; C5 is now the whack as plan 062 leaves
   it.

## Bookkeeping

- The index row in `curate/plans/README.md` and TODO 183 are rewritten to match this plan.
- `check_bookkeeping()` before any commit.
