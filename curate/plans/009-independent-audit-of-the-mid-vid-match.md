# 009 — An independent audit of the mid→vid match, from every witness that does not read the key

**status:** partly built — phases 1–2 built (decisions 047–053; the product is a **segment table** that tiles every
mid), phase 5 done (decisions 053, 054), phase 3 in part (decisions 048–056); the rest of phase 3 and phase 4 wait for
the key redo (TODO 25) · **see:** `TODO.md` item 25; decisions 046, 047; plans `003`, `008`

*Drafted with Claude (AI-assisted); the maintainer set the scope, lifted the decision rules for
the exploration, and framed it as a bookkeeping audit first, statistics as background tests.*

**Measured** (decision 047, run 2026-09-29 against `$FISHYDATA`): a ledger of every key row
(19,234; 2,967 claim a vid) with what each witness says; the witnesses' calibration; 132
discrepancy rows; 63 mobile-ids that carry two vids in sequence, split correctly by the key for
only 20; 884 vid-claiming rows (30 %) that no witness reaches; the ODS's 60 splits all fall
inside a ping silence, and a four-family reader recovers 42 of the 44 on key-claimed mids and
proposes 107 more (19 strong).

**Assumed** — the resolution rule in phase 2 (which evidence is enough to enter an override);
that usage-class and Hreidar checks in phase 3 reach a useful part of the 884; that the MMSI
series in phase 4 hold anything the mid side did not (the one run so far found nothing new).

## 1. What the first version of this plan got wrong or did not know

The plan began as "calibrate statistical witnesses, then synthesise verdicts". Executing it
showed the work is bookkeeping first:

1. **A physical witness decides more than the statistical ones.** Other-provider AIS on the
   claimed vid's MMSI, co-located with the mid's pings, confirms at 96–100 % sensitivity and
   2 false confirms per 100,000. Logbook and landings only discriminate at year level and
   each fails in a known way (a ferry that "lands" everywhere; fixed stations in fishing
   grounds). A contradiction therefore needs a second witness or W1.
2. **The defect is mobile-ids that changed hands**, under the same identifier strings, more
   than misread identifiers. Sequences of two vids on one mid are the unit.
3. **The human's ODS splits are recoverable by rule.** Silence ≥ 180 d, then a profile shift,
   a last trip out of Icelandic waters, or a registry change; ≥ 3 of 4 families is clean.
4. **A third of the vid-claiming rows have no independent witness at all.** That is not a
   percentage to improve; it is a list to reach or to state as unreachable.
5. **The product must tile.** The maintainer's invariant: a mobile-id that has a vessel has a vessel for its full period, first ping to last, and no ping is unassigned. The key breaks it today (39,487 pings on mids with a vessel, 28,299 on negative vids; `ais_key_coverage`). That makes the unit of work a **segment of a mid's timeline**, not an era found from the months a witness happens to cover.
6. **Names are not evidence.** vid and MMSI are the identifiers (maintainer); vessel names
   changed and were reused and are used nowhere as a witness.

## 2. Phase 1 — witnesses, ledger, reader (DONE, built as checks)

`R/audit_witnesses.R`, `R/audit_split_reader.R`; `curate/checks/ais_key_audit.R` (ledger +
discrepancy register) and `curate/checks/ais_key_split_candidates.R`; both wired into
`_targets.R`; run end to end in full. Calibration and results: decision 047.

## 3. Phase 2 — build the segment table (the product)

**Segments.** Cut each mid's ping timeline at the silences of ≥ 180 days where the split reader says
the vessel may have changed (≥ 3 of 4 families: strong; exactly 2: review), so segments tile the
whole mid, first ping to last, by construction. Silences shorter than that never cut.

**Assigning a vid to each segment**, in this order, keeping the source and a grade:
1. W1 (the vid's own other-provider AIS co-located with the mid) where it reaches: `physical`;
2. the registry's holder of the mid's call sign or MMSI over the segment: `registry`;
3. logbook and landings by month, at year level, corroborated: `witnessed`;
4. otherwise **continuity**: the vid the mid already has, carried across: `continuity` — never
   left empty, and always the weakest grade. Stretches in STK's start-up years (< 2009) are
   flagged; a mid's earliest pings may predate a stable identity.

**Devices** (net relays, beacons, gear carried between vessels): a mid that is not a vessel gets no
vid, and the invariant does not apply to it; a mid that alternates between vessels is read by hand.

**Acceptance tests, all mandatory:** (a) `ais_key_coverage` reports 0 unassigned pings and no
overlap; (b) wherever W1 reaches, the segment's vid is W1's; (c) every reviewed ODS row the table can
reach is reproduced; (d) a dry run against a copy of the key conserves every mid's pings. A table
that fails any of them is not entered.

*Built 2026-09-29: `curate/checks/ais_key_segments.R`; the four acceptance tests are asserted or reported there. Result: tiles all 2,879 mids, 0 unassigned pings except 16,902 on an explicit drop; 64.2 % of pings have direct evidence and 35.8 % are carried by continuity; 50 segments differ from the key. The logbook-and-landings step (3 above) is not yet in it.*

## 4. Phase 3 — review

Each disagreement between the segment table and the current key (and between the table and an ODS
row) goes to a person in the review app: the timeline strip, overlap, speed profile, map and track
correlation by year, with the decision recorded per segment. Nothing enters `overrides/` or the key
until a person has decided; the app already exists for the 30 first-pass proposals.
**Check:** every disagreement is `decided` (with the row that enters) or `open: needs maintainer`.

## 5. Phase 4 — reach and widen

- Usage-class plausibility; Hreidar against the logbook and landings; the 2016-06 bulk re-issue;
  time base across sources — for the segments graded `continuity`, which no witness reaches.
- The MMSI-series reader as a check; foreign vessels (3700–4999), where a vid is not one hull.
- The registry's own MMSI-to-vid errors, tested independently of W1.
**Check:** the `continuity` segments are re-counted in pings, each with why nothing reaches it.

## 6. Phase 5 — the ODS is retired (decided 2026-09-29, maintainer)

The ODS is **not a judge** and is not read by any of the new checks. The foreign vessels' matches it
held were extracted once, unchanged, to `overrides/stk_foreign_mid_vid.csv`. Dropping it changes no vid
in the segment table. What is left to do:
1. Review the segments that differ from the current key (63) and the ledger's discrepancies, in the
   review app, on evidence alone (phase 3).
2. ~~Switch `reference/vessels/ais_key.R` to read the segment table~~ **Done 2026-09-30** (decision 053): the cascade moved to
   `ais_key_cascade.R`, and `ais_key.R` now builds the key from the segment table.
3. ~~Retire the ODS~~ **Done 2026-09-30** (decision 054): the cascade no longer reads it; the file was moved to
   `$FISHYDATA/archive/retired_2026-09-30/` (not deleted: the maintainer decided to leave it there; nothing reads it).

## 7. What could still make this wrong

- W1 confirms mid ↔ MMSI; MMSI ↔ vid is the registry's word (21 reused MMSIs are handled by
  windows). A wrong registry MMSI corrupts the witness, not the key.
- W2/W3 calibration used W1-confirmed pairs, so it is in-sample for the 2013→ window and
  untested for 2007–2012, where the audit is weakest.
- The split reader is blind to 14 of the 41 W1-verified changes: a lower bound.
