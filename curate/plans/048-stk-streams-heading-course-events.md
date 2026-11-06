# 048 — STK's streams into the flow: heading and course apart, a stream on every STK fix, and port events judged as events by a generic step

**status:** proposal — written 2026-10-28 at the maintainer's request; every ask answered the same day, each as
recommended (§5); what §1 calls measured, Claude measured read-only the same day, on the dump of 2026-10-16 and the
build of 2026-10-23 (decision 218); step 1 run 2026-11-06 at the maintainer's word, read-only on the build of
2026-11-02 (decision 288, `$FISHYDATA/archive/2026-11-06-plan048-step1/`): the switch as sharp on either clock, 4,549,650
of the 8,460,441 event rows leave the track, and without them the speed filter frees the own-port arrivals and more
fixes than it flags; step 2 built 2026-11-06 at the maintainer's word (decision 289, ramb 2026.11.06, committed to its
local `main` and installed, not pushed; `$FISHYDATA/archive/2026-11-06-plan048-step2/`): `rb_flag_port_event()` trusts
108,339 of STK's events of 2008, 2016 and 2024 that today's tags do not and sets aside 3,089 they trust, and the unit
test leaves what the track has judged; step 3 run in scratch the same day (decision 290; the code on branch
`plan048-step3`, not merged; `$FISHYDATA/archive/2026-11-06-plan048-step3/`): with the good events only, port calls
lose 19,241 and gain 26,488 of 1,623,775, the lost ones those that stood on STK's event rows used as pings; steps
3-5 revised the same day at the maintainer's word (§7): the good events back as presence in the port-call rules, the
2017 cut kept for the pairs; §7.5's asks answered the same day, each as recommended; §7.4's step 3a built the same day
(ramb 2026.11.06.1, `rb_create_port_calls(presence = )`); next its 3b and 3c in scratch · **2026-10-28** · **see:** decision 233
(the streams, the heading field, the events), decision 196 (STK's I/U rows are events), decision 164 and its study,
decisions 288 (step 1), 289 (step 2) and 290 (step 3), `dump/oracle/meta/stk.yml`, TODO 88 (the whack filter), TODO 117 (decision
196's build), TODO 148

Drafted with AI assistance (Claude) on 2026-10-28; a person has not yet checked it.

The maintainer, 2026-10-27/28: "split STK's heading field into true heading and course, add the stream, take the events
as events (decision 196), and say what it means for the union, the whack filter and the rebuild"; and "port call is a
generic method. If the Icelandic port call relies on the STK - you need to provide a method in the code flow / ramb
that circumvents that exception".

## 1. What is at hand (measured 2026-10-28)

### 1.1 The field and the streams (decision 233, `stk.yml`)

- STK's trail carries three streams that no column tells apart: AIS (a position on a ten-thousandth of a minute, not on
  a hundredth), a centiminute stream (a hundredth of a minute; VMS in 2006-2010) and an ungridded stream (STK's own
  units, 20.9 M fixes in 2006-2011, a few thousand a year after). The overlay's definitions `on_ais_grid` and
  `on_centiminute_grid` give the test.
- `heading` is AIS true heading to 2010-06-09 17:40 (whole degrees, 511 when missing) and course over ground after, on
  the AIS stream; the centiminute stream's is a whole-degree course, the ungridded stream's a course in tenths. Values
  of a full turn or more are codes (991,213 rows); 0 is mostly a stationary fix's.

### 1.2 How STK reaches the flow

- `curate/ais_ping_union.R` reads `stk_trail()` straight from the dump and keeps `vid, mmsi, time, lon, lat, speed,
  heading`: no course, no stream, and **no filter on `in_out_of_harbor`**, so STK's I/U rows enter the track as pings.
- `sources/stk/convert.R` writes every row, events included, to `staging/ais/stk`; `sources/stk/event.R` makes
  `staging/ais/stk_event.parquet` from it (one row per vid, time and I/U; tags `io_pos`, `io_dup`, `io_short`, `io_ok`).

### 1.3 The events in the track

- The union holds **8,460,441 STK event rows** of 182,318,902 STK pings, and **904,187 of the 1,351,745 STK pings the
  whack filter removes (66.9 %) are event rows** (decision 164 had 66.8 % of the contradicted ones). By era and stream
  the filter keeps 81-96 % of the AIS and centiminute events to 2012 and 48-73 % of the ungridded ones from 2013 (the
  port markers).
- `stk_event` holds 4,409,698 `I` (4,250,304 inside their own port, 3,904,338 of them not at a position 10 or more
  vessels share; 3,450,350 `io_ok`) and 4,073,099 `U` (3,472,005 `io_ok`).

### 1.4 Port calls lean on the events through the ping filter

- `ramb::rb_create_port_calls()` is generic: its optional `events` are `vid, time, io` (`"I"`, `"U"`), `port_id` and
  `good`, and it makes `event_pair` port calls of the good ones.
- **The exception is fishycode's `good`**: `curate/port_call.R` sets it to `io_ok AND the event's own row is in
  ping_clean`, i.e. the event is trusted only if the whack filter kept it *as a ping*. Take the events out of the track
  and every event fails that test.
- 699,084 of the 1,631,285 port calls (42.9 %, all from 2017, `EVENT_FROM`) have `event_pair` as their strongest
  evidence; 13,510 rest on it alone.

### 1.5 Who reads heading and course

Nothing computes on them. fishycode carries them through the union, `ping_clean`, `curated/ais/ping` and the trail
(`R/trail_sql.R`), and the vessel overview shows `heading`; ramb reads a heading only in `read_mfri.R`. So the split
changes those two columns and no effort, fishing or catch value; the events' removal does change them (§4).

### 1.6 Codes in the union, by provider

Missing values are coded three ways: astdB's heading 511 (10,963,495 rows) and course of 360 or more (1,365,693);
EMODnet's heading -1 (11,476,439) and course codes (913,179); STK's 975,215; the GPS logger's 23,182. `astd` has neither
column.

### 1.7 The chain

17 targets lie downstream of `ais_ping_union` (`tar_network()`): `ais_ping_clean`, `ais_ping_tag`, `port_call`,
`ais_voyage`, `trip_voyage`, `trip_reconciled`, `voyage_gear`, `station_event`, `ais_trail`, `ais_catch` and seven
checks; `stk_event` feeds 15 of them through `port_call`. The `once` project's readers of `stk_trail()` (the key and its
checks) read no heading and are frozen; they are not rebuilt. `targets` cannot see an edit to `R/stk_trail.R` or a
script (`produces()` hashes a path).

## 2. Design

### 2.1 `stk_trail()`: the stream, true heading and course

Three columns, each a decoding of the dump as Oracle holds it (the original stays in `raw/`):

- `stream`: `"ais"`, `"centiminute"` or `"ungridded"` (ask a), by the overlay's grid definitions.
- `heading`: true heading, degrees, on the AIS stream before the switch; NA elsewhere and where the value is a code.
- `cog`: course over ground, degrees, on the AIS stream from the switch and on the other two streams throughout; NA
  where it is a code. A 0 is kept (a north course and a missing one look alike; `stk.yml` says so).

The switch is cut on the receipt time or on the position time, whichever step 1 finds the sharper (ask b). A test in
`tests/` builds a few rows in DuckDB (both sides of the switch, every stream, the codes) and needs no data.

### 2.2 The union

- STK gives `heading`, `cog` and `stream`; the other providers give `stream` NA (ask f).
- **Codes become NA for every provider**, in its own source function: astdB's 511 and 360, EMODnet's -1 and 360, STK's,
  the logger's (ask c). The source tables keep them.
- **STK's event rows leave the union**, but for decision 196's exception, an `I` whose position is inside its own port
  and at no shared marker (3,904,338 rows): that position is the vessel's, in port, and stays a fix. The union reads
  which ones from `stk_event` (a new edge in the graph); `U` rows and the rest go to `stk_event` only.

### 2.3 Port events judged as events: a generic step in ramb

`rb_flag_port_event(events, ports = NULL, pings = NULL, ...)`, a new ramb step beside `rb_flag_ping_*()`, judges any
table of recorded port events, whatever system sent them: STK's I/U, a VMS's entry and exit reports, a tracker's
geofence events, a logbook's declared departure. It adds `event_flag` (NA when no test fails) and `good`, the same rows
in the same order, and each test runs only where its input is given:

- **position** (with `ports` and a position): an arrival outside its own port, or inside another;
- **sequence**: an arrival after an arrival, a departure after a departure (`io_dup` today); an arrival and a
  departure at one port within seconds (`io_short`);
- **track** (with `pings`, the cleaned track): the vessel's fixes around the event's time lie far from the event's
  port, beyond what its speed allows. This replaces "kept by the ping filter" with the question that test stood for,
  asked of the event itself; with no fix near the event in time the test is not judged (NA, never a pass);
- **unit** (optional grouping column): a sending unit's events in a year are contradicted by the track or by sequence
  so often that none of them is trusted (decision 196's per-unit screen; §4.6 of decision 164's study found units
  with 20 or more isolated jumps holding 96-98 % of the flagged jumps). The threshold is measured on fishydata
  (step 2), and the default comes from the data.

`rb_create_port_calls()` is unchanged: it takes `good`. Its `io` codes stay `"I"`/`"U"` unless the maintainer wants
names (ask e). The step is checked on fishydata and on CNR's tracker log with its geofence events
(`raw/external/cnr/zenodo_5783920`, decision 148), so it is not fitted to STK.

In fishycode, `sources/stk/event.R` becomes STK's adapter only: one row per vid, time and I/U, the STK code turned into
a pid, the doubled `U` collapsed, a marker position flagged (its time kept, its position not used by the position
test). Its own tests move to the ramb step, which runs in the flow, in `curate/port_call.R`, after the cleaned track
exists. `EVENT_FROM` goes (decision 196), so the events of 2007-2016 count where they pass.

### 2.4 The whack filter

Its method does not change here. Its input does: the event rows that leave the union (about 4.6 M of the 8.46 M,
all but the `I` kept as fixes; the two counts are of rows and of collapsed events, so step 1 counts it exactly) are no
longer judged, and the fixes around them are judged without them. The `stream` column lets TODO 88 judge each STK
stream as its own chain, one of its candidates; step 1 measures how many whacks fall at a switch between streams once
the events are gone (decision 233: 6.9-17.2 % of STK's AIS-stream pings after another STK stream are whacked,
0.09-6.4 % of STK's pings after their own).

### 2.5 Products and docs

The vessel overview shows `cog` and `stream` beside `heading`. `products/user_tables.R` and the effort map's
`grid.R` (both modes) are rerun after the rebuild. `docs/on_ais.qmd` (the harmonised columns) and `docs/grammar.qmd`
(the trail's columns) say what `heading`, `cog` and `stream` hold. `AGENTS.md`'s paragraph on the data on disk is
brought up to date.

## 3. Steps

1. **Measure in scratch** (read-only on the store, a scratch `$FISHYDATA` for any write): the switch on `recdate` and
   on `posdate`, counting the fixes each puts on the wrong side; the union with and without the events, and the whack
   filter rerun on 2008, 2016 and 2024: pings in and out by provider and stream, whacks by stage, whacks at a stream
   switch; the codes per provider. An account in a decision. **Done 2026-11-06** (decision 288): it also found that the
   stream is already on every ping since plan 059 (`ping_stream_sql()`, named `stk_ais`, `stk_vms`, `stk_unit`,
   `stk_event`), its event label taken from time and position alone (6,091 rows equal to a fix, 310 with no event of
   the vessel), so step 3 takes the event from the dump row's own `in_out_of_harbor`; and that STK's 511 lies on every
   stream before the switch, so a code is NA on every stream.
2. **ramb**: `rb_flag_port_event()` with its tests, contract checks and messages (plan 013's registry); on fishydata's
   events and the cleaned track of 2008, 2016 and 2024, then on CNR's log; its unit threshold from the data. A version
   and its decision. **Done 2026-11-06** (decision 289, ramb 2026.11.06): `radius_m` 2 km and `kn_max` 25 from the data;
   the unit test at 70 % of 20 or more, and, departing from §2.3's "none of them is trusted", only for events the track
   has not judged (as written it set aside 13,506 events the track confirms). For step 3: a repeat breaks the adjacent
   pair `rb_create_port_calls()` makes even when the earlier event is months old, so it may pass only the good events.
3. **fishycode in scratch**: `stk_trail()` (§2.1) and its test, the union (§2.2), `event.R` as an adapter, and
   `port_call.R` calling the ramb step; port calls by rule and evidence against today's, each lost or gained call
   in one outcome (the 13,510 that rest on events alone first). **Run 2026-11-06** (decision 290; the code on branch
   `plan048-step3`): every year on a scratch store; the tag pass year by year (`TAG_YEARS`) for the disk. With the good
   events only (`STAY_EVENTS`), 19,241 of 1,623,775 calls lost and 26,488 new; every lost and new call in one outcome.
   Today 5,951 calls rest on events alone (13,510 on the build of 2026-10-23): 4,035 the same, 1,294 changed, 621 lost.
   The good events only chosen by the maintainer the same day (the branch's default since e8006d6). **Steps 3-5
   revised the same day: §7.**
4. **Rebuild**: fingerprints of the 19 targets (`R/fingerprint.R`) taken first; `stk`, `stk_event` and
   `ais_ping_union` invalidated by hand; `tar_make_isolated()`; no tracked edit while it runs; `tar_outdated()`
   empty after; fingerprints compared.
5. **Products, docs and the record**: §2.5; `stk.yml`; a decision with the account; this plan's header, its index row
   and TODO 148.

## 4. Checks

- Every STK row of the trail in one outcome: a fix in the union, an `I` kept as a fix, an event only, or no vid; the
  sum is the trail's.
- No `heading` or `cog` of a full turn or more, or below 0, in the union; `heading` on STK only on the AIS stream
  before the switch.
- Whacks by provider, stream and stage, before and after; the 904,187 event whacks gone, and the rest explained.
- Port calls by rule and evidence, before and after, every difference counted (decision 155's method).
- Voyages, trail fixes, effort hours and kilograms on fixes before and after; the allocation audit's outcomes; kg in =
  kg out.
- ramb's step: its own tests, and its flags on fishydata against today's `io_ok`, every disagreement counted.

## 5. Asks, answered

All answered by the maintainer on 2026-10-28, each as recommended ("go with recommendation").

- **a. The stream's values:** `"ais"`, `"centiminute"`, `"ungridded"`, what the data show. The docs say what each fits
  (AIS; VMS in 2006-2010; STK's own shore units). Not chosen: `"ais"`, `"vms"`, `"stk_unit"`.
- **b. Where the switch is cut:** on `recdate` or `posdate`, whichever step 1 finds the sharper. Step 1 records which.
  Step 1 (decision 288): equally sharp, the same rows on the wrong side at every second; Claude's tie-break is
  `posdate`, which the union carries, true heading before 2010-06-09 17:40:13.
- **c. Codes:** NA in the union for every provider (STK's 511 and 360.0, astdB's 511 and course of 360 or more,
  EMODnet's -1). The source tables keep them.
- **d. Decision 196:** read as written here: an `I` inside its own port and at no shared marker stays a fix (3.90 M
  rows); every other event row leaves the union.
- **e. Names:** the step is `rb_flag_port_event()`, its column `event_flag`. `io` stays `"I"`/`"U"` in this plan;
  `"arrival"`/`"departure"` is not chosen. The final names still go through the review of TODO 127.
- **f. Other providers' stream:** later. They get `stream` NA here; astdB's `dsrc` (ground or satellite reception) is
  the first candidate when it comes.
- **g. The 2009 clock episode** (2009-09-14 to 2009-10-05, AIS fixes 2.8-2.9 min ahead of their receipt): nothing in
  this plan, neither a label nor a correction, since which clock was off is not established. Decision 233 and
  `stk.yml` keep the finding.

## 7. Steps 3-5 revised (2026-11-06)

The maintainer, after step 3's run (decision 290): "I am a little bit worried that we may be going in the wrong
direction here. what is your verdict?", then "Yes, revise the plan". Written by Claude (AI); not yet checked by a
person.

### 7.1 Why

- **What stands.** Steps 1 and 2: the event rows out of the speed filter's input help it (decision 288), and events
  judged as events by `rb_flag_port_event()` beat survival as a ping (decision 289).
- **What went wrong in step 3's first design.** Today's port calls use STK's event rows as pings: the vessel's presence
  in port, above all the departure rows (decision 290: nearly every lost call had event rows that leave inside its
  span). The first design took that presence away and put back only arrival-departure pairs, a narrower kind of
  evidence. Each gap that opened became an STK patch (THH/THO departures with no pid, e10e2c3; repeats breaking pairs;
  departures coded for another port), the treadmill this plan set out to end. It also bundled a second change, the
  2017 cut dropped (decision 196), which alone adds 17,062 calls and moves about 360,000 before 2017, so the 650,000
  changed calls cannot be read. And its only yardstick was agreement with today's calls, which are no witness.
- **Measured** (decision 290 and its study): good events only, 19,241 of 1,623,775 calls lost and 26,488 new; with the
  THH/THO departure fix, 8,845 lost and 26,954 new.

### 7.2 What is kept

From the branch `plan048-step3`: `stk_trail()`'s stream, heading and course, and its test; the union without STK's
event rows but the own-port arrivals, codes NA for every provider; the stream from the union's own columns, and the
tag pass year by year (`TAG_YEARS`); `event.R` as STK's adapter (`mid`, `marker`, `pid_basis`, the THH/THO departure
taking its arrival's pid); `port_call.R` judging the events with `rb_flag_port_event()`, the good ones only.

### 7.3 The change: good events as presence

The good events go back into the port-call rules as presence: a judged event says the vessel was there at that time,
as the event rows did as pings, but only where `rb_flag_port_event()` passes it, never because the speed filter kept
it. Port calls then hang neither on the speed filter (§2.3's aim) nor on pairs alone, and should move only where an
event is judged bad or the cleaned track frees pings. Done generically, in ramb:
`rb_create_port_calls(events = , presence = TRUE)` takes the good events' times and positions into the dwell rules
beside the pings, and their pairs as before. The 2017 cut stays for the pairs (`EVENT_FROM`); presence counts in
every year, as the rows did.

### 7.4 Steps 3-5, revised

3. **Port calls with presence, in scratch.** (a) ramb: `presence = ` on `rb_create_port_calls()`, its tests, a
   version, at the maintainer's word. **Done 2026-11-06** ("Yes, build it"): ramb 2026.11.06.1 (1f720f6, local `main`,
   not installed or pushed), 16 expectations of its own, the whole suite passing (3,058). (b) fishycode on the branch: `port_call.R` passes it, `EVENT_FROM` back at 2017
   for the pairs. (c) On the scratch store, port calls only (the track is step 3's): every lost, new and changed call
   against today's in one outcome; the trips' AIS ends against the logbook's own dates where calls change (plan 069's
   witness); a hand check of what neither settles.
4. **Rebuild** as before, once the branch is merged at the maintainer's word and the scratch store deleted.
5. **Products, docs and the record** as before.
6. **Event pairs before 2017** (decision 196), after the rebuild, as a step of its own, measured against the logbook's
   own dates.

### 7.5 Asks, answered

All answered by the maintainer on 2026-11-06, each as recommended ("Yes, as recommended").

- **a. Which events give presence:** the good ones. Not chosen: every event, as the rows did unjudged.
- **b. Where an event's presence stands:** at its recorded position, a marker included, as the row stood (the dwell
  rules then find its port as they found the row's). Not chosen: at its port's polygon.
- **c. The pairs before 2017:** later, as step 6 against the logbook's dates. Not chosen: now.
- **d. The THH/THO departure fix (e10e2c3):** kept (a pair needs a departure's port). Not chosen: dropped.

## 6. Not in this plan

The whack filter's method (TODO 88); receipt time in a side table and port calls before mid-2007 from `tilk_stk`
(decision 196's other parts, TODO 117; the `tilk_stk` read, TODO 68); the AIS class; the GPS logger (decision 196); STK's foreign and unlinked units
(plan 021).
