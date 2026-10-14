# 015 — The ICES VMS datacall from the curated trail

**status:** proposal — nothing built · **2026-10-14** · **see:** TODO 27b and 8, plans 002, 010 (§7), 013
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
| MetierL6 | `gear_mapping.met6` by `agf_gid`, plus a hard-coded OTB_CRU fix | no `met6` anywhere; mesh size is in `fishing_sample.g_mesh` | **§4 a** |
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

- **a. Metier 6.** (i) Read 2025's gid → `met6` lookup off the old trail and keep it as a column of
  `reference/gear` (comparable with 2025). (ii) Derive the mesh class from `g_mesh`: recorded for 96-100 % of SDN,
  GNS and DRB but 14-17 % of OTB and OTM. (iii) (i) with (ii) where the mesh is recorded. Recommended: (iii),
  reporting how often each source decides.
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
