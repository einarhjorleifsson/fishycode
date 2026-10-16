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

## 8. The old trail stays until the datacall is rebuilt on the curated trail
**status:** blocked — on item 27b · **see:** decision 095

`~/stasi/fishydata_2024-2026/data/ais/trail` (31 GB) is the input of the 2025 ICES VMS datacall delivery
(`ices-datacall/2025/2025_vms-datacall.R` reads it), and the delivered CSVs are not kept locally. It reproduces that
delivery and is the baseline for checking item 27b. Removed and restored on 2026-10-14 (decision 095).

**check:** a datacall built on `curated/ais/trail` has been compared with the 2025 delivery and has superseded it,
and no directory under `~/stasi/fishydata_2024-2026` exceeds 1 GB.

---

## 10. `reference/species` is an empty directory
**status:** open
**see:** `curate/decisions/019-the-check-layer-exists.md`

This item used to read "`curated/check/` does not exist". That half is **closed** —
it holds three tables and the contract a check owes its reader is written down in
decision 019. The claim had gone stale before anyone noticed, which is why it is
recorded rather than quietly edited.

What is left is the species reference. `reference/species/` is an empty directory and
`curated/reference/` has no species table, so nothing in the sweep resolves a species
code to a name. Every other reference domain — gear, ports, geo, vessels — has one.

**check:** `curated/reference/species.parquet` exists and the catch tables' species
codes all resolve against it.

---

## 18. Fishing windows from behaviour, not from the logbook — PARKED
**status:** parked (maintainer, 2026-10-14: the measured gain is too small to build for now) · **see:** `curate/plans/004-behavioural-fishing-windows.md` (§8, measured 2026-10-14), decisions 090, 092, TODO 60

Infer fishing time from the track where the logbook gives none. Measured (plan 004 §8): day windows hold 80.7 % of
jigging fishing fixes, 22.8 % of static and 0.6 % of towed. A day window calls 18-30 % more static fixes fishing at
sea than the real hauls (an upper bound: unlogged setting), and cuts the 23 % of hauls that cross midnight.
Jigging was tested and stopped (§8). A speed rule relative to the local drift does no better than a fixed one
(0.62 against 0.635 balanced accuracy), and the logged sessions are too coarse to tell more. Left: static gear, by
placing each station on a hauling bout by its recorded position, scored on the holdout bench. The ceiling is about
+5 % of static fishing fixes, so it is worth building only if a delivery needs static-gear effort that precise.
Towed gear needs no window work for effort; the reported heading is the course.

**check:** none while parked. It reopens when a delivery needs static-gear effort that precise; plan 004's
header then records, for each of its five measurements, the answer or where it lives.

## 17. Full review of the STK vessel match
**status:** open · **needs: maintainer** · **see:** `curate/plans/003-stk-vessel-identity.md`,
`curate/plans/008-north-atlantic-vessel-registry.md`, `TODO.md` item 25 (the audit)

Reviewed 2026-09-22; steps 1–7 and 9 done (decisions 015, 020, 021, 032, 033,
034). Step 8 (foreign-vessel identity) is absorbed by and built in plan 008 —
`ais_key_foreign.R`'s six-stage cascade, 7,549 candidates proposed (decisions
036, 039, 040, 041). Plan 008's own Phase 7 (`_targets.R` wiring) and ongoing
candidate review remain open there, not here.

**`TFUT` resolves (checked 2026-10-14, plan 016 §2 i):** all four Fjarskiptastofa lists and Oracle's `vessel_mmsi`
give it to vid 2173 (MMSI 251017000), and the key already assigns its mid 133558 to 2173 (step `segment: registry`).
The 2026-09-27 reading ("two holders, both ending 1995") is superseded. `TFPH` is not rechecked.

**Asked of the maintainer:** the 88 Icelandic vids with no MMSI on record
(plan 003 §4.7 and §6; the note once at `ais_key.R:16-19` is gone) — a Fiskistofa/Fjarskiptastofa data
refresh, not a code fix. The refresh of 2026-10-14 is measured in plan 016 (TODO 63).

**check:** the 88-vid gap and `TFUT` both resolve against a refreshed pull, or
this item states why they can't.

