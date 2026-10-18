# 143 — The vessel overview in two modes: Overview for the curious, Quality control for the checker

*2026-10-18. The maintainer's asks after decision 140 ("a little bit more than brilliant. now for enhancement"), and
their guidance on the user's feel ("things have to be intuitive", "clear"; "the user could be a quality control person
or just a layman that is curious"). Design, code, checks and this record by Claude (AI-assisted). A person has not yet
used the new page.*

## Asked, and what was built

| asked | built |
|---|---|
| select vessels from a list | a list of the 7,317 vessels the register or the trail knows: number, name, call sign, MMSI, first year on AIS, last heard, last landing, photo. It can be filtered by text, by "heard on AIS", "with a photo" and "landed since", and sorted by any column. The service computes the summary once at start (0.7 s) |
| years, or a range of years | a from-to year pair. The trail, trips, hauls, catch and landings of the range load once, and every interaction then runs in the page |
| mark trips on the time-speed profile | each logbook trip a shaded band from departure to return. A click on a band selects the trip |
| mark hauls | each haul a bar along the top: grey from gear in to gear out (t1-t4), green for the fishing (t2-t3) where the logbook gives it. The flow's fishing flag is drawn red on the speed line, and landings are orange triangles |
| tabs | Activity: about the vessel, photo, map, chart, the last landing and the trip that landed it (through `lid_map`), the trips of the range. History: the register today and its history, all landings and all trips, by year and paged. It loads only when opened |
| two versions, layman and QC | one page with two modes, switched in the header and kept in the address (`mode=qc`). The data are shared; what each mode shows, and in what words, differs |
| QC: the pings and the main events | an event lane on the chart's time axis: logbook trip, setting t1-t2, fishing t2-t3, hauling t3-t4, landing, stays in port, voyages, `fishing_flow`, AIS gaps over 30 min. Also the pings of the window, 100 a page, each clickable to the map and chart |
| a trip table that opens | the trips of the range, newest first. A click selects the trip, frames it and its hauls, and opens its logbook records. A haul's row zooms the window to it. In QC every column of a haul is shown, with its basis and catch by species |

**Overview** speaks plainly:
- a summary card ("a fiskiskip, 19 m long, built 1990, home port Grímsey"; last heard on AIS, at sea or in port; the
  last landing; trips and tonnes in the range);
- a legend in words, and no identifier on screen.

**Quality control** shows identifiers and bases, and per trip:
- pings and fishing pings inside it;
- the warnings below.

## The checks, and the gillnet lesson

The first version flagged every trip of vid 2047, a gillnetter: its haul's gear went in hours before the trip's
departure. For static gear that is the norm, not a defect. The nets are set on one trip and hauled on a later one. The
grammar (`docs/grammar.qmd`) says the vessel attends static gear while hauling (t3-t4), and towed gear during the tow
(t2-t3). So each haul is now judged on the window its gear is attended:
- static (GNS, GND, GTR, LLS, LLD, FPO, ...): t3-t4;
- towed and jigged (OTB, OTM, SDN, PS, DRB, LHM, ...): t2-t3;
- gear unknown: t1-t4, the lenient choice.

On vid 2047's 2025-2026 that took the flagged trips from 102 of 102 to 35. The warnings are:
- the trip has no pings;
- no haul is recorded;
- a haul is attended outside T1-T2, with 15 min of slack, since T1 and T2 are often given to the quarter hour;
- a haul has no fishing ping in its attended window;
- the trip has fishing pings outside every haul's attended window.

They are computed in the page in linear time, by prefix sums over the sorted pings.

**The settled gear.** A haul's gear now comes from `curated/logbook/gear.parquet` (`gid_used`, with its basis), not the
fishing sample. The sample has no gear for adb, which the landings fill (`curate/corrections/logbook_gear.R`). On vid
2047, 34 adb hauls were "reconstructed" GNS.

## The gear after the last logbook trip

The maintainer's rule (2026-10-18): "if a logbook is missing from vessels last trip, assume that the gear is the same
gear as from the previous trip". In the page it applies only where a logbook is in fact missing:
- the last landing has no logbook trip in `lid_map`;
- the time runs from the last logbook trip's return to that landing.

A vessel that stopped fishing gets no assumed gear. The assumption is named as one wherever it shows:
- the panel of the trip that landed it, beside the landing's own gear;
- the pings' tooltips and the chart's hover text;
- in Quality control, the source trip's `.tid`.

Checked on vid 2047: the last landing (2026-10-14) has no logbook, and the previous trip (2026-07-15) gives GNS, which
agrees with the landing's Þorskfisknet. Checked on vid 2757: its last landing links exactly to its trip, so nothing is
assumed.

"Better still would be that we would obtain the gear from the ais track - but that is a bigger TODO" (maintainer):
TODO 86. The same rule in the flow's gear cascade, for pings and voyages with no logbook, is not made here.

**Revised the same day:** the landing's own gear now comes first, and the previous trip's only where the landing
records none (the second amendment below).

## Amended 2026-10-18: presets, the map's background, fishing hours in hexagons

The maintainer's tweaks:
- **"All loaded years" named its range.** The page loads the latest year by default, so the button now says
  "Whole range: 2026", and an **All years** button loads every year the vessel was heard on AIS.
