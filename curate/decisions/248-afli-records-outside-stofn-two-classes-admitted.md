# 248 — afli's records outside `afli.stofn`, each in one outcome: decision 098 holds, but for two classes the landings and the track admit

*2026-10-30. Plan 054 step 1, TODOs 75 and 118. Measured by Claude (AI) in a side session, read-only, and not checked
by a person; the scripts, logs and tables are in `$FISHYDATA/archive/2026-10-30-plan054-afli-outside-stofn/`. The
admissions are the maintainer's, put by Claude with AskUserQuestion the same day. Nothing is built: the two admitted
classes are built in plan 037's phase 2 (TODO 115, rebuild C). Closes TODOs 75 and 118.*

## The question, and the rule

Decision 098 did not admit the afli hauls that the merge into `afli.stofn` dropped. Decision 189 kept that for the sent
layer, until TODO 118 had classed every record. Since decision 205, `lid_map` reads every landing from 1992-09, so the
rule can now be tested in every period. The rule is decision 098's, applied to each class: a class is admitted if adding
it brings most of its trips nearer their landing, and if its positions agree with the AIS track about as often as held
hauls do.

## The records

43,463 staged records lie outside `afli.stofn`, with 288.3 kt of catch:

| group | records | what it is |
|---|---:|---|
| A | 23,513 | loaded into afli's `rafr_stofn`, never moved (TODO 118) |
| B | 3,182 | loaded, then deleted by Oracle |
| C | 2,009 | in fs_afli's `rafr_stofn` only |
| D | 14,759 | sent but never loaded (TODO 118) |

Decision 098's 23,570 rows are group A's records: 23,518 rows, plus 40 whose record is in `afli.stofn` through another
row, plus 12 with no staged record.

## The outcome

| class | records | kt | to 2007-08 | 2007-09..10 | 2011-14 | 2015-19 | 2020- | bad date |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| B deleted by Oracle | 3,182 | 48.3 | 2,728 | 262 | 125 | 23 | 3 | 41 |
| X impossible date | 11 | 0.0 | | | | | | 11 |
| E fs_afladagbok holds the vessel-day | 1,856 | 15.1 | | | | | 1,856 | |
| K strict copy (of a held haul 4,129; of another outside record 861) | 4,990 | 13.5 | 26 | 318 | 3,738 | 904 | 4 | |
| N no catch | 11,229 | 0 | 208 | 3,420 | 4,982 | 2,613 | 6 | |
| T0 loaded, on a kept trip | 5,910 | 30.9 | 1,168 | 2,651 | 1,187 | 903 | 1 | |
| T1 never loaded, on a kept trip, to 2014 | 2,542 | 29.7 | 354 | 1,257 | 931 | | | |
| **T2 never loaded, on a kept trip, 2015 on** | **1,714** | **21.9** | | | | 1,591 | 123 | |
| **W1 trip lost whole; catch and species match a free landing** | **7,021** | **60.3** | 170 | 1,934 | 2,372 | 2,362 | 183 | |
| W1 the same, but a held vessel-day or kept trip nearby | 928 | 5.0 | 178 | 643 | 66 | 41 | | |
| W1 catch matches, species unlike | 320 | 1.1 | 1 | 264 | 36 | 18 | 1 | |
| W1 catch does not match, or the landing holds none | 1,560 | 13.2 | 211 | 843 | 348 | 150 | 8 | |
| W2 trip lost whole; its landing is a kept trip's | 1,082 | 16.9 | 133 | 552 | 310 | 86 | 1 | |
| W3 trip lost whole; no landing within 2 days | 1,118 | 32.3 | 117 | 521 | 112 | 355 | 13 | |
| **total** | **43,463** | **288.3** | 5,294 | 12,665 | 14,207 | 9,046 | 2,199 | 52 |

