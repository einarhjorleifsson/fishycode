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

## 25. The next STK key redo (`once` project): the review lists
**status:** open · **needs: maintainer** — the go for the redo's build, once its code is in (review done 2026-10-23) ·
**see:** decisions 128, 195 and 204; plans 009, 016 §4 step 7, 021 step 7, 022 §3 and §7; decisions 047 and 075;
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
to about 2013-11-13), 101780, 108629, and decision 204's 50 "no vessel" rows; later: 6 undecided, two MMSIs.

**check:** a decision record states the redo; every row of lists 1-5 resolved through `overrides/` or a stated reason;
`ais_key_coverage` at 0 unassigned pings; no `once` script reads a view; no MMSI window opens before its hull's first
register date, MMSI 251764110's gap pings on 2608, and 3009 and 7764 resolved or stated; **proposed:** that cross-check
rerun after each redo, every same-track or partial case settled or stated; decision 204's rows in `overrides/`.

## 27b. Link pings to trips and fishing activity (the `trail`), and deliver from it
**status:** in progress - phases 0-3 built; the trail rebuilt 2026-10-16 (decision 112) · **needs: maintainer** —
the metier (TODO 131, 133, parked 2026-10-23) and its mapping to icesVocab at delivery, with which list decides (decision 212), and plan 015 §4 b-d and i (e-h answered, decision 202) · **see:** `curate/plans/015-datacall-on-the-curated-trail.md` (the datacall), `curate/plans/010-ping-activity-link.md` §7, §10-§12b, decisions 095 and 118

Built: `gear_window`, `station_window`, `curated/ais/trail` (AIS + the gps logger feed, plan 014), with the voyage's
trip (`.tid_voyage`) on fixes outside every window. Open: the datacall. `products/ices_vms_datacall/build.R` is the
2025 delivery script with only its paths changed, and it cannot run here (checked 2026-10-14). It reads columns the
current `ping_union` does not have (`.sid`, `s1`/`s2`, `t1`/`t2`, `met6`, `dt`, `dd`, habitat, depth, catch per fix),
a `station-for-ais.parquet` nothing here builds, and `agf_gid`/`met6` that `gear.parquet` lacks.
Repointing it means building its inputs from the curated tables. Built since 2026-10-14: the trail's `fishing`
(decision 093), `hours` and `kw_hours` on each fix (decision 101), and catch per fix in `curated/ais/catch` (decisions
101-102). Not built: metier 6 (the trail's `metier` is the house label gear + target2; a rule with a basis per operation is
proposed in plan 015 §4 a revised, from Claude's read-only study in `$FISHYDATA/archive/2026-10-metier6/`), swept
area from distance and gear width, habitat and depth by spatial join, and the logbook (LE) table without duplicate twins.

Plan 015 designs it, checked against the 2025 delivery. Also open: whether to store a sorted wide trail (maintainer).

**The old trail stays until then (from TODO 8):** `~/stasi/fishydata_2024-2026/data/ais/trail` (31 GB) is the input of
the 2025 delivery (`ices-datacall/2025/2025_vms-datacall.R` reads it), and the delivered CSVs are not kept locally. It
reproduces that delivery and is the baseline for the comparison. Removed and restored on 2026-10-14 (decision 095).

**check:** `products/ices_vms_datacall/build.R` runs on `curated/ais/trail`, its output is compared with the 2025
delivery and supersedes it, every synthesised window carries `win_basis`, and no directory under
`~/stasi/fishydata_2024-2026` exceeds 1 GB.

## 34. Trawl speed ranges near the coast: ask (1) of plan 012
**status:** blocked (the regulation and shoreline shapefiles, coming) · **needs: maintainer** — the shapefiles; the gillnet floor answered 2026-10-30, 0.2 kn (plan 054 ask o), built with its live rebuild the same day in
`reference/gear/windows.R` (gid 1-4, 22; decision 265) · **see:** `curate/plans/012-speed-range-vs-logbook-window.md` (§2e-§2m), `curate/corrections/logger_speed_placeholder.yml`, decisions 085, 093 and 201

Measured: the declared speed range per trawl gear keeps 88-92 % of fixes in recorded tow windows; kW, length and age explain under 5 % of towing speed; a vessel's own range gains nothing over the gear's; shifting the gear range by last year's vessel offset gains 0.2-1 point overall and 4-12 points for the tenth of vessel-years with a large offset; the logbook gear agrees with the landings for 93-99 % of trips. Built from the plan: step 0 (the logger placeholder fix) and step 4 (the gear codes on the trail, decision 085); steps 1-2 were not taken up (decision 093).

**Asked of the maintainer:** (1) whether fish-trawl tows of small vessels near the coast are permitted, so a flag can say "suspect" or "expected", and where a baseline or fjord polygon can come from (5 km from the coast is a stand-in). The same baseline serves the plan's step 5, the 12-mile limit. **Answered:** (2) the declared ranges stay, and `fishing` tests the ±10 min median speed instead of a vessel-shifted range (decision 093); (3) the gear codes on the trail (decision 085).

**The gillnet floor, measured 2026-10-23** (plan 012 §2m; Claude's, not checked by a person;
`$FISHYDATA/archive/2026-10-todo34-uv-areas/`): every gillnet fix in one class; the recorded hauls' p01/p05/p10 are
0.16/0.35/0.48 kn. 0.2 kn recommended: it loses 1.85 % of the fishing haul fixes and stops 98 % of the fishing fixes
in port calls and 23-29 % of the voyage rule's on soaks and haul-less voyages. A `uv` note is kept in `uv_note/`.

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
Oracle, plan 018), an adapter in `sources/` stages them, and the merge holds the foreign hauls; their catch on the
fixes is the user's (decision 261).

