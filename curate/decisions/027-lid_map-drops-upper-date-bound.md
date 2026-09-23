# `link_lid_map.R` drops its hardcoded upper date bound

*Decided and implemented 2026-09-23. Closes TODO.md item 2.*

## What was wrong

`land <- ... |> filter(vid > 0, date >= ymd("2007-09-01"), date <= ymd("2025-12-12")) |> ...`
in `curate/link_lid_map.R` silently excluded every landing after
2025-12-12 from the landings-to-trip matching cascade. `trip` (the logbook
side of the same join, a few lines below) has no upper bound at all and
never has.

`git blame` traces the `2025-12-12` literal to commit `bde740b`
("Migrate code from both archives under the new naming scheme") - it was
carried over verbatim during the restructuring, never revisited, and no
comment explains it. That, plus the asymmetry with the unbounded `trip`
side, is the signature of a stale "today" snapshot from whenever the old
script was last run, not a deliberate business boundary - unlike
`FS_DATE_MAX` (decision 023), which is a real, reasoned handover date.

It went unnoticed because `adb`'s three-tier merge into `logbook` only
started producing real 2026 stations on 2026-09-23 (decision 023) - before
that, nothing in `trip.parquet` had a 2026 date to lose.

## Measured, both before and after

| | adb (2026) trips in `trip.parquet` | reaching `lid_map` |
|---|---|---|
| before | 4,962 | 0 |
| after | 4,962 | 994 |

All 994 that reach `lid_map` are matched to a landing
(`.tid_land` non-`NA`) - the remaining ~4,000 fail the cascade's
unambiguous-match requirement for other reasons, same as any other
schema; not something this fix touches.

## The fix

One line: drop the upper bound entirely, matching `trip`'s own (always
unbounded) filter.

```r
filter(vid > 0, date >= ymd("2007-09-01")) |>
```

## Not yet checked

Whether recent landings near the current date are provisional or still
being revised - a legitimate fisheries-reporting-lag reason a deliberate
lag *could* exist - was not verified either way before this change. Nothing
in the code or its history suggested that was why `2025-12-12` was chosen,
but flagging it here rather than treating the absence of evidence as
evidence of absence.