## 15. The three-repo publication boundary
**status:** open · **needs: maintainer** · **see:** `curate/plans/001-three-repo-publication-boundary.md`

**Answered 2026-10-16 (§4):** fishycode is public on GitHub, with its history as it was; the
Mapbox token in that history is revoked (maintainer) and out of the working tree.

**Asked of the maintainer, in the plan's own words:** set the aggregation rule for what may
leave `fishydata` for an open `fishyweb` (§3), and say where `fishydata` lives and whether it
is backed up (§5). The
disclosure rule blocks item 16. Everything else in the plan I can act on unblocked.
`fishyweb` has local commits that wait for its first remote too (27b35ff, the plan 014 names; from TODO 52).

**check:** the questions of plan 001 §3 and §5 are answered in the plan.

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page.
The design, the evidence and the open questions are in the plan; this stub exists so
the work is visible here. `fishycode` has been public on GitHub since 2026-10-16
(`github.com/einarhjorleifsson/fishycode`), so its history is now fixed. The boundary that actually needs a rule is
`fishydata` → `fishyweb`, which is a data-disclosure question and binds item 16.


---

## 16. `~/stasi/fishyweb` — port the last mile
**status:** blocked · **see:** `curate/plans/002-the-last-mile.md`, item 15

`fishyweb` is alive, not an archive (maintainer, 2026-09-22) — the third repo of plan
001, keeping its 22 `ramb/` posts. The question is what to *port*, and the design is in
plan 002. Blocked on item 15's disclosure rule, which decides what may leave
`fishydata` at all.

**check:** plan 002's port list is built and item 15's disclosure rule exists.


---

## 21. GFW effort data may be worth cross-checking against STK
**status:** open · **see:** `curate/plans/008-north-atlantic-vessel-registry.md`

Not a vessel registry — GFW's own effort grids are activity data, the same kind as
`staging/ais/astd`, not identity like the rest of plan 008. Landed alongside it in
`~/garbage/vessels_from_.../gfw/`, not yet moved into `$FISHYDATA`:
`mmsi-daily-csvs-10-v1-5-2018.zip` (per-MMSI, 0.1°, 2018 only) and
`fleet-daily-csvs-100-v2-2020.zip` (flag+geartype, 0.01°, 2020, no MMSI).

Partners the maintainer has worked with have questioned GFW's data quality. The
Icelandic fleet is exactly the population where that is answerable — STK is this
project's own authoritative trail for it. A comparison here would be the same shape as
`curate/checks/ais_key_landings.R` (report disagreement, never correct from it).

**check:** a check exists comparing GFW-attributed Icelandic fishing effort against
STK's own trail for at least one overlapping year (2018, via `mmsi-daily`).

---

## 22. Foreign vessels never reach trip segmentation, even once identified
**status:** open · **see:** `curate/plans/008-north-atlantic-vessel-registry.md`, `curate/plans/017-foreign-vessels-through-the-flow.md`
(measured 2026-10-14: foreign vids keyed in STK already reach voyages; the plan proposes a vid, not an `external_id`, for the rest)

`reference/ports/ports_all.R` (kaenugardr, absorbed) already merges 24,653 harbours
globally — GFW's 12,831 worldwide anchorages, EMODnet's 946 European ports, GISCO's
2,440 EU ports, plus OSM/vmstools/local sources. The geometry side of "a foreign
vessel's trip start/end harbour" is ready and has been since the absorption.

The identity side is not, in three specific places, all keyed strictly on Icelandic
`vid`: `sources/stk/convert.R:31` and `curate/ais_ping_union.R:74` both
`inner_join(..., filter(!is.na(vid)))` — a ping with no Icelandic vid is dropped
before it ever reaches `curate/ais_voyage.R`, which then groups voyages by `vid` alone. The flow's
contract (plan 013, decided item 9) is that such a ping is kept with vessel `none`, not dropped.
Plan 008's `external_id` (§5–§7) will resolve identity for vessels that were never
going to get an Icelandic vid — but as things stand today, their pings never survive
long enough to be segmented into trips at all, no matter how good that resolution is.

