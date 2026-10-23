# 042 — Pumped catch back on the vessel that caught it: a link from the logbooks' notes

**status:** proposal — measured 2026-10-23 (read-only, `$FISHYDATA/archive/2026-10-transhipment/`); nothing built;
seven asks open (TODO 135) · **2026-10-23** · **see:** plan 020 §6 and
`$FISHYDATA/archive/2026-10-logbook-notes/README.md` (§3.2, ask a), decisions 103, 104, 199 and 210, TODO 73 and 101,
plan 038 §7, `curate/catch_by_species_station.R`, `curate/ais_catch.R`, `curate/checks/allocation_audit.R`

Drafted with AI assistance (Claude) on 2026-10-23, in a session started by another Claude session to design and then
build the link. The rule in §1 is the maintainer's. The measurements and the design are Claude's, and a person has not
yet checked them. The scripts (`m1`-`m7`, run in order) and their logs are in
`$FISHYDATA/archive/2026-10-transhipment/`. They read the store as built at f7c82eb (decision 205) and the notes
study's `results/transfer.parquet`. Notes are free text and may name people, so only counts are written here.

**Measured:** every number in §2. **Assumed:**
- that the notes study's partner vids are right where its routes agree (91 % of the rows two routes name; no person
  has checked a sample);
- that a carrier's "dælt frá" station holds what it took aboard and little of its own catch (§2.4: the notes' stated
  amounts cannot settle it per station);
- that where both purse seiners log (1986-2010, §2.6), they wrote the same catch twice rather than each its own part.

## 1. The rule

The maintainer, 2026-10-23: "in the logbooks keep the catch records on the original vessel; for landings use the vid
of the transfer vessel". Catch pumped from the vessel that caught it (the **catcher**) into another (the **carrier**,
decision 199's word) belongs on the catcher's station and fixes. The landing stays the carrier's, under its vid.

## 2. What the logbooks show

### 2.1 Where the notes sit

Transfer notes on stations the merge keeps (`station_fate`): fs_afladagbok 2,954 (2022-2025), afli 1,057 (2016-2022),
afli's purse-seine notes (`hringn`) 1,499 (1986-2010) and adb 249 (2025-11-19 on). fs_afladagbok's 805 of 2021-2022
are on stations the merge drops because afli holds the vessel-day. afli's station there carries a transfer note too,
in all 805. The sent layer's 432 notes (2008-2022) are not staged (ask g).

Note × named partner on kept stations: fs_afladagbok 1,465 "frá" (from) and 1,837 "í" (to); afli 489 and 595; adb
118 and 133; purse seine 527 and 305. 773 of fs_afladagbok's 1,465 "frá" rows are in notes naming several vessels.

### 2.2 The carrier logs the catch, on a tow of its own

- **The "frá" station is a tow, not a receipt.** On fs_afladagbok it has `t2` and `t3` (1,028 of 1,045 stations), a
  median 8.7 h apart in the pairs with the catcher's station. It overlaps the catcher's tow in 1,046 of those 1,410
  pairs and starts a median 15 min after it, never at the same times. afli: 289 of 420, adb 70 of 112.
