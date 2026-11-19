# 329 — An Icelandic census for ramb's and ogis's examples: the north-west in two tiers, July to September 2017

*2026-11-18. Asked by the maintainer through another session: an Icelandic example of AIS, logbooks and landings, of
large- and small-scale fisheries, for ramb and ogis to show the whole flow on. The maintainer set the year (the densest pings),
the gears, the anonymity's terms and "total catch only". In the same evening the maintainer added, in order:
- a **full census** of an area and a period, not a sample of vessels;
- the hard edge is the **spatial** one;
- a quarter may be all a public repository holds;
- thinning dense AIS, suggested and withdrawn (none was done);
- the frame of **a national institute's data**: detail on its own north-west fleet, and from the national AIS provider
  every other ship in its waters with less detail, some landing in its ports;
- PAME's data may be used with the vessels anonymised, MMSI included;
- landing data can be by species, logbook data not;
- the aim: an effort map with its grid effect, the problems ramb, EM4SSF and iapesca solve, and ogis's primary
  examples ("in a sense replace what we have now"). The limit is what GitHub can hold, the period free.

The area, the quarter, the tiers' rules and every number below are Claude's (AI). Claude built and counted them; no
person has checked them. Not published, not added to ramb or ogis, not committed until the maintainer says so
(TODO 202).*

## What was built

`products/exports/ramb_example_iceland.R` (its dictionary entries in `ramb_example_iceland_dict.R`) writes
`$FISHYDATA/exports/ramb_example_iceland/`:
- eleven parquet files in ramb's layout, each stamped with its entry of `data-dict.yaml` as ramb's `data-raw/data_dict.R`
  stamps its own;
- `summary.yml` with every count;
- the report, `README.md`.

The key to the store's ids is beside the folder, never in it. 87.0 MB in all, every file under GitHub's 50 MB warning:
- 7,312,487 pings in three monthly files of 21.7, 33.4 and 30.4 MB;
- 6,012 logbook trips and 11,237 hauls;
- 20,584 landing rows (8,504 landings by gear and species) and 5,969 trip-landing links;
- 1,364 vessels and ships, 42 species, 201 harbours, and IS 50V's coast.

- **2017**, measured: 275 pings a vessel-day in the trail (220 at sea), the most of 2007-2026.
- **Two tiers and the unmatched.** The area is 20.5-26.0 W, 64.8-67.2 N (the Westfjords, Breiðafjörður, Snæfellsnes's
  north coast).
  - **National:** the 573 vessels of the north-west's home districts (ÍS, ST, BA, SH, DA) active in the quarter, with
    everything in their windows wherever they went: every ping, logbook trip, haul and landing.
  - **Other:** 254 other register vessels, with their pings inside the area and the quarter only, and their landings
    in its ports.
  - **Unmatched:** 537 MMSIs of PAME's feeds no register vessel matches, with their pings inside the area and the
    quarter: 377 ships (cruise, cargo, tankers, foreign fishing vessels, and 165 Icelandic MMSIs never linked, a
    median of one ping each), 92 aids to navigation, 66 invalid numbers and 2 other stations. Their kind is read from
    the MMSI's layout before the MMSI goes (`mmsi_kind`).
- **July to September.** Measured by month for this design (`two_tier_months.csv` in the study).
  - Every gear asked for has at least 50 national trips: handline 4,065, longline 841, seine 355, lumpfish net 335,
    dredge 117, shrimp trawl 84, trawl 80, cod net 64, pots 50 (one vessel). Sea angling has 1,241 landings by 43
    vessels.
  - Q3 is stronger than Q2 in pots, dredges and sea angling, and holds ASTD's missing July as a feed outage
    mid-quarter. Q2 is stronger in lumpfish and cod nets.
  - A half year would be about 180 MB.
- **The national windows:** the quarter, widened until every voyage and logbook trip overlapping it is whole, capped
  at 31 days beyond it, then 12 hours each side. 39 trips and 70 voyages cross the quarter's edges, and 9 windows reach
  the cap.
- **Raw where the flow begins.**
  - The pings are the union's (preprocessing), not the trail's, and PAME's as staged for the unmatched.
  - The logbook's trips and hauls are as preprocessing writes them. The trip-landing links are the declarations'
    match (`lid_map`); the flow's further links by the track (`trip_landing`) are left out.
  - The GPS loggers' positions are left out (142,795): fishydata puts them on the cleaned track (decision 196).
- **The coast:** IS 50V's land and skerry polygons (natt.is, open data), for the land test and the maps.
- **Anonymised:** every vessel and ship 1-1,364 in random order, records renumbered, identifiers left out (MMSI
  included), the logbook's catch as totals, the landings by species. Positions, times, ports and the national
  vessels' kW, length, tonnage and home district are kept as recorded.
