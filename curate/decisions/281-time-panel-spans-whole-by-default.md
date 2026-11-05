# 281 — The time panel's spans: the whole series by default, the user's own units, the map following the choice

*2026-11-05. The maintainer, after decision 280: "when you select a vessel and then a span, the space map should only
show those, not all the other spans, by default"; a tick box for all only "if it is foreseen that it is generally
useful"; "who defines the span? and how?"; then "measure first" (plan 064 §1.4), "Yes, build it", and while it was
built: "the user may want to use other variables than Span, e.g. if he has already assigned trips", and "carefully
think what the default should be - if the trip is the default that means we can not just throw the raw data into the
app"; then, on a trip cut in two, "Yes, one per value". Built and tested by Claude (AI) the same day, not checked by
a person. ramb 2026.11.05.2 is 5ed850b, committed to ramb's local `main` at the maintainer's word ("Commit, then step
2"), not installed, not pushed.*

## What was chosen

- **The whole series by default.** A span was ramb's own unit, set by the browser's memory: a vessel's whole series up
  to 150,000 pings, else each calendar month. The cap came from one crash in plan 064's first design, every ping a map
  feature; the page as built holds a series as arrays and draws at most about 5,000 pings a window, and held 2,173,541
  pings (plan 064 §1.4). `span_max` is 3,000,000: Iceland's longest series loads in about 8 s, most of it the JSON.
  Raw pings need nothing but a time and a position, so the default asks nothing of the data: a vessel is offered whole
  alone, and the page shows no span list where no vessel has more.
- **The user's own units, in `span`.** A column of the pings that names them, one span per value from its first ping
  to its last (`span = "trip_id"`, or `c(trip = "trip_id")` to name the list), or a table of intervals, as the lanes
  take, which `list(fault = <table>)` names the same way: trips already assigned, voyages, port calls, or any
  variable. A span holds every ping of its vessel from its start to its end, those with no value too. The list names
  each span by its value and start, and the sidebar names the list. A vessel over the cap is offered by its spans,
  else by month, so a fleet too long to hold still opens.
- **One span per value, not per run** (the maintainer's "Yes, one per value"). Built first as runs, the case study's
  trip 19_838 came out as two spans, split by the one ping EM4SSF's speed loop removed (it has no trip id): that ping
  was in neither half, so stepping through trips hid it. By runs, 37 of the case study's 1,623 trips split. One span
  per value keeps a trip whole with the removed ping in it, its mark and the lane's break showing where and why
  (`checks/cs1_clock_minute.R` in me_code: the ping is good, the one before written a minute late). A state that comes
  and goes (behaviour, gear) gives spans that overlap, which the function reports, pointing to `lanes`.
- **The map follows the choice.** The map's ping and track layers show only the chosen vessel and span: their features
  carry the time on the panel's clock (`rb_t` on a ping, `rb_t0` and `rb_t1` on a line), filtered in the page as a
  vessel or span is loaded, not as the window moves. No tick box for the rest: none is foreseen as generally useful
  yet. A track's line that runs over a span's start or end is shown whole; the panel's own line, drawn from the span,
  is exact.

## Checked

- **In a browser,** each map served from ramb's working tree:
  - the case study, its EM4SSF trips as spans: vessel 19's list "trip"; on the whole series the map showed vessel
    19's pings alone, and on trip 19_836 its 246 pings (245 drawn in view), the chart and its lane on the trip, the
    span in the address; per value, trip 19_838 is one span of 207 pings (175, the removed ping, 31), and no overlap
    is reported;
  - `dansk_truth` (plan 065 step 1), each planted fault a span 15 min either side from a named table: 52 tracks, the
    late stamp on its own;
  - `dansk` from the lazy table, a track and no span: vessel and *Whole span* only in the sidebar, the track's lines
    filtered to EX_3 and its series' times, kept over a change of base map.
- **ramb's tests:** the whole suite passes, 294 blocks in 23 files, 2,710 expectations (with `dansk_truth`'s test,
  committed after as 2026.11.05.3). New: raw pings give the whole series alone; a column's spans, one per value,
  named and loaded exactly; a named table's; a vessel over the cap by its spans or by month; the overlap message; the
  layers' times on the panel's clock.

## Not done

- **A binary transfer** (typed arrays or parquet, as the vessel overview's) in place of JSON, which would roughly
  halve a long series' load: only if 8 s loads turn out to matter.
- **Every span in the page's config:** a fleet with hundreds of trips each lists them all, as the months were listed
  before; spans fetched with their vessel are for when a map that large is wanted.
- **The maintainer's step-through** (plan 064 step 5), asks d and e, and the push.
