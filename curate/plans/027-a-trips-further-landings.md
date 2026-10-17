# 027 — a trip's further landings: join them to the trip, in the flow

**status:** proposal — measured 2026-10-17 (read-only, on the build of 2026-10-16); nothing built; four asks open
(TODO 81) · **2026-10-17** · **see:** TODO 81, plan 026 §11, plan 025 §3.1 and §4 (`t_weighed`, `withdrawn`), plan
014 (preprocessing reads no AIS), decisions 075, 100 and 102, `curate/link_lid_map.R`, `curate/ais_catch.R`

Drafted with AI assistance (Claude) on 2026-10-17, from TODO 81. The numbers below were measured by Claude (AI); a
person has not yet checked them.

**Measured** (read-only): `curated/landing/`, `curated/logbook/{trip,station,catch,lid_map}.parquet`,
`curated/ais/{voyage,port_stay}.parquet`, `curated/ais/trail/` (voyage, its logbook trip `.tid_voyage`, fishing
fixes), `curated/ais/catch/` (approach `fishing_flow`) and ask's weighing times (`raw/oracle/ask/`, as plan 025 §3.1:
notes neither credit nor reversed; no column naming a person read). `ais_catch.R`'s landing-to-voyage link was
re-run in scratch, year by year, exactly as the script calls it. Scripts and output in scratch only.
**Assumed:** that the AIS track is the witness of whether a vessel fished between two landings (a voyage that AIS
missed reads as "in port"), and that a trip's logbook catch is its whole catch, 0.95-0.99 of the landed weight
(`ais_catch.R`'s header).

## 1. What happens now

- `link_lid_map.R` gives each logbook trip at most one landing, and `curated/landing` has one landing per vessel,
  date and port. A catch unloaded over two days, or at two ports, is two landings, and the trip claims one.
- `ais_catch.R` shares the catch of every landing `lid_map` leaves unclaimed. Checked on `curated/ais/catch`: in
  each of 25,317 vessel-years (2008-2026) the landing kg on the fixes equals the unclaimed landings' kg.
- So a second landing of a trip is counted beside the trip's logbook catch, which already holds it.
- **It lands on the trip's own fixes.** `ais_catch.R` passes only the unclaimed landings to
  `ramb::rb_link_trip_landings()`. Its last step, `since_previous`, gives every voyage not yet taken to the vessel's
  next landing within 14 days, so the logbook trip's voyage goes to the next unclaimed landing. 27,848 unclaimed
  landings (764 kt) are shared over fishing fixes of voyages that carry a logbook trip; 9,357 of the 9,955 below.

## 2. TODO 81's landings: the day after, at the same port

10,932 unclaimed landings (68.8 kt, from 2007-09) come the day after a claimed landing (C) of the same vessel at
the same port (`hid`). 977 have no catch. TODO 81 gave 9,878 (53.7 kt); its definition was not recorded and the
count was not reproduced. The 9,955 with catch, by what the track shows between C's arrival and the end of the
second landing's day:

| AIS between | landings | kt | logbook nearer C+U | what it is |
|---|---|---|---|---|
| in port throughout | 1,246 | 30.2 | 490 (23.0 kt) | the trip's catch; counted twice where the logbook holds it |
| went to sea, fished | 8,376 | 31.2 | 1,259 (7.3 kt) | a separate trip, counted once, but also shared on the trip's fixes |
| no AIS witness | 333 | 7.5 | 81 (3.7 kt) | unknown |

- "Logbook nearer C+U": the trip's logbook kg is nearer the two landings' sum than C alone.
- In port, the logbook holds the second landing for 490. For the other 756 (7.2 kt) it is nearer C alone: that
  catch is in no logbook, but no fishing produced it after the trip.
- **77 (15.1 kt) follow a zero-kg C**: the trip matched the withdrawn copy of a landing (plan 025 §3.3), and the
  catch's real landing came the next day. The logbook equals it (median about 1.0).
- **The kg is concentrated in pelagic gear**: 40 of the in-port landings (pelagic trawl 29, purse seine 11) hold
  23.1 kt.

By year and the logbook schema of the claiming trip, landings (kt):

| year | schema | in port throughout | went to sea, fished | no AIS witness |
|---|---|---|---|---|
| 2007 (from Sep) | afli | 26 (1.3) | 66 (0.2) | 7 (0.3) |
| 2008 | afli | 97 (1.9) | 364 (1.2) | 19 (0.4) |
| 2009 | afli | 111 (2.2) | 550 (2.9) | 42 (0.7) |
| 2010 | afli | 82 (1.4) | 483 (1.5) | 30 (0.1) |
| 2011 | afli | 68 (0.4) | 515 (1.4) | 23 (0.1) |
| 2012 | afli | 77 (3.2) | 409 (2.3) | 25 (0.9) |
| 2013 | afli | 83 (1.9) | 462 (1.7) | 11 (0.1) |
| 2014 | afli | 50 (2.4) | 484 (1.6) | 7 (0.0) |
| 2015 | afli | 55 (0.6) | 386 (2.3) | 10 (0.1) |
| 2016 | afli | 71 (2.1) | 436 (2.4) | 5 (0.0) |
| 2017 | afli | 72 (0.9) | 439 (2.0) | 14 (0.1) |
| 2018 | afli | 71 (2.0) | 399 (2.0) | 20 (0.2) |
| 2019 | afli | 56 (0.3) | 347 (1.5) | 9 (0.1) |
| 2020 | afli | 51 (0.3) | 350 (1.5) | 18 (0.1) |
| 2021 | afli | 31 (0.6) | 225 (1.4) | 8 (0.1) |
| 2021 | fs_afladagbok | 40 (0.1) | 496 (0.4) | 0 |
| 2022 | afli | 12 (2.7) | 68 (0.4) | 2 (0.0) |
| 2022 | fs_afladagbok | 34 (0.3) | 553 (1.5) | 8 (0.6) |
| 2023 | afli | 1 (0.0) | 11 (0.1) | 0 |
| 2023 | fs_afladagbok | 45 (2.6) | 355 (0.9) | 24 (2.7) |
| 2024 | afli, fs_afladagbok | 67 (3.1) | 437 (0.8) | 28 (1.2) |
| 2025 | fs_afladagbok | 22 (0.1) | 280 (0.8) | 14 (0.0) |
| 2026 | adb | 24 (0.1) | 261 (0.6) | 9 (0.0) |
| all | afli | 1,014 (24.2) | 5,995 (26.2) | 250 (3.0) |
| all | fs_afladagbok | 208 (6.0) | 2,120 (4.4) | 74 (4.5) |
| all | adb | 24 (0.1) | 261 (0.6) | 9 (0.0) |

**kg in against kg out, per vessel and year** (kg out on the fixes, raw, against kg landed):

| vessel-years | n | vessels | kg out / kg landed, median | without the in-port second landings |
|---|---|---|---|---|
| with an in-port second landing | 946 | 546 | 1.012 | 0.992 |
| with only went-to-sea or unknown ones | 4,561 | 1,266 | 1.002 | 1.002 |
| with none | 15,852 | 1,724 | 0.989 | 0.989 |

Taking the in-port second landings out brings those vessel-years to the ratio of the rest.

## 3. Wider than TODO 81: another port, or days later

The same happens when the second landing is at another port, or 2-7 days after C, with no fishing between. For
each unclaimed landing of a vessel with logbook trips, take the vessel's latest claimed landing in the 7 days
before it:

| gap, port | in port or moved without fishing | of these, logbook nearer C+U |
|---|---|---|
| 1 day, same port | 1,293 (29.7 kt) | 22.4 kt |
| 1 day, another port | 992 (42.6 kt) | 38.2 kt |
| 2-3 days | 919 (22.6 kt) | 17.6 kt |
| 4-7 days | 937 (24.5 kt) | 9.5 kt |

- The next day at another port, in port by AIS: 942 landings, median logbook/(C+U) 0.97. Only 6 % hold the same
  set of species as C, so most look like one catch split between plants.
- Counted twice by both witnesses (no fishing between and the logbook nearer C+U): 508 landings (22.4 kt) the day
  after at the same port (§2's 490, with C taken here as the latest claimed landing) and 1,529 (65.4 kt) beyond
  it. By the weight test alone, where AIS has no witness: 81 (3.7 kt) and 591 (17.8 kt).
- The wider set is mostly 2007-2010 (8-13 kt a year in 2008-2010).
- **The weight test alone is weak.** On the 24,611 landings with a fishing voyage between, it calls 20.5 % of them
  (31.7 % of their kg) part of the earlier trip.

## 4. The options, measured on TODO 81's set

Measured against the AIS witness of §2 (A in port, B went to sea and fished, C no witness):

| option | where | joins | A (right) | B (wrong) | A missed |
|---|---|---|---|---|---|
| 1. date and port: the day after, before the vessel's next logbook trip | `lid_map` | 9,264 (66.3 kt) | 1,143 (29.4 kt) | 7,806 (29.6 kt) | 103 (0.8 kt) |
| 2. option 1 and the logbook nearer C+U | `lid_map` | 1,585 (33.3 kt) | 428 (22.8 kt) | 1,081 (6.9 kt) | 818 (7.4 kt) |
| 3. first weighings under 6 h apart (`t_weighed`, 2007-09 to 2020-07) | landings | 403 (5.9 kt) | 100 (4.8 kt) | 286 (0.8 kt) | 1,146 (25.4 kt) |
| 4. `withdrawn` landings left out of `lid_map` (plan 025 §4) | `lid_map` | 77 (15.1 kt) | 38 (11.8 kt) | 26 (0.2 kt) | 1,208 (18.4 kt) |
| 5. no voyage between, by AIS | flow | 1,246 (30.2 kt) | 1,246 (30.2 kt) | 0 | 0 |
| 6. option 5, else option 2 where AIS has no witness | flow | 1,322 (33.9 kt) | 1,246 (30.2 kt) | 0 | 0 |

- **Option 1** would fold 7,806 separate trips into the trip before them. Most vessels that land the next day have
  been to sea: the voyage between fished in 8,314 of the 8,376, and for 6,456 of them no voyage between carries a
  logbook trip.
- **Option 3 does not tell one unloading from two trips.** Most in-port second landings are first weighed about a
  day after C (median 23.6 h, the same as for separate trips). Under 6 h it finds the big pelagic deliveries that
  run past midnight, and nothing after July 2020.
- **Option 4** is already chosen (plan 025 §4, item 2). It does half the kg of §2's counted-twice set with no new
  rule. What the 631 trips matched to withdrawn landings match instead is not yet measured.
- **Options 5-6 need the track**, so they belong in the flow: plan 014 keeps AIS out of preprocessing, and decision
  075 keeps the reconciled trip out of the declarations' own match.
- **The voyage link** (§1), re-run with every landing passed in and only the unclaimed landings' links kept: the
  unclaimed kg on logbook trips' voyages falls from 27,848 landings (764 kt) to 7,265 (331 kt), and for §2's set
  from 9,357 (58.2 kt) to 2,437 (16.7 kt). Without this, a second landing joined to its trip would hand the trip's
  voyage on to the vessel's next unclaimed landing.

## 5. The design (proposal)

1. **Plan 025's `withdrawn` first**, in preprocessing as chosen there. Measure what the 631 trips match instead.
2. **`curate/trip_landing.R`, a flow step**, writes `curated/logbook/trip_landing.parquet`. It has one row per
   logbook trip and landing, with `basis`:
   - `lid_map`: the declarations' own match, carried over unchanged.
   - `track`: an unclaimed landing with no fishing voyage since the vessel's last claimed landing joins that
     landing's trip. Any port, at most 7 days (ask b).
   - `weight`: where AIS has no witness, the same landing joins the trip if the logbook is nearer C+U. Its measured
     error goes in the record (§3).
   - `lid_map` is not changed.
3. **`ais_catch.R` reads `trip_landing`** where it now reads `lid_map`, in two places. The landings it leaves out of
   the shared catch are all of a trip's landings. Its raising factor is the trip's landed weight over all of them.
   A trip's catch stays its logbook catch ("one source per trip"), raised to all it landed.
4. **`ais_catch.R`'s voyage link takes every landing.** A claimed landing takes its own voyage first, and only the
   unclaimed landings' links are kept (§4).
5. Plan 026's 9 foreign second landings (3.5 kt) are covered by the same rule.

Not in this plan, measured only in size: 2,656 unclaimed landings (229 kt) are linked to a voyage whose logbook
trip has no landing in `lid_map`. Where that trip has logbook catch (`lid_map` matches no trip without), it looks
like a `lid_map` miss, and the kg would be counted twice too. A
`trip_landing` rule by voyage (a landing that ends a logbook trip's voyage joins it) would cover it; ask d.

## 6. Checks (done when)

- Per vessel and year, kg on the fixes raised equals kg landed within the ratio of the vessel-years with no second
  landing. The 946 vessel-years of §2 move from 1.012 to about 0.99, raw.
- No unclaimed landing's catch is shared on a voyage that carries a logbook trip, except those the record declares.
- `ais_catch.R`'s own checks hold: kg in equals kg out per year and approach, and no event is in two units.
- The docs page on the catch says how a trip's further landings are joined, with the counts.

## 7. Asks

a. **Where:** a flow table (`trip_landing`, recommended) or `lid_map` with a date and weight rule (options 1-2,
   which join thousands of separate trips)?
b. **The window:** recommended is any port, up to 7 days, until the vessel next goes fishing. Or the same port and
   the next day only, as in TODO 81?
c. **In port, logbook = C** (756, 7.2 kt): join anyway, so that the trip's raising factor carries the catch the
   logbook lacks (recommended), or leave those landings as their own?
d. **The voyage rule for `lid_map`'s misses** (2,656 landings, 229 kt): in this plan, or a TODO of its own?
