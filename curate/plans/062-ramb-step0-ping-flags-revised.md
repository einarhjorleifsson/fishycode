# 062 — ramb's step 0 revised: copies labelled, a lazy speed after the flags, direction as evidence, and every method scored on planted faults

**status:** partly built — steps 0-3 done 2026-11-02 (ramb's branches deleted, the studies archived; the two tests
measured, `$FISHYDATA/archive/2026-11-02-plan062-step1/`; the planted faults in ramb 2026.11.02.3, `dansk_planted`); step 3 done (the scores on the planted faults and the reload, and the timing,
`$FISHYDATA/archive/2026-11-02-plan062-step3/`). Written 2026-11-02 at the maintainer's request ("Ramb revisions": the forks, and the functions
that detect whacky pings, against the ICES data call, EM4SSF and iapesca), from a discussion the same day; the
maintainer's answers are under "Decided", the rest under "Asks". **see:** TODO 88 (the whack filter),
plan 061 (the ping chapter), decisions 067, 069, 078, 080, 164, 185, 232, 234, 273 and 275, `curate/ais_ping_clean.R`,
`curate/ais_ping_union.R`, ramb `R/ping.R`, `R/whack.R`, `src/whack_sda.cpp`, `~/stasi/em4ssf/me_code`

Drafted with AI assistance (Claude) on 2026-11-02. The facts below were read from the code (ramb 15af6e8, fishycode
f7f8e71) or are taken from the records cited; nothing was run for the draft. Steps 0 and 1 were carried out and
measured by Claude the same evening, and step 2 built, under "Done". No person has checked it. The choices are the maintainer's.

## What is there now

**Read from the code, 2026-11-02:**

- **ramb's branches.** `feed-clocks-step0` (3953894), `port-call-chunks` (7598da0) and `whack-feed-aware-evidence`
  (ad088e3) are all in `main` (15af6e8, equal to `origin/main`). Their worktrees (`~/R/Pakkar/ramb_wt_clocks`,
  `ramb_wt_portcall`, `ramb_wt_whack`) hold no uncommitted change. ramb has no fork on GitHub.
- **One exported function, five methods.** `rb_flag_ping_impossible(method = )`: `clean` (the default: `sda`, then
  `forward`), `sda`, `forward`, `fwdbwd` and `sequential`. All five take a data frame or a lazy table. For a lazy table,
  `.rb_label_lazy()` collects whole vessels in batches (`batch_pings`, 5 M), labels each in R, writes the labels to
  temporary parquet and joins them back, still lazy. The noise floor between feeds (`feed`) works for `clean`, `sda`
  and `forward` only. `fwdbwd` lets runs of bad pings through, by its own documentation.
- **Direction counts once, behind the speed.** The spike stage of `sda` flags a ping whose two legs meet at 25° or less
  *and* are both faster than `kn_max`. Argosfilter's own rule used distance (2.5 or 5 km); decision 067 swapped it for
  speed, since our intervals run from 5 s to 10 min. So the angle only picks which ping of an impossible leg goes. No
  flagger reads a recorded speed, course or heading.
- **Copies of ramb's work in fishycode:**
  - `curate/checks/whack_shims.R` rebuilds the four filters removed from ramb on 2026-10-11, so that 12 study scripts
    (`whack_*`, `sda_*`, `ais_residual_whacks.R`) still run; seven carry their own haversine (`hav()`). None is a target.
    Five write files to `curated/check/` that nothing rebuilds (`sda_tune`, `whack_recipe_timing`,
    `whack_recipe_vid`, `whack_sda_vid`, `whack_variants_vid`). They are the evidence of decisions 067 and 069, cited
    also by 080, 146, 181 and 218.
  - `add_central_speed()` in `curate/ais_ping_union.R`: the speed of astd and emodnet, which carry none, derived within
    each feed (by MMSI), lazily, from the previous report to the next, on the ellipsoid's local radii (within 0.1 % of
    the geodesic). ramb's `rb_calc_speed()` works on vectors in memory and takes the leg behind only. It runs in the
    union, before any flag, and the trail carries it unchanged.
  - The `tie` step in `curate/ais_ping_clean.R`: one ping per vessel and second, the first in a stated order (recorded
    over reconstructed, STK over the other feeds, then provider, longitude, latitude). Plan 061's one ramb candidate.
  - `ais_ping_clean.R` collects its own batches of whole vessels and calls ramb on data frames: the same batching as
    ramb's lazy route.
