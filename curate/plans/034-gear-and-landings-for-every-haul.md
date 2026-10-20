# 034 — A gear for every haul: adb's own codes, the trip–landing match by time, and landings to voyages

**status:** executed — measured 2026-10-20; the six asks (§6) answered by the maintainer the same day (§7), each as
recommended, and no weight check on `09 order`; built and rebuilt that evening at c7fa8c7 with TODO 98's logger
exclusion, the checks of §5 passed (decision 154) · **2026-10-20** · **see:** TODO 97, plan 014 3j (the landing's gear
first), decision 066 (adb's gear left empty), decision 094 (twins), decision 143 (the previous trip's gear in the
vessel overview), plan 031 and TODO 90 (the voyage definition), TODO 81 (a catch landed over two days),
`curate/corrections/adb_vs_fs_afladagbok.yml` (defect 3), `sources/adb/convert.R`, `curate/link_lid_map.R`,
`curate/corrections/logbook_gear.R`, `curate/station_window.R`, `curate/voyage_gear.R`

Drafted with AI assistance (Claude) on 2026-10-20, in a session the maintainer drove: the questions and the rules in
§2 are the maintainer's, the measurements and the proposal Claude's. The numbers were measured by Claude (AI); a person
has not yet checked them. The scripts are in `$FISHYDATA/archive/2026-10-plan034/scripts/` (read-only, rerunnable).

**Measured:** every number in §1 and §3. **Assumed:** that the old-code reading of adb's gear is the same system in
every adb source (checked only as agreement with the landings, §3.1); that a landing dated after the vessel left again
belongs to the voyage before (the freezer-trawler case in §1; not checked against a weighing record); that pairing in
order between two matched trips is right when the counts agree (§3.3; not checked by hand).

## 1. The case that started it

In the vessel overview, vid 2173 (a freezer trawler) shows no fishing in 2026's trip of 20 June – 20 July, and no
pings on the hauls of that trip or of 11 May – 8 June, while January-April are full of both. The chain:

- Both trips are `adb` (Trackwell). adb records no usable gear (`gid` left empty, decision 066), so a haul's gear comes
  only from the trip's landing (`logbook_gear.R`), and neither trip is matched to one: their 90 and 84 hauls get
  `gid_basis = none`, so `station_window.parquet` has no row for them, and no ping is put on a haul.
- 11 May – 8 June: the landing is dated 5 June, the logbook's declared end 8 June, 3 days apart (`lid_map`'s date
  steps reach ±2). Its voyage (11 May – 5 June) takes the landing's gear (`voyage_gear`, basis `landing`), so the speed
  rule flags fishing pings, but not on hauls.
- 20 June – 20 July: the landing (817 t, bottom trawl) is dated 23 July, after the vessel left again (21 July 22:18).
  Neither the trip match (3 days) nor the voyage window (to the day after the voyage ends) reaches it: voyage 7 has no
  gear, so no ping is flagged at all. The landing counts instead for voyage 8, the one at sea that day.
- The two later trips are matched but carry 2,712 and 2,803 haul pings against 10,000-13,600 before: ASTD ends in June
  2026 (its delivery stops there, decision 107) and STK alone reports every 10 minutes.

## 2. The maintainer's rules (2026-10-20)

- **The gear of a haul comes from the landing's gear id**, wherever the trip is matched to a landing: the landings are
  the truth. (This is plan 014 3j, built in `logbook_gear.R`, for a landing naming one gear.)
- **adb has gears**, in the old code system. They should be read.
- **The previous trip's gear as a fallback is a bad idea** for historical trips that should be in order. Not proposed.
- **Match by time, not just by instant**: a vessel's trips and landings in order, not each record by its date alone.
- Match a landing to the voyage just before it, even when the vessel has left again: measure how much it affects.

## 3. Measured

### 3.1 adb's gear, read as the old code

The 88,887 adb stations in the merged logbook carry `gid_old` and no `gid`. Read as the old code (`reference/gear.parquet`,
version old → `map`), 86,169 of them (97 %) resolve. `fs_afladagbok` carries both codes on 374,679 stations, and its own
`gid_old` → `gid` gives the same gear for every code it holds (purity 0.98-1.00). Scored against the landing on trips
whose landing names one gear (86,385 stations): **97.5 % agree**.

