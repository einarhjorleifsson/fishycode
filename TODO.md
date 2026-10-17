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

## 10. `reference/species` is an empty directory
**status:** open
**see:** `curate/decisions/019-the-check-layer-exists.md`

This item's other half (`curated/check/`) closed in decision 019. What is left is the species reference.
`reference/species/` is an empty directory and `curated/reference/` has no species table, so nothing in the sweep
resolves a species code to a name. Every other reference domain — gear, ports, geo, vessels — has one.

**Raw holds no proper list (measured 2026-10-17).** Each source has a partial list of its own: `afli/fiskar` (68
codes), `adb/species` (410), `kvoti/lods_fteg` (125) and `kvoti/stadall_fisktegundir_v` (74, the only one with
English and scientific names); `asfis/asfis` is FAO's list, with no Icelandic code. Together they resolve every
`sid` in `curated/logbook/catch` and `curated/landing/catch` but 9 codes (11 by schema): afli's 999 (74,706 rows,
143,586 t, 0.32 % of afli kg) and 0, lods' 0, agf's 665, 533, 278, 1128, fs_afladagbok's 665, 269, 954, 901 (almost
no kg). Not checked: that the lists name a shared code alike, and an Icelandic code → FAO 3-alpha link (none in raw
beyond the 74 scientific names).

**check:** `curated/reference/species.parquet` exists and the catch tables' species
codes all resolve against it.

---

## 15. The three-repo publication boundary
**status:** open · **needs: maintainer** · **see:** `curate/plans/001-three-repo-publication-boundary.md`

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page. The design, the evidence and the
open questions are in the plan. **Answered 2026-10-16 (§4):** fishycode is public
(`github.com/einarhjorleifsson/fishycode`), with its history as it was, so that history is now fixed; the Mapbox token
in it is revoked (maintainer) and out of the working tree. **Answered in part (§3):** the minimum of 3 vessels per cell
applies only to ICES datacall deliveries (maintainer, recorded 2026-10-02).

The boundary that still needs a rule is `fishydata` → `fishyweb`, a data-disclosure question that binds item 16.
**Asked of the maintainer, in the plan's own words:** the rest of the aggregation rule for what may leave `fishydata`
for an open `fishyweb` (the minimum cell and the allowlist of tables, §3); and §5: where `fishydata` lives and whether
it is backed up, whether `fishyweb` reads `fishydata` directly or only extracts committed to it, and whether `ramb` is
public. Everything else in the plan I can act on unblocked. `fishyweb` has local commits that wait for its
first remote too (27b35ff, the plan 014 names; from TODO 52).

**check:** the questions of plan 001 §3 and §5 are answered in the plan.

---

## 16. `~/stasi/fishyweb` — port the last mile
**status:** blocked · **see:** `curate/plans/002-the-last-mile.md`, item 15

`fishyweb` is alive, not an archive (maintainer, 2026-09-22) — the third repo of plan
001, keeping its 22 `ramb/` posts. The question is what to *port*, and the design is in
plan 002. Blocked on item 15's disclosure rule, which decides what may leave
`fishydata` at all.

**check:** plan 002's port list is built and item 15's disclosure rule exists.

---

## 24. Icelandic vessels that land fish but are never heard on AIS
**status:** open · **see:** decisions 110, 117 and 118, `curate/checks/ais_key_landings.R`

`ais_key_landings`' `landed_but_no_ais` lists 308 vids (the `once` file of 2026-10-09). It audits the cascade, not
the key (decision 053), so 53 of them are in the key and heard, and 148 are foreign. **107 Icelandic vids landed in
the AIS era with no key row and no ping from any provider in the union:** 96 registered vessels (9 with an MMSI, 67
landing in 2013 or later) and 11 landings placeholders. A vessel name is never used to
match, and the MMSI route is already taken, since the union takes ASTD, astdB and EMODnet by MMSI. What is left is to
say why each has no track: no transponder (a small boat), an STK unit the key leaves without a vid (plan 022 §3), or a
missed match.

