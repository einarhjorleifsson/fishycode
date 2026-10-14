# 013 — ramb as the function library for the WGSFD one-flow; fishycode as its first user

**status:** partly built — step A, phases 0–3 (phase 3 inside plan 014) and part of phase 4 done (decisions 070–093); what is left is ordered in "What is left, in order" (2026-10-14) · **2026-10-14** ·
**see:** `docs/one_flow.qmd` (the one-flow document, the home of version 2 since `~/stasi/wgsfd2026/` was retired), `~/R/Pakkar/ramb`, decision 070

Drafted with AI assistance (Claude) from the maintainer's direction in the session of 2026-10-08, three code
explorations and an adversarial review.

**Measured** (2026-10-08): the audit of ramb against the flow — which function does each step, tested once as a
data frame and once as a lazy DuckDB table on 3,000 `dansk` pings; ramb's git history of removed functions; the
fishycode scripts named as templates, read file by file.
**Assumed:** everything from "Function map" onward is proposal. In particular, that each fishycode step can be ported
to ramb with exact equality on real data, and that the speed-profile models fit at tier 3, are untested.


## What is left, in order (2026-10-14)

*Added by Claude (AI-assisted) at the maintainer's request: order what remains so that the design
(`docs/one_flow.qmd`, its cascade diagram) is fulfilled. Different parts of the Icelandic data take different paths
through the diagram, and ramb's functions must fit any dataset, not only this one. The phases below keep the designs;
this section orders them and adds what they lacked: the paths, and coverage. **Measured:** the two tables below
(read-only counts over `curated/`, 2026-10-14; 2026 left out, its data are incomplete). **Assumed:** the order, and
every function not yet built.*

**Built today** (decisions 070–093): the vessel and flag rows; trips from the logbook and from the track; records
with times or a day; gear from the record and the landing; fishing as window × speed. Every fix is labelled to that
depth. No fix carries effort or catch yet.

### The aim, and what stands between it and today

The aim, and the three tests for when it is met, are in `AGENTS.md` ("What this project is"). Against them:

**Critical gaps** (nothing below can stand in for them):

1. **No effort and no catch on any fix.** These are the product's two headline numbers. AIS fixes also lack the
   interval that effort needs (`dt_sec` is empty on them). Fails tests 1–2.
2. **Fishing is gated by the logbook.** A fix outside a logbook window is never fishing, so the track cannot stand in
   where the record is missing (rows 3–5). Fails test 1 for 16–24 % of fixes at sea on logbook trips, and for every
   voyage with only a landing or nothing.
3. **Vessels outside the Icelandic fleet are missing or unlabelled.**
   - Foreign vessels are dropped before the trail (TODO 22), yet they land most of the catch with no Icelandic
     logbook trip (rows 4, 9). Their logbooks exist at Fiskistofa.
   - Aquaculture and whale-watching boats carry no class, so they read as missing logbooks (row 6).
   - Fails tests 1–2.

**Approaches to rethink:**

