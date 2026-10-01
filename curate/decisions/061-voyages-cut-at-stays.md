# 061 — Voyages are cut at stays; the AIS chain is rebuilt once

*2026-10-01. Plan 011 Phase 4. Written BEFORE the rebuild, as the plan requires; the measured result is added
below when it has run.*

## What changes

`curate/ais_trip.R` no longer finds harbour runs from the polygon tag and bridges those shorter than 4 h. A
voyage is the sea between two stays (`curated/ais/harbour_stay`, decisions 059–060), from every provider; the
departure and arrival harbour are the stays either side. Event-only stays are not used (decision 060).
`curated/ais/ping` gains `stay_pid`; `pid` (polygon tag) is unchanged. The 4 h stay minimum is kept.

## What is rebuilt, and why now

The whole outdated chain, once (AGENTS: not per polygon change): the 26 outdated targets, among them
`stk`, `ais_ping_union`, `ais_ping_tag` (current polygons, decision 058; the ping tag still carries the old
set), `ais_ping_clean`, then `check_stk_event`, `harbour_radius`, `harbour_stay`, `ais_trip`, `trip_voyage`,
`ais_ping_trail`, the logbook and landing targets, and the key checks. The events and stays are computed from
the rebuilt `ping_clean`, so their numbers may differ a little from decisions 059–060.

## Baseline kept

`$FISHYDATA/archive/pre-phase4_2026-10-01/{trip,trip_voyage}.parquet` (the old voyages and their links).
`curated/ais/ping` and `ping_trail` are not archived (derived, ~45 GB); the old logic is in git (`342f766` and earlier).
Rollback = restore the two files and `git revert` the `ais_trip.R` change; `ping` is rebuilt by `ais_trip`.

## What is measured

`curate/checks/voyage_sharing.R` → `curated/check/voyage_sharing.parquet`, same definitions before and after:
logbook trips linked, trips whose voyage is shared with another trip (plan §6: from ≈ 23 % afli, 19 % fs_afladagbok to
a small, explained residue), arrival-harbour agreement with the logbook landing harbour, voyages over 3 and 7 days,
vid 2481 in 2011 (≈ 185 voyages).

## Result (2026-10-01, rebuilt in 45 min)

`tar_make()`: 21 targets built, 0 outdated afterwards. The first attempt stopped when the session lost its connection;
the targets it had finished were kept and the rest rebuilt. Checked on the outputs, not the log: `ping` has the same row count as
`ping_clean` in all 20 years; 54 % of pings carry a voyage, 45.9 % are in a stay; vid 2481 in 2011 has **186 voyages** (was 1;
185 landings). Rebuilt inputs: 1,468,284 stays (decision 060 had 1,468,243), 1,319,244 voyages for 2,731 vessels.

**The residue, voyage level** (voyages linked to more than one logbook trip, the measure of plan §6; "before" reproduces the
plan's 23 % and 19 %, so the baseline is the same thing):

| schema | linked voyages before → after | shared voyages before → after |
|---|---|---|
| afli | 320,762 → 602,441 | **23.2 % → 5.0 %** |
| fs_afladagbok | 86,830 → 139,665 | **19.3 % → 4.2 %** |
| adb | 1,762 → 4,494 | 30.4 % → 7.1 % |

Voyage length: over 3 days 19.5 % → 7.4 %, over 7 days 10.3 % → 2.4 % (a long trip of a freezer trawler is real; not
examined further). Arrival harbour equals the logbook landing harbour for 92.7 % (afli) and 94.1 % (fs_afladagbok) of linked trips,
was 83.0 % and 88.2 %.

**What is left**, of the shared voyages (afli 30,091, fs_afladagbok 5,912): 78 % carry exactly two trips, 8–9 % four or more.
For afli only 3.6 % have all trips on one day, so these are trips on different days with no stay between: the landing
without a stay (decision 060: 6.5 % of landings, of which about a third are visits of 1–4 h, a third under 1 h, a third
never heard in the harbour). For fs_afladagbok 34.7 % are on one day (two logbook records in a day; a real second trip).

**Cost:** the share of logbook trips with any voyage fell a little, afli 2008 97.5 → 95.4 %, 2012 98.9 → 97.2 %, 2023 unchanged
(99.2 %): more, shorter voyages, and those under 10 pings are dropped (`MIN_PINGS`, unchanged).

**Not done, and where it stands:** the 4 h stay minimum was kept as asked. The residue of about 5 % is the measure to beat when the
per-harbour minimum stay (TODO 33) is tried on the 1–4 h class. Phase 5 (a voyage-only `.tid` in `ais_trail()`) is open.
