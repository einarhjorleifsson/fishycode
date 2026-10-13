# 082 — The Iceland/Faroe pids are pinned; a renamed harbour keeps its code

*2026-10-13. Code and measurements by Claude (AI-assisted), on the maintainer's answer to TODO 36 ("pin
them"). Closes TODO 36 and the first open question of decision 068.*

## What was chosen

- **Each of the 157 Iceland/Faroe harbours (source `einar`) carries a pinned `pid`**, in
  `overrides/port_pid_pinned.csv` (`pid_bootstrap, pid, port, pinned_date`). The key is `pid_bootstrap`, the
  bootstrap's own code. `curate/corrections/ports_iceland.R` never changes it and corrects only names, so it
  survives a rename. `port` is the name when pinned, for the reader only.
- **The values are today's.** The one file that has left the repo, `exports/wgsfd/IS_harbours_20261006.gpkg`,
  carries exactly these 157 codes (checked: same set, no duplicates). Pinning them changes no pid anywhere, so
  the frozen `once` outputs keyed on pid (the port radius) stay valid. IS-SEL stays Seltjarnarnes. It named
  Selvík, as the misnamed "Selfoss", until decision 068's rename on 2026-10-06, the day of that export. No
  file outside the repo carries the older meaning.
- **A pinned name is not minted.** `build_pid()` in `reference/ports/ports_all.R`:
  - reserves every pin before it hands out codes, so no other name can be given one;
  - gives a pinned row its pin whatever it is called;
  - lets another source's feature with the same (country, name) share the pin, as it would share a minted code.

  In the deduplication of clusters, a pinned cluster always keeps its code.
- **No UN/LOCODE after the fact.** Where a pinned harbour has a UN/LOCODE that its pid does not use (about 20 in
  Iceland: Ísafjörður is IS-ISJ, UN/LOCODE ISISA), the pid stays as pinned. Decision 068 found UN/LOCODE wrong too
  often to be a key. A pid that changed to follow it would be the move this decision exists to prevent.
- **A new harbour stops the build.** `ports_all.R` fails until it has a row in the pin file. A pid is assigned to
  it deliberately rather than minted unseen.

## Found on the way

The `port` target (`reference/ports/harbour_codes.R` → `curated/reference/port.parquet`) reads the pids from
`staging/ports/ports_all.gpkg`, but its only listed dependency was `ports_iceland`. It could therefore run before
`ports_all` and read the old file. `_targets.R` now lists `ports_all` there, and the pin file is a file target
that `ports_all` depends on.

## Measured (2026-10-13, `ports_all.R` run without its writes)

| run | pid | pid_src | cluster | canonical | unlocode |
|---|---|---|---|---|---|
| new code, today's inputs | 0 of 24,653 differ | 0 | 0 | 0 | 0 |
| new code, Grindavík → Grindavíkurhöfn and Selvík → Selvík á Skaga | 0 | 0 | 0 | 0 | 1 |
| old code, the same two renames | 3 (IS-GRI → IS-GRN: einar, gfw and gisco) | 1 | 0 | 0 | 1 |

The one `unlocode` difference is renamed Grindavík: its pid IS-GRI is still Grindavík's UN/LOCODE, but the flag
follows whether the *name* matches UN/LOCODE, and "Grindavíkurhöfn" does not. The flag can therefore change on a
rename, but the pid cannot.

## What remains

The other questions in decision 068 and `docs/ports.md` (class, radius, period, custody) are unchanged.