- **Fishycode leaking into ramb.** `.rb_whack_duplicates()` takes Iceland's feeds (`stk`, `astd`, `astdB`, `emodnet`)
  as its default priority. The exported `rb_flag_ping_duplicate()` sets none, so it does no harm.

**Measured before (from the records):** `clean` on the whole record, 543.6 M pings: 200 s on a data frame, 290 s
through DuckDB, the same flags (decision 067, ramb of 2026-10-05). The filter kept a 24 kn out-and-back to a
day-shifted copy of vid 2350's track (TODO 88). The store holds 104,771 same-second ties, 80,559 from the GPS logger
(plan 061).

**The outside workflows** (decisions 232, 237 and 273, plan 061): every ping rule of the ICES data call, Mendo et al.
2024 (EM4SSF) and iapesca is either in ramb in a labelling form or on the wish list. The ICES data call has no speed
test (`spThres <- 20` is set in `0_global.R` and read nowhere, from a search of its scripts); Mendo et al. and iapesca
drop pings over 25 kn; GFW's guide flags them, as ramb does. None has a speed rule ramb lacks. Course limits are a
wish (EM4SSF D1.1 §8.1, GFW p. 73).

## Decided (the maintainer, 2026-11-02)

a. **"Forks" means ramb's branches.** All three are merged: they and their worktrees are deleted (step 0).
b. **The whack study scripts are archived**, shims and all (step 0).
c. **Copies within one feed are labelled in ramb**, not dropped by a `distinct()` (reverses plan 061's verdict on
   them).
d. **A lazy speed per stream goes into ramb in this revision.**
e. **The evidence is combined by a hand-set rule**, not a learned score.
f. **A same-second tie is decided on evidence**: the position that fits the track stays.
g. **Direction counts in the whack detection** ("should ideally take into account directional changes, etc.").
h. **The book describes the best approach**, and EM4SSF's comparisons go to `~/stasi/em4ssf/me_code`
   (decision 275).

## Asks

1. **The speed's distance** (the maintainer: not sure). Proposed: the union's ellipsoid formula on both routes of the
   new function, so a data frame and a lazy table give the same numbers, as ramb's compatibility policy wants, with a
   test that ties it to Karney. Haversine would be ramb's one lazy basis, but it differs from `rb_calc_speed()`'s
   geodesic default by heading: by Claude's arithmetic, not measured, at 64° N up to 0.25 % north-south and 0.38 %
   east-west.
2. **No derived speed on a flagged ping.** Proposed: NA with basis `none`; the neighbours' speeds skip a ping flagged
   as a bad position (invalid, impossible, tie), and keep a copy (`duplicate`) in its stream: test (i) found that
   dropping the copies moves 223,471 speeds of 2017 by a knot or more, none of them wrong before. A recorded speed is
   kept as it is.
