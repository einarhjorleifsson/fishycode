# 244 — The logbook's gear, rigging and per-haul sensor tables built (plan 052), independent of the set times

*2026-10-29. Built, measured and written by Claude (AI) in a side session at the maintainer's request; no person has
checked the code or the numbers. The asks were answered by the maintainer (plan 052 §7). Every number below is from
the build in a scratch store (`$FISHYDATA` linked read-only, outputs real files; the live store untouched, checked with
`find -newer`), and the live build of the same commit is compared with it at the end.*

## What was asked

The maintainer, 2026-10-29: get plan 052's curated tables done, "independent of the time issue" (the e-logbook's set
times and windows, TODO 164, plan 053). Plan 052's asks a-h were put first (AskUserQuestion, the plan's
recommendation first). Every one was answered as proposed: the line between gear and rigging as §1 draws it (a), two
tables of one shape (b), `sensor_summary` long with `environment` a pivot made for the user tables (c), placeholders
kept raw with no SI value (f), the undocumented columns used as read with basis `reconstructed` (g), and
`curated/vessel_sensor/` as the home of the vessel's streams (h). Asks d and e (the logger's positions in the AIS
union, its readings dated 1899) touch time, so they were deferred, and with them `vessel_sensor`.

## What was built

Three tables in `curated/logbook/`, keyed on (`.sid`, `schema`) for the stations the merge keeps, duplicate twins left
out (decision 094); no time in them, and none read:

| table | rows | stations with rows |
|---|---:|---:|
| `gear_part`: the netting and what is fixed to it, one row per station and part, one column per measure in SI | 15,678,761 | 5,772,723 |
| `rigging_part`: the rig, the units and their count, hooks in all, doors, sweeps, upper bridles, ropes, wires | 13,626,199 | 6,913,790 |
| `sensor_summary`: one row per station and reading (quantity, place, moment, mount, instrument), afli only | 17,569,309 | 5,228,806 |

The targets (`_targets.R`): `gear_part_map` (`reference/gear/part_map.R`: every source column in one row, with its
part and measure or the reason it is not used, its unit and factor to SI, the gears it applies to, its plausible
range and code list; and the code lists, labels as the sources hold them), `afli_part`, `fs_afladagbok_part`,
`adb_part` (`sources/*/part.R`, preprocessing; `staging/<schema>/{gear_part,rigging_part,sensor_summary,
part_column}.parquet`), and `logbook_part` (`curate/logbook_part.R`, downstream of the merge; with the accounts
`curated/check/logbook_part_station.parquet` and `logbook_part_column.parquet`). The reading is shared,
`R/logbook_part.R`: each layer's columns read long, each value given one outcome and its SI value in one SQL pass, the
best layer kept per measure, then pivoted. Nothing else reads the tables; `fishing_sample` and its `g_*` stay as they
are for one release (decision 210 item 3).

### Coverage by source and period (kept stations, duplicates out)