| adb code | stations | gear (old code) | agree with the landing |
|---|---|---|---|
| 6 | 31,535 | OTB_DEF | 100 % |
| 3 | 24,661 | LHM_DEF | 100 % |
| 5 | 15,468 | SDN_DEF | 88 % |
| 1 | 6,016 | LLS_DEF | 100 % |
| 2 | 3,048 | GNS_GAD | 98 % |
| 53 | 2,682 | none | (landings: DRB_DES) |
| 25 | 1,676 | GNS_LUM | 97 % |
| 7 | 1,367 | OTM_SPF | 100 % |
| 14 | 1,012 | OTB_SHR | 99 % |
| 92 | 792 | GNS_GHL | 99 % |
| 10 | 488 | PS_SPF (the reference only) | 100 % |
| 9 | 103 | OTB_NEP | 84 % |
| 51 | 36 | none | (landings: FPO_DEF) |

The adapter's reason for leaving `gid` empty (`sources/adb/convert.R`, decision 066: the codes "do not resolve") does
not hold against today's reference table. Of the 1,061 adb trips with no gear on any haul (2020: 315, 2021: 22,
2022: 3, 2025: 9, 2026: 712), the old code resolves every haul of 1,050 and no haul of the other 11 (which codes
they carry is not measured). Not
re-measured: the exceptions the correction file found on shared stations in 2026-09 (adb 53 where fs says 15, adb 6
where fs says gid 8).

### 3.2 The match drops trips with no logbook catch

`link_lid_map.R` keeps only trips with `catch > 0`, for every step, though steps 1-5 use only vessel, date and port.
Unmatched trips with no catch rows, 2020 on: adb 302 of 315 (2020), 18 of 22 (2021), 137 of 543 (2026);
fs_afladagbok 934 of 1,907 (2021), 469 of 1,226 (2022), 282 of 915 (2023); afli 110 of 816 (2020).

Some adb sources record trips with no catch at all (raw `adb`, not the adapter: `trip_catch_v` holds species numbers
only, where haul catch exists): "APP TÖFLUR" (2020: 7,104 trips, 408 hauls, one with catch; 2021: 2,270, none), and
"FRA GAFLI" / "FRA GAFLI - AUTO" (2021-2026, 4,575-9,437 trips a year, almost none with catch). What GAFL's automatic
trips are is not known here.

**2020's adb trips** in the merged logbook: 319 (113 vessels), 266 in June, a median 0.3 days and about one haul each,
the coastal hand-line season entered in the app. They are not duplicates: 317 overlap no other source's trip. 305 have a
landing of the vessel within 3 days, and another trip holds only 17 of those. Let into the date steps (±2 days, an
unmatched landing with weight, one candidate only), at least 767 of 2,880 unmatched trips with no catch since 2012 find
one landing; 2020's app trips mostly find several (264 of 302) and stay unmatched by the uniqueness rule.

### 3.3 Matching by time

Since 2007-09, 17,922 logbook trips are unmatched, 15,744 of them between two matched trips of the same vessel
(anchors, at their landing dates); unmatched landings of vessels with logbooks are 115,384 (94,921 between anchors).
Between anchors, by the numbers of unmatched trips (nt) and landings (nl):

| nt | nl | gaps | trips | landings |
|---|---|---|---|---|
| 0 | 1 / 2 / 3+ | 20,922 / 2,290 / 4,441 | 0 | 80,915 |
| 1 | 0 | 7,913 | 7,913 | 0 |
| 1 | 1 | 2,090 | 2,090 | 2,090 |
| 1 | 2+ | 851 | 851 | 6,464 |
| 2+ | 0 | 1,041 | 2,923 | 0 |
| 2+ | 1+ | 536 | 1,967 | 5,452 |

Most gaps are landings with no logbook trip (nt = 0), or a trip with no landing of its own (nt = 1, nl = 0: landed
with a neighbour, TODO 81, or not a fishing trip). With zero-weight landings left out, **2,524 trips sit in gaps where
the counts agree and could be paired in order**: 1,324 within 3 days of their landing, 903 at 4-14 days, 297 further.
Both of vid 2173's trips are among them. A full monotone alignment (pairing in order where the counts differ, with
skips) is not measured.