3. **The method list is a promise to users.** Proposed (Claude's view, asked for by the maintainer, not yet answered):
   a method is exported only if it scores well on some kind of data (step 3). The engines of an exported method stay
   internal; a method that does not score is removed after one release of warning, not kept as an internal function
   for comparisons (nothing in ramb would call it, and the book writes an outside rule inline). The pruning waits for
   the scores.
4. **A check of a track's time zone.** ramb has `rb_add_timestamp(tz = )` for a known zone, and step 0's clock
   functions measure one stream against another. Nothing tells from one stream which zone it was stamped in. Proposed:
   a check for summer time, a missing hour in spring with the vessel barely moving across it and a doubled hour in
   autumn where two copies of the track interleave; neighbour windows only, so lazy. In this revision, or later? It
   would answer `me_code`'s item 1 from the data.

## Steps

0. **Housekeeping, no ramb release.** Delete the three ramb branches and their worktrees. Move the 12 study scripts and
   the shims to `$FISHYDATA/archive/2026-10-whack-studies/`, with a README naming each script's decision; check what
   reads the five `curated/check/` files (here and in the old repos) before they move with it.
   **Done 2026-11-02** (by Claude): the three branches were in `main` and their worktrees clean but for build files;
   both are gone. The 14 scripts and the five files are in `$FISHYDATA/archive/2026-10-whack-studies/`, with a README
   naming each script's decisions; nothing read the files but the decisions that cite them. Left for step 4: ramb's
   `R/whack.R` still says its sda defaults follow `curate/checks/sda_tune.R`, now in that archive.
1. **Two simple tests**, read-only, in a scratch study:
   - (i) **The speed before the flags.** On one year: the astd and emodnet pings kept whose derived speed used a
     flagged neighbour, and how far it moves when derived on kept pings only.
   - (ii) **ramb's lazy route at scale.** Production's chain on a lazy table for one year, against `ping_clean` and
     `ping_whacky`: the same labels, wall time and peak memory, in a fresh process, three repeats, as ratios to the
     production script.
   **Done 2026-11-02** (by Claude, on 2017, the largest year and the only one with emodnet; not checked by a person;
   `$FISHYDATA/archive/2026-11-02-plan062-step1/`):
   - (i) The union's speed, reproduced from the positions, equals the stored one on 61,463,563 of 61,464,206 rows.
     7,309 kept astd positions (0.02 %) and 21,449 emodnet (0.12 %) had a neighbour flagged as a bad position;
     derived on kept positions only, 2,488 and 16,019 of them move by a knot or more, and their speeds over 25 kn
     fall from 589 to 5 and from 377 to 4. A neighbour flagged as a copy only (935,239 astd, 2,439,489 emodnet) is
     still a report of its own feed: dropped, it doubles the span, and 223,471 speeds move by a knot or more (ask 2).
   - (ii) The lazy route gives all 72,370,748 rows production's label and evidence but one pair: two copies of one
     report, alike in vessel, second, position and feed, where each route flags the other (ramb's lazy order, (time,
     lon, lat, feed), ties on them). It takes 1.62 times production's time (median 274 s against 169 s) and 0.88 times
     its peak memory (8.2 GB against 9.3 GB). The batches are not the cost: ramb's two passes take 123 s; joining
     their labels back to the year by row number, a window over 72 M rows per flagger, and writing it take 155 s.
2. **Planted faults, in ramb's `data-raw/`.** Faults planted into the clean, fishing-labelled tracks of ramb's example
   data (`dansk`, and the sets TODO 93 adds), thinned to several ping rates: a spike, a run, an out-and-back under
   `kn_max`, a time-shifted copy interleaved, lon = lat, two feeds with a clock offset, a near-copy a second later, a
   same-second tie at two places, a copy stamped in summer time, and a vessel truly fast. Each ping carries its fault
   (or none) and the track's fishing label; the sets are documented in ramb's data dictionary and read with
   `rb_read_example()`. The book (plan 061) and `me_code` use the same sets.
   **Done 2026-11-02** (by Claude, ramb 69b0332, version 2026.11.02.3, not pushed; not checked by a person):
   `rb_read_example("dansk_planted")`, 450,711 pings, made by `data-raw/planted_faults.R` with a fixed seed. The base
   is dansk without the 369 pings a 20 kn forward scan takes out (its own faults; its recorded speed never passes
   11.6 kn). One steaming hour of eight vessels is compressed to a true 30-40 kn. Each track is thinned to 10 s, 1 min,
   6 min and 1 h (`vid` = vessel and rate), and the nine faults are planted two while fishing and two not per vessel
   and rate where the track allows. The "time-shifted copy" is another day's positions (12-72 h away) stamped into
   the track, as on vid 2350 (TODO 88); "two feeds with a clock offset" is a second feed 10-90 s late. Each ping
   carries `fault`, `wrong` (whether step 0 should take it out), `planted_m`, `planted_s`, and the expert's `fishing`
   at its time. Wrong pings: 1,606 at 10 s, 1,412 at 1 min, 906 at 6 min, 262 at 1 h. The script checks that the
   detours keep both legs under 25 kn and turn under 60 degrees, and that no untouched leg passes 20 kn. TODO 93's
   sets wait for the maintainer; the planting itself (`plant()`) takes any clean track.
