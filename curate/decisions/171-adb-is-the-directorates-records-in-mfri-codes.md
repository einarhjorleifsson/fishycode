# 171 — adb is the Directorate's logbook records, copied field for field into MFRI's codes; fs_afladagbok is the better copy where they part

*2026-10-22. Found, not a change of rule: decision 160's rule (adb only from 2025-11-19) stands, and nothing is
rebuilt. The maintainer's hypothesis, checked at his request ("care to check this hypothesis again"). Written by
Claude (AI); every number is Claude's, measured on the dumps of 2026-10-16, and has not been checked by a person.
Scripts, logs and tables: `$FISHYDATA/archive/2026-10-adb-lineage/` (README). The persons' columns were compared by
counts only. Corrected the same day by decision 172: adb's departure port where fs has none is a placeholder (0),
not information, so fs is the better copy throughout.*

## The hypothesis

The maintainer (2026-10-22): adb is made by Java code, whose location he does not know, that reads the Directorate of
Fisheries' (Fiskistofa's) system. The schema it reads is similar or identical to fs_afladagbok's. fs_afladagbok is a
dead dump, but likely much better than the conversion adb is built on.

## Found

1. **adb is read from Fiskistofa.** This is consistent with everything in the dump. Oracle's comments say so
   (`batch_day`: "The query day from Fiskistofa"; `catch.source_id`: "Id of the source record from Directorate of
   Fisheries"). adb's trip and station numbers are Fiskistofa's. Its mapping tables `fishing_gear`, `port` and
   `species` translate "FS" numbers into MFRI's GEAR, CHANNEL and BIOTA numbers. Where the Java lives the dumps cannot
   say.
2. **What it reads has fs_afladagbok's shape.** adb's `fishing_trip`, `fishing_station`, `catch` and its five gear
   tables are fs's `ws_veidiferd`, `ws_veidi`, `ws_afli`, `ws_dragnot_varpa`, `ws_plogur`, `ws_linanethandf`,
   `ws_gildra` and `ws_hringn`, column for column. Oracle's comments are translated (the wrong "(ddmm)" too), and the
   units and ids are the same. adb also reads two more of the Directorate's record sets, and both are in dumps we hold.
   Every adb station before 2025-11-19 but 243 of 600,315 has its counterpart:

   | counterpart | stations |
   |---|---:|
   | fs `ws_veidi` (same id and trip) | 465,341 |
   | afli `stofn` (same id, vessel and day): `TRACKWELL BAEKUR` 112,729, `PAPPÍR` 21,574 | 134,303 |
   | fs `fishing_spot` (same id, tour and start): `APP TÖFLUR` | 428 |

   All 9,374 `APP TÖFLUR` trips are `tour` ids of the same vessel. They are 9,374 of the 9,821 tour-app trips that
   plan 019 found never imported into `ws_*`.
3. **fs_afladagbok is dead.** Its last registration is 2025-12-12, while adb's loads run to 2026-10-15. From
   2025-11-19, 88,470 adb stations have no counterpart and 2,226 do.
4. **On the values both hold, adb's tables are an exact copy.** On 467,567 shared stations, the times, the four
   position integers, depths (fathoms), notes, lost gear, the modified flag and the registration time are equal or
   NULL on both sides on every row. The gear tables hold the same rows, with values equal in the same units. Catch per
   station, species (through adb's map) and condition: 1,399,070 groups are equal in rows, quantity and weight,
   5,362,572 t on each side. The trips' dates, vessel (all but 7 of 206,481) and landing port agree.
5. **Where they part, fs is better.** adb's conversion:
   - writes bottom trawl (6) for shrimp trawl (FS 8, 4,352 stations, 2019-2024) and Nephrops trawl (FS 7, 848,
     2021-2024), against its own map (8 → 14, 7 → 9), and 99 for two FS codes its map lacks (431);
   - drops the dredge's weight (4,578) and the trap's type (65), and writes crab trap (51) on 24 traps fs gives no type;
   - writes 0 where fs is NULL: square window on 217,467 trawl stations, mesh on 102,738 line and net stations;
   - lacks 31,954 t of catch (11,671 `ws_afli` rows) on 4,144 stations of 2019-2021 from its 2021 loads, 3,727 of
     them with no catch at all, though fs registered every row before adb's `batch_day`;
   - and, in its views, misreads positions, gives depth x 1.8288 and feet x 0.3042 (decisions 165, 170).

   fs holds 2,246 stations adb does not (0.3-0.6 % a year). *This record first said adb had one field fs lacks, the
   departure port, on 94,467 trips of sources fs gives none for (`STOKKUR`, `TRACKWELL`, `FRA GAFLI`, `Marína raun`,
   `FRA TAKTIKAL`, `Fishtech raun`). Wrong, decision 172:* it is 0 on every one of them, a placeholder that adb's port
   map reads as "Skarðsstöð".
6. **Edits.** The 2,304 shared stations with an earlier version in fs were all changed before adb's load, and adb
   holds the current version of each. Whether adb picks up later edits cannot be told from these dumps.

## What it corrects

Decision 160's amendment said adb holds 56,623 trips "from sources fs_afladagbok's dump has none of" (`TRACKWELL
BAEKUR`, `PAPPÍR`, `APP TÖFLUR`). It also said 335 of the 340 trips decision 160 removed came by "the Directorate's
delivery to adb, which no dump shows". In fact `APP TÖFLUR` is in fs_afladagbok's dump, in the tour app's tables, and
the other two sources are afli's `stofn` records. That covers the 321 app trips; the 14 `TRACKWELL BAEKUR` and `PAPPÍR`
trips were not checked one by one. The amendment is corrected in place, as are `docs/source-schemas.md`, the footnote
of `docs/grammar_logbooks.qmd`, `docs/merge.qmd` and `AGENTS.md`, which had called adb derived from fs_afladagbok.

## What it changes downstream

Nothing at present. `curate/logbook.R` reads adb only from 2025-11-19 (decision 160), where fs_afladagbok has 2,226 of
adb's 90,696 stations. The gear-code collapse ends in 2024 and the missing catch is from 2019-2021. The zeros and the
dropped fields are in columns `sources/adb/convert.R` does not read. The rule's reason now rests on this record:
fs_afladagbok is the same records without adb's conversion.

## Left open

- The tour app's 447 trips adb does not hold, and plan 019's proposal to read the tour app (TODO 73).
- Whether the 243 adb stations before 2025-11-19 with no counterpart, and the 14 `TRACKWELL BAEKUR` and `PAPPÍR`
  trips decision 160 removed, are in afli's adapter's output.