## 65. A vessel registry for every ping, whatever the flag
**status:** in progress · **needs: maintainer** — the first `allocate_vids(dry_run = FALSE)`, by decision 190's
commands from the dry run on (the crosswalk was rebuilt with the complete rebuild, decision 218: 655,202 rows, the
dry run 379,912 hulls); the Directorate of Fisheries (MMSI, §6 d) and PAME
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
**status:** open · **needs: maintainer** — the query in plan 018 §3, at the next Oracle sitting (plan 054 ask n, §7) · **see:**
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
  up to date from Claude's audit of 2026-10-23, not checked by a person. Proposed in plan 057: a tow's start and end
  from each ping's label. The labeller is chosen (decision 270): a hidden-state model of towing and its look-alikes,
  decoded by LaMa; not built. Tested since (2026-11-01, by Claude, not checked by a person; studies in `$FISHYDATA/archive/`):
  on groundfish trawl alone (`2026-11-01-label-covariates/`: decision 270's set held 6,155 dredge hauls) the under-30 m
  class scores best, both ends within 10 min for 45.8 %; 2019's fit holds in 2017, 2018 and 2023 and on unseen vessels
  within 0-5 points, the ping spacing deciding (`2026-11-01-labels-out-of-sample/`); the dredge needs its own fit and
  still joins back-to-back hauls (16 % within 10 min; `2026-11-01-dredge-labels/`). Covariates as one set (maintainer):
  the vessel and its gear are one block, depth varies within vessels but goes with size; no `t1`, `t4` or warp is
  logged for trawl. Next, in order: the commercial splits reviewed (plan 057 §4); the feeds' clocks (TODO 178); the
  speed's spread tried on the trawl; the longline's feature; a year's first voyage kept out of the training labels.

**check:** each of items 4 and 6-10 is built and on the data, or plan 013 says why not, and a decision records it.

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
**status:** open ·
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
- splitting a vessel's pings into chains that are each consistent, e.g. one per STK stream (decision 233, plan 048);
- zigzags judged over a window;
- each leg's displacement against its reported speed and course.

Against ASTD/ASTDB, 2013-2026 (decision 164): 75 % of the removals a witness can test are supported, 2,780 kept pings
contradicted; 63 % of the supported removals are cross-feed legs within 0.3 nm. The prototype
(`$FISHYDATA/archive/2026-10-stk-trail-order/prototype/`, its README §10 five decisions) equals `ping_whacky` with the
defaults; a floor between feeds (0.3 nm) freed 22 % (2016) and 80 % (2026) of the false removals, mostly the clock
(plan 059 step 6: on aligned pings 0.3 nm still frees 71 % and 13 % of what is left, no true removal lost). In ramb
2026.11.01.2 (ad088e3; `feed`, `noise_nm`, `evidence`; no `two_sided`, maintainer), installed, and adopted in
`curate/ais_ping_clean.R` (plan 059 step 8): 0.3 nm between providers on the harmonized time, the evidence on
`ping_whacky` (the prototype's §10 items 4-5, the maintainer, 2026-11-01); in the data with the rebuild.

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

## 96. The vessel demo: Safari, Windows, and the basis for sending it
**status:** open · **needs: maintainer** — a Mac with Safari's remote automation on, or a person, and a Windows machine;
and the agreement under which the folder goes · **see:** decisions 153, 236, `products/exports/vessel_demo.R`,
`vessel_bundle.R`

The demo (`$FISHYDATA/exports/vessel_demo_2018-06/`) was tested from `file://` in headless Chrome and Firefox on macOS
only. Safari cannot be driven without `safaridriver --enable`. Under MFRI's data policy (gagnastefna), confidential data
leave MFRI only on an agreed basis.

Rebuilt on 2026-10-22 from 6b69323 with the page of decisions 177-179, and checked over HTTP in Chromium; the key is
unchanged (the same 30 vessels, numbers and windows). Rebuild it again if the page changes before it is sent; it does
not yet hold the page of decision 236.

The named 2024 bundle (decision 236) was built on 2026-10-28 and moved by Finder to `/Volumes/einarhj` (not seen there:
macOS denied both Claude and the maintainer's Terminal that volume). It stays inside MFRI; who reads it is the share
folder's permissions.

**check:** the demo opens and loads a vessel in Safari and in Edge on Windows, and the agreement it went under is
written in decision 153; the 2024 bundle is complete on the share (2,163 files, 2.2 GB) and loads a vessel from there
in Edge on Windows.

## 98. The afli GPS logger inside the AIS track: what is left once 2020 on is out
**status:** open (decided 2026-10-23, decision 196: re-interpolated in the flow on every build, with a gap limit
measured first; the logger kept in the track, plan 054 ask h, amended; the limit 60 min, decision 251) · **needs:
maintainer** — the next AIS batch's build, and whether a bracket may cross voyages (84,449 fixes at 60 min) · **see:**
decisions 075, 196 and 251, `curate/ais_ping_union.R`, `curate/logbook_sensor_gps.R`, `curate/corrections/logger_whole_degrees.yml`,
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

**check:** the logger interpolated on each build's cleaned track with the 60 min limit (a gap argument in
`rb_interpolate_track()`), `sensor_gps` retired; no logger fix in the trail more than 5 km from a recorded ping at the
same moment (met by construction, decision 251).

## 99. The whack test does not test interpolated positions against recorded ones
**status:** open — for the logger, met by construction once decision 196's step is built (decision 251); the generic
flag stays proposed · **see:** TODO 98, TODO 88, `curate/ais_ping_clean.R`, decisions 067 and 251

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

## 102. Logbook trips that overlap another trip of the same vessel
**status:** parked (plan 054 cut to what matters, the maintainer, 2026-10-30) — classed and the treatments chosen 2026-10-30
(decision 250), not built; left, decision 094's open ends below · **see:** plan 031 §3.11, decisions 094, 155 and 250, TODO 101

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

From TODO 138 (closed by decision 265): 125 Marína trips entered again with other catch, outside decision
094's twin rule (Claude's count, 2026-10-23), parked with this item's twin rule.
From TODO 101 (closed by decision 267): the merge's flag on stations dated outside their trip's days
(fs_afladagbok 3.0 %, adb 3.6 %), parked with this item.

**check:** decision 250's treatments built and traced in a rebuild; decision 094's same-time stations and later
arrivals judged, or declined in a decision.

## 103. Logbook set times that are a logbook app's placeholder, not the skipper's
**status:** parked (plan 054 cut to what matters, the maintainer, 2026-10-30) — the gillnet sets in port listed (decision 249); the
Trackwell draft is TODO 169's; decision 198's drift rule not built ·
**see:**
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
A lead (decision 242): afli's own electronic set times on nets and lines of 2019-2020 miss the set position by the
track on 45 % (far or in port), leaning to a set logged 1-3 h before the vessel reaches the gear: decision 157's
departure copies, or more. By app, 2022-2026: only Trackwell raun writes a set time; the rest copy another time or
a date into `t1`, and 4,798 merged stations still open a set window from it (plan 053, TODO 165).

**check:** decision 198's rule built and the trail's `fishing_flow` traced before and after; the gillnet set times in
port explained or listed.

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

## 110. The Oracle dumper's open ends after the run of 2026-10-21
**status:** open — `--resume` fixed 2026-10-30 (plan 054 step 0, decision 247); the Oracle reads at the maintainer's next
sitting (plan 054 §7) · **see:** decision 159 ("The run of 2026-10-21"), decision 167, `R/run_dump.R`, `R/dump_oracle.R`,
`dump/oracle/fs_afladagbok.R`

Fixed 2026-10-30: `.dump_finished()` reads each script's skips (`.dump_script_skips()`), so a schema whose overview
lists as skipped an object its script no longer skips is unfinished, and `all.R --resume` dumps it again
(`tests/test_run_dump.R`). orri, uv and fs_afli had been redone by hand; on the dumps of 2026-10-30 no overview holds a
skip its script dropped. Left: `fs_afladagbok.takt_json_form` (6,912 Taktikal JSON forms
with a file) is not dumped: a CLOB with NUL characters, which the NUL fallback strips from VARCHAR2 and CHAR only.
The overview rows of `stk.trail` (20,681,877 of 303,795,653 rows) and `afli.sjalfvirkir_maelar` are still stale after
9ef7596 (decision 164): recompute or re-dump. `simalinu` was dumped through RJDBC with `dirty = true` (decision 162):
a server run replaces it. The next dump run also makes decision 196's three read-only STK reads (`ALL_SEQUENCES` for the
trail's sequence, `ALL_OBJECTS.CREATED` for its trigger and sequence, a count of `stk.trail`). Decision 167's two files are done: kvoti and ops_einarhj were re-dumped on hafdruna and
adopted on 2026-10-22, DuckDB reads both whole and kvoti has its `_data-dict.yaml`
(`$FISHYDATA/archive/raw-oracle-redump_2026-10-22/README.md`).

**check:** `takt_json_form` dumped
(its JSON whole) or left out in a decision; every partitioned table's overview row equals its files.

## 115. The most upstream source, value by value, through the grammar (plan 037)
**status:** open · **see:** `curate/plans/037-the-most-upstream-source.md`, `docs/grammar.qmd`, decisions 158, 160,
162, 180, 189 and 248, TODO 110, `$FISHYDATA/archive/2026-10-plan037/`, `2026-10-xml-oracle-map/`

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

**Phase 2 also builds decision 248's admissions:** afli's trips lost whole whose catch and species match a free
landing, from 2007-06 (6,851 records; five near-pairs reviewed first), and records never loaded on kept trips from
2015, by trip (1,505); with them the adapter's fs_afli stations read as fs_afladagbok's (153, 92 in the first class),
and decision 171's line: adb's 243 stations and the 14 `TRACKWELL BAEKUR`/`PAPPÍR` trips, in afli's output or not.

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
Plan 048 (TODO 148) builds three of them: the event rows out of the track, the per-unit screen, and no cut at 2017.
**Recording or receipt, by stream** (plan 059 §1, 2026-11-01): the AIS stream's `posdate` is its receipt time in every
year 2007-2024, STK's own units' their own, 3-5 s earlier; the AIS stream's moves a second or two in May 2025, and
three backlogs in 2026 came hours to days late. In `dump/oracle/meta/stk.yml` with assertions by stream and period (plan
059 step 4, 2026-11-01).

**check:** each decision recorded, and what is chosen built or declined.

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

Built 2026-10-23 (decision 205): step 1's fate tables (TODO 79 closed), step 1b's bound (2007's double count gone,
−998.7 kt) and the reconciled trip across voyages (decision 193). Next (§8, decision 191): §7.1's catch units, then the
five readers of `trip_reconciled`. afli's monthly summaries, which decision 191 e made units of §7.1, are designed
as logbook stations in plan 041, parked (TODO 136). Decision 215: the main output is the link from each fix to its
events, the split the user's step with `fishing` and `fishing_flow` as presets; L5 and L6 rewritten for it (plan 038
§6-§7), the work in its steps 1, 3 and 6. Step 1c built 2026-10-23 (decision 216): catch the trip's landing
contradicts (over 10 times the landed, and 1 t more; 8,703 trip-species pairs, 294 kt) flagged, and carried onto
the fixes as `kg_flagged`; rule 2 built (decision 217), catch above the largest landing of
its species or vessel on trips with no linked landing. Left in 1c: the landings that hold none of the species.

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
bound is lifted in code as plan 038's step 1b (decision 203, not built); ask e's check of the steps' tolerances on
1992-2006 is in it. Nothing built.

