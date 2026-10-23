# 015 — The ICES VMS datacall from the curated trail

**status:** proposal — nothing built; effort and catch per fix have been built since (decisions 101–102); §4 e-h
answered 2026-10-23 (decision 202), a-d and i held for a metier study; §4 a revised from that study the same day (a
rule proposed, asks a1-a5 open) · **2026-10-14** · **see:** TODO 27b (8 folded in, decision 118), plans 002, 010 (§7), 013
(`rb_assign_effort`, `rb_share_catch`), decision 095

Drafted with AI assistance (Claude) on 2026-10-14, at the maintainer's request, from read-only checks of the code
and the data. The choices in §4 are the maintainer's to make.

**Measured** (read-only, 2026-10-14): what `products/ices_vms_datacall/build.R` reads and that none of it exists
here (§1); which datacall fields the curated tables already hold, and with what coverage (§2); what survives of the
2025 delivery (§3).
**Assumed:** that the 2026 call keeps the 2025 format (two tables, `VE` and `LE`, with the fields below) and asks
for 2009 to the last full year. Also that the curated trail's `fishing` is the right selection of fishing fixes:
it is the logbook window plus the ±10 min speed (decision 093), as 2025's was the window plus the fix's speed.

## 1. Why the script cannot run, and what replaces its inputs

`build.R` is the 2025 delivery script (`fishydata_2024-2026/ices-datacall/2025/2025_vms-datacall.R`) with only its
paths changed. Plan 002 found the same on 2026-09-22.

| 2025 input | what it gave | here |
|---|---|---|
| `data/ais/trail` (old repo, 31 GB) | fishing fixes with metier, vessel, interval, distance, habitat, depth, catch | `staging/ais/ping_union` has none of those columns; `curated/ais/trail` replaces it |
| `data/logbooks/station-for-ais.parquet` | the logbook in datacall form, with gear width; records without both `t1` and `t2` went to the day, whatever their gear, and were consolidated per vessel, gear, date and landing record into one record with a whole-day window (maintainer, 2026-10-14; `fishydata_2024-2026/scripts/12_DATASET_logbooks.R:844-887`, `curate/corrections/station_time_whole_day.yml`) | nowhere on disk; the curated logbook tables replace it, without that consolidation (§2) |
| `data/gear/gear_mapping.parquet` | `agf_gid` → gear, target, `met6` | `curated/reference/gear.parquet` has no `met6`; nor does the legacy copy |
| `data/vessels/vessels_iceland.parquet` | `loa`, `kw_total` | `curated/vessel/vessel.parquet` (one row per vid) |

It also writes into the repo (`here("ices-datacall/2025/...")`), which `AGENTS.md` forbids. Deliveries go to
`$FISHYDATA/exports/`.

## 2. Each field, where 2025 took it, and where it comes from now

**`VE` (one row per year × month × c-square × metier × length class × habitat × depth):**

