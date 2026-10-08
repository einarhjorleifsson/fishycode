# 067 — Whacky positions are labelled by `ramb::whack_clean()`; `ais_ping_clean.R` acts on the labels

*2026-10-05; `ping_clean` rebuilt 2026-10-07 (see Open). Replaces the two-pass filter of decision 017's `ping_clean`.*

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

- **Rebuilt 2026-10-07**, first by running the script directly, in 8.8 minutes, on the `ping_tagged` on disk: `ping_clean` 540,761,076 pings, `ping_whacky` 2,887,233 (1,091,000 vmask,
  6,487 spike, 1,789,746 forward; 93 MB). Then as the `ais_ping_clean` target, after its outdated ancestors (`ais_ping_tag`, `ais_ping_union`, `vessel_ais_key`, `logbook`, `afli`,
  `shapes`) were rebuilt, one session each with `tar_make_isolated()`: `ping_clean` 540,759,352, `ping_whacky` 2,888,957. In every year 2007-2026, `ping_clean` + `ping_whacky`
  equals the `ping_tagged` pings with a `vid`.
- **Downstream rebuilt 2026-10-08**: the 14 targets still outdated, in 46 minutes, `tar_outdated()` empty afterwards and every output file newer than the run's start.
  `curated/ais/ping` 540,759,352 fixes; `trip.parquet` 1,373,419 voyages; `harbour_stay.parquet` 1,551,848 stays, its 148 `pid`s all in the current `ports.fgb` (decision 068);
  `ping_trail` and `trail` 567,562,864 rows each, no duplicate (`vid`, `time`); `check_trail_agreement` 99.59 % agree where both are set.
- **127,795 pings (emodnet, 2017) have no `vid`** and are in neither `ping_clean` nor `ping_whacky`: the batches select `vid %in% g`, which never matches NA. The former script did the same
  (and its closing count did not show it; since 2026-10-08 the closing count reconciles every year, `ping_tagged` = `ping_clean` +
  `ping_whacky` + no-vid pings, and stops if one does not). They cannot be judged against a vessel. They are 21 MMSIs, all emodnet 2017, none in `vessel_identity`: 251513000 (60,391 pings, found
  nowhere, not even in GFW; **a fixed transmitter**: one position, 21.9 W 64.2 N, standard deviation 0 over the whole year, confirmed against the MarineTraffic page the
  maintainer pointed to) and 251439000 (51,735; GFW has it as an ISL purse seiner without a vid) are 88 %; then 251999898/899 (4,838, not identified), 273398460 and 273396110
  (Russia), 601378300 (South Africa), 659420000 (Namibia), 257026770 (Norway) from GFW. 251999898 (also one fixed position near Reykjavik), 273396110 and 257110000 (fixed, Russia and Norway) are fixed too; 251439000 moves (a vessel) and is **vid 2411 HUGINN (TFQW, IMO 9211690, registry MMSI 251139000, one digit different)**: where vid 2411 has an stk ping within 2 minutes of one of its 25,992 pings
  away from Vestmannaeyjar, 5,582 of 6,217 are within 500 m (median 110 m; the next vessel 1,041 of 16,339); **Maintainer, 2026-10-07: no override** (MMSI 251439000 stays without a `vid`; its 51,735 pings are not in `ping_clean`). Not settled from positions alone: one vessel with a mistyped MMSI against two vessels fishing side by side. `rb_mmsi_category()` calls all of them
  `vessel`, so the number format does not reveal a fixed transmitter, the position does. Maintainer, 2026-10-07: `ping_clean` should not carry them.
- The 208 vessels where the recipe flags more (12,981 pings net; `whack_recipe_vid.parquet`, built on an earlier `ping_tagged`). First look, 2026-10-08: half
  have 4 extra flags or fewer, 36 have 100 or more, 78 are foreign vids. In 62 of their vessel-years the recipe flags more **and the kept track gets longer**, the
  sign it kept the bad ping and dropped the good ones; 24 of those 62 still hold a **(0, 0) position in `ping_clean`**. Vid 4896, 2014: a smooth track at 1-14 kn
  ends in a (0, 0) ping; vmask flags the 452 pings before it and keeps it (track 2,016 km under the old filter, 13,430 km now). `ping_tagged` holds 721 (0, 0)
  pings, all stk; 607 are flagged and **114 are kept in `ping_clean`** (40 vessels, 72 of them in 2010, 32 in 2014), so they are in the trail too.
  The 62, rerun one by one (the rerun matches `ping_whacky` in all 62): **24** keep a (0, 0) ping, all foreign, stk only; with the (0, 0) pings removed before
  `whack_clean()` all 24 come back to the old result (flags 5,315 → 19, old 78; kept track 397,617 → 93,521 km, old 93,416; no leg over 25 kn left). **38** have
  no (0, 0) ping and that change does nothing for them. Most differ by a few km with no leg over 25 kn kept. The rest are other defects, each let through by the
  forward scan's reset after a gap of more than 4 h: **lon copied from lat** (vid 4028 2011, `(64.159, 64.159)`); an astd ping at lon -0.001 (vid 2657 2017);
  a fast vessel whose recorded speed is 29-33 kn, so 25 kn flags real track under either filter (vid 7830 2018, 5,200 of 10,677); a 22-ping sparse track (vid
  1186 2023). **lon == lat** is a defect of its own: 8,799 stk pings, **4,540 kept in `ping_clean`**, all from 59 foreign vids in 2011-2012, at 59-76° E
  (mostly land in Russia). A near-zero lon alone is not a rule: 0° E crosses the Norwegian Sea, where real pings are.