**From TODO 74** (decision 192): plan 023 §3 is superseded by plan 039 and plan 025 §4 taken into it. Plan 007's
questions: 1, a report of every landing where agf and LODS disagree (agf wins, so the merge cannot show an agf
defect), carried by plan 039 §5's witness account; 3, `link_lid_map.R` and `catch_by_species_trip.R` keyed on
(`.lid`, `schema_land`), plan 038 step 3 (no `.lid` is shared across schemas in `curated/landing` today, decision
203). Plan 023 §6's fifth source of a landing's trip, the line-incentive check's link of 154,146 landings to STK
events (decision 163; 9,716 arrivals at another time, 7,446 landings with no logbook trip, unexplained), builds on
plan 022 §4 (TODO 68).

**Found 2026-10-30** (decision 266, plan 055 rule 2): vor's `afli_einstakra_skipa` holds 1984 as one date per vessel (a
vessel-year); `landed_catch_pre94`'s month × port × gear crosses vor's vessel × month in 1982-90, and in 1991-93 it is
another stream, so period 0 needs a declared precedence, the other tables witnesses. Open from the same study
(decision 267): what agf's area codes `NE`, `GL`, `NA` and LODS's `U` mean; a record's ICES area by polygon, not a box.

**check:** every period's landings in the same columns with a basis and a layer, and each layer's landings and
kilograms in one outcome per period (plan 039 §9); plan 007's questions 1 and 3 answered in a decision; or the plan
parked or abandoned in its header.

## 124. What each column means, in its metadata: units, formats, precision and codes (plan 040)
**status:** open (plan 040's asks answered 2026-10-23, decision 209) · **see:** `curate/plans/040-metadata-at-three-layers.md`, decision 176, `dump/oracle/meta/README.md`, decision 188, TODO
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
**status:** open — plan 053's decoders built with plan 054's live rebuild on 2026-10-30 (decisions 258, 265); left:
decision 211's representation (no end yet carries a point, cell or none basis) and the per-app check (decided in
207, checked in 211) · **see:** decisions 207 and 211,
`$FISHYDATA/archive/2026-10-todo126-ais-check/README.md`, `$FISHYDATA/archive/2026-10-afli-minutes60/README.md`,
`dump/oracle/meta/{afli,adb,fs_afladagbok}.yml`, `curate/corrections/afli_end_three_digits.yml`, `R/logbook_position.R`,
decision 165, TODO 115, 124, plan 040

Decision 207 chose the representation: each end a point with its precision, a cell (lon/lat NA, the cell recorded), or
nothing (basis "none"); a derived centre only in its own column; a per-row column naming the kind and precision; the
formats in the overlays; per-app checks in `curate/checks/`.

Decision 211 (Claude's AIS check, read-only, not checked by a person) judged the ambiguous kinds against the vessels'
tracks, every position in one outcome, and wrote the overlays (merged into the raw dictionaries the same day):
- STOKKUR's whole degrees are rounded to the nearest degree, a 1-degree cell centred on the value, not a corner;
- afli's exactly 60 is a carry; its 60-99 end values are three digits, a haul end at minute 9-10 stored by the loader
  as degrees and minute run together (decodable, ± a quarter minute); its 61-99 start values and zeros are none;
- about a quarter of afli's paper positions at a rectangle's centre (from 2007) are fills, the rest real;
- Marína's six digits are seconds by the digits (the track cannot tell, its times being the trip's), ~0.5 km;
- Trackwell raun's and Jóhann Gíslason's four- and five-digit latitudes (2022-23) are unpadded decimal minutes, which
  `decode_logbook_position()` misreads; Taktikal holds exchanged latitude and longitude, and ddmm longitudes beside
  six-digit latitudes.

Left:
- the representation built in the adapters and the merge, `R/logbook_position.R` with it (decision 211, "Left"), in
  plan 038 §8's phase 4, a scratch build first;
- the per-app check `curate/checks/logbook_position_forms.R` (proposed in decision 211).

**check:** each source's ends in one kind (point, cell, none) in `curated/logbook/station.parquet`, with counts by source,
app and period; the per-app check built.

