# 047 — Independent audit of the mid→vid match: the key holds where it can be checked; the defect is call-sign reuse and it is concentrated

*2026-09-29. Executes plan `009-independent-audit-of-the-mid-vid-match.md`. Analysis by
Claude (AI-assisted) at the maintainer's direction, with the decision rules lifted for
the exploration. Nothing was written under `$FISHYDATA`; nothing was reassigned. The
analysis scripts live in the session scratchpad and were **not promoted** — the numbers
below are the record, and §7 says what promotion would take.*

## 0. How to read this record: a ledger first, statistics as background

The maintainer's framing (2026-09-29): this is a **bookkeeping** audit — every assignment
is a record to be checked against what each source says — and the statistics below are
background tests, not the finding. The row-level result, one row per key row
(`vessel_ais_key`, 19,234 rows; 2,967 claim a vid):

| status | rows | meaning |
|---|---|---|
| ok: physical (W1) | 1,710 | the mid's transponder is co-located with the claimed vid's own MMSI |
| ok: two witnesses / one witness | 40 / 89 | logbook and/or landings agree; nothing against |
| **discrepancy** | **132** | a witness names another vid on the mid, or the mid carries two vids in sequence, or ≥ 2 witnesses contradict |
| review | 20 | single-witness flags, or a split candidate the ODS did not make |
| covered, none supports | 92 | a witness reaches it and neither confirms nor refutes |
| **no witness reaches** | **884** | **30 % of the rows that claim a vid have no evidence except the registry and the STK identifier fields** |

The discrepancy register (248 rows) lists each with its type, mid, key vid, the other vid and
the evidence; it also carries the split candidates (20 strong, 71 review) that §6c describes.
Both are now **checks in the repo** — `curate/checks/ais_key_audit.R` and
`curate/checks/ais_key_split_candidates.R`, wired into `_targets.R` — and were run end to end
in full (7 and 2 minutes) with the write redirected to the scratchpad; the parquet under
`curated/check/` is built the next time the targets run. (The `mid outlives the hull` category
reads 0 in that test only because `curated/check/ais_key_registry.parquet` is stale until its
own target is rebuilt.) An earlier exploratory ledger reported 1,088 rows reached by no witness;
it dropped cells that only W1 covered, and this run replaces it.

The 30 % is the finding to sit with: the cascade assigns those vids without a single
independent witness, mostly small vessels with no logbook and no other-provider AIS.

## 1. Headline

Ping-weighted over the 2007–2025 mid-years the key assigns a vid to (~152 M pings):

