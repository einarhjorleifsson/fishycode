# 200 — A fishing vessel's voyage with no record is undecided, not "not fishing"; whale watching and aquaculture service are classes by rule, the rest sorted by the register

*2026-10-23. The maintainer's answers to TODO 49, asked by Claude (AI) in a status review of the repository. Counted
read-only by Claude the same day on `curated/ais/voyage.parquet`, `voyage_gear.parquet` and
`curated/check/vessel_activity.parquet` (decision 103); not yet checked by a person. Nothing is built.*

## Counted (2017 on)

| vessels, by year | voyages | with no logbook trip and no landing (no gear) |
|---|---|---|
| fishing vessels (they land that year) | 509,230 | 50,329 (4.1 M voyage hours) |
| whale watching | 76,802 | all |
| aquaculture service | 52,111 | all |
| other (land nothing, no class) | 78,587 | all |

A voyage with no gear has no speed range, so today its fixes come out not fishing with no reason given.

## Chosen

- **A fishing vessel's voyage with neither a logbook trip nor a landing is undecided:** its fixes carry fishing NA with
  the reason "no record", counted apart from not fishing, as the aim's first test of done asks ("fishing, not
  fishing, or undecided, with why"). Qualifying them waits for TODO 86, the gear read from the track, with its error
  measured on trips that have a logbook. The vessel overview's display rule (the previous trip's gear, decision 143)
  stays a display rule.
- **Whale watching and aquaculture service are classes by rule,** not one override each: a vessel-year that lands
  nothing and keeps no logbook, from the maintainer's port lists of 2026-10-14, is not fishing, basis `derived`, its
  class named on its voyages.
- **"Other" (3,768 vessel-years since 2017) is sorted first by the register's usage class** (leisure by decision 119's
  rule, the register's classes of plan 028), and what is left is listed for a person.

## Left (TODO 49)

The undecided label and the two class rules in the flow (the trail's fishing columns, `voyage_gear`), built with the
AIS batch; the sorting of "other" as a check; TODO 86 for the gear from the track.