1. **Which side decides activity: per unit, sometimes both** (maintainer). Today the logbook window decides for every
   fix, and the track can only narrow it.
   - Instead, the side with the better precision at that moment decides, and the other checks it:
     - a timed record on a sparse track: the window decides, the track checks;
     - a dense track with a coarse record or none: the track decides, the record checks;
     - both precise: they are compared, and agreement or disagreement is a label.
   - The deciding quantity is the one in `rb_reconcile_time()` (phase 4): the track's precision at the moment (the
     interval between fixes) against the declaration's (minute, date, or none).
   - This is the path column at work (below). The fallback rates of decision 090 give the track's side for towed
     gear; static gear and jigging need more.
   - **Approaches side by side, not a revamp** (maintainer, 2026-10-14). The trail keeps every approach, so the data
     can be summarised by any of them.
     - `fishing` stays as it is: the record's window (t2–t3, the haul, the jig or the day) × the gear's s1–s2 on the
       ±10 min speed. Its name stays too, because consumers read it (plan 002's column contract).
     - Each other approach is a column beside it:
       - the gear's s1–s2 on every fix with a gear, window or not;
       - later, the track models;
       - the per-unit choice, with `fishing_basis`.
       - Names are fixed when built.
     - Effort is computed for every fix at sea, whatever the approach: the interval, kW-hours, and pressure where the
       gear is known. A summary picks its approach by its column.
     - Catch per fix is long already (fix × species). It gets an `approach` key, since each approach shares a unit's
       catch over different fixes.
     - What is built stays: `station_window`, `station_event`, the stretch pairing, the ±10 min speed, the
       partitions. The cost is new columns, two new tables and one trail rebuild.
     - The approaches compared on the same fixes are how test 3 (each path's error) is measured.
2. **Catch sharing.** Not per record, but per unit the times and the track can separate (item 2): untimed records in
   one day pooled, a summary record widened to its day, landing sets across trips, all in one unit (kg, live weight).
3. **The path is implicit.** The code branches by which tables exist, and no number says which method made it. The
   path becomes a column per unit that the steps branch on (below).
4. **Steps 5–6 outside fishycode.** Settled 2026-10-14: they are part of the aim and are built in the flow.

### Where the Icelandic data sit on the diagram (measured)

Three periods, as the data change: the AIS interval and the logbook system both shift.

| | 2008–2012 | 2013–2020 | 2021–2025 |
|---|---|---|---|
| AIS interval at sea, median | 10 min | 1–3 min | 5–6 min |
| towed records with times (rest: day) | 70 % | 93 % | 99 % |
| static records with times | 34 % | 73 % | 90 % |
| jigging records with times | 2 % | 5 % | 77 % (day to 2021, timed from 2022) |

Each part of the data, by the path it takes (shares are the period means of the table above):

| # | Part of the data | Size | Path through the diagram | Today |
|---|---|---|---|---|
| 1 | Fixes in a timed window (tow, haul, jig) | 28 / 31 / 35 % of fixes at sea | declared trip → record with `t1`–`t4` → window + speed | built to step 4 |
| 2 | Fixes in a day window | 26 / 20 / 4 % of fixes at sea | declared trip → day record → speed within the day | built to step 4, basis `synthesised` |
| 3 | Fixes on a logbook trip, outside every window | 16 / 23 / 24 % of fixes at sea; at 1–6 kn: 6–7 % | declared trip → no record → the track decides | **never fishing**: the window decides alone |
| 4 | Voyages with a landing but no logbook trip | 20 / 14 / 12 % of voyages; 11 / 15 / 17 % of landed weight | landing → no record → the track → catch per landing | **not built**: no landing link, never fishing |
| 5 | Voyages with neither, of vessels that land that year | 10 / 9 / 8 % of voyages; 5–7 % of fixes | voyage → the track → effort only (TODO 49) | never fishing |
| 6 | Voyages of vessels that land nothing that year | 11 / 20 / 31 % of voyages; 6 / 11 / 24 % of fixes; 290–500 vessels | probably not fishing vessels: a vessel class, not a fallback | unlabelled |
| 7 | Logbook trips that no voyage covers | 4 / 2 / 4 % of trips; 1–6 % of records have no fix in their window | record with positions → catch at the record's position | **nowhere** |
| 8 | Logbook records before AIS | 3.5 M records 1990–2006 (93 % with a start position, none with an end); 1.4 M before 1990 (14 % with a position) | record with positions only | **nowhere** |
| 9 | Landings with neither a logbook trip nor a voyage | 5 / 3 / 4 % of landed weight | catch with a port and a date, no place | basis `none` |
| 10 | Pings without a vessel | 31,512 STK pings unassigned (TODO 25); foreign vessels dropped before the trail (TODO 22) | vessel `none` | dropped or unassigned |

- **Rows 4 and 9 are mostly foreign vessels landing in Iceland** (vid 3700–4999).
  - They keep their logbooks with their own flag state, not here.
  - Share of row 4's weight: 28 / 70 / 80 % by period. Share of row 9's: 84–88 %.
  - The Icelandic part of row 4 is 7.6 / 4.4 / 3.3 % of all landed weight.
  - Pelagic species (codes 30–36), 2019–2025: 1,144 of the 1,320 kt landed with no logbook trip is foreign, and
    952 kt of that has an AIS voyage.
- **Transhipment, pelagic species only** (codes 30–36; maintainer). A catcher's logbook trip would have no landing,
  and a carrier's landing no logbook trip. The totals would agree while the vessels do not.
  - Among Icelandic vessels it is small, 2019–2025: pelagic catch on logbook trips with no landing is 0–17 kt a year
    (whole weight). Icelandic pelagic landings with no logbook trip total 176 kt, about 25 kt a year.
  - A loose AIS meeting rule does not single the carriers out. The rule: another vessel within 1 km, both under 4 kn,
    for 30 min or more; landings selected by gear (pelagic trawl, purse seine). In 2023 it held for 52 % of the Icelandic pelagic landings with no logbook trip (46 landings, 21 kt)
    against 55 % of those with one: pelagic vessels work close together. A tighter rule, plus each vessel's catch
    balance, is needed.
- **Units.** Logbook and landings record in different units: tonnes against kilograms (maintainer). Condition is a
  second difference: the logbook has `catch_whole` and `condition`, the landings a product code (`kfteg`). The
  comparisons above between the two sources are therefore not on one unit. Comparisons within one source are.
- **Row 6 grows with other activity at sea** (maintainer: aquaculture, whale watching). Comparing 2013–2016 with
  2021–2024, the departure ports where these voyages grew most are:
  - the fish-farming fjords: Bíldudalur, Tálknafjörður, Patreksfjörður, Þingeyri, Súðavík, Ísafjörður,
    Fáskrúðsfjörður, Eskifjörður and Reyðarfjörður;
  - the whale-watching ports: Reykjavík, Húsavík, Akureyri and Hauganes.
  - The registry tables here give these vessels no class.
- Row 3 is mostly steaming between hauls. The slow part (1–6 kn) is the fishing the records may not cover: unlogged
  hauls, static gear being set.
- Fixes under 2 min apart: 4–8 % a year before 2013, 18–60 % after. Operations can be read from the track from 2013,
  hardly before.
- The trail's `dt_sec` is filled only for logger fixes: every AIS fix has it empty.
- "Fixes at sea" counts fixes, not time, so the years with sparse pings weigh less.

### The order

Each item names the ramb work (generic, for any dataset) and the fishycode work (the Icelandic wiring), and the rows
it serves. The order follows what the product gains, with dependencies first. Every new ramb function follows decided
item 9: it runs with the declared inputs `NULL` and returns the same columns. It is also tested on a fixture from
outside Iceland (`dansk`, the WKSSFGEO examples), and its defaults are checked for Icelandic bias.

**Paths are branches in the code, chosen per unit** (maintainer). One dataset does not run one sequence of methods:
each part of it runs the methods its data allow.

- **The path is a column.** Each unit (vessel-day, trip, landing set) gets one early, read from both sides (the
  declarations and the track).
  - Examples: `record` (timed records that pair with the track's operations), `summary` (records that hide more
    operations), `day`, `landing_only`, `track_only`, `no_ping`.
  - It starts from the declarations alone. Item 4 refines it with the track.
- **Each step chooses its method per row, not per call.**
  - `rb_assign_fishing()` takes an ordered cascade (`c("window", "track", "speed")`), and each fix takes the first
    method its path allows.
  - `rb_build_catch_units()` sets the unit by the path.
  - The fishycode flow script then branches nothing by hand: it calls the steps, and the column routes the rows.
- **The path stays on the output**, beside the bases, so each number traces back to the code that produced it.
- The registry (item 0) records which paths each step serves. The function that sets the path is named per the verb
  table.

0. **Contract checks before more step functions** (ramb only). The registry, `.rb_check_input()` and the shared misuse
   suite ("robustness to misuse" below) were to come before phase 4 added functions. Phase 4 has since added
   `rb_link_record_events()`, `rb_cut_record_stretches()`, `rb_link_record_stretches()` and `rb_calc_speed_smooth()`
   without them.
   - **Settled** (maintainer, 2026-10-14): the registry skeleton is built together with item 1, and each new step
     function enters with its row. The four existing step functions are retrofitted afterwards.
1. **Effort on the fixes already decided** (step 5; rows 1–2).
   - ramb: `rb_assign_effort()`.
     - Hours: the interval to the vessel's next fix, with the long-gap rule as an argument (the ICES drop over 2 h,
       or a cap).
     - kW-hours: hours × the vessel's engine power.
     - Pressure: where a width (towed gear) or a quantity (static gear) is known.
     - `effort_basis`.
     - Tier 1 (`lead()`), lazy.
   - fishycode:
     - the interval on every fix (`dt_sec` is empty on AIS fixes);
     - engine power, missing for a third of vessels (plan 015, choice f);
     - gear width (plan 015, choice d).
   - After this, the fixes already called fishing carry effort: 38 / 36 / 30 % of fixes at sea, all in rows 1–2.
2. **Catch shared at the finest level the data can separate** (step 6; rows 1–2 first, the landing units with items
   3 and 5).
   - **The unit is set by what the times allow, not by the record** (maintainer).
     - A fix can go to one record only where that record's window is its own.
     - Records whose windows overlap cannot be told apart on the track, e.g. several records in one day without
       `t1`–`t4`. They form one unit: their catch is summed and shared over all their fishing fixes.
     - The generic rule: the units are the connected sets of one vessel's records whose windows overlap.
       - A timed, exclusive window is a unit of one.
       - A day of untimed records is one unit.
       - A trip-level record is the trip.
   - **Measured** (2008–2025, records without times): how often one shares its day with other records.

     | gear class | 2008–2012 | 2013–2020 | 2021–2025 |
     |---|---|---|---|
     | towed | 98 % (6.3 records a day) | 92 % (5.3) | 79 % (4.0) |
     | static | 4 % | 8 % | 42 % (2.9) |
     | jigging | 3 % | 1 % | 18 % (1.5) |

     For towed gear without times, the day is the unit as a rule. For static gear and jigging, the record mostly is
     the day already, but less so since 2021.
   - **Landings** (row 4, where the logbook is missing; and as the weighed total).
     - Trips and landings link many-to-many (item 5), so a landing unit is a connected set:
       - one weekly landing over several trips;
       - several sales notes (one per buyer) for one trip, summed.
     - Its catch is shared over the fishing fixes of its voyages; fishing comes from item 3.
     - Where a trip has both a logbook and a landing, one source carries its catch, never both. The logbook says where
       the catch was taken; the landing is weighed.
     - The two record in different units: tonnes against kilograms, and the logbook's condition against the
       landing's product code. They are put on one unit (kilograms, live weight) before they are compared, summed or
       raised. The conversion factors are an input, never a constant in code.
     - A landing can carry another vessel's catch (transhipment, item 5). Its unit then spans both vessels' voyages.
     - **Raising is a column, not a choice** (maintainer).
       - Where a trip has both, each fix keeps its logbook-based share (`kg`) and carries a raising factor beside it:
         landed over logged, per species and trip, in one unit.
       - The raised value is `kg` × the factor. The user chooses, and nothing is overwritten.
       - The ICES data call raises in effect, by allocating sales-note landings to log events.
   - **Up a level.** Catch with no fishing fix in its unit moves up a level, so totals are kept: record unit → trip →
     landing set → vessel × period. `catch_basis` and the unit's `resolution` say where each kilogram came from.
   - ramb:
     - `rb_build_catch_units()`: records, their windows, trips, landings and the links in; units with their
       `resolution` and members out.
     - `rb_share_catch(pings, units)`: by effort.
     - Today's `rb_share_catch()` is EFLALO-shaped (`VE_REF`, `FT_REF`, `LE_KG`). It shares evenly, and has no haul
       level and nothing above the trip. Its ICES behaviour stays as a method.
   - fishycode: station catch, trip catch, landings with `lid_map`, and duplicate twins left out (decision 094).
3. **Fishing decided per unit, by whichever side is more precise** (step 4, with gear for it; rows 1–5; rethink 1).
   This is where the paths part: today a fix outside every window is never fishing.
   - ramb:
     - `rb_assign_fishing()` as a per-fix cascade whose order comes from the path, not from the call:
       - a timed record on a sparse track: `"window"`, then `"speed"` as the check;
       - a dense track, or a coarse record or none: `"speed"` (later the track models, item 9), with the window as the
         check where there is one;
       - neither: not decided.
     - `fishing_basis` says which side decided. Where both were used, a label says whether they agree.
     - First build: `"window"` and `"speed"` only. The track's precision is the interval between fixes.
     - The gear for it: the record, landing and none tiers of `rb_assign_gear()`.
       - On hold since 2026-10-08 because a trip can carry several gears.
       - This takes only the unambiguous case: one gear class on the voyage.
   - fishycode: each voyage's gear from its logbook trip or its landing; the wiring.
   - The fallback's cost is already measured on the recorded windows (decision 090, ±10 min speed). It calls fishing
     inside the windows, and not fishing far from them, at these rates:
     - towed gear: 93 % / 88 %;
     - static gear: 90 / 77 %;
     - jigging: 63 / 85 %.
4. **Records checked against the operations the track shows** (steps 2 and 4; rows 1–3). The path is chosen from
   both sides, not from the declaration alone (maintainer).
   - One record in a day can hide several operations that the track shows, e.g. several settings, or several tows.
     - The record is then a summary, whatever its times say.
     - Its unit widens to the day (or the voyage).
     - Fishing comes from the track's operations, and the catch is shared over all of them.
   - The reverse also happens: a record whose operation the track does not show (sparse pings, or a wrong record).
     Its catch moves up a level.
   - Per vessel-day, the records are compared with the operations found on the track:
     - **as many, and they pair:** the record path;
     - **more on the track:** the records summarise; the day or voyage is the unit, and fishing comes from the track;
     - **fewer on the track:** the records are unseen; the catch moves up.
     - The case is kept beside the record's declared resolution.
   - Seen so far, not counted for this purpose:
     - In June 2023, 30 % of towing-speed stretches held no declared tow (decision 092).
     - A day window calls 18–30 % more static fixes fishing than the real hauls (plan 004 §8).
     - How many records the track shows to be summaries is not measured; it is the first step of this item.
   - ramb:
     - The operations come from the existing pieces: `rb_cut_record_stretches()` and `rb_link_record_stretches()`
       (towed gear), and `rb_link_record_sets()` (static gear, item 8).
     - New: a step that reads the pairing and gives each record its case and its effective resolution.
       `rb_build_catch_units()` (item 2) then uses that.
     - Named per the verb table.
   - fishycode: wire it after item 3. A summary record's fixes then take the track path inside its day.

5. **Landings linked to trips and voyages** (step 1; rows 4 and 9).
   - ramb: `rb_link_trip_landings()`, many-to-many (several sales notes per trip, one weekly landing over several
     trips), a cascade of match rules.
   - Links can cross vessels: a carrier lands what a catcher took (pelagic species only, codes 30–36). ramb also gets an encounter step (two vessels side
     by side, slow, for a sustained time) as evidence for such a link. It is generic, the same kind of event GFW calls
     an encounter, and its thresholds are set on data where the transfers are known.
   - fishycode:
     - **Foreign landings** are most of rows 4 and 9.
       - Their catch has a landing and, for most, an AIS voyage, but no record.
       - So they take the landing path: fishing from the track, catch per landing.
       - Their track reaches the trail only once TODO 22 is closed.
       - Fiskistofa receives foreign vessels' logbooks for Icelandic waters, and more of them over time (maintainer,
         2026-10-14). They are a source to acquire (a `dump/` script and a `sources/` adapter). Once acquired, much
         of this catch takes the record path.
     - **Icelandic landings with no logbook trip:** check which are missed matches in `lid_map` and which are
       transfers. Use each vessel's catch balance (logbook against landed, in one unit) together with the encounters.
     - Then link landings to voyages on the flow side: the link reads AIS, so it is not preprocessing.
     - Those voyages get `trip_basis` from the landing.
   - With item 3, landing-only voyages get fishing from the track and catch per landing. `T2` reconciliation (phase 4)
     then has all three candidates.
6. **Which vessels fish** (the vessel row; rows 5, 6 and 10).
   - ramb: `rb_assign_vessel()` (planned): the time-bounded id → vessel join, keeping vessel `none`.
   - fishycode:
     - a vessel class on the voyage, so the voyages of vessels that land nothing are labelled, not counted as missing
       logbooks (`R/entity_class.R`, TODO 23).
       - Aquaculture service and whale watching are the two to recognise first (row 6).
       - The registry gives these vessels no class, so the class comes from another register or from the activity
         itself: home port, fjord-bound tracks, short day trips. It is a basis like any other.
     - TODO 49's decision for fishing vessels with neither a logbook trip nor a landing;
     - TODO 22 (foreign vessels kept) and TODO 25 (no unassigned ping).