**The divers (from TODO 67):** 8009 (the register's útgerðarflokkur "Kafarar") and very likely 8008 land only with gear
23 "Kafari", about 14 t on 152 landing rows, and have no hull. Mark them as divers, through an override that names the
two or a rule (a registration that lands only with gear 23).

**check:** each of the 107 has a stated reason in a check table or an override: no AIS expected, an STK unit or MMSI
found, or a match missed; and 8008 and 8009 carry a diver class and `landed_but_no_ais` leaves them out.

---

## 25. The STK key redo (`once` project): what enters it
**status:** open · **needs: maintainer** — the review of what enters and who reviews it (plan 022 §7 asks 3 and 5), a
boundary override for mid 108982, and the go for the redo · **see:** plans 009, 016 §4 step 7, 021 step 7, 022 §3 and
§7; decisions 047, 053, 075 and 117-119

The key is frozen and redone only by a decision (decision 075). Eight reviews wait on the same redo:
- **The audit** (plan 009, decision 047): 402 discrepancies on 239 mids (`once` files of 2026-10-09), none reviewed; 840
  vid-claiming rows no witness reaches; `ais_key_resolution`'s 30 proposals on 25 mids (track correlation confirms 12
  of the 14 strong ones); the segment table's 108 stretches (97,850 pings) for a person, on which decision 048's
  review is to be redone.
- **Coverage:** `ais_key_coverage` holds 31,512 unassigned pings in 344 stretches (the largest 4,962, mid 108582); the
  maintainer's invariant is no unassigned ping.
- **Mid 108982** (from TODO 39): the segment table gives it to 7830 from 7830's registration day, 2018-04-13, but the
  pings and 2835's own astdB say 2835 held it to 2018-07-19 (5,029 pings). The reviewed override moves no boundary.
  Asked: a boundary override, or a rule that a registration date does not cut where the earlier holder's AIS still
  witnesses the mid. How many mids have this shape is not counted.
- **SKB** (plan 016 §5, decision 119): 179 mobile-ids (357,642 pings), no vid and class "vessel" in the frozen key, to
  vid 100000 + n, class pleasure craft. The registry half is built, and the ASTD and astdB fixes reach the trail.
- **The archive** (plan 016 §4 step 7): 14 mobile-ids whose MMSI passed to another hull (626k pings), and 42 with no
  vid whose MMSI the archive gives to a vid (15k pings).
- **Foreign hulls** (plan 021 step 7, TODO 65): the foreign candidates on the same vids, and mids 101843, 147141,
  102481 and 102527 (reused call signs).
- **STK mined, review lists** (plan 022 §3, point 10): 43 units with no vid whose MMSI is an Icelandic vid's, 41 key
  rows the register gives to another vessel, 37 `ops$einarhj.mobile_vid` claims naming another vid.
- **STK mined, MMSI routes** (plan 022 §7 ask 3): whether routes M1 and M2 (14.5 M positions on vessel units with no
  vid) enter the key, with the 1,772 units created since the key's dump.

Two `once` checks filter `vid < 3700`, dropping every Icelandic vid from 5000 up (`ais_key_reused_callsign.R:70`,
`ais_key_landings.R:87`; decision 119); at the redo they take the `foreign` flag instead.

**check:** a decision record states the redo; `ais_key_coverage` reports 0 unassigned pings; every row of
`ais_key_audit_discrepancy` and of the lists above is resolved through `overrides/` or carries a stated reason; and
mid 108982 is 2835 through 2018-07-19, with the count of registration-date boundaries that cut a witnessed run.

## 27b. Link pings to trips and fishing activity (the `trail`), and deliver from it
**status:** in progress - phases 0-3 built; the trail rebuilt 2026-10-16 (decision 112) · **needs: maintainer** —
plan 015 §4's nine choices (a-i), none answered · **see:** `curate/plans/015-datacall-on-the-curated-trail.md` (the datacall), `curate/plans/010-ping-activity-link.md` §7, §10-§12b, decisions 095 and 118

