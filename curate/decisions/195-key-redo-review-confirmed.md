# 195 — The STK key redo's review lists confirmed, case by case in the vessel overview; the hull start and the MMSI gap chosen; TODO 82 folded into TODO 25

*2026-10-23. The maintainer's verdicts on TODO 25's review lists 1-5, put to the maintainer by Claude (AI) in a status
review of the repository, after a side session refreshed the drafts of 2026-10-17 on today's data (read-only,
`$FISHYDATA/archive/2026-10-23-key-redo-refresh/`). Every case the maintainer judged was first opened by Claude in the
vessel overview (plan 030), the proposed vessel and today's, and what the tracks, trips and landings showed was put
beside the drafted witnesses. Nothing was built and the key is unchanged: the verdicts act at the redo.*

## The mechanism

- **Approved before the cases:** a "no vessel" form in `overrides/ais_key_segments_reviewed.csv`; a reviewed row that
  brings its mid into the segment table's scope, and a report of a reviewed row that changes nothing.
- **The hull start (variant a1):** a hull starts at its earliest `vessel_hist` date, not the latest row's
  initial-registration date, which for a re-registered hull is the re-registration. On the refresh it clears 20 of list
  2's 32 fills outside a neighbour's lifetime (32,724 of their 34,514 pings) and relabels 6,500 pings on 13 units in
  all; a2 (or 1 January of `yh1`) relabels 22,226, a3 (the rebuilt register's first date) clears only 13 and meets
  start-of-system dates.
- **The MMSI gap (TODO 82):** a later holder's window opens no earlier than its first register date, and the previous
  holder keeps the gap (decision 128's rule). On the refresh no STK ping and no list 4 verdict moves; only MMSI
  251764110's 87,372 astdB and EMODnet pings of 2017-02 to 2018-01 go from 7873 to 2608, the sold hull they are.
  TODO 82 is folded into TODO 25 with its check.

## The verdicts (`verdicts_2026-10-23.csv` in the refresh folder)

| outcome | cases |
|---|---|
| confirmed, a reviewed row written | 18: mids 100112, 100161, 100881, 101081, 101083, 101115, 101126, 101174, 101358, 102182, 103280, 103742, 103752, 109102, 130145, 133483, 143852, 145250 |
| the hull-start rule gives the proposed vid itself, no row | 23 (confirmed as a class; the ten resting on continuity or weak were opened in the overview first, and all held) |
| settled by today's table, `leave` | 5 |
| no vessel, waiting for the form | 3: mids 101776 (Gothenburg 2011: neither the call sign's holder of 2007-09 nor the hull it carries today fits), 147514 and 147796 (units abroad whose broadcast id was read as a scrapped Icelandic hull's number) |
| a device aboard, waiting for the form | 1: mid 124288, which follows the coast-guard ships 1421 and then 3011, each in part |

The 'leave' rows of lists 1-5 (629 of 686 today) were confirmed as a class.

The overview changed the reading of three cases and stood behind every confirmed one:
- **101776:** the call sign alone proposed 1576, but the hull it carries today, 1512, has a landing record a month
  before the unit appears in Gothenburg. Neither fits, so: no vessel.
- **124288:** the partial fit to two coast-guard ships at once is a device carried aboard.
- **100881:** today's vid is a ferry that holds the call sign only from 2014. The single ping of 2009 can only be the
  call sign's holder of that year.

The check also found two positions the cleaning filter kept, now in TODO 88: vid 2654 at 8.55N 180W
(2013-09-13), and vid 7438 at 64.2333N 22.4W with speed and heading 0 (2009-07-09).

## Written

18 rows appended to `overrides/ais_key_segments_reviewed.csv`, `reviewed_date` 2026-10-23, each reason the refreshed
draft's with the confirmation noted. Two sit beside reviewed rows of decision 056, on the days just before them
(mids 101083 and 109102), and contradict neither. Open ends of the stretch keep the file's 2028-12-24, as its other
rows and the segment code do.

## Left (TODO 25)

The redo's code (the forms, the scope rule, a1, the MMSI patch, the register's matrix parse in data, the readers on
tables), vessel rows for 7845, 2953 and 7855, then the maintainer's go for the build and a decision record of the redo.