7. **Records without pings** (rows 7–8).
   - ramb: a step that gives a record with no pings positions to carry effort and catch.
     - Built from its start (and end) position and times, at a set interval.
     - `pos_basis` is `synthesised`; the record's `resolution` is kept.
     - Generic: logbooks with positions and no tracking are common (small vessels, the years before VMS).
     - Named per the verb table, e.g. `rb_build_record_pings()`.
   - fishycode:
     - the 1990–2006 logbook;
     - the later trips no voyage covers.
     - Whether the records before 1990 are in scope is the maintainer's call.
   - Effort from such a record is its duration, not a track, and the basis says so.
8. **Static gear** (rows 1–3, static).
   - ramb:
     - `rb_link_record_sets()` (set ↔ haul pairing, phase 4 design);
     - pressure as quantity × soak in `rb_assign_effort()`.
   - fishycode: gear quantity (nets, hooks) from the logbook where it is recorded.
   - TODO 18 stays parked.
9. **Track models for fishing** (step 4 beyond speed).
   - ramb: `"gmm"`, `"embc"`, `"hmm"`, and phases from a dense track (phase 4 design). For datasets without times
     these are the main path; for Iceland they matter least, since item 3 covers most fixes.
   - fishycode is the test bench:
     - row 1 from 2013 is a large labelled set, with fixes minutes apart;
     - score each method on it by gear, and again after down-sampling to 30 min (the EU Control Regulation's interval,
       WGSFD ToR C).
     - If any of it leaves MFRI, for instance as ToR C's reference dataset, that needs an agreed basis first.
10. **Declared times reconciled with the track** (`rb_reconcile_time()`, phase 4). Waits for ground truth (TODO 60).

Items 1–4 change the trail; one rebuild serves them. Each item ends as the phases do: ramb tests pass,
`check_bookkeeping()` passes, and a decision record and a commit are made in each repo.

**Asked of the maintainer:** nothing open (2026-10-14). The order, both ways of deciding activity, raising as a
column, and approaches side by side were settled the same day.

## Step A, now, for the WGSFD meeting. Approving this plan approves only this step.

Write version 2 of the one-flow document in `~/stasi/wgsfd2026/`. Version 1 is left untouched.

- **The diagram.**
  - `one_flow_cascade_v2.svg`: the diagram shown in chat (version 2), as a standalone SVG with explicit styles,
    since the chat's CSS classes are not available outside it.
  - `one_flow_cascade_v2.png`, rendered from it.
- **The document.** `one_flow_effort_pressure_catch_v2.md` is the version 1 text with the new figure, plus only the
  edits the diagram implies, in the doc's own short-bullet style:
  - two short entries before step 1:
    - vessel (`assign_vessel`): registry > own track > logbook/landing > continuity;
    - flag pings (`flag_pings`): invalid > duplicate > impossible, set aside; harbour pings stay in the trail;
  - step 1:
    - the voyage is built from harbour stays;
    - a "link and reconcile `T2`" bullet: many-to-many, covering sales notes per buyer and weekly landings over
      several trips;
  - step 2: the two-way note;
  - step 4: haul window + speed range;
  - step 6:
    - a "several trips (e.g. weekly landing)" row;
    - the sentence "catch can be coarser than the activity; each unit is shared over the fishing pings it covers";
  - "every ping is kept" becomes "every ping is accounted for; impossible pings are set aside";
  - the basis list adds `derived`;
  - the AI-use line gets a v2 entry: "diagram and matching edits drafted by Claude, 2026-10-08; human review
    pending".
- **The rendered page.** `one_flow_effort_pressure_catch_v2.html`, rendered with quarto. A clean render is enough;
  the output is not scraped.
- **What it does not touch:** the claude.ai master doc and version 1's files.
- **Then stop.** Phases 0–5 below start only on a separate go.

## Context

The WGSFD 2026 working document (`~/stasi/wgsfd2026/one_flow_effort_pressure_catch.md`, master on claude.ai rev 108)
describes one generic, per-ping flow: flag pings, then six steps (trip, logbook record, gear, fishing, effort and
pressure, catch and value). Each step takes the best source per ping, falls back when it is missing, labels the ping
with a basis, and keeps every ping.

The maintainer wants:

- **ramb** to be generic, with a function for every panel of the diagram;
- the Icelandic data (fishycode) to serve as the template for some cases;
- fishycode to call ramb wherever possible: anything of WGSFD value now in fishycode is generalised into ramb, then
  used from fishycode;
- names that are verb-ish and consistent, and that show where in the flow a function sits.

**Audit (2026-10-08).** Of the seven steps:

- ramb captures two: impossible positions (`rb_whack_clean`) and catch sharing (`dc_spread_cash_and_catch`, partly; renamed `rb_share_catch` on 2026-10-11).
- It has building blocks for three: trip, gear and effort.
- It has nothing for two: the logbook record, and the decision whether a ping is fishing.
- No ramb function writes a basis.

The step logic lives in fishycode scripts and SQL. ramb's own speed-profile and trip methods were removed in 2021–2025,
mostly because of their package dependencies.

**Maintainer direction (2026-10-08):**

| Step | Direction |
|---|---|
| 0 | Impossible positions go in a separate table; harbour pings stay in the trail. |
| 1 | `T2` is to be resolved by comparing logbook, landings and AIS, and no vessel should be without a trip. The design is open. |
| 3 | Gear on the trail, but on hold, because global data have several gears per trip. |
| 4 | The data are fishy, so this needs deep thought first. |
| 5–6 | Downstream, outside fishycode; ramb still gets generic functions for them. **Replaced 2026-10-14:** steps 5–6 are part of the aim and are built in the fishycode flow (maintainer). |

## Decided by the maintainer (2026-10-08)

1. **Names.**
   - A function that belongs to a step is `rb_<verb>_<stage>[_<detail>]`, verb first. The stage word marks its
     place on the diagram's vertical line: `vessel`, `ping`, `trip`, `record`, `gear`, `fishing`, `effort`, `catch`.
   - Tools that serve every step are `rb_<verb>_<object>`.
   - All existing exports are renamed, and each old name stays as an alias that warns it will be removed (item 8).
     It replaces the bare `.Deprecated()` of `R/whackies.R:802-847`.
2. **One task, one function.** Where several functions do one task, they become one function with a `method =`
   argument.
3. **Columns.**
   - Inputs default to the grammar names (`vid`, `time`, `lon`, `lat`, `speed`, `T1`, `T2`, `t1`–`t4`), each
     overridable by an argument with tidy evaluation (`vid = vessel_id`).
   - Added columns use the doc's names (`trip_id`, `record_id`, `n_records`, `fishing`, `harbour_id`,
     `<stage>_basis`).
4. **Basis values:** `recorded | derived | reconstructed | synthesised | none`.
   - `derived` means computed from recorded values of the same record (`t2 + duration`).
   - Modifiers (`capped`, `placeholder`) go in their own columns.
5. **MFRI-only readers** stay in ramb, renamed `rb_read_*_mfri` and marked as MFRI-only.
6. **Lazy-first, no new Imports.** Code from other packages is recoded, not copied (rule below).

7. **`duckdbfs` is the default for reading and writing**
   - **Lazy inputs:**
     - Examples, docs and readers (`rb_read_*_mfri`) open data with `duckdbfs::open_dataset()`.
     - Test fixtures are made lazy with `duckdbfs::as_dataset()`.
     - `duckdbfs` moves from Suggests to Imports.
   - **One connection:**
     - Everything opened through `duckdbfs` shares its cached connection.
     - Tier-2 SQL takes the connection from the input (`dbplyr::remote_con`), which is that cached connection.
     - A function with several lazy inputs stops with a clear message if they are on different connections.
     - `rb_register_macros(con = duckdbfs::cached_connection())`.
   - **Writing:**
     - Anything ramb writes goes through `duckdbfs::write_dataset()`.
     - This includes the tier-4 label batches: written as temporary parquet, opened with `open_dataset()`, joined
       lazily. This replaces today's never-dropped temp tables.
     - fishycode's lesson (`R/write_parquet.R`) applies: a materialised frame that `write_dataset()` registers in the
       cached connection must be released after each batch, or a loop accumulates it (48 GB spilled in the ASTD-B
       run).
     - fishycode keeps `write_curated()` for `curated/`, because it adds the provenance stamps.
8. **Aliases warn that the old name will go.**
   - **Renamed functions:** a small internal helper `.rb_renamed(old, new)` warns once per session per name, so a loop
     over batches warns once, not thousands of times. For example: "`rb_speed()` is now `rb_calc_speed()`. The old
     name still works but will be removed in a future version."
   - **Deprecated functions that keep their old body:** the warning says what supersedes them and that the old
     function will be removed. For example: "`rb_trip()` is superseded by `rb_cut_trip_voyages()` and will be removed
     in a future version; until then it behaves as before."
   - **Tests:** each alias test checks the warning and that the result is unchanged.
   - **No `lifecycle` dependency;** this is base `warning()` with a session registry.
   - **`NEWS.md`** lists every old name with its replacement.

9. **Never break on missing inputs; the same output at every resolution** (maintainer, 2026-10-09). Every step
   function runs when the declared inputs are absent (no trip table, no station table, no landings) and returns the
   same columns: filled from the track where it can (`T1`/`T2` from stays, `t1`–`t4` from the track, sets paired with
   hauls), otherwise empty with basis `none`. What fills the output depends on the data; its shape does not. Each step
   function's tests include a run with the declared inputs set to `NULL`.

## Decided in this plan (change at approval if you disagree)

- **One label column for step 0.**
  - The ping flaggers share `ping_flag`: NA means a good ping; otherwise it holds the reason, e.g. `invalid`,
    `duplicate`, `vmask`, `spike`, `forward`.
  - Each flagger tests only rows not yet flagged, so
    `pings |> rb_flag_ping_invalid() |> rb_flag_ping_duplicate() |> rb_flag_ping_impossible()`
    reproduces `ais_ping_clean.R:91-103`.
  - The doc's `impossible` is `!is.na(ping_flag)`.
  - The function is named `rb_flag_ping_impossible`, the doc's word, not "whacky". The old `rb_whack_*` names stay as
    aliases.