**check:** a ping carrying an `external_id` but no `vid` (plan 008's foreign match)
survives into `curated/ais/voyage.parquet` with a voyage key, `pid1`/`pid2` resolved
against `ports_all`.

---

## 23. Icelandic pleasure craft (SKB) have no entity_class or registry home
**status:** open — answered 2026-10-14, built by TODO 63 · **see:** `curate/decisions/041-fro-succession-and-skb-pleasure-craft.md`

`reference/vessels/registry.R:35` excludes `sknr` starting `SKB` from `vessel.parquet`
with no decision record explaining why — found to look mechanical (`SKB` codes are
alphanumeric, never fit the integer `vid` join) rather than a deliberate policy call.
Measured: 94 of 157 `SKB` mobile-ids in STK's unmatched residual resolve cleanly
against `raw/vessels/mmsi_iceland_archieves.parquet`'s own `sknr` field (192,554 of
256,292 pings) — including the single largest entry anywhere in the residual. A
resolution path now exists (`ais_key_foreign.R`'s `isl_pleasure_craft` stage, `source`/
`external_id` of their own, `vessel.parquet` untouched), but they still default to
`entity_class == "vessel"` in the main cascade and sit in the unmatched residual
looking like missed real vessels rather than a recognized class.

**Asked of the maintainer:** should `R/entity_class.R` recognize `SKB` as its own
class, and should `registry.R`'s exclusion be revisited now that it's shown to cost
real, resolvable AIS coverage? Since 2026-10-14 (vid is an integer, and a hull like an IMO number) this is
plan 016 §5 and §7 a. **Answered 2026-10-14: option B**, SKB as `vid` 100000 + n through the whole flow, with
`entity_class` pleasure craft at the next key redo (plan 016 §7).

**check:** `SKB`-prefixed mobile-ids carry a distinct `entity_class`, and
`registry.R:35`'s exclusion has a decision record (kept or changed) either way.

---

## 24. `landed_but_no_ais`'s top vessels have no MMSI on record at all
**status:** open · **see:** `curate/checks/ais_key_landings.R`

83 Icelandic vessels land fish (2007-09 to 2025-12) with zero STK identity. The
top 10 by landing-trip count (vid 980 STAFNES, 1035 HEIMAEY, 6723 BETA, 2362
HREFNA, 257 SIGURVON, 1263 ATLAVÍK, 1261 BERGKVIST, 6965 ARNAR, 2302 MÁNI, 978
SVANUR) carry **no `mmsi` in `vessel.parquet` at all** - not stale, absent -
so ASTD/astdB (both MMSI-keyed) can't be checked for them with a restricted
lookup the way plan 008's foreign candidates were. The only way to check is a
`vesselname`-matched scan across ASTD's ~2.77 billion rows, which is exactly
the full-table scan this repo has deliberately avoided everywhere else - so
it wasn't run; do it as a deliberate, budgeted pass, not incidentally.

**check:** each of the 83 has either an ASTD/astdB name-match result recorded,
or a note that none exists.

## 25. Resolve the STK key audit's discrepancies, and reach the rows no witness reaches
**status:** open · **needs: maintainer** — review of proposed overrides ·
**see:** `curate/plans/009-independent-audit-of-the-mid-vid-match.md`,
`curate/decisions/047-independent-audit-of-the-mid-vid-match.md`

Built 2026-09-29: `ais_key_audit` (ledger of every key row; 400 discrepancies on the 2026-10-07 build, none
reviewed, 132 when first built; 884 vid-claiming rows no witness reaches, not re-counted) and `ais_key_split_candidates` (silences where a
human-style reading says the vessel changed; 19 strong not in the ODS). Open: plan 009 —
phase 2 (segment table built with logbook and landings: tiles every mid, 90 % of pings with direct evidence, Icelandic ODS rows 87 % reproduced without the ODS; review open), phase 3 (review in the app),
phase 4 (reach the continuity segments, MMSI series, foreign vessels), phase 5 (the ODS is retired: `ais_key.R` switched to the segment table 2026-09-30, decision 053;
ODS retired the same day and everything rebuilt without it, decision 054; the archived file stays, by decision).
`ais_key_resolution` (built, first pass) reads each discrepancy as eras: 30 proposals on 25 mids;
track correlation confirms 12 of the 14 strong ones (decision 047), the other 2 need a person.
The `curated/check/` tables build the next time the `check_ais_key_*` targets run.

