# 082 — The curated wreck and aid lists: one list each from several witnesses, apart from the place names

**status:** executed — moved out of plan 074 (its step 9 and asks m, o and p) on 2026-11-20 at the maintainer's word
("I thought these kind of things were now in a separate entity that has nothing to do with placenames. If not, fix it"); the aid list built 2026-11-16 (plan 074 ask p: "Standalone in layers"), the wreck list ported into fishycode
2026-11-19 (decision 332); both standalone scripts in fishycode's layers, run by hand outside the targets flow; the place
names take them as witnesses, and the map's one table (`marine_feature`, decision 332) shows them beside the names, told
apart by `type` · **see:** plan 074 (the names, its step 9's islands and skerries), plan 075 (the harbours, as landing
sites), decision 332, `reference/wrecks/wreck.R`, `reference/aids/aid.R`, `curate/checks/wreck_accounting.R`,
`curate/checks/aid_accounting.R`, `R/curated_list.R`, the study `$FISHYDATA/archive/2026-11-11-named-features/` (its 84-98)

Moved by Claude (AI) on 2026-11-20. The text is plan 074's as it stood, written with AI assistance (Claude) and not checked
by a person; a record's own text from the internal lists is no longer quoted. The internal lists (Háskóli Íslands' and a
skipper's plotter) and every attribute taken from them stay internal: counts here, never their names, positions or text.

## 1. The lists

A wreck and an aid to navigation are entities of their own, not place names: a wreck is a thing on the seabed with a
history, an aid a thing in the water or on a shore with a characteristic. "Ergo Lights and beacons are separate from
örnefni" (the maintainer, 2026-11-16). Where one stands on a named place (a lighthouse on an island), the aid or the wreck
carries the named feature it lies on (`on_feature`, decision 332); the place keeps its name.

