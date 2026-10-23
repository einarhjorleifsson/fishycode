# 203 — `lid_map` reads every landing: the 2007-09-01 bound lifted, January-August 2007's landings off the fixes

*2026-10-23. Plan 038 step 1b (decision 191, ask g; plan 039's ask e). The task is the maintainer's, passed on by the
session that started this one. The code, the scratch runs and every number are Claude's (AI), and a person has not
checked them. Coded and checked on a scratch store, not built. Scripts and logs:
`$FISHYDATA/archive/2026-10-lid-map-bound/` (`scripts/`, `results/`).*

## Found

- **What the bound was.** `filter(vid > 0, date >= ymd("2007-09-01"))` in `curate/link_lid_map.R` is agf's first day.
  The old code read agf alone (`~/stasi/logbooks/landings-match.qmd`: "trips within the aflagrunnur coverage window
  (2007-09-01 onward)"). Decision 031 merged lods in from 1992-09-01 and the bound stayed, so no logbook trip before
  2007-09-01 had a landing (plan 039 §6).
- **What it did to the catch on the fixes.** Every landing of January-August 2007 was a landing with no logbook trip,
  so `ais_catch.R` shared it on the fixes beside its own trip's logged catch (decision 191).
- **What it did inside the link.** Step 8 (the expected date) found no landing near the own date of 188 trips of
  January-August 2007 and read them as misdated, so it gave them landings 37 to 1,726 days later (median 164). 152 of
  them have afli ids beyond every matched trip's (above -31,695): the curve (`approxfun(rule = 2)`) gave them its end,
  early September 2007, and all 152 took landings of 2007-09-01 to 09-07. In all, 169 trips sat on 6 landings of those
  days, one of them shared by 85 trips. 187 of the 188 have a landing of their own.
- **No `.lid` is shared across schemas** in `curated/landing` today, with the bound or without it (0 of 2,199,407 rows
  with a vessel; `01_lid_collisions.log`). The cascade's keys on `.lid` alone (TODO 123, plan 007's question 3) mis-join
  nothing yet.

## Changed

- `curate/link_lid_map.R`: the landings are read with `filter(vid > 0)`, no date bound.
- **Step 8 keeps its own `year(date) >= 2007`.** Lifted too (variant B), it matched 93 trips dated before 1992-09,
  where no landing is held, to later landings: the bound's artefact again, at LODS's first day. It also matched 25 more
  in 1992-2006, and step 9 lost 5. Comments at both places say why.
- `docs/landings-match.qmd`: its cascade table counts the matches of the trips in its own window (from 2007-09-01),
  as its denominator does. It counted the whole `lid_map`, which would have passed 100 % once the link reaches 1992.
  The page keeps agf's window; widening it is the book's choice.

Checked for other bounds that assume 2007-09: `catch_by_species_trip.R`, `ais_catch.R`, `trip_reconciled.R`,
`corrections/logbook_gear.R`, `voyage_gear.R`, `checks/landed_logged.R` and `checks/allocation_audit.R` hold no date
literal. The audit's trip-landing outcomes run by the landing's year, and its catch outcomes from the first year
`ais_catch` holds, so both follow the link without a change. `link_lid_map.R`'s `date_origin` (2007-01-01) is the
curve's origin only.

## Measured: the link (scratch, 2026-10-23)

A scratch `$FISHYDATA` of read-only links to the store as built at 003b194 (decision 180); the real store was not
written (checked with `find -newer`). HEAD's script on it gives the store's `lid_map` exactly (826,109 rows, none
differing). The new script gives 1,533,984 (`02_lid_map_compare.log`, `03_lid_map_changed.log`):

| the trip's `T2` | before | after | of which unchanged |
|---|---:|---:|---:|
| before 1992-09 | 0 | 6 | |
| 1992-09 to 2006 | 0 | 676,151 | |
| 2007-01 to 08 | 198 | 31,909 | 0 |
| 2007-09 on | 825,911 | 825,918 | 825,911 |

- **Every match from 2007-09 on is unchanged**: the same landing, step and `n_trips`. 7 are new, at step 9 (2007-09 to
  2009): a vessel's first anchor before the old bound opens a gap that had none.
- **The 198 of January-August 2007 all change.** 187 step-8 matches, and 10 at the bound (trips of 2007-08-30/31
  matched one or two days off to landings of 09-01), now take their own landing at steps 1-3. One step-8 match is
  lost: afli trip -31280 of vid 250 (2007-07-23, port 1), beside trip 78389482 of the same days at port 13, which takes
  the day's landing. With the years before in step 8's curve its expected date is 2006-07-29, not 2007-09-02, and the
  vessel landed nothing within a week of it (`04_freed_and_lost.log`).
- **Landings freed:** 33 that a changed trip held before (413 t): 6 of 2007-09-01 to 09-07 that step 8 had given to
  169 trips (306 t), 10 at the bound (1.4 t), 17 of 2007-09-12 to 2012-04-07 (105 t). Each becomes a landing with no
  logbook trip. **Taken:** 5 landings of 2008-2009, by the 7 new step-9 matches (3.1 t).
- **Each trip and landing of 1992-09 to 2007-08 in one outcome** (plan 038 §4). afli's 704,004 trips of 1992-09 to
  2006: exact 613,646, ±1 day 28,322, the day without the port 19,986, ±1 4,706, ±2 6,274, weight 374 + 214, order
  2,629, none 27,853. Its 32,594 of January-August 2007: 31,909 matched, 685 none. LODS's 1,196,919 landings of
  1992-09 to 2006: 675,107 matched, 521,812 with no logbook trip; January-August 2007's 37,448: 31,889 and 5,559.
  6 of the 275,253 trips before 1992-09 match landings of 1992-09-01/02.
- **The tolerances, set on 2007 on** (plan 039 ask e; `09_tolerances.log`), as background statistics, not a pass. Per
  matched trip with catch, the landed weight over the logged has a median of 1.00-1.03 at every step in every period.
  Within ×1.3 at step 1: 84 % in 1992-2006, 86 % in January-August 2007, 92 % from 2007-09. The looser steps agree
  less in 1992-2006: step 4 66 % (83 % later), step 5 57 % (64 %), step 9 65 % (79 %). The landing's day against
  `T2` has the same shape in every period, about two landings after `T2` for one before.

## Measured: downstream (scratch)

Every target from `lid_map` down was run on the scratch store with HEAD's scripts of 34c5641 (`trip_reconciled.R`
before decision 193). Against the store (`07_downstream_compare.log`, `13_trail_compare.log`, `14_*`):