- **ramb 2026.11.9.4 runs on August's file as shipped**, in seconds:
  - 112,278 cross-feed copies and 7,163 impossible positions flagged;
  - 3,942 port calls of 504 national vessels from the shipped harbours.

## What it found

- **The effort map.** The store's own fishing label, as a density test only, gives the national fleet 654 k fishing
  pings and 42 k hours in 11 gears: 53 ICES rectangles, 1,255 c-squares of 0.1°, 3,794 of 0.05°, 44,445 of 0.01°
  (`figures/effort_grid_test.png` in the study). An earlier draw of it took 0.05° × 0.025° cells for c-squares,
  which are square in degrees (the maintainer's correction); redrawn.
- **The trawls' grid effect, from the example itself.** The shipped tables went through ramb's chain: copies and
  impossible positions out, speed derived per stream, pings on their logbook trips, the gear's speed range, capped
  intervals.
  - Fish trawl: 4,657 hours on 77 ICES rectangles, 2,397 c-squares of 0.05° (58 % under an hour) and 20,130 of 0.01°.
  - Shrimp trawl: 8,118 hours on 39 rectangles, 1,061 c-squares of 0.05° and 11,412 of 0.01°.
  - Cell by cell at 0.05° the chain agrees with the store's label (log-hours correlation 0.92 and 0.91).
  - (`scripts/trawl_effort_test.R`, `figures/trawl_effort_test.png`.)
- **Reproducible:** a rebuild of the unchanged store gives every table and the key row for row.
- **ogis 2026.11.18.16 draws it** (`scripts/ogis_test.R`): ten vessels through the same chain, `og_tracks()`, served
  with no console error, the effort at every grid ogis offers. It found two defects of ogis's, not fixed here:
  - `og_tracks(pings = x)` without a map stops;
  - a vessel id with a space refuses every effort tile (HTTP 400), as the server's `utils::URLdecode()` leaves the
    query's `+`.

  A bundle of ten vessels is 172 MB.
- **The problems are in it,** counted in the report: copies across feeds, ties, impossible positions far from
  Iceland, pings on land outside harbours, missing speeds, VMS by receipt, a feed outage, gaps, port stays, trips
  across the period's edges, logbook dates against AIS times, static-gear hauls with set and haul times (1,097),
  landings without logbooks, vessels without records, and MMSIs that are not vessels.
- **ASTD's missing July 2017 is known** (`curate/corrections/astd_missing_months.yml`, decision 079).
- **Findings a search of the record did not turn up:**
  - **2017's density is EMODnet's:** its extract is 44 % of the set's pings, and each feed alone reports every 5-10
    minutes.
  - **34,099 national pings fall on IS 50V's land outside every harbour polygon.** They are most likely quays and small
    harbours; not checked.
  - **The seaweed barges' voyages run four to six weeks** by the flow's port calls; not checked why.
  - **The unmatched MMSIs hold 165 Icelandic MMSIs never linked to a vessel** and 92 AIS aids to navigation.

## Not settled

- **The anonymity is shallow.** A track can be matched to public AIS, and power, length and tonnage narrow the public
  register to one hull. Once a vessel is known, its logbook content is attributable to it. A release rests on an
  agreed basis with MFRI and Fiskistofa, not on the anonymisation (the report lists ways to weaken the link).
- **The feeds' terms:** PAME's use with anonymised vessels is as the maintainer stated. STK's and the 2017 EMODnet
  extract's terms are not recorded in fishydata, nor the harbour lists' licences (OpenStreetMap's are ODbL).
- **The choices are Claude's:** the area, the quarter, the national districts, the cap and margin, `mmsi_kind`'s
  rules, and leaving out the GPS loggers and the flow's links.
- **Where it would live:** 87 MB in ramb's `inst/extdata` would come with every install of ramb (LFS). A data
  repository of its own, or release assets, is the alternative; the maintainer's call.
- **Stable ids across versions:** the ids are drawn from a seed over the sorted census, so any change of the census
  renumbers them, and the seed would be public with the script. A key kept as a ledger (a number never moves, new ones
  appended) would make them stable and the seed irrelevant; not built.
- **The stamps read `fca550a-dirty`:** the build ran before its script was committed. Rerun it after the commit.

## Superseded the same evening: the July census of Breiðafjörður, kept for the reasoning

The first build was one month (July 2017) and one box (22.0-24.1 W, 65.0-65.8 N). It was the smallest of 200
box-by-month censuses holding every gear, with the box selecting vessels and never cutting them. It held 9.2 MB:
684,064 pings of 310 vessels and every gear, with pots 18 trips of one vessel and shrimp trawl 7 trips.

The maintainer's framing of the national institute replaced its single tier. His aims for effort maps and ogis
replaced its narrow month and box. July alone has no foreign ships at all, since ASTD, the only feed that holds them,
is missing that month. Its search (`search_box_month.csv`) and its first builds' logs are in the study.