3. **Score every method and candidate** on the planted sets, and on TODO 88's reload days (the one labelled Icelandic
   set: the receipt lag marks the truth): each ping in one outcome (fault caught, fault missed, good
   ping flagged, good ping kept), by fault, ping rate and gear, with the good pings flagged *while fishing* as the
   number to watch; absolute scores, never only a ranking. The time and memory at growing size (1 M, 10 M, 100 M
   pings) as ratios. The outside rules are scored on the same sets in `me_code` (Mendo et al., iapesca) and in the
   book's appendix (the ICES data call).
   **Part A done 2026-11-02** (by Claude; not checked by a person; `$FISHYDATA/archive/2026-11-02-plan062-step3/`):
   every method and fishycode's chain on `dansk_planted` (ramb 378bf21, which adds a tenth fault to step 2's set: the
   first ping after a gap moved, the anchor of a forward scan). Each configuration also runs on the tracks without
   their wrong pings, so a good ping flagged is told as the method's own or collateral. No method flags a good
   fishing ping of its own; every one flagged is taken beside a fault. No method is best everywhere: per 10,000 good
   fishing pings, `clean` takes 27 at 10 s, 314 at 1 min, 368 at 6 min and 1,181 at 1 h, `forward` 49, 12, 221 and
   984 (sda's vmask erodes good pings up to 45 steps from a fault it cannot resolve; a wrong anchor costs the
   forward scan a stretch). Wrong pings 1 km or more off caught: `clean` 98, 88, 61, 18 %; `forward` 96, 90, 56,
   23 %. `sequential` equals `forward` at 30 times the time; `fwdbwd` catches the fewest; every method flags the
   truly fast stretches; no configuration flags a near copy within a feed (step 4a).
   **Part B done 2026-11-02**, the reload of 2026-10-12 to 10-14 labelled from the raw trail's receipt as decision 143
   measured it: of 814,218 pings of 828 vessels, 1,802 reloaded pings (164 vessels) are day-shifted copies of the live
   track. Every method catches 2-8 of them, and flags 2,776-3,014 live pings only when the reload is there: where a
   copy meets the live track, the speed rules take out the live pings. A copy rule that searches the vessel's own
   track at a shift (a day, an hour) is a candidate for step 4a. **Part C done 2026-11-02:** on whole vessel-years of
   2017-2018, the lazy route grows linearly (`clean` 0.7 s per million pings, 69 s and 6.6 GB at 100 M), the same
   flags as the data frame's, at 1.25 times its time and 0.82 times its memory at 10 M; `forward` takes 0.68 of
   `clean`'s time, `sda` 0.81. Time does not choose between the methods; the scores do.
   **A prototype, 2026-11-03** (the maintainer: leave turns out, speed alone as distance and time step): a hand-set rule
   judging each leg against the vessel's local speed, from its recorded speed over ground (`local_sog`), with no
   heading. On the planted faults it catches the most at every rate (1 km or more off: 99, 97, 82, 41 %; `clean` 98,
   88, 61, 18), out-and-backs under 25 kn included (29, 95, 79, 100 %; every other method 0), and keeps the truly fast
   stretches; it takes more fishing pings than `forward` at 1 min (1.46 % against 0.12 %) and coarser. From the legs
   alone (`local_track`) it fails where copies interleave. Neither catches the reload's copies. A candidate for step
   4c in place of the turn features; its parameters are a first guess. **Tuned 2026-11-03** on half the vessels, judged
   on the other: thresholds hardly change the fishing cost, and the first guess stays. The cost is the interleaved
   copies: with them taken out first (by the truth, the best a copy rule could do), the rule flags 0.02 % of fishing
   pings at 10 s and 0.10 % at 1 min and catches every far-off fault left. So the order for step 4: copies first
   (4a: within a feed, at a shift, the second feeds), then the speed rule against recorded speed.
   **A copy rule prototyped, 2026-11-03** (`scripts/copy_rule.R` there): one report twice, told by position, recorded
   speed and course. On the planted faults, copies first and then the speed rule catch the most at every rate (1 km
   or more off: 100, 99.5, 88.5, 62 %) and flag 0.07, 0.22, 1.32 and 3.5 % of good fishing pings. On the reload it
   finds the pairs but picks the live ping as the copy (8 of 1,802 copies caught, 2,612 live pings flagged): the
   track around is no witness where copies are many. Ask (new): may the copy rule take a feed's receipt time, where
   it has one, to decide which of two is the copy? It is the reload's answer key.