- `logbook/gear.parquet`: 2,818,284 station rows before 2007, 100,829 of 2007, 3 of 2008 and 3 of 2009 change (the
  landing's gear where the trip now has a landing); the row count does not.
- `station_window`: 80,371 rows before 2007 and 2,618 of 2007. `station_event`: identical.
- `voyage_gear`: 358 voyages of 2007, each holding a station whose gear changed. Three more rows (2008, 2010, 2023)
  differ, and three reruns of `voyage_gear.R` on the store's unchanged inputs flip those and four others: `arg_max()`
  has no tie-break (TODO 101). The scratch file was pinned to the store's rows outside the reachable voyages
  (`08_pin_voyage_gear.R`), so that noise stays out of what follows.
- The trail, rebuilt for 2007-2009 (the years its inputs changed in): 2008 identical; 2009 `gid_landing` on 110
  fixes; 2007 `fishing` on 3,859 fixes, `fishing_flow` on 7,499, `gid_used` on 23,954, `gid_landing` on 719,090, the
  voyage's gear on 30,648, the station or phase on 127. Every fix is still in it.
- `trip_reconciled`: the landing witness on 676,157 trips before 2007, 31,911 of 2007, 3 of 2008 and 3 of 2009.
- `catch_by_species_trip`: 8,393,841 rows to 8,669,601, the landed catch beside the logged for 1992-2007.
- `check_landed_logged`: 557 rows of 1992-2007 added; 33 rows of 2007 and 2 each of 2008 and 2009 (the step-9 trips)
  move; later years are unchanged beyond float noise. `check_trail_sid_coverage` moves before 2007 and in 2007 only
  (a station's gear class from its landing), `check_trail_agreement` in 2007 only (109 fixes more with a station's
  trip), `check_survey_tow_times` not at all.

## Measured: the catch on the fixes, kilogram by kilogram

`ais_catch` was run again with its units on both stores, every year (`scripts/ais_catch_units.R`). On the store's own
tables it gives the store's file in every row, unit, basis and raise factor; `kg` differs by at most 1e-10 kg (the
order of float sums). Every catch-bearing event, before and after, is in one class (`11_trace.log`,
`15_station_paths.log`). The kilograms shared equal the units' kilograms on both sides, to 0 kg.

The landing path on fixes, approach `fishing_flow`, kt a month (`fishing` alike):

| | June | July | August | September | 2008, a month |
|---|---:|---:|---:|---:|---:|
| before | 96.0 | 96.1 | 70.0 | 5.2 | 7.4-22.3 |
| after | 7.1 | 5.5 | 4.7 | 5.4 | the same |