- **`harbour_id` is the harbour polygon's id**, which is fishycode's `pid`, not the landing code `hid` (TODO 3c).
- **The gear speed range is `speed_min`/`speed_max` in ramb.** This removes the clash with the grammar's station
  bounds `s1`/`s2`. fishycode keeps `s1`/`s2` on the trail and maps them at its boundary.
- **Each step function returns one thing.**
  - `rb_cut_trip_voyages` returns the voyage table only. Pings get their voyage through `rb_assign_trip(voyages =)`.
  - `rb_assign_record` returns the pings. A separate `rb_link_record_pings` returns the table that links each ping
    to every record covering it.

## The verb table (what each verb means)

| Verb | Means | Returns |
|---|---|---|
| `flag` | label rows with a state; no row is dropped | table + label column |
| `assign` | a diagram step: a key or value from the best source, with a basis | table + value + `*_basis` |
| `share` | distribute a quantity over rows, conserving the total | table + shares |
| `find` | derive intervals or events from a track | new table |
| `cut` | split a track into segments | segment table |
| `build` | a rule or window table that a step consumes | new table |
| `link` | crosswalk two tables, ambiguity kept | link table |
| `limit` | judge a value against a rule; raw kept, value set NA when implausible | table + column |
| `number` | number runs or segments within a vector | integer vector |
| `detect` | per-row logical, for use inside `mutate()` | logical vector |
| `calc` | per-row numeric derivative | numeric vector |
| `encode` / `extract` / `convert` / `bin` | codes, metier parts, units, grids | vector |
| `interpolate` / `fill` / `predict` / `classify` / `lookup` / `cap` / `standardise` / `sum` | as in English | vector or table |
| `check` | validate a table and warn | the table, unchanged |
| `get` / `read` / `plot` / `rasterize` / `rayshade` / `register` / `keep` / `drop` / `create` / `peek` | as in English | as now |

A method never appears in a name; it is always `method =`. A grouping never appears in a method; it is always `by =`.
A ramb test enforces the table: every export except the deprecated aliases starts `rb_<verb>_`.

## Lazy-first rule, and dependencies

Each function is written at the first tier that can express it:

1. **dplyr that dbplyr translates.** One body serves data frames and DuckDB. Examples: voyage numbering by runs, the
   declared-trip join, effort intervals (`lead()`), catch shares, the landing-link cascade, jepol trip cutting.
2. **DuckDB SQL rendered from the lazy input** (`dbplyr::remote_con` + `sql_render`, returning `tbl(con, sql(...))`).
   Examples: ASOF joins, window frames, `QUALIFY`, recursive CTEs, harbour stays, record windows, ping-to-record
   matching, track interpolation, `fwdbwd`, and the neighbour tests of `sda`.
3. **Reduce lazily, fit small, apply lazily.** For the speed-profile models: speeds (and turning angles) are binned in
   DuckDB, overall or `by =` trip; a weighted EM is fitted in R on the bins; the fitted thresholds or states are
   applied back in SQL. This covers the Gaussian mixture and binary clustering.
4. **Sequential cores only** (the forward whack scan, HMM decoding): Rcpp behind a batched lazy wrapper, the
   `rb_whack_clean` pattern (`whackies.R:757-799`). One batch of vessels is collected, labelled in C++, only the
   labels are written back, and a lazy join is returned. The temp table must be dropped when it is no longer needed;
   today it never is.

**Macro twins.** The per-row tools (`rb_calc_distance`, `rb_convert_speed`, `rb_encode_ices_rectangle`,
`rb_encode_csquare`, `rb_bin_midpoint`) get a DuckDB macro of the same name, registered by `rb_register_macros(con)`.
The same `mutate()` then runs on a lazy table. For `rb_calc_distance`, see "One distance function" below.

**Recoding.**

- An algorithm that came from another package is recoded at the lowest tier that can express it. The original
  package goes in Suggests only, for an equivalence test with `skip_if_not_installed()`. This is the pattern of
  `rb_whack_sda` against `argosfilter` (`tests/testthat/test-rb_whack_clean.R:47-48`).
- Imports reviewed:

  | Import | Action |
  |---|---|
  | `data.table` (jepol) | recode |
  | `traipse` (geodesics) | recode |
  | `geo::arcdist` and `trip::` (both undeclared) | recode |
  | `terra`, `mapdeck`, `scales`, and `sf` for plotting | Suggests |
  | `icesVocab` | Suggests |
  | `omar`, `geo` | Suggests, with `Remotes` |
  | `duckdbfs` | Suggests → Imports (the default reader and writer) |
  | `glue` | replaced by `sprintf` |

**Every step function has a test** that runs the same fixture as a data frame and as a DuckDB table and compares the
results. One known divergence to fix: `fwdbwd` gives FALSE at track ends on a data frame but NA on DuckDB.

## One distance function (maintainer's direction, 2026-10-09)

*The direction is the maintainer's: one function with a `method` argument; DuckDB spatial on lazy tables; Rcpp
where there is a loop. The default and every number below were proposed and measured by Claude (AI-assisted) in the
session of 2026-10-09. Nothing is built yet.*

ramb has two distance definitions today:
- **An ellipsoid:** Vincenty, `.rb_geodesic`, used by `rb_calc_speed`.
- **A sphere:** haversine with R = 6,371,000 m, used by `rb_calc_distance`, the speed filters' C++ and `rb_flag_ping_duplicate`.

They become one function:

`rb_calc_distance(lon1, lat1, lon2, lat2, method = c("geodesic", "andoyer", "haversine"))`

- **`"geodesic"`, the default.** Exact on WGS84.
  - **Data frame:** Karney's algorithm, from GeographicLib's C code (`geodesic.c`/`geodesic.h`, MIT) added to ramb's
    `src/` with its licence notice. It is called through Rcpp, and it is one C++ entry point that the speed filters also call. It
    replaces `.rb_geodesic` (Vincenty).
  - **Lazy:** DuckDB spatial's `ST_Distance_Spheroid`, which is the same algorithm (through PROJ). It takes points as (lat, lon);
    the macro fixes the order.
  - **Why Karney, not Vincenty (maintainer, 2026-10-09).** Vincenty fails near the antipode, which is never a real leg but
    possible for a garbage ping, and ramb's version fails without any signal. From Iceland (64° N, 22° W) to a ping at the
    antipode it is 19,441 m short; at 157.9° E, 63.95° S it is 7,059 m short. Andoyer–Lambert cannot stand in for it: it is
    6,476 m long at the antipode. NA was ruled out by the maintainer. Karney is exact everywhere, so there is no fallback
    branch. Data frames, the C++ filters and lazy tables run one algorithm and agree on every leg.
  - **A deliberate exception to the "recode" rule above.** The C code is taken in unchanged, not recoded. Recoding Karney's
    numerics by hand is where errors would enter, and a reference library kept with its licence is not the forked script the
    rule was written against.
- **`"andoyer"`:** Andoyer–Lambert, a closed form with no loop. It runs as a plain DuckDB macro, without the spatial extension.
- **`"haversine"`:** the sphere, to reproduce older outputs.

**Why exact by default.** Measured against Karney's geodesic (geodist) on:
- 3,293,579 Icelandic legs (June 2023);
- a grid of 18 bearings and legs of 10 m to 100 km at 45° S to 75° N;
- WKSSFGEO's Adriatic (43–44° N), Portuguese (37° N) and `dansk` (55–57° N) tracks.

| Method | Worst error | Time per million legs, data frame / DuckDB |
|---|---|---|
| exact (Vincenty in R today; `ST_Distance_Spheroid`) | under 3e-6 m on real legs / 2e-9 m | 0.5–0.9 s / 0.12 s |
| Andoyer–Lambert | 1.4e-6 of the distance (14 mm per 10 km up to 50°, 8 mm at 65° N); R and macro equal to 2e-9 m | 0.30 s / 0.06 s |
| haversine | −0.44 % to +0.56 % by latitude and direction; at 35° N +0.23 % north–south, −0.22 % east–west | 0.08 s / 0.02 s |

- **The sphere's error is a bias, not noise.** At low latitudes it also changes sign with direction, so no regional radius
  fixes it. Any summed distance (track km, effort, swept area) would carry it. On real legs: 18 m in the Adriatic,
  340 m on a 104 km Danish leg.
- **Two exact implementations agree** (to 2e-9 m), so the data-frame and lazy results pass this plan's equality test
  with no tolerance. Andoyer on one side and spatial on the other would differ by up to 14 mm per 10 km.

**Lazy mechanics** (tested with DuckDB 1.5.6 and dbplyr):

- **The switch is a macro, not a test.** Inside `mutate()` on a lazy table, dbplyr never runs the R function; it passes
  the call to SQL by name. So the switch is a macro named `rb_calc_distance`, registered by `rb_register_macros(con)`,
  not an `inherits(x, "tbl_lazy")` test. Step functions that take a table keep that test and write the same call into
  their SQL.
- **The method is always the fifth argument, never named.** dbplyr cannot pass a named argument: `method = "haversine"`
  renders as `'haversine' AS "method"`, a parser error. An overloaded macro does work: 4 arguments take the default, and a
  fifth, positional argument is the method.
- **The defaults cannot drift.** A macro cannot call itself, so the 4-argument form calls a shared helper macro. R writes
  the macro SQL from the same constants as the R code.
- **Registration checks itself.** `rb_register_macros()` loads spatial and checks one known distance (1° of latitude at
  64° N). NaN or a wrong value stops it: with (lon, lat) the spatial function returned NaN without an error. If spatial
  cannot load, it stops. It never falls back to another method silently.
- **The speed filters are the exception.** They pull batches into R even on lazy tables (tier 4), so their distance is the
  C++ one, and it must be the same exact function.

**Before switching the filters and the duplicate rule** (`DUP_M` = 128.6 m) to the default, count the change, as
decision 069 counted the time-step floor. At 64° N distances grow by about 0.33 %, about 0.08 kn at 25 kn.

**Assumed, not measured:**
- that GeographicLib's C code, called through Rcpp, is at least as fast as the R Vincenty (0.5–0.9 s per million legs). geodist,
  which uses Karney's algorithm, took 1.6 s per million legs including its R overhead;
