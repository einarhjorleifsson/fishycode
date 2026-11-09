# 312 — TODO 174 closed: afli_sent's overlap labels follow a written tie-break

*2026-11-09. TODO 174, at the maintainer's word (the items taken before decision 310's rebuild). Done and written by
Claude (AI); no person has checked it. Study: `$FISHYDATA/archive/2026-11-09-afli-sent-ties/`.*

## Why

Plan 054's live rebuild (decision 265) found that `sources/afli_sent/convert.R` labels overlapping stations
differently in two builds: `osfd::fd_flag_time_overlaps()` sorts by vessel and start only, and keeps the order it is
given for ties, which the query before it did not fix.

## What was chosen

A vessel's stations that start at the same time are ordered by their end, then by `.sid` (unique per row) before the
labels are made. Built twice on scratch stores, all seven staged files are equal row for row. Against the live store,
3,173 stations change label: 3,162 swap between "start time overlaps previous" and "end time overlaps next", and 11 move
from "ok" to one of them.

## What it leaves

- `sources/afli/convert.R` makes the same labels after the same kind of sort; no difference between builds has been
  seen there, and it is left as it is.
- `afli_sent` is one target of seven files, so the change rebuilds the logbook chain (15 targets beyond decision 310's)
  with that rebuild.
