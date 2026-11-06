# 069 — The candidate speed rule in production's place: a rebuild test of the AIS chain, overnight, on a scratch store

**status:** executed — written 2026-11-05 for TODO 192, at the request of the session that ran decisions 282-284;
asks a-f (§7) answered the same evening, each as recommended ("Yes, as recommended"); the night run set up, tried on
2007 and started that night in `$FISHYDATA/archive/2026-11-05-speed-rule-rebuild-test/` (its README: the log, how to
resume, the morning's checks); read 2026-11-06, every check passing and the control equal: fishing hours +0.007 %,
but 21,600 port calls lost, 8,142 new, and the AIS departure or return of about 13,000 trips moved by over 6 h, mostly
lengthening them; hand-checked the same day by the maintainer and against the logbook's own dates, both for production
(the study README); decision 287: production's rule stays, TODO 192 parked until plan 048 ("Yes, park until 048");
nothing in the pipeline changed · **see:** decision 287, TODO 192, decisions 282, 283
and 284, plan 068, plan 065 §7, TODO 184 (plan 062's item 4), TODO 148 (plan 048), `curate/ais_ping_clean.R`,
`$FISHYDATA/archive/2026-11-05-speed-rule-sweep/README.md`

Drafted with AI assistance (Claude) on 2026-11-05; a person has not yet checked it. **Measured** (by Claude, read-only,
the same evening): the chain below `ais_ping_clean` and its order (`tar_network()`: 18 targets, 16 once `ais_catch`
and `check_allocation_audit` are left out); its build times on 2026-11-02 (`tar_meta()`: the clean 20.5 min, the 16
below it 59 min, the trail 35 and the voyages 17 of them); that every input the chain reads from outside it was last
written on 2026-11-02 before the chain ran (07:22-15:27; the chain 15:29-16:50), and that no script of the chain, nor `R/` or `_targets.R`, changed since 5f522e0
but `R/check_session_close.R`, which it does not call (`git diff`); ramb's changes since that build's 2026.11.02.2
(its NEWS and `git diff`: the flaggers, the maps, new functions); the disk (74 GB free; the chain's outputs 67 GB,
`du`); that no pipeline script reads `whack_stage` but `ais_ping_clean.R`'s own closing count (`grep`); and the
sweep's numbers for 2007 and 2018 (its README). **Assumed:** that the chain's scripts run on a scratch store as
`tar_make_isolated()` runs them (§3's runner copies its setup); that its times hold (from 2026-11-02 and the sweep's
2018); that today's ramb gives production's stored labels (the control, §4 step 2, tests it); that the other 18
years of the sweep take about as long as 2007 and 2018 did.

## 1. What the test answers

TODO 192 asks whether production's speed rule moves from ramb's `clean` at 25 kn to the candidate of decisions
282-284. The sweep compares the two rules' flags, ping by ping, against the labels the store holds. It cannot say what
a flag does further down: a port call lost or a voyage merged, a trip linked to another voyage, the hours a fix stands
for in the trail. This test builds the AIS chain from the clean step down with the candidate, beside the live store,
and counts every record of every product in one outcome: the same, changed, only before, only after.

It does not explain the sweep's 2018 finding (the candidate flags 40,682 pings production keeps, 18,144 of them in
fishing windows, about 3,200 h). That needs hand samples (TODO 192's next step). It says what those flags cost in
effort. The sweep's hours are the time each ping stands for. In the trail a fix's `hours` run to the next fix in its
voyage, capped at 2 h (`R/trail_sql.R`), so a fix taken out mostly hands its time to the fix before it. 10,758 of the
18,144 are `stk_ais` pings of vessels under 25 kn (1,903 h, the sweep's 2018 counts by stream).

## 2. The change: `curate/ais_ping_clean.R`

Only the speed step changes. The invalid flag, the duplicate flag (still `kn_max = 25`, which sets its 128.6 m), the
tie step, the batching by whole vessels, the reconciliation and the outputs' contract stay.

| | production | the candidate |
|---|---|---|
| limits | none: one 25 kn for every vessel | `rb_create_ping_limits(x, stream = stream, speed = speed_rec, lag = lag_m, max_step_s = 300)` per year, lazily in DuckDB (4 threads, 5 GB), on every ping with a `vid` that is not invalid, the duplicates and the GPS logger's included, as the sweep took them; `speed_rec` the speed where `speed_basis` is `recorded`, `lag_m` the lag where `lag_basis` is `copy`, `receipt` or `measured` |
| speed step | `rb_flag_ping_impossible(method = "clean", kn_max = 25, min_dt_s = 10, feed = provider, noise_nm = 0.3, evidence = TRUE)` | `rb_flag_ping_impossible(method = "local", feed = provider, noise_nm = 0.3, speed = speed_rec, limits = lim, anchor = "vote", evidence = TRUE)` (`local_speed` its default `"larger_side"`; no `stream =`) |
| pings judged | recorded positions, after the invalid and duplicate flags | the same |
| `METHOD` | `…clean(feed-floor,evidence)…` | a new string, so every year is cleaned again |

What the outputs look like after:

- **`staging/ais/ping_clean`**: the same columns and contract (the unflagged pings). By the sweep, 2007 keeps 10,065
  more pings (11,812 production flags the candidate keeps, 1,747 the other way) and 2018 21,061 fewer (19,621 and
  40,682).
- **`staging/ais/ping_whacky`**: `whack_stage` takes `invalid`, `duplicate`, `local_spike`, `local_forward`,
  `local_anchor` (an anchor the vote found wrong) and `tie`; no `vmask`, `spike` or `forward`. New columns:
  `ping_flag_basis` (`recorded`, `ceiling`, `track` for the speed flags; ramb 2026.11.04's cascade gives the invalid
  and duplicate flags one too) and `ping_flag_speed_kn` (the local speed a ping was judged by). The evidence columns
  stay. The closing count lists the new stages.
- **New, `staging/ais/ping_limits/year=<y>/`**: each vessel and stream's ceiling, clock and the year's noise, with
  their bases and counts, so every `ceiling` flag can be read against its limit (a few MB a year).

Who reads them (`tar_network()`, 16 targets, in build order): `port_call` and `ais_voyage` read `ping_clean`; the rest
read what those write. Nothing in the pipeline reads `ping_whacky`'s stages. The `once` project's `port_radius` reads
`ping_clean` and is frozen, not rebuilt.

| target | what the candidate may move |
|---|---|
| `port_call` | a call made from STK's `I` and `U` events needs the event's ping in `ping_clean` (`event_pair`, its header). The candidate flags more STK event rows at 0 kn (2018: 8,715 production keeps, against 3,559 the other way): calls on events alone may go (13,510 rest on events alone, TODO 148) |
| `ais_voyage` | voyages are cut at port calls: a call lost merges two voyages; `curated/ais/ping` holds the clean fixes with their call and voyage |
| `station_event`, `trip_voyage`, `voyage_gear`, `trip_reconciled`, `trip_landing` | the links to voyages and the trips' departure and return from the AIS |
| `ais_trail` | the fixes, their `hours`, `fishing`, `fishing_flow`, station and trip |
| `user_tables`, `user_tables_check` | v0 links the trail and voyages; its own tables counted |
| `check_port_call_logbook`, `check_vessel_activity`, `check_voyage_sharing`, `check_survey_tow_times`, `check_trail_agreement`, `check_trail_sid_coverage` | the checks; the survey's tows are a witness no rule saw |

Not in the test: `ais_catch` and `check_allocation_audit` (decision 261); the effort map's grid (a product rerun by
hand, whose spill reached 48 GB); `stream =`, the time flag (`rb_flag_ping_time()`), the duplicate's copy rule with
the recorded speed (TODO 184) and STK's events out of the track (plan 048): each its own decision.

## 3. Where: a scratch store, not the live one

**Recommended: a scratch clone.** The test then changes nothing in production, and the comparison is direct: the live
store holds production's outputs on exactly the inputs the scratch chain reads (§ header: no input or script of the
chain changed since the live build), so every difference is the rule's, or ramb's since 2026.11.02.2, which the
control rules out.

- **The store**: `/Users/einarhj/stasi/scratch-192-candidate/`, `cp -c -R -p` of the live `raw/`, `staging/`,
  `curated/`, `products/` and `archive/pre-phase4_2026-10-01/` (`check_voyage_sharing` reads it): seconds, and no disk
  until a file is written (the memory note on scratch runs). v0's links are relative, so they stay inside the clone.
- **The code**: a `git clone` of fishycode at this plan's commit, beside the store. The chain runs from it, so another
  session's edits in the main checkout neither change what runs nor stamp `fd.dirty`; `write_curated()` reads `git`
  in the working directory and stamps the clone's commit. The candidate's script is a copy of
  `curate/ais_ping_clean.R` changed as §2 says, kept in the study, outside both.
- **R**: `R_ENVIRON_USER` names a scratch Renviron (`FISHYDATA` the scratch store, the project's `LANG` and `LC_ALL`);
  the runner asserts the path holds "scratch". Each script in its own `Rscript`, set up as a target is: TZ UTC, `R/`
  sourced, the project's packages attached, `configure_duckdb_temp()`, then `source_script()`.
- **The disk**: 74 GB free. The chain writes about 67 GB (`ping_clean` 20, `curated/ais/ping` 20, the trail 24 and its
  matches 2, the rest 1), which with the spill would not fit. Nothing after `ais_voyage` reads `ping_clean`, and every
  ping comparison runs on `ping_whacky` (the clean step itself checks clean + flagged + no vid = tagged, year by year).
  So the scratch's own `ping_clean` is deleted once `ais_voyage` is built and its counts written: the peak is then
  about 47 GB, leaving some 27 GB. Before each step the runner wants its write plus 15 GB free, or stops; a watchdog
  stops the step at under 8 GB (harmless on a scratch store).

**The live store** would need no extra disk (a file replaced frees the old one), but it would change production before
TODO 192 is decided, on a commit of the candidate to `main`; the before survives only as fingerprints and small copies,
and undoing it is another rebuild of about 1.5 h.

## 4. The night, in order

One script, `night.sh` in the study, under `caffeinate -ims` and `lockf -k /tmp/fishycode-heavy.lock`, every step
logged with its start, end and exit. A step that ends well leaves a marker; run again, the script skips those and
resumes at the step that stopped. Times from 2026-11-02 and the sweep.

0. **Preflight** (seconds): ramb 2026.11.05.11 from GitHub (b7109d4), DuckDB 1.5.6, the code clone clean at the
   plan's commit, no R process above 4 GB, 60 GB free; a marker file for the morning's check that the live store was
   not written.
1. **The sweep's other 18 years** (under an hour): `01_sweep.R 2007:2026` (done years skipped), then `02_summary.R`.
   Read-only on the live store, written into its own study.
2. **The control** (about 20 min): production's own `curate/ais_ping_clean.R`, from the code clone, on the scratch
   store. Its `ping_whacky` against the live one, ping by ping: equal stages, or every difference listed. The clone's
   completion markers (`staging/ais/ping_clean_marks`) are deleted first: they match production's method and the
   cloned inputs, so the script would otherwise skip every year.
3. **The candidate's clean** (about 25-35 min): the study's copy (§2), which overwrites the control's output year by
   year.
4. **The chain** (about 1 h): the 16 targets of §2, in order, each script from the code clone; the scratch's
   `ping_clean` deleted after `ais_voyage`.
5. **The comparison** (about 30 min): §5's tables, and `fingerprint_outputs()` (`R/fingerprint.R`) of the chain's
   outputs in both stores.
6. `NIGHT DONE`, the time, the free disk, and the spill folders emptied.

About 3-3.5 h from the start. Fixed `TMPDIR` and DuckDB `temp_directory` in the scratch store's `_tmp/` (R's own
temp folder vanished twice, memory note), cleared at the end. The scripts run with the DuckDB settings they set
themselves, as a rebuild runs them; the lock keeps every other heavy job waiting (ask e).

## 5. What is compared, every record in one outcome

Written to the study's `out/` as small tables; Icelandic data, so they stay under `$FISHYDATA`.

- **Pings**, year by year: every ping of `ping_tagged` with a `vid` in one of kept by both, flagged by both (same or
  another stage), production only, candidate only, by stream, stage and basis, fast vessel (ceiling over 25 kn) and
  STK event row at 0 kn; the sums equal the pings with a `vid`.
- **The control**: production's rule under today's ramb against the store's labels; equal is the expected outcome.
- **The sweep against the candidate's clean**: the same rule on the same pings, two implementations. Expected equal
  but for the GPS logger's pings, which the sweep judged and the clean step does not (2018: 427), and the order of
  pings in the same second; every difference counted.
- **Port calls**: each live and each scratch call matched by vessel and overlap: the same, moved, only before, only
  after, by year and `rule` (`event_pair`, `tag_then_gap`, `tag_span`, `gap_near_harbour`).
- **Voyages**: the same way, by year; voyages holding more than one logbook trip (TODO 147's count).
- **Links**: every trip of `trip_voyage`, `trip_reconciled` (by the basis of its departure and return),
  `trip_landing` and every event of `station_event` in one outcome.
- **The trail**, year by year and by gear: fixes, `hours`, `kw_hours`, and the hours where `fishing` and where
  `fishing_flow`; fixes in both with their voyage, station, trip, `fishing` and `fishing_flow` the same or changed,
  and their hours; a sample of changed fixes (keys only) for the hand check.
- **v0 and the checks**: each table's rows; each check's output the same or its differences.
- **Fingerprints**: every output file of the chain changed, unchanged, only before or only after.

## 6. The morning's checks

Written into the study's README before the start (`$FISHYDATA/archive/2026-11-05-speed-rule-rebuild-test/README.md`,
with the log's place, `logs/night.log`), run by Claude when the maintainer is back:

1. The log ends in `NIGHT DONE`; else the step it stopped at, and the same command resumes.
2. Nothing in the live `raw/`, `staging/`, `curated/` or `products/` newer than the preflight marker (`find -newer`).
3. The control equal to the store's labels; if not, the differences come first, since they colour every other number.
4. Every year of the candidate's clean reconciled (it stops otherwise); the sweep and the clean agree but for §5's
   two known causes.
5. Every file written in the scratch store stamped with the plan's commit, `fd.dirty` false and ramb
   2026.11.05.11@b7109d4 (all files, not a sample).
6. The free disk, the spill folders empty.
7. Then the reading: `out/summary.md`, the outcome tables, and what goes to hand samples; whether the scratch store is
   kept until TODO 192 is decided. It must go before any live rebuild, or it keeps the old files' disk.

## 7. Asks for the maintainer

- **a. Where**: a scratch clone (§3), or the live store. *Recommended: the scratch clone.*
- **b. The sweep's 18 years first, the same night** (under an hour, and the cross-check of §5). *Recommended: yes.*
- **c. The control run** (20 min: today's ramb on production's rule against the store's labels). *Recommended: yes.*
- **d. The disk**: the scratch's `ping_clean` deleted after `ais_voyage` (§3), or the chain on 4-5 contrasting years
  only. *Recommended: delete it after `ais_voyage`; every year is built.*
- **e. DuckDB's settings**: the chain's scripts as they are, as a rebuild runs them, under the heavy lock; or each
  connection patched to 4 threads and 5 GB, as plan 054's scratch runs did (untried on the AIS chain, which may then
  fail or take longer). *Recommended: as they are, under the lock; the candidate's own limits query at 4 threads and
  5 GB.*
- **f. Who starts it**: Claude, detached tonight on your word (`nohup`, its own session, `caffeinate`: it outlives
  every Claude session; the Mac plugged in, lid open); or you, one command from your terminal. *Recommended: Claude,
  on your word.*

## 8. After the test

If the maintainer moves production: the candidate goes into `curate/ais_ping_clean.R` in a commit, AGENTS.md's
"Which ramb" names 2026.11.05.11 for it, and the store is rebuilt live, the 54 outdated targets less `ais_catch` and
`check_allocation_audit`, fingerprints first, the scratch store deleted before; a decision record closes TODO 192. If
not, the test's tables go into the decision that parks or changes the candidate.
