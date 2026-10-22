# 178 — The vessel overview in one view: Where and When on top, panels that fold, the fishing in the window, a search box and links to copy

*2026-10-22. Amends decision 143 (two modes) and decision 177. The same session.*

- **Who chose.** The maintainer, 2026-10-22:
  - "do the in-place expandable panels and the copy link button", and "expandable panels allows thing to be more
    compact. what we want on the top is always where and when";
  - whether the activity panel of Quality control could open inside the time-speed plot, "and if that is possible ...
    merge the Quality view within the main view". Claude put the merge as a question with a sketch of the layout, and
    the maintainer chose it;
  - on the search: "check what marinetraffic.com does - it allows for search on anything (vid, mmsi, imo, vessel name,
    ....) ... and when you type the choices then narrows as the user is typing";
  - on the shape: a ship-tracking site's vessel page (marinetraffic.com, a vessel's details), "what we would be doing is
    all the 'scientific details'", "here the fishing science is the focus not the vessel per se. like time-speed profile,
    time-activity record, the landings, the events (station)";
  - "spend some time on the 'look' - the user should feel upfront that he knows exactly what is what".
- **Who did the work.** Claude (Anthropic): the code, the checks in the browser pane on the running server, and this
  record. Claude looked at marinetraffic.com in the browser pane: its search and a vessel's page, with its cookie banner
  declined. A person has not yet used the changed page.

## Done

**One view.** The Overview and Quality control switch is gone (decision 143's two modes). Everything shows the summary
first and the details on expanding:
- Where | When stay on top.
- When has the window's presets and a "Copy link" button in its head.
- Under the speed chart, the activity record (decision 143's event lanes) folds to one bar and opens in place.
  - Each lane is named inside itself, above its bars, so the chart and the lanes keep one 24 px gutter and nothing is
    drawn over the data.
  - The lanes are the logbook trip, three of the hauls' windows (setting; towing, hauling or jigging; date only), the
    landing, in port, the voyage, fishing (`fishing_flow`) and AIS gaps at sea.
- **Three cards follow the window**, drawn again once it rests (150 ms):
  - activity: time at sea and in port by the flow's port calls, voyages, pings, fishing hours (the trail's `hours`) by
    the pings' gear, trips and hauls by gear with the catch logged, landings, and where the logbook and the pings part;
  - hauls: the logbook's stations, each with its pings and fishing pings by `.sid`;
  - landings: each with its port, gear, tonnes, main species and whether a logbook trip claims it.
- **The trip table**, folding:
  - a trip row's checks are badges ("✓ agree" or a named warning);
  - an opened trip shows its record: the ids, T1 and T2 as recorded with their basis, and its pings in the trip and on
    its hauls;
  - an opened trip lists its hauls in plain words, with their pings, and what it landed;
  - a click on a haul frames it and opens every field of its record under it: the ids, t1-t4, the windows with their
    basis, the gear with its basis, the duration, the effort, the positions as written (never drawn on the map:
    decision 156), the depth, the pings and the catch by species.
- **Pings in the window**, folded until opened.
- **Remembered:** which panels are open is the user's choice. It is carried to the next vessel and kept in the address
  (`open=`). An address with decision 143's `mode=qc` opens the lanes and the pings.
- **The vessel is context, not subject.**
  - It is one line beside the tabs: its type, length, year built, home port, when it was last heard on AIS and its last
    landing.
  - The Vessel tab keeps its photos, the register and every identifier.
  - The strip with the photo, at the head of the page, is gone.

**The search**, as marinetraffic.com does it:
- one box in the header, for the vid, the name, the call sign, MMSI, IMO, the local sign and the names the annual
  register gave the vessel (to 2023-12-19);
- the choices narrow as one types, with the match in bold. Matches are ranked:
  1. an identifier typed whole;
  2. a name that starts with the text;
  3. a word in a name that starts with it;
  4. a name that holds it;
  5. an identifier that starts with it;
  6. a former name, shown as "a former name: …".

  Within each, the vessel heard most recently comes first. Icelandic letters match their plain spelling: 'saevik' finds
  Sævík, and 'thor' finds Þór.
- arrows and Enter choose, and '/' goes to the box;
- before anything is typed it shows the vessels opened lately, kept in this browser only;
- the sortable list (the List button) stays, with the same fields.

The service's vessel list gains `uid` and `names` (API version 2026-10-22.2). The demo builder sends them empty, and
its check holds that no vessel answer carries them.

**Copy link.** On the When panel for the view, and on each trip and haul row for that record. The link names the loaded
years, so the record is in them. A toast confirms the copy. Where the browser refuses the clipboard, the link is shown
to copy by hand.

**The look**, so that what is what is plain at once:
- each panel says what it holds in a line under its title;
- one colour per kind of record, the same in the chart, the lanes, the cards' swatches and the tables' rows:
  - speed blue;
  - fishing red;
  - a logbook trip, a pale blue band;
  - setting grey, towing or hauling green, a haul known by its date pale green;
  - a landing, an orange triangle;
  - in port, slate.

  Checked with the dataviz skill's palette validator: the four main colours pass. Green against red is in the
  colour-blind warning band (deutan ΔE 7.0), so each also differs by mark and place: hauls are bars along the top, the
  fishing is a line, a landing is a triangle at the foot. Text is never in a series colour.
- the map has a legend for its pings' colours ("speed 0 … 12+ knots"), which it lacked;
- the hover line says what it is for until the cursor is on the chart;
- on a phone the header scrolls away instead of covering the page.

## Checked (in the browser pane, on the running server)

- `check.R` passes: 85 answers and 10 refusals, each with exactly its allowlisted columns. The vessel list (7,317
  vessels) is built in 0.74 s at the start.
- **Vid 1977's 2025** (147,432 pings):
  - the three cards follow the last three trips: 39,451 pings, 1,300 fishing hours, 218 OTB hauls, 932.8 t logged, 3
    landings of 1,120.4 t;
  - the activity record opened with its nine lanes named, and Pings in the window opened with 100 rows;
  - a haul picked in the hauls card framed that tow (2025-10-02 08:14-13:01), opened its trip in the table and its
    record under it, and put `trip=` and `haul=` in the address.
- **The search:**
  - 'sighv' gives SIGHVATUR (1416) first;
  - '251295110' and 'tfqn' give 1416 alone;
  - 'saevik' gives five vessels, four by a former name;
  - Enter on 'tfqn' opened vid 1416.
- **Copy link:**
  - the view's link was copied and confirmed;
  - a haul's link (vid 1416, haul 103167528) opened that haul's day, its record and a one-day activity card.
- **The demo** builds with the new page in a scratch store and runs over HTTP: vessel 22's cards, its lanes, a search
  by number, and no Vessel tab. The demo in `exports/` was not rebuilt.
- No console error from the new page. The one error listed in the pane came from a click in an earlier test run, on the
  script before this change; its line no longer matches the code.

## Not checked

- **The redraw time with the lanes open.** The pane was hidden, so it gave the page no animation frames, and the
  benchmark could not finish. Decision 177 measured 17 ms (median) on the same vessel-year with the lanes folded. The
  lanes add one canvas draw per move, over the intervals in the window.
- A person using the page.
- Safari, Windows and a phone (TODO 96 has the demo's share of this).