`ais_key_coverage` finds the pings the key leaves unassigned (31,512 in 344 stretches on the 2026-10-07 build,
39,487 when first built; the largest now 4,962 on mid 108582) and proposes a fill; the maintainer's invariant is no unassigned ping.

`ais_key_vessel_recall` accounts for every Icelandic vessel-month AIS or the logbook shows active: 0.3 % of
AIS-heard months have no mid assigned (decision 047).
`ais_key_twins` keeps the mobile-ids heard with two vessels (a candidate fishyweb case example).
Side observation, NOT validated and not pursued: on the uncleaned 2019 union, implied-speed jumps
(> 50 kn) are 0.09 % of consecutive pairs for stk, 0.04 % for astdB, 0.02 % for astd.

Mid 101444 = vid 1421 (call sign TFGA) is now assigned by dated-holder ranking; the registry's own dated
call-sign history only starts 2023-12-19 and cannot date a reuse in the STK era (decision 047).

The segment table now uses each hull's registration date (a vid cannot precede its vessel): 0 impossible segments,
108 stretches / 97,850 pings for a person. The review of decision 048 was made on the earlier table and is to be
redone on this one before any verdict is used.

**check:** `ais_key_coverage` reports 0 unassigned pings, and every row of `curated/check/ais_key_audit_discrepancy.parquet` is resolved
through `overrides/` or carries a stated reason, and the 884 are re-counted.

## 27b. Link pings to trips and fishing activity (the `trail`), and deliver from it
**status:** in progress - phases 0-3 built and rebuilt from raw (2026-09-30) · **see:** `curate/plans/015-datacall-on-the-curated-trail.md` (the datacall), `curate/plans/010-ping-activity-link.md` §7, §10-§12b, item 8

Built: `gear_window`, `station_window`, `curated/ais/trail` (AIS + the gps logger feed, plan 014), with the voyage's
trip (`.tid_voyage`) on fixes outside every window. Open: the datacall. `products/ices_vms_datacall/build.R` is the
2025 delivery script with only its paths changed, and it cannot run here (checked 2026-10-14). It reads columns the
current `ping_union` does not have (`.sid`, `s1`/`s2`, `t1`/`t2`, `met6`, `dt`, `dd`, habitat, depth, catch per fix),
a `station-for-ais.parquet` nothing here builds, and `agf_gid`/`met6` that `gear.parquet` lacks.
Repointing it means building its inputs from the curated tables:
- the trail's `fishing`;
- metier 6 from the mesh size;
- swept area from distance and gear width;
- habitat and depth by spatial join;
- catch spread over a station's fishing fixes;
- the logbook (LE) table without duplicate twins.

Plan 015 designs it, checked against the 2025 delivery (item 8); its §4 choices are the maintainer's. Also open: whether to store a sorted wide trail
(maintainer).

**check:** `products/ices_vms_datacall/build.R` runs on `curated/ais/trail`, its output is compared with the 2025
delivery, and every synthesised window carries `win_basis`.

## 34. Trawl speed ranges, the logbook-gear check and the last haul (plan 012)
**status:** open · **needs: maintainer** · **see:** `curate/plans/012-speed-range-vs-logbook-window.md` (§2e-§2k), `curate/corrections/logger_speed_placeholder.yml`

Measured: the declared speed range per trawl gear keeps 88-92 % of fixes in recorded tow windows; kW, length and age explain under 5 % of towing speed; a vessel's own range gains nothing over the gear's; shifting the gear range by last year's vessel offset gains 0.2-1 point overall and 4-12 points for the tenth of vessel-years with a large offset; the logbook gear agrees with the landings for 93-99 % of trips. Nothing is built from the plan itself. Asked of the maintainer: (1) whether fish-trawl tows of small vessels near the coast are permitted, so a flag can say "suspect" or "expected", and where a baseline or fjord polygon can come from (5 km from the coast is a stand-in); (2) whether to adopt the vessel-shifted range or keep the declared ranges (§2l: for the pairing it gains about a point of agreement, not shown to be accuracy; not taken up, the declared ranges stay and `fishing` tests the ±10 min speed instead, decision 093). Question (3), the gear codes on the trail, is answered and built (decision 085).

