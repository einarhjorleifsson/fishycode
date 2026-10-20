# 154 — A gear for every haul: adb's own gear codes, trips with no catch, the match by time, and landings after the voyage

*2026-10-20. Executes plan 034 (asks answered the same day, §7). Supersedes the gear half of decision 066. The code is
in; the rebuild from `lid_map` to `ais_catch` waits for the maintainer, who held it that afternoon.*

- **Who chose.** The maintainer: the rules of plan 034 §2 (where a trip is matched, its hauls' gear is the landing's;
  adb has gears in the old code system; no fallback to the previous trip's gear; match by time, not by instant) and
  the six answers of §7, each the option Claude recommended. Claude chose the rest, not yet reviewed: reading adb's
  code through adb's own table (found while preparing ask a), trips with catch first in the date steps (below),
  the tie rule of `09 order`, and where each piece lives.
- **Who did the work.** Claude (Anthropic), in one session: the code, the trial runs and this record. The numbers
  were measured by Claude; a person has not yet checked them.

## What this supersedes

Decision 066 gave adb stations a gear only from their landing, since adb's code "does not resolve" against
`reference/gear.parquet`. It does. adb's code is the old code, the GEAR schema's `fishing_gear_no`, and adb's own
table `fishing_gear` (`raw/oracle/adb/fishing_gear.parquet`) maps it to the FS number, the new `gid`. 53 ("Dregin
plógur") is 15, DRB_DES, and 51 ("Krabbagildra") is 16, FPO_DEF. On the 11 codes it shares with the reference's old
code the two agree. Only code 99 ("Óskráð veiðarfæri", gear not recorded, one station) has no row. Decision 066's catch
half stands.

## Done (code, uncommitted at the time of writing)

- **`curate/corrections/logbook_gear.R`.** adb's `gid_old` is read through adb's table as the logbook's own gear,
  `gid_basis` "recorded", with the reference's labels. The landing's gear still wins where it names one.
  `fishing_sample.parquet` is untouched (`gid` empty, the code in `gid_old`). A file target, `adb_gear_code`, tracks
  the table, so neither the adapter nor the merged logbook is rebuilt.
- **`curate/link_lid_map.R`.** Trips with catch go through steps 1-8 as before. Trips with no logbook catch then go
  through steps 1-5, on the landings those left, under the same labels and uniqueness rule. Then comes **`09 order`**:
  between two matched pairs of a vessel (anchors, at their landing's date), the trips and the landings with weight
  left unmatched are paired in order. They pair only where their numbers agree and the order is defined (no two
  landings on one date, no two trips with one `T2`), and only within 14 days.
- **`curate/voyage_gear.R`.** A landing dated on a day the vessel was at sea all day no longer counts for that
  voyage. A voyage with no landing in its window takes the landings within 7 days of its end whose last voyage ended
  by the end of their day is this one, even when the vessel has left again. Its basis is `landing`, and
  `landing_gap_d` gives the days.
- **The text that no longer held:** the comment in `sources/adb/convert.R`, decision 066's row and title line,
  `curate/corrections/logbook_gear.yml`, defect 3 of `adb_vs_fs_afladagbok.yml`, `docs/landings-match.qmd` (step 9,
  trips with no catch) and `docs/ais_trail.qmd` (adb's gear).

## Measured in a trial (2026-10-20, read-only)

The three scripts ran against a scratch `$FISHYDATA` of symlinks to the builds of 2026-10-17 to 2026-10-19, each
reading the one before it. `station_window` ran too. Nothing under `$FISHYDATA` was written.

- **A first trial let trips with no catch into the same pass** as trips with catch. 67 trips with catch then lost the
  landing they had: a trip with no catch took it at an earlier step. In one case, a trip with 42 t logged and a
  landing of 39 t lost it to a trip of the same day with nothing logged. Hence trips with catch first.
- **`lid_map`**: every one of the 823,310 matches stands, and 3,073 trips gain one. 1,483 are trips with no catch
  in steps 1-5 (01: 949, 02: 144, 03: 314, 04: 25, 05: 51), mostly fs_afladagbok 2021-2023 and 2020's adb app
  trips. 1,590 come through `09 order`: 687 within 3 days, 732 at 4-7 and 171 at 8-14. That is fewer than §3.3's
  2,227, because the trips with no catch, matched first, become anchors and take most of those pairs. The tie rule
  costs 4.
- **50 `09 order` pairs read by Claude** (a random sample, with each trip's dates, hauls, catch and gear beside its
  landing's). 47 read right: the same gear, logged and landed weights within 0.86-1.28 of each other, and dates 3-11
  days apart, as hand-line trips logged by the day often are. One afli trip has `T1` after `T2`, and the pair follows
  `T1`. Two look wrong: 2,250 kg logged against 817 kg landed, and a hand-line trip of 1,700 kg against a longline
  landing of 147 kg 11 days before. One trip with no catch cannot be judged. Over all 1,590 pairs, 1,515 name the same
  gear; 1,324 agree in weight within 50 %, 134 within 3 times and 100 do not (17 of them name another gear), and 32
  trips have no catch. Asked whether `09 order` should also check weight, the maintainer said no ("Do not check
  weights", 2026-10-20).
- **`logbook_gear`**: adb's stations now carry their own gear on 86,224 stations (`recorded`) and the landing's on
  2,663, and none is left without. Before, 86,385 carried the landing's and 2,502 had none. For afli and
  fs_afladagbok, 311 stations take a landing's gear through the new matches. adb's gear agrees with the landing's,
  where it names one, on 97.5 % of the stations §3.1 scored (codes the reference resolves, old matches), and on 96.9 %
  with 53 and 51 counted. 53 agrees on 78 %: the 584 that disagree are, in adb's own dredge table, the ocean quahog
  dredge (Kúffisksplógur) on trips whose landings (agf, gear 16) are whelk (species 45) caught with traps. The landing
  is the likely truth, and its gear is used.
- **`station_window`**: vid 2173's adb trips of 11 May and 20 June 2026 get 90 and 84 haul windows (bottom trawl,
  `gid` 6), against none before. Both trips are now matched, at `09 order`: 8 June to a landing of 5 June, and 20
  July to one of 23 July.
- **`voyage_gear`** (on the trial's gear and the current `trip_voyage`): 2,481 voyages with no gear take a landing's
  (§3.4: 2,476), at 2-7 days; 486 lose their landing gear to the at-sea rule (§3.4: 528 before the addition); 195 with
  none and 616 with a landing's now have a logbook gear, through adb's own codes.

## Not done

- The rebuild, by name from a clean tree, and the checks of plan 034 §5 on it. It runs together with TODO 98's change
  to `curate/ais_ping_union.R` (the afli GPS logger's whole-degree fixes left out, 2020 on), which rebuilds the AIS
  chain from `ais_ping_union`; so the voyages of 2019-2024 move for reasons of their own, and the counts after mix the
  two. The checks: pings and fishing flags on vid 2173's
  hauls, in the vessel overview too; `gid_basis` by source and year in the product; voyages gaining and losing a
  landing gear, counted on the rebuilt tables. The 50 `09 order` pairs are read in the trial's `lid_map`, which the
  rebuild reproduces from the same inputs.
