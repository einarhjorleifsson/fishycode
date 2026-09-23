# 017 — The clean stage was reporting a quarter of its rejections

*2026-09-23. Found by gating `staging/ais/ping_clean` against `ping_tagged` after
the rebuild, and chased because `ais_trip` is not resumable and should not start on
a number that does not add up.*

## The discrepancy

`curate/ais_ping_clean.R` closed its run with:

```
kept 539,907,152 pings, dropped 2,306,257 as whacky (0.43%)
```

Against a `ping_tagged` of 543,045,030, that leaves **831,621 rows unaccounted for**.
539,907,152 + 2,306,257 = 542,213,409, which is 831,621 short.

## Where they went

Nowhere. The rows were correctly dropped; the counter never saw them.

The stage runs two filters. Pass 1, `whack_fwdbwd`, runs lazily in DuckDB and its
survivors are materialised with `filter(!whack)` into a temporary parquet. Pass 2,
`whack_forward`, runs in memory per batch of whole vessels. `dropped` was incremented
only inside the batch loop, as `n_in - nrow(clean)`, where `n_in` counts rows that
have **already survived pass 1**. Pass 1's rejections were therefore invisible to the
tally, and the closing message called the pass-2 figure the whole of "whacky".

Per-year, reconstructed from the run log's batch lines plus row counts of the two
datasets:

| | rows |
|---|---|
| `ping_tagged` in | 543,045,030 |
| dropped by pass 1 (`whack_fwdbwd`) | **831,621** |
| dropped by pass 2 (`whack_forward`) | 2,306,257 |
| `ping_clean` out | 539,907,152 |

**The true drop rate is 0.58 %, not 0.43 %.** Pass 1 is 26.5 % of all rejections and
the reported figure omitted all of it.

The split is not uniform. In 2009 and 2016, pass 1 drops are within a factor of three
of pass 2's (107,806 vs 41,750; 160,393 vs 178,553). From 2018 onward pass 1 nearly
vanishes — 8,111 in 2020 against 152,287 — which is what you would expect if the
isolated single-point spikes pass 1 catches belong to the older, sparser stk-dominated
era. Not investigated further; recorded because the shape is informative and was
previously invisible.

## A second, smaller mislabel

The per-batch progress line read:

```r
message(sprintf("  batch %d/%d: %s vessels, %s pings kept", ..., format(n_in, ...)))
```

`n_in` is the count going *into* pass 2, before `filter(!whack2)`. Every batch line
overstated what it had kept. Now prints both: pings in, and pings kept.

## What was and was not changed

The **data is correct and was not rebuilt**. Both filters did their job; only the
arithmetic reporting them was wrong. `ais_ping_clean.R` now carries `dropped1` and
`dropped2` separately and names which filter each belongs to.

Note the consequence: the script's hash has changed, so `targets` will consider
`ais_ping_clean` stale and want to re-run it — three and a half hours for a change
that alters no output. That is `targets` behaving correctly, and it is a reason to
make cosmetic edits to expensive scripts deliberately rather than in passing.

## Why this was worth stopping for

The number was not wrong in a way that mattered to any analysis — 0.43 % against
0.58 % of pings changes nothing downstream. It mattered because it was the only
end-to-end check on a stage that had just been rebuilt, and it did not reconcile. A
gate whose failure is shrugged off is not a gate. The cost of chasing it was one
query; the cost of not chasing it would have been starting the non-resumable
`ais_trip` stage while unable to explain a 831,621-row gap.