- that DuckDB spatial keeps the (lat, lon) order in later versions (the registration check guards this).

## What the diagram may be missing (from fishydata)

1. **Vessel identity.** Pings arrive as an MMSI or a mobile id. Mapping them to a vessel that changes over time is a
   stage of its own (`vessel`); it took plans 003, 008 and 009 in fishycode.
2. **Several feeds.** Merging feeds needs a feed priority and the flagging of cross-feed copies (decision 069).
3. **Harbour stays, not harbour pings.** Trips from the track need stays measured in elapsed time, a minimum stay by
   harbour class and year, and a departure radius per harbour. That is a builder the diagram hides.
4. **Sources checked against each other before the cascade.** `T2` reconciliation; logbook ↔ landing ↔ voyage links
   (products in themselves); corrections that keep the original value; human overrides as inputs (how cycles are
   broken).
5. **Two-way flow.** Records also get positions and times from the track: logger fixes on the AIS track, haul
   positions from pings.
6. **Ambiguity is kept.** Several records can cover one ping, and one voyage can carry several logbook trips (3–4 %),
   so counts and links are needed alongside "finest first".
7. **A fourth basis value**, `derived`: the doc uses it in step 4.
8. **Not every ping is kept; every ping is accounted for.**
   - Impossible positions are set aside in their own table (whacky pings, `ping_whacky`); every other ping stays in
     the trail. Pings in = pings out across the two tables.
   - The ramb flaggers only label. The caller does the split.
9. **Catch can be coarser than the activity.**
   - Fishing may be resolved per ping and per haul (`t1`–`t4`) while catch arrives per day × rectangle, or as a
     weekly landing that covers several daily trips.
   - Step 6's units therefore go above the trip ("several trips", e.g. a weekly landing; as a last resort vessel ×
     period). Each unit's catch is shared over the fishing pings it covers, by effort.
   - Trips and landings link many-to-many: several sales notes per trip (one per buyer), one weekly landing over
     several trips.
   - Sales notes are already in the landing panel; no new box.

## Using the functions alone and in the flow (robustness to misuse)

*Maintainer, 2026-10-09: ramb will have many functions. A user may call one alone, to look at one aspect of the data,
or run them all to deliver the ICES data call or an institute's own product. The functions must not let a user
silently get it wrong, and should say which steps the data need first. Design drafted by Claude (AI-assisted) from
established practice; nothing is built yet. To be built before phase 4 adds its functions, and retrofitted to the
step 0-2 functions first.*

**Prior art.** The problem is old and the methods are established. ramb takes the following from each:

