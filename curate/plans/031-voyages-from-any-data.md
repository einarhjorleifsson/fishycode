# 031 — Voyages from any data: the stays the track misses, records as evidence, and several gears in a voyage

**status:** proposal — measured 2026-10-19 (read-only, on the build at e2f741f); nothing built; six asks open (TODO 90) ·
**2026-10-19** · **see:** TODO 90, decisions 060, 063, 074, 101 and 144, plan 011 (port stays), plan 013 (ramb's
steps), plan 025 (the first weighing bounds `T2`), `docs/one_flow.qmd` (step 1, trip, and step 3, gear),
`curate/port_stay.R`, `curate/ais_voyage.R`, `curate/link_trip_voyage.R`, `curate/voyage_gear.R`; on the vessel-overview
branch, not merged: TODO 86 (the gear read from the track) and TODO 89 (gaps at sea judged against coverage)

Drafted with AI assistance (Claude) on 2026-10-19, at the maintainer's request. The numbers below were measured by
Claude (AI); a person has not yet checked them.

**Measured** (read-only, scripts and output in scratch only):
- `curated/ais/{voyage,port_stay,voyage_gear}.parquet`, `curated/ais/trail/` (fixes, their voyage), and
  `curated/link/trip_voyage.parquet`;
- `curated/logbook/{trip,station,gear,lid_map}.parquet` and `curated/landing/landings.parquet`;
- `curated/reference/{port_geometry,port_radius,gear_window}.parquet`.

**Assumed:**
- A port's distance is measured from its polygon's centre, with the larger of its departure radius and 2 km as "at the
  port". `port_stay.R` measures from the polygon itself, so a few numbers below are approximate, as marked. Step 1
  settles them with `port_stay`'s own code.
- A vessel steams at about 6 knots, for the time-budget rule of §4.1.
- A landing's date is within a day of the arrival (plan 025: the date is the weighing's, sometimes later).

## 1. The question

The maintainer's framing (2026-10-19), after voyages with several gears were found to break `voyage_gear`'s choice of
one gear (decision 144):
- **Iceland:** a voyage with several gears is more likely a voyage allocation issue than real multi-gear fishing. The
  landings are the better record of gear, since the Directorate of Fisheries enforces them: an output-controlled ITQ
  system watches kilograms, not gear or days at sea. Logbook gear is little checked. Few Icelandic voyages use two
  gears, and mostly small vessels.
- **The end goal is generic:** a function that builds voyages from a ping series. Sometimes only landings exist,
  sometimes only logbooks, sometimes both or neither. And in many fleets one voyage can use several gears: Iceland is
  the exception.
- **So** each fix for the Icelandic data should be judged by whether the algorithm would also work at a global scale
  (WGSFD).

## 2. What happens now

- **Stays** (`port_stay.R`, `ramb::rb_find_trip_stays`): a stay needs 2 hours of evidence at one port, from any of
  four rules (decisions 060, 074):
  - two consecutive pings 2 h or more apart, the first within 2 km of the port (arrival) and the second within the
    port's own departure radius (2-6 km);
  - pings inside the polygon spanning 2 h or more;
  - an STK arrival and departure event pair.
- **Voyages** (`ais_voyage.R`, `rb_cut_trip_voyages`): the sea between two stays.
- **Trips to voyages** (`link_trip_voyage.R`): each logbook trip goes to the voyage it overlaps most. One voyage can
  carry several trips.