Open, not blocked: whether the last haul of a trip is left unclosed. Not seen at the window level (§2d) or in the logger's speed after `t3` (§2k); the logbook end looks late on some last tows, not early.

**check:** the answers to (1) and (2) are recorded in a decision, and either a speed rule is chosen or plan 012 is marked abandoned with the reason.

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

## 39. Mid 108982 changes hands on a registration date, not where the pings say
**status:** open · **needs: maintainer** — how a reviewed boundary enters the key ·
**see:** `curate/decisions/067-whacky-positions-are-labelled-by-whack-clean.md` (vid 7830), item 25

`ais_key_segments` gives mid 108982 to vid 7830 from 2018-04-13 (`boundary_basis`: 7830 registered that day). The pings
and 2835's own astdB say the mid was vid 2835's in the Westfjords until 2018-07-19 and 7830's off Reykjavik from
2020-07-10, so 5,029 of 2835's pings are on 7830. `ais_key_split_candidates` lists the gap but grades it weak. The
reviewed override cannot fix it: `overrides/ais_key_segments_reviewed.csv` replaces the vid of a segment it covers by
half its days or more, and moves no boundary. Asked: a boundary override, or a rule that a registration date does not
cut where the earlier holder's own AIS still witnesses the mid. How many other mids have this shape is not counted.

**check:** mid 108982 is 2835 through 2018-07-19 in `vessel_ais_key`, and the count of registration-date boundaries
that cut a witnessed run is recorded in a decision.

## 48. The voyage step took 51 min since the ramb port, against 9.4
**status:** open · **see:** decision 077 (3h), ramb f6faf9b

The cause was an unpartitioned `row_number() OVER ()`, which DuckDB runs on one core. Numbering per vessel took a
4.9 M-ping batch from 24.0 to 7.3 s with identical output (plan 014 3h). The plan 014 rebuild took 29 min (decision
079): faster, not yet fast. The 2026-10 rebuilds took 13.8 and 14.1 min with the same voyages (decisions 086, 089). Not profiled
further.

**check:** the step runs no slower than 10 min on the full data, with the same output.

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
Plan 016 adds `vessel/mmsi`, `vessel/vessel_year`, `vessel/vessel_class`, `vessel/vessel_sign`, the columns `status`,
`foreign`, `register` in `vessel.parquet` and `kw_basis`, `leisure`, `leisure_basis` on the trail (after its rebuild).

**check:** `data-dict validate-spec docs/data-dict.yaml` and `validate-meta` pass with zero errors, and the tables of
plan 016 are in the file.

## 62. Foreign vessels' logbooks for Icelandic waters
**status:** open · **needs: maintainer** — where they are: an Oracle schema and table, or an extract from Fiskistofa ·
**see:** plan 013 item 5, decisions 102-103, plan 017 §3 (`raw/logbooks/afli/steini.parquet` is a partial one: oceanic redfish, 1989-2017)

The maintainer said yes on 2026-10-14: acquire them. Foreign vessels land 80-124 a year in Iceland and hold most of
the landed weight with no Icelandic logbook trip (plan 013, rows 4 and 9; 1,144 of 1,320 kt of pelagic species in
2019-2025). They are not in what is dumped: the logbook tables hold 6 foreign trips in all, and none of the four
logbook schemas (afli, fs_afladagbok, adb, logbook) has a foreign table.

**check:** a `dump/` script writes them to `raw/logbooks/`, an adapter in `sources/` stages them, and `ais_catch.R` puts
foreign catch on the record path where a logbook exists.

## 63. Refresh the vessel registry and the MMSI archive
**status:** open — the eight asks in plan 016 §7 were answered on 2026-10-14; ready to build ·
**see:** `curate/plans/016-vessel-registry-and-mmsi-refresh.md`, TODO 17 and 23

New Oracle vessel tables were dumped on 2026-10-14 (the April set is in `$FISHYDATA/archive/raw-vessels_2026-04-25/`),
and the March 2026 Fjarskiptastofa list was merged into `raw/mmsi/mmsi_iceland_2026-03-25.parquet`, which nothing reads.
Adopting that merge as it stands would put four vids twice in `vessel.parquet`. The plan rebuilds the archive from
all its sources and makes `vid` an integer and unique again, after the `rjdbc` driver turned it into a double.

