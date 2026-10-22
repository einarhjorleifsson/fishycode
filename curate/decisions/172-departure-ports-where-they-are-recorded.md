# 172 — Departure ports: adb's is the app's or a placeholder, the landings hold none, and STK, the quota system and AIS record them

*2026-10-22. Found, not built. The maintainer: "dig into where adb's departure ports come from ... it is the key for
the downstream processing", expecting a trip table in the landings, with STK as an additional source for the trip
table wanted downstream. Written by Claude (AI); every number is Claude's, measured on the dumps of 2026-10-16 and
`curated/` as built, and has not been checked by a person. Scripts, logs and tables:
`$FISHYDATA/archive/2026-10-adb-departure-port/` (README). Corrects decision 171 (point 5).*

## Found

1. **adb has no departure port of its own.** Where fs_afladagbok has one (112,014 trips), adb's is the same port
   through its map. Where fs_afladagbok has none (94,467 trips, whole sources whose apps send none: `STOKKUR`,
   `TRACKWELL`, `FRA GAFLI`, `Marína raun`, `FRA TAKTIKAL`, `Fishtech raun`), adb's is **0** on every trip. adb's port
   table maps FS 124 "Skarðsstöð" to 0, so the 0 reads as a port, but it is a placeholder. From 2025-11-19, 9,807 of
   adb's 43,570 trips carry it (Marína 5,106, `FRA GAFLI - AUTO` 4,696). In `curated/logbook/trip.parquet`, 5,094 adb
   trips have `hid1` 0, and no adb trip has a `pid1` or `pid2`. The merge never maps adb's ports to `pid`. The landing
   match is not affected: it keys on `hid2`.
2. **The landings hold no trip and no departure port.** All 21,869 columns of the 28 dumped schemas were searched by
   name and comment, and the 93 tables with a vessel and two or more dates were read by structure. `ask`, `agf`, kvoti's
   `lods*` and `vor` are landing events and weighing slips. Their dates are a landing's start, closing and registration.
   The catalogue of all 112 schemas adds only small trip objects outside the dumps (`nyting.veidiferd` 1,894,
   `afladagbok.tour` 3,312, `flokkun.trip` 109). The predecessor repos read only adb's `departure_port_no`.
3. **The quota system ties landings to departures for three regimes.** These are trip records keyed by the landing
   (`hofn`, `komunr`):
   - line incentive (`kvoti.ivln_tilkynning_londun`, 172,451 landings, 2004-2020): STK and phone-line out and in
     events; a departure port on 10-15 thousand landings a year to 2013;
   - coastal fishing (`kvoti.strandveidar`, 231,015 landings, 2009-2023): STK out and in events to 2020; a port on
     7-15 thousand a year 2009-2013;
   - days-at-sea boats (`kvoti.tilkynning_sokn`, 1996-2001): phone notifications; a port only in 2000-2001.
4. **STK records departures.** `stk.tilk_stk_allt` holds 3.19 M voyages, port to port, 2003-09 to 2021-02. 1.42 M have a
   departure port. STK's out-events stop carrying the port in 2014 (1.32 M "Hafnarheiti vantar"), and 418 thousand
   voyages have no out-event. The phone records cover 2004-2014 (line incentive) and 2010-2012 (Coast Guard).
5. **AIS gives the most, and the witnesses agree to about 95 %.** For every logbook trip (twins left out):

   | logbook, years | trips | own port | STK or AIS where own is missing | none |
   |---|---:|---:|---:|---:|
   | afli, to 2003 | 809,670 | 0 | 11,559 | 798,111 |
   | afli, 2004-2007 | 213,633 | 0 | 185,070 (STK 181,977) | 28,563 |
   | afli, 2008-2020 | 607,908 | 0 | 594,675 | 13,233 |
   | afli, 2021- | 29,812 | 0 | 29,450 | 362 |
   | fs_afladagbok, 2021- | 153,778 | 110,774 | 39,117 | 3,887 |
   | adb, 2021- | 37,847 | 32,728 | 5,089 | 30 |

   Where two witnesses meet, they agree on most trips. AIS agrees with the logbook's own port on 94.7 % of
   fs_afladagbok trips (102,878 of 108,592) and 94.6 % of adb's. STK agrees with AIS on 95.2 % of afli trips
   (264,304 of 277,555).

## The departure time comes with the port

Measured the same day (`09_times.R`). Every witness that gives a departure port also gives a departure datetime:
- the logbook's own: a datetime on 152,430 of 153,795 fs_afladagbok trips and 37,602 of 37,847 adb trips. afli's T1
  is a day only, and the first fishing day rather than the departure;
- AIS: a datetime on every linked voyage;
- STK: a datetime where it has no port too. For afli trips of 2008-2020 there are 535,272 STK times against 261,287
  STK ports, because the out-events kept the time after they lost the port in 2014, until STK ends in 2021-02;
- the quota system's and the phone records' out and in events: datetimes, not yet joined to trips.

Where two witnesses meet, their times sit close:
- AIS against the logbook's own datetime: a median of 13-14 minutes; 76-77 % within 1 hour and 92-94 % within 12
  hours (fs_afladagbok 146,435 trips, adb 37,101);
- STK against AIS on afli trips (553,197): a median of 10 minutes; 73 % within 1 hour and 86 % within 12 hours. The
  14 % beyond 12 hours is likely the two cutting different voyages around the same trip, not checked;
- afli's first fishing day against the AIS departure: the same day on 83 %, AIS a day or more earlier on 16 %.

## What it means for the trip table

No source gives a full trip table with departure ports. A departure port can be put on nearly every logbook trip from
2004 by a cascade of witnesses, each with its basis:
- the logbook's own port (fs_afladagbok and the apps that send one, from 2021);
- the AIS voyage (from 2008);
- STK's recorded voyage and the quota system's trip records (2003-09 to 2013 with a port; times to 2021);
- the phone records.

Before 2003-09 there is none, but for 2000-2001 phone calls. The departure time (T1) comes with the port, so the
cascade gives a departure datetime and port together. Which witness ranks first where they disagree (about 5 % on the
port, 23-27 % beyond an hour on the time) is a design choice. It is TODO 121, beside TODO 68 (STK's voyages against
the track).

## Left open

- adb's `hid1` 0 is kept as a port in `curated/logbook/trip.parquet`. Whether to read it as missing is part of
  TODO 121.
- adb's ports carry no `pid` in the merged trip table.
- The quota system's trip records were measured by landing, not yet joined to the logbook trips through `lid_map`.