| Practice | Where it is used | What ramb takes |
|---|---|---|
| Design by contract: preconditions and postconditions (Meyer) | software engineering generally | each step function states what it needs and what it guarantees to add |
| Data contracts at pipeline boundaries | pandera (decorators that check a function's input and output frames), pointblank (step-by-step validation reports), Great Expectations | a light contract per function (columns and types), with no dependency on these packages |
| State inferred from what a step leaves behind | scikit-learn `check_is_fitted`: "fitted" is read from attributes ending in `_`; `NotFittedError` says what to call first | the flow state is read from the columns a step adds; the message names the step to run first |
| One test suite run over every component | scikit-learn `check_estimator` | one shared misuse test suite run over every step function |
| Recipes and pipelines | tidymodels `recipes` (steps, then `prep`/`bake`), scikit-learn `Pipeline` | the two layers below: single verbs, and recipes that run them in order |
| Structural assertions for movement data | move2 (`mt_is_time_ordered`, `mt_is_track_id_cleaved`, `mt_has_unique_location_time_records`, used with `assert_that()`), tsibble (key and index validity), amt (`make_track()`) | cheap structural checks: grouped by vessel, ordered in time, unique `(vid, time)` |
| Error messages for people | the tidyverse style guide (a problem statement with "must" or "can't", then `x` and `i` bullets, naming the call), via rlang | ramb's message style, plus one line with the code that fixes it |

**Not classes or attributes.** move2, amt, tsibble and sf mark state with a class or attributes. Both are lost when a
table is written to parquet or passed through a lazy DuckDB query, which is how ramb is used. ramb reads state from
**columns**, which survive both.

**The design.**

1. **A step registry.** One internal table, one row per exported step function: its stage, the columns it **needs**,
   the columns it **adds**, and the step that normally comes before it. Checks, messages, documentation, the misuse
   tests and a user-facing `rb_check_flow(x)` are all generated from it. `rb_check_flow(x)` reports which steps a
   table has been through and what comes next. A test fails if an exported step function has no row.
2. **A contract check at the top of each function.** One internal helper (`.rb_check_input(x, fn, ...)`) reads the
   registry and checks:
   - the needed columns, under the user's column names (tidy evaluation, as now);
   - their types: a date-time for times, numbers for positions;
   - on a lazy table, the schema only, with value checks (latitude range, plausible units) on a small sample. They
     can be switched off with `check = FALSE`, so a 500 M-row table is never scanned for a check.
3. **Three responses, by harm:**
   - *stop* when the result would be silently wrong: a needed column missing, latitude outside ±90, a time that is
     not a date-time, an input from the wrong stage;
   - *warn once per session* when it runs but worse, e.g. stays from pings that were never flagged (the existing
     warn-once registry of `.rb_renamed`);
   - *fix quietly* where there is one right answer: sort by vessel and time, treat times as UTC.

   A missing **declared** input (no logbook, no landings) is a normal case, not misuse (decided item 9): the
   function runs and fills basis `none`. A missing **prerequisite step** gets a message.
4. **Messages** follow the tidyverse style through `rlang::abort()`/`rlang::warn()`, adding no dependency. Each says
   what is wrong, why it matters, and what to run first. The last line is taken from the registry, never written by
   hand:

   ```
   Error in `rb_cut_trip_voyages()`:
   ! `stays` must be supplied for method "stays".
   x `stays` is missing.
   i Voyages run from one stay in port to the next.
   i Run first: stays <- rb_find_trip_stays(pings, ports)
   ```
5. **Two layers.**
   - The single verbs: permissive, column names as arguments, on a data frame or a lazy table.
   - Recipes that run the steps in order with sensible defaults: `rb_flow()`, with presets such as `"ices_datacall"`
     or an institute's own. Most users never assemble the steps by hand, which removes most of the room for misuse.
6. **A shared misuse test suite**, generated from the registry and run over every step function, as
   `check_estimator` does in scikit-learn. Each function is tested with:
   - each needed column missing, where the error must name the step that adds it;
   - wrong types;
   - unsorted input;
   - a lazy table, which must equal the data frame;
   - the declared inputs `NULL`, which must give the same columns;
   - messages snapshot-tested (`expect_snapshot`), so they do not rot.
7. **Provenance as the last net.** If a user still gets it wrong, the basis and case columns show it in the output.

**Costs.** The registry must stay in step with the functions; the test of item 1 enforces that. Checks add a little
time per call; lazy tables are checked by schema only. Messages need care to stay short.

## Function map: panel → ramb function → template

| Stage | ramb function | Template, origin, status |
|---|---|---|
| vessel | `rb_assign_vessel(pings, key)`: the time-bounded join | `reference/vessels/ais_key.R`; the key builder stays in fishycode |
| ping | `rb_flag_ping_invalid(rules)` | `ais_ping_clean.R:94`: `lon == lat`, (0,0), out of range |
| ping | `rb_flag_ping_duplicate(feed, priority)` (no default priority) | `rb_whack_duplicates` (vector core becomes internal) |
| ping | `rb_flag_ping_impossible(method = "clean" \| "sda" \| "forward" \| "fwdbwd" \| "sequential" \| "distance")` | `rb_whack_clean`, the other labelling filters, and the removed `rb_whacky_points` |
| ping | `rb_flag_ping_harbour(pings, harbours)` → `harbour_id` | `curate/ais_ping_tag.R` (port last: it re-runs the filter on 543 M pings) |
| trip | `rb_find_trip_stays(pings, harbours, min_stay, radius_in, radius_out, events = NULL)` | `curate/harbour_stay.R`; STK event pairs become the optional `events` |
| trip | `rb_cut_trip_voyages(pings, stays, method = "stays" \| "runs" \| "jepol", min_pings, split_at_year)` | `curate/ais_trip.R` (keep its choices: per-year cut, numbering before the `MIN_PINGS` filter); `rb_trip`, `rb_trip_jepol`, removed `define_trips_pol` |
| trip | `rb_link_trip_voyages(trips, voyages)` | `curate/link_trip_voyage.R` |
| trip | `rb_link_trip_landings(trips, landings, method = "cascade" \| "nearest_date")`: a many-to-many link table (sales notes per buyer; weekly landings over several trips) | `curate/link_lid_map.R`; removed `match_nearest_date`. **Phase 4** |
| trip | `rb_assign_trip(pings, trips, landings, voyages)` → `trip_id`, `trip_basis` | the declared tier from `rb_link_trip_logbook` (was `rb_add_tripid`; rewritten: it fails silently on DuckDB); the `T2` tier is phase 4 |
| record | `rb_limit_record_duration(records, rules)` | `R/duration_limit.R` |
| record | `rb_build_record_windows(records, rules)` | `curate/station_window.R`; the adb `t1`/`t4` swap stays in fishycode |
| record | `rb_assign_record(pings, windows)` → `record_id`, `phase`, `n_records`, `record_basis` | `R/trail_sql.R` |
| record | `rb_link_record_pings(pings, windows)` | `trail_match` in `R/trail_sql.R` |
| record | `rb_link_record_sets(hauls, pings)` → per static-gear haul: set time, soak, the voyage that set it, `basis` reconstructed | iapesca `Create_Nets` + `Retrieve_SettingOperations`, recoded with attribution (decision 078). **Phase 4** |
| gear | `rb_assign_gear(...)`, `rb_predict_gear_width(method = "benthis")`, `rb_fill_gear_width(rules)` | `curate/corrections/adb_gear.R`, `rb_benthis_width`, `rb_gearwidth_proxy`. **On hold** |
| fishing | `rb_assign_fishing(method = "window" \| "speed" \| "gmm" \| "embc" \| "hmm", by = NULL)` | `"window"` = `R/trail_sql.R`, ported as it is in phase 3; the rest in **phase 4** (the removed `R/models.R` is the specification, rewritten) |
| fishing | `rb_build_fishing_speeds(method = "declared" \| "recorded_windows" \| "gmm", by = NULL)` | `reference/gear/windows.R`, plan 012, removed `rb_gaussian` |
| effort | `rb_assign_effort(pings, vessels, widths)` | `products/ices_vms_datacall/build.R` (stale); ramb only |
| catch | `rb_share_catch(pings, catch, landings, method = "effort" \| "equal")`: units at any resolution, including units above the trip (several trips; vessel × period); uncovered catch moves up a level | `dc_spread_cash_and_catch`, removed `dc_split_among_pings`; ramb only |

## Current exports: one-to-one renames (phase 1a; behaviour unchanged)

| New | Old (kept as an alias) |
|---|---|
| `rb_calc_speed`, `rb_calc_distance`, `rb_calc_step_time`, `rb_calc_step_acceleration`, `rb_calc_track_time` | `rb_speed`, `rb_distance`, `rb_st`, `rb_sa`, `rb_track_time` |
| `rb_convert_speed(x, from, to)` | `rb_ms2kn`, `rb_kn2ms` |
| `rb_number_runs` | `rb_event` |
| `rb_encode_ices_rectangle`, `rb_bin_midpoint` | `rb_d2ir`, `rb_midpoint` |
| `rb_detect_in_polygons`, `rb_keep_in_polygons`, `rb_drop_in_polygons` | `rb_points_in_polygons`, `rb_st_keep` (the `spatial.R` body), `rb_st_drop` |
| `rb_extract_metier` (`part =`) | `rb_gear_from_metier`, `rb_target_from_metier`, `rb_met5_from6` |
| `rb_get_gear_vocabulary` (`list =`) | `rb_get_ices_*` |
| `rb_predict_gear_width`, `rb_fill_gear_width`, `rb_standardise_gear_meshsize` | `rb_benthis_width`, `rb_gearwidth_proxy`, `rb_std_meshsize` |
| `rb_classify_mmsi`, `rb_lookup_mmsi_country` | `rb_mmsi_category`, `rb_mmsi_flag` |
| `rb_cap_outliers` (`method =`) | `rb_cap_iqr`, `rb_cap_miller`, `rb_cap_winsorize` |
| `rb_detect_crosses_year`, `rb_check_trip_crosses_year`, `rb_create_timestamp` | `rb_check_crosses_year`, `dc_check_eflalo_crosses_year`, `dc_create_timestamp` |
| `rb_plot_trail`, `rb_plot_trip`, `rb_rasterize_xyz`, `rb_rayshade_raster`, … | `rb_mapdeck`, `rb_md_trip`, every `mb_*` (each listed in NEWS.md, including the misspelt `mb_rashade_xyz_dynamic`) |
| `rb_read_logbook_mfri`, `rb_read_trail_mfri`, `rb_read_harbours_mfri`, `rb_read_survey_*_mfri` | `rb_logbook`, `rb_trail`, `read_is_*` |
| `rb_interpolate_track`, `rb_interpolate`, `rb_sum_across`, `rb_pad_harbour`, `rb_peek` | kept as they are; their verbs are in the table |

Notes on this table:

- `rb_convert_speed`, `rb_extract_metier`, `rb_get_gear_vocabulary` and `rb_cap_outliers` merge pure functions with
  identical outputs; the `from`/`to`, `part`, `list` or `method` value reproduces each old function.
- `rb_encode_csquare` is new (the datacall uses `vmstools::CSquare`).
- `whack_clean`, `whack_sda`, `whack_forward`, `whack_fwdbwd` and `whack_sequential_fast` are re-pointed at the new
  functions.

**Not renamed. These are deprecated and keep their old bodies.** Each one's behaviour differs from the new function
that supersedes it:

| Deprecated function | Why it is not an alias of the new function |
|---|---|
| `rb_whack_*` table filters | output layouts `whack`, `whack2`, `whack_sda`, `whack_stage` |
| `rb_whacky_speed_mendo`, `rb_whacky_speed_trip` | they drop rows; `_trip` also has a bug (`whackies.R:596-600`) |
| `rb_trip`, `rb_trip_jepol` | they work on vectors |
| `rb_add_tripid` | |
| `rb_cap_effort` | it does three things: fills with the median, caps at 12/24/15 h, overwrites `t2` |
| `rb_grade` | it differs from `rb_midpoint` |
| `rb_st_remove` | it differs from `rb_st_drop` on MULTIPOLYGON |
| `rb_rms_tbl` | `calc` returns a vector, and this returns a table |
| `dc_spread_cash_and_catch` | |

Each one's alias test runs it against its own snapshot from before the change.

**Update (2026-10-11):** three rows of the table above have since landed — `rb_add_tripid` is now
`rb_link_trip_logbook`, `dc_spread_cash_and_catch` is now `rb_share_catch` (placeholder arguments
`ignore_Einstein`/`go_nuclear` became `raise_unallocated`/`raise_unmatched`), and `rb_grade` is removed
(`rb_bin_midpoint` is the same binning with the floating-point floor fixed). The same day the
`R/` sources were reorganised from 40 topical files into 22 stage-named ones, test files mirroring them.

## Removed functions that come back as methods (rewritten, not copied)

| Removed (commit) | Becomes |
|---|---|
| `rb_whacky_points` (6e9d444) | `rb_flag_ping_impossible(method = "distance")` |
| `define_trips_pol` (e147cfd) | the `"jepol"` method, one version only |
| `rb_add_trips`, `rb_add_trips_vt` (3e45175) | the declared tier of `rb_assign_trip`; column arguments cover EFLALO/TACSAT names |
| `match_nearest_date` (008120f) | `rb_link_trip_landings(method = "nearest_date")` |
| `rb_gaussian`, `rb_gaussian_binary_clustering`, `rb_hidden_markov_step`, `rb_hidden_markov_step_and_turn` (f9d4039) | the `"gmm"`, `"embc"` and `"hmm"` methods (with `by =`), and `rb_build_fishing_speeds(method = "gmm")` |
| `dc_split_among_pings` (4cad4f6) | its `level` argument informs `rb_share_catch`'s move-up order |
| `stk_bearing`, `stk_angle` (2021) | `rb_calc_bearing`, `rb_calc_turn_angle`, needed by the HMM step-and-turn method |

The four functions in `models.R` used `%>%`, hard-coded `id`/`x`/`y` (UTM)/`behaviour` and needed `plotmm`. They are
the specification, rewritten under the lazy-first rule.

## Phases

**Checkpoints, even in auto mode.** Phases 0 and 1 run straight through. Work stops for the maintainer:

- after phase 1, before phase 2 (the first change to step logic);
- before any full rebuild;
- before any push of ramb to GitHub;
- before any change to the claude.ai doc.

Each phase ends with three things:

- ramb tests passing;
- fishycode `check_bookkeeping()` passing;
- a decision record, numbered from 071 (070 closes TODO 12) and indexed, plus a commit in each repo.

0. **Record.**
   - **Diagram.** The proposed update to the WGSFD doc's one-flow figure (version 2, shown 2026-10-08) goes into the
     claude.ai doc once you agree its content:
     - vessel and flag-pings rows;
     - voyages from harbour stays;
     - the many-to-many link-and-reconcile band;
     - the two-way note;
     - window + speed;
     - catch units above the trip, with the "coarser than the activity" band;
     - the bottom bar saying "accounted for", with five basis values.

     The doc's text changes with it: "Every ping is kept" becomes "accounted for". The AI-use line is extended to
     cover the change.
     - Saved locally as `~/stasi/wgsfd2026/one_flow_cascade_v2.svg` and `.png`, beside the untouched
       `one_flow_cascade.png`.
     - The figure in the claude.ai master doc is replaced only on an explicit yes. The doc keeps revision 108 in its
       history.
   - Close TODO 12: verify the stamps and record it in decision 070.
   - TODO 37 stays parked on its branch; its full rebuild joins phases 2–3.
   - Write fishycode `curate/plans/013-ramb-one-flow.md`: its header contract (status; measured vs assumed), a row
     in `plans/README.md`, and a TODO stub with a status and a check.
   - Widen the basis triple in `AGENTS.md` and `docs/grammar.qmd`, and note the `s1`/`s2` clash.
   - Add TODO items for the fishycode fixes listed below.
   - In ramb: write `NEWS.md` (the old → new map) and a "Naming" section in `R/ramb-package.R`.
1. **Pure renames.**
   - **1a.** Snapshot every current export's output on its fixture, apply the one-to-one table, and add the naming
     test and the alias tests.
     - Drop the duplicate definitions, keeping `spatial.R`'s `rb_st_keep` and `mb_rasterize_xyz.R:34`.
     - DESCRIPTION: `R (>= 4.1)`, Roxygen markdown, the Import review, `rb_register_macros`.
     - `_pkgdown.yml` reference grouped by stage, plus a Deprecated group.
     - Update README.Rmd, the articles and TODO.md to the new names.
   - **1b.** fishycode callers move to the new names. Outputs are unchanged, so nothing is rebuilt.
     - `curate/ais_ping_clean.R`, `ais_ping_union.R`, `ais_trip.R:197`, `R/entity_class.R`, `reference/vessels/mmsi.R`
     - `sources/norway/logbooks.R:62`, `products/exports/astd_iseez.R:201`, `buseful_2025-05-05.R:146`,
       `products/ices_vms_datacall/build.R:247`
     - the checks, and `docs/stk_data-inspection.qmd`
     - A grep then confirms that no deprecated name is called.
   - Outside users (`~/stasi/test`, fishyweb notes) keep working through the aliases.
2. **Steps 0–1 in ramb**, ported with exact equality first:
   - Functions: `rb_flag_ping_invalid`, `rb_flag_ping_duplicate`, `rb_flag_ping_impossible`, `rb_find_trip_stays`,
     `rb_cut_trip_voyages` (`"stays"`, then `"runs"`/`"jepol"` recoded), `rb_link_trip_voyages`, and
     `rb_assign_trip` (declared, voyage and none tiers).
   - Fixtures: a `dansk` subset with `dansk_harbours`, plus synthetic tracks.
   - fishycode's `ais_ping_clean.R`, `harbour_stay.R`, `ais_trip.R` and `link_trip_voyage.R` call them.
   - Equivalence is checked on vessel subsets without touching `curated/` (the existing `AIS_TRIP_VIDS` hook writes
     to staging).
   - `rb_flag_ping_harbour` and the `ais_ping_tag.R` port come last.
3. **Step 2 + fishing `"window"` in ramb**, exact port:
   - Functions: `rb_limit_record_duration`, `rb_build_record_windows`, `rb_assign_record`, `rb_link_record_pings`, and
     `rb_assign_fishing(method = "window")`. The last three must run lazily on a month of the trail.
   - fishycode's `R/duration_limit.R`, `station_window.R`, `R/trail_sql.R` and `ais_trail.R` call them.
   - Subset equivalence first. Then **one full rebuild for phases 2–3 together, with TODO 37 merged**, verified with
     per-partition fingerprints (rows plus a hash of key columns) against snapshots from before the change.
   - Only after that, as separate counted commits:
     - half-open windows, which end the boundary double count;
     - the `ais_ping_tag` overlap de-duplication.
4. **Design, then build.** Each piece continues an existing plan or TODO item rather than opening a new one:
   - `T2` reconciliation, with `rb_link_trip_landings` (the `link_lid_map` fixes) as its first piece: TODO 27b and
     plan 011.
     The maintainer, 2026-10-09: neither declared date is the arrival. The logbook's `T2` is often the expected arrival,
     written before the trip ends; the landing's date is when the catch was declared or sold. Only the track measures
     when the vessel enters port, so reconciliation links the declarations to the arrival rather than choosing one of
     them as it, and keeps all three with their basis.
     The bootstrap this creates (maintainer, same day): preprocessing matches logbook and landings on the declared
     dates only (no AIS, plan 014), and the accurate departure and arrival exist only in the flow. So step 1 builds the
     reconciled trip table as a flow output: `T1`/`T2` from the track's stays, the logbook trip and the landings linked
     to it, each with its basis; it may also link landings the declared-date match missed. It is never written back
     into the preprocessing link (`lid_map`). If a reconciled result must change an input, it re-enters as a reviewed,
     frozen input by decision, as the vessel key does (decision 075).
   - Gear with several gears per trip: TODO 34.
   - **Reconcile declared times with the track** (maintainer, 2026-10-09), one rule for every time a declaration
     may carry: `T1`, `T2` and `t1`–`t4`. `coalesce` only falls back; here a present declared value can also lose.
     Each value keeps its candidates (logbook, landing, track) and gets one of five cases:
     - *agree*: the candidates agree within tolerance;
     - *refine*: they agree and the track is more precise (a date becomes a date and time);
     - *fallback*: no declaration, so the track fills in;
     - *override*: the track contradicts the declaration, is precise enough, and is linked unambiguously, so it wins
       and the declared value is kept beside it;
     - *not checked*: the track is too sparse at that moment to judge, so the declaration stands.
     The deciding quantity is the track's uncertainty at the event (about the gap between the pings either side),
     against the declaration's own precision (date only, minute, or an expected time). With good AIS resolution the
     track may overwrite; with poor resolution it may not. Output per value: the chosen time, the candidates, an
     uncertainty, its provenance (`basis`) and the case. Generic, as a ramb step (e.g. `rb_reconcile_time()`); the
     `T2` reconciliation above is its first use.
     - **Built so far (2026-10-14, decision 088):** `rb_link_record_events()` puts each declared t1–t4 against the
       track: the fix that bounds its phase (a start takes the next fix, an end the previous one) and `gap_s`, the
       track's precision at the event. It is the anchor, not the reconciliation: a link, never a changed time.
     - **Measured, not ready yet (2026-10-14, Claude, AI-assisted; maintainer's request).** A small test: June 2023,
       3,281 bottom-trawl tows with t2 and t3 both reported (47 vessels).
       - *The test:* from the declared t2 − 90 min to t3 + 90 min, fixes at the gear's towing speed (s1–s2); the
         towing run that overlaps the declared tow most gives the track's tow start and end.
       - *Precision:* the track could place a boundary to about ±5 min (median gap between fixes 5 min, 90 % within
         10).
       - *Agreement:*

         | the ping's speed | start within 15 / 30 min | end within 15 / 30 min | start tails (5 % / 95 %) |
         |---|---|---|---|
         | alone | 50 / 57 % | 46 / 52 % | −13 / +220 min |
         | alone, dips ≤ 10 min merged | 60 / 70 % | 57 / 66 % | −28 / +185 min |
         | median of the fixes within ±10 min | 61 / 74 % | 60 / 71 % | −86 / +153 min |
         | median within ±15 min | 53 / 66 % | 48 / 64 % | −89 / +85 min |

       - *The window around each ping (maintainer):* a slowdown between towing speeds is not the end of fishing.
         ±10 min centres the boundaries (median offset −1.9 min at the start, +0.4 at the end, against +10 and −17
         for the ping alone). ±15 min starts to smear across the hauls between tows, and the ends drift late.
       - *Not the speed range:* inside the declared tows (10 min in from each end) 92.2 % of fixes are within s1–s2,
         and only 1 of 47 vessels is below 80 %. The tows with a start more than 30 min off are spread over the
         fleet: the five worst vessels hold 16 % of them, and the median vessel has 21 %. A vessel's poorer fit to
         s1–s2 goes with more bad starts (correlation −0.67), so vessel-specific ranges (plan 012) would help some.
       - *Why it is not ready:*
         - A tow is rarely one run at towing speed: 81 % of tows hold two or more runs even at ±10 min.
         - Shooting and hauling can run at towing speed, and adjacent tows compete for the same fixes.
         - Nothing says which side is right when the track and the declaration differ by half an hour.
       - *Before an override is trusted:*
         1. Find the boundaries on the voyage as a whole, all its tows at once with the declared tows as the prior,
            from the windowed speed (±10 min) and the heading's stability; possibly an HMM (decision 078's WKSSFGEO
            practice).
         2. Vessel-specific speed ranges.
         3. A test set with known times: a trawl's bottom-contact sensor if any exists for Icelandic vessels, or the
            labelled static-gear sets of WKSSFGEO / WKSSFGEO2.
         4. Then set the five cases' tolerances on measured error rates.
     - **Exploration before any more building (agreed with the maintainer 2026-10-14; TODO 56).** Analysis first, on a
       month or two of real tracks; nothing goes into ramb or the targets until it is measured.
       1. *The speed rule as a window (step 4, not only here).* The trail's `fishing` tests each fix's own speed
          against s1–s2. Score that rule against the windowed one (the median of the fixes within ±W) on the
          recorded tows and hauls:
          - share of fixes inside a recorded window called fishing;
          - share outside called not fishing;
          - how the score moves with W.

          If the window wins, it changes `rb_assign_fishing()` and the trail's `fishing`, whatever happens to the
          time reconciliation.
       2. *Voyage-wide boundaries, a prototype on one month.*
          - Segment each voyage into steaming, towing and slow stretches, from the windowed speed and the heading's
            stability.
          - Pair the stretches in order with the declared tows: one stretch per tow at most, the order kept.
          - Count what pairs, what does not (an unreported tow, a tow the track cannot see, two tows the track shows
            as one), and the boundary offsets of the pairs.
       3. *What `station_event` becomes.* It was built and kept as a first, provisional layer (decision 088): the
          bounding fix of each declared t1–t4 and the track's precision there. Decide after 2 whether it stays as
          the declarations' anchor beside the voyage-wide pairing, or the pairing replaces its labels on the trail.
       4. *Ground truth.* Find a source of known tow or haul times: Icelandic trawl sensors, a vessel with observer
          records, the labelled sets of WKSSFGEO / WKSSFGEO2.

       ramb 2026.10.14 and 2026.10.14.1 (`rb_link_record_events()`) are committed in ramb but not pushed, held by the
       maintainer until this settles the function's shape. The exploration has settled it: the function becomes
       exclusive (TODO 57) before any push. **Built (2026-10-14, Claude, AI-assisted; decision 091):** ramb
       2026.10.14.2 makes `rb_link_record_events()` and `rb_build_record_windows()` exclusive (`ping_lost`,
       `win_opened_by`, half-open windows), and 2026.10.14.3 breaks a tie between two phases of one record; both
       committed and installed, still unpushed. Rebuilt the same day; TODO 57's check passed (0/0/0).
     - **Measured (2026-10-14, Claude, AI-assisted; decision 090).** The maintainer added an invariant first: *a fix
       belongs to at most one record, and to one phase of it*. It holds for assignments (trail, `station_event`, the
       pairing). `trail_match` holds candidates. When two events share a bounding fix, the one nearer in time keeps
       it. The census of where the current code breaks the invariant is in decision 090.
       1. *Speed window* (2023, at-sea fixes of voyages with one gear range; "in" = inside a recorded window with
          one candidate, "out" = ≥ 30 min from any window):

          | gear class | in, called fishing: own speed / ±5 / ±10 / ±15 / ±20 min | out, called not fishing: same |
          |---|---|---|
          | towed (2.64 M in, 1.69 M out) | 89.9 / 91.7 / 93.4 / 94.3 / 94.7 % | 88.4 / 88.3 / 88.0 / 87.7 / 87.6 % |
          | static (1.26 M, 0.76 M) | 87.3 / 88.8 / 89.6 / 91.0 / 91.3 % | 77.0 / 76.9 / 76.8 / 76.6 / 76.5 % |
          | jigged (0.87 M, 0.26 M) | 62.3 / 62.3 / 62.7 / 66.5 / 66.8 % | 84.6 / 84.8 / 84.9 / 84.6 / 84.7 % |

          Next to a window the cost is larger: towed "out", all fixes, goes from 80.4 to 78.1 % at ±10, because
          shooting and hauling get smeared. ±10 min is the choice for `rb_assign_fishing()` (TODO 59).
       2. *Voyage-wide pairing* (June 2023, 4,237 declared tow operations, 87 vessels, twins as one operation).
          - **Method:**
            - stretches of fixes at the gear's towing speed (median within ±10 min), broken at a gap > 30 min, at
              least 15 min long;
            - a stretch holding two declared tows is cut at the slowest fix between them;
            - an ordered, one-to-one pairing that maximises the overlap with the tows widened by 30 min.
          - **Result:** 0 invariant breaks in every variant. Shares of all declared tows:

            | variant | paired | start within 15 / 30 min | end within 15 / 30 min |
            |---|---|---|---|
            | own speed, no prior | 97.4 % | 43.5 / 59.7 % | 41.0 / 52.3 % |
            | ±10 min, no prior | 95.0 % | 50.6 / 71.3 % | 46.9 / 61.2 % |
            | ±10 min, cut at the declared tows | 99.0 % | 54.4 / 76.8 % | 51.1 / 66.1 % |
            | the same, OTB only (2,951) | 99.5 % | 61.8 / 77.2 % | 63.2 / 74.1 % |

          - Against the earlier non-exclusive test (OTB, 61/74 and 60/71 %), exclusivity costs nothing.
          - SDN (1,187 tows; end 23 % within 15 min) and OTM (71) need a model of the phases, not one speed range.
          - 30 % of towing-speed stretches hold no declared tow: searching, slow steaming, or unreported tows.
       3. *`station_event`* stays as the declared anchor, made exclusive (TODO 57). The pairing gives the track's
          boundary. The two are the candidates that `rb_reconcile_time()` compares.
          - In June 2023 the exclusive rule takes the fix from 57 of 8,468 t2/t3 anchors, and the pairing still
            bounds 50 of those tows.
          - The track's start is within one fix interval of the declared start for 30 % of paired tows.
       4. *Ground truth*:
          - none locally for Icelandic towed gear. The afli logger follows the captain's station entry, and
            WKSSFGEO's OTB AIS labels only fishing pings.
          - The labelled dredge and pot sets suit static gear.
          - Candidate: MFRI's groundfish survey tows (TODO 60).
       5. *All years* (2007-2026, maintainer's request; decision 090 has the tables):
          - **Q1 holds in every year.** Inside the towed windows, 89.2 → 92.7 % are called fishing at ±10 min.
            Far from them, 87.2 → 86.8 % are called not fishing. Within 30 min of a window the cost is
            58.3 → 50.0 %.
          - **Q2, 1.29 M tow operations:** 87.3 % paired, start within 15/30 min for 46.6/64.7 %.
            - Exclusive and independent pairing on the same stretches agree equally, but the independent one
              breaks the invariant 27,863 times.
            - OTB 2015-2025: 98-99 % paired, start 55-60/77-80 %.
            - Before 2012 the track is too sparse (OTB 2007: 20 % paired).
            - Dredges lose 11.6 points of pairing to exclusivity, because one stretch holds several short tows.
       6. *Built* (2026-10-14, decision 092; TODO 59): `rb_calc_speed_smooth()`, `rb_assign_fishing(window_s =)`,
          `rb_cut_record_stretches()` and `rb_link_record_stretches()` in ramb 2026.10.14.4. June 2023 reproduced
          tow for tow. Not yet used in fishycode (TODO 61).
   - **Set ↔ haul pairing for static gear**, `rb_link_record_sets(hauls, pings)` (maintainer, 2026-10-09). Build each
     haul's line from its pings, then find the earlier pass along that line (iapesca: 330–550 m, the same voyage or up
     to two voyages back, within 240 h). That pass is the set. The result is the set time, the soak, and the setting
     voyage, which can differ from the hauling one because the gear soaks while the vessel is in port. Generic, for any
     fleet with static gear.
     - Recoded in ramb, never copied; iapesca is credited (decision 078).
     - Tested against labelled ground truth: WKSSFGEO2 `data_examples/IT_CNR_2023_GP.csv` (pots: 426 setting,
       1,607 hauling pings) and WKSSFGEO `data-examples/example_data_GPS.csv` (pots and dredges, 5 vessels).
     - A further candidate, not yet looked at: a gillnet dataset on IRD's dataverse (doi:10.23708/IBZJGD,
       https://dataverse.ird.fr/dataset.xhtml?persistentId=doi:10.23708/IBZJGD) and its paper
       (https://hal.archives-ouvertes.fr/hal-03116922). The pointer came from ramb's old `machine2.Rmd` sketch,
       deleted 2026-10-13 and kept in ramb's history before 7fcebcd. Whether it carries set and haul labels is
       unchecked.
     - Bears on plan 004 / TODO 18 and on the static gear under-covered by `logger_runs_past_the_station`.
   - Fishing beyond window + speed: plans 004 and 012, TODO 18.
     - `"gmm"` and `"embc"` at tier 3, tested against `mixtools` and `EMbC`.
     - `"hmm"`: fitted at tier 3, decoded at tier 4, tested against `moveHMM`.
5. **Steps 5–6, ramb only:** `rb_assign_effort` and `rb_share_catch`.

   **Before building steps 1, 3, 4 or 5, read decision 078:** outside code mined for them (iapesca, WKSSFGEO,
   WKSSFGEO2), and ramb's `crs_m = 3575` port-buffer default, measured wrong away from the north.

**fishycode fixes found while exploring** (TODO items in phase 0, fixed in the phase that ports the code):

- `logbook_sensor_gps.R:45-52, 68` joins ids without `schema`.
- `catch_by_species_trip.R:40, 55` groups ids without `schema`.
- `ais_ping_tag.R` can duplicate a ping where polygons overlap.
- `link_lid_map.R:198, 210` applies `isTRUE()` to a column, and the map is not one-to-one.
- `products/ices_vms_datacall/build.R` is stale and writes into the repo.

Anything that goes back into the WGSFD document states its AI use (MFRI policy).

## Verification

- **ramb:** `devtools::test()` passes. It covers:
  - the naming test;
  - alias tests against the pre-change snapshots;
  - one data-frame-vs-DuckDB equivalence test per step function;
  - recoding tests against the original packages, guarded by `skip_if_not_installed()`.

  `R CMD check` shows no new notes. Install with `R CMD INSTALL --preclean .`
- **fishycode, phases 1b–3:**
  - `targets` cannot see script edits, so ported targets are `tar_invalidate()`d by hand.
  - Equivalence is shown first on vessel subsets written to staging.
  - The full rebuild uses `tar_make_isolated()`, or `tar_make()` once TODO 37 is merged.
  - Rebuilt outputs are compared by per-partition fingerprints against snapshots taken before the change.
  - Every difference is counted and explained in the phase's decision record.
  - `check_bookkeeping()` passes.
- **Pushing** ramb to GitHub happens only with your yes; fishycode has no remote.

## TODO items folded into the phases

Open `TODO.md` items that this revamp closes or touches, so they are done together rather than twice:

| Phase | TODO items |
|---|---|
| 0 | 12 (closed, decision 070) |
| 1 | 7 and 30 (closed, decision 071) |
| 2 | 40 (the key loop: W1 reads key-dependent pings), 42 (`ais_ping_tag` overlap duplicates), 38 (whack loose ends), 3c and 36 (harbour code types, `pid` stability), 33 (harbour class), 22 (foreign vessels never reach trips) |
| 2–3 rebuild | 37 (`produces()` cleanup, on branch `todo-37-produces-cleanup`), 14 (two astd months, needs the union rebuilt anyway) |
| 3 | 3 (`station_type` = the record's `resolution`), 41 (`.sid`/`.tid` joins without `schema`), 29 (afli overlap check blanks `t2`/`t3`) |
| 4 | 43 (`link_lid_map` bugs), 27b (datacall onto the trail), 25 and 39 (key review), 34 and 18 (speed ranges, behavioural windows), 17 and 23 (vessel identity) |
| not part of it | 8, 9, 10, 15, 16, 19, 21, 24 |

## Logic questions found while porting (phase 2)

An exact match with the old output proves the port faithful, not the logic right. These were found by reading
the ported code. Each is to be settled by a measurement, and fixed only as a separate, counted commit:

| Step | Doubt | What would test it |
|---|---|---|
| 0 duplicate | A lower feed's copy is flagged before the impossible stage, so an STK anchor that is itself impossible still removes a sound astd copy. | Count duplicates whose STK anchor is later flagged impossible. |
| 0 invalid | `lon == lat` is safe only where the fleet never fishes at lon ≈ lat (59–76 °E at these latitudes); it is no generic rule. | It stays a fishycode rule (`rules = "lon_eq_lat"`); ramb's default adds `out_of_range`. Count what `out_of_range` adds. |
| 0 harbour | The harbour polygons are one static set (`staging/aux/ports.fgb`) applied to 2007–2026, though harbours were built out over those years. A ping by a new quay counts as at sea in the years before its polygon was drawn, and the other way round. | Date each polygon change; count pings that change tag if the polygon of the ping's year is used. |
| 1 stays | The nearest harbour is chosen by `ST_Distance` in degrees (EPSG:4326). At 65 °N a degree of longitude is about 0.42 of a degree of latitude, so east–west distances are understated. | Re-choose in metres (EPSG:3575) and count the pings whose harbour changes. |
| 1 stays | Event pairs count only from 2017 (`EVENT_FROM`), so stays are defined differently before and after. | Count event-only stays by year; check whether pre-2017 events are usable. |
| 1 voyages | Voyages are cut at New Year, so a trip at sea over 31 December becomes two voyages and links to two logbook trips. | Count voyages that end at 23:59:59 31 Dec or start at 00:00 1 Jan with no stay between. |
| 1 voyages | Voyages under 10 pings are dropped after numbering. Their pings get `trip = NA` though they are at sea, which goes against "no vessel without a trip". | Count the pings and vessel-days on dropped voyages, by year. |
| 1 voyages (`jepol`) | The ICES rule splits a voyage over `max_dur_h` one ping before its longest gap (`which.max(INTV[2:.N])` indexes the rows from the first), and its 3-minute test reads the gap before that ping, not the longest one. Kept so the recode matches `rb_trip_jepol()`. | Fix in ramb as its own commit; count on `dansk` the voyages whose cut moves. Not used by fishycode. |
| 1 voyages (`jepol`) | The ICES rule's voyage ends at the first ping back in harbour, so that harbour ping belongs to the voyage; `"stays"` and `"runs"` end at the last ping at sea. The methods differ in more than how they find harbour. | Document the choice per method; decide whether `jepol` keeps the ICES convention. |
| key | W1 now reads the merged pings before cleaning, so whacky other-feed positions count as evidence. | Compare W1 hits with the whacky-flagged pings removed. |
| key | The segment build keeps the first row of a tie in several places; which row wins was decided by the input files' row order (now fixed by sorting on all columns). A principled tie-break (e.g. stronger evidence, then earlier date) is not chosen. | List the ties the sort decides, and compare with an evidence-ranked choice. |
