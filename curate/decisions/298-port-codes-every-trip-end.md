# 298 — Every logbook trip end keeps its port: adb's trips carry their pid, fs_afladagbok maps every app code

*2026-11-08. TODO 196 (closed), at the maintainer's word: "Proceed with what is left from 196" and "Delete, then
rebuild". Coded, run, measured and counted by Claude (AI); no person has checked the code or the counts. The study, its
scripts and every table: `$FISHYDATA/archive/2026-11-07-port-codes/` (its README).*

## Why

The port list is unified (decision 007) and the neighbouring ports stay apart (2abe3ed, the maintainer: "there are and
should be different ports"). Two gaps were left, both in the adapters:

- **adb's trips had no pid.** Its port codes are the landing system's hid (decision 172), and only `trip_reconciled`
  joined them to a pid. In `curated/logbook/trip.parquet` 37,847 adb trips had none.
- **fs_afladagbok dropped 14 app codes.** The adapter read one app code per port, from the ports a landing uses, and
  439 trip ends with another code lost their port.

## What was chosen

- **adb's adapter joins `pid1`, `pid2` and `port` from `port.parquet` by hid** (d62cc07). 0, the placeholder of the
  apps that send no port, keeps its hid and gets no pid. `trip_reconciled` reads the pid from the trip; its own adb case
  is dropped, and its values do not change.
- **fs_afladagbok maps the app's codes through `port_code.parquet`**, one row per code. `port_code.R` now takes every
  code the e-logbook's trips use (`ws_veidiferd`). The 14 codes:
  - three second codes of Icelandic ports (Borgarnes, Hellissandur, Hnífsdalur);
  - 109, abroad;
  - 130, "port name missing", a placeholder;
  - seven countries;
  - two test ports.
- **The nine codes that no landing uses** are classed in `reference/ports/port_code_class.yml`: the seven countries as
  `abroad`, the two test ports as `placeholder`. The file is a hand-kept list; these nine lines were added by Claude
  (AI) and wait for the maintainer's look.
- **Voyages with no departure port stay as they are**: 7,269, all the first voyage of their year. 3,991 follow a voyage
  still open at New Year, 2,143 are in the vessel's first year, 811 follow a year with no voyage, and 324 follow a
  voyage that ended at a port, 226 of them after more than a month. Carrying the old year's port forward would be a
  guess; no look-back.

## What was run

- **A scratch test** (2026-11-07) of the five steps the fix touches, on a `cp -c` clone: only the port columns changed.
- **The live rebuild** (2026-11-08, 06:54-07:37), at 8f46429 with ramb 2026.11.07.1 and DuckDB 1.5.6: the 34 outdated
  targets from `port_code` down, `ais_trail` and `user_tables` among them.
  - Left outdated: `ais_catch` and `check_allocation_audit` (decision 261), and the place-name session's
    `name_group`, `place_name` and `place_name_evidence`.
  - All 9 curated files that changed carry 8f46429 with a clean tree. 8f46429 is another session's commit to
    `TODO.md`, made a minute before the build began.
- **The store before the fix rebuilt on a second scratch clone** (code 2abe3ed, `scripts/run_before.sh`), since no copy
  of the old files was kept. Every file the rebuild changed was then compared with it row by row
  (`scripts/04_before_after.R`).

## What it changed

| file | rows changed | what |
|---|---|---|
| `staging/fs_afladagbok/trip` | 323 trips | 196 departures and 210 returns gain their hid, 3 a pid |
| `staging/adb/trip` | every trip | `pid1`, `pid2`, `port` added |
| `curated/reference/port_code` | 104 → 113 codes | the nine codes added |
| `curated/logbook/trip` | 38,098 trips | port columns only (adb 37,862, fs_afladagbok 236) |
| `curated/link/trip_reconciled` | 3 trips | Borgarnes's second code, the trips' own port witness |
| `curated/check/voyage_sharing` | 3 rows | adb's arrival-port match, none before, now 0.73-0.94 |
| `products/v0/logbook/trip` | — | the same port columns as `trip_reconciled` (by column hash; rows not counted) |

- **No landing link moved.** `check/trip_landing` and `logbook/trip_disposition` give every landing and trip the same
  outcome and disposition as before.
- **Their kg differ only by float noise**, as do `check/landed_logged`, `aggregate/ices` and, against the store before
  the build, `logbook/catch_flag`. These are sums of doubles whose order changes from run to run: the largest
  relative difference is 4e-15. Every other column of these files is equal.
- **The trail, the voyages, the port calls and every other AIS file are unchanged** (467 files), so the effort
  map's grids need no rerun.

## What it leaves

- **The second scratch store**, `/Users/einarhj/stasi/scratch-196-before/`, waits for the maintainer's word to be
  deleted. The first, `scratch-196-ports`, was deleted at the maintainer's word before the rebuild.
- **Float noise in the store's kg sums** makes a rebuilt file's fingerprint change when nothing in it did. Fingerprints
  compare these files at the bit level, so a rebuild needs a row-by-row check against a tolerance to tell noise from a
  change. Not pursued.
