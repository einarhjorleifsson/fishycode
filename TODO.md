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

**Dumped 2026-10-17 (decisions 121-122), not yet read:** `taxon` (`tegund_v`: names, WoRMS id, FAO 3-alpha), `orri` whole
(`fisktegundir`, `fao_fisktegund_vorpun`), `ufs.fisktegundir` (the landed species, with FAO code) and
`fs_ufs.landing_species` (landings code to orri code, taxon number, WoRMS id and target assemblage).

**check:** `curated/reference/species.parquet` exists and the catch tables' species
codes all resolve against it.

---

## 15. The three-repo publication boundary
**status:** open · **needs: maintainer** · **see:** `curate/plans/001-three-repo-publication-boundary.md`

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page. The design, the evidence and the
open questions are in the plan. **Answered 2026-10-16 (§4):** fishycode is public
(`github.com/einarhjorleifsson/fishycode`), with its history as it was, so that history is now fixed; the Mapbox token
in it is revoked (maintainer) and out of the working tree. **Answered in part (§3):** the three-vessel rule applies
only to the ICES VMS datacall, and no minimum vessel count applies anywhere else (maintainer, 2026-10-17).

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

## 25. The next STK key redo (`once` project): the review lists
**status:** open · **needs: maintainer** — to confirm the drafted verdicts row by row · **see:** decision 128; plans
009, 016 §4 step 7, 021 step 7, 022 §3 and §7; decisions 047 and 075

The first redo is decision 128 (2026-10-17): SKB as vid 100000 + n, MMSIs broadcast after their window, the coverage
fills and a boundary override for mid 108982. The rest waits for the next one. For each list Claude drafts the
witnesses and a proposed verdict per row, and the maintainer confirms (plan 022 §7 ask 5); confirmed rows enter
`overrides/`:
- the audit's 426 discrepancy rows on 254 mids, the 1,051 rows no witness reaches, and `ais_key_resolution`'s
  proposals (decision 128);
- the 32 stretches filled with a neighbour outside its registered lifetime (34,514 pings, 12 before 2009), on which
  decision 048's review of the stretches for a person is redone;
- vid 7570's MMSI 251477540: the hull was struck in 2018, and the MMSI is heard in west Iceland 2021-24;
- plan 016 §4 step 7's 14 mobile-ids whose MMSI passed to another hull;
- plan 022 §3's 43 co-location units, the 41 key rows the register gives to another vessel, the 37 `mobile_vid`
  claims, and §5.1's 5 port codes;
- after plan 021 step 6: the foreign hulls (plan 021 step 7, TODO 65) with mids 101843, 147141, 102481 and 102527
  (reused call signs), and routes M1/M2 (plan 022 §7 ask 3, the maintainer: not before).

The drafts (2026-10-17) are in `$FISHYDATA/archive/2026-10-17-key-redo/review/`, with a README: 47 distinct `vid`
proposals, the rest `leave` or `no vid`. Before they can act, `ais_key_segments.R` needs a form for "no vessel", a
rule admitting mids named only by a reviewed row (5 rows of list 5a), and the hull start from the earliest
`vessel_hist_v` date or `yh1`: the latest row's is a re-registration, which made most list 2 fills. Decision 129 rebuilt the union on the new key, so the `once` project's
`tar_outdated()` lists the key and its checks again. That is the cycle, not a reason to build: the key changes only here.

The annual register's matrix parse is fixed in code, not yet in data: build years and a legend entry had been read
as vids (22 rows, 2018-2022). The redo invalidates `skipaskra` by hand, since `targets` cannot see the edit; in a
scratch run 6,891 pings on 3 mids change vid (`$FISHYDATA/archive/2026-10-17-skipaskra-vid/NOTE.md`).

**check:** a decision record states the redo; every row of each list is resolved through `overrides/` or carries a
stated reason; `ais_key_coverage` stays at 0 unassigned pings.

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

