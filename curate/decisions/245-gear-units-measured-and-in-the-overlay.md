# 245 — Plan 052 step 1's remainder: the gillnet's length is metres, the dredge's size and large door areas stay raw, the units in the overlay

*2026-10-30. Measured, coded and written by Claude (AI) in a side session at the maintainer's request ("take plan 052
step 1's remainder here now: overlay units, ICES code-list columns, gillnet and dredge units, door areas above
40 m²"); no person has checked the code or the numbers. The choice on the ICES columns is the maintainer's (below).
Every count is from the dumps of 2026-10-16 and the store built on 2026-10-29 (decision 244), read-only; the scripts
are in `$FISHYDATA/archive/2026-10-30-gear-units/`.*

## The gillnet's mean length is metres

`medal_lengd_neta` (afli's `lineha` and `rafr_lineha`, fs_afladagbok's `ws_linanethandf`) and adb's
`line_and_net.net_length` had no established unit (decision 210 item 2). No source states one: the apps' schema
documents the element without a unit, fs's comment has empty unit brackets, adb's says metres but its values are fs's.

- **The values.** 11,251 kept stations hold one, almost all set gillnets (GNS): afli 10,746 (18 vessels, 2008-2014),
  fs_afladagbok 441, adb 64. The commonest are 54, 58, 50 and 55; half nets of 27-31; median 54 (afli) to 59 (adb).
- **A document.** The regulation on cod gillnets (115/2006, art. 6) caps the nets a vessel may have in the sea and
  counts a net as 60 fathoms of netting: "Miðað er við að 60 faðma löng slanga sé í hverju neti". Hung on its ropes at
  about half its stretched length, the usual hanging of a gillnet (assumed, not measured), that is a net of some 30
  fathoms, 55 m. Read as fathoms, the logged nets would hang twice the netting the regulation counts.
- **A physical witness, the track.** On 8,083 afli stations with AIS fixes in the haul phase, the displacement from
  the first to the last fix over nets x length (metres) is 0.5-1.2 on 4,252 and below 0.5 on 1,187; its median is
  0.89. Fathoms would put it near 1.8 (less the ends the fixes miss). The set phase gives no reading: its windows hold
  steaming (median 2.95), the set times being the time issue of TODO 164. The logbook's own start and end positions
  give none either: whole minutes, 1-2 km, the length of a fleet.

