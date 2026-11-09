# 313 — TODO 87 closed: STK's October 2026 reload needs no correction

*2026-11-09. TODO 87, at the maintainer's word ("Let's go for at least one of the TODO's", the rule "agree"d before the
last measurement, "I still want to take things on before the rebuild"). Measured and written by Claude (AI); no person
has checked the queries. Study: `$FISHYDATA/archive/2026-11-09-stk-october-reload/`.*

## Why

After the Oracle crash of 2026-10-11 the maintainer reloaded STK's reports by hand. TODO 87 held that many carry a date
a day early and put day-shifted copies of tracks into the trail (vid 2350, 2026-10-12), and asked for a declared
correction before the whack filter.

## What was found

Over 3 h late and received 11-15 October: 897,291 AIS and 5,872 VMS reports of 1,312 units.
- **At their own times.** STK's live AIS track has a hole from 11 October 00:00 to 13 October about 12:00, and the
  reload fills that span at its written times. A reload dated a day early would leave a hole a day later.
- **No day-shifted copies beyond chance.** 0.65 % of the reload's AIS reports find the same unit at the same place
  exactly a day later, against 10.5 % of 1-7 October's live reports (moored vessels repeat their position).
- **A finer ping rate.** For the 781 units with reports in both: median interval per unit 181 s against 646 s in 1-7
  October; steps over 30 kn 0.59 % against 10.2 %; reports at one instant 2.3 % against 3.9 %. 13,301 reload reports are
  exact copies of an earlier one. vid 2350's 105 steps of 12 October include none over 30 kn.

## What was chosen

The rule agreed before the last measurement: intervals shorter and impossible steps not above the normal rate, so no
correction. The reload is STK's backlog at a finer ping rate, at its own times, and its exact copies are labelled by step
0's duplicate rule. TODO 87 is deleted; nothing in the pipeline changes.

## What it leaves

- The other mass-delivery days of decision 164 (17 besides this one, 2007-2026) are not checked for day-shifted
  copies; TODO 182's study found none in May and June 2026.
