# 280 — The time panel after the maintainer's first look: its controls in the sidebar, one gap in seconds, none by default

*2026-11-05. The maintainer, in ad hoc questions on the panel of decision 279: "all the user controls be on the left
box, not between the two graphs"; the track's one-hour break should be "gap_h = Inf" by default, since a user "would
get confused when he is doing detailed QC"; the argument renamed, in seconds ("Should we in general use _s when
speaking time in ramb?"); and the article's example without the impossible pings ("we are only introducing this app
now"). Each answered as Claude recommended; built and tested by Claude (AI) the same day, not checked by a person.
ramb 2026.11.05 is 3d7709d and 2026.11.05.1 is f91ab3b, committed to ramb's local `main`, installed from it, not
pushed.*

## What was chosen

- **Every control of the panel in the sidebar.** A group *Time*, above the layers, holds the vessel, the span, the
  columns to draw and *Whole span*. Over the chart only the readout stays (the window, or the ping under the cursor),
  in the chart's top margin: it follows the pointer, so it sits by the data it describes. The strip of controls
  between the map and the chart is gone, and the chart has its height. The group is there from the page's start, so
  the sidebar does not move when the map has loaded. On a phone it is behind the menu with the layers.
- **One gap, in seconds, and none by default.** `rb_map_track(max_gap_s = Inf)` replaces `gap_h = 1`, and
  `rb_map_time(max_gap_s = )` takes the track's when the map has one, else `Inf`. The value breaks the track, the
  panel's line on the chart and on the map, and a lane's runs; before, the track took `gap_h` and the page and the
  lanes had an hour of their own, hard-coded twice. Why none by default: a rule the user did not ask for hides
  stretches of the data, and in a quality check a break reads as missing pings. With none, a silence shows as a long
  straight line, which is easy to see, and `max_gap_s = 3600` gives the old line. `gap_h` warns once a session and
  goes in the next release. Why seconds: ramb's other durations are (`min_dt_s`, `window_s`, `max_gap_s` of
  `rb_create_record_stretches()`), and `_min` already means a minimum there; the rest follow in TODO 189.
- **The track's text in words**: "The pings of each vid joined in time order, broken where two are more than 1 hour
  apart, and coloured by behaviour." It said "1 hours", and would have said "Inf hours".
- **The article introduces the viewer and nothing else.** Its example reads `dansk` lazily, as the quick look does,
  with no copy into R and no renaming; the impossible pings and their marks are left to the book's chapter on step 0,
  and `marks =` is a line under "Some things to know". The article is edited, not committed: ramb's rule leaves an
  article's commit to the maintainer.

## The cost, seen in the browser

With no gap, the chart joins a vessel's last ping before a silence to its first after it: on `dansk`'s EX_11 in
2015-02 the speed climbs in straight lines from 0 to about 8 across each silence between trips, and a lane's run of
*Other* spans the silence. That is the data as recorded, drawn as `ggplot2::geom_line()` draws it; a user who wants
the silences open gives `max_gap_s`. The case study's viewer in `me_code` (`viewers/cs1_time_map.R`) has no track
and gives no gap, so its chart and lanes, which broke at an hour, now break nowhere until it gives
`rb_map_time(max_gap_s = )`.

## Checked

- **The click paths in a browser** on `dansk`, served from the working tree: two columns with marks and lanes, and one
  column straight from the lazy table: a vessel, a month's span, a drag, a double click, *Whole span*, a hover, a click
  on a ping, a click on a lane, a second column, a reload from the address, a change of base map, and the page at a
  phone's width (the group behind the menu, a vessel chosen there). With `max_gap_s = 3600` on the track the panel
  took 3600, and the chart, the lanes and the text broke at an hour; with none, `T_GAP` is `Infinity` and the text has
  no break clause.
- **A bundle served as static files** (`rb_map_bundle()`, EX_1 and EX_11 with an hour's gap): the gap carried into
  the page, the group shown, a month's span loaded from `time/`.
- **ramb's tests:** the whole suite passes, 292 blocks in 23 files: with `devtools::test()`, and against the installed
  package (`load_package = "installed"`), 2,660 expectations, none failed, 3 skipped as on CRAN. New: the track's
  default line and its text, `max_gap_s = 3600`, the old `gap_h` with its warning, the refusals, the gap in words;
  the panel's gap absent by default, its own, the track's, and no lane's run spanning a silence longer than it.
- **The installed ramb** (`git archive f91ab3b` with the clone's 22 LFS files, `R CMD INSTALL --preclean`):
  2026.11.05.1, `dansk` whole (395,558 rows), and the article's new chunk builds its map (14 vessels, speed and
  course, two lanes, no gap).

## Not done

- **The maintainer's step-through** of the case study's viewer (plan 064 step 5's check), and asks d and e.
- **ramb pushed**, and the article committed: each the maintainer's word.
