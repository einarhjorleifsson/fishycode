# 120 — The 23 plans' status lines checked against the record; four TODO stubs for open plans

*2026-10-17. Written by Claude (AI-assisted) at the maintainer's request ("double check the plans similarly"). Three
read-only reviews compared each plan's header and its row in `curate/plans/README.md` with the decision records,
`TODO.md`, git and the data. Their main claims were spot-checked before any edit. Only headers, index rows and
`TODO.md` changed. A plan's body stays the design, as the plans README says.*

## What was wrong

`check_bookkeeping()` tests that every plan has an index row. It does not test that a status is true. 14 of 23 were
not, five more carried dead links, and 015 gains a note:

| plan | was | now |
|---|---|---|
| 001 | proposal, nothing built | §4 done; §3 answered in part (decision 118); the rest waits on the maintainer (TODO 15) |
| 002 | proposal, nothing built | partly built: steps 1 and 5 (decisions 010, 011, 070), the tail as plan 010's trail |
| 003 | partly built (index: steps 1–4) | executed: steps 1–7 and 9; step 8 went to plan 008; the key is plan 009's (053) |
| 005 | parked | abandoned: decision 098 settled it, and its open ends are TODO 75 |
| 006 | proposal, nothing built | abandoned: overtaken by plans 007 and 010 and decisions 093 and 100–102 |
| 007 | decision record "not yet written" | decision 031 is that record; §6 questions 1 and 3 open (TODO 74) |
| 008 | Phase 7 onward proposal | Phase 7 in part (decision 114); the rest carried by plan 021 |
| 009 | "restructured", with a second status fragment | partly built: phases 1–2 and 5 done, 3 in part, the rest TODO 25 |
| 010 | proposal, nothing built | executed: steps 0–4 built; the function became `curated/ais/trail` (065) |
| 011 | header self-contradicting; index "nothing built" | executed: decisions 058–065, class dropped (074), port stays (075) |
| 012 | proposal, nothing built | partly built: steps 0 and 4 (085); 1–2 not taken up (093) |
| 013 | item 10 blocked (TODO 60) | item 10 unblocked by decision 104, not built (TODO 72) |
| 015 | (accurate) | notes that effort and catch per fix were built after it (101–102) |
| 021 | the override review waits | done: 52 links confirmed; the build and the allocation wait (TODO 65) |
| 022 | §4 waits for the rebuilt voyages | the voyages were rebuilt 2026-10-16; §4 waits for the maintainer's go |
| 004, 014, 017, 018, 023 | dead TODO or file links | repointed |

Index rows corrected to match. Plans 016 and 021 have nine asks, not eight; 019 has seven, not five; 022 has five, not
two. Row 015 was out of order. `parked` joins the status vocabulary, since plan 004 uses it.

## What had no TODO item

The plans README requires a stub in `TODO.md` for every open plan. Four were missing, now items 72–75:

- **72:** plan 013's items 4 and 6–10. Item 7 (the 1990–2006 logbook) is no longer blocked: decision 103 put the years
  before 1990 out of scope. ramb's NEWS (53519ee) reports a static-gear measurement that no record here holds.
- **73:** plans 019 and 020, with their asks.
- **74:** plan 023's asks, and plan 007 §6 questions 1 and 3.
- **75:** decision 098's open ends (the 410 trips lost whole, and the 1,854 rows before 2007-09).

Asks added to existing items: plan 001 §5's other two questions (TODO 15); plan 017's asks e and f, and decision 115's
dominant-IMO question (TODO 65); plan 017's ask g, and the path of `steini`, now `raw/oracle/afli/` (TODO 62); and plan
016's two unasked questions, the 2024-10-22 list and who refreshes MFRI's register copy (TODO 71). Plan 008's Equasis
licensing is left in that plan as a later option. Plan 021 §6 d chose GFW's API instead.

## Not changed

Stale sentences inside plan bodies, for example plan 009's "not yet in it" and plan 015's §4 e naming a ramb method
that has since been renamed. The headers now say where each plan stands.

## Enforced since

`check_bookkeeping()` gained three invariants the same day, at the maintainer's request: each plan's status opens
with a declared word, its index row opens with the same word, and every `proposal` or `partly built` plan is named in
`TODO.md` (by its path, or as "plan NNN"; a list such as "plans 009, 016 and 021" counts). Each was shown to fail on a
scratch copy broken for it: plan 009 given "restructured", row 011 set back to "proposal", and TODO 73 removed (019
and 020 reported). The real repo passes.
