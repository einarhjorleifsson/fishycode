# 240 — The logbook merge after a colleague's Nephrops checks: one count, no stored effort, extremes flagged, adb read as fs_afladagbok

*2026-10-29. Plan 050 (TODO 156). An MFRI colleague raised five issues with the Nephrops series in the new mar's merged
logbook (version 2026-10-27), and the maintainer had fishycode's merge reviewed in their light, then answered the plan's
asks a-e and h the same day. Built in three commits (fea2317, 9e33b8b, 93dfbdb), each run first in a scratch store
against the live one (plan 050 §6), and the store rebuilt from them the same afternoon. Built and written by Claude (AI);
the numbers come from its runs, and no person has checked them.*

## Decided (the maintainer, 2026-10-29)

- **One count for every gear** (ask a): `effort_count`, the grammar's, "for longline it is number of hooks, nets number
  of nets, pots number of pots, towed gear number of trawls", with its basis and its unit.
- **No flag for a count that looks like a trip setting** (ask b): the count changes within 4-7 % of trips in every
  source, so a note, not a column (vid 2048's single tows logged as twin are the Directorate's data).
- **adb's gear read back at its adapter** (ask d): "the adb is an inhouse convertion. it messed up the gear code".
- **A letter twin of the gear code** in the merged product, `gear_code` (`XXX_YYY`, one to each new gid), and the
  landing's gear correction in the records users use.
- **No stored effort** (ask e): the times, the count and a recorded duration are the observation; the duration and the
  effort are the analyst's choices (a longline's t1 → t4 or t3 → t4; whether a twin tow counts twice), made by
  `calc_effort()`. The colleague's email had said the same.
- **An extreme value is flagged, not corrected** (ask h): "the decision taken at the time was ad-hoc. we deal with this
  issue downstream when it comes to joining things to ais etc."; "we are not correcting e.g. extreme catch values. same
  should apply in general" (now in `AGENTS.md`, Rules).
- **The tails** (ask c) are found by vessel and period with a trip guard, and held on branch `plan-050-step5-tails` for
  plan 051, which sets every whole-weight factor from one table.
- **afli stays first per vessel and date**; in the end fishycode bypasses adb.

## Built

- **Step 4** (fea2317). adb's legacy gear code is read back to the FS code through adb's own `fishing_gear` at its
  adapter: every station adb shares with fs_afladagbok from 2025 on gets fs's code. `logbook_gear.R` drops its adb path
  (amends decision 154). `lid_map`'s pelagic set takes the new code alone: its loose weight step held Nephrops trawl,
  shrimp trawl and longlines as pelagic (292 of 335 links). `gear_code` in `reference/gear/mapping.R`, the merge,
  `gear.parquet` and v0.
- **Step 2** (9e33b8b, 93dfbdb). The count: afli's twin flag 0/1 read as 1/2 (`derived`; per vessel it follows
  fs_afladagbok's count), fs_afladagbok's and adb's counts as recorded (equal on every station both hold), one gear
  `synthesised` for a towed gear or a seine that records none. `effort_count_unit` beside it. afli's dredges no longer
  have effort 0 (13,351). adb's times are read as fs_afladagbok's (`elogbook_times()`, `R/logbook_effort.R`): its tows
  had no duration, and `station_window.R` no longer moves them.
- **Step 6.** The 22,359 fs_afladagbok stations of 2021 with a start and no end: neither afli's sent messages nor adb
  holds their ends. Declared in `docs/output-schema.md`.
- **Ask e** (93dfbdb). `effort`, `effort_unit`, `effort_duration` and `effort_duration_unit` leave the adapters, the
  merge and v0; `duration_m` is the duration the record gives (afli, aflaskeyti), NA for the e-logbook
  (`.duration_source` `times`). `calc_effort(sample, from, to, by_count, unit, implausible)` reproduces the effort
  stored before wherever both take the same interval.
