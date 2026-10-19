# 031 — Voyages from any data: the stays the track misses, records as evidence, and several gears in a voyage

**status:** proposal — measured 2026-10-19 (read-only, on the build at e2f741f); steps 1 and 2 done the same day
(§3.6, §3.9);
the cascade (§4.0), the other pitfalls (§3.7), outside code (§3.8) and the robustness bench (§4.8) added the same
day; nothing built; eight asks open; TODO 90 now carries it under a wider review of the voyage definition ·
**2026-10-19** · **see:** TODO 90, decisions 060, 062, 063, 074, 078, 101 and 144, plan 011 (port stays), plan 013 (ramb's
steps, and its table of logic doubts), plan 017 (foreign ports), plan 022 §4 (STK's own voyages, TODO 68), plan 025
(the first weighing bounds `T2`), `docs/one_flow.qmd` (step 1, trip, and step 3, gear), `docs/ports.md`,
`curate/port_stay.R`, `curate/ais_voyage.R`, `curate/link_trip_voyage.R`, `curate/voyage_gear.R`, TODO 86 (the gear read
from the track) and TODO 89 (gaps at sea judged against coverage)

Drafted with AI assistance (Claude) on 2026-10-19, at the maintainer's request. The numbers below were measured by
Claude (AI); a person has not yet checked them. §3.7, §3.8, §4.0, §4.7 and §4.8 were written by Claude the same day,
in a second session. They draw on the maintainer's outline of the problem (§4.0) and points on robustness (§4.8), on
the code and on the record.

**Measured** (read-only, scripts and output in scratch only):
- `curated/ais/{voyage,port_stay,voyage_gear}.parquet`, `curated/ais/trail/` (fixes, their voyage), and
  `curated/link/trip_voyage.parquet`;
- `curated/ais/ping/` (each fix's `stay` and `voyage` keys), `staging/aux/ports.fgb` (every source's port polygons) and
  `staging/ais/stk_event.parquet` (STK's port event rows);
- `curated/logbook/{trip,station,gear,lid_map}.parquet` and `curated/landing/landings.parquet`;
- `curated/reference/{port_geometry,port_radius,gear_window}.parquet`;
- ramb 2026.10.15.1 (installed) on a made-up track with no port list (§3.7);
- the external example data of §4.8: vmstools 0.77's data, iapesca's, WKSSFGEO's and WKSSFGEO2's files (including
  the CNR folder of WKSSFGEO's `dev_branch`), and ramb's `inst/extdata`.

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

- **Whacks first:** the pings are marked and the whacks set aside before any stay is sought (step 0,
  `curate/ais_ping_clean.R`, ramb's `rb_flag_ping_*`, decisions 067 and 069). The stays read `ping_clean` only.
- **Stays** (`port_stay.R`, `ramb::rb_find_trip_stays`): a stay needs 2 hours of evidence at one port, from any of
  four rules (decisions 060, 074):
  - two consecutive pings 2 h or more apart, the first within 2 km of the port (arrival) and the second within the
    port's own departure radius (2-6 km);
  - pings inside the polygon spanning 2 h or more;
  - an STK arrival and departure event pair, from 2017 only (decision 059); a stay found only from events is not
    used (decision 060).
- **Ports:** the 157 `einar` polygons only, Iceland 129 and Faroe 28 (plan 017). `staging/aux/ports.fgb` holds 9,905
  more from other sources (GFW anchorages, vmstools, GISCO, OSM, `jeppe`, EMODnet), and no stay reads them.
- **Voyages** (`ais_voyage.R`, `rb_cut_trip_voyages`): the sea between two stays, cut at New Year (`by_year`); a voyage
  of under 10 recorded pings is dropped after numbering, and its fixes keep no voyage.
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

### 3.6 Step 1: `port_stay`'s own rules replayed

`port_stay.R`'s year function was run from a scratch copy on the real inputs: the same pings, polygons, radii and STK
events, with one parameter changed at a time.
- **The check:** with today's parameters it reproduces the built stays exactly, 1,631,285 of 1,631,285.
- **The four loosenings:**
  - a departure radius of 30 km;
  - that, plus an arrival radius of 5 km;
  - a minimum stay of 1 h;
  - a minimum stay of 0.5 h.
- **The measure:** a stay one of them finds that overlaps no built stay is a missed call. Finds of one vessel and port
  that overlap are one call, labelled by the loosenings that find it. A landing or logbook trip end at that port
  within a day confirms it.
- These numbers replace the approximations of §3.2-3.4 where they differ.

| the call fails | calls | confirmed by a record |
|---|---|---|
| only the departure radius: the next ping is outside it | 12,295 | 79 % |
| the minimum stay: at port 1-2 h | 168,323 | 16 % |
| the minimum stay: at port 0.5-1 h | 168,568 | 14 % |
| the arrival radius: the last ping 2-5 km from the polygon | 7,325 | 28 % |
| short, and the departure ping outside | 630 | 77 % |

- **The departure radius is the clear fault, and a time budget fixes it.**
  - These calls are long silences in port: a median 19 h, most overnight.
  - The first ping after is a median 4.1 km from the polygon (90 % within 12.3 km).
  - §4.1's rule (2 h, at 6 knots) accepts 12,022 of the 12,295: 9,630 of the 9,712 a record confirms, and 2,392 of the
    2,583 no record names.
- **Short calls are many and mostly unconfirmed.** 336,891 calls of 0.5-2 h, only about 15 % with a landing or logbook
  end at that port that day. Lowering the minimum stay everywhere would mostly add stops that are not landings. A
  record confirming a short call (ask c) adds about 51,000.
- **The 7,388 landings with no stay:**
  - 29 % are departure-radius misses, and 2 % more combine it with another;
  - 13 % are calls of 1-2 h, 2 % calls of 0.5-1 h, and 5 % an arrival ping 2-5 km out;
  - 42 % are found at the landing port by no loosening. There the track and the landing disagree on the port: a wrong
    port in the record, a landing trucked in, or another vessel's track (§4.2's check).
- **The 24,729 voyages with several trips:**
  - 43 % hold no missed call;
  - 25 % a call of 1-2 h, 17 % a departure-radius call, 6 % a call of 0.5-1 h, 3 % an arrival-radius call, and about
    5 % several kinds.
  - Of §3.2's continuous sea trips, 165 of 5,023 get a call: they are what they looked like. Of its voyages with a
    port call inside, 8,203 of 11,933 do.

### 3.7 The current method's other pitfalls

Counted 2026-10-19 on the same build, or cited where the record already holds the number.

1. **No port list gives no stays, and no warning.** ramb on a made-up track (three day trips 6 h apart, silent in port)
   with an empty port table: `rb_find_trip_stays` returns no stay, and `rb_cut_trip_voyages` makes one voyage of the
   three. Other people's data meet this first.
2. **A foreign port is never a stay.** The stays read the `einar` polygons of Iceland and the Faroes only, so a call
   anywhere else is part of a voyage. *Corrected 2026-10-19 (maintainer's doubt): a first count here gave 296 voyages,
   far too few. It matched pings only inside polygons, so the lists stored as points (GISCO, vmstools, EMODnet, most of
   OSM) never matched, and it left out the Faroes, which are on the `einar` list.* Counted again, 2007-2026:
   - **AIS:** 40,117 vessel-days with pings under 2 knots within 3 km of a foreign port on any list (raw GFW anchorages,
     GISCO, OSM, vmstools, EMODnet, UN/LOCODE, `jeppe`, and the Faroese ports). 200-470 a year in 2007-2012 (STK only),
     3,200-4,150 a year since 2020, when ASTD hears vessels abroad; 19-147 vessels a year. A vessel-day is not a call (a
     stay of 5 days counts 5), and a few lie at offshore anchorages on GFW's list.
   - **Landings abroad** (the Directorate's port codes): the Faroes 1,207 (111 vessels), Norway 535 (138), Canada 29,
     Denmark 27, Greenland 23, Ireland, Scotland, the Netherlands and Britain 12: at least 1,833. Code 150 "various
     places" holds 3,028 more, and code 159, with no name in the port list, 7,305 (145 vessels); what 159 is, is ask h.
   - Among the places: yards in Turkey (Tuzla, Yalova); Rendsburg on the Kiel Canal is a transit, so a longer list also
     brings stays that are not port calls.
   - Plan 017: non-Faroese foreign voyages have no start port in 19 % of cases.
3. **The fixes of a short voyage get no voyage.** A fix in neither a stay nor a voyage sits in a voyage of under 10
   recorded pings, which the cut drops: every such run has 9 or fewer recorded pings, checked in 2010 and 2020.
   - 807,040 fixes in 2007-2026, 30-50 thousand a year.
   - 1.0 % of fixes in 2007, 0.5-0.7 % in 2008-2012, and 0.05-0.2 % since 2013.
   - This breaks "every fix accounted for" and answers one row of plan 013's table of logic doubts.
4. **The cut at New Year.** 510 voyages in 2007-2025 end open on 31 December (2-64 a year, more in recent years). About
   as many start open on 1 January.
   - One sea trip becomes two voyages, each missing a port.
   - `docs/one_flow.qmd` names the same fault in the ICES data call.
   - This answers the other row of plan 013's table.
5. **Long voyages are not sorted.** 979-2,006 voyages a year last over 7 days, and 153-696 over 30.
   - Some are distant-water trips.
   - Some hide the calls of item 2 and §3.3.
   - Nothing yet tells the two apart.
6. **A gap at sea has no class.** A gap that does not begin and end at one port counts as sea.
   - In 2019 and 2023, 5.5-6.0 % of gaps end at no port within 2 km (plan 011 §2b).
   - Such a gap may be a foreign or unlisted port, a coverage hole (TODO 89) or a transponder switched off, and the rules
     cannot tell which.
7. **One minimum stay everywhere.** Lowering it from 3 to 2 h adds 7 stays per landing recovered, and from 2 to 1 h
   adds 23 (decision 062). §3.6 finds the short calls mostly not landings.
   - A learned or longer port list must face anchoring, shelter in a fjord, canal queues and fish farms.
8. **Geometry for the North Atlantic.** The nearest port is chosen by distance in degrees (`ST_Distance` on longitude
   and latitude in `rb_find_trip_stays`), and the buffers default to EPSG:3575 (plan 013's table).
   - Generic code needs metres in a projection local to each port.
9. **Circular evidence.** The Icelandic polygons are hulls of STK's own `I` pings
   (`reference/ports/bootstrap_iceland_faroe.R`). STK's 3.19 M recorded voyages (`tilk_stk_allt`, plan 022 §4, TODO 68)
   are paired from the same port events.
   - Neither checks the stays independently.
   - Plan 022 §4's comparison is still undone.
10. **Vessel errors become voyage errors.** Two vessels on one mobile id (vid 2765) make false stays and jumps. The
    voyage step trusts the vessel key (TODO 25).
11. **Neighbouring ports.** Njarðvík and Keflavík, Reykjavík and Sundahöfn (decision 060): 2.5 % of landings meet a stay
    at another port only (§3.4).
12. **Whacks the speed filter leaves.** STK's table holds both the AIS position stream and the port entry and exit
    records (`in_out_of_harbor`, `harborid`). So a track can jump to a harbour and back at consecutive time steps
    (maintainer). The speed filter removes most of these; counted in `curated/ais/ping` for 2007-2026, with each step
    under an hour:
    - **Harbour to another harbour and back:** 2,640. 770 of them are STK event rows. In 2008-2012 all of them are,
      at a median 6-15 km apart and up to 26 km. Since 2013 most are 0.5 km flickers between neighbouring polygons.
    - **Sea to a harbour and back,** 2 km or more out: 1,792. 1,593 of them (89 %) are STK event rows, at a median
      2-7 km and 10-16 knots, under the filter's 25.
    - **A harbour, the sea and back:** 1,684. 567 of them are event rows.

    That is about 6,000 fixes in all, a few hundred a year. Their effect on stays and voyages is not measured.

### 3.8 What outside code does for trips and ports

Read 2026-10-19. Decision 078 read the rest on 2026-10-09. None of it is in ramb, and none of it is copied here.

- **iapesca's `Detect_FishingTrips`** (Ifremer, WKSSFGEO 2022) is a small cascade:
  - ports (points or polygons), buffered from 2 km, the buffer grown up to 2 nm until the track touches one;
  - else a coastline, downloaded through `geodata` when none is given: pings within the buffer are ashore;
  - optionally a speed limit, under which pings near the port or coast are stops;
  - a trip breaks across a run of pings ashore when the trip starts are over `min.stop` (1 h) apart. The run's
    length in rows is scaled by the mean ping interval.

  It drops the pings ashore and works one vessel at a time, in memory. A silence with no ping ashore never breaks a
  trip, the fault plan 011 fixed here.
  - **To take:** the coastline as the last port tier (§4.3), and rules scaled by the ping interval (as §4.1).
  - **Not to take:** a coastline band cuts or removes inshore fishing within 2 km of land, as in Icelandic fjords and
    much small-scale fishing.
- **The Italian CNR code** (WKSSFGEO `dev_branch`, `R-dev/galdelli_pulcinella_tassetti`):
  - A vessel is in port after 4 consecutive pings within a port's 1 km buffer, at a mean speed under 6 knots.
  - `closest_port_recovery` gives an open trip end its port: of the five closest ports within 50 km of the first or
    last ping, the port at the trip's other end if it is among them, else the closest. With none in reach the end is
    "At_Sea".
  - **To take:** a last tier for `pid1` and `pid2` (§4.0), with its own basis.
- **The Irish code** (the same branch): a gap of 2 h or more ends a trip (decision 078). It assumes VMS never falls
  silent at sea, and AIS does.
- **`define_trips_pol`** (WKSSFGEO, the ICES data call) is ramb's `"jepol"` already.
- **The ICES data call** takes trips only from the logbook. Its vmstools harbour points are buffered 3 km in
  EPSG:3857, about 1.3 km on the ground at 64°N.

### 3.9 Step 2: the robustness bench, measured

Run 2026-10-19, read-only; scripts and output in the session's scratch. The design is §4.8.
- **Scoring:**
  - *found* is the share of witnessed landings (a landing that a logbook trip end or an STK arrival puts at the same
    port group within a day) with a stay at that group on the landing day or the day before;
  - *claimed* is the share of a method's stays that some witness record claims, each record claiming only the nearest
    stay;
  - *per landing* is stays per witnessed landing.
- **Port groups:** `einar` ports within 3 km of each other (157 ports, 138 groups).
- **Comparing:** compare methods within a year only. Before 2017 STK's events are no witness, so *claimed* is lower
  in 2010.

**The bench's own check.**
- The published jepol reproduces its 90 saved trips on the Danish tracks exactly.
- CNR's method, run per vessel as its script does, gives back 84 of its 94 saved trips. The other 10 are artefacts of
  CNR's own run: one saved trip starts on one vessel and ends on another.
- ramb's `"jepol"` matches the published code on 89 of 90 trips. The one difference is a split ramb fixed on purpose.

**Today's inputs (S0):**

| method | found 2010 | found 2018 | stays 2018 | claimed 2018 | per landing 2018 |
|---|---|---|---|---|---|
| `stays`, today's | 95.2 % | 98.3 % | 62,331 | 76.4 % | 1.25 |
| `stays` + time budget (§4.1, prototype) | 97.8 % | 98.4 % | 73,339 | 65.6 % | 1.47 |
| `runs` | 97.3 % | 99.4 % | 77,645 | 73.6 % | 1.55 |
| jepol (ramb) | 97.9 % | 99.5 % | 78,438 (14,464 at no port) | 76.3 % | 1.28 |
| Irish, a gap of 2 h | 97.6 % | 65.8 % | 114,970 | 31.8 % | 2.27 |
| CNR (published R, 65 min on 4 cores) | not run | 97.6 % | 59,891 | 79.9 % | 1.20 |
| learned ports, no port list (§4.3) | 97.6 % | 98.1 % | 68,770 | 70.9 % | 1.37 |
| iapesca (published R) | not run | not run: too slow as published (above) | | | |

- **The time budget helps where pings are sparse:** +2.6 points in 2010. In 2018 it only adds about 11,000 stays that no
  witness claims, so it must scale with the ping interval.
- **jepol's** 72 h cap splits long trips at sea, hence its stays at no port.
- **CNR's rule** has the best *claimed* and the fewest extra stays on Icelandic AIS.

**Learned ports against lists that do not come from our AIS.** The `einar` polygons are hulls of STK's own pings, so
learned ports were compared with the raw lists, before `ports_all.R` merges them into `einar`. In Iceland those are GFW
anchorages (63 places), GISCO (60), UN/LOCODE (80), OSM (11) and vmstools (1).

| | 2018 | 2010 |
|---|---|---|
| learned ports near an `einar` port, within 2 km of a place on some independent list | 82.4 % of 91 | 73.9 % of 115 |
| learned ports away from every `einar` port, near any list | 0 % of 33 | 0 % of 99 |
| landing ports found by learned ports | 96.7 % of 60 | 100 % of 62 |
| landing ports on GFW / GISCO / all independent lists | 91.7 / 90.0 / 95.0 % | 90.3 / 87.1 / 91.9 % |

The learned ports away from `einar` are on no list: anchorages, shelter, fishing grounds or fish farms. That is the
learning's false-port cost.

**Port lists by source and by share (S3, S4), 2018, today's rules:**

| port list | found | claimed |
|---|---|---|
| `einar` | 98.3 % | 76.2 % |
| GFW anchorages, points buffered 1 / 2 / 3 km | 98.1 / 98.3 / 96.6 % | 77.4 / 77.0 / 75.4 % |
| GISCO, buffered 1 / 2 / 3 km | 91.8 / 95.0 / 89.7 % | 76.9 / 76.5 / 72.8 % |
| all independent lists, 2 km | 98.3 % | 76.9 % |
| `einar` with 25 / 50 / 75 % of ports dropped | 79.3 / 35.1 / 17.6 % | about 76 % |
| the same, plus learned ports | 98.4 / 98.3 / 98.2 % | 74.5 / 73.0 / 71.7 % |

- **An independent list does as well as our AIS-made one.**
- **A point list wants a buffer of 1-2 km.** At 3 km, neighbouring ports merge and passing vessels are caught.
- **A partial list with learned ports as the fallback** recovers what the list misses (the cascade of §4.0).

**Thinned pings (S5)**, on the 323 vessels of 2018 whose pings are a median 3 minutes apart or less:

| method | full | 10 min | 1 h | 2 h | in-port pings removed (as STK) |
|---|---|---|---|---|---|
| `stays` | 98.2 % | 97.9 % | 86.9 % | 82.4 % | 97.0 % |
| `stays` + time budget | 98.2 % | 98.0 % | 87.5 % | 82.9 % | 97.4 % |
| `runs` | 99.3 % | 89.9 % | 83.3 % | 81.9 % | 0 % |
| jepol | 99.4 % | 92.8 % | 85.7 % | 84.2 % | 0 % |
| Irish | 51.0 % | 51.0 % | 47.4 % | 91.6 % (6 stays per landing) | 98.1 % |
| learned ports | 95.9 % | 95.4 % | 87.0 % | 87.5 % | 95.1 % |

- **Methods that need pings in port fail when the tracker falls silent there** (`runs`, jepol). The silence-based rules
  keep 95-98 %.
- **At VMS rates every method loses 12-16 points.** Mostly these are short calls by day boats, which hold one or two pings.
- **A fixed 2 h gap or minimum stay** is meaningless at 2-hourly pings: 2,626 learned "ports", and 6 Irish stays per
  landing. The stay rules must scale with the vessel's own interval. The time in port should be estimated from the pings
  just outside the call, less the sailing time, not only from silences that begin near a port.

**Whacks (S6):** with the speed filter's 59,000 whacks of 2018 put back, the duration-based methods hardly move
(`stays` 98.2 %, jepol 99.6 %, learned 98.0 %). `runs` gains 13,000 short false stays (*claimed* 73.6 to 65.8 %),
because whacks flicker in and out of port. Many whacks are STK's port-event rows at the harbour: noise for the track,
evidence of a stay.

**Combinations:**

| | found 2018 | claimed 2018 | found 2010 | claimed 2010 |
|---|---|---|---|---|
| best single (jepol 2018; `stays` + budget 2010) | 99.5 % | 76.3 % | 97.8 % | 56.7 % |
| today's `stays` | 98.3 % | 76.4 % | 95.2 % | 59.5 % |
| vote, 5 methods agree | 98.1 % | 77.1 % | 97.1 % | 61.2 % |
| vote, 3 agree | 98.9 % | 73.8 % | 97.7 % | 59.3 % |
| union | 99.8 % | 73.9 % | 98.6 % | 54.6 % |

- **In dense 2018,** combining adds little.
- **In sparse 2010,** a vote of 5 methods beats today's on both counts.
- **The cascade as prototyped** (time budget for vessels with a median interval over 15 min) adds nothing: almost no
  vessel qualifies. It should judge the gaps around each call.
- **The hourly vote fragments calls** when many methods must agree (7 methods, 6 agreeing).

**Other fleets' data**, scored against their providers' trips: the share of trip boundaries a method puts a stay
across, on boundaries with a ping within 6 h either side.

| set | `stays` | `runs` | jepol | Irish | learned | CNR |
|---|---|---|---|---|---|---|
| vmstools, VMS about 2 h, logbook trips (291 vessels with VMS) | 83.7 % | 95.0 % | 97.8 % (1.41 splits per trip) | 92.4 % (3.30 splits) | 82.4 % | 18.6 % |
| iapesca, 15 min, its harbour | 100 % | 100 % | 100 % | 57 % | 57 % | 86 % |
| Adriatic passive gear, 6 min, CNR's harbours | 89 % | 100 % | 100 % | 100 % | 78 % | 56 % |
| Irish pots, gillnets; Italian pots (anonymised, trip pings only) | none | none | none | 100 % | 0 / 0 / 100 % | none |

- **Where a file holds only trip pings,** only the gap rule sees a boundary.
- **Where anonymisation moves each trip,** learned ports fail.
- **CNR's rule needs 4 pings in port,** so at 2-hourly VMS it misses most calls.
- **vmstools' example data:** its logbook covers 586 vessels and its VMS 291, so trips of vessels with no VMS are left
  out. 133 pings are dated 29/02/1801, a day its anonymisation invented. 22 % of speeds are missing.

**What the bench changes in the design:**
- the port tier can be any independent list (GFW, GISCO), points buffered 1-2 km, with learned ports as the fallback;
- every duration rule (minimum stay, gap, time budget) scales with the ping interval around the call;
- methods that need pings in port are not used alone;
- in sparse data, a vote of methods is worth having;
- CNR's per-ping rule now has a C++ port in ramb, uncommitted. It reproduces the published code on the Italian,
  Adriatic and Danish data, and runs Iceland 2018 in under a minute.

## 4. The design (proposal)

A generic voyage finder, with Iceland as one configuration of it.

### 4.0 The cascade

The maintainer's outline (2026-10-19), put in order. A voyage is a vessel's movement from a stay at one port to a stay
at the next. Defining one is not a single method but a cascade of rules of provenance.

**A voyage has five attributes:** the vessel, `pid1`, `T1`, `pid2` and `T2`. Each attribute carries a value, a basis
and a precision. A trip is a declared fishing trip, linked to one voyage or more.

**The inputs.** Each is optional, and each fails in its own way:

| input | gives | how it fails |
|---|---|---|
| logbook trips | `T1`, `T2`, sometimes the ports | dates without times; `T2` the expected arrival; values missing; trips missing; one sea trip split by day; a recorded value can still be wrong (maintainer, 2026-10-19) |
| landings | `T2` as a date, `pid2` | the date is the weighing or the sale, not the arrival (plan 025); a catch trucked from another port |
| pings (AIS, VMS, STK) | position over time | whack pings; silence in port (STK stops at entry, before delivery); gaps at sea from coverage, faults or a transponder switched off; the wrong vessel |
| port events (STK `I`/`U`) | arrival, departure | flicker and duplicates; poor before 2017 (decision 059) |
| a port list | where "in port" is | complete for one country and missing for others; points or polygons, of mixed accuracy |

**The steps.** Each step falls back from the best source it has, and records which one answered:

- **A. Ports**, where a vessel can be in port. Best first:
  - curated polygons, with a departure radius per port;
  - other lists (GISCO, EMODnet, OSM, vmstools, GFW anchorages);
  - ports learned from the track, where silences and still pings begin and end;
  - a coastline band (§3.8);
  - none.
- **B. Stays**, when the vessel was in port. Best first:
  - pings in the port spanning the minimum stay;
  - a silence that begins at a port and could have been spent there (§4.1);
  - an arrival and departure event pair;
  - a record that confirms a call the track can reach (§4.2).

  `T_in` and `T_out` are kept as intervals, from the last ping at sea to the first evidence in port.
- **C. Voyages:** the sea between two stays. Each gap at sea gets a class, and open ends are flagged, never dropped
  (§4.7).
- **D. Logbook trips with no track:** the declared trip is the voyage, with basis `recorded`. With no `T1`, the
  vessel's previous landing bounds it.
- **E. Link and reconcile** (`docs/one_flow.qmd`, step 1). This is a link, not a fallback.
  - Trips, landings and voyages are linked many-to-many.
  - Each attribute is chosen by precision, and the declared value is kept beside the chosen one.
  - The output is the reconciled trip table, never fed back into the declared match.

The same, attribute by attribute:

| attribute | 1st | 2nd | 3rd | else |
|---|---|---|---|---|
| `T1` | the track: the end of the stay before | the logbook's `T1` | bounded by the previous landing or voyage | none |
| `T2` | the track: the start of the next stay | the logbook's `T2` | the landing's date (plan 025: the first weighing bounds it, Iceland 2007-2020) | none |
| `pid1`, `pid2` | the stay's port: listed, else from another list, else learned | the landing's or logbook's port | the closest port in reach of an open end (§3.8, the CNR rule) | none |

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
- **A recorded value can be wrong** (maintainer, 2026-10-19), the logbook's above all. So no record is the truth that a
  method is judged by. §4.8 scores every record source against the others.

### 4.3 Beyond the port list, and without one

Step A of §4.0. Each tier gives the stay's port a basis: `listed`, `other_list`, `learned` or `coast`.
- **Other lists:** the polygons of `ports.fgb` that are not `einar` would take the foreign calls of §3.7 item 2. This
  is ask g.
  - Transits such as the Kiel Canal, and anchorages, then need the minimum stay, or a record, to count.
- **Learned ports:** for fleets with no port polygons, which is much of the world's small-scale fishing.
  - A candidate port is a place where silences or still pings begin and end, near the coast. `docs/one_flow.qmd`
    already names this.
  - The stay's port is then `learned`, not listed.
  - Many vessels decide a port, not one (§4.8).
  - The false ones to expect: anchorages, shelter, canal queues and fish farms (§3.7 item 7).
- **A coastline band:** the last tier, as in iapesca (§3.8). It must not cut inshore fishing that never leaves the band.
- **No guard is silent.** With no port list and no coastline, the function learns ports and says so. It never returns
  one voyage per vessel and year without a word (§3.7 item 1).
- **Distances in metres,** in a projection local to each port, not degrees (§3.7 item 8).

Learned ports and the coastline are generic work that Iceland does not need. Ask e puts their scope.

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
- **The track** adds the gear's kind where no record gives it (TODO 86).
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
| ports beyond the list (§4.3) | a new `rb_` step: other lists, learned ports and the coastline, each with a basis, and a message when it falls back | the other sources of `ports.fgb` (ask g) |
| the cut (§4.7) | `rb_cut_trip_voyages`: no cut at New Year, short voyages labelled, open ends and gap classes | `ais_voyage.R` keeps the year as a partition only |
| an open end's port | the CNR rule as the last tier for `pid1` and `pid2` (§3.8) | the same |
| reconciled trips (§4.0, E) | a new `rb_` step (plan 013's `rb_reconcile_time`): one row per voyage or declared trip, each attribute with value, basis and precision | logbook trips, landings and voyages passed in |

Every case gives the same output (`docs/one_flow.qmd`): the columns are the same, and the `basis` says what filled them.

| data | stays from | voyage gear from |
|---|---|---|
| pings only | the track | the track's pattern, or none |
| pings with no port list | the track, at learned ports or the coastline (§4.3) | as the row it otherwise matches |
| pings and landings | the track, confirmed by landings | the landings |
| pings and logbooks | the track, confirmed by trip ends | the logbook stations |
| all three | as above | the landing first, then the logbook |
| records with no pings | none: the declared trip is the voyage (§4.0, D) | the records |

### 4.7 The cut: open ends, short voyages and gaps at sea

Step C of §4.0, so that every fix keeps a voyage (§3.7 items 3-6):
- **No cut at New Year.** A voyage runs across 31 December. The year stays a partition of the files, not a boundary
  of a voyage.
- **Short voyages are kept and labelled.** A voyage of few pings keeps its fixes, its `n_pings` and a label, so a
  consumer can leave it out. None of its fixes is left without a voyage.
- **Open ends are flagged.** A voyage with no stay before or after it, at the start or end of a vessel's series, says
  so. Its port may come from §4.0's last tier, with that basis.
- **Each gap at sea of 2 h or more gets a class:**
  - `coverage`: a gap usual for its distance offshore, receiver and year (TODO 89);
  - `possible_call`: long enough to sail to a port, stay the minimum and sail back, at §4.1's steaming speed. Only a
    record (§4.2) or a learned port makes it a stay;
  - `dark`: neither, a vessel silent at sea.
- **Long voyages then sort themselves.** A long voyage with no `possible_call` is a long trip (§3.7 item 5).

### 4.8 Robustness: methods, inputs and witnesses tested against each other

The maintainer (2026-10-19): the Icelandic data can test how robust each method is. The test takes inputs away, and
runs other groups' methods on the same pings. The same test can show whether a combination of methods is more robust
than any one of them.

**The witnesses.** In Iceland a stay or a trip has several sources, kept apart by who records them:

| witness | source | what it gives | recorded by |
|---|---|---|---|
| logbook | `afli`, `fs_afladagbok`, ERS (`dw_aflaskeyti`, plan 026) | trip `T1`, `T2` and ports, at each schema's precision | the skipper |
| landings | `agf`/`lods` (plan 007), `ask` (plan 025) | port and date. The first weighing bounds the arrival to the hour, 2007 to July 2020 | the weighing at the port, for the Directorate |
| STK port events | `tilk_stk`, 5.9 M | arrival and departure at a port; good from 2017 (decision 059) | STK |
| STK voyages | `tilk_stk_allt`, 3.19 M | port-to-port voyages, paired from `tilk_stk`, so not a second witness | STK |
| Coast Guard notifications | `tilk_vss`, 2010-2013 | calls to the traffic service (plan 022) | the Coast Guard |
| other AIS feeds | ASTD, `astdB`, EMODnet, GFW | pings in port, where STK falls silent | other receivers |

**The yardstick.** A stay is *witnessed* where two independent witnesses agree on the vessel, the day and the port, or
its neighbour (§3.7 item 11). No single source is the truth.
- **Leave one witness out:** each witness is scored against the others in the same way as a method. That includes the
  logbook, whose recorded values can be wrong (§4.2), so its errors are measured rather than assumed away.
- **STK counts once:** its events and its voyages are one witness (§3.7 item 9).
- **The `einar` polygons** are hulls of STK's `I` pings, so the port-list scenarios also use other sources' polygons.

**The methods,** each run on the same cleaned pings:

| method | from | needs a port list | rule |
|---|---|---|---|
| `stays` | ramb, fishycode now | yes | §2 |
| `stays` with the time budget | §4.1 | yes | §4.1 |
| `runs` | ramb; the predecessor repos | yes | every run of pings in a port cuts |
| Danish, `jepol` | DTU Aqua, the ICES data call; ramb | yes | first ping out to first ping back; short voyages dropped, long ones split at the longest gap |
| Irish | Marine Institute (WKSSFGEO) | no | a gap of 2 h or more ends a trip |
| Italian | CNR (WKSSFGEO) | yes | 4 pings within 1 km of a port under 6 kn; an open end to the closest port within 50 km |
| iapesca | Ifremer | ports, or a coastline | a buffer around the ports or the coast; slow pings there are stops; 1 h minimum |
| learned ports | §4.3 | no | a place where many vessels stop (below) |

- **Outside code is run as published,** from its own checkout or package, in scratch. None of it is copied into ramb or
  fishycode. A method chosen for ramb is rewritten there with attribution (decision 078).
- **Where each method runs:** iapesca and the CNR code work one vessel at a time, in memory. They run on a sample of
  vessel-years drawn across years, fleets and ping densities. ramb's methods run on all the data.

**Learned ports from many vessels.** With no port list, a place is a candidate port where many vessels stop or fall
silent, and stay, in the same small cell (an H3 cell, or a cluster of stop positions). No single vessel decides it.
- A stop that only one vessel ever makes is anchoring, shelter or fishing, until a record says otherwise.
- The count of vessels also checks a stay found any other way: a stay at a place no other vessel uses is suspect.

**The scenarios.** Each changes the inputs:

| scenario | what is taken away or changed |
|---|---|
| S0 | nothing: today's inputs |
| S1, no records | no logbook or landings, which are kept only for scoring: the track and the ports alone |
| S2, no port list | the track alone: learned ports, the Irish rule, iapesca's coastline |
| S3, ports by source | `einar` only (now); each other source alone (GISCO, `jeppe`, EMODnet, OSM, vmstools, GFW anchorages); all sources; all but `einar`, which is what an analyst outside Iceland would have |
| S4, ports by share | 25, 50 and 75 % of the `einar` ports dropped at random; the ports with least traffic dropped |
| S5, thinned pings | dense AIS thinned to 10 min, 1 h and 2 h, as VMS; pings in port removed, as STK does |
| S6, whack points | without the whack filter, as other people's data may arrive; with it, as now; with it and the residue of §3.7 item 12 removed |

S5 draws on the vessel-years with dense pings from the other feeds, the well-recorded part of the data. Their result at
full density is the reference that the thinned runs are scored against (AGENTS.md: each path's error is measured on the
well-recorded part).

**The measures,** per method and scenario, by year and fleet:
- witnessed stays found at the right port within a day, and within the hour where a first weighing or an STK event
  times them;
- stays that no witness supports, by port and kind (anchorage, shelter, canal, fish farm): the false ones;
- voyages per vessel-year, against landings per vessel-year;
- the voyages' `T1` and `T2`, against the witnessed times;
- fixes without a voyage, voyages cut at New Year, and long voyages (§3.7 items 3-5).

**Combining methods.** Three combinations are scored like the methods:
- a vote: a stay found by at least k of n methods;
- the cascade: in each case, the best method the inputs allow (§4.0);
- the union, as an upper bound on what can be found.

The questions:
- Does a combination beat the best single method in every scenario, or only in some?
- Does the methods' agreement predict that a stay is witnessed? If it does, the agreement can be the stay's precision
  column.

**External example data** (maintainer, 2026-10-19). Other fleets' public data test the methods outside Iceland, where
others recorded the trips. Profiled 2026-10-19:

| data | where | what | trips to score against | ports | in ramb |
|---|---|---|---|---|---|
| `tacsat`, `eflalo`, `harbours` | vmstools 0.77 (GPL ≥ 2) | VMS of 291 vessels, about 2 h apart, dates shifted to 1800-1801; logbook trips of the same vessels | 3,147 logbook trips with departure and landing harbour and time; 83 % of the pings fall inside one | 3,839 harbour points with a range; 34 named in the logbook | no, and not to be copied: read from vmstools |
| `VMShf` | vmstools | 702 high-frequency VMS pings | none | none | no: not to be distributed without the author's permission; read from vmstools |
| `positions`, `harbours` | iapesca 0.1 (GPL) | 1 vessel, 8 trips, 15 min apart, 2021-2022 | 8 trip ids | 1 polygon | no, and not to be copied: read from iapesca's checkout |
| `example_data_AIS.csv`, `harbours.rds` | WKSSFGEO (MIT) | 14 Danish vessels, 10 s apart, 2012-2020, fishing labelled | none in the file; the CNR folder (below) holds two methods' trips | 942 polygons | yes: `dansk`, `dansk_harbours` |
| `passive_vessel_ais_adriatic_2017.csv` | WKSSFGEO (MIT) | 1 Adriatic static-gear vessel, 6 min apart | 10 trip ids | none | yes: `wkssfgeo_adriatic_passive` |
| `data/Denmark.rds` | WKSSFGEO (MIT) | Denmark's land, one multipolygon (EPSG:32632) | none | a coastline for the Danish tracks: iapesca's last tier (§3.8) | yes: `wkssfgeo_denmark` |
| `galdelli_pulcinella_tassetti/data` | WKSSFGEO `dev_branch` (GNU GPL 3, the folder's own licence) | `datatest.csv`: 6 vessels, 6 min apart; the Danish tracks cut into trips by CNR's method and by jepol | CNR 94 trips, jepol 90, on the same Danish pings | 1,415 Mediterranean harbour polygons; its second list is these and the Danish ones | yes: `wkssfgeo_cnr_ais`, `wkssfgeo_cnr_dansk_trips`, `wkssfgeo_cnr_dansk_ping_trips`, `wkssfgeo_cnr_med_harbours` |
| `IRL_FPO`, `IRL_KY22` | WKSSFGEO2 (MIT) | Irish pots, 1 vessel, 6 min apart, labelled; gillnets, 4 vessels, 10 min apart. Dates and positions anonymised | 6 and 136 trip ids | none: the positions are moved | yes: `wkssfgeo2_irl_pots`, `wkssfgeo2_irl_gillnets` |
| `PT_IPM_2017_GP2` | WKSSFGEO2 (MIT) | Portuguese pots and dredges, 8 vessels, 30 s apart, labelled | 8 trip ids | none | yes: `wkssfgeo2_pt_gps` |
| `IT_CNR_2023_GP` | WKSSFGEO2 (MIT) | Italian pots, 1 vessel, 60 s apart, sets and hauls labelled; anonymised | 13 trips | none | yes: `wkssfgeo2_it_pots` |
| creel, Portuguese GPS, Malagasy gillnets | Dryad (CC0), WKSSFGEO (MIT), IRD (CC BY 4.0) | small-scale tracks, 60 s, labelled | one trip per vessel (creel), else none | none | yes: `creel`, `wkssfgeo_pt_gps`, `ird_mg_gillnet` |
| `anonymized_dataset.rds` | CNR-IRBIM, GitHub `PamelaLattanzi/softwarex_paper` v2.0 (GNU GPL 3), for Lattanzi et al. 2026, SoftwareX; `$FISHYDATA/raw/external/cnr` | Italian passive-gear vessels, 5, 30 s apart, fishing labelled by hand; dates and positions anonymised, positions in metres with no CRS stated; speed and the other features scaled 0-1, no gear | 846 trip ids | none: the positions are moved | no, not decided: read from `raw/external/cnr` |
| `mmc3`-`mmc6` | Mendo et al. 2023, Ecological Indicators, supplements (CC BY 4.0); `$FISHYDATA/raw/external/mendo2023` | soak-time code in R (two PDFs) and its samples: Peruvian gillnets, 3 vessels, 3 min apart; a Danish gillnetter on 4 days, 1 min apart. Labels are a random forest's, not observed; metres with no CRS stated | 3 and 4 trip ids | none | no, not decided: read from `raw/external/mendo2023` |
| `gps_data.csv`, `ssf_functions.R` | CNR-IRBIM, Zenodo 5783920 (CC BY 4.0), for Pulcinella et al. 2022, Sensors; `$FISHYDATA/raw/external/cnr/zenodo_5783920` | one vessel's raw tracker log, Ancona, November 2021, 60 s, real positions, with power, satellites and the device's geofence events; no labels | none: its R code cuts trips by gaps of 45 min and by power-on | the device's 33 geofence entries and exits | no, not decided: read from `raw/external/cnr` (decision 148) |

How the bench uses them:
- **Every method runs on every set,** scored against the set's own trips. Where the positions are anonymised, no real
  port list can apply, so those sets are scenario S2 by nature.
- **vmstools' VMS and logbook** are the ICES data call's situation: pings about 2 h apart, logbook trips with harbours,
  and a list of harbour points. They test S5's thinned pings on real VMS, not on thinned AIS.
- **The CNR folder's two trip tables are a check of the bench itself.** Run as published, CNR's method and jepol must
  give back its 94 and 90 trips on the Danish tracks before their numbers on the Icelandic data are believed. ramb's
  trips vignette already compares `runs` with `jepol` on one of these vessels.
- **Each harbour list (vmstools, the Danish polygons, the two Mediterranean lists)** is a port list from another
  source. They add to S3.

**Into ramb** (maintainer, 2026-10-19). *Done the same day: ramb `b93d9fe`, pushed and installed here.* The WKSSFGEO
and WKSSFGEO2 sets that ramb lacked are in its `inst/extdata` as parquet under Git LFS, nine files, made by
`data-raw/wkssfgeo_examples.R`. fishycode reads every one through ramb (`rb_read_example()`), never from the workshop
repositories. Each is documented as the present sets are:
- an entry in `inst/extdata/data-dict.yaml` with every column (name, type, units, description, range), its **Cite:**,
  **Licence:** and **Changes:** lines, and its `origin`;
- its sources in `inst/REFERENCES.bib` (the workshop reports, and the CNR authors for their folder) and a line in
  `inst/COPYRIGHTS`. Both repositories are MIT, Copyright (c) 2021 and 2023 ICES Expert Groups, except the CNR folder,
  which carries its own licence, the GNU GPL version 3, as ramb's GPL (>= 3) allows. Its method paper (Galdelli et al.
  2019) was checked against Crossref;
- a `data-raw/` script that reads the source at a fixed commit. `data-raw/data_dict.R` then stamps the entry into the
  file's metadata, and Git LFS holds the file, as now.

Left out, each for a reason:
- vmstools' and iapesca's data are not copied into ramb (maintainer). The bench reads them from those packages.
- Already in ramb under other names: `track01` (WKSSFGEO `pkg` branch) is the Danish tracks, `dansk`; `code_example/`
  is the creel tracks, `creel`.
- Not data: the CNR folder's `parameters.csv`, `centroids.csv` and random-forest model. Its coastal ban zones belong to
  gear, not to voyages.
- The CNR folder's `ices_med_harbours`, being `med_harb_gsa` and `dansk_harbours` together (checked in the script).

GitHub's source archives of ramb hold the LFS pointers, not the data, so `remotes::install_github()` gives a ramb whose
`rb_read_example()` stops. Until the repository includes LFS objects in its archives (a setting on GitHub, the
maintainer's), ramb is installed from a clone: `remotes::install_git("https://github.com/einarhjorleifsson/ramb.git",
git = "external")`.

**Whacks out first** (maintainer, 2026-10-19). The flow marks the whacks and sets them aside before it seeks a stay,
and the bench keeps that order. The whacks the speed filter leaves (§3.7 item 12) belong to the filter, not to the voyage
step:
- STK's event rows near a harbour, at speeds a vessel can make;
- the generic filter, for data with no such marker, is TODO 88;
- the hand reload of October 2026 is TODO 87.

## 5. Steps

1. **Measure exactly.** Replay `rb_find_trip_stays` on every voyage with a missed call (§3.2-3.4), not only those with
   several trips. Classify each miss by the rule it fails, with the polygon distances `port_stay` uses. This settles
   the approximations above. Read-only. *Done 2026-10-19, §3.6.*
2. **The robustness bench (§4.8),** read-only, in scratch, on pings with the whacks set aside (§2):
   - first, the WKSSFGEO and WKSSFGEO2 sets join ramb, documented (§4.8, "Into ramb"), and that ramb is installed
     here. *Done 2026-10-19, ramb `b93d9fe`*;
   - the witnessed stays;
   - the CNR folder's two trip tables reproduced, as the bench's own check;
   - then the methods across the scenarios S0-S6, on the Icelandic data and on the external sets;
   - then the combinations.

   *Done 2026-10-19, §3.9.* Not run:
   - iapesca's trip finder. Its published code took over 13 minutes on 4 cores for a sample of 100 Icelandic vessels
     and was stopped (maintainer); a faster version is being tested in a separate session. Its coastline mode, which
     downloads a coastline, was not tried either.
   - CNR for 2010: its R loop took 65 min for 2018, and ramb's C++ port is not installed yet.

   Its results choose what steps 3 and 4 build. The time budget and records as evidence enter it as methods.
3. **The time budget in ramb,** with the cut of §4.7 and, if ask g says so, the other lists of §4.3. Tested in scratch
   on the Icelandic data. Measure:
   - stays gained and lost, and voyages split;
   - the landing coverage of §3.4, with a tighter window;
   - the share of the 11,933 voyages left with a call inside;
   - stays added with neither a landing nor a logbook end, by port (anchoring, waiting): the false-positive check;
   - the counts of §3.7 items 2-5 again: foreign calls, fixes without a voyage, voyages over New Year, and long
     voyages by the class of their gaps.
4. **Records as evidence** (landings, then logbook trip ends), with step 3's measures, and the records the track
   contradicts listed for the key review.
5. **The gear set** (`voyage_gear` in ramb and fishycode), landing first. Measure fishing flags and catch against
   now: the catch must stay equal in every vessel-year (kg in = kg out).
6. **Simulated scenarios in ramb's tests:** dense AIS, hourly VMS, sparse STK; landings only, logbook only, neither;
   two gears in one voyage; a logbook that splits one sea trip by day; no port list; a call at a port not on the list;
   a voyage over New Year; a long gap at sea out of reach of any port. Each runs on ramb's example data (§4.8) as well
   as on made-up data.
7. **Apply to Iceland and rebuild,** on the maintainer's go. Check the landing coverage, the voyages with several
   trips, the day-split trips left on one voyage, and fingerprints before and after.
8. **Describe it** in `docs/one_flow.qmd`, steps 1 and 3, for WGSFD, with the bench's errors per method and data
   situation.

## 6. Checks (done when)

- Every landing by a vessel with AIS that day falls on a stay at its port, or is listed with the reason the track
  gives. The landings with no stay (§3.4) fall well below 0.8 %, most of all in 2007-2010.
- Few voyages with several trips still hold a port call of 2 h or more inside them; each one left is explained.
- `voyage_gear` gives the same result on every run, and a voyage can carry several gears.
- No fix is left in neither a stay nor a voyage, and no voyage is cut at New Year.
- Every gap at sea of 2 h or more carries a class.
- With no port list, the function learns ports and says so.
- The bench of §4.8 gives each method's error in each scenario, each witness's error against the others, and says
  whether a combination beats the best single method.
- ramb's tests cover the scenarios of step 6.
- The catch is equal in every vessel-year before and after.

## 7. Asks

a. **May a landing make a stay** where the pings alone fall short of the minimum, given the track reaches the port
   that day? Or should it only confirm, and flag?
b. **The steaming speed for the time budget:** one value (6 knots), or each vessel's own from its track?
c. **A call under 2 h on a landing day:** a stay, or a call of its own, which cuts the voyage but is labelled short?
d. **Voyage gear:** the landing first for every voyage, or only where the logbook stations disagree?
e. **Learned ports for fleets without a port list:** built in ramb in this plan, or in a later one? The bench tests a
   scratch version either way.
f. **The logbook's day trips on one sea trip:** keep them as several trips on one voyage, as now, or merge them into
   one trip in the reconciled trip table?
g. **Ports outside Iceland and the Faroes:** take the other sources' polygons in `ports.fgb` as a second tier now
   (§3.7 item 2, §4.3), or wait for learned ports (ask e)? The bench's scenario S3 measures what each source adds.
h. **Landing port code 159:** 7,305 landings of 145 vessels in 2007-2026 carry it, and the Directorate's port list
   gives it no name. Is it a port abroad, fish sold in containers, or something else (§3.7 item 2)?
