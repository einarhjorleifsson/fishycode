# 092 — The towing stretches, their pairing with the declared tows, and the windowed speed, in ramb

*2026-10-14. Built by Claude (AI-assisted) on the maintainer's request (TODO 59). The design and its numbers are
decision 090 and plan 013 phase 4 ("Measured", items 1-2). ramb 2026.10.14.4 (b33aa31), committed and installed,
and pushed with 2026.10.14 to .14.3 on the maintainer's request the same day. Nothing in fishycode calls the new functions yet, and nothing under `curated/` was rebuilt. Closes
TODO 59.*

## What ramb now has

- `rb_calc_speed_smooth(speed, time, window_s = 600)`: the median speed within ±`window_s` of each position. A
  position without a speed gets NA and is not counted.
- `rb_assign_fishing(..., window_s = 0)`: the same median, in DuckDB. **The default 0 keeps each fix's own speed**,
  so a ramb install does not change the next trail build. The ±10 min of decision 090 is set by the caller.
- `rb_cut_record_stretches(pings, records = NULL, ...)`: runs of fixes at sea whose windowed speed is in the fix's
  speed range. A run breaks at a gap over 30 min, and runs under 15 min are dropped. With the declared tows as a
  prior, a stretch holding two tows is cut at the slowest fix between them. The speed range is a column on the
  pings, so the caller chooses it: the prototype used the vessel's commonest range among the month's tows.
- `rb_link_record_stretches(records, stretches, ...)`: each tow pairs with at most one stretch and each stretch
  with at most one tow. Pairs keep the order of both, and the pairing maximises the overlap with the tows widened
  by 30 min. The output names the tows whose candidates went to a neighbour (`stretch_lost`).

The cut and the pairing run in R, one vessel at a time. The pairing is solved within clusters of tows and stretches
that overlap, which gives the same optimum as one table per vessel. All of 2023 (61,464 tow operations, 82,915
stretches) takes about 6 s.

## Two departures from the prototype

1. **Ties on the widened overlap go to the tow that overlaps the stretch itself.**
   - Two short tows less than an hour apart can both cover a stretch once widened by 30 min. The prototype then
     chose by the order in which it filled its table.
   - On 2023 this re-chose 627 pairings. No vessel's total overlap or number of pairs changed.
   - For those 627 tows, the start within 15 min rose from 7.5 to 51.4 %, the end from 28.2 to 51.0 %.
   - On a full tie (the same times), the lower `(.sid, schema)` keeps the stretch, as in decision 091.
2. **Twin records count once in the prior.**
   - The prototype collapsed twins before it ran. Fed both records, the prior read a turn between them and cut
     the one tow in two.
   - Twins are to be resolved upstream (TODO 58, maintainer, 2026-10-14). This only keeps the function sane until
     then, and for other countries' data.

## The check (TODO 59)

On the prototype's own input: June 2023, 4,237 tow operations, twins collapsed, fixes from the current trail.

| run | paired | start within 15 / 30 min | end within 15 / 30 min | against the prototype, per tow |
|---|---|---|---|---|
| ±10 min, cut at the declared tows (`q2_best.rds`) | 99.0 % | 54.4 / 76.8 % | 51.1 / 66.1 % | all 4,237 the same |
| the same, joining stretches under 10 min apart (`q2all.R`) | 99.0 % | 53.9 / 77.9 % | 51.1 / 66.7 % | 4,236 the same, 1 tie |
| own speed, no prior (`q2all.R`) | 97.4 % | 43.5 / 59.7 % | 41.0 / 52.3 % | 4,236 the same, 1 tie |

These are the numbers in decision 090, to the decimal. The prototype's own runs disagreed on one tie: `q2b.R` and
`q2all.R` broke ties differently. `q2_best.rds` matches the tie-break above.

**All of 2023** (61,464 operations, the vessel-month speed range as in `q2all.R`): 96.5 % paired, start within
15 / 30 min for 52.7 / 74.2 %, end for 52.3 / 68.2 %. No stretch is paired twice, and no two stretches overlap.
Against `q2all.R`, 60,785 tows are the same.
- Without the tie-break, 87 differed: 72 in the first or last days of a month, where the prototype ran each month
  on its own, and 15 ties.
- With it, 679 differ, 627 of them re-chosen ties.

**ramb:** 366 tests pass with `devtools::test()`. On the package installed from a clean `git archive`, 365 pass and
one older test is skipped. New fixtures:
- the windowed speed against a brute-force median, in any row order;
- a spike inside a tow made fishing by `window_s`;
- a turn smoothed into one stretch and cut by the prior;
- gaps, the shortest stretch dropped, joining;
- twins;
- the tie-break;
- empty inputs.

Each compares a data frame with a lazy table.

The scripts and logs are in `$FISHYDATA/archive/2026-10-todo59/`.

## Not done here

- Using them in fishycode (TODO 61): a pairing table, the trail's `fishing` at ±10 min, and the speed range per
  ping. This needs a rebuild, and so the maintainer's go.
- Danish seine (SDN) and pelagic trawl (OTM) need a phase model, and dredges (DRB) a stretch that holds several
  tows (decision 090).
- Whether the declared or the track's boundary is right needs ground truth (TODO 60).
