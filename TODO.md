# TODO

Open work items. One line of provenance each, and a **check** that decides when the
item is closed — so this file can be audited against the code rather than believed.

Not a diary. Why a thing is the way it is goes in `curate/decisions/`. Data defects
with a detection rule and a repair go in `curate/corrections/*.yml`. This file is
only for work that is *not done yet*.

**An item is a stub, not an essay — 35 lines at most, enforced.** It says what is open,
points at the record that holds the evidence, and states its check. When an item wants
sections, tables and its own numbers it is a plan or a correction, and what stays here
is the pointer. This file reached 871 lines by ignoring that; the cure was mechanical —
four "Resume note" sections were 211 of them, and seven items were restating a plan or a
correction that already said it better. Session state belongs in the git log, which is
where "what happened when" is recorded.

Status: `open` · `blocked` · `parked` · `in progress` · `done` (delete when done and
recorded elsewhere)

`parked` is a deliberate stop, not an obstacle: the work could proceed and a decision
was taken that it should not. `blocked` means something outside the item is in the way.
Conflating them hides which ones a session could actually pick up.

An item that cannot move without the maintainer — a decision, an account, a
credential, anything outside this repo — also carries **`needs: maintainer`**, and says
in one line what is being asked. Without that marker a session either stalls on it or
does it twice.

---

## 15. `fishydata`'s backup: the essentials to MFRI, where IT says
**status:** blocked · **needs: maintainer** — a talk with MFRI's IT about where the copy goes · **see:**
`curate/plans/001-three-repo-publication-boundary.md` §5, decision 187

The rest of plan 001 is answered (decisions 118, 187; plan 033 ask c). The maintainer, 2026-10-23: the store stays on
this laptop for now, and its backup will be the essentials copied to MFRI: `raw/`, `archive/`, the `once` outputs and
`exports/`, about 230 GB of 552 (`staging/` and `curated/` rebuild from them). Until IT names the place nothing backs
it up; the Mac has no Time Machine destination. The home is revisited when free disk falls below about 50 GB (112 GB
on 2026-10-23). Decision 018's layout is kept and documented (`docs/pipeline.qmd`).

**check:** the essentials are copied on a schedule to the place IT names, the first copy is verified file by file,
and plan 001 §5 says where.

---

## 24. Icelandic vessels that land fish but are never heard on AIS
**status:** open · **see:** decisions 110, 117 and 118, `curate/checks/ais_key_landings.R`

`ais_key_landings`' `landed_but_no_ais` lists 308 vids (the `once` file of 2026-10-09). It audits the cascade, not
the key (decision 053), so 53 of them are in the key and heard, and 148 are foreign. **107 Icelandic vids landed in
the AIS era with no key row and no ping from any provider in the union:** 96 registered vessels (9 with an MMSI, 67
landing in 2013 or later) and 11 landings placeholders. A vessel name is never used to
match, and the MMSI route is already taken, since the union takes ASTD, astdB and EMODnet by MMSI. What is left is to
say why each has no track: no transponder (a small boat), an STK unit the key leaves without a vid (plan 022 §3;
decision 161's units name 32 of these vids by an identifier), or a missed match.

**The divers (from TODO 67):** 8009 (the register's útgerðarflokkur "Kafarar") and very likely 8008 land only with gear
23 "Kafari", about 14 t on 152 landing rows, and have no hull. Mark them as divers, through an override that names the
two or a rule (a registration that lands only with gear 23).

**check:** each of the 107 has a stated reason in a check table or an override: no AIS expected, an STK unit or MMSI
found, or a match missed; and 8008 and 8009 carry a diver class and `landed_but_no_ais` leaves them out.

---

## 25. The next STK key redo (`once` project): the review lists
**status:** open · **needs: maintainer** — the go for the redo's build, once its code is in (review done 2026-10-23) ·
**see:** decisions 128 and 195; plans 009, 016 §4 step 7, 021 step 7, 022 §3 and §7; decisions 047 and 075;
`$FISHYDATA/archive/2026-10-23-key-redo-refresh/`

Lists 1-5 of the drafts of 2026-10-17 (the audit's discrepancies and `ais_key_resolution`'s proposals, the 32 fills
outside a neighbour's lifetime, vid 7570's MMSI, the MMSIs passed to another hull, plan 022 §3's co-location units,
register rows, `mobile_vid` claims and port codes) were refreshed and reviewed by the maintainer on 2026-10-23, each
case checked in the vessel overview (`verdicts_2026-10-23.csv`, decision 195): 18 reviewed rows are in
`overrides/ais_key_segments_reviewed.csv`; 23 proposals the hull-start rule gives by itself; 5 settled by today's
table; 3 "no vessel" (mids 101776, 147514, 147796) and a device aboard 1421, then 3011 (mid 124288) wait for forms.

The redo's code, approved 2026-10-23 (decision 195), in `ais_key_segments.R` and the `once` readers:
- a "no vessel" form in the reviewed table, and a device form with its carrier (decision 053);
- a reviewed row brings its mid into scope (mids 130145, 133483, 145250); one that changes nothing is reported;
- a hull starts at its earliest `vessel_hist` date (variant a1), not the latest row's re-registration;
- **from TODO 82:** a later holder's MMSI window opens no earlier than its first register date, the previous holder
  keeping the gap (patch in `$FISHYDATA/archive/2026-10-17-mmsi-window/`: MMSI 251764110's 87,372 pings of
  2017-02..2018-01 go from 7873 to 2608); later holders 3009 and 7764 are in neither `vessel_hist_v` nor `vessel.parquet`;
- the register's matrix parse fixed in data (`skipaskra` invalidated by hand; 6,891 pings on 3 mids change vid); its
  call signs and `yh2` NA (decisions 136, 142, 144); W2's logbook positions, W3's own hid → pid crosswalk (decision 047);
- **from TODO 120** (decision 185): `ais_key_segments.R`, `skipaskra_evidence.R`, `skipaskra_discrepancy.R` read tables;
- vids 7845, 2953 and 7855 need vessel rows (only the MMSI archive knows them).

`once`'s `tar_outdated()` lists the key since decision 129: the cycle, not a reason to build. Later redos: the 1,051
audit rows no witness reaches, today's audit's 85 new rows, plan 031 §3.11's contradicted records (1,006 landings,
1,482 trip ends), the foreign hulls with mids 101843, 147141, 102481, 102527 and routes M1/M2 (after plan 021 step 6),
the STK units with no vid (decision 161, TODO 116). **Fix by fix** against the MMSI feeds (2026-10-23, Claude's, not
checked; `$FISHYDATA/archive/2026-10-stk-key-crosscheck/` §6): 213 cases, 16 settled. For this redo: mids 100137 (1136
to about 2013-11-13), 101084 (off 2212 in 2022-09/10), 101780, 108629; later: other feeds at one place, two MMSIs.

**check:** a decision record states the redo; every row of lists 1-5 resolved through `overrides/` or a stated reason;
`ais_key_coverage` at 0 unassigned pings; no `once` script reads a view; no MMSI window opens before its hull's first
register date, MMSI 251764110's gap pings on 2608, and 3009 and 7764 resolved or stated; **proposed:** that cross-check
rerun after each redo, every same-track or partial case settled or stated.

## 27b. Link pings to trips and fishing activity (the `trail`), and deliver from it
**status:** in progress - phases 0-3 built; the trail rebuilt 2026-10-16 (decision 112) · **needs: maintainer** —
plan 015 §4 a-d and i, held for a metier study (e-h answered, decision 202) · **see:** `curate/plans/015-datacall-on-the-curated-trail.md` (the datacall), `curate/plans/010-ping-activity-link.md` §7, §10-§12b, decisions 095 and 118

Built: `gear_window`, `station_window`, `curated/ais/trail` (AIS + the gps logger feed, plan 014), with the voyage's
trip (`.tid_voyage`) on fixes outside every window. Open: the datacall. `products/ices_vms_datacall/build.R` is the
2025 delivery script with only its paths changed, and it cannot run here (checked 2026-10-14). It reads columns the
current `ping_union` does not have (`.sid`, `s1`/`s2`, `t1`/`t2`, `met6`, `dt`, `dd`, habitat, depth, catch per fix),
a `station-for-ais.parquet` nothing here builds, and `agf_gid`/`met6` that `gear.parquet` lacks.
Repointing it means building its inputs from the curated tables. Built since 2026-10-14: the trail's `fishing`
(decision 093), `hours` and `kw_hours` on each fix (decision 101), and catch per fix in `curated/ais/catch` (decisions
101-102). Not built: metier 6 from the mesh size (the trail's `metier` column is there, its level not checked; `rdbes.metier`,
the allowed metiers by area and mesh range, is dumped next, decision 121), swept
area from distance and gear width, habitat and depth by spatial join, and the logbook (LE) table without duplicate twins.

Plan 015 designs it, checked against the 2025 delivery. Also open: whether to store a sorted wide trail (maintainer).

**The old trail stays until then (from TODO 8):** `~/stasi/fishydata_2024-2026/data/ais/trail` (31 GB) is the input of
the 2025 delivery (`ices-datacall/2025/2025_vms-datacall.R` reads it), and the delivered CSVs are not kept locally. It
reproduces that delivery and is the baseline for the comparison. Removed and restored on 2026-10-14 (decision 095).

**check:** `products/ices_vms_datacall/build.R` runs on `curated/ais/trail`, its output is compared with the 2025
delivery and supersedes it, every synthesised window carries `win_basis`, and no directory under
`~/stasi/fishydata_2024-2026` exceeds 1 GB.

## 34. Trawl speed ranges near the coast: ask (1) of plan 012
**status:** blocked (the regulation and shoreline shapefiles, coming) · **see:** `curate/plans/012-speed-range-vs-logbook-window.md` (§2e-§2k), `curate/corrections/logger_speed_placeholder.yml`, decisions 085, 093 and 201

Measured: the declared speed range per trawl gear keeps 88-92 % of fixes in recorded tow windows; kW, length and age explain under 5 % of towing speed; a vessel's own range gains nothing over the gear's; shifting the gear range by last year's vessel offset gains 0.2-1 point overall and 4-12 points for the tenth of vessel-years with a large offset; the logbook gear agrees with the landings for 93-99 % of trips. Built from the plan: step 0 (the logger placeholder fix) and step 4 (the gear codes on the trail, decision 085); steps 1-2 were not taken up (decision 093).

**Asked of the maintainer:** (1) whether fish-trawl tows of small vessels near the coast are permitted, so a flag can say "suspect" or "expected", and where a baseline or fjord polygon can come from (5 km from the coast is a stand-in). The same baseline serves the plan's step 5, the 12-mile limit. **Answered:** (2) the declared ranges stay, and `fishing` tests the ±10 min median speed instead of a vessel-shifted range (decision 093); (3) the gear codes on the trail (decision 085).

`uv`'s regulation areas (decisions 121 and 122) may hold the trawl limits; not checked. Also for the ranges (decision
198): the declared gillnet range starts at 0 kn, so any stopped gillnetter on a gillnet voyage passes the voyage rule.

