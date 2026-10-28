# 237 — Global Fishing Watch's vessel tracking guide read against fishycode and ramb: a guide for those who run tracking systems, met where it touches the data, four wishes added

*2026-10-28. The maintainer gave the guide's link: "add this to our knowledge base - we want to judge fishycode and
ramb against this". Claude (AI) read it against fishycode at `ba1d53d` and ramb 2026.10.28.2 (`ca57d64`). Claude wrote
this record, the provenance note and the new wish-list rows in `docs/one_flow.qmd`. No person has checked them.
Nothing went into ramb.*

## What it is

*Vessel Tracking Best Practices Guide*, Global Fishing Watch, September 2026. Its authors are Charles Kilgour and
Michele Kuruc. It has 120 A4 pages, and its printed page numbers equal the PDF's. It is licensed CC BY-NC-SA 4.0
(p. 7). It is summarised here in our own words and cited by page.

| | |
|---|---|
| source | `https://globalfishingwatch.org/wp-content/uploads/Reduced_CORRECTED_2026-10-13-GlobalFishingWatchGuide_ENGLISH_V10_DIGITAL.pdf`, fetched 2026-10-28 |
| version | English V10, corrected 2026-10-13 (the file's name and its modification date) |
| filed | `$FISHYDATA/raw/external/gfw/vessel-tracking-guide-2026/`, the PDF as fetched and `guide_pages.txt`, its text page by page (`pdftotext`); both sha256 in `raw/external/gfw/README-provenance.txt` |
| md5 | `01d9a826df0dbe01dd8ac48550ffb20d` |

It is written for governments that run VMS and AIS for monitoring, control and surveillance. Its focus is large
vessels, and small-scale fisheries are left out (pp. 11, 20). It says it is not a standard, and its "should" is advice
(p. 6). It has three sections:

1. foundations: the systems, aims, transparency and data ethics (pp. 12-25);
2. technical standards and data processing: devices, networks, storage, access, security, integration, interface,
   polling and analytics (pp. 26-80);
3. costs and law (pp. 81-100).

Fisheries science is one of the twelve uses it names: effort and where and when vessels fish (p. 22).

## Where the guide and fishycode meet

Most of the guide is about running a tracking system: devices and their approval (pp. 28-41), networks (pp. 42-47),
storage, access and security (pp. 48-51), costs (pp. 82-84), and law and courts (pp. 85-100 and Annex 2). Those parts
judge the authorities that run Iceland's tracking, not fishycode, which receives their data. Pages 89-95, on legal
provisions and sanctions, were not read closely. What follows is the part that touches the data.

| The guide asks | fishycode and ramb | Judged |
|---|---|---|
| One identifier per hull for life, never reused. Every other identifier kept and linked, and names never used alone (pp. 24, 35, 55) | the vid, one per hull and never moved (the vid ledger, decisions 115, 190). The identity tables carry call sign, IMO, MMSI, flag and name beside it (`reference/vessels/identity.R`). Call signs reused (decisions 045, 047) and mobile ids heard with two vessels (`ais_key_twins.R`) are found and kept | met, and more: the guide assumes each fix comes with its identifier, while fishycode infers it for every STK ping (the key, a fitted model) |
| VMS and AIS used together: linked through the identifier, each checked against the other, a silence in one seen in the other (pp. 17-18, 53, 73) | STK's trail is three streams in one (decision 233). The commercial AIS feeds join it by MMSI and date (`curate/ais_ping_union.R`). Two feeds' ids are linked where they move together (`rb_link_vessel_tracks`, decisions 047, 146) | in part: the feeds are joined, but a silence in one is not checked against the others (wish 1) |
| Times stored in UTC, written as ISO 8601 when exchanged (pp. 56-57) | every date-time is UTC, and both targets projects set `TZ=UTC` (decision 111). Parquet holds typed timestamps | met |
| Speed in knots, to one decimal at least; the original unit kept (p. 57) | ramb's speeds are knots (`rb_calc_speed`, `rb_convert_speed`). The dumps' units are in the dictionary's overlay (plan 040, decision 176) | met |
| Positions in WGS84 to five decimals of a degree, about 1 m; course 0-360 (p. 59) | not fishycode's to set. STK's VMS-like stream lies on a grid of a hundredth of a minute, about 18 m in latitude. Its heading field is heading to 2010-06-09 and course after (decision 233) | recorded where the data fall short |
| A data dictionary: each field's name, definition, type, unit and whether it is mandatory (p. 58) | the dumps' dictionaries with their overlay of units and codes (plan 040), and `docs/data-dict.yaml` for `curated/` (decision 029). A flow column is always present, and its basis says whether it holds a value | met; whether every curated column states its unit was not checked |
| How data are made, documented; audit trails and a chain of custody (pp. 50, 58, 96-97) | every curated file carries its commit, script and the md5 of each input (`write_curated()`, decision 070). A correction adds columns and never overwrites | met for a research product. There is no access log and no evidentiary chain, and none is needed |
| Positions that need over 25 knots flagged (pp. 34, 40, 74) | `rb_flag_ping_impossible(kn_max = 25)`, the same number. It labels and never drops | met |
| Polling every 1-15 minutes; an interval no longer than a quarter of the event to be seen; rates checked against logbooks and observers (pp. 64-66) | ramb's set finder at five ping rates on labelled tracks (decision 234). The hours held in intervals over 1 h, counted once (decision 231) | in part: no record is checked against the interval around it (wish 2) |
| Fishing from speed, set for each gear; course and learned models beyond it (pp. 70-71, 76-77) | gear speed ranges and record windows (`rb_add_fishing`), and the mixtures and HMMs in fishymodel. Learned classifiers are a wish already | met for speed. The record window, fishycode's best source, is not in the guide |
| Detections checked against what was seen (inspections, observers, EM) and set for the fleet (pp. 68-69) | the allocation audit (decision 155), the survey's tows (decision 104), real set times (decision 158), and the track link calibrated on Iceland (decision 047). Scores as functions are a wish already | met in fishycode, but not as ramb functions |
| Port arrivals and departures, at berths and at anchorages, checked against declared port entries and exits (p. 75) | ramb's port calls, with declared port events as one rule (`event_pair`). STK's port events, and each trip end from ranked witnesses (decisions 172-174) | in part: anchorages with no drawn polygon are a wish already (GFW's `pipe-anchorages`) |
| Entering and leaving zones (EEZ, closed areas, MPAs), checked against the vessel's permits; time inside below a transit speed (pp. 69, 76, 111). A port is such a zone, and arrival and departure are its events (p. 75) | built for ports: a port call's start and end are the vessel's arrival and departure (`rb_create_port_calls`). They come from pings tagged with the port polygon they lie in (`rb_flag_ping_port`, which takes any polygons with an id) and a port's rules: a minimum dwell, a radius, the time budget. For other polygons, `rb_detect_in_polygons` says in or out for each fix. `reference/geo/shapes.R` names no closed or protected area. The licence history is coded, not built (plan 029) | in part: ports only (wish 3) |
| Encounters between vessels and loitering at sea (pp. 71, 77-79) | `rb_link_vessel_tracks` measures the same closeness, summed over a period: each id's best other id shows pair trawlers or a tender. Catch moved between vessels comes from the logbook's notes (plan 042) and is not checked against the track | not met: no events (wish 4) |
| Exchange by API or by CSV and JSON files; NAF, FLUX and GDST as standards (pp. 60-61) | parquet files with provenance. The vessel overview's service runs on this machine only | not judged: no format has been asked for |
| Tracking data made public, with narrow exceptions (pp. 9, 23-24, 49) | kennitala and persons' data never published. The vessel overview is internal. ICES's three-vessel rule applies in the data call only | not judged: what MFRI publishes is MFRI's call |
| Gear coded by FAO's ISSCFG (pp. 54, 59) | ramb's vocabulary is ICES's (`rb_get_gear_vocabulary`). Decision 229 found the same split in EM4SSF's D1.1 | noted |

**What the guide stops short of.** It ends where a fix is judged fishing or not. Logbooks appear only as a source to
check against (pp. 52, 66). It does not link fixes to logbook records, share catch over fixes, or give a value its
basis. fishycode's main output, the link (decision 215), has no counterpart in it, nor does kg in = kg out.

## Four wishes added

These are new rows at the end of the wish list in `docs/one_flow.qmd`:

1. **A silence in one feed checked against another** (pp. 17, 73, Figure 3). For each gap in one feed: its length,
   the distance between the fixes either side, and whether another feed heard the vessel during it. The guide's
   example is a VMS silence of six hours during which AIS shows purse-seining. fishycode joins the feeds but compares
   their coverage only to link ids (the `opportunity` of `rb_link_vessel_tracks`).
2. **Each record's length against the ping interval around it** (pp. 64-66). An event is hard to detect when the
   interval exceeds a quarter of its length, so a one-hour haul needs pings every 15 minutes. A record shorter than four
   intervals could be flagged as below the rate that shows it. That would bound each path's error from the ping rate,
   which the project's third aim asks for.
3. **Entering and leaving any zone, as ports already are** (pp. 69, 75-76, 111). A port call is such an event: its start
   is the arrival and its end the departure. The wish is the same entry and exit for any polygon set (EEZ, closed areas,
   protected areas), without a port's minimum dwell. It also asks for the time inside below a transit speed (5-6 knots in
   the guide's drafting example), checked against permits where a licence history exists. ramb can already tag pings
   with any polygon's id (`rb_flag_ping_port`), but the port call's rules are written for ports.
4. **Encounters and loitering, as events** (pp. 71, 77-79). An encounter is GFW's rule as the guide gives it: two
   vessels within 500 m for over two hours, at low speed, away from port. Loitering is one vessel slow at sea for longer
   than usual, with no partner seen. In Iceland these would check the transfers of catch that plan 042 reads from the
   notes, and pair trawling.

The guide is also cited on eight existing rows: duplicates and impossible speeds, downsampling and the ping rate,
harbours with no drawn polygons, fishing from speed rules, learned classifiers, gear from the track, scoring, and gaps
reported.

## GFW's own code, scanned by its READMEs

The same day the maintainer asked for a light scan of GFW's repositories (`github.com/GlobalFishingWatch`), "only reading
the README.md's", noting what may be of use. There are 180 repositories: 35 archived, 20 forks, 144 with a README.
Each README's opening lines were read, and about fifteen were read further. No code was read or run. Most are
infrastructure (BigQuery, Dataflow, Airflow), web front ends, workshops and country reports. Each pipeline listed here
runs on Google Cloud and reads GFW's own tables. None is a package one can call on a track table.

| Repository (licence, last push) | What its README says | Of use for |
|---|---|---|
| `pipe-gaps` (Apache 2.0, 2026-10-19) | a gap event when consecutive positions of one vessel are further apart than a set threshold; an open gap when no position has come yet. It is flagged as likely deliberate disabling when the gap lasts 12 h or more, its last position is more than 50 nm from shore, satellite reception there exceeds 10 positions a day (per 1° cell and AIS class), and the vessel sent 14 or more satellite positions in the 12 h before. Rules from Welch et al. 2022 (`AIS-disabling-high-seas`) | wish 1 and the EM4SSF gap row: a definition, and a test that coverage explains a gap. It works on one feed at a time, not across feeds |
| `pipe-encounters` (Apache 2.0, 2026-10-23) | encounters from AIS by a maximum distance and a minimum time (the README's example: 0.5 km, 120 min, the guide's rule). It works per segment first, then merges across day boundaries by vessel | wish 4 |
| `pipe-loitering` (Apache 2.0, 2026-09-29) | loitering events; the README gives no rule | wish 4 |
| `pipe-events` (Apache 2.0, 2026-10-16) | fishing, encounter, loitering and port-visit events published together. Fishing events are runs of positions scored fishing by a neural net (or by a night-loitering score), rejoined across gaps of up to 2 h, and kept above a minimum length. Each event carries authorisation and regions | how GFW handles zones: regions tagged on each event, not entry and exit events (wish 3) |
| `pipe-anchorages` (Apache 2.0, 2026-10-23) | anchorages clustered from stationary positions near the coast and named. Port-visit entry and exit events and voyages, with confidence levels, run daily on AIS and VMS | already cloned at v4.6.4 (decision 148); the "harbours without drawn polygons" row |
| `pipe-segment`, `gpsdio-segment` (Apache 2.0, 2026-07-24) | splits one MMSI's messages into segments where two or more vessels broadcast it at once | the STK key's twins and shared MMSIs, a published method to compare with |
| `pipe-vms-norway`, `pipe-vms-chile`, `pipe-vms-generic` | fetching and normalising national VMS, then the same segment, encounter, anchorage and event pipelines as for AIS | how GFW normalises Norway's VMS, if fishycode ever reads it (`raw/external/nor` holds the register only) |
| `pipe-naf-reader` (Apache 2.0, 2025-12-11) | parses NAF messages to CSV, with a JSON schema of the fields | a NAF reader, if Iceland's VMS or the guide's exchange format is ever wanted |
| `training-data` (CC BY 4.0, 2021) | AIS tracks with fishing and gear labels, for training (numpy, git-lfs) | the "open labelled data" row and TODO 93 |
| `vessel-classification`, `vessel-scoring`, `track-based-models` | vessel class, length and fishing per position from TensorFlow models; fishing-score heuristics with their evaluation | the gear-from-track and learned-classifier rows (cited already) |
| `gfw-longline-sets-model` (2018), `paper-global-longline-sets` (2024) | longline set times from AIS. The tracks are not public; the paper's tables are in a public BigQuery dataset | the set finder, which fails on Icelandic static gear (decisions 158, 234) |
| `paper-clarifying-uses` (2025) | GFW's reply to Hintzen et al. 2025, which found GFW overestimates Northeast Atlantic pelagic fishing against self-reported fishing; it plots the general model, the trawler model and the reported fishing for a vessel | fishycode's trail is reported fishing for Iceland's fleet, so GFW's fishing hours on Icelandic vessels can be scored against it |
| `gfwr` (R, Apache 2.0, 2026-10-21) | the API in R: `gfw_event()` (fishing, encounter, loitering, port visit, gap), `gfw_ais_fishing_hours()`, `gfw_vessel_info()`, `gfw_region_id()` | GFW's events for Icelandic vessels, against fishycode's port calls, records and fishing. The maintainer's token works but sits in `~/.Renviron`, which R started in fishycode does not read |
| `ShipDataProcess` (Apache 2.0, 2026-10-28) | Python functions that normalise ship names and call signs, standardise IMO numbers, flags and gear types, and collapse many identity messages into one | the vessel crosswalk's name matching (plan 021) |

Of little use here: the web and map tools (`4wings`, `track-inspector`), AIS decoding (`ais-tools`, `gpsdio`), the
cross-pipeline tests (`data-integration-tests`, `table_identical_checks`, `data-testing`), the IUU-risk and
forced-labour work, and the satellite look-up table for spoofing checks (`pipe-satellite-data`).

## Not done

- Nothing built in ramb. Which wishes to build is the maintainer's choice; TODO 151 holds it and the two
  measurements below (opened 2026-10-28). By the
  project's rule (`AGENTS.md`), a document gives asks and definitions, not methods. GFW's code for gaps, encounters
  and loitering exists (above) but was not read beyond its READMEs.
- Not measured: the Icelandic tracks against the guide's numbers, such as the ping interval of each stream and year, or
  the share of logbook records shorter than four ping intervals.
