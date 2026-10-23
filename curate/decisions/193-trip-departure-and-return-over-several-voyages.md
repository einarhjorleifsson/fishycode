# 193 — A trip's AIS departure and return span every voyage its stations lie in; a span that reaches another trip keeps the one linked voyage, flagged

*2026-10-23. Plan 038 step 2, its first part: the maintainer's condition of decision 191 (ask b) that no reader
switches to `trip_reconciled` before this is fixed. The task, with its rule that trips interleaved with another are
flagged rather than guessed, came from the Claude session working through plan 038. The rule below, the choice between
keeping the linked voyage and NA, the code, the scratch run and every number are Claude's (AI), and a person has not
checked them. Coded and checked on a scratch store, not built. Scripts and results:
`$FISHYDATA/archive/2026-10-23-trip-span/` (`scripts/verify.R`, `results.txt`).*

## Found

- **The defect** (decisions 173, 174, their notes of 2026-10-23): the `ais` witness of a trip's departure (`T1`) and
  return (`T2`) was the one voyage `trip_voyage` links, the one overlapping the declared trip most. On a trip whose
  stations lie in several voyages these are one voyage's bounds, and they outrank the logbook's own times. Every one
  of the 16,178 trips this record changes that had an AIS witness had a timed station outside its AIS `T1`-`T2`.
- **How many trips span voyages.** By voyage_gear's link (every t1-t4 that is not 00:00, decision 155), 40,997 trips
  have stations in two or more voyages, not decision 155's 13,084. That count took one time per station, the first of
  t1, t3, t4. Most of the difference is static gear: a set (t1) on an earlier voyage than the haul.
- **A span that reaches another trip.** Of the 40,997 trips, 24,813 have a voyage within their span that holds another
  trip of the vessel: one of its stations by time, or its linked voyage. Mostly the trips are in sequence, and one
  station's time reaches back. A net set on the previous trip's voyage is one case. afli's hauls of a landing day
  put on the next trip are another: vid 182, trip -1037764 of 2019-02-25 to 27, holds two hauls of the 25th,
  01:12-08:35, that lie in the voyage that ended at 11:18 and holds trip -1037755. Where the other trip lies in the
  span: at its first voyage only 7,672 trips, at its last only 3,555, at both 10,500, at a voyage between 3,086. On
  these trips the span is wrong for fs_afladagbok and adb: its `T1` is a median 1,462-4,312 min from the logbook's
  own, against 12-16 min for the linked voyage. The trials (`scripts/measure*.R`) were run before the overlap test
  also read the other trips' links, which added 214 trips to it.

## Chosen (Claude, not yet reviewed)

- **The witness** is the span of the voyages a trip's stations lie in by their own times, where there are two or
  more: the first voyage's departure and port, the last voyage's return and port. The link is voyage_gear's: every
  t1-t4 not at 00:00, duplicate twin stations and stations deleted in the source left out. Unlike voyage_gear, it
  needs no gear. A station with no time, or with times in no voyage, adds nothing. One voyage, or none, by station
  time: the linked voyage as before, unchanged. This holds even where that one voyage is not the linked one (3,412
  trips, 362 of them linked to none), as the task asked.
- **All four times, not the hauls only.** Leaving static gear's set times out was tried. It leaves 899 fs_afladagbok
  and 235 adb trips on one voyage, where the logbook's own departure is the set voyage's (median 16-26 min to the span,
  410-442 min to the linked voyage). The sets that reach another trip's voyage are caught by the overlap test.
- **A span that holds another trip keeps the linked voyage, with `ais_flag` "overlap"**, rather than NA. Which trip
  the shared voyage belongs to is not judged (TODO 102). NA would give `T1` to a lower witness, although on these
  trips the linked voyage agrees with the logbook's own as on any other: `T1` a median 13-14 min, 76-81 % within 1 h;
  `T2` 20-22 min, 74 % (against 13-14 min, 76-77 % and 25-28 min, 68-69 % on one-voyage trips). Decision 191 c's "no
  trip and a flag" is about a fix inside two reconciled trips. That is the trail's rule (§5.1 a), which the flag lets
  it apply. It does not ask for a witness to be dropped. Every flagged trip has a timed station outside its AIS
  window, and readers must expect it.
- **Columns**: `n_voyage_ais` counts the voyages holding the trip's stations by time (0 for none). `ais_basis` says
  how the witness was found: `stations` (the span) or `trip_voyage` (the linked voyage), NA where there is no AIS
  witness. `ais_flag` is `overlap` or NA. `T1_basis` stays `reconstructed`: how the voyage was found is a modifier,
  and the grammar keeps modifiers in their own column.

## Done (code)

- `curate/trip_reconciled.R`: the `ais` witness as above, built in temp tables before the cascade, with the
  voyages, stations and samples as new inputs. Nothing else in the cascade changes.
- `_targets.R`: `trip_reconciled` depends on `ais_voyage` too.

## Measured (scratch, 2026-10-23)

A scratch `$FISHYDATA` of read-only symlinks to the store's inputs (built at 003b194, decision 180); the real store was
not written. HEAD's script on it gives the store's file exactly: 1,853,260 rows, none differing in any column. The new
table, row by row against the store, puts every trip in one outcome:

| outcome | trips | differ from the store |
|---|---:|---:|
| spanned (`ais_basis` `stations`) | 16,184 | 16,184 |
| flagged (`ais_flag` `overlap`), the witness as today | 24,813 | 0 |
| unchanged: one voyage by station time | 394,144 | 0 |
| unchanged: no station time in a voyage | 395,051 | 0 |
| unchanged: no AIS witness | 1,023,068 | 0 |

The spanned trips are afli 13,196, fs_afladagbok 2,366, adb 617 and aflaskeyti 5. 14,653 of them span 2 voyages,
1,134 span 3 and 397 span 4 or more. Six trips gain an AIS witness they lacked. On the spanned trips `T1` changes on
7,001, `T2` on 10,110, `pid1` on 1,735 and `pid2` on 2,080. No other trip changes in any column.

Against the logbook's own times, on the spanned trips (a time of day; before → after):

| | fs_afladagbok | adb |
|---|---|---|
| `T1`, median | 438 → 19 min | 430 → 22 min |
| `T1`, within 1 h | 33.1 → 65.6 % | 38.1 → 64.4 % |
| `T2`, median | 39 → 13 min | 35 → 14 min |
| `T2`, within 1 h | 53.9 → 82.3 % | 54.9 → 84.0 % |
| same departure port | 79.9 → 91.9 % | 85.3 → 94.0 % |
| same return port | 83.2 → 91.8 % | 84.7 → 94.3 % |

Over the whole table, decision 173's departure median is 13 min after for both sources (14 and 13 before). Within
1 h it moves from 76.0 to 76.6 % for fs_afladagbok and from 77.4 to 77.9 % for adb. The return median is 30 and 29 min
(31 and 29 before). The chosen `T2`'s outcome moves from differ to agree on 8,092 trips and the other way on 393;
`T1`'s from agree to differ on 1,584 and the other way on 1,263.

afli has no own departure time. On its 13,196 spanned trips, `T1` falls on or the day before the first fishing day on
12,827 (10,979 before), and `T2` on the landing day on 11,352 (4,049 before). STK's departure is more than an hour
from the span's on 2,940 of the 3,349 trips with both. On 2,141 of these it is the start of a later voyage of the
span. STK's rule takes the latest STK voyage out by the first fishing day, so it picks the voyage of that day, not
the earlier one the trip's first hauls lie in. 799 are elsewhere. At the return STK agrees as before (median 6 → 5
min).

Spans over 14 days: afli 617, fs_afladagbok 72, adb 13, aflaskeyti 3. Of these, 552, 67 and 10 are trips declared over
14 days. The rest begin with a voyage that is itself weeks long, a port call missed (TODO 90). That fault reaches the
one-voyage trips today, and more often: an AIS `T1` more than 2 days before the trip's first station on 2.44 % of
them, against 0.90 % of the spanned trips (0.49 % before).

## Left

- **For the maintainer: the build**, by name, fingerprints first. `trip_reconciled`'s command changed, so it is
  outdated without `tar_invalidate()`. Nothing reads it yet. The command stops unless `trip_reconciled` is the only
  target outdated on its path. On 2026-10-23 it was not, because other sessions' uncommitted changes to the logbook
  targets (TODO 79, plan 038 step 1b) also put `logbook`, `lid_map` and `trip_voyage` there. Run it once those are
  built or set aside; or let their build reach `trip_reconciled`, and read `verify.R` after.

  ```bash
  Rscript -e 'for (f in list.files("R", full.names = TRUE)) source(f); stopifnot(identical(targets::tar_outdated(names = "trip_reconciled"), "trip_reconciled")); fp <- fd_curated("link", "trip_reconciled.parquet"); a <- fd_path("archive", "2026-10-23-trip-span"); saveRDS(fingerprint_outputs(fp), file.path(a, "fp_before.rds")); file.copy(fp, file.path(a, "out_old.parquet")); tar_make_isolated(names = "trip_reconciled"); saveRDS(fingerprint_outputs(fp), file.path(a, "fp_after.rds")); file.copy(fp, file.path(a, "out_new.parquet"))'
  ```

  After it, `BEFORE=$FISHYDATA/archive/2026-10-23-trip-span/out_old.parquet S=$FISHYDATA/archive/2026-10-23-trip-span
  Rscript $FISHYDATA/archive/2026-10-23-trip-span/scripts/verify.R` gives `results.txt` again if the inputs have not
  changed since 2026-10-23; after a logbook rebuild the same report says what moved.
- `docs/data-dict.yaml`'s `link_trip_reconciled` gains `n_voyage_ais`, `ais_basis` and `ais_flag`. Its `T1_ais` and
  `T2_ais` then read "the AIS witness: the span of the voyages its stations lie in, or the linked voyage". Both wait
  until the built file has the columns, so the examples come from it.
- The 3,412 trips whose stations lie in one voyage that is not the linked one keep the linked voyage, or none
  (362). On the 3,050 with a link, their station voyage is closer to the logbook's own return but not to its
  departure: `T2` a median 1,115-1,283 → 101-381 min, `T1` 551-646 → 890-938 min. TODO 101's evidence.
- The flagged trips wait for TODO 102's classes. Their stations outside the AIS window, and the long first voyages,
  are TODO 90's (missed port calls).