- **Ask h** (93dfbdb). `flag_duration_limit()` (`R/duration_limit.R`) keeps the value and flags it: above the gear's
  limit, a recorded duration of 0 or less, an e-logbook span below 0 (a span of 0 is one time in every slot, which the
  windows handle). `judged_time_sql()` leaves out the end a flagged duration ran to in `station_window.R`,
  `voyage_gear.R`, `trip_reconciled.R` and `allocation_audit.R`; `calc_effort()` does the same by default.
- **Two leads from step 1** (93dfbdb). afli's Nephrops tow times before 2000 are minutes, not hours (median 270-300 in
  every five years from 1965): 132,684 tows keep them. fs_afladagbok's coordinate format is read by adb's rule
  (decision 211): Marína raun's six-digit positions are seconds, not hundredths of a minute.

## The rebuild

`$FISHYDATA/archive/2026-10-29-plan-050-rebuild/` (`rebuild.sh` and its logs). At 93dfbdb, DuckDB 1.5.6, ramb
2026.10.28.3: the twelve targets whose scripts changed invalidated by hand, and the 40 outdated targets built from
14:32 to 15:38 UTC, nothing outdated after and the tree unchanged during the build. Every one of 8,084 output files in
one outcome against the fingerprint before:

- **The same: 7,799.** The merge's station and trip fates among them: every staged record keeps its outcome.
- **Rows or schema changed: 72.** The planned columns in the staged and merged fishing samples and the gear tables;
  `station_event` +131,174 rows (the restored Nephrops tow ends); `station_window` −46, `lid_map` −10,
  `catch_by_species_trip` −12 and `catch_flag` −6 (the gear and the landing links); the AIS catch +23,964 rows in 33
  files and `trail_match` ± a few hundred rows a month in 26 (the windows); the allocation audit −26 rows, the trail's
  species coverage −4.
- **Values moved: 212.** The trail (151 files), the AIS catch (47), `trail_match` (6), and `voyage_gear`,
  `trip_reconciled`, the merged station (positions, twins, station types), `catch_by_species_station`, two checks, and
  the staged fs_afladagbok station (positions) and afli_sent sample (the flag).
- **Only before: 1.** adb's `surrounding_net.parquet`, no longer read; the file stays.

After it: v0's user tables (`products/user_tables.R`; station 7,301,171 rows with the count, its basis and unit, the
duration's source and raw value, no effort) and the effort map's two grids (`products/effort_map/grid.R`, and `grid.R
fixes`), rerun at 93dfbdb. The vessel overview's haul record shows "duration · count" in place of "duration · effort":
the recorded duration, or the one its times give (a tow t2 → t3, a set t1 → t4), marked when flagged
(`products/vessel_overview/api.R`, `www/app.js`). Tested on port 8793 against the rebuilt store: an adb haul of 2026
("310 min t2 → t3 · 1 trawls", its gear in and out now in t2 and t3) and an afli haul of 2015 ("224 min recorded ·
1 trawls"), no console error. A service started before this commit reads `effort` and must be restarted.

## Where the colleague's five issues stand here

1. **The count of trawls.** afli's 0/1 flag is read as 1/2, the e-logbook's count as recorded; the product stores the
   count, not the effort. The new mar reads the flag as a count (effort 0 on 2.21 M single trawls).
2. **No 2021 tow times.** The merge takes afli first: 2021's trawls keep their ends (99.9 %). The 22,359 stations it
   takes from fs_afladagbok have none anywhere we hold. The new mar takes 2021 from the e-logbook alone.
3. **Tails.** Found, and held for plan 051.
4. **The landings 2000-2007.** Ours equal `lods_oslaegt` and the new mar's to the kilogram for Nephrops. The new mar's
   detailed landings of 1994-2006 read LODS's pelagics in tonnes as kilograms.
5. **vid 2048, May 2026.** The Directorate's data, as the new mar's author says; a note, not a correction.

## Open

- Plan 050 step 1's comparison with the new mar's merge, both halves (a session started 2026-10-29), and asks f (access to
  the live `fs_afladagbok`; its build drops trips registered on a month's last day) and g (the candidate defects for
  the new mar's author).
- Step 5 on its branch, for plan 051 (TODO 152, TODO 157).

Closes TODO 153 (the twin-trawl flag) and TODO 154 (the 2021 ends).
