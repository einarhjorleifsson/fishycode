# 005 — Harbour geometry is a frozen, reviewed input, not a computed output

*2026-09-21. Decided with the maintainer while tracing the Hellnar polygon
(`004-issue-11-seventy-extra-rows.md`). Applies to kaenugardr's Iceland/Faroe
harbour polygons and, through them, to every AIS harbour tag in this pipeline.*

## The cycle, stated exactly

STK does not deliver bare positions. `raw/ais/DUMP_stk.R:19` selects:

```r
hid = harborid, io = in_out_of_harbor
```

The vendor has **already classified** each ping as in or out of harbour, and already
named which harbour. kaenugardr's `ports-iceland-and-faroe.R` then takes exactly those
pings — `filter(!is.na(hid))`, `filter(io == "I")` — groups them by STK's `hid`, and
draws a polygon around each group. `reference/geo/shapes.R` copies the result to
`staging/aux/ports.fgb`, and `curate/ais_ping_tag.R` spatially joins pings to it to
decide which pings are in harbour.

So: **STK's harbour classification → polygon → our harbour classification.**

The polygon contributes no information that was not already in `io`. It is a lossy
re-encoding of the vendor's own per-ping judgement as a single hull, and downstream it
is treated as independent evidence about where harbours are. It is not.

## Why this is the pipeline's existing rule, not a new one

`AGENTS.md` already commits to the remedy:

> **Cycles are broken by a human, outside the DAG.** [...] A reviewed override in
> `overrides/` re-enters as an *input*, never as a computed output.

The harbour geometry is the same shape of problem as the vid-assignment cycle that rule
was written for. It simply was never recognised as one, because the two halves live in
different repositories.

## The state on disk already agrees

`ports-iceland-and-faroe.R` **cannot currently run**: its input,
`data-raw/ais/stk/stk_trail`, is not in the kaenugardr checkout (`data-raw/` holds only
`maksims/` and `marta/`). The committed `ports_iceland_faroe.gpkg` is therefore already a
frozen artifact — frozen by a missing input rather than by decision, with no version
stamp and no statement that it is frozen.

Consistent with this, `$FISHYDATA/raw/ports/ports_all.gpkg` and
`ports_iceland_faroe.gpkg` are byte-identical (md5) to kaenugardr's outputs, copied by
hand with no import step (TODO 3b).

## Decided

1. **Harbour geometry is an input.** It is not recomputed from STK on any build. Ports
   are physical infrastructure; they do not change as AIS accumulates, so re-deriving
   them from a growing trail buys nothing and re-closes the loop each time.

2. **The derivation script stays in the repo.** `ports-iceland-and-faroe.R` is kept as
   the record of how the harbour set was bootstrapped, and as the means to bootstrap it
   again if the set ever has to be rebuilt from scratch. It is marked a **one-time
   bootstrap** and excluded from the regular build — it is not deleted, and it is not run.

3. **Corrections are reviewed edits to the artifact**, recorded, in the manner of
   `overrides/` — never a re-run of the bootstrap. This is the route by which the
   Hellnar/Hellissandur/Hnífsdalur record (004) gets fixed.

4. **The artifact carries a version stamp**, and this pipeline imports it rather than
   receiving a hand copy. That closes the sync half of TODO 3b.

## What the cycle explains

The two harbours with no geometry are exactly the two STK never flagged. `ports_add`
exists because `kvoti.stadur` lists harbours that "is not in the stk data" — so a vessel
berthing at Hellissandur was, to STK, not in any harbour. The hand-written patch for that
gap is where the coordinate was copy-pasted (004). **The blind spot and the bad record
have one origin**: a harbour list inherited from the vendor, with no independent check
against a gazetteer.

This is the concrete argument for breaking the loop rather than merely freezing it. A
frozen copy of STK's harbour list is still STK's harbour list, and still cannot see
Hellissandur. Independent geometry — OSM, a gazetteer, or local knowledge — is what makes
the artifact worth freezing.

## Not done here

kaenugardr was **not modified**: the maintainer is working on source overlap in it
(TODO 3b). This record states the decision; the edits follow once that work lands.
