# 155 — A station's voyage by its own time, and an audit of every link the flow makes

*2026-10-20. Follows decision 154. The code is in; the rebuild from `voyage_gear` and the audit's first run follow
(below, when done).*

- **Who chose.** The maintainer: a voyage whose gears tie points to a wrong voyage allocation, since two gears on a
  voyage are rare, and the fault "may show error in the code flow that may actually then affect single voyage gears";
  "pursue this - and then do double checks on this, you may find some other allocation errors", and look for a
  method in the flow to check such things in general. Claude chose the rest, not yet reviewed: the rule below, the
  audit's links and outcomes, and leaving out stations deleted in the source.
- **Who did the work.** Claude (Anthropic), in one session: the measurements, the code and this record. The numbers
  were measured by Claude on the build of 2026-10-20 (c7fa8c7); a person has not yet checked them. Scripts and notes
  in `$FISHYDATA/archive/2026-10-voyage-gear/` (`README.md`, `scripts/`).

## Found

- **A trip goes to one voyage; its stations did not.** `link_trip_voyage.R` links a logbook trip to the one voyage it
  overlaps most, and `voyage_gear.R` counted every station of the trip for that voyage. A logbook trip often spans
  several AIS voyages (a vessel in port overnight, a Danish seiner in and out by day): of 1,686,274 stations with a
  time of day, 93,246 (5.5 %) lie in another voyage of the vessel, 81,725 of them the next or the one before, in every
  year 2007-2026 and every source; 13,084 trips have timed stations in two or more voyages. So 17,518 voyages took a
  landing's gear and 2,746 none while logbook stations lay in them. Example: vid 2965 (Danish seine), afli trip
  -1255497, 29-31 August 2021, 13 hauls over four voyages, all counted for one.
- **A check that compares only where both sides exist hid it.** `trail_agreement.R` reported 99.5 % agreement between
  a fix's station trip and its voyage's trip, counted over the fixes that have both. 13.8 M fixes on a station (8.8 %)
  never reached the comparison: their voyage named no trip, or several. On timed stations: 91.7 % same trip, 4.5 %
  shared voyage, 2.8 % voyage with no trip, 0.7 % fix in no voyage, 0.4 % another trip.
- **The ties are not this fault.** By station time the voyages with several gear labels rise from 601 to 755; 224 of
  the 242 tied stay so. Stations of two gears lie in one AIS voyage: a port call missed, or a real change of gear.
  TODO 90.
- **Stations deleted in the source** (`eytt_deleted`, 352 afli stations with 4,238 t): `station_window.R` leaves them
  out, and so `ais_catch`; `lid_map`'s trip catch, the catch by species, `landed_logged` and `voyage_gear` counted them.
- **Other links**, measured whole: a station's date is outside its trip's days for 3.5 % of adb stations and 3.0 % of
  fs_afladagbok's (0.04 % of afli's); a station's time lies in a port call of its vessel for 7.4 % of fs_afladagbok's
  timed stations and 5.9 % of adb's (0.75 % afli), mostly where the port call spans an AIS silence of days to months
  (the weak rule of plan 031) and sets of nets laid on an earlier trip; of trips matched to a landing exactly, 76 %
  land on the end day of the voyage holding their last station at its port, 3 % before that voyage ended (a port call
  missed), 2.4 % at another port. Catch: every logged kilogram since 2007 reaches `ais_catch` but for the deleted
  stations and 57 t on 43 stations with no window (no gear, no unambiguous vessel, a gear with no code), lost
  silently. Not a fault: negative vids (dbplyr's `%%` is `FMOD`, every such vessel is in `ais_catch`).

## Done (code)

- **`curate/voyage_gear.R`**: a logbook station is on every voyage one of its own times of day (t1-t4, not 00:00)
  lies in; a station with no time of day, or whose times lie in no voyage, stays on its trip's voyage. Stations of
  trips linked to no voyage now count where their times lie. Stations deleted in the source are left out, as in
  `station_window.R`. Built as temp tables one step at a time: as one query, or with a range join, DuckDB spilled over
  100 GB (an ASOF join finds a time's voyage).
- **`curate/checks/allocation_audit.R`**, target `check_allocation_audit`, `curated/check/allocation_audit.parquet`: the
  method. Each link is a child record placed in a parent; the child's own time is a witness the link did not use; every
  child is counted in exactly one outcome, the inconsistent and the unjudgeable included, with `ok` TRUE, FALSE or NA.
  Links: `station_voyage`, `station_voyage_gear`, `fix_trip`, `station_trip`, `trip_landing` (by match type) and
  `catch` (kilograms). It runs in about 5 seconds.
- `trail_agreement.R`'s header names its blind spot; `docs/one_flow.qmd` and `AGENTS.md` describe the rule and the
  audit.

## Measured in a trial (read-only, scratch store of symlinks to the build of 2026-10-20)

- `voyage_gear`: 24,838 voyages go from a landing's gear to the logbook's and 3,802 from none (5.8 M fixes); 951 fall
  from the logbook's to a landing's, 60 to none, 288 to ambiguous (several speed ranges now seen). Of the 3,644 voyages
  whose code changes from a landing's to the logbook's, 259 change gear label and 1,536 speed range.
- The audit's `station_voyage_gear`, on 1,802,922 timed stations in a voyage: before, 94.9 % in a voyage taking their
  own gear from the logbook, 3.5 % in one taking a landing's, 1.0 % in one with no gear, 0.05 % in one with another
  logbook gear; after, 99.35 %, 0, 0 and 30 stations, and 0.65 % ambiguous.

## Not done (proposed, the maintainer's to choose; TODO 101)

- The trail's `.tid_voyage` / `n_tid_voyage` still come from the trip's one voyage: a voyage holding a trip's stations
  by time names no trip.
- Stations deleted in the source still count in `lid_map`'s trip catch, the catch by species and `landed_logged`.
- The 57 t on stations with no window are not kept on a coarser unit in `ais_catch`.
- The stations in port and the trips landed before their voyage ended are evidence for TODO 90 (port calls over
  silences, missed port calls); the stations dated outside their trip are not examined further.
- The audit's method fits ramb as a generic tool (a link, a child time, a parent interval, every child counted).