- **"Last N trips" instead of a month.** "rather than having 'month' having last x trips": a preset of the last 1, 3,
  5 or 10 logbook trips, or of AIS voyages for a vessel with no logbook. The page opens on the last 3. "Last month"
  stays. Every preset also fits the map to what it selects, and **Fit map** does so after a drag ("center the data
  view to the last trip(s), month, year per vessel").
- **What the map shows outside the window:** the whole loaded track, the fishing hours in hexagons, or nothing ("choose
  to only see the data selected or the full sweep").
  - The first version drew a heat map. "hex-layer instead of heatmap may be better science" (maintainer): a heat map
    smooths over a spread set in screen pixels, while hexagons are fixed cells with a quantity and a legend.
  - The cells sum the trail's `hours`, the effort each fishing fix stands for, not a count of pings, so a stretch the
    AIS reported often weighs no more than one it reported seldom. On vid 1977's 2026 that is 4,268 fishing hours in
    78,347 pings.
  - The cells are 0.5, 1, 2 or 5 km from centre to corner, regular on the Web Mercator map at the map's latitude, so
    only roughly equal in area. H3 cells would be equal-area; they would need h3-js or the service.
  - The option is greyed out for a vessel with no fishing ping.

The service now sends `hours` with the trail (API version 2026-10-18.4), so an older running server shows the page's
banner. Checked in the browser pane on vids 2047 and 1977: the presets, the range's name, the hexagons' legend (0-10.4
fishing hours per 1 km cell for vid 1977). The redraw time with hexagons on was not measured: the pane was hidden.

## Amended 2026-10-18: one table of trips and landings, the vessel in a strip and a tab, the gear from the landing

The maintainer's next asks; code, checks and this section by Claude (AI-assisted). The page alone changed, not the
service.

- **One table.** "we can just have trip tables - then if one (double-)clicks on a table it would show the logbook
  records for that trip only as a 'subtable'". The Activity tab's table now holds:
  - every logbook trip of the range, with what it landed through `lid_map` (in Quality control, the match too);
  - every landing no trip of the range claims, as a row of its own ("no logbook", or "logbook trip in another year"),
    with the landing's gear.

  A click selects a row: the window, map and chart go to the trip, or, for a landing, to the AIS voyage that ended
  within a day of it. A double-click, or the caret, opens the row: a trip's logbook records and what it landed, or a
  landing's species. The panels "Last landing" and "The trip that landed it" are gone.
- **The vessel as a strip and a tab.** "the vessel info should become a tab, not a scroll down", and "a short 'strip'
  at the top with only one/two row info line, with the thumb-image at the rightmost side".
  - Activity opens on two lines about the vessel, with its photo as a thumb at the right.
  - A click on the thumb opens the new **Vessel** tab: about the vessel, every photo, the register today and its history.
  - History keeps all landings and all trips.
  - Both modes now share one top-down layout: the strip, the choices, where | when, the table, and in Quality control
    the pings.
- **The chart's speed capped at 15 knots.** "vessels rarely go above 12-15 knots. And all fishing activity is well below
  that speed". A ping above the cap is drawn at 15. The map's tooltip keeps the real speed.
- **The gear from the landing.** "actually the gear is in the 'last landing', better than using the logbooks". This
  revises the rule above. After the last logbook trip, a time takes the gear its next landing records. The previous
  logbook trip's gear is used only where that landing records none.
  - On vid 2047, all 22 landings after the last logbook trip (2026-07-15) record Þorskfisknet, so nothing is assumed
    now. Before, each was given GNS from the previous trip.
  - The gear is the landing's own name for it (Þorskfisknet, Lína), not the logbook's code (GNS, LLS).

**Found on the way: voyage numbers restart each year.** The trail numbers a vessel's voyages afresh each year, and the
page grouped pings by that number. Over a range of two years it merged, for example, 2025's voyage 72 with 2026's:
- the map drew a path between the two;
- "Last N voyages" could span a year.

A voyage is now the consecutive pings of one number. On vid 2047, the landing of 2026-09-08 framed 2025-08-21 to
2026-09-08 before the fix, and after it its own voyage, 06:57-10:37 that day. Separately, vid 2757's 2025 holds one
voyage from 1 January to 24 August with no stay. That is the trail's matter, not the page's.

Checked in the browser pane:
- vid 2047, 2025-2026, Quality control: 129 rows (102 trips and 27 landings without one). A mouse double-click opened
  trip 250710 with its haul and its landing (`lid_map` 01 exact).
- vid 2757, 2024, Overview: 42 rows, one landing with no logbook.
- vid 1977, 2026: the strip, the thumb, and the Vessel and History tabs, with no console error.

Not checked: the layout at phone width, and a person using the page.

## Measured

- The service (`check.R`): 67 answers on vids 2757, 3739 and 2652, each with exactly its allowlisted columns, all
  under 0.7 s; 10 refusals.
  - Three years of trail for vid 2757: 242,669 pings in 0.1 s.
  - A vessel's whole history: up to about 14,000 landing rows and 1,957 trips, under 0.1 s.
- The page, on vid 1977's 2024-2026 in Quality control (388,428 pings, 2,758 hauls, 36 trips, 38 landings):
  - loaded in 1.2 s;
  - 40 window moves redrew the map, chart and lane in 7-17 ms each, median 8 ms.
- On vid 2047's 2025-2026: 129,982 pings, 102 trips, 147 hauls, loaded in 0.4-0.9 s.

## Not done, or not checked

- **Species are codes.** No species reference exists yet (TODO 10). For a curious reader that is the largest gap left.
- The hover link between chart and map, Play, and the QC lane's hover were not measured. Each was seen working
  once in the browser pane.
- The checks' rule for gear the lists do not name is lenient by design. Whether STATIC and MOBILE are complete for
  the Icelandic gears is for a person to say.