| verdict | pings | share |
|---|---|---|
| **confirmed** — W1 (transponder co-located with the vid's own MMSI) or ≥ 2 witnesses agree | 109.0 M | **71.5 %** |
| supported by one witness (W2 or W3), nothing against | 29.0 M | 19.1 % |
| covered, none supports (mostly "fits but not uniquely", see §5) | 11.3 M | 7.4 % |
| no witness can speak | 2.3 M | 1.5 % |
| flagged by one witness | 0.6 M | 0.4 % |
| **contradicted by ≥ 2 witnesses, or by W1** | **≈ 0** | **0.04 % of cells** |

**No key row that could be tested against a physical witness was refuted.** The errors
are elsewhere: a small set of mobile-ids that changed hands under one call sign
(§3), and vids the key never gave a mid (§4).

## 2. The instruments, and how far each was trusted

Each witness was calibrated **before** it judged anything (plan §3.1), on rows the
others had already confirmed and on a shuffled null.

| | what it does | sensitivity | specificity | limits found |
|---|---|---|---|---|
| **W1** other-provider AIS (`astd`/`astdB`/`emodnet`) co-located with STK, ≤ 5 min and ≤ 2 km | STK ping `M`; provider ping labelled `vid V` via MMSI | tier A, provider at least as dense as STK: **96–100 %**; raw score falls to 3 % when the provider is sparse, so the score is **hits ÷ opportunity** (STK pings with any `V` ping ±5 min) | random other vid confirms **2 in 100,000**; not circular — 0.44 % of hits are timestamp-and-position-identical | 2013→ only; proves *mid ↔ MMSI*; MMSI ↔ vid is still the registry's word |
| **W2** logbook station within 10 km of the mid's track that day | station has date only (hour is always 0) | 97 % of W1-confirmed pairs score ≥ 0.5 | **per month poor** (best impostor ≥ 0.5 in ~65 % of vid-months, crowded grounds); **per year good**: true beats best impostor 97.3 %, impostor wins 0.6 % | needs ≥ 30 stations; per-month grain mis-scores short-lived mids (§4) |
| **W3** landing at a port on a day the mid logged entering that port | STK `hid` (in/out events, ~3–4 % of pings) → `pid` learned from W1-confirmed pairs (101 codes, median 91 % agreement) | median hit rate 1.00 | true beats best impostor 93.5 %, margin ≥ 0.1 in 78 % | **a port-hopper wins everything at its ports** — see §4; crosswalk was learned in-sample |
| **W6** mid number as a clock | Spearman(mid, first ping) **0.992**, 31,777 mids | — | — | see §6 |

## 3. Where the key is wrong: one mobile-id, two vessels (W1)

**Standard applied:** the maintainer's bar is 99.99 %, not 95 %. In the slice W1 can decide
(2013→, vessels heard by another provider) the key is wrong for **1.18 % of moving pings**
(823,446 of 69.5 M; 837 of 59,757 mid-months), plus 0.21 % where two vids both fit; 98.6 %
agree. That is ~100× the bar, and it is measured only where a physical witness exists.

Identifiers are vid and MMSI; vessel names are not used anywhere in this audit as evidence
or to tag findings (an earlier draft tagged "known vs new" by name; redone by mid).

**Sequential-identity mids.** W1 confirms **63 mids on two different vids in
non-overlapping eras** (≥ 3 confirmed months each). The key splits only **20** of them
correctly by vid and date; **13** hold only the first vid, **11** only the second, **9**
are wrong for both, **10** have no key row for those dates (probably gear/net devices
carried between vessels — the key class for 8 of them is not a vessel). At least 33
mids therefore carry a wrong vid for one whole era. This is broader than the 27-group list
below, which only counts eras where the key's own vid was silent.

**The 27 long (≥ 6 month) K-silent groups:** 13 have their mid recorded in decisions
020/021/044/045, the corrections file or `overrides/`; **14 are not recorded**:

| mid | key vid | co-located vid | tier | period | STK pings |
|---|---|---|---|---|---|
| 101084 | 2903 | 2212 | C | 2022-08→2026-01 | 71,171 |
| 100137 | 2847 | 1136 | B | 2013-01→10 | 20,741 |
| 101967 | 2892 | 2730 | B | 2013-01→11 | 15,203 |
| 111702 | 2870 | 3038 | B | 2023-03→2025-08 | 13,661 |
| 100739 | 1371 | 3010 | B | 2022-09→2026-01 | 10,186 |
| 112543 | 3857 | 2730 | C | 2022-07→2023-07 | 8,118 |
| 101049 | 1585 | 3060 | B | 2025-05→2026-01 | 8,074 |
| 103072 | 2219 | 2943 | B | 2022-03→2024-04 | 6,549 |
| 103007 | 2699 | 2110 | B | 2021-02→2024-07 | 5,959 |
| 122712 | 2923 | 3042 | B | 2024-06→2025-09 | 3,821 |
| 103738, 103740–42 | 9848, 9850–52 | 2914 | **A** | 2022–2025 | ~8,500 |

Mids 100137 and 101967: the co-located vid's **call sign differs from the mid's `glid`**
(so it is not call-sign reuse) and the key's vid only entered the registry in 2013/2017.
This qualifies decision 046's reading for **2013, the only year W1 can see**; most of
their before-birth pings are 2007–2012 where no witness reaches — untested, not cleared.

Three mids with no vid are co-located with a real hull for ≥ 6 months, no other mid keyed
to it: **100881** = vid 2887 (59,724 pings, 2014-10→2018-12), **101763** = vid 2500
(22,513), **100512** = vid 1599 (17,177, 2014-01→2015-05) — contradicting
`ais_key_callsign_reuse.yml`'s "vid 1599 never transmitted".

Nothing is entered as an override: each needs the decision-045 track-correlation
procedure or a maintainer's eye first.

## 4. What looked like contradictions and was not

Both W2 and W3 first reported 297 contradicted cells, 254 of them in 2007–2012. **All but 11 were
instrument artefacts**, and the ways they failed are the lessons:

- **A port-hopper wins at every port it visits.** 162 of the 238 W3-only contradictions
  name one impostor, mid 103094 — a ferry in and out of
  Vestmannaeyjar and Þorlákshöfn daily. Rule adopted: a contradiction needs a second
  witness or W1.
- **Fixed stations and net relays sit inside crowded fishing areas** and "hit" nearby
  logbook stations; impostors must be moving vessels.
- **Month-grain scoring against a mid that lived days.** The 9 corroborated tier-D
  (`NA_mmsi`) contradictions are all short-lived placeholder mids replaced by the vessel's
  proper mid *within minutes* (112402's last ping 07:10, 112423's first 07:15, 2014-02-28),
  both keyed to the same vid. The key is right; the scoring was not.
- The remaining **2 are real**: mids 103007 and 101049 — W1 and W2/W3 agree (both are in §3).

## 5. The 7.4 % "covered, none supports"

Not weak. 3,064 of 5,025 cells are "key vid fits (≥ 0.8) but another mid fits within
0.1" (a busy port); the median best score in the bucket is 1.00. Persistently weak
(≥ 80 % of ≥ 3 covered years below 0.5): **18 of 1,825 pairs**, 12 of them foreign
hulls or whalers whose "stations" are not logbook tows. 98 % of these pings are fishing
classes (`mclass` 33/35/36/37/64/68), where logbook and landings exist — the coverage
follows the usage class, as it should.

## 6. What the mid-clock and real spans showed

- **Real activity spans, not `d1`/`d2`.** Vids with two mids whose *real* ping spans overlap
  > 1 day: **57 pairs (51 vids)**, against the 129 the sentinel-based `two_mids_open`
  reports. Of the 31 long ones, W1 confirms **both mids in 14** (two transponders on one
  hull), one mid in 9 (the other not heard by any provider), 8 W1-blind. Not defects
  until the 9 are read.
- **Handover is visible.** A vessel's second mid usually starts minutes after the first
  ends (§4). A mid that *starts* while another of the same vid is still live is the
  case worth reading.
- **Anachronism.** 2,591 mids have a first ping > 30 d earlier than their number
  implies (1,030 by > 365 d); a cohort of 2007-06-01 first pings sits on mid numbers that
  imply ~2009-08 — history back-filled onto later-numbered mids. Tested: in 2007–2009
  these mids' verdicts match ordinary mids (confirmed 11.8 % vs 11.0 %; flagged 5.2 % vs
  2.8 %), so **no evidence they are misattributed**, but that window is W2/W3-only and
  weak. 646 mids were created > 180 d before their first ping (dormant hardware).