4. **The ramb release**, after steps 1-3:
   - (a) `rb_flag_ping_duplicate()` labels copies within a feed (exact, and near: within `max_dt_s` and the noise
     floor) and same-second ties. A tie keeps the position that fits the track (its legs to the neighbours, its
     agreement with the recorded speed and course); the feed order decides only when the evidence does not.
   - (b) A lazy speed per stream (`rb_add_ping_speed()`, by the naming rules): central difference, the span beside it,
     a basis, the same formula on both routes (ask 1), on unflagged pings (ask 2).
   - (c) Direction as evidence in `rb_flag_ping_impossible()`: the turn at the ping, the detour (the two legs against
     the straight line from the ping before to the ping after), the turn rate, the acceleration, and where a stream
     records them the residuals against its speed and course. Each is a neighbour window, so computed lazily in SQL;
     only the loop that removes a ping and judges its neighbours again needs the batches. A hand-set rule combines them
     (decided e), and switches off where the legs are within the noise or the interval is too long for a turn to mean
     anything. Opt-in, written to the evidence columns, until step 3 shows it catches more faults without flagging
     more fishing pings; then the default, checked on the store before it moves.
   - (d) The method list as ask 3 decides. (e) `.rb_whack_duplicates()` without its Icelandic default. (f) The zone
     check, if ask 4 says now.
   - (g) From test (ii): the lazy route without the join back, one pass per batch that runs every flagger of the call
     and writes the batch's rows whole, so a lazy table costs no more than production's own batching; and a total
     order (every column, as production sorts), so that which of two copies is flagged does not depend on the route.
   - A version, NEWS, tests, and a case for each new function in `test-etiquette.R`.
5. **fishycode follows.** The union without its own speed (ramb's, after the clean); `ais_ping_clean.R` on ramb's
   lazy route if test (ii) holds, without its own batching or `tie`; the targets from the union down rebuilt,
   fingerprints before and after, every difference explained in a decision.
6. **The book.** `flow_pings.qmd` describes step 0 as built (plan 061); the scores go in an appendix chapter.

## What would change the plan

- Test (i) finds no kept ping touched: the speed still moves to ramb (decided d), but the rebuild is not urgent.
  (It found 28,758 in 2017, and the copies' case for ask 2.)
- Test (ii) fails at scale: ramb gets one pass for the whole of step 0, collecting each batch once for every flagger,
  instead of a pass per flagger. (It held, at 1.62 times production's time, the cost in the join back: step 4g.)
- Direction adds nothing in step 3: it stays as evidence columns only.
- `clean` fails badly on some fault or ping rate: TODO 88's candidates (a limit per vessel from its own speed, chains
  that are each consistent) come into this revision.

## Bookkeeping

- An index row in `README.md`, a stub in `TODO.md` (184), plan 062 named in TODO 88's see line.
- `check_bookkeeping()` before any commit.