### 3.4 Landings to voyages

`voyage_gear.R` counts a landing for every voyage it falls within (start day to the day after the end), not one.
Of 973,683 landings in the vessels' AIS spans, under "the last voyage ended by the end of the landing's day":

| today | landings | vessels | kt |
|---|---|---|---|
| the same voyage | 413,148 | 2,059 | 14,062 |
| shared with the next voyage too | 518,585 | 1,980 | 8,414 |
| only the voyage at sea that day ("moved") | 27,790 | 1,854 | 1,860 |
| no voyage ("newly matched") | 13,866 | 1,718 | 1,074 |

Made exclusive, the rule would take the landing gear from 61,292 voyages (6.7 M pings): small boats make several
voyages a day and land once. As an **addition** (a voyage holding no landing takes the first landing after its end,
within G days), voyages with no gear today gain one:

| G | voyages | vessels | pings |
|---|---|---|---|
| 3 days | 1,813 | 822 | 0.52 M |
| 7 days | 2,476 | 1,051 | 0.64 M |
| 14 days | 2,832 | 1,163 | 0.69 M |
| none | 3,622 | 1,370 | 0.95 M |

Gaps of over 30 days (about 5,000 landings) point to a voyage cut wrong or a track missing, not a landing just after.
Today's window also gives 21,578 landings to a voyage the vessel was at sea on all that day (13,710 voyages, 1,507
vessels); without them, 528 voyages whose gear is a landing's would lose it, and 14 change gear. Of about 426,000
voyages with no gear, nearly all have neither a logbook trip nor a landing.

### 3.5 Trips with no gear, and their voyages

1,064 trips have no gear on any haul: 1,061 adb and 3 afli. 899 are on a voyage: 622 of those voyages have a landing
gear today, 76 a logbook gear (another trip on the voyage), 193 none (7 gain one by §3.4 at 7 days). §3.1 resolves all
but 11 of the adb ones on their own, so the voyage is a cross-check, not a source, for them.

## 4. The design (proposal)

Gear stays the landings' wherever a trip is matched; the work is to match more trips, rightly, and to read adb's own
code where no landing is matched.

1. **adb's own gear, read** (preprocessing, `curate/corrections/logbook_gear.R`). adb's `gid_old` is mapped to the new
   code through the reference's old code, as the logbook's own gear; `fishing_sample.parquet` keeps `gid_old` and its
   empty `gid` (the original is never overwritten). The landing's gear still wins where it names one; where it does not,
   or no landing is matched, adb's own stands. Codes 53 and 51 by ask a. The adapter's comment and decision 066 are
   amended.
2. **Trips with no catch in the date steps** (`curate/link_lid_map.R`). The `catch > 0` filter applies to the weight
   steps 6-7 only; steps 1-5 take every trip, with the same uniqueness rule.
3. **A match by time** (`curate/link_lid_map.R`, a step after the cascade). Per vessel, between two anchors, the
   unmatched trips and landings with weight are paired in order where their numbers agree, within a day limit (ask c),
   as `match_type` "09 order". A full alignment is a later step, measured first.
4. **Landings to voyages by time** (flow, `curate/voyage_gear.R`). A voyage with no landing in its window takes the
   first landing after its end within G days (ask e), even when the vessel has left again; a landing dated on a day the
   vessel was at sea all day no longer counts for that voyage. Basis `landing`, the gap kept in a column.
5. **Rebuild**, by name from a clean tree with fingerprints first: `lid_map`, `logbook_gear`, `station_window`,
   `trip_voyage`, `station_event`, `voyage_gear`, `ais_trail`, `ais_catch` and their readers (`catch_by_species_*`,
   the checks). Not measured: how long it takes.

Not proposed: the previous trip's gear in the flow (§2; after step 1 it would reach 14 trips: 11 adb, 3 afli).

## 5. Checks (done when)

- vid 2173's two trips have haul windows, pings on their hauls and fishing flags, in the vessel overview too.
- adb's gear agrees with the landings' on at least 97 % of stations with one landing gear (§3.1), now inside the
  product: `gid_basis` counts before and after, by source and year.