- **The catcher's station is found** by its own note naming the carrier, within a day, for 1,387 of fs_afladagbok's
  1,465 rows; by time (its pelagic tow overlapping the carrier's, else the last before it) for 41; not at all for 37.
  afli: 415, 37 and 37; adb 112 and 6 not found.
- **The catcher logs none of it.** It logs no pelagic catch on 1,271 of the 1,387 (92 %), less than the carrier on
  105, as much or more on 11. afli: none on 236 of 415, less on 166, as much or more on 11.
- **The carriers' trips land what they logged with these stations.** Landed over logged, pelagic species 30-36:
  median 1.03 on 387 fs_afladagbok trips (10-90 %: 0.95-1.20), 1.03 on 231 afli and 1.06 on 55 adb trips. Without the
  "frá" stations: 3.97, 2.22 and 2.46. The "frá" stations hold 77 %, 55 % and 62 % of these trips' pelagic catch.
- **Half name several catchers.** One carrier station names several catchers on 714 of fs_afladagbok's 1,387 rows.
- **Both stations have a window** (`station_window`) for 1,963 of the 1,966 rows that would move from 2020 on; 1,930
  of the catchers' windows are timed.

### 2.3 How much would move

Pelagic and other catch on the carriers' "frá" stations, kt, by the rule of §3.4. "Stated" moves the notes'
kilograms instead (ask a), summed over every note of a catcher naming the carrier in the day before:

| year | carrier stations | kt on them | moved, whole station | moved, stated kg | catcher's station not found | logged by both |
|---|---:|---:|---:|---:|---:|---:|
| 2008-2017 | 105 | 31.7 | 19.7 | — | 9.0 | 3.0 |
| 2020 | 44 | 17.7 | 17.2 | 12.1 | 0.3 | 0.1 |
| 2021 | 223 | 56.1 | 51.6 | 38.3 | 3.9 | 0.6 |
| 2022 | 244 | 70.2 | 66.9 | 50.3 | 3.2 | 0.2 |
| 2023 | 296 | 95.9 | 92.8 | 71.9 | 2.7 | 0.3 |
| 2024 | 258 | 72.2 | 71.1 | 56.0 | 1.1 | 0 |
| 2025 | 351 | 90.2 | 88.8 | 68.2 | 1.4 | 0 |
| 2026, to the dump | 99 | 24.4 | 22.5 | 16.2 | 1.9 | 0 |

2008-2015 is the sent layer's notes (ask g); 2016-2017 afli's own. The vessels are few: 17-22 carriers and 17-28
catchers a year from 2021.

### 2.4 The stated amounts settle nothing per station

The carrier station's catch over the catchers' stated kilograms: a median 1.11, but 0.34-2.45 for 10-90 % of the
1,486 e-logbook stations, and within 25 % on 333. Over the carrier's own note's amounts it is a median 1.83 (one
catcher) and 1.35 (several). The notes study reads amounts by rules near the species word (its rough edges), and a
catcher pumps into a carrier more than once before the carrier logs.

### 2.5 The catcher's note only

fs_afladagbok has 348 rows where the catcher names the carrier and the carrier writes nothing within a day (afli 146,
adb 13). The carrier logs pelagic catch on a station that day in 254 of them, but within 20 % of the stated amount on
4: it did not log the catch it received. Where its trip lands at least twice what it logged, it is one of decision
199's carriers. A note names the catcher for 14-28 % of those trip-species a year in 2021-2025: 1.4-7.5 of the 61-104
kt excess (the notes study, `08_check_transfers.log`).

### 2.6 The purse seiners log on both sides

afli's purse-seine notes, 1986-2010: where the catcher's station is found (by date; no times), it logs more pelagic
catch than the carrier's on 198 of 415, about as much on 32, less on 76 and none on 84. The whole-station rule would
move 0.9-7.9 kt a year in 1992-2004.

## 3. The design (proposal)

### 3.1 The notes into staging (preprocessing)

One script per adapter, beside its `convert.R` and reading only its own source:
- `sources/fs_afladagbok/note.R` (`ws_veidi.athugasemd_txt`);
- `sources/afli/note.R` (`stofn.aths_texti`, `hringn.athskipst`, `rafr_hringn.athskipst`);
- `sources/adb/note.R` (`fishing_station.note`).

Each writes `staging/<source>/station_note.parquet`: `.sid`, `schema`, `note_source` and the note as entered (decision
210). Each is a target of its own (`fs_afladagbok_note`, `afli_note`, `adb_note`), so the logbook chain is not rebuilt.
The columns' overlays (`dump/oracle/meta/`) and the staging dictionary are written with them (plan 040 phase 2). The
free text stays in staging and is never printed.

### 3.2 The rules into the repo

The archive's `rules.R` and `07_transfers.R` become functions in `R/` (definitions only):
- `R/note_rules.R`: `fold_note()`, `note_rules()` (the 73 tags as a table) and `tag_note()`;
- `R/note_vessel.R`: the vessel mentions in a note and their routes (register number, call sign, district number,
  name), the amounts and the direction. The register is passed in as arguments.

`tests/test_note_rules.R` tests them on invented notes, never real ones.

### 3.3 The link: `curate/link_transhipment.R` → `curated/logbook/transhipment.parquet` (preprocessing)

It reads the staged notes, the curated logbook and `curated/vessel/{vessel_sign,vessel,vessel_identity_all}`, and no
AIS. It writes one row per pumping a note names, with no free text:

| column | holds |
|---|---|
| `vid_catcher`, `.tid_catcher`, `.sid_catcher`, `schema_catcher` | the catcher and its station (NA when not found) |
| `vid_carrier`, `.tid_carrier`, `.sid_carrier`, `schema_carrier` | the carrier and its station (NA when only the catcher's note names it) |
| `date` | the station's date |
| `witness` | whose note names the other: `both`, `carrier` or `catcher` |
| `catcher_found` | `note` (its own note names the carrier), `time` or `none` |
| `kg_stated`, `kg_basis` | the notes' kilograms of pelagic or unnamed species, the catcher's first |
| `share` | the catcher's share of the carrier station's catch |
| `partner_basis`, `partner_agree` | the route that gave the vid, and whether the routes agree |
| `outcome` | `moved`, `logged_by_both`, `catcher_not_found`, `carrier_did_not_log` or `not_moved_period` (ask c) |
| `basis` | `derived` |

- **The catcher's station:** its station whose note names the carrier, within a day. Else its pelagic station
  overlapping the carrier's tow, else the last to end before it, that day or the day before. Never a duplicate twin
  or a station deleted in the source.
- **The share:** by the stated kilograms where every catcher of the station has some, else equal (ask b).
- **`logged_by_both`:** the catcher's station already holds at least 90 % of its share. Nothing moves, and both
  stations are kept (at most 1.0 kt a year, §2.3). This is Claude's choice, for review.
- **Checks in the script,** which stops otherwise: every transfer note × partner on a kept station in one outcome;
  the shares of a carrier station sum to 1; the partner vids set against the archive's `transfer.parquet`, with the
  agreement reported.

### 3.4 The move: one function, two readers

`R/move_pumped_catch.R` holds `move_pumped_catch(catch, transhipment)`, in dbplyr verbs as `calc_whole_weight()`
is. For each `moved` row, every species row of the carrier's station leaves it × `share` and joins the catcher's
station, with the carrier's trip kept as the trip that landed it. The amount is the station's whole catch (ask a). It
is read by:
- `catch_by_species_station.R`, "the catch as caught": a column `catch_moved` (signed whole weight, out on the
  carrier's station and in on the catcher's), and a row for each species a catcher's station logged none of. The catch
  as caught is `catch_round + catch_moved`;
- `ais_catch.R`: the logbook's catch netted per station and species before the units. A move whose catcher station has
  no window in the year stays on the carrier, and is counted.

These stay as recorded, the logbook's statement against its landing: `catch.parquet`, `lid_map`,
`catch_by_species_trip`, `landed_logged`, `logbook_gear` and `voyage_gear`. So the carrier's trip still matches its
landing, and decision 199's carrier test is made on the records as logged.

### 3.5 The landings keep the carrier's vid; the raising follows the landing

Nothing in `curated/landing/` changes. In `ais_catch`, `raise_factor` stays the trip's landed over logged weight as
recorded. The moved catch takes its carrier trip's factor (ask d): the carrier's weighed landing raises the catch it
carried, wherever that catch was caught. A unit that holds both its own and moved catch of a species gets the factor
weighted by kilograms. Decision 199's carriers are flagged and not raised, as chosen.

### 3.6 Kg in = kg out across both vessels

- **The link:** a carrier station's moved kg are at most its catch, per species, and its shares sum to 1.
- **`catch_by_species_station`:** per year, Σ (`catch_round` + `catch_moved`) = Σ `catch_round`.
- **`ais_catch`:** its check per year and approach is unchanged, since a move stays inside the logbook.
- **The audit**, a link `transhipment`: every note × partner in one outcome (records and kg), and the kg out of the
  carriers equal to the kg into the catchers, per year.

### 3.7 Decision 199's outcome names the catcher

The audit's carrier outcome (TODO 101, not built) takes each carrier trip-species (pelagic, landed at least twice what
it logged) with its excess landed kg, in one of three outcomes:
- catcher named, and its station logs catch of the species, so the catch is on the catcher's fixes;
- catcher named, but no logbook holds the catch;
- no catcher named.

The catcher is named by a link row of either witness whose carrier is the trip's vessel, dated from `T1` - 2 days to
`T2` (the notes study's rule in `08`). The named kilograms stay in the outcome (ask e).

## 4. Steps

1. §3 and the asks agreed (this plan).
2. The notes staged (§3.1) and the rules in `R/` with their tests (§3.2), on a scratch store.
3. The link (§3.3) on a scratch store. Its outcomes counted against §2, its partner vids against the archive.
4. The move (§3.4-3.6) on a scratch store: `catch_by_species_station`, then `ais_catch` for 2020-2025
   (`SCATCH_YEARS`), the kilograms traced per vessel and year, then the audit.
5. `docs/data-dict.yaml` entries (`station_note`, `logbook_transhipment`, `catch_moved`), a section in the book, and a
   decision record.
6. The build, by name, on the maintainer's go: the three note targets, `transhipment`, `catch_by_species_station`,
   `ais_catch` (about 20 min) and `check_allocation_audit`. The logbook chain and the trail are not touched.

## 5. Asks

a. **The amount:** the carrier station's whole catch (recommended: its trips land what they logged with it, §2.2), or
   the notes' stated kilograms capped at it, with the rest left on the carrier (§2.3's "stated": 21-26 % less a year in
   2021-2025).
b. **Several catchers on one station:** shares by the stated kilograms where all have some, else equal (recommended).
c. **The purse seiners of 1986-2010** (§2.6): linked and not moved (recommended), or moved by the same rule where the
   catcher logs less.
d. **Raising the moved catch:** by its carrier trip's factor (recommended), or not at all, extending decision 199's
   rule to every trip in the link.
e. **Decision 199's named excess that no logbook holds:** named in the outcome only (recommended), or put on the
   catcher's station named in its note, as landing catch.
f. **The name:** `transhipment`, with `catcher` and `carrier` (recommended). It is the maintainer's word in decisions
   103 and 104, and the grammar keeps "transfer" out (a quota transfer).
g. **The sent layer's notes** (2008-2015; 0.5-4.4 kt a year would move): staged with plan 037 phase 2 (recommended), or
   by a note script now.