## 6b. W8 — behaviour change-points: tested empirically, useful only as a triage ranker

Grounded in labelled data, not assumed. Labels: every ≥ 14-day silence in a mid's
series where W1 names a vid within 6 months on **both** sides — **23,760 hiatuses, 351
(1.5 %) with a different vid**.

- **A hiatus is not evidence.** 158k hiatuses ≥ 14 d on 11,710 mids; 90.5 % of random dates
  on W1-stable mids have one within ±60 d. Different-vid rate by gap: 14–59 d **1.3 %**,
  60–179 d 1.8 %, 180–364 d 1.0 %, 365–729 d **11 %**, ≥ 730 d **35 %**.
- **The instrument works on a known change:** splicing two stable mids at a random date
  is detected with AUC 0.95 (0.80 for same-class, similar-size, same-area pairs).
- **My first scan was wrong, and is discarded:** it scored splits inside the W1 bracket,
  needing 8 populated weeks on both sides — impossible across a multi-year silence — and
  returned AUC 0.40–0.45 on 63 known switches. The raw data shows the change plainly
  (centroid shifts of 1–2° latitude, speed 3 → 5.4 kn). Corrected: last 8 active weeks
  before a silence vs first 8 after, seasonal null = the same calendar windows ±1 year.
- **Short silences: no signal.** Seasonally adjusted AUC 0.49–0.54 (14–364 d); among
  same-vid hiatuses 10 % show a centroid shift above 225 km (seasonal migration).
  Hiatus length alone is as good as the profile, and its brackets are selection-biased.
- **Long silences (≥ 365 d):** 33 of 166 labelled are different vessels; raw AUC for
  ≥ 730 d is 0.82 (centroid) and 0.89 (speed histogram). Flag rule (centroid shift
  ≥ 150 km or speed-histogram distance ≥ 0.4): **precision 0.33, recall 0.90** on the
  labelled ≥ 365 d set. Nowhere near 99.99 %.