| field | 2025 | curated | coverage, status |
|---|---|---|---|
| the fishing fixes | `between(speed, s1, s2)` and `between(time, t1, t2)`, `whack == FALSE`, `.cid > 0` (at sea) | trail `fishing` TRUE (clean fixes only), `stay` NULL | built |
| Year, Month, Csquare (0.05°) | fix time, `vmstools::CSquare` | the same | built; `rb_encode_csquare` is planned in ramb (plan 013) |
| MetierL4, L5 | `gear_mapping` by `agf_gid` | trail `gear`, `target` (the landing's gear where it names one, plan 014 3j) | built |
| MetierL6 | `gear_mapping.met6` by `agf_gid`, plus a hard-coded OTB_CRU fix | no `met6` anywhere (the trail's `metier` is the house label gear + target2, `OTB_NEP`); the mesh is in the logbooks' raw gear tables | **§4 a**, revised |
| VesselLengthRange, AverageVesselLength | `vessels_iceland.loa` | `vessel.loa` | 95.7 % of vessels |
| AveragekW, kWFishingHour | `vessels_iceland.kw_total` | `vessel.kw_total` | **65.3 % of vessels** (§4 f) |
| Habitat, Depth | old trail `.msfd_bbht`, `.depth` | `staging/ais/ping_tagged` `bbht`, `depth` (from `area_h3`, H3 res 8), joined on (vid, time) | depth 100 %, habitat 61.9 % of cells |
| No_Records, FishingHour, AverageInterval | `dt` (s to the previous fix); rows with `dt` > 2 h or < 5 s dropped | trail `dt_sec` | built; the rule **§4 c** |
| AverageFishingSpeed | `speed` | trail `speed` | built |
| SweptArea, AverageGearWidth | `dd` (distance to the previous fix) × width from the logbook, missing widths set by gear (100, 45, 60, 2 m) and capped | distance from consecutive fixes; `fishing_sample.g_width` | width recorded for **17 % of OTB, 18 % of DRB** (§4 d) |
| TotWeight | the station's `catch_total` shared equally over its fixes | `catch_by_species_station.catch_round` (whole weight), shared by `ramb::rb_share_catch()` | built in ramb; the method **§4 e** |
| NoDistinctVessels, AnonymizedVesselID | `VE_ID` = row number of the vessel table, so not stable between deliveries | a fixed vid → ID key | **§4 g** |

**Untimed stations.** In 2025 a record went to the day when it lacked `t1` or `t2`, whatever its gear: the day
depended on the record (maintainer, 2026-10-14). Now `station_window` gives a day window when the times its gear's
rule needs are missing, so the day depends on the gear, and the two need not pick the same stations. 2025 then
consolidated the day records per vessel, gear, date and landing record (first station's position, effort and catch
summed, mean width), so a day had one whole-day window per gear and every fix in it had a gear. The curated logbook keeps each station, and a day
window per station (decision 091), so several day windows can claim one fix. The trail then fills neither `.sid`
nor gear: **2,005,833 fishing fixes, 2009-2025 (1.9 % of 106.2 M), carry no gear**, and the datacall would drop
them. The choice is **§4 i**.

**`LE` (one row per year × month × ICES rectangle × metier × length class × VMS-enabled):** built from
`station.parquet` without duplicate twins (decision 094) or deleted records, with the gear as above and catch from
`catch_by_species_station`.
- FishingDays is 1 / (stations of the vessel that day); kWFishingDays follows from it.
- The rectangle is the midpoint of the station's fishing fixes where the trail has them, else the logbook position,
  as in 2025.
- VMSEnabled is Y when the trail has fixes for the station.

## 3. What survives of the 2025 delivery, for the comparison

- **The old trail is restored** (decision 095), so the `VE` half of 2025 can be rebuilt from it. Its `met6`
  column also holds the only surviving copy of 2025's metier-6 lookup.
- **Not on disk:** `station-for-ais.parquet` and the delivered CSVs. 2025's `LE` table, and its swept area and gear
  width (which read the logbook), cannot be rebuilt here unless ICES returns the 2025 submission (§6).

## 4. Choices for the maintainer

- **a. Metier 6.** Revised 2026-10-23 below (§4 a revised), after a read-only study; the options of 2026-10-14 rested
  on a coverage of `g_mesh` that the study found wrong for OTB and OTM.
- **b. Years.** 2009 to the last full year, as 2025 did 2009-2024?
- **c. Effort per fix.** 2025 dropped intervals over 2 h or under 5 s. Keep that, or cap with `ramb::rb_cap_effort()`?
  Recommended: keep 2025's rule for the first comparison.
- **d. Gear width.** 2025's fixed values for missing widths, the recorded width where there is one, or ramb's
  `rb_predict_gear_width(method = "benthis")` from vessel size (on hold in plan 013)? Recommended: 2025's rule first;
  a better width is its own step.
- **e. Catch per fix.** Equal shares over the station's fishing fixes (2025), or by effort (`rb_share_catch(method =
  "effort")`)? Catch on stations without fixes stays in `LE` only.
- **f. kW.** Missing for a third of vessels. Leave kWFishingHour short, or fill from another register?
- **g. Vessel IDs.** A stable vid → `ISnnnn` key, kept in `reference/vessels` and never renumbered?
- **h. Where it runs.** By hand per delivery, writing to `$FISHYDATA/exports/ices_vms_datacall/<call year>/` with a
  manifest (commit, inputs, row counts), or as a target?
- **i. Untimed stations.** (i) Consolidate them per vessel × gear × date for the datacall, as 2025 did. (ii) Let
  the trail carry gear, target and metier when all the stations claiming a fix agree on them: one rule in
  `R/trail_sql.R` / `ramb::rb_assign_record()`, so the trail itself improves, but it is a trail rebuild. For `LE`,
  FishingDays sums to one per vessel-day either way. Only where the day's catch and position fall differs.
  Recommended: (ii) for the trail, (i) in `LE` for comparability with 2025.

**Answered 2026-10-23** (the maintainer, decision 202): e and f, the curated catch and the trail's kW with its basis, 2025's
equal shares beside them for the comparison; g, a stable vid → `ISnnnn` key, never renumbered; h, by hand per delivery
into `$FISHYDATA/exports/ices_vms_datacall/<call year>/` with a manifest. **Held:** a, the metier 6 (2025's lookup was
typed by hand, the mesh is unreliable, and MFRI's RDBES uploads assign metiers too: a read-only study first), and with
it b, c, d and i.

### §4 a revised (2026-10-23): metier 6

*A read-only study by Claude (Anthropic), not yet checked by a person, on the maintainer's words of 2026-10-23
(2025's lookup "was sort of made upon the fly"; "the mesh reporting in the logbooks is notorious") and the point that
the metier may be the regulation's rather than each haul's declaration. Scripts, the row-by-row account of 2025's
lookup and every number: `$FISHYDATA/archive/2026-10-metier6/README.md`.*

**Measured** (2009-2025 unless said; fishing fixes are the trail's `fishing`, 105.6 M, with the ICES area of
`ping_tagged.fao`):
- **2025's lookup** (`00_DATASET_gear.R`, four commits from 2025-07-15 to the day of delivery) is keyed on the
  landing's gear and assumes one mesh class per gear: the unbounded `>0` for nets, pelagic trawl, purse seine, dredge
  and traps, `>=120` for bottom trawl and seine, `90-99_1_120` for Nephrops, `40-54` for shrimp. On the old trail
  94.2 % of 2025's VE fishing fixes carry a code allowed in their area by rdbes's list; 5.66 % do not: the shrimp code
  in 27.5.a.2 (4.25 M; the class allowed there is 32-69), `DRB_DES` (0.68 M; `DRB_MOL` and `DRB_CRU` are allowed) and
  `HMS_SWD`. The list moves: rdbes's copy of 2024-10-23 has other ranges and none of 2025's bounded codes for 27.5.a.2.
- **MFRI's RDBES upload** is a 2024 pelagic pilot: 61 fishing operations carry a metier 6, the commercial tables
  none. Its views call `metier6(area, gear, target, mesh)` with the mesh from adb's logbook table and the target set to
  SPF; the function is hidden from the dump account, and on all 61 it acts as the narrowest allowed range holding the
  mesh in the operation's area. Each row in one outcome: the 61 agree with 2025 at level 5 and disagree at level 6
  (2025's is the unbounded code); the commercial tables (1,435 rows) and the trip and match tables (562) are not
  comparable.
- **The logbooks' mesh** is recorded on 92-100 % of trawl, seine and cod-net stations in afli and fs_afladagbok
  (lumpfish and monkfish nets 67-75 %; none from the STOKKUR, TRACKWELL and FRA TAKTIKAL apps), and heaps at the
  regulation's values: bottom trawl 100/135/155 mm on 75-94 %, seine 87-95 %, Nephrops 80 (82 %) and 100 (11-15 %),
  shrimp 36-42, nets on half-inch steps. The 14-17 % of 2026-10-14 for OTB and OTM was `g_mesh`, which the afli adapter
  leaves empty although afli's `toga` holds the codend mesh on 99-100 % of bottom-trawl stations. Impossible for the
  gear: 2-3 % of bottom trawl (10-80 mm), 34 % of fs shrimp trawls (135 mm), 4-19 % of nets (10 and 20 mm
  placeholders). The class changes within a trip on ≤ 1.7 % of trawl trips, 7-13 % of cod-net trips. Where the
  logbook's and the landing's gear differ, the mesh mostly sides with one (trawl logged, shrimp landed, fs: 38 mm).
- **So** where a gear's regulation fixes the class (bottom trawl, seine, Nephrops, shrimp), every legal mesh lies in
  one class and the recorded mesh only confirms it; it decides only where the regulation leaves the class open: nets
  (120-219 or ≥ 220 mm; 31.5 % of cod-net fixes ≥ 220), pelagic trawl, purse seine, and Nephrops if 100 mm counts.

**Proposed rule**, per fishing operation, with `met6_basis`, the first that answers:
1. `rdbes`, RDBES's own code for the operation;
2. gear and target from `gid_used` (the landing's gear where it names one, decisions 085 and 154), dredge as
   `DRB_MOL` and other gear as `MIS_MIS`, the codes allowed in 27.5.a;
3. the mesh: `regulation` where the regulation fixes the class (the legal mesh: bottom trawl 135, Nephrops 80, shrimp
   36, seine 135 mm); `recorded` where it does not and the mesh lies in the gear's trusted range; else `vessel usual`
   (its median trusted mesh for the gear that year), `fleet usual`, `unbounded` (`>0`); `gear has no mesh` for lines
   and jigs (`0_0_0`); none where no code is allowed (diving, seaweed);
4. the code, the narrowest allowed range holding the mesh in the fix's ICES area, with selection device `0_0`.

Applied (`unit_metier.parquet`): of the fishing fixes, regulation 47.0 %, gear without mesh 42.8 %, recorded 8.3 %,
unbounded 0.85 %, vessel usual 0.58 %, fleet usual 0.40 %, RDBES 2,206 fixes, no code allowed 21 k (seaweed), no gear
38 k; every fix with a gear gets a code allowed in its area. Against 2025 (2009-2024): agree 81.8 %, another mesh
class 17.4 %, another target 0.8 %. It gives RDBES's code on all 61 operations. By year and gear:
`rule_basis_by_year.csv`, `rule_basis_by_gear.csv`.

**Assumed:** the regulation's values (543/2002 as a model read island.is; 964/2019 for shrimp and 188/2020 for
Nephrops not read; the seine's 135 mm from the records); `metier6()` from 61 pelagic operations; stations with no
fishing fix in 27.5.a.2; the target from the gear code alone.

**Asks a1-a5** (the maintainer's):
- **a1.** Regulation first or recorded first for the regulated gears? Only Nephrops moves: recorded first puts 18.6 %
  of its fixes at 100 mm or more (bottom trawl 0.17 %, seine 0.09 %).
- **a2.** Targets the gear code cannot give: dredges (`DRB_MOL`, though sea cucumber is no mollusc), pelagic trawls of
  100 mm or more (`OTM_DEF`, oceanic redfish, 1.4-3.5 % of pelagic fixes), traps by their catch.
- **a3.** Selection devices: afli records a 22 mm grid on 75 % of shrimp stations and fs a bycatch grid on 98 %, and
  `OTB_CRU_32-69_2_22` is allowed in 27.5.a; the Nephrops panels have no allowed code there. `0_0` for the first
  delivery?
- **a4.** Which allowed list: rdbes's (analysed in Oracle on 2025-10-23) or the call's own.
- **a5.** A dated regulation table in `reference/gear` (gear, target, legal mesh, from, to, the regulation), and
  afli's codend mesh carried into `g_mesh` (or `gear_part`, plan 020).

## 5. Steps

1. **Rebuild 2025's `VE` from the old trail** with the 2025 rules, leaving swept area and width out (their logbook
   input is gone). Keep it as the baseline in `$FISHYDATA/archive/2025-ices-datacall/`.
2. **The fishing-fix table**: the trail's fishing fixes with distance to the previous fix, habitat, depth, metier 6,
   vessel and gear width. One DuckDB pass per year.
3. **`VE` and `LE`** in the 2025 format, with the ICES vocabulary checks of 2025 (`icesVocab`). AnonymizedVesselID is
   filled where a cell has fewer than three vessels; that is the call's own rule, and no other suppression applies.
4. **Compare with 2025** by year × MetierL4:
   - fishing hours, kW hours, catch and records;
   - the share of 2025's fishing hours in c-squares the new table also has.

   Expected differences are listed before the run, so each can be traced:
   - twins out (decision 094);
   - the ±10 min speed (+3.8 % fishing fixes, decision 093);
   - afli tow starts before 01:00 (087);
   - the landing's gear (plan 014 3j);
   - the STK key from the segment table (plan 009);
   - whacky positions labelled (067);
   - which stations go to the day (by record in 2025, by gear now), and their consolidation (§4 i).
5. **Record a decision**, write the delivery to `exports/`, and close TODO 27b. TODO 8 closes when the new delivery
   supersedes 2025's.

## 6. Open

- The 2026 call's own document: format and years. The maintainer has it, or it is fetched when published.
- Whether ICES can return Iceland's 2025 submission. That would allow comparing `LE`, swept area and width too.
- The ICES areas: 2025 filtered only to latitudes 30-90; whether the call wants an area filter.
- Porting to ramb (`rb_assign_effort`, `rb_encode_csquare`, the `"ices_datacall"` preset of plan 013) comes after
  the fishycode version has matched 2025.

## 7. Not proposed

- New effort definitions, behavioural windows (TODO 18 is parked) and a sorted wide trail. The first delivery should
  differ from 2025 only by the curated data, so the comparison can be read.