## 34. Trawl speed ranges, the logbook-gear check and the last haul (plan 012)
**status:** open · **needs: maintainer** — ask (1) · **see:** `curate/plans/012-speed-range-vs-logbook-window.md` (§2e-§2k), `curate/corrections/logger_speed_placeholder.yml`, decisions 085 and 093

Measured: the declared speed range per trawl gear keeps 88-92 % of fixes in recorded tow windows; kW, length and age explain under 5 % of towing speed; a vessel's own range gains nothing over the gear's; shifting the gear range by last year's vessel offset gains 0.2-1 point overall and 4-12 points for the tenth of vessel-years with a large offset; the logbook gear agrees with the landings for 93-99 % of trips. Built from the plan: step 0 (the logger placeholder fix) and step 4 (the gear codes on the trail, decision 085); steps 1-2 were not taken up (decision 093).

**Asked of the maintainer:** (1) whether fish-trawl tows of small vessels near the coast are permitted, so a flag can say "suspect" or "expected", and where a baseline or fjord polygon can come from (5 km from the coast is a stand-in). The same baseline serves the plan's step 5, the 12-mile limit. **Answered:** (2) the declared ranges stay, and `fishing` tests the ±10 min median speed instead of a vessel-shifted range (decision 093); (3) the gear codes on the trail (decision 085).

`uv`'s regulation areas (decisions 121 and 122) may hold the trawl limits; not checked.

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
trail's exclusive windows allow, and §8.7's render is not checked.
**2019-2025, the lead:** Norway's open ERS catch messages. `sources/norway/logbooks.R` reads them, but it is not a
target, it reads from `staging/`, and the files are not on disk. The Faroese half has no lead.

**check:** a `dump/` script writes the foreign logbooks under `raw/` (`raw/oracle/<schema>/` if they are in
Oracle, plan 018), an adapter in `sources/` stages them, and `ais_catch.R` puts
foreign catch on the record path where a logbook exists.

## 65. A vessel registry for every ping, whatever the flag
**status:** in progress · **needs: maintainer** — decision 115's `vessel_ais_link` is built (decision 129: 655,184
rows on the redone STK key, with its review list of 3,023 rows), so next is the first vid allocation,
`allocate_vids(dry_run = FALSE)`, and its readings confirmed; the Directorate of Fisheries asked about MMSI (§6 d);
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

## 74. The landings: trip, gear and catch from each period's source (plans 023 and 025), and plan 007's two questions
**status:** open · **needs: maintainer** — plan 023 §8 asks 1 (who knows what feeds LODS 1 and agf since 2020) and 2
(the write-up), plan 025 §6 asks 1 (factory-vessel live weight) and 2 (when to build), plan 007 §6 questions 1 and 3
· **see:** `curate/plans/023-landings-trip-gear-catch.md`, `curate/plans/025-ask-mined.md`,
`curate/plans/007-landings-merge-agf-lods.md` §6, decision 031, plan 022

Plan 023 has the inventory and the columns of ask, kvoti and agf measured, and nothing built. Its §6, each landing to
its trip from four sources, builds on plan 022 §4 (TODO 68). Plan 007's merge is built (decision 031), with two
questions left: a `curate/checks/` report of every trip where agf and lods disagree, since agf wins on disagreement
and the merge cannot show an agf defect; and keying `link_lid_map.R` and `catch_by_species_trip.R` on
`(.lid, schema_land)`, not `.lid` alone. Plan 025 has ask mined whole and its design chosen (agf's rows, ask's
columns, a weighing table), nothing built: its first weighing time bounds `T2` to the hour for 2007-2020, and agf keeps
zero-kg landings that the Directorate withdrew.

**check:** the asks of plans 023 and 025 are answered in the plans, and each is built, parked or abandoned in its
header; and plan 007's questions 1 and 3 are answered in a decision.

## 75. Afli trips lost whole, and the rows before 2007-09 (decision 098's open ends)
**status:** open · **see:** `curate/decisions/098-dropped-afli-hauls-not-admitted.md` ("Open"), plan 005

