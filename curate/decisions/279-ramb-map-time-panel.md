# 279 — ramb's map viewer gets a time panel, `rb_map_time()`: one vessel's pings over time, linked to the map

*2026-11-04. The maintainer's ask, 2026-11-04: function calls in ramb "that would emulate the space and time profiles"
of fishycode's vessel overview, so that a partner's case study can be viewed; then "can we implement plan 064". Asks
a, b, c and f were answered the same day, each as recommended. Built and tested by Claude (AI) that evening; no person
has checked it. ramb 2026.11.04.4 is 10c5355, committed to ramb's local `main` at the maintainer's word, not
installed and not pushed.*

## What was built

- **ramb's `rb_map_time()`.** It adds a panel under a map from `rb_map_pings()` or `rb_map_track()`, or starts a map of
  its own, and it pipes either way round, one panel a map. The panel shows:
  - one vessel's columns over time, each on its own scale (the first's axis on the left, the second's on the right);
  - marks where a column says so (a flag), as ticks along the chart's top and rings on the map;
  - lanes of intervals: runs of a ping column, broken at a silence of over an hour as the line is, or a table of port
    calls (`T_in`, `T_out`), voyages (`T1`, `T2`), records' windows (`w_start`, `w_end`) or any `start` and `end`.
    A value keeps its colour along its lane.
- **The server's route `/time?v=&span=`** gives one vessel's span as JSON. The vessel and span are checked against the
  panel's before R sees them. A vessel key is matched as text, a whole number written alike from an integer or a
  double column, so a lane's table finds its vessel.
- **The page** (engine 3) loads uPlot 1.6.30 from jsdelivr only for a map with a panel. The links:
  - a drag across the chart sets the window, and a double click or the "Whole span" button shows the whole span;
  - the map draws the window's track and pings and fits to them;
  - a hover marks the ping on the map, and a click within 8 px of a window ping marks its time on the chart, pinned to
    that ping;
  - a click on a lane's interval sets the window to it;
  - the vessel, the span and the window go into the address (`tv`, `tspan`, `tw`), and survive a change of base map.
- **`rb_map_bundle()`** writes each vessel's spans as script files (`time/`), so the panel works with no server.
- **An example on `dansk`**: `inst/examples/map/dansk_time_map.R`.
- **In `me_code`** (EM4SSF's private repo): `viewers/cs1_time_map.R`. It shows the partner's case study, served on
  127.0.0.1 and never bundled. Its marks are EM4SSF's speed loop and ramb's `clean`, and its lanes are the project's
  trips and the file's fills.

## Chosen, and why (plan 064 step 1, measured in a browser)

- **The window is drawn as new data.** A filter or a global-state paint on one GeoJSON source of 150,000 points
  re-tiles it, at about 0.3 s a window move. The map's `idle` event waits out a 300 ms label fade, so the times were
  taken to the frame that shows the change.
- **The window's pings and line are thinned to about 5,000, a marked ping always kept.** On `dansk`'s largest vessel
  (103,680 pings) a window is drawn in 48-65 ms from a day to the whole span. That is near plan 047's 50 ms mark. The
  page's own code takes 2-6 ms of it.
- **The page holds one vessel's span: the whole series up to 150,000 pings, else a month.** A tab building 454,000
  points as features crashed. Loading the whole of 103,680 pings takes 350-450 ms on 127.0.0.1. The JSON for 150,000
  pings is 5.3 MB and parses in 6 ms.
- **Times are shown as stored, in no zone,** on an ISO axis, labelled by `time_label`. A dataset whose zone is not
  known (the case study's) is not converted.

## Checked

- **The click paths in a browser,** on `dansk` and on the case study, at the pane's narrow width and at 800 px: a
  vessel, a month's span, a drag, a double click, "Whole span", a hover, a click on a ping, a click on a lane, a second
  column, a reload from the address, and a change of base map.
- **A bundle served as static files:** the panel's spans load from `time/`, a vessel and a month switched.
- **ramb's tests:** four new blocks in `test-map.R` and two etiquette cases. The whole suite passes, 291 blocks in 23
  files, none failed, 3 skipped as on CRAN. R CMD check: no error; the known warning from R's own `Boolean.h`; three
  notes that were there before. A first run caught the new help example filtering `dansk` on vessel numbers it does
  not have; it was fixed and the check run again.
- **ramb's article "Maps in RStudio"** has a section on the panel, on `dansk`; a copy rendered with the working tree
  installed in a scratch library, and the example's map gives each of `dansk`'s 14 vessels its whole series.

## Not done

- **The maintainer's step-through** of the case study's viewer (plan 064 step 5's check), and asks d (the vessel
  overview's future) and e (a bundle for the partners, only with CNR-IRBIM's agreement).
- **ramb installed and pushed:** each is the maintainer's word (committed as 10c5355). Until ramb is installed, the
  case study's viewer runs only with `pkgload::load_all()`.
- **An htmlwidget wrapper** (plan 064 §7), and the play button (ask f, later with plan 047).