- **Triage list (not evidence):** flagged, key gives the same vid on both sides, W1 blind:
  **578 hiatuses on 411 mids**, 10–65 per start year, 2007→2024 — where W1 cannot look.
  Usage-class history (Hreidar's `Notkunarteg` by year) was not yet used to explain a
  flagged change.

## 6c. Emulating the human who made the ODS splits — and going past them

Goal set by the maintainer: do better than the ODS, then use the algorithm on the full data.
**What the human read** (maintainer): the time-speed profile, spatial patterns (down to a
vessel's last trip out of Icelandic waters), changes in the vessel registry, and logbook and
landings month by month. **Measured on the ODS's own splits** (60 boundaries between
recorded rows with different vids, Icelandic focus): all 60 lie inside a silence of the mid's
pings, 54 of them a year or longer; the profile shift across them is large (median centroid
shift ≥ 300 km, speed-histogram distance 0.59). So the candidates are the silences ≥ 180 d
on mids the key gives an Icelandic vid, read for four evidence families:

| family | fires at the human splits (of 44 on key-claimed mids) | at all 3,934 such silences |
|---|---|---|
| profile shift (≥ 150 km or speed-histogram ≥ 0.4) | 38 | 664 |
| last/first position outside Icelandic waters | 31 | 161 |
| registry: a different hull holds the mid's call sign or MMSI after | 28 | 47 |
| registry: the key vid's own lifetime ends at the silence (±1 y) | 38 | 140 |
| *(logbook/landings best-fit vid changes — left out of the check: 14 / 29, costly)* | | |

Every human split has at least one of the four non-profile families. Calibrated against
W1's independent eras on the same Icelandic mids: **≥ 3 families — 51 silences, 32 already
split by the human, all 19 that W1 can check are real vessel changes; exactly 2 families —
98 silences, W1 confirms 7 of 22.** The reader is blind to 14 of the 41 W1-verified changes
(no family fires), so it is a lower bound.

**Past the human:** 107 silences the ODS did not split (19 strong, 88 review). For the 19
strong, 16 get a proposed vid pair (before / after) from the registry holder, the logbook /
landings best fit and W1, and 5 have two independent sources agreeing on both sides. That
table is `proposed_splits` (session scratchpad, not promoted). Nothing is entered as an
override: a proposal is a candidate for the decision-045 track-correlation step and a
maintainer's review.

**Built as checks** (`R/audit_split_reader.R`, `R/audit_witnesses.R`, `_targets.R`):
`curate/checks/ais_key_split_candidates.R` → `curated/check/ais_key_split_candidates.parquet`
(one row per silence with the four flags, tier and `ods_split`); and
`curate/checks/ais_key_audit.R` → the ledger and discrepancy parquet described in §0, which
reads the split candidates rather than repeating them. Both were run end to end with the
write redirected to the scratchpad and `curated/` untouched; the split check reproduced the
numbers above exactly. `ais_key_audit` was then run in full as well (see §0).

### The same reader on the MMSI series (the second identifier)

vid and MMSI are the two identifiers; the provider pings are keyed by MMSI and labelled with a
vid through `vessel_identity`'s MMSI windows, so an MMSI that moved between vessels is the
mirror of a mid that changed hands. Run 2026-09-29 on the non-STK providers (2,097 MMSIs,
2.6 M MMSI-days, from 2013): 1,459 silences of ≥ 180 d on Icelandic vids, on 473 MMSIs. Same
families, with the registry's own MMSI-window end replacing the call-sign handover.

- **Calibration is thin: only 5 silences are registry-known migrations** (the MMSI maps to a
  different vid after). All 5 fire the registry families and 4 of 5 fire profile and abroad.
  In all 5 that STK can check, the mid co-located with the MMSI afterwards is keyed to the
  vid the registry names — the registry's MMSI handovers are confirmed from the STK side.
- **Same-vid silences, 1,454:** 19 fire ≥ 2 families (3 fire ≥ 3). STK evidence for those
  19: the key agrees with the registry's label on ≥ 1 side for 11, contradicts it for 2, and
  there is no STK evidence for 7 (unverifiable). The 2 contradictions are **already found
  from the mid side**: MMSI 251289000 (registry vid 2916) rides with mid 101350, which the
  key gives vid 2197 although that hull ended in 2014; MMSI 251536000 (vid 2730) rides with
  mids 101967 (key vid 2892, 2013) and 112543 (key vid 3857, 2022–23). No MMSI is shown to
  have migrated beyond the 5 the registry already records.
- **Reading:** the two identifiers tell the same story. The MMSI side adds a second, independent
  route to the same two discrepancies, and finds none of its own. 7 candidate silences have
  no STK witness; a promoted check would list them as unverifiable, not as findings.

## 7. Manual rows, tier A, and what is not settled

- **The manual rows** (592 cells, 61 mids): 421 confirmed, 122 single-witness, 21
  inconclusive, 21 uncovered, 7 flagged, **0 contradicted**. Where W2/W3 disagree they
  point at mid 103173 (vid 2549) vs mid 101078 (loid 2500) — a candidate swap.
- **Tier A.** The expectation that "both fields state the vid" proves little was right to
  hold. W1 finds no tier-A refutation in ~29,000 covered mid-months, but the residual
  flags (149 single-witness + 74 flagged-vs-support + 5 conflicts + 2 contradictions) sit
  almost entirely in tier A, and the vid 985x family above is tier A. Its strength is that
  two independent free-text fields agree; it does not say the transponder on board is the
  vessel's own.
- **Not done:** the logbook/landings family in the split reader as a check; the 2016-06 bulk re-issue of ~1,800 mids as a unit;
  W1 for 2007–2012 and 2026 (no other-provider data); the 389-row watch list (single-witness
  flags) triaged; the W3 crosswalk re-learned out of sample.
- **Registry usage class** (`mclass`) was used to stratify coverage, not yet as a
  plausibility witness: a mid whose track is a trawler's while the register calls the vid
  a passenger vessel.

## 8. Rules relaxed, and what came of it

Relaxed as instructed: the cascade order, the tier boundaries, "a `vid_vid` row is right
because two fields agree", and "a `manuals` row is right because a person entered it".
None was needed to reach these results; each was *tested* and only the tier-A assumption
was found to need qualifying. The cycle rule (`AGENTS.md`) was kept: W1 reads other
providers keyed by MMSI, W2/W3 read logbooks and landings; none reads the key.

## 8b. Phase 2, first pass: the discrepancies read as eras

`curate/checks/ais_key_resolution.R` (`curated/check/ais_key_resolution.parquet`, wired into
`_targets.R`) turns each mid in the discrepancy register into eras: runs of months in which one
vid's own other-provider AIS is co-located with the mid, set beside the key's vid for those
months, tested against the registry, with the boundary read against the mid's ping silences.
Run in full 2026-09-29 (output to the scratchpad; `curated/` untouched). 196 mids, 249 rows:

| action | rows |
|---|---|
| key already right | 130 |
| key differs: reassign (a proposal) | 32 |
| not a vessel: a device heard with this vid, leave the key | 24 |
| the mid moves between vids, its own included: a device carried between vessels, read by hand | 13 |
| two vessels heard at once: read by hand | 2 |
| unresolved: no W1 era (before 2013, or not heard by any provider) | 48 |

**30 proposals on 25 mids** (14 strong ≥ 12 months of co-location, 7 moderate, 9 weak < 6). The
first draft of this table proposed 112 and was wrong twice, both worth keeping: a seasonal
vessel's winter silence cut one tenure into many short eras, and net relays and devices
carried between vessels (the mids keyed to vids 9848–9852, moving between vids 1252 and 2914)
were proposed as vessels. Eras are now runs of one vid that no other vid interrupts, isolated
months of a neighbour are dropped first, and a device is never given a vessel's vid.

Nothing is entered as an override. A proposal is where a person starts, with the track
correlation of decision 045 as the next step. 48 discrepancy mids have no W1 era at all; for
them phase 3 (usage class, Hreidar against logbook and landings) is the only route.

### Track correlation on the 14 strong proposals (decision 045's method)

Each STK ping of the mid is matched to the nearest-in-time ping of the candidate vid's own
other-provider track (≤ 6 h, either side) and the great-circle distance taken. Years of the
proposed era only, years with ≥ 100 matched pings:

- **12 of 14 confirm**: 90–100 % of the mid's pings within 2 km of the proposed vid's own track,
  median 0.0–0.5 km (mids 100099, 100111, 100170, 100290, 100645, 100739, 101081, 101439,
  101759, 103094, 103749, 111702).
- **2 are consistent but noisier**: mids 103007 and 103072 — 52–61 % within 2 km but median
  0.4–3 km and 76–100 % within 10 km; read as a sparser other-provider feed meeting the 6-hour
  window, not a different vessel. They stay for a person to read.
- **The key's vid has no other-provider track in the era years for any of the 14**, so nothing
  supports the key either way; where the key vid *does* have a track it lies before the era
  (mid 100099: 2013–2015, 78–79 % within 2 km), which is the two-vessel sequence itself.

A temporary Shiny review app (session scratchpad, **not committed**) shows each of the 14 for a
person: month-by-month overlap of the mid, both vids' AIS, logbook stations and landings; the
time-speed profile; tracks before and during the era; the correlation by year; the key, eras and
registry rows; and records accept / reject / read-by-hand per mid to `review_decisions.csv`. A
decision recorded there is still only a decision: it enters `overrides/` through a person.

## 8c. The invariant: no ping of a mid that has a vessel is unassigned

Stated by the maintainer (2026-09-29): when a mobile-id is assigned to any vessel, a vessel is
assigned for its **full period**, first ping to last. The key assigns with `between(time, d1, d2)`,
so a ping outside every period, or inside one with a negative vid (the ODS's `drop` rows), is
silently lost. **The key does not meet it today.** `curate/checks/ais_key_coverage.R`
(`curated/check/ais_key_coverage.parquet`, wired into `_targets.R`), run 2026-09-29 with the write
redirected to the scratchpad, on 2,879 mids that have a vessel (181.2 M pings):

| where the pings are | mids | stretches | pings |
|---|---|---|---|
| before the first period, starting in STK's start-up years (< 2009) | 8 | 22 | 34,602 |
| before the first period, later | 16 | 20 | 546 |
| after the last period | 9 | 46 | 4,005 |
| between periods of different vids | 17 | 53 | 333 |
| between two periods of one vid | 1 | 1 | 1 |
| a negative vid, start-up years (a deliberate drop) | 7 | 7 | 24,525 |
| a negative vid, later | 7 | 7 | 3,774 |

39,487 pings sit outside every period (0.02 %) and 28,299 more on negative vids. **The largest
single cause is a typo**: mid 101097's first row has d1 2008-06-04 after d2 2008-05-20, so it
covers nothing, and the mid's first ping is 2007-06-04 — 34,307 pings unassigned. The check
proposes a deterministic fill (the first period's vid extended back; a single vid across a gap;
two different vids cut at the midpoint of the pings and flagged ambiguous; a negative vid listed
for a person, never filled by a rule) and **asserts that applying it leaves 0 pings unassigned**.
Stretches beginning before 2009 are flagged `startup_phase`: STK's start-up years are
untrustworthy (back-filled history, a device not yet on its vessel, test transmissions), so a
person confirms those fills. The split proposals of §8b obey the same invariant: each is built
from tiling periods and was dry-run against a copy of the key (1.62 M pings relabelled across 25
mids, none lost).

## 8d. The segment table (plan 009 phase 2), built and scored against the ODS

`curate/checks/ais_key_segments.R` (`curated/check/ais_key_segments.parquet` and
`ais_key_segments_vs_ods.parquet`, wired into `_targets.R`) rebuilds the assignment as a table
that **tiles every mobile-id**. Cuts: silences of ≥ 180 d where the split reader fires ≥ 2
families, and changes of the vid W1 confirms (dated mid-way between the two runs); over-cutting is
harmless because neighbouring segments of one vid are merged. Each segment's vid, best evidence
first: **physical** (W1 confirms it in ≥ 3 months of the segment), **registry** (the mid's own call
sign or MMSI belongs to one vid over it), **continuity** (the key's vid carried across). A negative
key vid stays unassigned for a person. Run in full 2026-09-29, write redirected to the scratchpad.

**Acceptance, asserted and passing:** the segments tile all 2,879 mobile-ids that have a vessel, with
no gap and no overlap; every one of 181,165,778 pings is in exactly one segment; the only pings on
no vid are **16,902 on an explicit drop**. 2,989 segments in all.

**How far the evidence reaches** — the number to keep in mind: **64.2 % of the pings (116.3 M) lie in
a month W1 confirms for the assigned vid or in the registry holder's period; 35.8 % (64.8 M) are
carried across a segment by continuity.** A segment graded "physical" is usually only partly
covered, so the grade is not the coverage. W1 agrees with the table in 59,591 of 60,566 confirmed
mid-months; the 975 that differ (1.6 %) are twins or companion vessels still to be read.

**Against the current key:** 50 segments (2.05 M pings) carry a different vid — the queue for a
person, which subsumes the 30 first-pass proposals of §8b. 1,755 segments start in STK's start-up
years and are flagged.

**Scored against the ODS without using it** (each segment also has a vid derived with the key rows
that came from the ODS taken out of the continuity step):

| ODS row type | reproduced without the ODS | the table differs | unreachable without the ODS |
|---|---|---|---|
| dual (124) | 91 | 7 | 26 |
| manual (351) | 8 | 1 | **342** |
| split (3) | 3 | 0 | 0 |

**The rule alone reproduces the ODS where a witness reaches it and cannot reach the 342 single-vid
manual rows** (5.5 M pings) and 26 dual rows: for those mobile-ids the cascade had no answer, a
person supplied one, and no physical or registry evidence exists to re-derive it. That is the
measured content of "the ODS is the only evidence for those rows". Reaching them needs logbook and
landings at segment level and a person's review (plan 009 phase 4), and until they are answered the
ODS stays an input. The 8 differing rows are decided by a person.

### Update 2026-09-29: logbook and landings added, and a correction

Logbook (W2) and landings (W3) now sit between the registry and continuity in the vid assignment,
scored over each segment window with the year-level calibration (logbook ≥ 80 % of the vid's stations,
margin ≥ 0.1, ≥ 30 stations; landings alone only at ≥ 90 % with margin 0.3, because a ferry wins every
port it calls at). The audit now persists the monthly tables they need
(`ais_key_audit_lb_hits/_n`). A missing record is never evidence against a vid: the denominators only
exist for months a vid has records, so a vessel that stopped fishing does not dilute its own score.

- **Sources of the assignment:** physical 1,686 segments (167.2 M pings), registry 171 (1.5 M),
  logbook 173 (3.5 M), landings 60 (0.7 M), continuity 895 (8.2 M pings assigned by continuity on
  top of the parts of other segments the evidence does not reach). **0 pings on no vid**: the one
  drop segment (16,902 pings, negative key vid) is now assigned by logbook evidence and goes to a
  person as a proposal, since the human dropped it.
- **Direct evidence now reaches 89.6 % of the pings (162.4 M)**; 10.4 % (18.8 M) are carried by
  continuity. A logbook or landing month counts as evidence only when the mid explains ≥ half of that
  month's stations or landings and at least two of them (the first cut counted a single hit and read
  91 %; too generous).
- **55 segments (2.17 M pings) differ from the key** (was 50). 990 W1-confirmed mid-months (1.6 %) sit
  in a segment of another vid.
- **Correction to the ODS score above.** The 332 "unreachable" manual rows are **all foreign vessels**
  (vids 3711–4981, not in the Icelandic registry); the earlier line that the ODS is the only evidence
  for 342 Icelandic manual rows was wrong. Re-cut by nationality, without using the ODS:

| ODS rows | reproduced without the ODS | the table differs (a person) | unreachable |
|---|---|---|---|
| **Icelandic (vid < 3700), 129** | **112 (86.8 %)** | 6 (4.7 %) | 11 (8.5 %, 114,317 pings, mostly 2007-08) |
| foreign (3700+), 349 | 15 | 2 | 332 (5.2 M pings) |

For the Icelandic focus the rule therefore reproduces the ODS almost entirely from independent evidence.
The six differences (mids 101084, 101081, 101223, 101776, 101089 and one more) and the eleven
unreachable start-up-year rows are the residue a person reads. The foreign vessels are the bonus and
stay ODS-only until they get their own evidence.

## 9. Recommended next steps (none started)

1. Send the 14 unrecorded W1 groups, the ~33 mis-split two-era mids and the 3 unassigned mids through the decision-045 track-correlation
   procedure; enter confirmed ones through `overrides/`.
2. Amend decision 046's before-birth ⇒ reuse reading for TFGR and TFCR (wrong for 2013; 2007–2012 untested).
3. Ask the maintainer what STK devices carry vids 9848–9852 (gear travelling with vid 2914?).
4. Promote W1 as `curate/checks/ais_key_colocation.R` (cheap: ~0.5 s/month); W2 and W3
   only at year level with the corroboration rule.
5. The MMSI-series reader (§6c, last part) is exploratory and not built as a check; promote it only if the 7 unverifiable candidates matter. The 2016-06 sweep. §6b's hiatus list is superseded by the split candidates.
