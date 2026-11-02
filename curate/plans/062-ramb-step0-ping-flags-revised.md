# 062 — ramb's step 0 revised: copies labelled, a lazy speed after the flags, direction as evidence, and every method scored on planted faults

**status:** partly built — step 0 done 2026-11-02 (ramb's branches deleted, the studies archived). Written 2026-11-02 at the maintainer's request ("Ramb revisions": the forks, and the functions
that detect whacky pings, against the ICES data call, EM4SSF and iapesca), from a discussion the same day; the
maintainer's answers are under "Decided", the rest under "Asks". **see:** TODO 88 (the whack filter),
plan 061 (the ping chapter), decisions 067, 069, 078, 080, 164, 185, 232, 234, 273 and 275, `curate/ais_ping_clean.R`,
`curate/ais_ping_union.R`, ramb `R/ping.R`, `R/whack.R`, `src/whack_sda.cpp`, `~/stasi/em4ssf/me_code`

Drafted with AI assistance (Claude) on 2026-11-02. The facts below were read from the code (ramb 15af6e8, fishycode
f7f8e71) or are taken from the records cited; nothing new was run. No person has checked it. The choices are the
maintainer's.

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
2. **No derived speed on a flagged ping.** Proposed: NA with basis `none`; the neighbours' speeds skip it; a recorded
   speed is kept as it is.
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
2. **Planted faults, in ramb's `data-raw/`.** Faults planted into the clean, fishing-labelled tracks of ramb's example
   data (`dansk`, and the sets TODO 93 adds), thinned to several ping rates: a spike, a run, an out-and-back under
   `kn_max`, a time-shifted copy interleaved, lon = lat, two feeds with a clock offset, a near-copy a second later, a
   same-second tie at two places, a copy stamped in summer time, and a vessel truly fast. Each ping carries its fault
   (or none) and the track's fishing label; the sets are documented in ramb's data dictionary and read with
   `rb_read_example()`. The book (plan 061) and `me_code` use the same sets.
3. **Score every method and candidate** on the planted sets, and on TODO 88's reload days (the one labelled Icelandic
   set: the receipt lag marks the truth): each ping in one outcome (fault caught, fault missed, good
   ping flagged, good ping kept), by fault, ping rate and gear, with the good pings flagged *while fishing* as the
   number to watch; absolute scores, never only a ranking. The time and memory at growing size (1 M, 10 M, 100 M
   pings) as ratios. The outside rules are scored on the same sets in `me_code` (Mendo et al., iapesca) and in the
   book's appendix (the ICES data call).
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
   - A version, NEWS, tests, and a case for each new function in `test-etiquette.R`.
5. **fishycode follows.** The union without its own speed (ramb's, after the clean); `ais_ping_clean.R` on ramb's
   lazy route if test (ii) holds, without its own batching or `tie`; the targets from the union down rebuilt,
   fingerprints before and after, every difference explained in a decision.
6. **The book.** `flow_pings.qmd` describes step 0 as built (plan 061); the scores go in an appendix chapter.

## What would change the plan

- Test (i) finds no kept ping touched: the speed still moves to ramb (decided d), but the rebuild is not urgent.
- Test (ii) fails at scale: ramb gets one pass for the whole of step 0, collecting each batch once for every flagger,
  instead of a pass per flagger.
- Direction adds nothing in step 3: it stays as evidence columns only.
- `clean` fails badly on some fault or ping rate: TODO 88's candidates (a limit per vessel from its own speed, chains
  that are each consistent) come into this revision.

## Bookkeeping

- An index row in `README.md`, a stub in `TODO.md` (184), plan 062 named in TODO 88's see line.
- `check_bookkeeping()` before any commit.