**check:** plan 016 §8.

## 65. A vessel registry for every ping, whatever the flag
**status:** open · **needs: maintainer** — the eight asks in plan 021 §6 ·
**see:** `curate/plans/021-vessel-registry-for-every-ping.md`, plans 008, 016 and 017, TODO 22

The maintainer asked on 2026-10-15 for a registry of every vessel the pings carry, not only the Icelandic ones. Plan 021
measures what each identity source reaches over every MMSI in ASTD and astdB, and proposes one integer `vid` per hull
and a crosswalk from each feed identity to it. It follows plan 016's rebuild and plan 018 phase 3.

**check:** plan 021 §7.

## 67. Divers' registrations in the landings
**status:** open · **see:** `curate/decisions/110-divers-registrations-in-the-landings.md`, TODO 24

Two `vid`s in the landings are divers, not vessels: 8009 (the register's útgerðarflokkur "Kafarar") and very likely
8008, both landing only with gear 23 "Kafari", about 14 t on 152 landing rows. They have no hull and no AIS track, so
a check of vessels that land but are never heard on AIS counts them as missed vessels unless they are told apart.
Mark them as divers, through an override that names the two, or a rule (a registration that lands only with gear 23),
and leave them out of `ais_key_landings`' `landed_but_no_ais`.

**check:** 8008 and 8009 carry a diver class in fishycode's landings or vessel classification, and
`landed_but_no_ais` leaves them out.


## 68. stk's tables besides the trail: what they hold, and which fishycode should read
**status:** open · **see:** plan 022, decision 109, `curate/ais_voyage.R`, `curate/port_stay.R`

fishycode reads only stk's trail. The server's dump of stk (2026-10-16) holds 63 objects, and the maintainer asks for
them to be checked: some are copies of the trail, some may be very useful. First **`tilk_stk_allt`**: recorded
voyages, 3,186,904 from 2003-09-08 to 2021-02-08, each a departure and an arrival (time, port, the trail ids at both
ends) and its duration; `tilk_stk` holds the 5.9 M port events behind them. They are voyages in fishycode's sense,
port to port: whether the vessel fished is not recorded (maintainer). Of value three ways (maintainer):
- before mid-2007, voyages where there is no track: 116,000-129,000 a year by 1,400-1,700 vessels in 2004-2006, when
  the trail has 190 to 9,820 positions a year;
- to 2021, recorded departures and arrivals to check, or correct, the voyages and stays cut from the track;
- a departure time (T1) for logbook trips and landings, which lack one, with its own basis.
The other `tilk_` tables (maintainer: they may hold more): `tilk_stk_allt_v` (1.95 M voyages, the same columns: which
selection?), `tilk_stk_por_v` (pairs departure and arrival; skipped: Oracle did not finish it in over 2 h, twice), and `tilk_vss`, calls of
departure (1) and arrival (2) to the traffic service in 2010-2011 (28,138, of them 9,824 moved to STK's events,
`flutt`), then in 2012-2013 almost only a code 0 that Oracle's comment does not explain (141,172).
Then `leidangrar_stk` (2,018,618 rows), `lodnuskip_stk` (1,102,509), `tilk_vss`, `posrep_current`,
`coral_stk_export`, and the mobile-id tables (`mobile`, `mobile_skip_v`, `mobile_tab`), to compare with fishycode's
STK key. Copies: `trail_all` is the trail as one table (the same
303.8 M positions, 5 fewer columns; checked 2026-10-16, no positions before 2007 beyond the trail's), and most
likely `stk_vms_v` (303,784,194 rows), the yearly `vms_stk_export_*` and the view `view_trail` (303,791,859).
`stk_vms_v`, `trail_all` and `view_trail` stay on the server (`SYNC_EXCLUDE`).

The first half of the check is met by plan 022's appendix (2026-10-16); the voyages comparison is plan 022 §4.

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
(and `vessel_mmsi`) on the server · **see:** plan 022 §3.1, `reference/vessels/mmsi.R`, decision 111, TODO 63

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
