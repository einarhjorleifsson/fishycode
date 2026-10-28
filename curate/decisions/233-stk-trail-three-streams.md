# 233 — STK's trail is three streams in one, its heading field changes meaning, and the whacks gather where the streams interleave

*2026-10-28. Found, not decided. Data tests by Claude (AI), asked step by step by the maintainer (2026-10-27/28), on the
dump of 2026-10-16 and the ping tables of the rebuild of 2026-10-23 (decision 218); the counts are Claude's and have not
been checked by a person. The column-level facts, with their checks, are in `dump/oracle/meta/stk.yml` (merged into
`raw/oracle/stk/_data-dict.yaml`; `check_data_dict()` passes on all 303,795,653 rows); the scripts were not kept.*

## The streams

No column tells a row's source: `msgtype` (0), `comsystemid` (100) and `mobile`'s `type` (0) and `comsystem` (100) are the
same on every row, and one mobile id carries several streams (4,488 mobile-id-years of 2007-2010 send gridded and
ungridded fixes). The position's grid tells them apart, and each has its own signature:

- **AIS**: a ten-thousandth of a minute, not a hundredth. Every 10 minutes (STK thins it); coastal to 2019; satellite AIS
  from 2020 (open-ocean AIS fixes 15-2,360 a year to 2019, 10,809-29,019 after).
- **Centiminute**: a hundredth of a minute. In 2006-2010 hourly, at whole minutes, whole-degree course, whole-knot speed,
  offshore: VMS. From 2013 every 10-12 minutes near the coast, heading mostly 0. 0.67 % of its 2006-2010 fixes are AIS's 511.
- **No grid**: STK's own shore-received units, 20.9 M fixes in 2006-2011, every 9.5-14.5 minutes, 99.8 % within 50 nm;
  from 2012 a few thousand offshore fixes a year, hourly.

Satellite reception of AIS lands in the AIS stream, so the far-offshore fixes before 2020 are VMS, not satellite AIS. AIS
class is in no column: 2014-2024, 48.3 % of the STK fixes with a vid are of vessel-years ASTD hears only in its Class B
feed, 45.4 % only in its main feed.

## The heading field holds two quantities

True heading on AIS fixes to 2010-06-09 17:40 (whole degrees, 511 when missing), course over ground after. The switch is
STK's, within minutes for all 308 units that sent 511. On 344,282 fixes matched to the same AIS message in astdB and
EMODnet, the STK value is the course in 18,744 of 19,735 where the message had both, the heading alone in 12. The
centiminute stream's is a whole-degree course, the ungridded stream's a course in tenths. The values over a full turn
are codes (511, 360.0, a few more); 0 is mostly a stationary fix, and stands in for a missing course in 5,293 of 20,923
matched messages.

## Port events

An `I`/`U` row is a message of its own, not a flagged fix, and comes from all three streams with their values. From 2013
the ungridded events (1.1 M) are made by STK at a port's marker (3,351 positions used by 10 or more units, speed and
heading 0), and a `U` is mostly two rows, one without its port code (none before 2013, checked on every row). `tilk_stk`
is the trail's events with the vessel number (out 1, in 2; same time and code on all 4.9 M joined rows), to 2021-02-08.

## Before mid-2007

The trail is in volume from 2007-06. Before it, positions only in `trail_deleted_rows` (2003-09 to 2003-12, 94-96 %
ungridded) and 11,515 trail rows; port events in `tilk_stk` (763,721 in 2003-2006, their trail rows gone). The exports
(`coral_stk_export`, `vms_stk_export_*`) are copies. Plan 022's appendix carries this.

## Time

No time-zone offset in `posdate` or `recdate`, in any stream or season, against each other or against ASTD at the same
position. One clock episode, 2009-09-14 to 2009-10-05: 247 thousand AIS fixes 2.8-2.9 minutes ahead of their receipt.

## Whacks by stream

Impossible jumps (`vmask`, `spike`, `forward`) in 2008, 2009, 2016, 2021 and 2024: ASTD 0.01-0.55 %; STK's AIS stream
0.23-1.24 %, centiminute 1.0-2.6 %, ungridded 1.3-2.5 % to 2009 and 14-45 % from 2016 (from 2013 most ungridded rows
are port-marker events). An STK ping whose vessel's previous ping is from another STK stream is whacked 6.9-17.2 % (AIS),
1.1-18.3 % (centiminute) and 9.5-47.5 % (ungridded); after a ping of its own stream 0.09-6.4 %; an AIS-stream ping after
ASTD 0.01-0.57 %. The switches between STK's streams hold about half of STK's whacks in 2008 (4.8 % of its pings), 14 % in
2016 and 26 % in 2024; most of the rest are within one stream, or after ASTD.

## What it leaves

Nothing is changed: `stk_trail()` and the trail carry one `heading`, both quantities and the codes, and no stream. The
maintainer asked for a plan (2026-10-27): the field split into true heading and course with a stream column, the events
taken as events (decision 196). For the whack filter (TODO 88), a stream is a candidate for its "chains that are each
consistent".
