# 009 — An independent audit of the mid→vid match, from every witness that does not read the key

**status:** restructured 2026-09-29 after phases 1 and the witnesses were built — phase 1 done,
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
5. **Names are not evidence.** vid and MMSI are the identifiers (maintainer); vessel names
   changed and were reused and are used nowhere as a witness.

## 2. Phase 1 — witnesses, ledger, reader (DONE, built as checks)

`R/audit_witnesses.R`, `R/audit_split_reader.R`; `curate/checks/ais_key_audit.R` (ledger +
discrepancy register) and `curate/checks/ais_key_split_candidates.R`; both wired into
`_targets.R`; run end to end in full. Calibration and results: decision 047.

## 3. Phase 2 — resolve the discrepancies (next; the bulk of the value)

Inputs: the 132 discrepancy rows, the split candidates the ODS did not make (19 strong, 88
review), the ODS rows left open-ended after a vessel changed (mids 101084, 103251, and the
swap of mids 101197/102497), and the rows the ODS flags "needs checking" (112543, 118584).
For each, in this order and stopping when the answer is clear:

1. the decision-045 track-correlation test (the mid's pings against each candidate vid's own
   other-provider track — the strongest identity evidence there is);
2. the vessel registry's dates for the candidate vids;
3. logbook and landings by month over the disputed span.

A resolved case becomes a row in `overrides/` (`proposed` → maintainer-reviewed). Nothing is
entered by an algorithm alone (`AGENTS.md`: the loop is broken by a human). Resolution
rule (assumed): W1/track correlation clear on both eras, or two independent witnesses agree.
*First pass built 2026-09-29: `curate/checks/ais_key_resolution.R` derives the eras and the WHEN/WHICH for each discrepancy mid from the physical witness (30 proposals on 25 mids; 48 mids unreachable by it); track correlation and the review itself are still to do.*
**Check:** every discrepancy row is `resolved` (with the override or a reason it stays) or
`open: needs maintainer`.

## 4. Phase 3 — reach the 884 rows no witness reaches

- **Usage-class plausibility**: a mid whose track behaves as a trawler while the register
  calls the vid a passenger vessel (or the reverse) — `mclass`, and Hreidar's `Notkunarteg`
  by year, which also catches class changes over a hull's life.
- **Hreidar against the logbook and landings** (the maintainer's original suggestion): a vid
  in the logbook or landings in a year Hreidar says it did not exist, or after its recorded
  fate. Hreidar shares the registry's lifetimes (decision 046), so this finds registry-side
  and logbook-side errors, not the STK ones.
- **The 2016-06 bulk re-issue** of ~1,800 mids, as a unit.
- **Time base across sources**: nearest-in-time offsets among confirmed pairs, never inspected.
- What still cannot be reached is **stated**, not left implied.
**Check:** the 884 are re-counted; each remaining row carries why nothing reaches it.

## 5. Phase 4 — widen

- The MMSI-series reader as a check (exploratory result: it confirms the mid side's two
  discrepancies and finds none of its own; 7 candidate silences have no STK witness).
- Foreign vessels (3700–4999): a bonus, after the Icelandic work; the keel rule does not hold
  there, so a vid is not one hull and the reader needs a different unit.
- The registry's own MMSI→vid errors, tested independently of W1 (W1 trusts that map).

## 6. Phase 5 — feed back

Decide, after phase 2 has answers: what `ais_key.R` itself should change (a time-aware
identity split instead of one vid per period row — plan 003's open steps), how the ODS is
kept or retired (measured: it is the only evidence for 392 of its 508 rows; it is a raw
input and is never destroyed), and whether the ledger becomes the release's audit table.
**needs: maintainer.**

## 7. What could still make this wrong

- W1 confirms mid ↔ MMSI; MMSI ↔ vid is the registry's word (21 reused MMSIs are handled by
  windows). A wrong registry MMSI corrupts the witness, not the key.
- W2/W3 calibration used W1-confirmed pairs, so it is in-sample for the 2013→ window and
  untested for 2007–2012, where the audit is weakest.
- The split reader is blind to 14 of the 41 W1-verified changes: a lower bound.