| source and period | stations | `gear_part` | `rigging_part` | `sensor_summary` |
|---|---:|---:|---:|---:|
| afli to 2002 (paper; the edited layer) | 4,185,535 | 72.1 % | 92.6 % | 63.8 % (wind, mostly) |
| afli 2003-2019 (`rafr_`, afli's copy) | 2,423,275 | 87.4 % | 98.1 % | 96.2 % |
| afli 2020-2023 (the afli route: `rafr_`, fs_afli's copy) | 230,119 | 91.5 % | 99.1 % | 98.1 % |
| fs_afladagbok 2020-2025 | 370,984 | 91.4 % | 92.8 % | none recorded |
| adb from 2025-11-19 | 88,200 | 100 % | 99.4 % | none recorded |
| aflaskeyti (foreign vessels, ERS) | 3,058 | none recorded | none recorded | none recorded |

What fs_afladagbok and adb fill: the codend mesh and orientation, the headline (feet), the grid (as text), the
square window, the doors' weight, the sweeps and the Danish seine's rope (fathoms), the twin count, the nets, hooks,
jigs and traps, the gillnet's mesh and height, the purse seine, the dredge's type, mesh and count (its size kept raw),
the trap's type, and the gear's material as typed (343,244 fs operations). No temperature, no wind, no sea state: the
21 of `rafr_`'s 55 filled columns plan 052 §2 counted. adb's gear values equal fs's field for field on every shared
station (217,569 trawl, 124,737 line and net, 4,578 dredge, 1,276 purse seine stations), but adb writes 0 where fs
holds none (net mesh, square window: read as empty) and lost the dredge's weight.

## How each value is chosen (the cascade)

afli's layers (plan 052 §5, plan 037): what the apps sent, where the loader lost or changed it (from
`staging/afli_sent`: hook type and size, hand-baiting, hooks per jig line, the dredge's size, the bottom; and the
headline depth, read from the message itself), always first; the loaded `rafr_` tables, afli's copy and then
fs_afli's for the records afli's lacks (2020-07 to 2023: 134,276 towing rows, the afli route's detail, which
fs_afladagbok thinned); the edited tables, afli's and then fs_afli's paper stations. Between the loaded and the edited
layer the maintainer's rule decides (below). Per measure the best layer holding a value answers; `layer` names every
table a row's values came from.

**Gear rows left behind by a correction** (the maintainer's hypothesis, 2026-10-29: when a station's gear was
corrected, the row in the old gear's table may not have been deleted). Confirmed in kind: no station is in two of
`rafr_`'s gear tables, 220 are in two of the edited layer's (e.g. 24 e-logbook hauls loaded as pelagic trawl now purse
seine, with a new purse-seine row and the old towing row kept; 18 loaded as bottom trawl now handline). fs_afladagbok
and adb have none. Rule, for every source: a gear table describes some gears (towing: OTB, OTM, SDN, DRB; lines and
nets: LLS, GNS, GND, LHM; purse seine; traps; adb's and fs's likewise), and a row of a station whose gear, as the
merge has it, is another is counted `other_gear_table` and not carried: 16,662 afli values, 66,456 adb (its dredge
table holds rows for 96,650 stations, 7,260 of them dredges), 5 fs. The same rule leaves out the trawl form 13,482
bottom-trawl records were loaded on before the edit recoded them as dredges (9,631 ocean quahog, 3,657 scallop, 194
sea urchin): their trawl values are not the dredge's.

**What a value is.** A 0 in a gear or rigging measure is a form's empty field: no value, counted (`empty`). In
`sensor_summary` a placeholder keeps `value_raw` with no `value` (ask f): a temperature of 0.0, a headline depth of 0 or
1, a sea state or wind speed of -1, and a wind direction of 0 with no wind (speed 0, -1 or none, and force 0 or none;
on paper 0 goes with Beaufort 0 on 314,692 of 343,260 stations): 533,107 directions. A value outside its plausible
range is kept and flagged `implausible` (AGENTS.md); the bounds are physical and wide, set where the tails show the
apps' 1s and the sentinels 9999, -99, 990 (sea water -3 to 25 °C, air -40 to 35, wind to 40 m/s, door weight 20 to
9,000 kg). A code in no list is `unknown_code` (afli's grids 1 and 2, its mesh orientations 1, 3, 6, 50, 80).

## What the building found, and the choices made

- **The headline depth's unit, record by record.** `rafr_toga.hoflinu_dypi` has no unit of its own: of the sent
  `HOFLINU_DYPI_M` (metres), the loader stored 22,572 as fathoms and 21,310 as sent, not cleanly by app version
  (2.6.20: 944 one way, 237 the other). The schema documents `HOFLINU_DYPI` as fathoms and `HOFLINU_DYPI_M` as metres
  from version 30. So the depth is read from the message the sent layer staged (`.xid`), per record: metres or
  fathoms by the element. 822 sent depths the loader lost come back. Where no message holds it, the loaded value is
  kept raw with no metres (`unit_raw` "fathom or m, by record").
- **Water depth has one home**, the station's `z1`, `z2`: `sensor_summary` holds none. TODO 113's defect (afli's `z2`
  1.83 times the sent metres on 946,197 stations) is the station's to fix, not to copy.
- **fs_afladagbok's `moskvi_fj_ummali`** is the codend's meshes around (median 150, as afli's codend's 200), not the
  shrimp trawl net's (afli's `staerd`, 2,250), whatever its comment says.
- **fs's and adb's hooks on jigs** are per jig line on some records and in all on others, mixed within every app
  (Trackwell raun: 20,213 equal to the jigs, 15,009 a multiple): kept as `hook_total` flagged `per_jig_or_total`.
- **fs's Danish seine `grandarar`** (11-14 fathoms on 57,619 hauls) join the wings to the ropes as sweeps do on a
  trawl: read as sweeps on every towed net.
- **The tour app** (`fishing_spot`) is not read: its ids coincide with `ws_veidi`'s by number on 29,195 rows, none in
  the same trip or at the same time, and its stations are not in the merge (plan 019).
- **afli's square-mesh codend (`leggpoki`)** is not a copy of the window (`legggluggi`): they differ on 59,412 tows.
- **Kept raw, no metres** (decision 210 item 2, unit not measured): a gillnet's mean length (afli, fs, adb; adb's
  comment says metres, its values are fs's) and a dredge's size (fs's comment says feet; one vessel's constants
  3 x 3 x 3 and 2.5 x 3.6 x 0.2). fs's dredge weight of 10 kg (3,980 hauls) is flagged implausible.

## Where the edit changed a value `rafr_` holds: the expert's edits answer

The first build took `rafr_` before the edit, as plan 052 §5 has it, and counted the edit's changes: the twin flag
(3,295 tows loaded 1 and edited 0, 49 the other way), the Danish seine rope 6,701, the headline 4,044, the door weight
3,243, the codend mesh 3,151 + 2,064, the gillnet mesh 2,131, the sweeps 1,863, the tubs 487 and hooks per tub 455, and
the square window. Some looked like corrections (a gillnet set loaded with 230 nets, edited 30), some not (longline tubs
loaded with 450 hooks, edited 20).

The maintainer, 2026-10-29, on that order: "think we may need to revert that, manual edits at least done <= 2018 are
[the expert's account] - i trust him". Who changed what was then measured by plan 037's method: the domain expert's account read
from `FISHYDATA_EXPERT_ACCOUNT` in the git-ignored `.Renviron`, passed to DuckDB as a parameter and never printed or
written, against the last changer of the station's `rafr_stofn` row (afli keeps no editor, so a lower bound). Counted
per column, the disagreements on records to 2018 lie on stations the expert last changed (twin flag 1,454, headline
2,176, codend mesh 2,175) and on others' (1,893, 1,776, and the rope's 6,570). On records of 2019 on, the afli route's
import, almost all are other accounts', dominated by the square window and square-mesh codend set to fitted on 94,635
tows the apps sent without one (fs_afladagbok, the same e-logbook, holds the field on 105 operations): an import's
mapping, not an edit. 648,245 stations of records to 2018 and 3,590 of 2019 were last changed by the expert's account.

**The rule** (`sources/afli/part.R`): the edited layer answers before `rafr_` on every record to 2018 and on every
station the expert's account last changed (1,014,398 stations), `rafr_` before the edit elsewhere (the import of 2019
on). The sent layer and the message stay first, for what the loader lost or changed. Where the edit emptied a value,
`rafr_` still fills it (the Danish seine's surface temperature and tow time, plan 052 §2). The `rafr_` values lost to
an edit are counted in `part_column` (`n_lost_differs` on the `rafr_` layers: rope 6,700, codend mesh 4,141 + 3,068,
headline 3,910, door weight 3,214, gillnet mesh 2,131, sweeps 1,834), and the edit's square windows lost to `rafr_`,
94,684. The rule was relayed to the plan-053 session: the afli route's edited values, set times included, are an
import's, and the expert's corrections are labels a rule can be scored against (plan 037 §1).

## Checks

- **Every kept station in one outcome per table** (`check_logbook_part_station`), and every source column of every
  layer (`check_logbook_part_column`): afli 488 columns over its 19 layer tables (202 read, the rest listed with their
  reason), fs 48 (32 read), adb 48 (28 read); every afli value read (71.6 M) in one outcome.
- **`effort_count` read from `rigging_part`** (a towed gear's rig, a longline's hooks in all, the nets, jigs and
  traps) equals `fishing_sample`'s on every fs_afladagbok and adb station, and on afli's but 51, each explained: 44
  records of 2019 on where `rafr_` answers by the rule and the edited layer, which today's count reads, changed or lacks
  the value (33 twin flags fs_afli's copy holds, 6 twin remarks, 5 longlines); 5 records to 2018 where the edit emptied
  a value `rafr_` fills (a twin flag, a dredge's, 2 longlines', a jig count); and 2 jig counts of -1 on paper records,
  flagged, which today's count leaves out. With `rafr_` first everywhere they were 3,976. A towed gear or seine with no
  count recorded is `synthesised, no rigging count` (fishing_sample's one gear).
- **Against plan 052 §2** (afli's `rafr_` stations, eytt 0): stations holding a temperature or headline depth
  538,306 (§3: 537,584; the 822 depths from the messages, the edit's values, and the ranges -3 to 25 °C against -2.5 to
  20); a fitted flag only 263,153 (263,827); readings by place within 1.1 % of the study's (e.g. bottom at the start
  399,116 against 399,063). fs's operations with a part 349,857 (349,868). Bottom trawl's headline, doors, sweeps 97.5-97.6 % against
  100 %: the 13,482 recoded as dredges.
- `docs/data-dict.yaml`'s seven new entries pass `data-dict validate-spec`, `validate-meta` and `validate-data`.

## What is left (TODO 163)

- `vessel_sensor` and asks d and e, after the set times (TODO 164, plan 053).
- `effort_count` read from `rigging_part` (51 afli stations would move, above), and the `g_*` columns out a release
  later (decision 210 item 3).
- Plan 052 step 1's remainder: the units in the metadata overlay (`dump/oracle/meta/`; for now the map is their one
  record), the ICES vocabularies as columns of the code lists, the gillnet's length and the dredge's size measured,
  §2's unexplained headline and sweep records listed by vessel. Door areas above 40 m² (12,736 tows) may be square
  feet: unchecked.
- The remaining sent elements (plan 037 phase 2): doors, sweeps, codend, grid and the sensors as sent.