By class, `fishing_flow` (33,230 of 2,562,505 events change):

| class | events | t in | t onto fixes |
|---|---:|---:|---:|
| a landing of January-August 2007 now matched to its trip | 31,889 | -999,014.3 | -245,238.1 |
| a landing freed (held before by a trip that now has its own) | 33 | +413.1 | +413.0 |
| a landing now matched at step 9 (2008, 2009) | 5 | -3.1 | -3.1 |
| a station moved up into a landing's unit that is gone now | 546 | 0 | -2,794.4 |
| a station whose own window or gear changed | 299 | 0 | +373.8 |
| a station moved up into a landing's unit that is new | 148 | 0 | +14.5 |
| a station moved from one landing's unit to another | 88 | 0 | 0 |
| a landing still unmatched whose voyages changed (2007) | 222 | 0 | +74.9 |

- **The year totals:** 2007 loses 998.7 kt in, from its landing path: 244.8 kt on fixes and 753.9 kt kept with no fix,
  most of it before AIS starts in June 2007. Its logged catch on fixes falls by 2.4 kt, to no fix: stations with no fishing fix of their
  own had been moved up into a January-August 2007 landing's voyages, the double-counted unit, and now go to the
  vessel's month or keep no fix. 2008 gains 19.2 t on fixes and 2009 59.0 t, the freed landings less the step-9 ones.
  2011 and 2012 each free one landing (0 and 13 kg); 2010 and 2013-2026 are unchanged in every event.
- **`raise_factor`** is on 11,960,471 of 2007's 13,823,866 logbook rows, from 5,768,992 of 13,932,766; 56 more rows in
  2008 and 202 in 2009.
- **The audit** (`12_audit_compare.log`): its catch outcomes move in 2007-2009 only, as above. Its trip-landing
  outcomes gain 676,157 trips before 2007 and 31,726 in 2007; in 2008-2012 only the freed landings and the new step-9
  matches above move.

## Left

- **For the maintainer: the build.** Decision 194 left `logbook` and its chain outdated on the maintainer's word: a
  build by name that reaches a target downstream of `logbook` goes with the logbook chain, or not at all. `lid_map` is
  downstream, so step 1b is built with that chain, and the same build carries decisions 181's caps, 193 and 194. Plan
  038 §8 orders it that way (step 1, then 1b). On 2026-10-23 `tar_outdated()` listed exactly `logbook` and its 19
  descendants. The command stops if anything else is outdated. It fingerprints the chain's outputs first
  (`tar_meta()` drops an invalidated target's paths) and keeps decision 193's copy of `trip_reconciled`. Then it
  invalidates `lid_map` by hand, since `targets` cannot see the script edit:

  ```r
  for (f in list.files("R", full.names = TRUE)) source(f)
  o <- targets::tar_outdated(); print(o)
  e <- targets::tar_network(targets_only = TRUE)$edges
  d <- "logbook"; repeat { n <- union(d, e$to[e$from %in% d]); if (length(n) == length(d)) break; d <- n }
  stopifnot(all(o %in% d), "lid_map" %in% o)
  a <- fd_path("archive", "2026-10-lid-map-bound"); a193 <- fd_path("archive", "2026-10-23-trip-span")
  fp <- unique(unlist(targets::tar_meta(names = tidyselect::all_of(o), fields = "path")$path))
  saveRDS(fingerprint_outputs(fp), file.path(a, "fp_before.rds"))
  file.copy(fd_curated("link", "trip_reconciled.parquet"), file.path(a193, "out_old.parquet"))
  targets::tar_invalidate(lid_map)
  tar_make_isolated(names = o)
  saveRDS(fingerprint_outputs(fp), file.path(a, "fp_after.rds"))
  file.copy(fd_curated("link", "trip_reconciled.parquet"), file.path(a193, "out_new.parquet"))
  ```

  Then `TZ=UTC Rscript $FISHYDATA/archive/2026-10-lid-map-bound/scripts/16_after_build.R` compares the store's
  `lid_map` and catch with this scratch. Where the rebuilt logbook changed trips (decision 181's caps), the differences
  are theirs, listed by year. Decision 193's `verify.R` is read after the same build.
- **Not chosen here.** Step 8 before 2007 (variant B), and whether the looser steps' tolerances hold in 1992-2006:
  their weight agreement is lower there, as above. The month step before LODS is plan 038 step 3.
- The scratch stores are kept in `scratch/` (about 15 GB) until the build is read; the scripts make them again in
  about an hour.