- Every new match is counted by step and year, and a sample of 50 "09 order" pairs is read by hand.
- Voyages gaining a landing gear and those losing one are counted against §3.4.
- `check_bookkeeping()` passes; a decision record says what was built.

## 6. Asks

a. adb codes 53 (2,682 stations) and 51 (36): the landings say dredge (DRB_DES) and pots (FPO_DEF). Map them so, or
   leave them without gear?
b. adb's translated code: `gid_basis` "recorded" (it is the logbook's own), or a label of its own?
c. The match by time: equal counts between anchors only, and within how many days (2,227 pairs are within 14)? Or
   design the full alignment first?
d. Trips with no catch into the date steps: yes? Who or what makes GAFL's automatic trips, and are they fishing trips?
e. Landings to voyages: G = 7 days, and stop counting landings for a voyage the vessel was at sea on all day?
f. When to rebuild, given the run from `lid_map` to `ais_catch`.

## 7. Answered (the maintainer, 2026-10-20)

*Recorded by Claude from the maintainer's answers in chat the same day, one round, each the option Claude recommended.
The facts found while preparing the asks, and "To settle in the build", are Claude's, for review.*

a. **adb's own table.** Every adb code is read through adb's own crosswalk, `raw/oracle/adb/fishing_gear.parquet`
   ("between FS and GEAR fishing gear numbers"): adb's code is the GEAR number (`raw/oracle/gear/fishing_gear.parquet`),
   and the FS number it maps to is the new `gid`. So 53, "Dregin plógur" (GEAR: dredge, ISSCFG 0410), is FS 15
   (DRB_DES), and 51, "Krabbagildra" (trap, 0820), is FS 16 (FPO_DEF), as the landings say. On the 11 codes it shares
   with the reference's old code the two agree. Through it, 88,886 of the 88,887 adb stations resolve. The one left is
   code 99, "Óskráð veiðarfæri" (gear not recorded), which keeps no gear.
b. **`gid_basis` "recorded"**: it is the logbook's own gear, written in the old code. `gid_old` stays in
   `fishing_sample.parquet`, so the translation can be traced.
c. **Equal counts between anchors only, within 14 days** (2,227 of the 2,524 pairs). The full alignment is a later
   step, measured first.
   Follow-up, the same evening: no weight check on `09 order` ("Do not check weights"), though 100 of its 1,590 pairs
   differ in weight by more than 3 times (decision 154).
d. **Yes**, trips with no catch go into steps 1-5. The question about GAFL falls away: no "FRA GAFLI" or
   "FRA GAFLI - AUTO" trip reaches the merged logbook (0 in `trip.parquet`, 2021-2026). The "… - GAFL AUTO" trips that
   do (1,608 in 2026) all have catch, and all but one are matched. The trips with no catch that matter are 2020's app
   trips, fs_afladagbok's in 2021-2023, afli's in 2020 and about 137 adb trips in 2026.
e. **G = 7 days**, and a landing dated on a day the vessel was at sea all day no longer counts for that voyage.
f. **Now, in this session**, from a clean tree. The work left uncommitted was committed first, as it stood (5c129eb,
   the vessel demo; fb3f3e8, this plan). The maintainer then held the rebuild until they are home (same day).

**To settle in the build** (Claude's reading):

- The crosswalk is read in `logbook_gear.R` where the dump put it, tracked by a file target of its own
  (`adb_gear_code`), so the adapter and the merged logbook are not rebuilt. In `gear.parquet` adb's `gid` is the
  translated code, and its labels (gear, target, target2) are the reference's for that code.
- Step 8 (the expected date) keeps `catch > 0`, as before, so its yield changes only through the landings that earlier
  steps now take.
- `09 order` takes every unmatched trip (with or without catch) and every unmatched landing with weight. Anchors are
  the matched pairs at their landing's date, and trips (by their `T2` date) and landings lie strictly between two of
  them. A gap pairs only where the numbers agree, and only where the order is defined: no two of its landings on one
  date and no two of its trips with one `T2`. A pair is kept within 14 days.
- `voyage_gear.R` gives a landing its voyage before as measured in §3.4: the last voyage ended by the end of the
  landing's day. A voyage with no landing in its window takes those landings within 7 days of its end date. The days
  go in `landing_gap_d`, which is empty for a landing in the window.
