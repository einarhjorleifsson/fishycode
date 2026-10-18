# 075 — Three sides: preprocessing without AIS, frozen one-time fixes, the generic flow

*2026-10-09. The maintainer's direction and choices; the plan (014), the measurements and the phase-1 code by
Claude (AI-assisted), from plan mode, an adversarial review and read-only counts on `$FISHYDATA`. Closes TODO 45,
37 and 46.*

## Decided

- **The line** (TODO 45, plan 014). Each script is on one of three sides and names it in a `# Side:` header,
  which `check_bookkeeping()` enforces:
  - **preprocessing**: Icelandic data into standard inputs, reading **no AIS**. The maintainer first said "per
    source, never cross-source", then narrowed it the same day. The logbook and the landings are two declarations
    about one trip, so reconciling them (the trip-landing match, gear from the landings) is preprocessing.
  - **once**: the one-time fixes;
  - **flow**: everything that uses the track.
  AIS may later qualify fishing that has no declaration (TODO 49), on the flow side.
- **Three one-time fixes**, frozen as decision 073 built them:
  - the STK mobile-id → vid key (`curated/vessel/vessel_ais_key.parquet`);
  - the GPS logger positions (`curated/logbook/sensor_gps`);
  - the port departure radius (`curated/reference/port_radius.parquet`, a stamped copy of
    `harbour_radius.parquet`).

  *Amended 2026-10-18: a fourth, the annual ship register's history to 2023-12-19 (plan 028), is built in the `once`
  project too, by the maintainer's choice (decision 132).*

  Their 23 targets form a second targets project (`_targets_once.R`, `TAR_PROJECT=once`). It watches the
  main-project files they read and never builds them. The main project reads each fix through `frozen_input()`,
  which stops if the file is missing or empty. A fix is redone only by a decision record.
- **AGENTS.md amended.** Its rule was that a reviewed input re-enters "never as a computed output". A one-time fix
  is computed once, reviewed, and frozen, so it re-enters as an input under the same principle: a person breaks the
  cycle.
- **Terms** (the maintainer's answers):
  - **port** is the place word everywhere, and `pid` (port id) stays;
  - `hid` is a source's own code;
  - a **stay** is the interval in port. Its values live only in the stay table, and pings carry a key ("values
    repeated on every ping are not kosher");
  - the ping column `trip` → `voyage`.

  The renames (ramb, columns, paths) are plan 014 phase 3 (c). Not renamed: STK `io`, the whacky/clean tables,
  `provider`.
- **Port labels.** Decision 074 removed the class. The two reviewed labels in `overrides/harbour_class.csv`
  (Hornvík `no_pier`, Helguvík `cargo`) set nothing in the flow. *Amended 2026-10-09: this said three, adding
  Kristnes `transient`, which decision 063 left to the data and never entered as an override.* They stay as reviewed
  description, and plan 014 phase 3 renames the file to `overrides/port_class.csv`. The WGSFD port file
  (`products/exports/wgsfd_harbours.R`) reads them from there.
- **TODO 37.** `tar_make_isolated()` is the way to build (AGENTS.md). Its check allows closing on that.
- **TODO 46.** The key audit's undeclared read of `ping_union` is now a watched input of the `once` project. Its
  AIS witness excludes `gps` as well as `stk` (`provider NOT IN ('stk', 'gps')`), so logger positions, interpolated
  from STK pings the key assigned, can never confirm the key.

## Measured (read-only, 2026-10-09)

- `sensor_gps`: 0 of 49,324,452 rows carry a wrong vid. The `.tid`-only join of TODO 41 hits 14,843
  `fs_afladagbok` samples (556 `.sid` with two vids), but no logger fix lands on them, so freezing today's file is
  safe. The join is fixed for a redo, as is the logger's read of its own `gps` rows.
- STK events (2017+, with a port): of 3,400,403, the cleaned-track neighbour test (`io_jump`) rejects only 40 that
  step 0 kept. The events can be tagged from STK alone (plan 014 phase 3 b).
- `curated/ais/trip.parquet`'s `hid1`/`hid2` hold port ids (`IS-THH`), while the logbook trip's `hid1` is a landing
  code (`42`).
- `lid_map`: 790,632 trip-landing links. Coverage of logbook trips is afli 38.3 %, fs_afladagbok 96.6 % and
  adb 98.9 %. 3,642 landings sit on two or more trips.
- The frozen radius: all 157 `pid`s have a polygon. A guard in `curate/harbour_stay.R` stops if one does not
  (TODO 36: a rename re-mints a pid).

## Removed

- `curate/corrections/afli_coords.R`, the AIS-free logger recovery (median 329 m off AIS), never adopted.
  - Its declaration `afli_coords.yml` stays.
  - Its output `staging/afli/sensor_gps` stays on disk as the record behind parked TODO 19's corroboration check.
  - The script is in git history before this commit.

## Graph after phase 1

- The main project has 48 targets (was 60); `once` has 23.
- `tar_validate()` passes for both.
- In the main project, `tar_outdated()` lists the three frozen targets (their commands changed) and the 15 targets
  downstream of them. Nothing was rebuilt; plan 014 phase 4 rebuilds once.
- The only data written is `port_radius.parquet`, identical in content to `harbour_radius.parquet`.