The last haul is answered by plan 012 §2d and §2k (no unclosed last haul seen; the end looks late on some last tows, not early), and the plan's step 3 is marked not taken up (2026-10-23, Claude's audit, not checked by a person).

**Answered 2026-10-23 (decision 201):** coastal trawling is permitted in places by regulation; tows are judged
`expected` or `suspect` against `uv`'s dated regulation areas for their gear, measured first (what `uv` holds for bottom
trawl, a dated layer, the tows scored), the layer also serving step 5; the gillnet floor is set from recorded hauls.
Amended the same day: the layer waits for the proper regulation and shoreline shapefiles the maintainer says are coming
(`uv`'s dated areas perhaps as their history); the gillnet floor is measured now.

**check:** the layer built from the shapefiles and the tows flagged against it; the gillnet floor set from recorded hauls.

---

## 49. AIS as a qualifier where the logbook or the landings are missing
**status:** open · **see:** plan 014 §1, decisions 103 and 200, TODO 86

Preprocessing reads no AIS (decision 075), but some AIS tracks may be truly fishing with no logbook or even landing
behind them. Since 2017, 50,329 of fishing vessels' 509,230 voyages have neither (4.1 M hours), and every voyage of the
vessels that land nothing (whale watching 76,802, aquaculture service 52,111, other 78,587); today such a voyage's fixes
come out not fishing with no reason. Decided 2026-10-23 (decision 200): a fishing vessel's voyage with no record is
undecided (fishing NA, reason "no record") until TODO 86 reads the gear from the track; whale watching and
aquaculture service are classes by rule from the port lists, not fishing, basis `derived`; "other" is sorted by the
register's usage class (decision 119, plan 028) and the rest listed for a person. Built with the AIS batch.

**check:** the trail's fishing columns say undecided with a reason on fishing vessels' voyages with no record; the two
classes named on their vessels' voyages; "other" sorted, its remainder listed.

## 62. Foreign vessels' logbooks for Icelandic waters
**status:** in progress · **needs: maintainer** — where the 2019-2025 ones are: Norway's open ERS data for the
Norwegian half, an extract from Fiskistofa for the rest ·
**see:** plan 026, plan 013 item 5, decisions 102-103 and 126, plan 017 §3 (`raw/oracle/afli/steini.parquet` is a partial one: oceanic redfish, 1989-2017; whether to stage it is
plan 017's ask g)

The maintainer said yes on 2026-10-14: acquire them. Foreign vessels land 80-124 a year in Iceland and hold most of
the landed weight with no Icelandic logbook trip (plan 013, rows 4 and 9; 1,144 of 1,320 kt of pelagic species in
2019-2025). They are not in what is dumped: the logbook tables hold 6 foreign trips in all, and none of the four
logbook schemas (afli, fs_afladagbok, adb, logbook) has a foreign table.
**2014-2018 (decision 126):** `dw.dw_aflaskeyti` holds 2,778 foreign hauls of 111 vessels, each confirmed by AIS and
by landings in Iceland. Norway is whole by vessel; the Faroes only from 2017-10. Coordinates are swapped, Faroese
summer times are local, and there are no trips. The maintainer took them in (2026-10-17); plan 026 is the design:
an adapter, three corrections, trips cut at landings in Iceland and then at 48-hour gaps, and a tier in
`curate/logbook.R`. The adapter, the corrections and the trip script are coded and run on a
scratch `$FISHYDATA`, with the 280 Icelandic hauls on vessel-days the logbook lacks (maintainer, 2026-10-17) and
tier 4 in `curate/logbook.R` (plan 026 §11), and `docs/merge.qmd` has the section. Built to `curated/logbook`
2026-10-17 (decision 127), and on the fixes the same day (decision 129): plan 026 §8.6 passes, §8.5 holds as the
trail's exclusive windows allow, and §8.7 passes: `docs/merge.qmd` renders against the build (2026-10-19).
**2019-2025, the lead:** Norway's open ERS catch messages. `sources/norway/logbooks.R` reads them, but it is not a
target, it reads from `staging/`, and the files are not on disk. The Faroese half has no lead.

**check:** a `dump/` script writes the foreign logbooks under `raw/` (`raw/oracle/<schema>/` if they are in
Oracle, plan 018), an adapter in `sources/` stages them, and `ais_catch.R` puts
foreign catch on the record path where a logbook exists.

## 65. A vessel registry for every ping, whatever the flag
**status:** in progress · **needs: maintainer** — the go for the crosswalk's rebuild and the first
`allocate_vids(dry_run = FALSE)`, by the commands in decision 190; the Directorate of Fisheries (MMSI, §6 d) and PAME
(ASTD, §6 h) have not answered · **see:** `curate/plans/021-vessel-registry-for-every-ping.md`,
plans 008, 016 and 017, decisions 114-115, 118 and 190, TODO 15 and 25

The maintainer asked on 2026-10-15 for a registry of every vessel the pings carry, not only the Icelandic ones. Plan 021
proposes one integer `vid` per hull and a crosswalk from each feed identity to it. Its asks are answered (a revised and
c amended 2026-10-17, i answered the same day: a vid is kept when a hull's key changes). Step 1 is built (decision 114),
steps 2-4 are code (decision 115), the crosswalk built 2026-10-18 (decision 144). The maintainer, 2026-10-23: decision
115's readings 1-6 and 8 confirmed. The fixes asked for before allocating are code, checked in scratch only (decision
190, Claude's, not checked by a person): a dominant IMO takes a `two_imos` segment (172 of 176), the 27 MMSIs with a
reviewed foreign link's IMO reach its vid, the STK rows' open end is NA, the trail's SKB range ends at 199999. The dry
run on the scratch crosswalk gives 379,912 hulls.

The 52 links in `overrides/vessel_ais_link.csv` for 50 of the 59 `foreign_vid_candidate` MMSIs were confirmed on
2026-10-17; 9 stay held. Left from that review: 19 of them (class B) rest on the hand-made STK call-sign sheet
`overrides/stk_foreign_mid_vid.csv`, whose entries want checking; the STK key is wrong for mids 101843, 147141, 102481 and 102527
(reused call signs, step 7's redo, TODO 25); foreign vids 3777 (a duplicate of 3756), 4077 and 3792 are not one hull each;
decision 161 widens this to 42 call signs, each held by 2-3 foreign landing vids over the same days.

**From TODO 22:** a ping with no vid is still dropped before the voyages: STK by the key's join
(`sources/stk/convert.R:31`, `curate/ais_ping_union.R:78`), the other feeds by the MMSI periods
(`curate/ais_ping_union.R:62`). A foreign hull reaches the voyages once the union reads the crosswalk (plan 021 step 6);
`ports_all` already holds the ports abroad. Also open (maintainer): plan 017's asks e (gear for a foreign voyage with
no landing in Iceland) and f (ports abroad).

`curated/check/ais_key_foreign_candidates.parquet` (decisions 039-043, run by hand) was built 2026-09-27 and never
since, so it predates the key of decision 128 (Claude's audit of 2026-10-23, not checked by a person). Decision 190's
"Left" has two smaller ends of the dominant rule.

**check:** plan 021 §7, and plan 017 §7's check that a foreign vessel's ping reaches `curated/ais/voyage.parquet` with
a voyage key and `pid1`/`pid2` resolved; no STK row of the crosswalk ends on the open-end date.

## 68. stk's tables besides the trail: what they hold, and which fishycode should read
**status:** open · **needs: maintainer** — the go for plan 022 §4, and its asks 1 (who knows what STK's export and
backup tables were for) and 4 (survey windows) · **see:** plan 022 (§2.1, its appendix, §4, §7), decision 109,
`curate/ais_voyage.R`, `curate/port_call.R`

The maintainer asked for every stk object besides the trail to be checked: some are copies of the trail, some may be
very useful. Plan 022's appendix (2026-10-16) says what each of the 63 holds, so the first half of the check is met.
Left is **`tilk_stk_allt`**: 3,186,904 recorded voyages, 2003-09-08 to 2021-02-08, port to port, with times and the
trail ids at both ends. It is of value three ways (maintainer): voyages before mid-2007, where the trail has almost no
track; recorded departures and arrivals to check, or correct, the voyages and stays cut from the track; and a
departure time (T1) for logbook trips and landings, with its own basis. The comparison is plan 022 §4. The voyages
it needs were rebuilt on 2026-10-16 (decision 112); it waits for the maintainer's go. Ask 4: whether
`leidangrar_ctrl`'s windows mark the survey tows of chartered vessels in the trail (plan 022 §5.1). Since then
(decisions 163, 164): `tilk_stk` carries the vessel from 2003 and alone supports 57-77 thousand stays a year in
2004-2007; `trail_multi_rectime_v` is 99.6 % exact copies; `tilk_stk.trailid` is the line-incentive check's link.

**check:** each stk table besides the trail has a line saying what it holds, its time span and keys, and whether
fishycode reads it; and `tilk_stk_allt` is compared with `curated/ais/voyage.parquet` on a sample of vessels, the
result recorded in a decision or a plan.

## 70. `afli.afli`: which stored values `TO_CHAR` rejects
**status:** open · **needs: maintainer** — the query in plan 018 §3, run against Oracle · **see:**
`curate/plans/018-raw-oracle-dumps-as-is.md` §3, decision 109

The dump reads `afli.afli` and `v_afli` whole: `TO_CHAR` fails on `visir`, which is read natively, and its values match
the April copy exactly (decision 109). Which rows and stored bytes `TO_CHAR` rejects is not known; the query in plan 018
§3 (`DUMP()` only, one scan) names them. The 48 empty `afli` values (46 stations) are in both copies and are not this
fault. `visir` runs from -2,768,723,449 to 10,630,176,826, with 4,064,520 rows outside 0 to 10^9; whether those are
the rejected values is not known. `ops$einarhj.heildarafli` carries the same ids and fails the same way (decision 122).

**check:** the rows the query returns are recorded in a decision or a correction, with whether they are the 48 empty
values.

## 71. The `ops$einarhj` MMSI list of 2023-01-15: find it or dump it
**status:** open · **needs: maintainer** — where the 2024-10-22 list is, and who refreshes MFRI's copy of the vessel
register, stale since about June (plan 016 §7, "still open, not asked") · **see:** plan 022 §3.1, `reference/vessels/mmsi.R`, decision 111, decision 119

The whole schema is dumped since 2026-10-17 (decisions 121-122), the 2023 list among it; `mmsi.R` does not read it
yet. Of the tables not dumped before, judged from the dump's overview (columns, Oracle's row counts), only one
holds what fishycode does not:
- **The 2023 list:** `mmsi_icelandic_registry_20230115` (3,687 rows), the MMSI list of 2023-01-15. It falls between
  the 2022-04 snapshot and the 2024 lists that the MMSI history reads.
- **Probably the same list:** `vessel_mmsi` has its columns and its row count.
- **Already held:** `mmsi_mid` and `vessel_mid` (MID → flag, as `staging/aux/maritime_identification_digits`).
- **Earlier versions of what is dumped:** `mobile_vid_20240212`, `stk_mid_vid`, `stk_mid_vid_2020`,
  `mid_vid_icelandic_20220418`, `temporary_mid_vid` and `pame_vid_mmsi`.

**Not on the Mac (2026-10-16):**
- the overview has the 2023 list as listed, not written;
- the old copies in the Trash (`raw-mmsi-oracle_2026-10-14`) are the four snapshots `mmsi.R` reads;
- no file of that name is under `~/stasi`, `~/R` or `$FISHYDATA`.

**The undated `mmsi_icelandic_registry` is not it.** It shares 3,756 of its 3,759 MMSI-vessel pairs with the list of
2024-08-21, so it is a 2024 list. `mmsi.R` reads it with no date.

**check:** `raw/oracle/ops_einarhj/mmsi_icelandic_registry_20230115.parquet` exists and the MMSI history reads it as a
dated list, or a decision says why not; and `mmsi_icelandic_registry` carries a date in the MMSI history.

## 72. Plan 013's open items (the ramb one-flow)
**status:** open · **see:** `curate/plans/013-ramb-one-flow.md` ("What is left, in order"), decisions 099-104, ramb
53519ee

Items 0-3 and 5 are built and on the data. Items 4 and 6-10 are built in part (decisions 099-103, 173-174). What is
left of each is in the plan:
- 4, records checked against the operations the track shows: in part, decision 155's allocation audit tests each
  link by the records' own times;
- 6, which vessels fish (the vessel row; the classes are TODO 49);
- 7, records without pings: the 1990-2006 logbook (3.5 M records, start positions only) needs a target of its own;
  decision 103 left the years before 1990 out of scope, now plan 038's ask e;
- 8, static gear: `rb_link_record_sets()` is in ramb, but against real set times it is right (within 60 min) on
  about half the longlines and a third of the gillnets, no better than the vessel's typical soak (decision 158,
  superseding 146's Icelandic score), so it is not run; pressure as quantity × soak is not built (decision 103), and
  a placeholder `t1` is NA (TODO 103). Its defaults and a set made inside another haul's window wait for the
  maintainer (decision 146). ramb a68d1f6 is on origin/main and installed as 2026.10.22.2 (checked by Claude
  2026-10-23);
- 9, track models for fishing;
- 10, declared times reconciled with the track: a trip's departure and return are `rb_add_trip_time()` (the step
  planned as `rb_reconcile_time()`, decisions 173-174, built in 180); a haul's times against the track are not built
  (decision 104's ground truth; plan 031 §3.11: logbook times and the port calls disagree mostly by 1-3 h). Brought
  up to date from Claude's audit of 2026-10-23, not checked by a person.

**check:** each of items 4 and 6-10 is built and on the data, or plan 013 says why not, and a decision records it.

## 73. Plans 019 and 020: the fs_afladagbok tables, gear detail and environment
**status:** open · **needs: maintainer** — plan 019 §6 asks 1-7, plan 020 §5 questions 1-6 · **see:**
`curate/plans/019-fs-afladagbok-mined.md`, `curate/plans/020-gear-part-and-environment.md`

Two proposals of 2026-10-15, prototyped in scratch, with nothing in the pipeline. Plan 019 sets fs_afladagbok's 32
objects against the grammar (the tour app, the port translation, implausible catch, mammal and bird bycatch, the depth
unit by app). Plan 020 keeps the gear detail and the environment that the adapters fold away, as tidy tables beside
the fishing sample (`gear_part` prototyped for fs). For plan 020: the trawl's `gear_width` is the bridle (sweep)
length, not a width (decision 170, left unchanged; Claude's audit of 2026-10-23, not checked by a person).

**check:** each plan's asks are answered in the plan, and each is built, parked or abandoned in its header.

## 75. Afli trips lost whole, and the rows before 2007-09 (decision 098's open ends)
**status:** open · **see:** `curate/decisions/098-dropped-afli-hauls-not-admitted.md` ("Open"), plan 005

Decision 098 did not admit the afli hauls the stofn merge dropped. It left two things open. About 410 trips are lost
whole yet have a landing that no logbook trip took: they are the only candidates for genuinely missing records, and
nothing proves them (in the 219 with catch on both sides, the lost catch is 0.87 of the landing, median). Before
2007-09 no landing link reaches the rows: 1,854 rows, mostly 2004-2006, where the share absent was highest (19 % in
2004), and whether those are copies is unknown.

**check:** a decision says, for the 410 trips and the 1,854 rows, whether they are admitted, with the evidence.

## 79. Every source station and trip accounted for in the logbook merge (plan 024)
**status:** open · coded and checked on a scratch store, built with the next logbook rebuild · **see:** decision 194,
`curate/plans/024-logbook-station-fate.md`, plan 038 §8 step 1

Coded and checked on a scratch store (decision 194; Claude's, not yet checked by a person). `curate/logbook.R` writes
`curated/logbook/station_fate.parquet` (8,013,418 staging stations of afli, fs_afladagbok, adb and aflaskeyti) and
`trip_fate.parquet` (2,175,609 trips), each with the rule that dropped it, and stops unless the account adds up. The
whole weight is one function, `R/whole_weight.R`. The four logbook tables and `catch_by_species_station` come out
identical to the store's. Not built, on the maintainer's word: the build is the next rebuild that touches the logbook
(plan 037 phase 1). Until then `tar_outdated()` lists `logbook` and the 19 targets after it; build them together. The
adapters' own drops come later, each its own ledger.

**check:** both files in the store, built with that rebuild; the merge's invariants held in its log; plan 024 §2's
counts (decision 194) recounted on it, with the differences explained; `docs/merge.qmd` renders its section.

## 81. A trip's catch landed over two days: `lid_map` claims one landing
**status:** open · **needs: maintainer** — plan 027's four asks · **see:** plan 027, plan 026 §11, plans 025 and 014,
`curate/link_lid_map.R`, `curate/ais_catch.R`

`lid_map` gives a trip one landing, and `ais_catch.R` shares every landing it leaves unclaimed, mostly on the trip's
own fixes (its voyage link sees only unclaimed landings). Measured 2026-10-17 (plan 027 §2-§3): of 9,955 next-day
landings at the same port (68.8 kt), 1,246 (30.2 kt) came with the vessel in port, 490 of them (23.0 kt) also in the
logbook, so counted twice; 8,376 (31.2 kt) came after it fished again. Another port or 2-7 days later adds 1,529
(65.4 kt). Plan 027 proposes plan 025's `withdrawn` first, a flow table `trip_landing` read by `ais_catch.R`, and
the voyage link given every landing. Nothing changed in the pipeline. Seen again in plan 031 §3.11 (2026-10-20): 4,870
trips are matched to a landing the vessel made at a call before the trip's last station.

**check:** a trip's further landings join it (plan 027 §5), and kg on the fixes, raised, equals kg landed per vessel
and year within the ratio of vessel-years with no second landing (plan 027 §6).

## 83. The annual ship register mined whole, into the `vessel` schema's tables (plan 028)
**status:** in progress · **needs: maintainer** — plan 028 §9's asks d (the MMSI lists `mmsi.R` does not read) and e
(editions outside 2004-2022) · **see:**
`curate/plans/028-skipaskra-mined.md`, decisions 130-132, 135, 136, 142 and 144, TODO 71

Steps 1-5 are built in the `once` project:
- the 19 editions read whole, and the other witnesses (decisions 130, 131);
- the evidence table and 38 checks (61,049 findings, `docs/skipaskra.qmd`);
- the history to 2023-12-19 in the `vessel` schema's tables, chosen by the decision model (decision 136).

Build by name, never the whole project, whose key targets are outdated:
`tar_make_isolated(names = c("check_skipaskra_discrepancy", "skipaskra_history"))` in `TAR_PROJECT=once`. What public
sources print is kept, never published.

Steps 6 and 7 are built in the main project (decisions 142, 144): `curated/vessel/register/` holds the register's
tables for every year, and `vessel_sign`, `vessel_class`, `vessel_year` and `registry.R` read it. The history was rebuilt
first with mbl last, kvoti first for the class, SKEMMTISKIP as 62 and Hreiðar's years read whole (decision 144).

The AIS chain and trail were rebuilt on them (decision 144), and again after a reviewed row set 6061's 2016 kW to 58.

Left in the register (decision 144):
- the class name column: 622 rows name another class than their code;
- mbl's sole values, such as 2730's TFCR in 2023;
- 12 kvoti stretches starting on its 1901 placeholder, on old hulls before 1920;
- 111 local signs typed oddly ("RE.", "ís", "TH" for ÞH), which `vessel_sign` folds in its key.

**check:** asks d and e answered or parked, and the four leftovers fixed or declared.

## 84. A fishing licence history from every witness (plan 029)
**status:** in progress · **needs: maintainer** — plan 029 §8's asks: where licences are kept after 2020-07-22 and
whether it can be dumped (a), the rules' threshold (b), lumpfish statuses (d), plan 028 reading the table (e),
lineages (f), activity as a witness (g), records before 1991 (h); c answered (decision 133) · **see:**
`curate/plans/029-licence-history.md`, decisions 133-134, plan 028 (§3.4 and ask c), TODO 83

kvoti's licence tables stop on 2020-07-22. Plan 029 sweeps every dumped table for other witnesses of a licence, before
1996 and after 2020, and calibrates each by its agreement with the licences while both existed. The history to
2020-07-22 builds in `once`, the live tail in the main project (decision 133). Steps 1-3 (staging, the lost-century
correction, the evidence table with the calibration) are coded and checked in a scratch store (decision 134). Not
wired: the plan 028 session edits `_targets_once.R` too. Step 4 needs asks b, f and g.

**check:** `curated/vessel/licence.parquet` and `curated/check/licence_discrepancy.parquet` built in `once` and
reviewed, and `docs/licence.qmd` rendered, or the plan parked.

## 86. The gear read from the AIS track, where no logbook gives it
**status:** open · **see:** TODO 49, plan 004 (parked), decision 143, `docs/grammar.qmd` (the attended windows)

Where a trip has no logbook, the flow has no recorded gear for its pings. The vessel overview assumes the previous
logbook trip's gear, up to the last landing (the maintainer's rule, decision 143). "Better still would be that we would
obtain the gear from the AIS track - but that is a bigger TODO" (maintainer, 2026-10-18). A track shows its gear's
kind: a tow at 3-4 knots for hours, a seine's circle, a longline's or a net's set and haul a soak apart, a jigger's
drift. The logbook trips with a recorded gear give the labelled examples. TODO 49 asks whether a voyage with neither
logbook nor landing counts as fishing; this asks which gear a voyage used.

**check:** a plan or decision on reading the gear's kind from the track, its error measured on trips whose logbook
records the gear; or the item parked.

## 87. The STK reports reloaded by hand after the crash of 2026-10-11
**status:** open · **see:** decision 143 (the measurement), `R/stk_trail.R`, `curate/ais_ping_clean.R`

The Oracle database crashed around 2026-10-11 and the reports were loaded by hand (maintainer).
- About 904,000 STK reports were received 2026-10-12 to 10-14 with position dates 2026-10-11 to 10-13, from about
  1,200 mobile ids.
- Many carry a date exactly one day early, with the time of day right. Some duplicate live reports.
- They put day-shifted copies of tracks into `curated/ais/trail`, as on vid 2350 on 2026-10-12.

The fix is a declared correction in `curate/corrections/`, before the whack filter: a corrected time beside the
original, and the duplicates flagged. The maintainer: the dump's order may help. Then the AIS chain is rebuilt, with the
maintainer's go. Other periods with the same signature are listed (decision 164): 18 mass-delivery days 2007-2026
(3,745,293 late pings; this reload 927,058, 1-5 days late), a re-import in 2012, stuck-date units in 2016. The dump's
order is receipt order (20 inversions), so it adds nothing to `recdate`. Which days carry day-shifted copies is not
measured.

**check:** a corrections entry (`.yml` and `.R`) for the reload; the trail's jumps on 2026-10-11 to 10-14 counted
before and after; the other mass days checked for day-shifted copies.

## 88. A whack filter that catches troubled pings without domain knowledge
**status:** open · **needs: maintainer** — the prototype's §10 (the floor, the forward stage, ramb's version, adoption) ·
**see:** decisions 067, 069, 078, 143, 164 and 185 (TODO 38 folded in), TODO 99, plan 031 §3.7 item 12 (what the
filter leaves near harbours: about 6,000 fixes, mostly STK port event rows)

"the current whack procedure should have picked out these troubled pings ... we may not have the luxury in other cases
for having this domain specific knowledge" (maintainer, 2026-10-18). The case:
- On vid 2350, 2026-10-12, the filter removed 29 pings of a day-shifted copy of the track (TODO 87).
- It kept a 24 kn jump between the copy and the live track, under its fixed 25 kn.

The reload is a labelled test: its receipt lag marks the truth, and is never a filter input. Candidates:
- a per-vessel speed limit, from the vessel's own recorded speed (99.9th percentile at sea + 3 kn; 2026-10-20: 132,380
  steps under 25 kn but over it, 8,196 out and back, 400-800 vessels a year; vid 1417, a 7-knot boat, 132 steps). It
  needs no voyage, so it goes in the first pass (decision 185 keeps TODO 99's measurement);
- splitting a vessel's pings into chains that are each consistent;
- zigzags judged over a window;
- each leg's displacement against its reported speed and course.

Against ASTD/ASTDB, 2013-2026 (decision 164): 75 % of the removals a witness can test are supported (`forward`
99.7 %, `vmask` 54 %), and 2,780 kept pings are contradicted; 63 % of the supported removals are cross-feed legs within
0.3 nm. A prototype re-run on 2016 and 2026 (2026-10-22; `$FISHYDATA/archive/2026-10-stk-trail-order/prototype/`):
with the defaults it equals `ping_whacky` ping for ping; a distance floor between feeds (0.3 nm) frees 22 % (2016) and
80 % (2026) of the false removals and loses no true one (0.5 nm: 24 % and 97 %); a two-sided forward stage does almost
nothing. Its ramb changes, opt-in arguments `feed`, `noise_nm`, `evidence`, are uncommitted in `~/R/Pakkar/ramb_wt_whack`
(branch `whack-feed-aware-evidence`); its README §10 holds five decisions for the maintainer. Its §8c: the STK-ASTD
offset on moving vessels is a time lag that varies by year, so no single floor fits every year.

The filter is in ramb, so a candidate is judged by its WGSFD-wide use. **From TODO 38**, decision 067's loose ends
(the detail in decision 185): fast vessels (84 under 12 m lose 8,433 real pings; iapesca's fast-run rule, decision
078), the forward scan's first ping after a 4 h gap, sparse tracks, and vmask eroding good track beside a burst.
Kept by the filter, found 2026-10-23 in the vessel overview (TODO 25's review): vid 2654's ping of 2013-09-13 05:19
at 8.55N 180W, and vid 7438's of 2009-07-09 12:59 at 64.2333N 22.4W (rounded, speed and heading 0).

**check:** a plan with the current filter's recall and precision on the reload's days, the candidates compared on
those days and on normal ones, and a recommendation, with a verdict on TODO 38's fast-vessel, gap and sparse cases.

## 89. AIS gaps at sea judged against coverage
**status:** open · **see:** decision 143 (intervals at sea by distance offshore and provider), plan 030

The intervals between pings at sea grow offshore, where only satellites receive (maintainer). On the 2021 trail:
- within 100 nm of a port, under 1% of intervals exceed 30 min;
- 100-200 nm out, 29% do;
- beyond 200 nm, 10.5% do;
- `astdB`'s 90th percentile is 299 min.

So a fixed threshold mostly flags coverage. A gap flag should judge a gap against the intervals usual for its distance
offshore or area, its receiver and its year. The trail has no distance offshore, so this is flow work. Until then, the
vessel overview's lane of AIS gaps at sea (its activity record, decision 178) keeps its 30 min threshold.

**check:** a plan or decision with the grouping that explains the intervals, measured over several years, and a gap
flag on the fixes that the overview's lane reads.

## 90. The voyage definition revisited: stays, records, trips and gears together (plan 031)
**status:** open · **see:** `curate/plans/031-voyages-from-any-data.md` (asks answered, a-h 2026-10-19, i-k 2026-10-23;
g is TODO 92), decision 197, decisions 144 and 155,
TODO 25, TODO 27b, TODO 49, TODO 81 (and plan 027), TODO 101, plan 011

The maintainer (2026-10-19): the issue is broader than the gear of a voyage, so revisit the voyage definition as a
whole, with what is now known of the data. The goal is a generic voyage finder for any data: pings with landings
only, logbooks only, both or neither, and several gears in a voyage.

Measured, in plan 031 §3.2-3.6: `port_stay` misses calls in four ways, the departure radius the clear fault, which a
time budget fixes; 42 % of the landings with no stay disagree with the track on the port; a fifth of the voyages with
several logbook trips are one sea trip that the date-only logbook splits by day. The rest of the plan: the cascade
(§4.0), the pitfalls (§3.7: no stays and no warning without a port list, calls abroad never stays, short voyages
dropped), outside code (§3.8) and the robustness bench (§4.8, step 2).

The threads it gathers: the STK key (TODO 25); the trail and its delivery (TODO 27b); AIS where records are missing
(TODO 49); a landing over two days (TODO 81, plan 027); the gear read from the track (TODO 86); gaps judged against
coverage (TODO 89).

Step 3 done (§3.10, in ramb), step 4 measured 2026-10-20 (§3.11: a landing placing a call lifts landings with a call
at their port from 94.1 % to 97.0 %; a logbook time at sea inside a call is mostly a disagreement of times). Open from
step 3: ramb's defaults against the plan's choices, a short voyage by time rather than pings (thin voyages measured
2026-10-20, `$FISHYDATA/archive/2026-10-todo98/scripts/thin_voyages.R`), the weak `gap_budget`, and gap rules that
hold only for a feed silent in port (TODO 89's coverage model).
Also unflagged: `port_call.parquet`'s 13,510 event-only calls (2017-2026), which cut no voyage (decisions 060, 061),
and Hornvík's anchorage stops, port calls since one 2 h minimum (decisions 074, 077), never marked as no trip's end
(Claude's audit of 2026-10-23, not checked by a person).

Decided 2026-10-23 (decision 197): the frozen departure radius retires for the time budget, applied with the AIS batch
after the key redo; a logbook time cuts a call only with its trip's own landing; records as evidence into ramb on four
conditions; the audit judges static gear by all its times.

**check:** a voyage definition decided and built for every data situation of plan 031 §4.6, or the item parked.

## 92. Ports abroad: the independent lists as a second port tier, tested
**status:** open · **see:** plan 031 §3.7 item 2 (calls abroad), §3.9 (the port-list scenarios), §4.3; its ask g

Calls abroad are many: 40,117 AIS vessel-days at foreign ports in 2007-2026, at least 1,833 landings abroad. Today they
are never stays, because the stays read only the `einar` polygons of Iceland and the Faroes. The bench found that an
independent list does as well as `einar` in Iceland. GFW anchorages, read raw and buffered 2 km, find 98.3 % of the
witnessed landings, as `einar` does. The maintainer (2026-10-19, ask g): "this needs some testing" before such a list
becomes a second tier.

To test, abroad: which raw list or lists (GFW anchorages, GISCO, OSM, vmstools, `jeppe`, UN/LOCODE), and the buffer
radius. Score them against the landings abroad (the Faroes, Norway; code 159 "Gámur/Sigling" names no port), and count
the false stays at transits and offshore anchorages (the Kiel Canal at Rendsburg).

**check:** a decision on the second tier, with its lists and radius and their score abroad; or the item parked.

## 93. Which of decision 148's data go into ramb's example data
**status:** open · **needs: maintainer** — the choice of sets, and four asks outside this repo (below) · **see:**
decision 148, `docs/wkssfgeo.qmd`, plan 031 §4.8

Proposed (2026-10-19), each documented as ramb's present sets are (data dictionary, sources, licence):
- CNR-IRBIM's two coastal zones (WKSSFGEO `dev_branch`, GPL 3). ramb's `cnr` method needs them to give CNR's own
  trips: 72 with the zone, 70 without. Plan 031 §4.8 had left them out as gear data.
- CNR-IRBIM's tracker log (`raw/external/cnr/zenodo_5783920`, CC BY 4.0). It is the only set with power, ignition
  and the device's own port events.
- CNR-IRBIM's labelled tracks (`raw/external/cnr/anonymized_dataset.rds`, GPL 3), raw columns only. Wait until the
  CRS of its x and y is known.

The asks:
- Lattanzi (CNR-IRBIM): the CRS of the labelled tracks' x and y.
- Mendo or Glemarec: the observed set and haul times behind Mendo et al. 2023's samples. With them the samples become
  a set-finder test; without them they are model output.
- Galdelli (CNR-IRBIM): may the 5-vessel file they removed from WKSSFGEO2 be used?
- The five WKSSFGEO2 sets that never reached GitHub (DK_DTU_1897_EM, ES_AZT_2018_AIS, ES_IEO_2021_GRB,
  IE_MII_2019_IVMS, PT_CCM_2021_GP): on the WKSSFGEO2 SharePoint, `2022 Meeting Documents/06. Data` (the report's
  Annex 5 and section 2.3; `docs/wkssfgeo.qmd`). The maintainer has access (2026-10-19), but the site downloads one
  file at a time; the maintainer is finding another way to copy them out.

**check:** each proposed set is in ramb's `inst/extdata` with its dictionary entry, or recorded as left out with the
reason.

## 94. fishybook: one Quarto book for the groups' thinking, ramb's methods and the Icelandic data (plan 033)
**status:** open · **see:** `curate/plans/033-fishybook.md`, plans 001 and 002, items 15 and 91; TODO 16 folded in
(decision 185)

The maintainer, 2026-10-19: replace the doc spaces with one Quarto book, *From pings to effort and catch*, for the
members of WGSFD and WKSSFGEO. Its main text is generic (the problem, the approach, the ramb code, on example data). It
consolidates the groups' reports, and it is the guide to what ramb can do and still lacks. Technical tests go in
appendices, and the Icelandic data manual is its own part. ramb keeps only what it takes to run it.

Asks a-f answered the same day (plan 033 §12): `docs/` converted in place; one edition, at `~einarhj/fishybook`; Part
IV public as rendered figures and tables, no data files (widgets count as data, so vessel data are static and
interactive figures use ramb's example sets); the four leftover pages removed; the 2026 meeting folder moved, cited
once published.

**Step 1 done** (decisions 150, 152). All 13 reports are in the reading map `docs/ices_reports.yml` (1,777 topic
rows, 511 code rows). The diagram held as the centre and was amended as version 3, and §4 was revised. Over all 13,
version 3 holds.

**Step 2 done** (decision 151): `docs/` renders as a book, three parts from the pages that exist, no new text.

Open:
- decision 152's proposals, the maintainer's call: four boxes for the products row (indicators from the grid,
  disclosure, coverage, impact), and a chapter on the products' uses;
- the main part is restructured (2026-10-20): one skeleton chapter per diagram row (`docs/flow_*.qmd`, with
  sections per box, the cases outlined from ramb's articles and data), and the Icelandic chapters are in the
  appendices. The skeletons wait for the maintainer's review, then their cases are written, graphics first;
- chapter 1 (`docs/at_sea.qmd`) is drafted and waits for the maintainer's review. Its gap: the fisher's money, since
  no landing value or cost is in the data held; find a public price source or leave it stated;
- steps 3-9. Step 5 holds TODO 16 (folded in, decision 185): `fishyweb`'s five real pages into the book, its 26
  outlines dropped, its unpushed 27b35ff and untracked `notes/whacky-positions.qmd` (vessel tracks: the disclosure rule
  first) settled, `fishyweb` archived read-only and plan 002 closed or redirected; the posts of
  `~/stasi/fishyweb_2026-09-24` are sources for chapters, read against ramb's present names.

**check:** decision 152's proposals are decided, `check_book()` runs in `check_bookkeeping()` (plan 033 step 3), and
step 5 is done: fishyweb's pages in the book, fishyweb archived, plan 002 closed or redirected.

## 95. `sources/stk/convert.R` leaves a partition its new build no longer writes
**status:** open · **needs: maintainer** — approve the fix below and when to rebuild `stk` clean · **see:** decision 185 (TODO
69, the same defect in every output, folded in), decision 151, `docs/stk_data-inspection.qmd`

Found 2026-10-19 (plan 033 step 2): `staging/ais/stk/year=2006/` holds 2 rows from the build of 2026-09-23 (vid 2618,
an `I` at HFN, 2006-12-31 12:28), without the column `d2e` the rebuild of 2026-10-17 wrote into the other 27
partitions. The key now starts that mid on 2007-06-01, so no build writes 2006 again, and `duckdbfs::write_dataset()`
replaces only the partitions it writes. The book's STK page reads with `unify_schemas = TRUE` until this is fixed.

Measured 2026-10-19, read-only:
- **Downstream.** Only `sources/stk/event.R` reads the table (and the STK page). `stk_event.parquet` holds the stale
  ping as an event, and it makes vid 2618's first real event (2007-06-01 05:20, `I` HFN) `io_dup`, so `io_ok` is
  FALSE: 2 rows wrong. No further: `port_call` reads events from 2016 on (`EVENT_FROM` 2017), the frozen `port_radius`
  2008-2025, and the ping chain reads the trail through `stk_trail()`, not this table.
- **Other outputs.** 20 hive-partitioned datasets (1,838 files) under `staging/`, `curated/` and `raw/`. In the 10 that
  targets write, this is the only file older than its target's last build. `convert.R` is the one writer that clears
  nothing and takes its years from the data (`group_by(year)`, junk years such as 1936 and 2106 included). `ais_catch.R`,
  `ais_trail.R` and `logbook_sensor_gps.R` clear the whole output; `ais_ping_clean.R` and `ais_voyage.R` clear the
  years they write; `ais_ping_union.R` and `ais_ping_tag.R` write the feeds' years (decision 181).
- **Mixed schemas, not stale:** `ping_union` 2025-2026 store `dt_sec`, `sid_gps` and `n_sid_gps` as INT32 (DOUBLE,
  INT64 elsewhere); 7 `astd` months carry an extra `ship_id`. (`raw/ais/trail2/`, read by no code, is in the Trash:
  decision 168.)

**Proposal.** (a) In `convert.R`, `unlink(fd_staging("ais", "stk"), recursive = TRUE)` before the write, as
`ais_catch.R` does. (b) `targets` cannot see that edit, so with the next AIS rebuild, from a clean tree: fingerprint,
`tar_invalidate("stk")`, then `tar_make_isolated(names = )` on the 15 targets from `stk` down (`stk_event`,
`port_call`, `ais_voyage`, `ais_trail`, `ais_catch`, `station_event` and 8 small ones), ~75 min at their last build
times. Only `stk` and `stk_event` should change in content; the rest is re-stamped. `once`'s `port_radius` is outdated
already and stays frozen. (c) The STK page drops `unify_schemas`.

**check:** every partition of `staging/ais/stk` is from the latest build, the writer clears what it no longer writes,
`stk_event` has no 2006 row, and the STK page no longer needs `unify_schemas`; and (TODO 69's check) no partitioned
output under `staging/` or `curated/` holds a partition its last build did not write, its writer making sure of it.

## 96. The vessel demo: Safari, Windows, and the basis for sending it
**status:** open · **needs: maintainer** — a Mac with Safari's remote automation on, or a person, and a Windows machine;
and the agreement under which the folder goes · **see:** decision 153, `products/exports/vessel_demo.R`

The demo (`$FISHYDATA/exports/vessel_demo_2018-06/`) was tested from `file://` in headless Chrome and Firefox on macOS
only. Safari cannot be driven without `safaridriver --enable`. Under MFRI's data policy (gagnastefna), confidential data
leave MFRI only on an agreed basis.

Rebuilt on 2026-10-22 from 6b69323 with the page of decisions 177-179, and checked over HTTP in Chromium; the key is
unchanged (the same 30 vessels, numbers and windows). Rebuild it again if the page changes before it is sent.

**check:** the demo opens and loads a vessel in Safari and in Edge on Windows, and the agreement it went under is
written in decision 153.

## 98. The afli GPS logger inside the AIS track: what is left once 2020 on is out
**status:** open (decided 2026-10-23, decision 196: re-interpolated in the flow on every build, with a gap limit
measured first) · **needs: maintainer** — the gap limit, from the measurement · **see:** decisions 075 and 196, `curate/ais_ping_union.R`, `curate/logbook_sensor_gps.R`, `curate/corrections/logger_whole_degrees.yml`,
TODO 99

The maintainer's rule (2026-10-20): logbook positions never join the AIS feed; the vessel overview's haul layer is gone.
`ais_ping_union.R` still joins the afli GPS logger (`provider = gps`, frozen `curated/logbook/sensor_gps`): the
logger's time, speed and heading, with lon/lat interpolated once from the AIS track of 2026-10-09.

Decided the same day: from mid-2020 the logger writes position in whole degrees and speed in whole m/s, and those
fixes leave the track (`logger_whole_degrees.yml`; built 2026-10-20 at c7fa8c7, decision 154). That removed 4.85 M of
the trail's 8.86 M logger fixes of 2019-2024 (and 15 of 2008) and 1,234 of its 2,071 over 5 km from the recorded
track. Measured on the rebuilt trail (2026-10-20): 861 remain over 5 km of 21,971,181 logger fixes, all on vids 2173
(500, 2019-2020) and 2411 (361, 2013-2020); 860 of them interpolated across a gap of over an hour.

Left: the rest of the 2,095 off-track fixes (vid 2173 2019-mid 2020, vid 2411 2013-2020) come from interpolating
across silences of the old track (no gap limit: 101,982 fixes span over 6 h). Options: take the logger out of the
track, keeping its speed and heading in a side table by time; or redo `sensor_gps` (a once fix, by decision) on
today's track with a gap limit. Either needs a rebuild from `ais_ping_union`. The logger's
other readings (depth, temperature) are TODO 100. Scripts: `$FISHYDATA/archive/2026-10-todo98/`.

Found 2026-10-21 (`curate/corrections/afli_coords.yml`, `origin_in_the_sent_record`): the logger's DDMMmm-as-seconds
fault is already in the XML each app sent, in every version 2008-2024 (SeaData 2.0, Trackwell 2.6, 2.7), so the XML
cannot repair it; Trackwell is asked whether the devices' readings survive (the draft of TODO 103).

**check:** the gap limit chosen from its measurement; the logger interpolated on each build's cleaned track, `sensor_gps`
retired; no logger fix in the trail more than 5 km from a recorded ping at the same moment.

## 99. The whack test does not test interpolated positions against recorded ones
**status:** open · **see:** TODO 98, TODO 88, `curate/ais_ping_clean.R`, decision 067

`ais_ping_clean.R` runs the impossible-step test on recorded positions only, since an interpolated (`reconstructed`)
position was assumed to lie on the track. When the track it was drawn from differs from today's, it does not: vid
2173's logger fixes ran up to 270 km beside ASTD's. Found by a check outside the flow: each reconstructed fix against
the recorded pings at the same moment (bracketing pings within 15 min, linear interpolation), flagged over 5 km. On
the trail before the 2026-10-20 rebuild it flagged 2,095 of 26.8 M logger fixes, and 861 of 22.0 M after it, nothing else,
all years in about two minutes
(`$FISHYDATA/archive/2026-10-todo98/scripts/gps_scope.R`). Proposed: that test in the cleaning step, as a flag on
any reconstructed position, generic for ramb (`rb_flag_ping_*`), whatever TODO 98 decides for the logger.

The per-vessel speed ceiling measured here (vid 1417; 132,380 steps over the vessel's own ceiling) is now in TODO
88 (decision 185).

**check:** the cleaning step flags a reconstructed position away from the recorded track; zero such fixes on the trail.

## 100. The logbook's sensor readings: what they measure, and whether they can time a haul
**status:** open · **needs: maintainer** — is this worth a product, and which sensor tables to read · **see:** TODO 98,
`curated/logbook/sensor_gps`, `raw/oracle/afli/toga.parquet`, `raw/oracle/afli/lineha.parquet`

The maintainer's idea (2026-10-20): a gear sensor, such as the headline depth, shows when a trawl goes down and comes
up, and so could check the logbook's t1-t4. Measured the same day, read-only, in the logger (`sjalfvirkir_maelar`,
2008-2023, about 250 vessels a year): `botndypi` is the echosounder's depth under the vessel (filled 97-99 % at every
speed, steaming too; follows GEBCO, median ratio 0.95-0.98; longliners and purse seiners have it; pelagic trawlers
none). `hofudlinudypi` (headline depth) is next to empty: 19,264 fixes of 1-2 vessels in 2010-2013 and 2017, a copy
of the bottom depth in 2010-2011; no longliner. Its hauls carry t2 and t3: in 2012 (about 700 hauls, pelagic) the
headline is 71 m in the half hour before t2, 132 m between t2 and t3 and 9 m in the half hour after t3, the gear
coming up; 2013 weaker (114, 104, 58 m); 2017 (one deep pelagic trawler, 580-680 m) no step. A test set for the
tow windows, not a general check.
`botnhiti` (filled 82-100 %) does not step when the gear reaches or leaves the bottom (2015 OTB: change between fixes
across t2 or t3 the same as inside the tow, median 0; same level inside and outside), so it is not on the gear;
the hull's sea temperature, most likely, which is not checked. So the logger cannot time a haul beyond its speed.

Not yet read: the per-haul sensor values of `afli.toga` and `rafr_toga` (headline depth and temperature at the start and
end, bottom and surface temperature, the sensor `nemi`, doors, headline length), `lineha` (bottom, surface and air
temperature) and `fs_afladagbok.ws_veidi` (depth at start and end). They cannot time a haul either, but may tell a
pelagic tow from a bottom one, and bottom depth and temperature per haul are environmental data in their own right.

**check:** decided whether the sensor readings become a product or a QC check, and recorded which column measures what.

## 101. Allocation errors the audit finds: the fixes chosen (decisions 155, 199)
**status:** open · **see:** decisions 155 and 199, `curate/checks/allocation_audit.R`, plan 038 (§5.1, §7.1), TODO 90

`check_allocation_audit` tests every link the flow makes against the records' own times (decision 155). The maintainer
chose the fixes on 2026-10-23 (decision 199); each is built as a step with a scratch build and the catch traced:
- stations deleted in the source (352, 4,238 t) out of every sum and link, kept in `station_fate` as deleted;
- pelagic transfer trips (2,548 trip-species landed 2-300 times their log) flagged and not raised: the excess landed
  weight to an outcome of its own in `ais_catch`;
- `voyage_gear` deterministic (tie-break by kilograms, then gear code; `gid` and gear class from one row; a count of
  gear labels per voyage), with the AIS batch;
- catch on stations with no window (57 t, 43 stations) to the vessel-day or trip unit (plan 038 §7.1);
- a flag in the merge on stations dated outside their trip's days (3.5 % adb, 3.0 % fs_afladagbok);
- the two landing-to-voyage rules compared in the audit (`voyage_gear`'s window + 7 days, `rb_link_trip_landings()`).
Parked: the audit as a generic ramb tool, until plan 038's phases are built. Answered elsewhere: the trail's trip from
one voyage (plan 038 step 2, decision 193); station times in port calls (decision 197, TODO 81).

**check:** each chosen fix built (or declined in a decision), and `allocation_audit.parquet` read after the rebuild.

## 102. Logbook trips that overlap another trip of the same vessel
**status:** open · **see:** plan 031 §3.11, decisions 094 and 155, TODO 101

Found 2026-10-20 (plan 031 step 4), read-only: trips of one vessel and schema that overlap another by over an hour,
twins (decision 094) left out: afli 21,220 (1.3 %, 4,092 with three or more others), fs_afladagbok 4,116 (2.7 %, mostly
2022-2025; vids 2880, 2400, 2657, 2328, 1831 most), adb 624. vid 7373 logs up to seven trips a day on 2023-04-30 and
05-01, one jigging haul each and 0-0.01 t, before the coastal jigging season and with no landing; the track is in port.
Counted as pairs (decision 155's session, `$FISHYDATA/archive/2026-10-voyage-gear/scripts/multigear.R`): afli
40,051 pairs on 979 vessels, fs_afladagbok 3,321 on 686, adb 449 on 184.
Such trips cut port calls in plan 031's R2 (679 cuts) and make tied multi-gear voyages (16 of 323). Not known: which
are resubmissions decision 094 misses, several boats' logbooks under one vid, test entries, or real overlaps. A
session to classify them was proposed on 2026-10-20 (read-only; overview links per class).
Decision 094's open ends belong here too: its 6,035 same-time stations, which their equal times cannot place apart,
and 148 resubmitted fs_afladagbok trips with a later arrival (median 6.5 h), where which arrival is right is untested
(Claude's audit of 2026-10-23, not checked by a person).

**check:** a decision or correction says what the overlapping trips are, by class with counts, and how the flow
treats each.

## 103. Logbook set times that are a logbook app's placeholder, not the skipper's
**status:** open · **needs: maintainer** — send the Trackwell draft and record it (chosen 2026-10-23) · **see:**
decisions 157, 158 and 198, `curate/corrections/logbook_set_placeholder.yml`, plan 031 §3.11 and asks i-k,
`$FISHYDATA/archive/2026-10-todo103/`, `$FISHYDATA/archive/2026-10-plan035/` (the draft, `trackwell.yml`, kept out of git)

Origin found and corrected (decisions 157, 158): Trackwell's app (Fishing Log 2.7, from 2014) sends the static-gear set
time as the haul start less 270 or 1,710 min; those `t1` are NA and flagged since the rebuild of 2026-10-21. Nothing
fills the set (plan 035 failed its test).

Decided 2026-10-23 (decision 198): slow drift during a soak is not fishing on the vessel's fixes unless hauling-like,
on every static voyage (about 201 k h longline and 47 k h gillnet less); built in `R/trail_sql.R` with the AIS batch.
Left: that build; the other placeholder patterns (a set copied from the departure, the haul times or 00:00), left as
recorded by the maintainer's choice; the gillnet set times in a port call with no pattern (9-40 % of recorded sets, unexplained);
the draft to Trackwell (now leading with the logger, TODO 98) sent or dropped.

**check:** decision 198's rule built and the trail's `fishing_flow` traced before and after; the gillnet set times in
port explained or listed;
`trackwell.yml`'s `sent` filled or the draft dropped.

## 105. A date-only haul's day window, stretched past midnight along its fishing stretch
**status:** open · **see:** decision 092 (`rb_cut_record_stretches()`, `rb_link_record_stretches()`), decision 091 (one
fix, one record), `$FISHYDATA/archive/2026-10-todo98/scripts/` (`day_expand.R`, `day_expand_smooth.R`)

Every one of the 2,438,223 date-only hauls has the window 00:00 to 00:00. Scoped 2026-10-20 with raw speed (2010, 2015,
2021): 1.1-2.4 % of those with pings cross midnight into unclaimed fishing pings, a median 0.6-0.8 h, 90 % within
3-4.5 h; purse seine and trawl often, hand line and gillnet rarely. Proposed: stretch the day window along the fishing
stretch it sits in with ramb's stretch functions, the day as the prior, one fix one record. Not redone with the ±10 min
smoothed speed. The maintainer: reported `t2`/`t3` are not truth; the independent witness proposed is the research
survey tows: channel (41 of 42, one view broken in Oracle) and biota (96 of 96) are dumped and in `raw/oracle/` since
2026-10-21 (decision 159).
Not all day windows are date-only: 994,500 afli tows (198,373 from 2007) hold a timed start and no end and still get
the day (decision 083 (b): ramb needs an end or a duration); counted 2026-10-23 by Claude, not checked by a person.

**check:** the stretch measured with the smoothed speed and against the survey tows, and built or declined in a decision.

## 107. App-made fixed values left in the logbook times, static and towed gear
**status:** open · **needs: maintainer** — the drafts' decisions · **see:** decision 157, TODO 103,
`$FISHYDATA/archive/2026-10-time-offsets/`, `$FISHYDATA/archive/2026-10-time-offsets-towed/`

Measured 2026-10-21 by Claude, read-only, in two side sessions (not yet checked by a person), each with a decision
draft (not committed): after decision 158, static set times still sit on a half-hour grid computed from the haul
start (about 32,600 stations), at 24 h (5,315) and beside the 270-min placeholder (3,023); haul lengths are rounded
to whole hours at entry. Towed gear: the paper logbook's tow times are the skipper's rounding (42 % of starts on the
hour), the electronic logbook holds a few app dummies. The sent XML holds the same values (TODO 115, from 108): they can be
flagged, not recovered from it. A defect beside them: adb's `duration_m` is empty on its trawls and dredges (32,329
OTB, 1,367 OTM, 2,174 DRB), since the adapter computes it from `tow_start`, which adb leaves empty.

**check:** each draft decided and recorded (correction, flag or no action), or declined in a decision.

## 110. The Oracle dumper's open ends after the run of 2026-10-21
**status:** open · **see:** decision 159 ("The run of 2026-10-21"), decision 167, `R/run_dump.R`, `R/dump_oracle.R`,
`dump/oracle/fs_afladagbok.R`

`all.R --resume` skips a schema whose last run exited 0 with nothing failed, and `.dump_finished()` counts a
deliberately skipped object as finished: orri, uv and fs_afli were skipped although decision 159 had opened tables
in them (done by hand with `run_dump(..., resume = TRUE)`). It should count a schema unfinished whose overview lists
an object as skipped that its script no longer skips. And `fs_afladagbok.takt_json_form` (6,912 Taktikal JSON forms
with a file) is not dumped: a CLOB with NUL characters, which the NUL fallback strips from VARCHAR2 and CHAR only.
The overview rows of `stk.trail` (20,681,877 of 303,795,653 rows) and `afli.sjalfvirkir_maelar` are still stale after
9ef7596 (decision 164): recompute or re-dump. `simalinu` was dumped through RJDBC with `dirty = true` (decision 162):
a server run replaces it. The next dump run also makes decision 196's three read-only STK reads (`ALL_SEQUENCES` for the
trail's sequence, `ALL_OBJECTS.CREATED` for its trigger and sequence, a count of `stk.trail`). Decision 167's two files are done: kvoti and ops_einarhj were re-dumped on hafdruna and
adopted on 2026-10-22, DuckDB reads both whole and kvoti has its `_data-dict.yaml`
(`$FISHYDATA/archive/raw-oracle-redump_2026-10-22/README.md`).

**check:** a test on the stand-in shows `--resume` dumping a table taken off a skip list; `takt_json_form` dumped
(its JSON whole) or left out in a decision; every partitioned table's overview row equals its files.

## 111. `docs/output-schema.md`'s four column tables: retire them for `docs/data-dict.yaml`?
**status:** open · **needs: maintainer** — whether the page's column tables go and its other sections stay ·
**see:** decisions 029 and 188, item 94

The curated logbook tables (`curated/logbook/{trip,station,fishing_sample,catch}.parquet`) are described column by
column twice: in `docs/data-dict.yaml` (decision 029), which `data-dict validate-meta` checks against the files, and
in the four column tables of the book appendix `docs/output-schema.md`, carried over from the predecessor repository
and written for afli and fs_afladagbok. The dictionary was brought up to the build at de25239 on 2026-10-21 (all 94
columns, the ten of plan 026 among them); the page's tables list fewer columns than the files hold. Two copies of one
fact drift (AGENTS.md).

Proposal (Claude, 2026-10-21): delete the page's four column tables, and the paragraphs above them that repeat the
dictionary, and point to `docs/data-dict.yaml` for the columns. Keep what the dictionary does not hold: the renaming
dictionary (`wk_translate()`), the timestamp population by schema and gear class, the effort units by gear class,
the duration caps, and the afli `aggregate.parquet` section. Also open: whether the book should carry the dictionary
as a page of its own (`data-dict render` writes one self-contained HTML page), so that the book's readers still see
the columns.

**check:** the maintainer has decided; `docs/output-schema.md` then holds no column table that `docs/data-dict.yaml`
describes, or a decision says why both stay.

## 112. The catch's disposition, code 159 'Gámur/Sigling' and agf's `afdrif`, carried to the trip (plan 036)
**status:** open · **needs: maintainer** — plan 036's seven asks (§5), above all b (the 159 landing kept apart and
joined to its trip, or folded into the home landing) · **see:** `curate/plans/036-catch-disposition.md`,
`$FISHYDATA/archive/2026-10-landing-disposition/`, TODO 81, plan 027, decision 031

159 is not a port but what became of the catch: exported unprocessed in a container, or landed abroad (the maintainer,
2026-10-21). LODS keeps that part as a landing of its own at 159 to 2013-08, 717 kt over 1992-2013; agf records it per
row as `afdrif` U from 2013-09, and lacks it before. The study found no double counting: agf equals LODS's home
landing on 4,439 of 4,447 shared vessel-days, and the logbook's catch is 1.004 times home + 159. fishycode drops
`afdrif`, gives 159 no name, and `lid_map` leaves the 159 part off 4,073 trips (107.6 kt).

**check:** the asks answered in the plan; landings, trips and their catch carry a disposition with a basis, landed kg
unchanged, and those trips' logged over landed near 1.0; or the plan parked or abandoned in its header.

## 115. The most upstream source, value by value, through the grammar (plan 037)
**status:** open · **see:** `curate/plans/037-the-most-upstream-source.md`, `docs/grammar.qmd`, decisions 158, 160,
162, 180 and 189, TODO 110 and 118, `$FISHYDATA/archive/2026-10-plan037/`, `2026-10-xml-oracle-map/`

The maintainer's principle (2026-10-21): each value from the most upstream layer that holds it, when it states its
unit and keeps more or known precision; a resend or an in-house edit, being later and deliberate, wins. afli's
electronic logbook has three layers (sent, loaded, edited): one adapter per layer into the grammar's tables, the choice
per field group only in `curate/`, the layer beside the basis. Every ask of §7 is answered (f-h 2026-10-23, decision
189). The sent layer (`sources/afli_sent/`) is in the store since decision 180, read by nothing in `curate/` yet. Next:
phase 1 (the precedence table, the provenance column, consumers reading the whole weight by name), then phase 2.

**Phase 2 closes three folded items** (decision 189; measured 2026-10-21 by Claude, not yet checked by a person):
- **TODO 108:** the sent end position (`POS_END`, 814,598 afli stations; `afli_end_longitude` retires), start
  positions to the arc-second (805,383), west longitudes Oracle turned east (905), the Danish seine's tow time Oracle
  lost (`TOGTIMI`: t3 back on 99,028 of 106,045), the soak unrounded (`KLST`: `duration_m` too long on 61,992
  longline and 4,215 jigging stations), each record's closing time (`FAERSLA_LOKUD`); the draft correction in
  `$FISHYDATA/archive/2026-10-xml-positions/draft/`, the towed times in `../2026-10-time-offsets-towed/`.
- **TODO 113:** afli's end depth `z2` is 1.83 times the sent metres on 946,197 electronic stations (Oracle kept
  `DYPI_LOK` in metres; `afli_depth_units.R` converts it as fathoms, decision 022): both depths from the message, the
  per-vessel test kept for paper records and for Fishing Log 2.6 in 2010-2012.
- **TODO 114:** on 2.65 M afli catch items logged gutted, round(gutted × 1.25) is labelled `recorded`; the weight as
  logged and its state are in every sent item.

**check:** each phase built or declined in a decision, or the plan parked or abandoned in its header; with phase 2,
afli's end positions, tow times, soak and closing times from the sent record (or declined), `afli_end_longitude`
folded in; `z1`/`z2` of afli's electronic stations equal the sent metres, `afli_depth_units.yml` saying which it still
converts; every logbook catch row carries the weight as logged, its state and the whole weight, `derived` where computed.

## 116. STK units with no vid: from the archive study to the key
**status:** open · **needs: maintainer** — decision 161's D1-D10, and whether "not before plan 021 step 6" means step 4
(the vids come from step 4) · **see:** decision 161, `$FISHYDATA/archive/2026-10-stk-unlinked-units/`, plan 021 step 7,
TODO 25, 65

14,709 key units (27.9 M pings) have no vid, each in one outcome; mostly foreign, named by the global id. They are not
ready for the vessel list: no route leads from an STK unit to a hull, and the ledger is empty. After the first
allocation (TODO 65) the hulls of 6,360 of them have vids; their units link only at a `once` redo. Before it, the
classification becomes a `once` check on the crosswalk's keys, and Claude drafts the review lists (D2, D3, D4, D7, D10)
for the maintainer to confirm into `overrides/`.

**check:** every key unit with no vid has a row and an outcome in the check; the redo's decision says which got a vid,
which await review, and which stay `unkeyed` with a reason.

## 117. What the flow takes from STK beyond the position: events, receipt time, `U` positions
**status:** open · **needs: maintainer** — outside only: the questions for STK (§12 decision 10) · **see:** decisions
164 and 196, `$FISHYDATA/archive/2026-10-stk-trail-order/README.md` §12, decisions 059 and 075,
`sources/stk/event.R`, `curate/port_call.R`, TODO 68, 88

STK's `I`/`U` rows are events, not track fixes: `U` positions sit at regional port markers and `I` jumps inside their own
harbour. The events are clean in 2004-2011 and from 2017, noisy in 2012-2016, the junk per unit, so `EVENT_FROM` 2017
and the dropped jump test rest on 2017 on only. To decide: a `stk_receipt` side table (receipt time, lag and identity
classes) or nothing; `U` positions kept out of the whack and the track; the event cut as a year, a jump test or a
per-unit screen; port calls from `tilk_stk` for 2004 to mid-2007; the Oracle reads and the questions for STK.
**Decided 2026-10-23 (decision 196):** I/U rows are events, never fixes (a `U` position or one at a shared marker never
reaches the whack or the track); `stk_receipt` as a side table, the lag a label; events screened per unit, not cut at
2017; port calls for 2004 to mid-2007 from events; dwell from the commercial AIS in port, else the I → U pair; each unit's
class in `stk_receipt`; the three Oracle reads in the next dump run (TODO 110). Each is a step of its own, scratch first.

**check:** each decision recorded, and what is chosen built or declined.

## 118. afli's hauls in a layer but not in `afli.stofn`: loaded but never moved, and sent but never loaded
**status:** open · **see:** plan 037 §2.1, TODO 75, decisions 098 and 189

Of the records Oracle loaded, 26,695 in afli's `rafr_stofn` never moved to `afli.stofn`: 3,182 deleted, 23,513 not,
and why is unexplained. The sent layer stages all of them, so once it is read they enter the logbook unless
explained. Some may be a haul loaded twice; some genuinely missing hauls (as TODO 75's lost trips). Decision 098
already ruled on these hauls (23,570 live rows absent from `stofn`): not admitted, since adding them overshoots the
landing and most are the same hauls submitted again. Also open from decision 171: whether adb's 243 stations before
2025-11-19 with no counterpart, and the 14 `TRACKWELL BAEKUR` and `PAPPÍR` trips decision 160 removed, are in afli's
adapter's output (both added from Claude's audit of 2026-10-23, not checked by a person). Decision 098 holds in
phase 2 (the maintainer, 2026-10-23, decision 189).

**Sent but never loaded** (plan 037 ask f, decision 189): 14,759 records of the sent messages that Oracle's loader never
wrote into `rafr_` (168 vessels, 2001-2022, 142.8 kt as logged), staged with `loaded = FALSE` and kept out of the
logbook. Measured 2026-10-23 by Claude: 2,890 (31.7 kt) on a vessel-day the curated logbook holds, likely copies; about
11,650 (111 kt) on vessel-days it lacks, and 7,771 of those with catch have the vessel's landing within 0-3 days; 10
dated 2096-2099.

**check:** each of the 23,513 in one outcome (a copy of a moved record, a missing haul, unexplained), judged by
decision 098's rule or by a decision that overturns it; each of the 14,759 never loaded in one outcome (a copy of a
held haul, a missing haul, unexplained) and its admission decided per class; and the sent layer stages no haul twice.


## 122. The logbook flow, whole: from each source to its catch on the fixes (plan 038)
**status:** open · **see:** `curate/plans/038-the-logbook-flow-whole.md` (asks answered 2026-10-23, decision 191),
decisions 155, 172-174 and 180

Plan 038 places every open piece of the logbook flow in one order: the sources and their layers, the merge, the trip ↔
landing link, the reconciled trip, the stations on the fixes, effort and catch. Each piece keeps its own TODO item.
It designs two things no record does yet: what reads `trip_reconciled` (decision 174's open end), and every logged
kilogram in one catch unit and one outcome in every year. 54 % of the logbook's kilograms are logged before 2007 and
are in no unit (measured 2026-10-22). Also measured: 6,991 tour-app trips (9.2 kt) on vessel-days no curated source
holds. That is TODO 73's unread tour app, not decision 160: adb's 9,374 `APP TÖFLUR` trips carry 428 stations and 2
catch rows, so the catch never came in through adb (counted 2026-10-23 by Claude, not checked by a person).
For the sources' layer: decision 057's duration limit runs inside three adapters (afli, afli_sent, fs_afladagbok), a
correction outside `curate/`, and fs_afladagbok's then blanks the recorded end time behind it (`duration_m_raw` keeps
the span) (Claude's audit of 2026-10-23, not checked by a person).

Next (§8, decision 191): step 1's instruments (TODO 79), then step 1b, `lid_map`'s lower bound lifted, which ends
2007's double count on the fixes; then `trip_reconciled`'s build with its multi-voyage fix (coded, decision 193:
16,184 trips spanned, 24,813 flagged; the command in the record) before its five readers switch.

**check:** each of its phases built, or declined in a decision; the plan executed, parked or abandoned in its header.

## 123. The landings flow, from the first record to now: one cascade, the same output in every period (plan 039)
**status:** open · **needs: maintainer** — outside asks only: who at the Directorate knows what feeds LODS 1 and agf
since 2020 and whether agf's factory-vessel live weight is the yield measured on board (plans 023, 025), and a DBA or
KVOTI's owner to run `$FISHYDATA/archive/2026-10-ivln/get_source_ivln.sql` · **see:**
`curate/plans/039-the-landings-flow.md` (asks answered, decisions 191 and 192), plans 007, 023, 025, 036, 037 and 038,
TODO 112, 119, `$FISHYDATA/archive/2026-10-lods-upstream/`, `2026-10-landings-flow/`, `2026-10-fiskifelagid/` (period
0's tables with a draft overlay; parked by the maintainer 2026-10-22, its asks a-f in its README §9)

Plan 039 sets the landings' layers period by period, with a basis and a layer on every value and one output shape:
vessel-month totals for 1966 to 1992-08 (`fiskifelagid`, `vor`; built when unparked); LODS 1 with the container
tables to 2007-08, and ask's columns in July and August 2007; agf with ask's columns to 2020-07-22 (plan 025 §4); agf
alone after (the maintainer, 2026-10-22: "that is life"). Every ask is answered (decision 192): LODS's conversion of
its time, lumpsucker's roe with the whole fish derived (2006's factor carried back, flagged), the exports from the
container tables, a `provisional` flag on the last two years, `kvotix`'s logs measured first. `lid_map`'s 2007-09-01
bound is lifted as plan 038's step 1b (decision 191). Nothing built.

**From TODO 74** (decision 192): plan 023 §3 is superseded by plan 039 and plan 025 §4 taken into it. Plan 007's
questions: 1, a report of every landing where agf and LODS disagree (agf wins, so the merge cannot show an agf
defect), carried by plan 039 §5's witness account; 3, `link_lid_map.R` and `catch_by_species_trip.R` keyed on
(`.lid`, `schema_land`), plan 038 step 3. Plan 023 §6's fifth source of a landing's trip, the line-incentive check's
link of 154,146 landings to STK events (decision 163; 9,716 arrivals at another time, 7,446 landings with no logbook
trip, unexplained), builds on plan 022 §4 (TODO 68).

**check:** every period's landings in the same columns with a basis and a layer, and each layer's landings and
kilograms in one outcome per period (plan 039 §9); plan 007's questions 1 and 3 answered in a decision; or the plan
parked or abandoned in its header.

## 124. What each column means, in its metadata: units, formats, precision and codes (plan 040)
**status:** open · **needs: maintainer** — plan 040's asks b-f (§6; a answered, f implemented in its reversible form)
· **see:** `curate/plans/040-metadata-at-three-layers.md`, decision 176, `dump/oracle/meta/README.md`, decision 188, TODO
110, plans 037-039

Phase 1 is built (decision 176): the overlay `dump/oracle/meta/<schema>.yml`, merged by the dumper and by
`rewrite_data_dict()`, and checked at a dump's adoption by `check_data_dict()` (`dump/oracle/README.md` §11). The 28
raw dictionaries were rewritten with it on 2026-10-22: all valid, every check of the eight overlays (kvoti, adb, afli,
dw, stk; agf, ask, vessel) as described. Phase 2 is inside plans 038 and 039; the curated layer after them.

**check:** the asks answered in the plan; or the plan parked or abandoned in its header.

## 125. The vessel overview after the rebuild: the reconciled trip, the landing's origin, two checks left
**status:** open · **see:** plan 030 §7, decisions 169, 173, 174, 177-180

Left by the overview's session of 2026-10-22.
- **The reconciled trip**, `curated/link/trip_reconciled.parquet`, built 2026-10-22 (decision 180):
  - each trip's departure and return, time and port, with the witness that gave each, beside the logbook's T1 and T2;
  - the trip's band on the chart from them.
- **The landing's port of origin**, lods' `hid_origin` (decision 169), on the landing lines; the landings carry it
  since decision 180.
- **Not checked in the browser pane**, which was hidden: Play, and the map's tooltip. A person should try both.
- **On hold (maintainer):** a hexagon colour scale pinned across vessels, as the History axis is.

**check:** the trip table and chart show `trip_reconciled`'s times and ports with their witness; the landing lines show
`hid_origin`; Play and the map's tooltip tried by a person; or each declined in a decision.

## 126. The logbooks' positions: what each haul end holds (a point and its precision, a cell, or nothing), by source
**status:** open · **needs: maintainer** — the representation below, and the AIS check's go · **see:**
`$FISHYDATA/archive/2026-10-afli-minutes60/README.md` (scripts 01-10), TODO 115 (from 108), 124, plan 040, decision 165,
decision 180, `R/logbook_position.R`, `curate/corrections/afli_coords.yml`, `afli_end_longitude.yml`

Found 2026-10-22 from the rebuild's `error > 60 min` lines (decision 180), measured with the maintainer:

- **afli:**
  - a rectangle-only record until the mid-1980s (1950-84: 87 % of stations have no position, only `reitur`; never
    filled in at a centre); the changeover is 1985-89, when the quarter (`smareitur`) appears;
  - manual entry (paper) varies by record: hand rounding to 10 minutes, about 1,200 rectangle-centre fills (1990s
    mostly), 61-99 "minutes" (about 1,600, unexplained: the rectangle cannot decide, and at the quarter they look
    like neither reading);
  - the `rafr_` loader rounded electronic positions to the minute, so exactly 60 means no carry, and the sent record
    holds the arc-second (TODO 115, from 108);
- **e-logbooks** (fs_afladagbok, adb):
  - precision by app and year: whole minutes (the old TRACKWELL route), seconds (Trackwell raun and most later apps),
    mixed within Taktikal and Jóhann Gíslason, hundredths on Taktikal and Marína 2023;
  - STOKKUR (2021-22, 23,362 stations) reports whole degrees, a cell's corner; no app reports centre points;
  - end positions are missing on all stations for most apps;
  - decision 165, left open: fs_afladagbok's adapter reads all 7,710 kept Marína stations as hundredths, a trip with
    a carried 60 too (23), and leaves 59 with a 4-5 digit longitude past 30° (Claude's audit, not checked by a person).

Proposed:
- each end kept as reported: a point with its precision; a cell (whole degree, rectangle, quarter) with lon/lat NA and
  the cell recorded; or nothing, basis "none";
- a derived centre only in a column of its own, and a per-row column naming the kind and precision;
- the formats and precision by source, app and period in the overlays (plan 040; a new fs_afladagbok overlay);
- per-app checks in `curate/checks/`.

Open: corner or midpoint, truncated or rounded, for the whole degrees and the centre fills, and the 61-99 values,
judged against the vessel's AIS track that day (the maintainer). A diagnostic; logbook positions never join the track.

**check:** each source's ends in one kind (point, cell, none), with counts by source, app and period; the overlays
state the formats and precision; the AIS check reported.

## 127. Names in the grammar and in ramb: the review of every noun and act (pending)
**status:** open · **needs: maintainer** — the review, rule by rule and item by item · **see:**
`docs/grammar.qmd` (section "Names under review", and the parts of "Resolution and provenance" drafted 2026-10-22),
`docs/one_flow.qmd`, ramb's `AGENTS.md` (naming), decision 147

Drafted 2026-10-22 with the maintainer, who asked for a review of every process, abstract and independent of the data,
with verbs and nouns that match. In the grammar:
- six rules: one word per concept; the part of speech by job (verbs for functions, nouns for things, participles for
  how a value came to be); one root through verb, noun and participle; mirrored acts paired; a name in use changed
  only for a clash or a synonym; plain words;
- the acts, each with verb, noun, participle and mirror;
- seven clashes (event, reconstructed, sample, set, unit, window, allocation);
- eleven synonyms (`station_type` and `resolution`, ping and fix, track and trail, share and split, …);
- two mirrors reserved (decode, thin).

Also for the review: decision 012's `entity_class` basis disagrees with the grammar's table: a name pattern (a rule)
is `reconstructed`, a matched vid (another source) `recorded`, the hand list `synthesised` (Claude's audit of
2026-10-23, not checked by a person).

Decided: **split** for an additive total divided by a key (the maintainer), so `rb_share_catch()` is to become
`rb_split_catch()`. Nothing is renamed yet.

After the review: the grammar's text follows (three clashes are in its own new parts: sample, set, unit); then the
one-flow document's sketch and summary ("The grammar, in brief") and the cascade diagram; then ramb's renames, each
with an alias for a release, as in decision 147; then fishycode's columns and AGENTS.md's terms.

**check:** every item answered in the grammar's section, the section's callout removed, and the renames listed in a
decision.

## 130. The species reference's unmatched lists: a person's read of the 30 codes
**status:** parked · **needs: maintainer** — paused 2026-10-23 at the maintainer's word · **see:** decision 182

`curated/reference/species.parquet` takes a code's values only from the lists that mean the same taxon as its first
list (ufs, else orri). On 30 codes a list could not be matched: its values are kept in the `_other` columns, never
taken (`lists_unmatched`). Read by Claude on 2026-10-23, not by a person, they fall in three groups: another species
under the code (278, 953, 445 in afli, 165, 901, 556, 613, 905, 162, 409, 410, 645; unsure 641, 236, 213), a
catch-all or another rank (55, 29, 184, 20, 50, 147, 190, 324, 658, 732, 316), and the same name the matching rule
missed (185, 271, 738, 1035). Only 9 are in the catch tables, and of weight only the catch-alls 55, 29, 184 and 20.
To answer per code: which list is right, and whether the third group's lists should be taken.

**check:** each of the 30 codes answered in decision 182, and `reference/species/species.R` changed where an answer
says so (a list taken, or a code's note).