Decision 098 did not admit the afli hauls the stofn merge dropped. It left two things open. About 410 trips are lost
whole yet have a landing that no logbook trip took: they are the only candidates for genuinely missing records, and
nothing proves them (in the 219 with catch on both sides, the lost catch is 0.87 of the landing, median). Before
2007-09 no landing link reaches the rows: 1,854 rows, mostly 2004-2006, where the share absent was highest (19 % in
2004), and whether those are copies is unknown.

**check:** a decision says, for the 410 trips and the 1,854 rows, whether they are admitted, with the evidence.

## 79. Every source station accounted for in the logbook merge (plan 024)
**status:** open · **needs: maintainer** — the go, and plan 024's four asks (§6) · **see:**
`curate/plans/024-logbook-station-fate.md`

`curate/logbook.R` drops staging stations by date bounds and (vid, date) tiers, and nothing records them: a dropped
station is simply absent from `curated/logbook`. Plan 024 proposes `curated/logbook/station_fate.parquet`, written by
the merge, one row per staging station with whether it is kept and, if not, why, and measures what it would hold on
the build of 2026-10-16: 702,988 stations dropped (8,131 kt as recorded), 99 % of held vessel-days copies of what is
kept.

**check:** `curated/logbook/station_fate.parquet` exists, has one row per staging station, and reproduces plan 024
§2's counts; a decision records it.

## 81. A trip's catch landed over two days: `lid_map` claims one landing
**status:** open · **needs: maintainer** — plan 027's four asks · **see:** plan 027, plan 026 §11, plans 025 and 014,
`curate/link_lid_map.R`, `curate/ais_catch.R`

`lid_map` gives a trip one landing, and `ais_catch.R` shares every landing it leaves unclaimed, mostly on the trip's
own fixes (its voyage link sees only unclaimed landings). Measured 2026-10-17 (plan 027 §2-§3): of 9,955 next-day
landings at the same port (68.8 kt), 1,246 (30.2 kt) came with the vessel in port, 490 of them (23.0 kt) also in the
logbook, so counted twice; 8,376 (31.2 kt) came after it fished again. Another port or 2-7 days later adds 1,529
(65.4 kt). Plan 027 proposes plan 025's `withdrawn` first, a flow table `trip_landing` read by `ais_catch.R`, and
the voyage link given every landing. Nothing changed in the pipeline.

**check:** a trip's further landings join it (plan 027 §5), and kg on the fixes, raised, equals kg landed per vessel
and year within the ratio of vessel-years with no second landing (plan 027 §6).

## 82. MMSI windows that open before the hull exists
**status:** open · **needs: maintainer** — whether the gap goes to the previous holder or to no vid, and whether to
apply the patch · **see:** plan 016, decision 128, `reference/vessels/mmsi.R`, `reference/vessels/identity.R`,
`$FISHYDATA/archive/2026-10-17-mmsi-window/`

Measured read-only by Claude, 2026-10-17. Of the 24 vessel MMSIs with more than one holder, 18 later holders'
hand-set windows open 1.9-14.5 years before the hull's first register date. One has pings in the gap: 87,372 ASTDB and
EMODnet pings of MMSI 251764110 carry vid 7873 from 2017-02 to 2018-01, but they are the sold hull 2608 in northern
Norway. 79,721 of them reach `curated/ais/trail` (2 voyages, no catch). None falls in W1's box, and the key's MMSI tier
gives the same vids. The drafted rule: a later holder's window opens no earlier than its first register date, and the
previous holder keeps the gap (decision 128's rule), with the given dates kept and a `proposed` correction. The patch
(4 files) and its note are in the archive above, not applied. It outdates the AIS half (about 2 h) and the `once` key
targets. Found beside it: the later holders 3009 (MMSI 251179000) and 7764 (251846940) are in neither `vessel_hist_v`
nor `vessel.parquet`, so `identity.R` drops them and the earlier holders keep those MMSIs for all time.

**check:** no MMSI window opens before its hull's first register date, or the maintainer's alternative is recorded;
MMSI 251764110's pings of 2017-02 to 2018-01 carry vid 2608 (or none); 3009 and 7764 are resolved or stated.