So the map reads it as metres in all three sources, basis `reconstructed` (the unit read from the values, plan 052
ask g), plausible 20 to 110 m (110 m being the regulation's 60 fathoms of netting). 11,251 rows of `gear_part` gain
`length_m`; 183 are flagged implausible and kept (fs's 136 ones, 22 thirteens, two 250s and a 5; afli's 19 of 1-17;
adb's two 5s and a 150).

## Door areas above 40 m² are not square feet; they stay flagged

afli's `fermetrar` is square metres by the schema (`HLERAR@FERMETRAR`, "Flatarmál hlera í fermetrum"). 12,264 rows of
the edited `toga` and 11,149 of `rafr_toga` hold more than 40, on 27 vessels. They are not square metres: so read, the
doors weigh a median 44 kg per m², against 420 for the same vessels' other doors. Every edited row above 40, in one
outcome, against the same vessel's areas of 40 or less at the same door weight:

| outcome | rows | vessels |
|---|---:|---:|
| the same door's area with the decimal point lost (105 for 10.5, 85 for 8.5) | 2,649 | 7 |
| a hundredth (the decimal point two places off) | 1 | 1 |
| square feet of the same door (x 10.764) | 0 | 0 |
| another number at a door weight the vessel also logs an area for (160 at 700 kg, where its area is 2.3) | 9,119 | 13 |
| at a door weight the vessel logs no area for | 435 | 8 |
| the sentinel 999 | 57 | 1 |
| no door weight | 3 | 1 |

The ft² test and the lost-decimal test have the same tolerance (0.05 m²). In a looser test, by distinct value
without the weight, 3 of the 30 high values are a ft² reading of one of the vessel's areas, as many as a factor of 9 or
12 gives by chance (2 and 1). So the "square feet?" of plan 052 is answered no. The values stay as recorded, flagged
`implausible` with no use in a sum (AGENTS.md: an extreme value is flagged, not corrected), as decision 244 left them.
The lost decimals are not corrected either. The dictionary now carries the defect as an assert expected false on
those rows.

## The dredge's size stays raw

The schema documents `PLOG_STAERD`'s width, height and length in feet ("Breidd plógs í fetum"), and fs_afladagbok's
comments say feet; adb's values are fs's. afli's edited layer holds 49,080 widths (1972-2021; `rafr_toga` 5, and the
map's note that both layers were empty was wrong, now corrected), 44,292 lengths and 2,515 heights.

- **Scallop dredges, 86 % of afli's values** (Iceland scallop the main catch on 42,193 of the 48,986 stations with
  a width, 190 vessels): 8 x 8 x 2
  at the median, 5-9 wide. In feet a dredge 2.4 m wide, 2.4 m long and 0.6 m high; in metres a frame 8 m long and
  2 m high. Feet.
- **Sea urchin and sea cucumber dredges of 2003 on** (3,287 stations, 15 vessels): 2-4 wide, 2.5-4 long, 1 high. In
  feet 0.6-1.2 m wide; in metres a plausible frame. fs_afladagbok's one sea urchin vessel logs 2.5 x 3.6 x 0.2: 0.2 ft
  would be 6 cm. Metres, it seems. Its one ocean quahog vessel logs 3 x 3 x 3, adb's app default (decision 170).
- **No switch in time.** The six vessels that dredged the same species before and after 2003 kept their numbers or
  near them (9 and 9, 16 and 16, 6 and 6, 10 and 10, 9 and 12, 8 and 10), none by a factor of 3.28.

So the unit is feet on some records and probably metres on others, and nothing on the row says which. The map keeps
them raw (`unit_raw` "unknown", no metres). A rule by the station's species (scallop dredges in feet) would give 86 %
of afli's values metres; it is not made, since a gear table reads no catch (plan 052 §5), and it is left in TODO 163.
adb's overlay had stated feet for `dredge.width` (decision 170); it now says the unit is not established.

## The ICES vocabularies: the matches recorded, no columns

Plan 052 §1 found that ICES has vocabularies for gear exceptions, door types and rigging and fishycode states none, and
step 6 has ICES's codes become columns of the code lists where they match. ICES's vocabulary service
(vocab.ices.dk, read 2026-10-30) was searched for each of the 14 code lists. Five have a match:

| code list | ICES vocabulary | match |
|---|---|---|
| `footrope` | `TS_GearEx` (DATRAS gear exceptions) | rockhopper R; steel and rubber bobbins B (ICES's code the broader); rope, chain, discs none |
| `grid` | `IC_SelectivityDevice` (InterCatch) | each grid GRID (broader), no grid NOSD |
| `bottom_type` | `SUBST` (bottom substrate) | sand SD, gravel (möl/grús) GR, bedrock and lava (klöpp, hraun) RK, rocks (klettar) RK or BD, cobbles (hnullungar) ST, soft (mjúkur) SS, clay or mud (leir/drull) CL or SS; kelp, coral, sponge, snags and fauna none |
| `rig` | `GearType` (métier level 4) | twin and triple OTT for an otter trawl only; single none (the gear's own code) |
| `bait` | `SpecASFIS` | 51 of 67 codes are species codes with an ASFIS code in `reference/species` (`fao_3a`); the bait products (10000-10007) and three sand eels none |

None for `sea_state` (ICES's `SwellHeight` is a swell in bands of 0, 0-1, 1-2, 2-3 and 3+ m, afli's list the Douglas
scale of the wind sea), `hook_type`, `codend_type` (ICES's `CodendType` is main or collecting bag), `dredge_type`,
`trap_type`, `seine_type`, `sounder`, `mesh_orientation` (`MeshType` is the netting's material) or `yes_no`.
`sensor_summary`'s wind force is on ICES's `Beaufort` scale as it stands.

Asked whether to add the columns (AskUserQuestion; Claude's recommendation first, with the reason that nothing reads
them: the VMS datacall needs the gear at level 4, which the delivery maps from `metier6`), the maintainer chose
"Record only": the matches are kept here, and the columns come when something reads them.

## The units in the overlay

Every gear, rigging and per-haul sensor column the map reads is now in the dump's overlay (plan 040), with its label,
type and unit, where it is read into, its plausible range and the evidence: `dump/oracle/meta/afli.yml` (`stofn`'s
wind; `rafr_toga`, `toga`, `rafr_lineha`, `lineha`, `rafr_hringn`, `hringn`, `gildra`), `fs_afladagbok.yml`
(`ws_veidi`'s material; `ws_dragnot_varpa`, `ws_plogur`, `ws_linanethandf`, `ws_gildra`, `ws_hringn`, `ws_kofun`) and
`adb.yml` (`fishing_station`'s material; `trawl_and_seine_net`, `dredge`, `line_and_net`, `trap`,
`surrounding_net`, `diving`). The entries were generated from the map and checked by eye on a sample; adb's hand
entries for the headline, bridle and rope were kept. fs_afli's copies have no overlay yet (plan 038).

A unit is now stated twice, in the overlay and in the map that applies it. Each table's details say a change goes to
both. Only the map's unit is applied, so a disagreement would not change the data, only mislead a reader of the
dictionary.

New asserts: the door area (expected false on 12,264 and 11,149 rows) and a scale check of the gillnet's length in all
four tables (the mean between 20 and 110 is 53.3-61.7: pass). The columns whose unit is not established carry a `todo`
(14, the dredge's sizes and afli's `beitufrakast`).

Rewritten in a scratch copy of each dump folder, the three dictionaries pass `validate-spec` with no error; the
warnings rose by exactly those 14 `todo`s (adb 27 to 30, fs_afladagbok 16 to 19, afli 38 to 46), and every assert
passes or fails on exactly its expected count.

## Checks

The map and the part tables rebuilt in a scratch store (the method of decision 244) against the live store:
`rigging_part`, `sensor_summary` and `check_logbook_part_station` identical; `gear_part` differs on exactly the
11,251 net rows with a length (the metres, `unit_raw` m, basis `reconstructed`, 183 flags) and nothing else in them;
`check_logbook_part_column` on the four net-length columns. `docs/data-dict.yaml` validates as before (its 10 errors
and 261 warnings are HEAD's).

## The live build

*Pending at this commit.*

## What is left (TODO 163)

- `effort_count` read from `rigging_part`, then `g_*` out (decision 244), and `vessel_sensor` with asks d and e:
  the mother session's, with plan 053.
- §2's unexplained headline and sweep records listed vessel by vessel (plan 052 step 1, not asked for here).
- The dredge's unit per record, if a rule by species is wanted.