- **Voyage gear** (`voyage_gear.R`): one gear per voyage.
  - The logbook stations' most used gear, with its speed range when all its gears share one range ("ambiguous"
    otherwise).
  - Else the landing's gear with most weight.
  - Station gear (`gid_used`) already takes the landing's gear where the trip's landing names one gear (plan 014 3j,
    the maintainer's rule of 2026-10-09).
  - Ties are broken by row order, so the choice is not deterministic (decision 144).

## 3. Measured

### 3.1 Voyages with several gears are rare

Of 797,540 voyages with logbook stations, 702 have more than one gear (`gid_used`), 0.09 %:

| kind | voyages | mostly |
|---|---|---|
| several trips on the voyage, each with one gear | 386 | all sizes; 218 under 12 m |
| one trip with several gears | 183 | 107 of 40 m and over: bottom and pelagic trawl (6+9) on 96; longline and handline (12+14) on 39 |
| code variants of one gear type | 99 | all under 15 m: Lína, Landbeitt lína and Línutrekt are all LLS_DEF, but carry different speed ranges |
| several trips, one of them with several gears | 34 | |

The share is highest on vessels of 40 m and over (0.37 %), where a trawler switching between bottom and pelagic trawl
is plausible.

### 3.2 A voyage with several logbook trips

24,729 voyages (3.1 %) carry two or more logbook trips. Whether the track calls at a port inside the voyage, by the
radius assumed above (approximate):

| | voyages | share | median voyage |
|---|---|---|---|
| a port call of 2 h or more inside the voyage | 11,933 | 48 % | 69 h |
| only brief port touches, under 2 h | 7,773 | 31 % | 42 h |
| no port inside the voyage | 5,023 | 20 % | 20 h |

- **The first is the allocation issue the maintainer expected:** the voyage merges several sea trips across a stay
  the rules missed. The 386 voyages of §3.1 split 171, 106 and 109 the same way.
- **The last is a continuous sea trip the logbook splits by calendar day.** The old logbook (`afli`) and many day
  records date a trip by day, with no time.
  - Hull 1458 leaves Patreksfjörður at 04:39 on 19 June 2021 and arrives in Bolungarvík at 11:04 on the 20th. The
    logbook has two trips, the 19th and the 20th.
  - Hulls 1926 (2013), 2800 (2015) and 2500 (2022) show the same.
  - There the voyage is right, and several trips on it are not an error.

### 3.3 The missed calls: mostly a silence in port, mostly 2007-2012

The 17,202 port calls of 2 h or more inside those 11,933 voyages:
- 76 % are a silence near the port, the vessel unheard for 2 h or more. 10,338 of those 13,125 fall in 2007-2012,
  when STK reported sparsely. The arrival ping is near the port, but the first ping after the silence is often already
  outside the departure radius, so the gap rules fail by design.
- 17 % are pings near the port spanning 2 h or more. Some of these are inside the radius used here but under 2 h
  inside the polygon, so step 1 must recount them.
- Hull 7263 in 2010 shows the sparse case: a six-day voyage on 49 STK pings.

### 3.4 The landings as the yardstick

A landing names the vessel, date and port, and the Directorate enforces it. Of 990,335 landings 2007-2026, 958,106
are by a vessel with AIS within a day of the landing date:

| | landings | share |
|---|---|---|
| a stay at the landing port, within a day | 926,828 | 96.7 % |
| a stay at another port only | 23,890 | 2.5 % |
| no stay at all | 7,388 | 0.8 % |

- The landings with no stay are 1.5-3 % in 2007-2010, and 0.2-1 % since.
- Of the 7,388:
  - 33 % fall silent 2 h or more at the port, with the next ping outside the departure radius;
  - 23 % are at the port under 2 h;
  - 18 % look 2 h or more at the port by this measure;
  - 14 % come near but never inside the port radius;
  - 11 % never come within 20 km of the landing port.
- **A time budget would accept most silences.** The silence, less the time to sail from the last ping to the port
  and from the port to the next ping at 6 knots, is 2 h or more for 2,378 of the 2,467 silent cases.
- A day's window is generous for day boats: a landing can be covered by the stay of the evening before. So this
  coverage is an upper bound, and the 11,933 voyages of §3.2 are the sharper measure of missed calls.

### 3.5 The port list is not the cause

Every one of the 66 landing ports has a stay polygon, and stays are found at all of them.

## 4. The design (proposal)

A generic voyage finder, with Iceland as one configuration of it.

### 4.1 Stays from the track at any resolution: a time budget

The departure radius (decision 060) stands in for "the vessel cannot have left long before this ping". Make that
explicit, so it scales with the ping interval:
- **The rule:** a silence that begins near a port is a stay when the silence, less the time to sail from the last
  ping to the port and from the port to the next ping, is at least the minimum stay.
- **Dense AIS:** the travel time is minutes, and the rule is the present one.
- **Hourly VMS or sparse STK:** the rule still finds the stay where a fixed radius rejects it.
- **The steaming speed:** one value (6 knots) or the vessel's own, read from its track (ask b).

### 4.2 Records as evidence, never as positions

A landing, a logbook trip end (its declared port and date) or a port-state visit says the vessel was at a port on a
date.
- **Confirm:** where the track can reach that port on that date (§4.1's budget), the record supports a stay. That
  includes a call shorter than the minimum, where the record says the vessel landed there (ask a, c). The stay's
  `basis` names it: `landing`, `logbook`.
- **Never place:** a record never makes a stay where the track is elsewhere all that date. That disagreement goes to
  a check, one of three things:
  - the wrong port or date in the record;
  - another vessel's track (it feeds the STK key review, TODO 25);
  - a landing trucked from another port.
- **Order:** the evidence order follows the maintainer's judgement of the records: landing over logbook.

### 4.3 Without a port list

For fleets with no port polygons, which is much of the world's small-scale fishing:
- a candidate port is a place where silences or still pings begin and end, near the coast (`docs/one_flow.qmd`
  already names this);
- the stay's port is then `learned`, not listed.

This is generic work that Iceland does not need. Ask e puts its scope.

### 4.4 Voyages and the logbook's day trips

Voyages are cut at stays, as now (`rb_cut_trip_voyages`). Several logbook trips on one voyage stay allowed: on a
continuous sea trip they are the logbook's days, not an error. The reconciled trip table (`docs/one_flow.qmd`, step 1)
says, for each voyage, which records cover it (ask f).

### 4.5 Several gears in a voyage: a gear set

`voyage_gear` becomes a set of gears per voyage, each with its share and basis:
- **Where shares come from:** the landing's gears by weight, the logbook stations by count or time.
- **The order** follows the maintainer's rule for Iceland: the landing first, then the logbook (ask d).
- **Code variants** of one gear type (Lína, Landbeitt lína and Línutrekt as LLS_DEF) are one gear, with one speed range.
- **Fishing per fix:**
  - by the record's window where one holds the fix;
  - else by the speed range of the gear in use at that time, where the logbook dates its gears;
  - else a fix is fishing if it fits a gear of the set, and carries that gear.
- **The track** adds the gear's kind where no record gives it (the overview branch's TODO 86).
- **Ties** are broken by a fixed order, so the result is the same on every run (decision 144).
- **For Iceland** the set is nearly always one gear, and the trail's columns stay. A second gear adds rows to the
  set, not columns to the trail.

### 4.6 Where each piece lives

| piece | ramb (generic) | fishycode (Iceland) |
|---|---|---|
| time-budget stays | `rb_find_trip_stays` gains the rule, with the steaming speed as an argument | the speed chosen by ask b |
| records as evidence | `rb_find_trip_stays` takes optional `records` (vessel, date, port, kind) | landings and logbook trip ends passed in |
| learned ports | a new `rb_` step, later (ask e) | not needed |
| gear set | a new `rb_` step: a voyage's gears from records, with shares | landing first; metier variants merged |
| fishing per fix | `rb_assign_fishing` takes a gear set | `R/trail_sql.R` |

Every case gives the same output (`docs/one_flow.qmd`): the columns are the same, and the `basis` says what filled them.

| data | stays from | voyage gear from |
|---|---|---|
| pings only | the track | the track's pattern, or none |
| pings and landings | the track, confirmed by landings | the landings |
| pings and logbooks | the track, confirmed by trip ends | the logbook stations |
| all three | as above | the landing first, then the logbook |

## 5. Steps

1. **Measure exactly.** Replay `rb_find_trip_stays` on every voyage with a missed call (§3.2-3.4), not only those with
   several trips. Classify each miss by the rule it fails, with the polygon distances `port_stay` uses. This settles
   the approximations above. Read-only.
2. **The time budget in ramb,** tested in scratch on the Icelandic data. Measure:
   - stays gained and lost, and voyages split;
   - the landing coverage of §3.4, with a tighter window;
   - the share of the 11,933 voyages left with a call inside;
   - stays added with neither a landing nor a logbook end, by port (anchoring, waiting): the false-positive check.
3. **Records as evidence** (landings, then logbook trip ends), with the same measures, and the records the track
   contradicts listed for the key review.
4. **The gear set** (`voyage_gear` in ramb and fishycode), landing first. Measure fishing flags and catch against
   now: the catch must stay equal in every vessel-year (kg in = kg out).
5. **Simulated scenarios in ramb's tests:** dense AIS, hourly VMS, sparse STK; landings only, logbook only, neither;
   two gears in one voyage; a logbook that splits one sea trip by day.
6. **Apply to Iceland and rebuild,** on the maintainer's go. Check the landing coverage, the voyages with several
   trips, the day-split trips left on one voyage, and fingerprints before and after.
7. **Describe it** in `docs/one_flow.qmd`, steps 1 and 3, for WGSFD.

## 6. Checks (done when)

- Every landing by a vessel with AIS that day falls on a stay at its port, or is listed with the reason the track
  gives. The landings with no stay (§3.4) fall well below 0.8 %, most of all in 2007-2010.
- Few voyages with several trips still hold a port call of 2 h or more inside them; each one left is explained.
- `voyage_gear` gives the same result on every run, and a voyage can carry several gears.
- ramb's tests cover the scenarios of step 5.
- The catch is equal in every vessel-year before and after.

## 7. Asks

a. **May a landing make a stay** where the pings alone fall short of the minimum, given the track reaches the port
   that day? Or should it only confirm, and flag?
b. **The steaming speed for the time budget:** one value (6 knots), or each vessel's own from its track?
c. **A call under 2 h on a landing day:** a stay, or a call of its own, which cuts the voyage but is labelled short?
d. **Voyage gear:** the landing first for every voyage, or only where the logbook stations disagree?
e. **Learned ports for fleets without a port list:** in this plan, or a later one?
f. **The logbook's day trips on one sea trip:** keep them as several trips on one voyage, as now, or merge them into
   one trip in the reconciled trip table?