Both were added to plan 074 on 2026-11-16 as its step 9, **curated lists from several witnesses**, at the maintainer's
word: "we have a list of wrecks in the new data. now these wreck list can by matched against any of the other wreck list we have in already gathered datasource. This
way we have more than one witness -> here the aim is to come up with a curated wreck list. similar as we will have a curated
harbour list, curated list of lights, beacons, curated sediment list (some of those infos will come from the sea-charts)".
Each a reference table of fishycode (reference/<list>/ to curated/reference/<list>.parquet, as plan 075's landing sites),
every source staged as delivered, every record in one outcome: the same thing seen by several witnesses (matched by place
within a distance of each witness's precision, and by name where both name it), seen by one, or witnesses in conflict; its
position and its attributes from the best witness for each, with the basis beside (as `basis` everywhere); internal sources
kept internal (fishycode's rules: no internal name in the repo, persons by counts). The names use them as witnesses: a
wreck's or an aid's name and position, a harbour's, a ground's or a deep's bottom.

   - **Wrecks** (measured): Landhelgisgæslan's 279 (on ÍSOR's map server; its comments carry names and depths), the list
     Háskóli Íslands' researcher shared (80, internal: raw/external/wreck_hi, to be asked before anything is published), SKFI's
     18 named wrecks, ÍSOR's 16 points, 57 diving sites; of the 80, 30 lie within 500 m of one of Landhelgisgæslan's; the 18 are
     all among the diving sites. Joined within 500 m, 344 places: 304 seen by one list, 22 by two, 18 by three to five. Still to
     read: the charts' wreck symbols (INT 1 section K, raw/external/chart_symbols, decision 301's code lists) and their names;
     EMODnet's human-activities wrecks; the plotters' and Trackwell's (internal; outside plan 074, decision 316; the plotter
     taken into the prototype as a witness and Trackwell counted on 2026-11-16, below).
   - **Wrecks, the prototype** (built in the study the same day, its 91 and 92, at the maintainer's word: "Let's go for the
     wreck list"). Two more lists fetched: the UK Hydrographic Office's wrecks as EMODnet Human Activities serves them (283 in
     the box 32 W to 6 W, 59 N to 70 N, Open Government Licence; `dump/emodnet/human_activities.R`) and OpenStreetMap's (22;
     `dump/osm/wrecks.R`). Found on staging: 22 of Landhelgisgæslan's 279 are not its own (symbol 0, coordinates 0 in their
     columns): 19 are copies of the diving map's wrecks or ÍSOR's points, 3 have no original; SKFI's 18 are the diving map's
     folder Flök, at the same places; the diving map's other 39 sites are not wrecks; some of Landhelgisgæslan's IDs and
     comments were stored in Mac Icelandic and read as Windows-1252 (kept as given, a reading beside). Added the same day:
     a skipper's TimeZero plotter (internal, as Háskóli Íslands' list; raw/external/ornefni/ and raw/external/vernd_i_hafi/),
     its 2021, 2022 and 2025 exports one witness: 856 marks, 724 of them wrecks by the plotter's wreck icons (310, Landhelgisgæslan's list read into it, 149
     of its 182 within 1 m of an LHG record; 10, the owner's own) or by name, 132 not (depth marks, an anchor and chain, marks
     with neither a wreck icon nor a name); 659 copies (511 at Landhelgisgæslan's records, 2 at UKHO's, 18 re-marks of an
     icon-310 wreck, 128 earlier states of a mark), 65 witnesses, 59 places known from it alone, 6 joined to other lists.
     Trackwell's ground names hold one that names a wreck (21 hauls of one vessel, no position for the wreck; "Flakið" none,
     the other -flak names banks): counted, not a witness (the study's README has it). 1,611 records in all, each in one outcome: 155 seen by several lists,
     526 by one, 63 in conflict, 696 copies, 171 not wrecks; 625 places (68 with several witnesses, 526 with one, 31 in
     conflict: 27 crowded, 4 years sunk disagreeing, 2 names, 2 a list twice). 13 of the joins between Landhelgisgæslan and
     UKHO lie at the same position (under 1 m): one survey, two lists. The 92 places only the internal lists know (Háskóli
     Íslands' 32, the plotter's 59, both 1), and every attribute taken from them, are internal. Every descriptive field of
     every list is kept, one row a field (the maintainer: keep any "description" information; later sources such as
     timarit.is may add rows, not this plan's job), and all text is UTF-8 (the maintainer). The charts' wreck symbols wait (the
     maintainer, 2026-11-16: "mining the sea-charts again for any wreck information waits for now"). The conflicts are
     listed, not resolved (the maintainer, 2026-11-16: "for now we are not going to resolve conflicts").
     Depth and the date sunk, the same day (the maintainer: "Be careful with units"; the date sunk "as a common variable if
     possible"). Two depths, one column each: the seabed at the wreck and the least depth over it. A text depth is read only
     where its unit is written (metres or fathoms) and a depth word or fathoms say it is a depth, the text, unit and pattern
     beside it. UKHO's two fields and OpenStreetMap's tags are read by their documentation. A number whose unit is stated
     nowhere is listed, not read. Háskóli Íslands' depth column states its unit nowhere. It is read in metres, measured
     against the witnesses and the depth model (the maintainer: "Yes, metres", then "Test HI's depth unit"). Against another
     witness's metres, 18 of 25 pairs agree within 25 %. Against the Olex depth model within 500 m of each position, 33 of its
     41 depths fit only as metres, 6 either way, 1 neither (metres within 1 km) and 1 only as fathoms; that one is flagged and
     left out, not converted. The test's controls of known unit fall where they should: 12 of 12 fathom depths, and UKHO's
     metres as metres or either way in 172 of 185. Of 1,611 records, 407 depths read, 22 ambiguous and 89 not depths (a sinking
     written in the depth's field; a length); 315 places have a seabed depth, 35 a least depth. The date
     sunk is ISO 8601 truncated to what is known (day, month or year), with its precision and basis and the year for sorting.
     In comments it is read only beside a word of loss, in the diving map's prose only within that sentence. 626 records read
     (493 to the day), 40 ambiguous (no year, a decade, a range, an uncertain year, malformed); 289 places have a date.
     Witnesses are compared at their common precision: 6 places differ (5 in the year, 1 by a day). Places now 67 with several
     witnesses, 526 with one, 32 in conflict (27 crowded, 6 dates, 2 names, 2 a list twice); records 152 seen by several
     lists, 526 by one, 66 in conflict.
     The wreck list stays outside fishycode's targets flow (the maintainer, 2026-11-16: "we do not at this moment really
     want this to be part of the huge rebuild / target flow"). *Amended 2026-11-17* (the maintainer: "9 - wrecks go to
     fishycode"): it moves into fishycode's layers as the aids did, standalone scripts run by hand outside the targets flow
     (ask p), the internal lists and every attribute taken from them kept internal; not moved yet. As everything else in
     fishycode: the lists as delivered in raw/external/ (done, dump/), each staged as delivered with the common columns
     (`staging/<list>/wreck.parquet`, sources/), then the join and the best witnesses into `curated/reference/wreck.parquet`,
     its records and descriptions beside (reference/wrecks/), checked by `curate/checks/wreck_accounting.R`, as plan 075's
     landing sites (ask p).
   - **Aids** (lights, buoys, beacons, leading marks, radar beacons): the List of Lights in force (546, its positions exact to a
     hundredth of a minute in 514; the study's 86), Vegagerðin's 101 national lights, the charts' letterings of lights and
     their characteristics (the study's 84), the charts' light symbols (barely read so far); Notices to Mariners
     (Tilkynningar til sjófarenda) for changes since the list's edition.
   - **Aids, the prototype** (built in the study the same day by a Claude session, its 93 and 94; no person has checked the
     counts). Three more lists fetched by fishycode's dump/: OpenStreetMap's seamarks (`dump/osm/seamarks.R`, 495 in the box,
     355 aids; 292 from US NGA Pub. 115 of 2010), LMÍ's IS 50V lighthouses (`dump/natt/lighthouses.R`, 108, accuracy 1-10 m)
     and Wikidata's lighthouses (`dump/wikidata/lighthouses.R`, 130). NGA's own Pub. 115 was not had: its portal was under
     maintenance, and the Wayback Machine's copy (a PDF of 2024-11-30) is the maintainer's to fetch. Found on staging:
     Vegagerðin's 101 lights are the List's own (every Admiralty number shared, positions within the List's rounding, 10 m);
     all 12 of Vegagerðin's wave buoys are in the List as lit special buoys (öldudufl, Fl(5)Y), kept not aids as asked;
     the List gives one number to two lights three times. Measured with the Admiralty number as the test: at 100 m the
     nearest alone joins 14 pairs whose numbers differ and misses 55; the number first, then kind and characteristic, joins
     776 by number, none differing, 6 missed (chosen). The charts' letterings and printed characteristics are labels,
     attached to an aid by characteristic within 5 mm of their box (261) or by name within 10 mm (350); 120 stand alone,
     289 with no aid within 20 mm are readings, not aids. 2,422 records, each in one outcome (1,376 several witnesses, 466
     one, 125 conflict, 3 copies, 452 not aids); 801 places, 737 in Iceland (304 several witnesses, 409 one, 24 in
     conflict). The 25 conflicts are listed: 20 positions farther apart than their digits allow (OSM's Mjóeyri 1.6 km
     and Miðleiðarsker and Skarfaklettur 440 m from the List, Vegagerðin and IS 50V; IS 50V's Málmey 1.05 km from all the
     others), 7 characteristics (Sauðanes Fl W 15s in the List, 20s in Vegagerðin and OSM), 2 lists holding one light
     twice. Most "several witnesses" are one official record seen through copies of several dates; IS 50V is the one
     independent witness of position. Every descriptive field kept (25,039), all text UTF-8, 28 checks hold. The
     maintainer, the same day: "no more fetching" (NGA's Pub. 115 stays unfetched); "wave buoys may help explain gap in
     the effort maps" (a first table, the study's 95, then "do later"); ask m dug into (below); ask p answered (below).

   *Assumed*: that a witness's precision can be stated (Landhelgisgæslan's surveyed wrecks exact, fishermen's snags not;
   the List of Lights' two decimals exact, one decimal approximate); that one list's record is one thing (a wreck may be two
   pieces, a harbour two basins). *Check*: every record of every source in one outcome; the conflicts listed for the
   maintainer.

## 2. Asks (plan 074's, their letters kept)

m. The aids: the List of Lights as their source (position, characteristic, kind), the charts' letterings their labels?
   *Dug into* (2026-11-16, the maintainer: "m - not sure, can you dig in"; the study's 96, by Claude, no person has checked
   it): the witnesses against each other. Position: where the List (1/100 minute), Vegagerðin and IS 50V hold one
   lighthouse (95), Vegagerðin's geometry lies nearer IS 50V than the List in 58, the List in 20, the same in 17 (medians
   4.3 m and 7.5 m): its finer digits are the List's position before rounding. The List agrees with IS 50V within 25 m at
   89 of the 95; where witnesses part, the odd one is OSM (NGA's 2010 positions: a digit at Mjóeyri, 440 m at
   Miðleiðarsker and Skarfaklettur, twelve lights 100-300 m off, harbour lights most) or IS 50V (Málmey 1.05 km).
   Characteristic: Vegagerðin agrees with the List in 100 of 101, OSM in 221 of 227, Wikidata in 26 of 27, the charts'
   printed characteristics in 45 of 59 within 5 mm of a List light (the rest fragments of the read or older editions).
   Kind: the List's parts and OSM's types agree in every joined pair. Labels: a chart's lettering lies a median 2-4 mm
   from its aid on its own chart (367 m on the 1:100 000), a label's place. So the working answer holds with one
   refinement: position Vegagerðin's geometry where it has the light, else the List; the List for characteristic, kind,
   height, range and number; IS 50V, OSM, Wikidata as checks; the charts' letterings the labels.
   *Settled* (the maintainer, 2026-11-16: "Proceed with m"); fishycode's aid list takes its best witnesses so. Proceeded
   with in the study's 98: each light of the names map linked to its aid, so that it has a position apart from its label.
   Of the map's 128 lights, 118 link by their own letterings (12 of them lettered for 2-3 aids, the most lettered taken),
   5 by an aid of their name within 3 km; 5 link to none, the nearest aid of their name 7-29 km off (namesakes elsewhere,
   or a light the List no longer holds). From the label's place to the aid's position: a median 872 m, 84 over 500 m, 43
   over 1 km. 37 aids are lettered only in another feature's name (an island, a point, a shoal: Engey, Grímsey, Hrísey,
   Helgasker's buoy): the feature keeps the name, the aid its position. In the names editor the same day (the maintainer:
   "Yes, in the editor"): the aids at their positions from the curated aid list, a dot each by kind, a line from each to its
   light's name; 618 aids, 110 linked to a name; the 119 only a chart shows have no position and no dot. The names map
   (71) still draws a light at its label.

Asked on 2026-11-16, with the curated lists:

o. *Settled* (the maintainer, 2026-11-16): the conflicts listed, not resolved ("for now we are not going to resolve
   conflicts"); the internal witnesses in, the plotter added the same day, internal like Háskóli Íslands' list; the charts'
   wreck symbols wait. The distance without a knife edge ("Do we really need to do this here - as long as we flag a potential
   issue. I hate knife edge decisions, at least on this one"): records join at 500 m, mutual nearest; two places whose
   witnesses are each other's nearest but lie apart within 1 km, or within the two records' coordinate digits, are flagged
   as maybe one wreck, on both places, never joined, their outcomes unchanged. On the prototype: 29 pairs on 42 places, their
   names agreeing in 6, differing in 3, one side or both unnamed in 20; none beyond 1 km by the digits. Asked: The wreck list's witnesses: every list above with the charts' wreck symbols, and the
   internal ones (Háskóli Íslands' list, the plotters') kept as internal witnesses; which distance makes two records one wreck
   (500 m, or each witness's own precision)? Measured on the prototype with the plotter: 500 m gives 625 places, 31 in
   conflict; 1 km, 602 and 51 (29 more joins, 7 with the plotter; 6 confirmed by names, 3 contradicted, 20 with a name on one
   side or none); 500 m widened by the coordinates' digits (114 of UKHO's 283 to the whole minute), 622 and 31 (3 more
   joins). Before the plotter: 567 and 30; 548 and 49; 564 and 30.
p. *Decided for now* (the maintainer, 2026-11-16: "we do not at this moment really want this to be part of the huge rebuild /
   target flow"): the wreck list stays a standalone script in the study (its 91 and 92), outside fishycode's targets flow.
   Asked: The curated lists in fishycode's reference/ as tables of their own (as plan 075's landing sites), built before the
   names use them; or first within this study?
   *Answered again* (the maintainer, 2026-11-16, of the aid list: "p - this whole process should go into the flow: raw ->
   staged -> out or curated"): every curated list, the wrecks' and the aids' alike, goes raw -> staging -> curated in
   fishycode's layers. A sketch, on plan 075's landing sites: each list staged by its own script in sources/<source>/ to
   staging/<source>/ (the List of Lights' PDF read in R, as the study's 86 does in Python; Vegagerðin's lights and wave
   buoys; OSM's seamarks; IS 50V's lighthouses; Wikidata's lighthouses), the charts' printed characteristics frozen in the
   study first and read as a frozen input, as chart_names is (only the names are frozen now); the join, the outcomes and
   the best witnesses in reference/aids/aid.R to curated/reference/aid.parquet with its records, pairs and descriptions
   beside (write_curated, stamped); the accounting (the study's 94) in curate/checks/aid_accounting.R; the machinery both
   lists share (mutual nearest across lists, places, outcomes, best witness, the long descriptions) once, in R/.
   *Settled* (the maintainer, 2026-11-16: "Standalone in layers"): standalone scripts in those layers, run by hand, outside
   the targets flow and its rebuild. The aid list built so the same day (by Claude; no person has checked it):
   `sources/{vitaskra/aid.R, vegagerdin/light.R, osm/seamark.R, is50v/lighthouse.R, wikidata/lighthouse.R, sjokort/aid_label.R}`
   to staging/, `reference/aids/aid.R` to `curated/reference/{aid,aid_record,aid_pair,aid_description}.parquet` and
   `curated/check/aid_join_rules.parquet`, `curate/checks/aid_accounting.R` (24 checks hold) to
   `curated/check/{aid_accounting,aid_conflict}.parquet`; the shared machinery `R/curated_list.R` and
   `R/light_characteristic.R`, tested by `tests/test_curated_list.R`; the charts' printed characteristics and 84's aid
   letterings frozen by the study's 97. The R reading of the List of Lights gives 86's table field for field; the curated
   tables give the prototype's record for record (outcome, kind, attachment, aid, every attribute). The wreck list is its
   own session's to move; `R/curated_list.R` is there for it.

## 3. Not in this plan

The harbours (plan 075's landing sites; the maintainer, 2026-11-17: "9 - harbour, leave out of this plan"); the bottom type
(TODO 201); the charts' wreck symbols (the maintainer, 2026-11-16: "mining the sea-charts again for any wreck information
waits for now"); resolving the conflicts ("for now we are not going to resolve conflicts"); NGA's Pub. 115 ("no more
fetching"); the wave buoys as an explanation of gaps in the effort maps ("do later").