The kilograms going in equal those coming out, and every record is in one class. "Free" means a landing within 2 days
that no logbook trip took. A copy (K) is the same vessel and date with an equal sent time, or the same position (within
55 m) and an identical catch, or an identical catch of two species or more within 3 days. This rule matches held records
against each other 2.2 % of the time by chance, against 10 % for decision 098's catch-only test.

Each class, judged by the rule:
- **Out, by the rule:** 19,562 records.
  - The source withdrew them (B): 3,182.
  - The merge ranks fs_afladagbok above afli on those days (E, decision 123): 1,856.
  - Copies (K): 4,990.
  - Their trips would overshoot the landing: T0 (39.5 % of trips more than 30 % over it, 28 % nearer), T1 (70.6 % over),
    W2 (59.2 % over). 9,534 records in all.
- **Out, unexplained:** 15,166 records.
  - No catch, so the landing cannot weigh them (N): 11,229. They sit about 2 h from the nearest held haul of the same
    gear, so they are not resends. The track puts 93.5 % within 5 km, against 97.5 % for held hauls.
  - No landing at all (W3): 1,118.
  - A free landing that disagrees, or a doubtful match: 2,808 (the other three W1 rows).
  - An impossible date (X): 11.
- **Pass both halves of the rule:** 8,735 records, T2 and W1 (below).

## Chosen (the maintainer)

- **W1 is admitted from 2007-06: 6,851 records.**
  - What W1 is: 1,155 trips lost whole, from 148 vessels, 2004-2022. The lost catch is 0.994 of the free landing
    (median). Picking the landing by date alone still matches on 76-87 % of trips, against 37 % for a landing a week
    off. The species overlap the landing as much as kept trips overlap theirs (95.3 % ≥ 0.8 in both). The track agrees
    as for held hauls: 96.2 % and 89.9 %, against 97.5 % and 90.7 %. No copy, and no station of any source on the same
    vessel-days.
  - The 170 records before 2007-06, where there is no AIS track, stay out (decision 098).
  - Five pairs inside W1 lie within 10 min and 1 km of each other with different catches. They are reviewed before the
    build.
- **T2 is admitted by trip: 1,505 records.**
  - What T2 is: 60 trips of 11 vessels, one vessel holding 77 %, all from Trackwell's Fishing Log. With these records,
    the trips' logged catch goes from 0.142 of the landing to 1.032, and 89.3 % of trips come nearer. The track agrees
    better than for held hauls: 98.7 % and 96.5 %.
  - Only the trips they bring nearer are admitted. The 6 trips that go farther (64 records) and the 4 that cannot be
    judged (145 records) stay out.
- **Every other record stays out**, as above. Decision 098 holds for it.

## TODO 75's open ends

- **The 1,854 rows before 2007-09:**
  - 1,167 sit on kept trips that overshoot the landing (92.3 % more than 30 % over, 5.9 % nearer). The landing reads
    them as copies, as after 2007-09.
  - 406 are on trips lost whole with a free landing. Only 60 of those match on catch and species, and they enter with
    W1 where they fall from 2007-06 on.
  - The rest: 93 W2, 175 with no catch, 12 copies, and 1 with an impossible date.
- **The ~410 trips:** recounted on today's `lid_map`, they are 394, with 1,030 rows. 309 of those rows fall in W1's
  matching class.

## No haul staged twice

The sent layer stages each record once: 1,317,165 records. The two admitted classes hold no copy of a held haul, exact
or near, and no two records with the same sent time.

## Found on the way, carried to TODO 115

- **The afli adapter misreads fs_afli's records.** It treats fs_afli's electronic stations as fs_afladagbok's hauls,
  which is wrong for 153 group C records of 2002-2022, 92 of them in W1. This is fixed with the admission.
- **Decision 171's line was not covered:** adb's 243 stations before 2025-11-19 with no counterpart, and the 14
  `TRACKWELL BAEKUR` and `PAPPÍR` trips decision 160 removed. Are they in afli's adapter's output?