Built: `gear_window`, `station_window`, `curated/ais/trail` (AIS + the gps logger feed, plan 014), with the voyage's
trip (`.tid_voyage`) on fixes outside every window. Open: the datacall. `products/ices_vms_datacall/build.R` is the
2025 delivery script with only its paths changed, and it cannot run here (checked 2026-10-14). It reads columns the
current `ping_union` does not have (`.sid`, `s1`/`s2`, `t1`/`t2`, `met6`, `dt`, `dd`, habitat, depth, catch per fix),
a `station-for-ais.parquet` nothing here builds, and `agf_gid`/`met6` that `gear.parquet` lacks.
Repointing it means building its inputs from the curated tables. Built since 2026-10-14: the trail's `fishing`
(decision 093), `hours` and `kw_hours` on each fix (decision 101), and catch per fix in `curated/ais/catch` (decisions
101-102). Not built: metier 6 from the mesh size (the trail's `metier` column is there, its level not checked), swept
area from distance and gear width, habitat and depth by spatial join, and the logbook (LE) table without duplicate twins.

Plan 015 designs it, checked against the 2025 delivery. Also open: whether to store a sorted wide trail (maintainer).

**The old trail stays until then (from TODO 8):** `~/stasi/fishydata_2024-2026/data/ais/trail` (31 GB) is the input of
the 2025 delivery (`ices-datacall/2025/2025_vms-datacall.R` reads it), and the delivered CSVs are not kept locally. It
reproduces that delivery and is the baseline for the comparison. Removed and restored on 2026-10-14 (decision 095).

**check:** `products/ices_vms_datacall/build.R` runs on `curated/ais/trail`, its output is compared with the 2025
delivery and supersedes it, every synthesised window carries `win_basis`, and no directory under
`~/stasi/fishydata_2024-2026` exceeds 1 GB.

## 34. Trawl speed ranges, the logbook-gear check and the last haul (plan 012)
**status:** open · **needs: maintainer** — ask (1) · **see:** `curate/plans/012-speed-range-vs-logbook-window.md` (§2e-§2k), `curate/corrections/logger_speed_placeholder.yml`, decisions 085 and 093

Measured: the declared speed range per trawl gear keeps 88-92 % of fixes in recorded tow windows; kW, length and age explain under 5 % of towing speed; a vessel's own range gains nothing over the gear's; shifting the gear range by last year's vessel offset gains 0.2-1 point overall and 4-12 points for the tenth of vessel-years with a large offset; the logbook gear agrees with the landings for 93-99 % of trips. Built from the plan: step 0 (the logger placeholder fix) and step 4 (the gear codes on the trail, decision 085); steps 1-2 were not taken up (decision 093).

**Asked of the maintainer:** (1) whether fish-trawl tows of small vessels near the coast are permitted, so a flag can say "suspect" or "expected", and where a baseline or fjord polygon can come from (5 km from the coast is a stand-in). The same baseline serves the plan's step 5, the 12-mile limit. **Answered:** (2) the declared ranges stay, and `fishing` tests the ±10 min median speed instead of a vessel-shifted range (decision 093); (3) the gear codes on the trail (decision 085).

Open, not blocked: whether the last haul of a trip is left unclosed. Not seen at the window level (§2d) or in the logger's speed after `t3` (§2k); the logbook end looks late on some last tows, not early.

**check:** the answer to (1) is recorded in a decision, and plan 012 says whether the last haul is left unclosed.

---

## 38. Loose ends of the `whack_clean()` switch
**status:** open · **see:** `curate/decisions/067-whacky-positions-are-labelled-by-whack-clean.md`, fishyweb `notes/whacky-positions.qmd`

The switch and the rebuild downstream of it are done (decision 067). Of the 208 vessels where the new filter flags
more, the 62 vessel-years that also keep a longer track were looked at: placeholder positions are now flagged first
(`curate/corrections/ais_invalid_position.yml`). Left, none blocking (decision 067): vessels faster than 25 kn lose
real track under either filter - 84 fishing vessels, all under 12 m, 8,433 real pings, steaming only (needs a choice:
a per-vessel limit, or not flagging a leg the vessel's own recorded speed confirms); the forward scan accepts the
first ping after a gap of more than 4 h untested (vid 2657, 2017); sparse tracks (vid 1186, 2023). Shown on
simulated tracks in the review package (github.com/einarhjorleifsson/test): vmask erodes good track beside a burst
moved along the heading (8 good pings lost), and a burst within reach of the last good ping is partly kept. fishyweb `notes/whacky-positions.qmd`
is untracked and shows vessel tracks, so the disclosure rule comes first.
A third fast-vessel option, to revisit later (from Ifremer's iapesca, 2026-10-09, not built): a run of 3+ legs over 25 kn
whose two-ping legs are fast too is real running - in June 2023 it held 1,115 of the filter's 8,942 flags, recorded SOG > 20 kn on 90-98 %; needs a speed cap (decision 078).

**check:** decision 067 records a verdict on the fast-vessel, gap and sparse-track cases, and
`notes/whacky-positions.qmd` is committed or removed.

## 49. AIS as a qualifier where the logbook or the landings are missing
**status:** open · **needs: maintainer** — whether to qualify them, and the classes · **see:** plan 014 §1, decision 103

Preprocessing reads no AIS (decision 075), but some AIS tracks may be truly fishing with no logbook or even landing
behind them. Counted (plan 013 rows 5-6; decision 103): voyages with neither are 29-43 % a year since 2017, most by
vessels that land nothing all year; `curated/check/vessel_activity.parquet` suggests a class for each such
vessel-year (whale watching and aquaculture explain 69,198 of 108,505 such voyages in 2021-2025). The flow gives a
voyage with neither no gear, so no speed range and no fishing: whether it should qualify the rest is the
maintainer's.

**check:** a decision says whether the flow qualifies voyages with neither a logbook trip nor a landing, and the
suggested classes of `vessel_activity` are confirmed through an override or dropped.

## 51. `docs/data-dict.yaml` fails the current data-dict spec
**status:** open · **see:** decision 029

Decision 029 validated it with zero errors; the tool's spec has moved on (data-dict 0.0.3, `datadict::dd_install()`).
On 2026-10-15 a table-level `primary_key` the spec does not allow was moved into `details`, the tables and columns of
decisions 099-104 were added (`ais_catch`, `ais_voyage_gear`, `check_landed_logged`, `check_survey_tow_times`,
`check_vessel_activity`, 16 trail and trail_match columns), and the trail's `.tid` columns were corrected to text:
141 errors, none in the new entries (130 `S07`: a number or string column without `examples`, a datetime without
`range`; 11 `S28`: the types `timestamp` and `double`). `validate-meta` stops at any spec error in the file; on a
scratch copy of the seven tables touched it passes with no warning. The tool reads no `*` glob, so a partitioned
table names one representative file (decision 029).
Plan 016's tables are built (decision 112) and not in the file yet (checked 2026-10-17): `vessel/mmsi`,
`vessel/vessel_year`, `vessel/vessel_class`, `vessel/vessel_sign`, the columns `status`, `foreign`, `register` in
`vessel.parquet` and `kw_basis`, `leisure`, `leisure_basis` on the trail.

**check:** `data-dict validate-spec docs/data-dict.yaml` and `validate-meta` pass with zero errors, and the tables of
plan 016 are in the file.

## 62. Foreign vessels' logbooks for Icelandic waters
**status:** open · **needs: maintainer** — where they are: an Oracle schema and table, or an extract from Fiskistofa ·
**see:** plan 013 item 5, decisions 102-103, plan 017 §3 (`raw/oracle/afli/steini.parquet` is a partial one: oceanic redfish, 1989-2017; whether to stage it is
plan 017's ask g)

The maintainer said yes on 2026-10-14: acquire them. Foreign vessels land 80-124 a year in Iceland and hold most of
the landed weight with no Icelandic logbook trip (plan 013, rows 4 and 9; 1,144 of 1,320 kt of pelagic species in
2019-2025). They are not in what is dumped: the logbook tables hold 6 foreign trips in all, and none of the four
logbook schemas (afli, fs_afladagbok, adb, logbook) has a foreign table.

**check:** a `dump/` script writes them under `raw/` (`raw/oracle/<schema>/` if they are in Oracle, plan 018), an
adapter in `sources/` stages them, and `ais_catch.R` puts
foreign catch on the record path where a logbook exists.

## 65. A vessel registry for every ping, whatever the flag
**status:** in progress · **needs: maintainer** — the go to build decision 115's targets, then the first vid
allocation, `allocate_vids(dry_run = FALSE)`, and its readings confirmed; the Directorate of Fisheries asked about MMSI (§6 d);
PAME's answer on ASTD (asked 2026-10-17, §6 h) · **see:** `curate/plans/021-vessel-registry-for-every-ping.md`,
plans 008, 016 and 017, decisions 114-115 and 118, TODO 15 and 25

The maintainer asked on 2026-10-15 for a registry of every vessel the pings carry, not only the Icelandic ones. Plan 021
proposes one integer `vid` per hull and a crosswalk from each feed identity to it. Its asks are answered (a revised and
c amended 2026-10-17, i answered the same day: a vid is kept when a hull's key changes). Step 1 is built (decision 114),
steps 2-4 are code checked in scratch (decision 115).

The 52 links in `overrides/vessel_ais_link.csv` for 50 of the 59 `foreign_vid_candidate` MMSIs were confirmed on
2026-10-17; 9 stay held. Left from that review: 19 of them (class B) rest on the hand-made STK call-sign sheet
`overrides/stk_foreign_mid_vid.csv`, whose entries want checking; 27 MMSIs carrying a linked hull's IMO would still get
a second vid (a change to `curate/vessel_ais_link.R`); the STK key is wrong for mids 101843, 147141, 102481 and 102527
(reused call signs, step 7's redo, TODO 25); foreign vids 3777 (a duplicate of 3756), 4077 and 3792 are not one hull each.

**From TODO 22:** a ping with no vid is still dropped before the voyages: STK by the key's join
(`sources/stk/convert.R:31`, `curate/ais_ping_union.R:78`), the other feeds by the MMSI periods
(`curate/ais_ping_union.R:62`). A foreign hull reaches the voyages once the union reads the crosswalk (plan 021 step 6);
`ports_all` already holds the ports abroad. Also open (maintainer): plan 017's asks e (gear for a foreign voyage with
no landing in Iceland) and f (ports abroad), and whether a dominant IMO (99 % of the IMO pings, 176 of the 636
`two_imos` segments) may be linked by rule rather than one override each (decision 115).

**check:** plan 021 §7, and plan 017 §7's check that a foreign vessel's ping reaches `curated/ais/voyage.parquet` with
a voyage key and `pid1`/`pid2` resolved.

## 68. stk's tables besides the trail: what they hold, and which fishycode should read
**status:** open · **needs: maintainer** — the go for plan 022 §4, and its asks 1 (who knows what STK's export and
backup tables were for) and 4 (survey windows) · **see:** plan 022 (§2.1, its appendix, §4, §7), decision 109,
`curate/ais_voyage.R`, `curate/port_stay.R`

The maintainer asked for every stk object besides the trail to be checked: some are copies of the trail, some may be
very useful. Plan 022's appendix (2026-10-16) says what each of the 63 holds, so the first half of the check is met.
Left is **`tilk_stk_allt`**: 3,186,904 recorded voyages, 2003-09-08 to 2021-02-08, port to port, with times and the
trail ids at both ends. It is of value three ways (maintainer): voyages before mid-2007, where the trail has almost no
track; recorded departures and arrivals to check, or correct, the voyages and stays cut from the track; and a
departure time (T1) for logbook trips and landings, with its own basis. The comparison is plan 022 §4. The voyages
it needs were rebuilt on 2026-10-16 (decision 112); it waits for the maintainer's go. Ask 4: whether
`leidangrar_ctrl`'s windows mark the survey tows of chartered vessels in the trail (plan 022 §5.1).

**check:** each stk table besides the trail has a line saying what it holds, its time span and keys, and whether
fishycode reads it; and `tilk_stk_allt` is compared with `curated/ais/voyage.parquet` on a sample of vessels, the
result recorded in a decision or a plan.

## 69. Partitioned outputs keep partitions a rebuild no longer writes
**status:** open · **see:** decision 111

`duckdbfs::write_dataset()` replaces the partitions it writes and leaves the others. `staging/ais/stk` still holds
`year=1970` and `year=2006` from the build of 2026-09-23 (3 rows), which every reader of it takes in. Any partitioned
output can carry an older build's rows the same way. Clear the directory before each write, or check for it.
Measured after the rebuild of 2026-10-16 (decision 112): of the eight partitioned outputs it wrote, only
`staging/ais/stk` holds files older than the build (those two).

**check:** no partitioned output under `staging/` or `curated/` holds a partition its last build did not write, and
the scripts that write them make sure of it.

## 70. `afli.afli`: which stored values `TO_CHAR` rejects
**status:** open · **needs: maintainer** — the query in plan 018 §3, run against Oracle · **see:**
`curate/plans/018-raw-oracle-dumps-as-is.md` §3, decision 109

The dump reads `afli.afli` and `v_afli` whole: `TO_CHAR` fails on `visir`, which is read natively, and its values match
the April copy exactly (decision 109). Which rows and stored bytes `TO_CHAR` rejects is not known; the query in plan 018
§3 (`DUMP()` only, one scan) names them. The 48 empty `afli` values (46 stations) are in both copies and are not this
fault.

**check:** the rows the query returns are recorded in a decision or a correction, with whether they are the 48 empty
values.

## 71. The `ops$einarhj` MMSI list of 2023-01-15: find it or dump it
**status:** open · **needs: maintainer** — where a copy is, if one exists; else dump `mmsi_icelandic_registry_20230115`
(and `vessel_mmsi`) on the server; also where the 2024-10-22 list is, and who refreshes MFRI's copy of the vessel
register, stale since about June (plan 016 §7, "still open, not asked") · **see:** plan 022 §3.1, `reference/vessels/mmsi.R`, decision 111, decision 119

Ten tables of `ops$einarhj` are not dumped. Judged from the dump's overview (columns, Oracle's row counts), only one
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

Items 0-3 and 5 are built and on the data. Items 4 and 6-9 are built in part, and item 10 not at all (decisions
099-103). What is left of each is in the plan:
- 4, records checked against the operations the track shows;
- 6, which vessels fish (the vessel row; the classes are TODO 49);
- 7, records without pings: the 1990-2006 logbook (3.5 M records, start positions only) needs a target of its own,
  since the years before 1990 are out of scope (decision 103);
- 8, static gear: `rb_link_record_sets()` is in ramb, and its run on the Icelandic static hauls and pressure as
  quantity × soak are not built (decision 103). ramb's NEWS (53519ee, 2026-10-16) reports a measurement on the 2023
  Icelandic static-gear hauls that no fishycode record holds;
- 9, track models for fishing;
- 10, declared times reconciled with the track (`rb_reconcile_time()`): unblocked by decision 104's ground truth,
  not in ramb.

**check:** each of items 4 and 6-10 is built and on the data, or plan 013 says why not, and a decision records it.

## 73. Plans 019 and 020: the fs_afladagbok tables, gear detail and environment
**status:** open · **needs: maintainer** — plan 019 §6 asks 1-7, plan 020 §5 questions 1-6 · **see:**
`curate/plans/019-fs-afladagbok-mined.md`, `curate/plans/020-gear-part-and-environment.md`

Two proposals of 2026-10-15, prototyped in scratch, with nothing in the pipeline. Plan 019 sets fs_afladagbok's 32
objects against the grammar (the tour app, the port translation, implausible catch, mammal and bird bycatch, the depth
unit by app). Plan 020 keeps the gear detail and the environment that the adapters fold away, as tidy tables beside
the fishing sample (`gear_part` prototyped for fs).

**check:** each plan's asks are answered in the plan, and each is built, parked or abandoned in its header.

## 74. The landings: trip, gear and catch from each period's source (plan 023), and plan 007's two questions
**status:** open · **needs: maintainer** — plan 023 §8 asks 1 (who knows what feeds LODS 1 and agf since 2020) and 2
(the write-up), plan 007 §6 questions 1 and 3 · **see:** `curate/plans/023-landings-trip-gear-catch.md`,
`curate/plans/007-landings-merge-agf-lods.md` §6, decision 031, plan 022

Plan 023 has the inventory and the columns of ask, kvoti and agf measured, and nothing built. Its §6, each landing to
its trip from four sources, builds on plan 022 §4 (TODO 68). Plan 007's merge is built (decision 031), with two
questions left: a `curate/checks/` report of every trip where agf and lods disagree, since agf wins on disagreement
and the merge cannot show an agf defect; and keying `link_lid_map.R` and `catch_by_species_trip.R` on
`(.lid, schema_land)`, not `.lid` alone.

**check:** plan 023's asks are answered in the plan and it is built, parked or abandoned in its header; and plan 007's
questions 1 and 3 are answered in a decision.

## 75. Afli trips lost whole, and the rows before 2007-09 (decision 098's open ends)
**status:** open · **see:** `curate/decisions/098-dropped-afli-hauls-not-admitted.md` ("Open"), plan 005

Decision 098 did not admit the afli hauls the stofn merge dropped. It left two things open. About 410 trips are lost
whole yet have a landing that no logbook trip took: they are the only candidates for genuinely missing records, and
nothing proves them (in the 219 with catch on both sides, the lost catch is 0.87 of the landing, median). Before
2007-09 no landing link reaches the rows: 1,854 rows, mostly 2004-2006, where the share absent was highest (19 % in
2004), and whether those are copies is unknown.

**check:** a decision says, for the 410 trips and the 1,854 rows, whether they are admitted, with the evidence.
