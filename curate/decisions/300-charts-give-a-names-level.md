# 300 — The sea charts give a broad name its depth level: an older chart and the current ones, two models for plan 070

*2026-11-08. At the maintainer's word: "In /Volumes/stasi there may be two .tif file that containt older sea-chart ...
can you mine it", then "Think about how to mine the placenames and potential substrate type from these map ... Do this
as a scoping exercise", "would it not help to use the contours and names and try out the contour - name boundary",
"we could have one 'model' based on the tif charts - that may then compete/augment the sea-chart maps from
lmi.is/natt.is", "Yes, build model B" and "Yes, all names". Found, coded, run and counted by Claude (AI); no person has
checked the code, the readings or the counts. The study, its scripts and every table:
`$FISHYDATA/archive/2026-11-08-old-chart-names/` (its README).*

## Why

Plan 070 builds broad place-name areas from two bases only, the sea charts and the Olex depth grid (the maintainer,
2026-11-06). The maintainer had an older chart of Iceland as GeoTIFFs and asked whether it adds names, bottom types,
or a hint of a ground's boundary in its depth contours.

## The charts brought in

`raw/external/sjokort_old/` (its `README-provenance.txt`: each file's md5 against its original):

- **IS25 and IS26**: ÍSLAND, Austur and Vestur hluti, 1:750 000 at 65° N, Hjörsey datum, Sjómælingar Íslands, margins
  cut off (no edition shows). From the maintainer's home share, by way of `~/dummy`.
- **S300**: NORSKEHAVET med tilstøtende havområder, Norges sjøkartverk, 1:10 M at the equator, compiled to 1976.
  Dropped after a look: round Iceland it prints coastal names and lights only ("This does not look very promising -
  lets drop it", of S300 alone).
- **Vikurall_Hali.tiff**: a north-west chart with multibeam over it, found first and taken for the old chart by
  mistake; its names read in the study's `composite/`, kept as a record.

## What was found

- **Names: next to nothing new.** A pilot of 20 of the 154 windows (Sonnet 5.5 subagents, about 10,000 tokens a
  window) read 92 names; 81 are on the current charts at the same place, and none of the rest is a new sea name.
- **Bottom types: none on this chart.** But the current 1:300 000 and 1:100 000 charts print them (S, St, M, h ...),
  which TODO 186's reading left out. Read since in a session of its own
  (`$FISHYDATA/archive/2026-11-08-chart-bottom-types/`), to be recorded there.
- **The contours pair each name with a level.** In the East Fjords the chart's black contour is the 200 m line and
  each deep is set inside its own 200 m trough. But a closed contour round a name is rare (2 of 21): a trough opens to
  the ocean, a ground joins the coast's shelf. And the old line is not the grid's isobath: near Reyðarfjarðardjúp the
  grid gives 170 m, median, under the chart's 200 m line.

## What was built

One method for any chart, a chart entering only as its names (label positions) and its contour lines (points)
(`scripts/name_levels.R`):

- **A name's level is read off the chart's own lines**: the grid's depth under every chart point within 15 km of the
  label, snapped to the chart's levels; the level enclosing the label is the name's (for a deep the deepest drawn level
  shallower than the label, for a rise the shallowest deeper). Asking whether the chart draws the grid's isobath
  separates the chart's levels from controls only weakly (0.13 against 0.07), and saturates on the current charts.
- **Model A**, the old sheets: its black lines lifted off the images (graticule, coastline and type removed).
- **Model B**, the current charts: their cyan contours lifted by colour off TODO 186's 1:300 000 and 1:1 M windows
  (891,151 points); they draw a 150 m line the old chart does not.
- **A beside B**, on the pilot's 21 deeps and banks: 16 get the same level (B's 150 m taken as A's 200 m, the next
  line A draws). The other five are labels on different parts of a feature or different features of one name
  (Háfadjúp, Reynisdjúp, Tjörnesgrunn, Hóll, Rifsbanki); none differs where the labels mark the same place.
- **Model B on every broad sea name** (136 printed at 1:300 000 or broader, deeps and rises): a level for 128. Deeps
  200 m for 33 of 56; rises 150 m for 30, 100 m for 15, 50 m for 12. No level for 8: four far offshore beyond the
  lifted contours, four banks whose label lies just deeper than the line drawn near it.

## What it means

The charts give a broad name its level, and two editions a generation apart say it the same way. They are one
agency's charts, so two witnesses of one cartographer, not independent ones. The line itself is the depth grid's at
that level; the open side needs plan 070's rules (the shelf edge, the troughs either side). Plan 070 takes this as
§2.7.

## Open

- The open side's rule, and the areas set beside plan 070's depth-only ones.
- Model A on all its names: about 1.4 M Sonnet tokens to read the 134 windows left; not asked for.
- TODO 186's reading feeds model B unchecked: three fragments came in as names (DJÚP, FJARÐARÁLL, RDJÚP) and eight
  names are printed at two places.
