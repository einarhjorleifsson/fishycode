# `docs/data-dict.yaml` introduced

*Decided and implemented 2026-09-25.*

## What this is

[`data-dict`](https://data-dict.tidyverse.org/) (the maintainer's own tool, in
`~/garbage/data-dict`) validates a YAML data dictionary against a spec and
against the real parquet it describes — column names, types, constraints,
relationships — and renders it as a page. `docs/data-dict.yaml` is a first
draft for every table in `curated/`, generated with `data-dict draft` against
the real files (one representative file per year-partitioned table:
`ais/ping`, `logbook/sensor_gps`) and hand-extended with a `relationships` and
`glossary` section. It passes `validate-spec` and `validate-meta` with zero
errors — the remaining 324 warnings are per-column `todo`s (mostly "add a
description"), which is what a draft is supposed to leave behind: real
per-column business descriptions are domain work for a human to do
incrementally, not something to fabricate here.

## What got checked while building it

Building the `relationships` section required knowing which join columns are
actually unique — the S06 spec rule requires a `primary_key`/`unique`
constraint on the "one" side of a `many-to-one`/`one-to-one` join, and
declaring one without checking would be asserting structure the data might
not have (`AGENTS.md`: "measure before claiming... every `x`"). Measured
2026-09-25:

| column | rows | distinct | |
|---|---|---|---|
| `vessel.vid` | 7,043 | 7,043 | clean — the only key this draft asserts |
| `logbook/trip.parquet` `.tid` | 1,820,387 | 1,813,822 | 6,565 duplicated |
| `logbook/station.parquet` `.sid` | 7,239,778 | 7,224,594 | 15,184 duplicated |
| `reference/gear.parquet` `gid` | 59 | 37 | duplicated |
| `reference/port.parquet` `pid` | 112 | 86, 21 missing | duplicated + missing |

Only `vessel.vid` is declared as a `primary_key` and used in a
`relationships` entry (`logbook_trip.vid = vessel.vid` etc. — four tables).
Every other join this draft knows to be real (`.tid` trip → station, `.sid`
station → fishing_sample/catch, `gid` → `reference_gear`, `pid` →
`reference_port`, the `trip_voyage`/`lid_map`/`catch_by_species_trip` links)
is written out as a comment above `relationships:` in `docs/data-dict.yaml`,
naming the script it comes from, rather than as a `relationships:` entry —
declaring one would assert a constraint the data does not currently satisfy.

**Not yet investigated**: whether the `.tid`/`.sid` duplication is a real
defect (worth a correction) or an artefact of a schema mixing two tiers that
should be deduplicated first — same open question for whether
`reference_gear`/`reference_port`'s real key is a composite
(`gid, something`) rather than `gid` alone. Flagging, not diagnosing.

## The three tables mid-rename — rebuilt 2026-09-25

`curate/decisions/028-join-key-naming-aligned.md` renamed columns in
`link_trip_voyage.R`, `catch_by_species_trip.R` and `aflagrunnur/convert.R`
the same day; this draft was first built before `tar_make()` picked the
renames up, so it briefly showed the pre-028 names (`voyage_year`/`voyage`,
bare `tid`/`tid_land`, `.sid`/`.stid`).

`tar_make(names = c("aflagrunnur", "trip_voyage", "catch_by_species_trip",
"lid_map", "check_ais_key_landings", "check_ais_key_reused_callsign"))` was
run the same day (`✔ ended pipeline [1m 59.3s, 6 completed, 22 skipped]`) —
`tar_outdated()` confirmed these were the only six targets affected, nothing
else in the graph was stale. The three tables were manually redrafted
against the rebuilt parquet (`data-dict draft` won't overwrite an existing
table entry, so this can't be a plain re-run) and now show `.tid`/`year`/
`trip` in `link_trip_voyage`, `.tid`/`.tid_land` in
`logbook_catch_by_species_trip`, and bare `sid`/`stid` in `landing_catch`,
confirmed against the real files with `data-dict describe`.
`validate-spec`/`validate-meta` both still pass clean.

One pre-existing warning surfaced during the rebuild, unrelated to this
change: `lid_map` — "Detected an unexpected many-to-many relationship" from
`dplyr::left_join()` — which is the same `.tid` duplication measured above
(6,565 dupes), not a regression from the renames.

## Not done

- No `validate-data` pass (checks values, not just names/types — the natural
  next step once more `constraints`/`examples` are filled in).
- No render (`render-spec`) published anywhere yet.
- Every table's `description` (grain + population) is still a `todo` except
  `vessel`, which got a one-line placeholder.
