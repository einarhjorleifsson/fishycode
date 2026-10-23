# 215 — The main output is the link from each fix to the events it may belong to; splitting the catch is the user's step, the flow's filters presets

*2026-10-23. The maintainer's framing; its details drafted by Claude (AI) and left to Claude ("proceed - and i trust
your decision"). Nothing is built; nothing in the store changes. **Amended 2026-10-23:** the effort is summed from
the dt of the fixes the filter keeps (the maintainer: "the effort will be calculated from each ping dt value that
remains after the filter (s, t, ...)"); and any additive quantity the record reports is split the same way (the
maintainer: "one may even split effort reported in the logbooks across the 'filtered pings', number of hooks, nets,
catch value, ...").*

## The maintainer's words

"The main output is not spreading the catch on the pings (fixes), it is one step before: linking pings to
logbook/landings events. Then the user can decide at that step how to proceed with 'split catch'", for example by
the gear's speed range (s1 to s2), by the time window (t1 to t4), by a mixture of both, "or whatever else".

## Chosen

- **The product is the linked track** (`curated/ais/trail`): every fix with the events it may belong to (the logbook
  station and its phase in the window t1-t4, the trip, the voyage and its port calls, and the landing once it is on the
  fix, below) and the evidence for each link: the window and its basis, the fix's speed against the gear's speed range
  (`s1`, `s2`), and how the link was made. Where a fix may belong to more than one record, the candidates are kept
  (`trail_match`); decision 090's one fix, one record is the default assignment beside them, not the only answer.
- **Splitting the catch is the user's step:** a filter the user chooses over the linked fixes (the speed range, the
  window or a phase of it, both, or another rule) and a key (by default the fix's hours). ramb's split
  (`rb_share_catch()`, to be `rb_split_catch()`, TODO 127) takes the filter as any logical column, and keeps the
  account
  whatever the filter: an event left with no fix moves up to the next unit that overlaps it, then to the vessel's
  month, and what still finds no fix is kept with no time and basis `none`, so every kilogram is in one outcome
  (kg in = kg out).
- **The flow's own filters are presets:** `fishing` (the window alone) and `fishing_flow` (the window, else the voyage
  gear's speed), applied in `curated/ais/catch`. They stay as references, for the ICES datacall and the maps, and as
  worked examples of the user's step; they are not the product.
- **Effort follows the filter:** each fix carries its dt, the time it stands for (`hours`, kW-hours), fishing or not
  (in June 2021 on 2,562,552 of 2,572,712 fixes). The effort of an event is the sum of dt over the fixes the user's
  filter keeps, and the same dt is the split's key, so effort and catch come from one choice.
- **Any additive quantity is split, not only the catch:** the kilograms, the value, the hooks, the nets, the effort
  the logbook reports (soak or tow hours), each over the kept fixes by the key, its parts adding up to the event's
  total; a label (gear, metier, port) is inherited, as is a non-additive value (a price, a mesh size). This is the
  grammar's rule for moving a value between units (`docs/grammar.qmd`, "Moving a value between units"); the kind of
  each variable is declared once, in the data dictionary. Every unit of an additive quantity is in one outcome, as the
  kilograms are.
- **Flags travel with their event:** catch the landing contradicts (plan 038 §8 step 1c) and the records typed by what
  they cover (decision 214) are marked on the links, so the user's filter can leave them out or keep them.

## What it changes

- **`AGENTS.md`** states the aim this way (this change).
- **Plan 038's L5 and L6** (§6 the stations on the fixes, §7 effort and catch) rewritten around the link the same day,
  with `curated/ais/catch` as the presets applied; the work in its steps 1, 3 and 6 (TODO 122).
- **The landing on the fixes:** a landing reaches the fixes today only inside the catch step, through the voyages it
  ended (`ais_catch.R`'s `landing_trip` units, `ramb::rb_link_trip_landings()`), or through its logbook trip
  (`lid_map`, `trip_voyage`). The link product needs it on the fix itself (plan 038 L3 and L5).
- **ramb's split** takes `kg` and one `value` column today (`rb_share_catch(kg =, value =)`); it is to take any
  additive column, with the account kept for each (with ramb's renames after TODO 127's names review).
- **The book** (`docs/flow_catch.qmd`, `docs/one_flow.qmd`): the split shown as the user's step, the presets as
  examples (plan 033).

## What it does not change

The cascade's steps and their order (`docs/one_flow.qmd`), what fishycode builds, the presets' outputs, and the rule
that every value carries its basis. Decision 214 and plan 038's step 1c stand as they are.