## 127. Names in the grammar and in ramb: the review of every noun and act (pending)
**status:** parked (the maintainer, 2026-10-23: "lets hold this TODO") · **needs: maintainer** — the review, rule by
rule and item by item · **see:** `docs/grammar.qmd` (section "Names under review", and the parts of "Resolution and provenance" drafted 2026-10-22),
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
`rb_split_catch()`. Nothing is renamed yet. For the review (the maintainer, 2026-10-23, decision 214): an event can
be any construct, "even a single ping", an operation, day × rectangle × gear, day × gear, ...; `event`'s fixed trip ×
gear × day × rectangle is too narrow; what kind of event a row is, is its resolution (its groups' resolutions).
Candidates (Claude, 2026-10-23): "event" in Darwin Core's sense (an action at some place during some time, at any
scale, nested by a parent event), and its "grain" (what one row represents: its groups' resolutions combined); a
lumped catch × species × year is an event of grain year × species. Set aside: record (ramb's station), unit (a clash),
cell (odd for a ping), observation (the grammar's catch).

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

## 131. The Icelandic metier per fishing operation: gear, target, mesh, rigging and devices, each with a basis
**status:** parked (the maintainer, 2026-10-23: "park this / put on hold") · **needs: maintainer** — ask a2 of
plan 015 §4 a (the target where the gear code gives none) ·
**see:** decision 212, `curate/plans/015-datacall-on-the-curated-trail.md` §4 a revised,
`$FISHYDATA/archive/2026-10-metier6/README.md`, TODO 133, TODO 27b (the mapping to ICES's codes), plan 020 (`gear_part`)

The flow carries Iceland's own metier, and a datacall maps it to icesVocab when it is answered (decision 212, the
maintainer). Plan 015 §4 a revised proposed an ICES-coded rule from Claude's read-only study of 2026-10-23. It is to be
redrawn in Icelandic terms: gear and target from `gid_used`; the mesh from the regulation where it fixes the class
(a1, answered: the recorded mesh a witness, disagreements listed), else the recorded mesh, the vessel's or fleet's
usual one, or none; rigging (`tvo_veidarf`) and selection devices (grids, panels) as recorded. RDBES's code is a
witness. Open: (a2) the target for the three gear codes that name none, Plógur, Flotvarpa and Gildra (dredges,
pelagic trawl, traps): from the catch, or left unnamed. The practices ICES's lists leave out (twin and triple rigs,
Nephrops panels, sea cucumber and urchin dredges, seaweed, diving; TODO 132 folded in) are kept as recorded here.

**check:** a2 answered; the fishing fixes carry the Icelandic metier and its basis, every fishing operation in one
outcome; the operations where the recorded mesh disagrees with the regulation listed.

## 133. The legal mesh by gear and date, from the regulations themselves (`reference/gear`)
**status:** parked (the maintainer, 2026-10-23: "park this / put on hold") · **see:**
`curate/plans/015-datacall-on-the-curated-trail.md` §4 a revised (ask a5), TODO 131,
decision 212 (the regulation's mesh first)

The metier takes the mesh class from the regulation where the regulation fixes one (decision 212), and the values are
constants in a study script: bottom trawl 135, Nephrops 80, shrimp 36 and Danish seine 135 mm, the last assumed from
the records. They come from a model's summary of reglugerð 543/2002 on island.is; 964/2019 (shrimp) and 188/2020
(Nephrops) returned 403 and were not read, and the seine's and the gillnets' regulations were not looked for. A dated
table (gear, target, part, legal mesh, from, to, the regulation and its article), read from B-deild, lets the rule's
`regulation` basis cite its source over the years the datacall asks for.

**check:** `reference/gear` holds the table with a source on every row, read by a person, and the metier rule reads it.

## 134. Commercial sampling: samples from a trip or haul, and their measurements, in the grammar
**status:** open · **see:** decision 210 (plan 019 ask 4), `docs/grammar.qmd` (observation, sample), TODO 127,
`raw/oracle/biota/`, `raw/oracle/channel/`, `raw/oracle/rdbes/` (`sample`, `biological_variable`,
`frequency_measure`)

The maintainer, 2026-10-23: following the grammar for protected bycatch (every measure the source holds) opens a
pending step, commercial sampling: a sample taken from a trip or haul and then measured (lengths, and more). MFRI's
samples are dumped (biota, channel, and its RDBES upload tables), and the logbook notes name samples for MFRI
("prufa", "hafróprufa", "sýni"; decision 210's notes study links them). Nothing is measured yet; a plan comes when the
item is taken up.

**check:** a plan that maps the samples and their measurements to the grammar's tables and links each sample to its
trip, haul or landing, or the item parked.

## 135. Pumped catch back on the vessel that caught it (plan 042)
**status:** parked (the maintainer, 2026-10-23: "park this / put on hold") · **needs: maintainer** — the seven asks
of plan 042 · **see:** `curate/plans/042-pumped-catch-on-the-catcher.md`, decisions 199 and 210, TODO 73 and 101,
`$FISHYDATA/archive/2026-10-transhipment/`

The maintainer's rule of 2026-10-23: in the logbooks the catch stays on the vessel that caught it; the landing keeps
the vid of the vessel that landed it. In the e-logbook the carrier logs pelagic catch pumped from another vessel on a
tow of its own, and the notes name the catcher: 52-93 kt a year in 2021-2025 (Claude's measure, not checked by a
person). Plan 042 designs the notes into staging, a link from them (preprocessing), the move onto the catcher's
station read by `catch_by_species_station` and `ais_catch` only, raising by the carrier's landing, and decision 199's
carriers named. Its seven asks come before any code.

**check:** unparked by the maintainer, the asks answered in the plan, the link and the move built by name, and the
audit's transhipment account read after the build.

## 136. afli's monthly summaries back in the logbook, each kilogram once (plan 041)
**status:** parked (the maintainer, 2026-10-23: "park this / put on hold") · **needs: maintainer** — the seven asks
of plan 041 · **see:** `curate/plans/041-afli-monthly-summaries-in-the-logbook.md`, decisions 084, 191 e and 266, plan
055, TODO 73 and 122, `$FISHYDATA/archive/2026-10-afli-summaries/`, `$FISHYDATA/archive/2026-10-logbook-notes/` §3.1

afli holds 40,967 monthly summary stations (Nephrops 1960-1999, shrimp 1953-1986, Danish seine 1960-1966; 199.4 kt).
Each is a vessel × month × square or shrimp area, dated the 15th. The adapter sets them aside in
`staging/afli/aggregate.parquet`, which nothing reads; the maintainer (2026-10-23) wants them in the logbooks. Plan
041 designs them as stations of type `monthly_aggregate` on a vessel-month trip with no dates. A summary leaves where
afli's hauls of its cell hold 95 % of its kg (Nephrops 1986-1999 repeats its hauls), and stays less the hauls where
they hold less: 173.0 kt kept (Claude's measure, not checked by a person). `ops$sigfus`, their source, was dumped on
2026-10-23 and is to be read first (plan 041 §6); its seven asks come before any code.

The comparison with the new mar's merge (2026-10-29, plan 050 §6) adds that the summaries hold the only Nephrops of
1973-1985 (1.2-2.7 kt a year) and nearly the only shrimp before 1975, and that in 1986-1999 they repeat the hauls (the
new mar reads them as stations, so its Nephrops of those years is counted twice).

`ops$sigfus` read on 2026-10-30 (decision 266): the Nephrops summaries match it cell for cell; its seine table holds 937
rows of 1967-1970 (7.2 kt) never loaded into afli; `staging/afli/aggregate.parquet` keeps no place for the 12,708
shrimp summaries; the fleet's Nephrops of 1960-72 are allocated at the year and of unknown quantity (plan 055 ask g).

Plan 056 §5 (TODO 175, 2026-10-31) puts the summaries in the release's `historical/` as `ops$sigfus` holds them,
flagged where they repeat afli's hauls; this item stays parked.

**check:** unparked by the maintainer, the asks answered in the plan, the adapter and merge built by name, and
`station_fate`'s account closing with the summaries in it.

## 137. A record's resolution by what it covers: e-logbook stations that hold a trip or a day
**status:** parked (plan 054 cut to what matters, the maintainer, 2026-10-30; decided 2026-10-23, decision 214, not built) · **see:**
decision 214, `$FISHYDATA/archive/2026-10-trip-time-stations/` (README, `recheck/`), decisions 206, 210 and 211,
TODO 73, 127, 138

Decision 214 (the maintainer's go on Claude's recommendation): a record is typed by what its times and position
cover. Marína's and Taktikal's stations (departure to return), STOKKUR's (the landing; a 1-degree cell), the old
TRACKWELL route's (midnight) and the tour app's spots (the landing) are resolved to the trip or the day, not to an
operation:
their window is the AIS voyage under both approaches, their catch unit the trip; no haul window is made from a stamp
(set aside and flagged, as decision 206 does); catch the landing contradicts is flagged (decision 210). Three witnesses
agree: the AIS track, the landings and the digits. Open: whether the slow time a trip-long window adds is fishing.

Left, in plan 038 §8's phase 5 beside TODO 107, a scratch build first:
- each group's resolution on these records in the merge (time: the trip or the day; place: a point or a 1-degree
  cell); the stamped times set aside and flagged;
- the voyage as their window in the flow, under both approaches; STOKKUR's 8.8 kt of net and line catch, today on no
  fix (6.7 kt) or the vessel's month (1.6 kt) under `fishing`, measured onto its trip;
- decision 210's implausible-catch flag: built where the trip has a linked landing (decision 216), two of
  STOKKUR's six entry errors; the other four by rule 2 (decision 217, built), on trips with no linked landing;
- the tour app read with t4 = the spot time (decision 210's build);
- the windows, fishing fixes and catch traced before and after.

**check:** a scratch build, then the store's, with these records typed and windowed as decision 214 says, STOKKUR's
catch on its trips, and the before-and-after trace recorded in a decision.

## 140. The user tables after v0: the user's feedback, the product's version, and the design
**status:** open · **needs: maintainer** — the feedback is the maintainer's use of v0 and the colleague's of release
2026.10.31.1 · **see:** decisions 219 and 268, TODO 102, plan 027

v0 (`$FISHYDATA/products/v0/`, decision 219) is in use by the maintainer as an end user. The next round, in this order:
how a data product is versioned ("very important", 2026-10-24; v0's links follow every rebuild), the maintainer's
feedback, then a plan for the user tables. Leads for that plan, from 2026-10-24:
- two joins every table supports: by key, and `join_by(vid, between(time, T1, T2))`, which needs a vessel's trip
  intervals exclusive (TODO 102) and a window for every landing;
- a landing window table with every landing in one outcome (a trip; a further landing of a trip, plan 027; the vessel
  logs that year but this landing has no trip; the vessel never logs; foreign), T1 and T2 with a basis. The logic is
  inside `curate/ais_catch.R` (units `landing_trip` and `landing`);
- `T2_basis` `reconstructed` for the track's time: the label, or the ranking where the e-logbook's own time agrees
  with the track (decisions 173, 174);
- the flow diagram's vessel row draws only ping → vessel: the vessel's curation and its links to the MMSI, the
  logbooks and the landings are missing (`docs/figures/one_flow_cascade_v3.svg`, plan 033);
- skills for the user, later (maintainer);
- the logbook product structured by the grammar's parts (maintainer, 2026-10-29): the gear (its own measures: "things
  like mesh size belong to the gear"), the rigging ("things like warp", plan 020's `gear_part`, TODO 73) and the
  sensors, summary records as a rule but at times a continuous recording. The afli GPS logger is one: `curated/logbook/sensor_gps`, 49.3 M fixes with the echosounder
  depth (`botndypi`, filled 97-99 %, TODO 100), the headline depth and two temperatures, linked into v0's logbook as
  it is on 2026-10-31 (plan 056; TODO 98).
  Its depth must be joinable to the AIS fixes in the analysis, by vessel and time, where it exists; "including them in
  the ais is not the way" (maintainer, 2026-10-29).
- the analyst's view of plan 055 (TODO 171) as the tables' specification: one quantity per table, the population on
  every landed row. Found 2026-10-30 (decision 266): v0's logbook table leaves `duration_m` empty on every adb station
  and 347,852 of 378,818 fs_afladagbok stations, the e-logbook's tow time being in `t2`/`t3` and `duration_m_raw` by
  design; a user's catch per tow hour loses the e-logbooks.

How a release is versioned and published is decided and built (plan 056, decision 268): the check's first half is
met. The colleague's feedback on release 2026.10.31.1 comes here, as the next release's list, with the vids the
vessel table lacks (TODO 177).

**check:** a decision records how a product is versioned, and the plan for the user tables is written.

## 142. Haul windows that hold steaming or a position jump: what the spread effort map shows
**status:** open — the counts to rerun on the trail of plan 054's live rebuild (decision 265) · **see:** decision 219, TODO 140, TODO 103,
`$FISHYDATA/archive/2026-10-effort-map/` (README)

Found 2026-10-24 (Claude's, read-only, not checked by a person): the effort map prototype spreads each fishing fix's
hours along the line to its next fix (same vessel and voyage, gaps up to 30 min), and draws a few hauls across land
or all the way to harbour. Over the whole trail, `fishing` fixes whose segment to the next fix implies:
- 8-20 knots, steaming inside a window: 528,603 fixes, 30,825 h (0.34 % of fishing hours); 16,820 h of it in `day`
  windows (`synthesised`), 12,834 h in windows with recorded times;
- over 20 knots, an isolated position away from the track: 31,741 fixes, 624 h (0.01 %), 26,383 of them in `tow`
  windows with recorded times.
Fixes whose own speed is over 8 knots: 198,423, 7,946 h. Inside a window neither preset applies a speed range:
`fishing_flow` is `fishing` there (2019: every window fix over 8 knots is `fishing_flow` TRUE).

Open: which are windows bounded too wide (a day window that holds the steaming to and from port, a haul end logged
late), and which are positions the impossible-ping filter keeps. The effort is small; on a map each one is a line.

**check:** a decision says how a haul window is bounded where the track leaves the gear's speed range, and what is
done with a position jump inside a window; the counts above are rerun after it.

## 144. Place names: the next round (plan 045), the originals, the hazard class
**status:** open · **needs: maintainer** — plan 043 ask a; plan 045 ask a (where MFRI's depth model lives); whether
the effort lanes go flow-side · **see:** `curate/plans/045-place-names-review-model-boundaries.md`,
`curate/plans/044-place-name-gazetteer.md` §2, §4-§6, `curate/plans/043-place-names-staged.md` §6, decisions 221-226

Staged (decision 222), curated as versions 1 and 2 (decisions 223, 224), with the tagging databases, channel and uv
(decisions 225, 226); Claude's build, not checked by a person. A read-only explorer of it, the first step towards plan
045's review page, is `products/place_names/` (2026-11-01). Open:
- plan 045 (the maintainer, 2026-10-24): a review interface with a feedback loop through `overrides/`; a model for
  placing names (vague places, conflation, source reliability); MFRI's depth model for GEBCO; EUSM or better as a
  boundary aid; the effort by gear as an image of grounds and lanes (flow side). It carries the review loop and the
  lanes and footprints of plan 044 §2;
- irregular inflection (Fætinum for Fótur) is missed: BÍN is not to be downloaded (maintainer, 2026-10-24), so any
  such form needs a rule of its own;
- the originals still in `~/stasi/ornefni` (plan 043 ask a): moved under the one-home rule, or the ornefni repo's
  git as the home of `data-md/` and the hand-made workbooks, with raw holding snapshots;
- the hazard class against the effort: a weak tendency (decision 224), to test again on more marks.

**check:** each item done and recorded in a decision, or dropped by the maintainer, and plans 044's and 045's statuses
agree.

## 145. The flow on one vessel: ramb's map viewer built around the flow diagram (plan 047)
**status:** open · **needs: maintainer** — plan 047's asks a-g (the vessel overview's place, the default span, how far
the user operates, which mode first, example data with catch, names, a public demo) · **see:**
`curate/plans/047-flow-map-one-vessel.md`, plan 046, decisions 215, 227, plan 030 §7

The maintainer, 2026-10-25: the next round of `rb_map` centred on the diagram's rows, so that a user can take one vessel
and follow the whole process in the app, from the flagged pings to the split catch. Plan 047 proposes a step panel, a
track layer held in the browser, a timeline linked to the map and the user's filter carried through effort and catch;
as built from `curated/` in fishycode, live from the `rb_` steps in ramb. None of its steps built; ramb 2026.10.25.4's
`rb_map_pings()` and `rb_map_track()` are parts they can use, and ask f is answered for those two names (§8).

**check:** plan 047's seven steps done and recorded in a decision, or the plan parked or abandoned by the maintainer,
and its status agrees with its index row.

## 146. The events of a fishing operation beyond `t1`-`t4`: what `t3` means, and the A to J protocol's source
**status:** open · **needs: maintainer** — (b) only; (a) answered 2026-10-30, towed `t3` the start of hauling, in the
grammar (decision 247) · **see:** `docs/grammar.qmd` (section "Events between and
around the four"), decision 230, TODO 127

The maintainer, 2026-10-26, gave a cruise protocol's ten bridge actions per tow (A to J) to extend the grammar's
fishing operation; the section and decision 230 match a longline to it. Open:
- (a) for towed gear, is `t3` the start of hauling (E, what Hafriti and `fs_afladagbok` record) or off the bottom
  (F, as the grammar's table defines it)? The grammar says, for now, that a recorded `t3` is the start of hauling;
- (b) which cruise the protocol is from, and whether its A to J presses, with the engine or fuel data, are kept;
  if so, they measure the E to F gap on towed gear.

Whether the translation may stay in the published book is answered: it may (decision 230).

Names for the events between and around the four go to TODO 127's review.

**check:** the grammar's table of the four events names one event for towed gear's `t3`, and decision 230 names the
protocol's cruise and says whether its records exist.

## 147. Voyages that still hold several logbook trips after the time budget: what they are
**status:** open · **see:** plan 031 §3.2, §3.6, §3.10, decision 197, TODO 90

Plan 031 §3.10: the time budget cuts the voyages that hold two or more logbook trips from 2,203 to 815 in 2010 and from
1,078 to 815 in 2018. That is 1.1-1.3 % of each year's voyages, and at least 1,630 trips a year, about 3.5 % of them (a
lower bound from the plan's numbers, not counted). Not all are errors. Before the budget, over every year (§3.2):
- 48 % held a port call of 2 h or more that the rules missed;
- 31 % only touches under 2 h;
- 20 % no port call at all: one sea trip that a date-only logbook splits by day, where the voyage is right.

How the 815 divide among these is not measured; the plan leaves it to the AIS rebuild (step 7). The maintainer asked
for it as an item on 2026-10-27.

Count each remaining voyage in one outcome, the unjudgeable too (decision 155's method):
- a port call the budget still misses;
- a call under 2 h, and whether a landing or logbook end confirms it;
- one sea trip split by date;
- the track and the records disagree on the port or the vessel.

Read-only, either on 2010 and 2018 with plan 031's step-3 scripts (`$FISHYDATA/archive/2026-10-plan031/scripts/step3/`),
or on every year once step 7 has rebuilt the port calls.

**check:** the remaining voyages with several logbook trips, of 2010 and 2018 or of every year after step 7, are counted
into these outcomes with every voyage in one, and the counts are in plan 031 §3.10 or a decision.

## 148. STK's streams into the flow: heading and course apart, a stream, port events judged as events (plan 048)
**status:** open — plan 048's asks a-g answered 2026-10-28, each as recommended (its §5); next is step 1, the scratch
measurements · **see:** `curate/plans/048-stk-streams-heading-course-events.md`, decisions 196 and 233, TODOs 88 and 117

The maintainer, 2026-10-28: STK's heading field split into true heading and course, a stream on every STK fix, and the
events taken as events; port calls a generic method, so their trust in STK's events must not hang on the ping filter.
Plan 048: `stk_trail()` gives `stream`, `heading` and `cog`; the union drops STK's event rows but an `I` inside its own
port, and every provider's codes become NA; a generic ramb step, `rb_flag_port_event()`, judges any recorded port
event by position, sequence, the cleaned track and its sending unit, so `port_call.R` no longer asks whether the
whack filter kept the event as a ping (699,084 port calls lean on events, 13,510 on events alone; 904,187 of STK's
1,351,745 whacks are event rows). Then the chain from the union down is rebuilt.

**check:** plan 048's five steps done and recorded in a decision, or the plan parked or abandoned by the maintainer,
and its status agrees with its index row.

## 149. ramb's set finder fails badly on pots and sparse tracks: amend it, or let the data choose
**status:** open — next: its own ramb session, once ramb is pushed and the note to iapesca's author is sent (the
maintainer, 2026-10-28) · **see:**
decisions 234, 158 and 146, TODO 72 item 8, `$FISHYDATA/archive/2026-10-mendo-vs-iapesca/` (the harness)

The maintainer, 2026-10-28: a method that fails badly on a dataset is amended; methods may be scored against each
other; one method robust across data richness, or one chosen by the data. `rb_link_record_sets()` (iapesca 1.3) gets
33 of 56 dense pot sets, little from 10 min on, and 56 of 72 drive-in gillnets with its 1-hour floor (decision 234).
In ramb, in order:
- classify the ~22 wrong pot sets: run-in to the buoy, other passes over the line, or the truth rule's pick;
- per haul, whether ramb and Mendo DK err on different hauls (both right, one, neither), before any agreement score;
- a choice by the data (ping rate, soak against the floor), its basis recorded on the output;
- `key` checked unique, with a guiding message (repeated ids ran 13+ min with no warning).
- the acceptance rule as an option of this function (a minimum share of the line covered), measured, not a second
  method; Mendo's two samples as an agreement test (decision 234, items 2 and 3).

Mendo's method is not recoded (the maintainer, 2026-10-28); the per-haul check reopens that if the two err apart.

**check:** each of the five is done in ramb and measured on all its labelled tracks at five ping rates, or recorded
as not done, in a decision.

## 150. DuckDB 2.0: 1.5.6 until 2.0.1, then measured again
**status:** open — R's default back to 1.5.6 on 2026-10-29, after the rebuild under 2.0.0 (decision 239) · **see:**
plan 049, decisions 239, 235 and 218, `curate/issues/duckdb.yml`, `$FISHYDATA/archive/2026-10-28-duckdb2/`
(`bench_small.sh`, `synth/`, the fingerprints and their logs)

The store was rebuilt from raw under 2.0.0 on 2026-10-28 and compared with the build of 2026-10-23, every file in one
outcome (decision 239). 2.0.0 has three regressions, each worked around in the code. The maintainer chose 1.5.6 until
2.0.1 (due 2026-11-18); 2.0.0's build is kept at ~/Library/R/duckdb-2.0.0. Open:
- `bench_small.sh` and the reprexes again at 2.0.1, under both engines;
- the three drafts to DuckDB, whether and how to send them (the maintainer's call).

**check:** a decision records 2.0.1 against 1.5.6 on the battery and the reprexes, and which engine builds from then on.

## 151. Global Fishing Watch's vessel tracking guide: which wishes to build, and the two measurements it asks for
**status:** open · **needs: maintainer** — which of the four wishes to build, and in what order; the two measurements
made 2026-10-30 (decision 251) · **see:** decisions 251 and
237, `docs/one_flow.qmd` (the wish list's four last rows), `$FISHYDATA/raw/external/gfw/vessel-tracking-guide-2026/`

The guide (GFW, 2026) was read against fishycode and ramb on 2026-10-28 (decision 237), and four wishes were added to
the wish list: a silence in one feed checked against another; each record's length against its ping interval (an
interval no longer than a quarter of the event); entering and leaving any zone, as port calls already are; encounters
and loitering. GFW's code for gaps, encounters and loitering (`pipe-gaps`, `pipe-encounters`, `pipe-loitering`) was
read by its READMEs only. A document gives asks, not methods (`AGENTS.md`): a wish built is recoded only for a reason
(decision 234).

Open, needing no decision:
- the ping interval of each AIS stream and year, measured on the Icelandic tracks;
- the share of logbook records shorter than four ping intervals, by gear and year.

**check:** a decision records the two measurements, and each of the four wishes built, put in a plan, or set aside
by the maintainer.

## 155. EM4SSF's shared code: the time zone to ask its authors, and the trace to redo as the code grows
**status:** open · **needs: maintainer** — the question to the project's WP2 authors (a) · **see:** decisions 238 and
229, `~/stasi/em4ssf` (private, outside the repo), `raw/external/mendo2024`

Decision 238 traced the code EM4SSF shares privately to Mendo et al. 2024's published supplements. There is no new
method so far. Two things are left:
- **(a) The time zone of `DATE_TIME`.** D2.1 gives its format (ISO 8601, no offset) but not its zone (D2.1 §2.1,
  tables 1-2). The shared R reads it in the zone of the paper's Scottish case, so trips cut by calendar day depend on
  that choice. This was read from the code, not run. It is a question for the format's authors, through the project,
  not a `curate/issues/` note, since the code is not public.
- **(b) The trace again as the code grows.** The repositories will change up to and at the Ancona hackathon (November
  2026). Pull both, then trace each new or changed script by 238's method. A script with no public origin is EM4SSF's
  own and is read under 238's rule.

**check:** (a) D2.1's zone for `DATE_TIME` is known, from the authors or a later D2.1; and (b) every script at the
repositories' newest commit after the hackathon has its origin in decision 238 (amended).

## 157. Whole weight: one factor table for the logbooks and the landings (plan 051)
**status:** open — built in plan 054's live rebuild of 2026-10-30 (decisions 257, 265); left: the lumpfish rows,
provisional until HV 2020-33's authors answer (TODO 169), and the paper era's × 1.25 (ask e), the maintainer's; b
partly from the regulations (plan 051 §5) · **see:** `curate/plans/051-whole-weight-one-factor-table.md`,
TODOs 114, 115, 152, 167, plan 050 step 5

The logbooks store whole weight as gutted × 1.25 for every species, while the landings apply a factor per species,
state and period (cod 1.25 to 1997, then 1.1905; flatfish 1.087; lumpfish roe 3.030, 3.788, then 3.401). So the same
gutted fish is 0-15 % heavier logged than landed. Plan 051 proposes one factor table that both read. Plan 050's
Nephrops tails are built with it (decision 257). For ask c: from 2025-11-19 adb writes every lumpfish as 48, and Grásleppa
(951) and Rauðmagi (950) cannot be told apart there, not even by the gear (plan 050 §6). Steps 1-2 measured
2026-10-29 (plan 051 §1): a lumpfish barrel is 0.472 t of fish by MFRI, and barrels are only in afli's own lumpfish
logbook (1977-2016), which no source of the product reads as catch yet (ask c).

**check:** plan 051 executed or parked, with a decision record.

## 160. The Directorate's link of trip to landing as a witness for `lid_map`
**status:** open · **needs: maintainer** — the id as a witness or not, and `ops$rafn.rekjanleikanumer` dumped ·
**see:** `curate/link_lid_map.R`, `$FISHYDATA/archive/2026-10-29-trace-id/findings.md` (§5 the proposal), plan 050 §6

Measured 2026-10-29 by Claude (AI), read-only, not checked by a person. The trip side is in our dump,
`fs_afladagbok.ws_rekjanleiki`, one id per trip, equal to the new mar's trip `trace_id` on all 243,149. The landing
side is in no dump: in Oracle only `ops$rafn.rekjanleikanumer` (178,555 rows, fewer than the 200,716 landings with an
id). It was read once from the new mar's landings parquet on S3, six columns, with the maintainer's leave. Landings
carry the id from 2021-04, all of them from 2022-10. Of 192,395 e-logbook trips of 2021 on: 149,325 same landing,
3,984 different, 633 only the id, 16,331 only `lid_map`, 1,646 neither, 20,476 not judged. Where they differ, the
logged catch sides with `lid_map` 1,755 to 538: the id is made at the weighing, and names the previous trip or an
empty auto trip when the logbook trip is late. It is better on swaps (294 trips; the weight agrees 176 to 23) and on
step 05, `vid_date ±2` (162 of 191 contradicted; 85 to 23).

Proposed: the id as a witness column on every link and the resolver for swaps and step 05, not a step of its own; its
landing side dumped from the table first, never read from the S3 parquet.
The landing side cannot be rebuilt from our dumps (`$FISHYDATA/archive/2026-10-29-rafn-mail/rafn-mail.md` §3): from
2022-10, same vessel and day gives 82.5 % of the landings' ids and the vessel's last trip 3.4 %; the other 14.1 % are
the landing system's choices at the weighing, kept only in `ops$rafn.rekjanleikanumer`. No dumped table holds the
landing side, ask included (it ends 2020-07-31, before the ids begin); the ids on the new mar's afli trips are its
author's own join by vessel and landing day, not a source value (decision 243).

**check:** the maintainer's choice; if taken, the table dumped, the witness and the two resolvers built and measured,
every trip in one outcome, in a decision.

## 163. The logbook's gear, rigging and sensor tables (plan 052): what is left after the build
**status:** parked (plan 054 cut to what matters, the maintainer, 2026-10-30) — asks d and e answered 2026-10-30 through plan 054's ask
h (amended the same day); `effort_count` from the parts and `vessel_sensor` not built · **see:** `curate/plans/052-logbook-gear-rigging-sensor-tables.md`, decisions 244 and 245, TODOs 98, 100,
140, 165

Built 2026-10-29 (decision 244), not checked by a person: `curated/logbook/{gear_part,rigging_part,sensor_summary}`,
every source column and kept station in one outcome; afli's edited layer answers before `rafr_` to 2018 and where
the domain expert's account last changed the station (the maintainer). Units measured 2026-10-30 (decision 245): the
gillnet's length metres; door areas above 40 m² and the dredge's size kept raw; every unit in the dump overlay. Left:
- **`effort_count` from `rigging_part`** (51 afli stations would move, each explained in decision 244); `g_*` kept
  until TODO 140 versions the product (plan 054 ask i).
- **`vessel_sensor`** (`curated/vessel_sensor/`): long, like `sensor_summary`, with no positions; the logger stays in
  the AIS track (decision 196); the 1899 readings dated from their record, `reconstructed` (plan 052 §5, amended).
- **Plan 052 step 1's remainder**: §2's unexplained headline and sweep records listed vessel by vessel; the dredge's
  unit per record, if a rule by species is wanted (decision 245); the ICES columns when something reads them (the
  matches are in decision 245).
- **`toga.virle`'s note** in `reference/gear/part_map.R` (and so the dump overlay): "0 on every row" is `rafr_toga`'s;
  afli's edited `toga` has 127 thousand Danish seine wires, 1976-2001, which `rigging_part` carries rightly. Reword at the
  next touch of the map (`$FISHYDATA/archive/2026-11-01-label-covariates/`, "Warp length").

**check:** `effort_count` read from `rigging_part`, the change accounted for; `vessel_sensor` built or declined; a
decision record.

## 169. Outside contact: the questions and requests waiting to be sent
**status:** open · **needs: maintainer** — each is the maintainer's to send · **see:** plan 054 ask e, decision 247,
TODOs 103, 157, 165, decisions 264 and 265

One list of every question or request fishycode waits on from outside (plan 054 ask e, the maintainer, 2026-10-30).
The items they came from close on what fishycode does; the waits are kept here.
- **On hold since 2026-10-29**, with no contact with the new mar's author until the maintainer says:
  - plan 050's ask f and plan 053's ask f (TODO 165): the live fs_afladagbok feed, and read access to
    `mfriops/Landings`. The feed answered by its author in the maintainer's own mail (2026-10-30): the Directorate's
    two REST services (`$FISHYDATA/archive/2026-10-30-fs-api/`). Still wanted: their token endpoint, and the code;
  - plan 053's ask g (TODO 165): Trackwell's own haul file as a standing witness.
- **The Trackwell draft** of TODO 103 (chosen 2026-10-23): `$FISHYDATA/archive/2026-10-plan035/trackwell.yml`, kept
  out of git; its `sent` is filled when it goes.
- **The Directorate** (decision 264): does it hold the small boats' logbooks of September 2020 to March 2021?
- **HV 2020-33's authors** (TODO 157, plan 051 c): the questions in
  `$FISHYDATA/archive/2026-10-whole-weight/lumpfish.md` §6, a draft.

**check:** each sent and its answer recorded in the plan or item it came from, or dropped by the maintainer.

## 170. Plan 053's leftovers: the small pieces its steps named and did not build
**status:** open · **needs: maintainer** — the pressed records' starts (below) · **see:** decisions 255, 258, 259 and
260, `curate/corrections/logbook_app_profile.yml`, `R/logbook_app_profile.R`, `R/logbook_position.R`, TODO 126

Plan 053 was executed on 2026-10-30 (decision 260), and it was built with plan 054's live rebuild the same day (decision 265). Left from its steps:
- P8's 8 merged stations, whose side Trackwell's own copy contradicts, as a frozen list in `overrides/`;
- a station-level `position_uncertain` flag (`pos1_flag`); the staged `pos1_form` says it for now (decision 258);
- `z_unit` "uncertain" for the vessels rows D2 and D3 note (Taktikal 37, Reiknistofa 34), as a frozen list from the GEBCO
  witness (decision 259);
- 21 fs stations of pattern 5/4 outside P4, 19 of them against the track, for a person to judge (decision 258);
- I4's unlanded clusters by adb's apps, now that the store carries adb's `source` (decisions 256, 265);
- **for the maintainer:** 1,767 pressed records start at the trip's departure and 821 at its landing. T14 takes them
  as written, and no reviewed row says whether such a start is a copy (decision 255).

**check:** each built, or declined in a decision; the maintainer's answer on the pressed records' starts recorded in
the profile.

## 171. The grammar in two views, with the rules the factor table left (plan 055)
**status:** open · **needs: maintainer** — plan 055's eight asks · **see:** `curate/plans/055-the-grammar-in-two-views.md`,
decision 266, `docs/grammar.qmd`, `docs/one_flow.qmd`, TODOs 127 and 140,
`$FISHYDATA/archive/2026-10-30-nephrops-shrimp-factors/`

The maintainer's aim (2026-10-30): tables an analyst can use without knowing the pipeline, robust against misuse; the
datacall a side product. The records-and-factors table was tested on Nephrops and shrimp and set aside (decision 266).
Plan 055 writes the grammar in two parts on the project's first boundary: the analyst's view (a quantity over a cell,
with basis, lineage and coverage) and the builders' view (today's levels and streams), joined by the link. It adds
eight rules from the measured cases, lineage and coverage (claim, measure, gap) as properties of a source in a period,
and the Icelandic track as the census witness from 2007. Nothing needs a rebuild.

**check:** the asks answered in the plan; `docs/grammar.qmd` rewritten with both parts and a clean render; a decision
records the revision.

## 173. Plan 019's `protected_bycatch`: fs_afladagbok's mammal and bird bycatch, parked
**status:** parked (the plan 054 cut to what moves effort or catch, the maintainer, 2026-10-30) · **see:**
`curate/plans/019-fs-afladagbok-mined.md` (its table list and ask 7), decisions 210 and 265

Plan 019 proposes a staged table of fs_afladagbok's protected bycatch: 4,462 rows keyed by station and taxon, with
`n`, `length_cm`, `sex` and `note`. Nothing stages or reads it. Its ask 7 (the name, and counts only or not;
`ws_medafli` also has length and sex for whales) was answered with the others in decision 210. It moved here when
TODO 73 closed (decision 265).

**check:** staged and merged with every record in one outcome, or abandoned in plan 019's header with a decision.

## 174. afli_sent's overlap labels depend on the row order
**status:** open · **see:** decision 265, `sources/afli_sent/convert.R` (`.checks`)

Found by plan 054's live rebuild (decision 265, Claude's, not checked by a person). Built twice, afli_sent's staged
`fishing_sample` differs in `.checks` on 3,286 stations whose neighbours tie in time: "end time overlaps next" and
"start time overlaps previous" swap with the row order, 12 of them to or from "ok". Nothing downstream reads the
column, so no merged table changes.

**check:** the labels follow a written tie-break, and the file built twice is identical.

## 175. The user tables as a data repository: its first release, for a colleague, with the historical aggregates
**status:** in progress · **needs: maintainer** — the share's path, where the colleague reads; then the copy · **see:**
`curate/plans/056-a-first-release-of-the-user-tables.md`, decisions 219 and 268, TODOs 123, 136, 140 and 171, plans
039, 041 and 055

The maintainer, 2026-10-31: a preliminary release of the user tables for an MFRI colleague working on Nephrops and
shrimp, as a test case, on a central MFRI server, with the historical aggregated data. Plan 056 is built (decision
268): release 2026.10.31.1 is published in `$FISHYDATA/published/releases/2026.10.31.1/` (36 files, 1.95 GB, read-only),
with its manifest, `CHANGES.md`, `meta.yml`, `meta.html` and README, and the repository's README, `RELEASES.md` and
`LATEST` beside it. Left: the share's path; the copy of `$FISHYDATA/published/` to it, plain copies with no links (ask
a), checked file by file against the manifest's md5s; and the colleague's use, whose feedback goes to TODO 140.

**check:** the release on the share, checked against its manifest there, and the colleague told where it is.

## 176. A knowledge skill for MFRI colleagues, built from the record on kb-hafro-kerfi's pattern
**status:** parked (a wish, the maintainer, 2026-10-31) · **needs: maintainer** — a skill of its own or pages in
kb-hafro-kerfi (the software team's), and which confidentiality line it keeps · **see:** kb-hafro-kerfi's `SKILL.md`
and `about.md` (the org's skill catalog), TODO 175, plan 056

The aim: a colleague asks Claude on claude.ai, say "What can you tell me about Nephrops recordings of catch in both the
logbook and landings", and is answered from what fishycode has learned of the sources, each claim stamped to its
record line. The record cannot be handed over as it stands: 273 decisions, 61 plans and 48 corrections in the order
things happened, superseded facts beside what replaced them (the tails' factor 3.3, then 3.25 in decision 257; the
correction's status line still said the live store waited for a rebuild a day after the table was built there, fixed
2026-10-31). It needs a topic layer, one page per source, species or variable, true now, built as kb-hafro-kerfi is:
stamped claims, a hook index with a lookup, `OPEN.md` for the known unknowns, `about.md`, `gaps.md`.

Tried on the Nephrops question on 2026-10-31, read-only: the record answers it (correction `logbook_nephrops_tails`,
decisions 240 and 257, plans 050 and 051), and kb-hafro-kerfi's `afli-layers.md` holds the other half (afli's x 3.3 in
2007-2018), not the landings' 3.25 or the tails logged since 2019. Ideas carried: pages generated from the record and
checked as `check_bookkeeping()` checks it (every stamp resolves, none cites a superseded record); versioned with plan
056's releases, so an answer describes the tables a colleague opens; knowledge, not data, pointing to the release for
amounts. TODO 175's colleague (Nephrops and shrimp) is the natural first user. kb-hafro-kerfi keeps vessel numbers away
from logbook figures (Regulation 307/2023, art. 2), stricter than plan 001 §3's three-vessel answer: a shared skill
keeps one line.

**check:** a pilot page (Nephrops in the logbook and the landings) answers the question in a fresh context from the
skill alone, and the maintainer has chosen a skill of its own or kb-hafro-kerfi; or the wish dropped with a decision.

## 177. The old vessel numbers: the lumpfish logbook's own boat numbers until 1991, and the other vids the vessel table lacks
**status:** open · **needs: maintainer** — the fate of the lumpfish numbers until 1991 in the next release, the rule
for 1991, and whether anyone at MFRI holds the 1980s lumpfish boat list · **see:** decisions 263, 268 and 269, TODO 140

Decision 269 found two things about release 2026.10.31.1's 22,588 stations whose vid is not in `vessel/vessel`:
- None of them carries a number the register ever held. The register covers every hull the logbooks name.
- The old part is the lumpfish logbook, which numbered its own boats until 1991: 20000 + x in 1980-81, x in 1982-90,
  both in 1991. Of its 100,381 stations up to 1991, 15,669 are in the gap. Most of the rest sit silently on a hull the
  number does not name. The merge's one-source rule left out 243 t of roe on 1,895 vessel-days of those years.

For the next release (TODO 140), in the merge, with the logged number kept:
- the lumpfish numbers up to 1991 out of `vid`, into a column of their own, and out of the one-source rule;
- the 9 renumbered open boats through a reviewed table in `overrides/`;
- kvoti's 39 unregistered boats into the vessel table, as a register of their own;
- the software-test vessels and the quota entries left out, as duplicates are, and vid 0 and the divers flagged;
- the README's gap line replaced by decision 269's breakdown.

**check:** the next release's README places every station whose vid is not in the vessel table in an outcome, and no
lumpfish station before 1992 carries a register vid without a witness.

## 178. How many clocks: the first test on a track, and the feeds harmonized before any speed or turn is derived (plan 059)
**status:** open · **see:** plan 059,
decision 270 (its section "Time is an observation"), decision 233, TODO 88, TODO 117, plan 048,
`curate/corrections/ais_feed_clock_offset.yml`, the studies `$FISHYDATA/archive/2026-11-01-phase-model/` and
`2026-11-01-feed-clocks/`

The maintainer (2026-10-31): time is observed, like position, with an error of its own. Decision 270 measured it on
the Icelandic feeds:
- astd lies 15-90 s behind stk in October 2025 to May 2026 and 30-75 s in September 2015 to January 2016, by month;
- STK's AIS stream is stamped at receipt in every year 2007-2024, its own units at their own time; the stream mix
  changed about 2011, the AIS stream's meaning by a second or two in May 2025 (plan 059 §1, amending decision 270);
- the trail's `speed` is never derived across feeds, so the speed filter is safe; turns and spreads in those months
  are not.

Plan 059: a standing check right after `ais_ping_union`, the lag applied in the tag pass, the delivered time beside;
ramb's step 0 for the generic part. Step 1 is run (2026-11-01, the study
`2026-11-01-feed-clocks/`): offsets in 2014-2016 and 2025-2026, a lag per vessel and month, 266 thousand copies the
duplicate flag misses. Step 5 too: aligned, the whack's false removals fall 56-90 % in 2015 and 2026 for 0.4-1.1 % of
its true ones; on-time copies in a late month say a copy's own lag is needed beside the month's. Asks a-h answered
(maintainer, 2026-11-01, each as recommended; the rule "derive within one stream" is in AGENTS.md). Step 2 is built
(2026-11-01, ramb's branch `feed-clocks-step0`, not merged or pushed): `rb_add_ping_stream()`, `rb_create_ping_lags()`,
`rb_add_ping_own_lag()`, `rb_add_ping_time()`; on 2016 and 2026 they give step 1's lags and copies and step 5's aligned
time, every difference explained (the study's "Step 2"); installed from GitHub as 2026.11.01 (3953894). Step 3 is built: `curated/check/ais_feed_clock`
(target `check_ais_feed_clock`), equal to step 1 but at the 30-pair bound. The tag pass (§3) is a tested candidate in
the study (2026: the whack's false removals 97,535 to 9,622). Step 4 is written: STK's time by stream and period in
`dump/oracle/meta/stk.yml`, with assertions `check_data_dict()` tests, and astdB's speed `recorded` in the union's code.
Steps 6 and 7 are run as studies (2026-11-01): TODO 88's floor kept at 0.3 nm with the aligned times; astd's speed
stamp a central difference within astd (ask i, the maintainer's yes, 2026-11-01). Step 8's code is built (2026-11-01):
the candidate as `curate/ais_ping_tag.R`, the clean with TODO 88's floor and evidence, astd's and emodnet's central
speed, the five columns to the trail; on 2026 in a scratch store it equals the candidate and step 6's 0.3 nm run.
Next: the rebuild, prepared in `$FISHYDATA/archive/2026-11-01-plan059-rebuild/` (its README: before.R, build.sh,
after.R), with TODO 179's port calls and decision 268's logbook side; plan 048 and TODO 117 later.

**check:** a decision records the test on the Icelandic feeds and whether the trail's turns and windows are corrected,
or why not.

## 179. Port calls lost at New Year: the January part of a stay begun in December becomes voyage 1
**status:** open · **needs: maintainer** — the fix (an overlap window and a merge step in ramb, used by `port_call.R`)
and its rebuild · **see:** `$FISHYDATA/archive/2026-11-01-voyage-year-boundary/` (README, `notes/fix_draft.md`),
`curate/port_call.R`, `curate/ais_voyage.R`, decision 270, TODO 72

`port_call.R` makes the port calls one year at a time. Year Y's run ends a December call at the vessel's first January
ping, and year Y+1's `t_in_window` drops the call, which began in December; the pings from there to the departure
belong to no port call and become voyage 1. Measured 2026-11-01 by Claude (AI), not checked by a person, every
vessel-year boundary in one outcome: 9,352 of the 25,871 boundaries spent in port lost the January part; 22.9 M pings
(3.9 % of 2007-2026, every year from 2008; 5.98 M in 2017's strike), 99.98 % in voyage 1, 99.4 % under 0.3 kn;
`fishing_flow` puts 22,951 h on them (`fishing` 109 h). The fix drafted: keep the calls that overlap the window, merge
a vessel's calls at one port across years and renumber them; rebuild `port_call` → `ais_voyage` → the trail and what is
keyed on `voyage_id`.

**Built and tested on a scratch store** (2026-11-01, `$FISHYDATA/archive/2026-11-01-port-call-new-year-fix/`): ramb
branch `port-call-chunks`, 7598da0 (2026.11.01.1: `rb_create_port_calls(window = )`, `rb_merge_port_calls()`; 240
tests pass), and fishycode branch `claude/nice-spence-7dd95d`, 0c644e4 (`curate/port_call.R`, AGENTS.md); both
merged on 2026-11-01 (ramb's `main` fast-forwarded, pushed and installed from GitHub, RemoteSha 7598da0; fishycode
517ddab). 1,623,564 of 1,623,626 calls equal a run on each vessel's whole series (81 differ,
explained); 22,988,131 of the 22,988,188 lost pings now in a port call; voyage 1 starts later in 6,183 vessel-years.
Next: the rebuild with plan 059's step 8.

**check:** the fix built, the rebuild's fingerprints compared, no port call cut at New Year, and a decision record.
