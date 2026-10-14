# 098 — The afli hauls the stofn merge dropped are not admitted

*2026-10-14. Measured by Claude (AI-assisted) on the maintainer's request; the decision rule was agreed before the
run, and the close is the maintainer's. Closes TODO 19 (parked since 2026-09-23). The defect is declared in
`curate/corrections/afli_rafr_stofn_stations_dropped.yml`, which this amends.*

## The question, and the rule fixed before the run

23,570 live electronic afli submissions (2003-2019) never reached `stofn`, the source system's merged table, and
so are absent from the logbook. In September the reading swung three times on why the merge dropped them. This
asked instead whether they are true, of two witnesses that never read the merge.

- **Admit** if adding them brings most of their trips nearer the landing, and their positions agree with the AIS
  track at about the rate of merged hauls.
- **Close as working-as-designed** if they overshoot the landing or disagree with the track.
- The rows before 2007-06 have no witness and stay out either way.

## The landings: the trips are complete without them

A lost haul's trip is found with the adapter's own trip key: vessel, landing date and landing harbour. 20,201 lost
hauls sit on a trip that holds kept hauls; 3,369 are on trips lost whole. Trips of 2007-09 to 2019 with one
landing:

| trips | n | logbook / landed |
|---|---|---|
| no lost haul (control) | 560,513 | 0.984 |
| lost hauls carrying catch, kept hauls only | 3,142 | **0.987** |
| the same, lost hauls added | 3,142 | **1.772** |

- Adding the lost hauls brings 19.3 % of these trips nearer the landing, and takes 59.7 % more than 30 % over it.
  Only 3.9 % fall more than 30 % short without them.
- The gap the lost catch would fill is nothing: (landed − kept) / lost has a median of 0.02.
- The more of a trip was lost, the worse adding it fits: trips with 30 % or more of their hauls lost go from 0.974
  to 1.889.
- It holds in every period: 2007-2010, 2011-2014 and 2015-2019 all match their landings without the lost hauls.
- **Trips lost whole** (1,288 trips, 2007-09 to 2019): 83.4 % have a landing of that vessel within 2 days, against
  99.5 % for kept trips. Only 31.9 % have one that no logbook trip took. The other landings are already a kept
  trip's.

## What they are: mostly the same hauls submitted again

- Of lost hauls with catch, 30.1 % have a catch-identical kept haul (every species and weight) of the same vessel
  within 3 days, against 10.0 % for kept hauls. In 2011-2017 it is 31-68 %. Of the nearest such copies, 3,522 of
  3,535 are in another submission, and 3,443 are on the same day.
- So the copy is a separate submission. September's test looked for twins within one submission, where only 14
  exist, and so missed them.
- In 2004-2010 almost no lost haul has an exact or a same-position copy (0-1 % and 0.4-11.5 %). The landings still
  show those trips complete (2007-2010: 1.022 kept only, 1.042 with the lost added, nearer in 1.9 %). How they
  repeat the kept hauls (an edited copy, a haul merged into another) is not shown.

## The track agrees, but cannot decide

The lost hauls of 2007-06 to 2019 were tested against the kept hauls of the same submissions.

- **Day test:** 91.1 % of lost hauls lie within 5 km of the vessel's track that day, against 97.2 %.
- **Tow start** (towed gear, the fix nearest the recorded start): 91.9 % against 95.7 %.
- Revised rows (version ≥ 2) agree least (84.3 %).
- A copy of a real haul lies on the track as the haul does, so the track cannot tell a copy from a missing haul;
  the landings can.

## Decision

Not admitted. By the rule agreed beforehand, the lost hauls overshoot the landing. For the most part the merge
was right to leave them out. September's reading ("real hauls, complete and undeleted; the per-vessel skew is the
argument") was wrong: they are real, but repeated.

- **The warning is revised.** `docs/afli-dropped-stations.qmd` no longer tells analysts that per-vessel figures
  are wrong for 53 vessels. From 2007-09 the landings show the trips complete.
- **The check no longer flags vessels.** `curate/checks/afli_rafr_stofn_loss.R` drops its `usable` flag and keeps
  the counts of rows absent from the merge.

## Open

- **About 410 trips lost whole that do have a landing no logbook trip took.** They are the only candidates for
  genuinely missing records, and nothing here proves them. In the 219 with catch on both sides, the lost catch is
  0.87 of that landing (median).
- **Before 2007-09 no landing link reaches the rows.** That is 1,854 rows, mostly 2004-2006, where the share
  absent was highest (19 % in 2004). Whether those are copies is unknown.

Scripts and logs: `$FISHYDATA/archive/2026-10-todo19/` (`measure.R`, `copies.R`).
