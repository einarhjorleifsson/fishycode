# 009 — An independent audit of the mid→vid match, from every witness that does not read the key

**status:** restructured twice, 2026-09-29 — phase 1 (witnesses, ledger, reader, resolution first pass, coverage check) done and built; the product is now a **segment table** that tiles every mid, phases 2–5 open · **see:** `TODO.md` item 25; decisions 046, 047; plans `003`, `008`
phase 2 first pass built (`ais_key_resolution`), phases 2 (review), 3–5 open · **see:** `TODO.md` item 25; decisions 046, 047; plans `003`, `008`

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

## 6. Phase 5 — replace the ODS, in stages (decided 2026-09-29, maintainer)

The ODS (`raw/ais/stk/stk_mobile_match-and-duals.ods`, 508 rows) is given up as an **input**, and kept
as a raw file, never destroyed, and as a **test set**.
1. Build the segment table (phase 2) and run it **beside** the current key. Nothing reads it yet.
2. Score it against the ODS row by row: reproduces / differs / unreachable. The ODS's 44 splits on
   key-claimed mids are the first test (the reader recovers 42 with ≥ 2 families, 32 with ≥ 3); the
   360 single-vid manual rows are unmeasured and are measured next.
3. Every ODS row the table **differs** on is decided by a person (phase 3). Every row it **cannot
   reach** (392 of 508 have no physical witness) is listed with what the table assigned instead and
   on what evidence, so no human judgement is dropped unseen.
4. Only when the table reproduces every reviewed ODS row it can reach, every difference has a
   reviewed answer and acceptance tests (a)-(d) pass, does `ais_key.R` stop reading the ODS and read
   the segment table. Until then the ODS stays an input.
**needs: maintainer** — the reviewed answers, and the moment of the switch.

## 7. What could still make this wrong

- W1 confirms mid ↔ MMSI; MMSI ↔ vid is the registry's word (21 reused MMSIs are handled by
  windows). A wrong registry MMSI corrupts the witness, not the key.
- W2/W3 calibration used W1-confirmed pairs, so it is in-sample for the 2013→ window and
  untested for 2007–2012, where the audit is weakest.
- The split reader is blind to 14 of the 41 W1-verified changes: a lower bound.
