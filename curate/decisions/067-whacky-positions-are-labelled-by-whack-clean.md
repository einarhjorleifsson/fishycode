# 067 — Whacky positions are labelled by `ramb::whack_clean()`; `ais_ping_clean.R` acts on the labels

*2026-10-05. Replaces the two-pass filter of decision 017's `ping_clean`. The script is switched; `ping_clean` is **not rebuilt yet**.*

## What changed

`curate/ais_ping_clean.R` calls `ramb::whack_clean()` (ramb `81cef38`) instead of `whack_fwdbwd` (lazy, DuckDB) then `whack_forward` (R). The function labels:
`whack` and `whack_stage` (`vmask`, `spike`, `forward`). The script acts on the labels: `staging/ais/ping_clean` is the unflagged pings, columns and layout unchanged;
**new** `staging/ais/ping_whacky` holds the flagged pings with their `whack_stage`, so a flag can be reviewed and overruled instead of the ping being lost.
The completion fingerprint now includes the method, so every year is re-cleaned on the next run (the old markers cannot match).

## The recipe

vmask (rms speed to the four nearest neighbours, peaks above 25 kn, repeated), a leg-speed spike test (both legs above 25 kn, angle at most 25 degrees), then the forward scan.
Steps 1-2 are `argosfilter::sdafilter()` (Freitas et al. 2008) re-implemented in Rcpp (`ramb::whack_sda()`, identical flags at the package's defaults) with three settings
changed for AIS: 25 kn instead of 2 m/s, every vmask removal stands (the package keeps those within 5 km of the previous ping), and a speed test instead of its 2.5/5 km
distance test (the distances are absolute; our pings are 5 s to 10 min apart). Tuned on 2012 and 2016 (32 variants), then run on all years.

## Measured, 543.6 M pings 2007-2026

| | former | `whack_clean` |
|---|---|---|
| flagged | 3,075,693 | 2,887,233 |
| speed spikes left among the unflagged | 50 | 7 |
| track length of the unflagged pings | 231 M km | 224 M km (raw 494 M km) |

Fewer flags in every year; fewer in 1,964 vessels, more in 208 (not examined). The filter takes 200 s on a data frame (2.7 M pings/s) and 290 s through DuckDB,
against about 67 s for the former two passes; the two paths flag the same pings. Scripts: `curate/checks/whack_recipe_evaluate.R`, `whack_recipe_timing.R`
(`curated/check/whack_recipe_vid.parquet`, `whack_recipe_timing.parquet`); the tuning in `sda_tune.R`, `sda_evaluate.R`. Written up in fishyweb `notes/whacky-positions.qmd`.

## Not solved (stated, not hidden)

Interleaved streams (vids 2350, 2628, 2765; two transmitters on one mobile id, decision 047): the recipe still drops most of such a burst. A bad first ping of a vessel
survives. Sparse tracks cannot be judged. Stage 1 flags good pings next to a bad one (vid 239, 18 Aug 2012: 58 of 124 good pings flagged). Row order of the input no longer
matters (ties in time are broken by lon, lat); the former filter's counts varied by a few hundred between runs for that reason.

## Open

- **Rebuild**: `tar_invalidate(ais_ping_clean)` and a `tar_make()` of the chain downstream of it (trip, harbour stay, trail) have not been run. Until they are, `ping_clean` is the
  former output and `ping_whacky` does not exist.
- The 208 vessels where the recipe flags more.
