# 191 — Plan 038's asks answered: the link's lower bound lifted next, the reconciled trip read after its multi-voyage fix, every logged kilogram accounted from 1950

*2026-10-23. The maintainer's answers to plan 038 §9 a-i, asked by Claude (AI) in a status review of the repository.
Nothing was built or measured anew; the numbers are the plan's and the audit's of 2026-10-23, by Claude, not yet
checked by a person.*

## Answers

- **a. The split with plan 039** (§0): confirmed as the two sessions agreed it, with plan 039's three additions (a
  month step for landings before LODS, the link's lower bound lifted, the quota regime and gear on the landing).
- **g. The order of §8:** as written, except that step 3's lift of `lid_map`'s lower bound (2007-09-01) comes right
  after step 1. It fixes a defect measured in the product today: January to August 2007's landings find no logbook
  trip, so `ais_catch.R` shares them on the fixes beside their own trips' logged catch (the landing path holds 70-96 kt
  a month in June-August 2007 next to 74-97 kt logged, then 5-16 kt a month from September). This also answers plan
  039's ask e.
- **b. What reads `trip_reconciled`:** all five readers of §5.1 (the trail's trip, `ais_catch.R`'s trip unit, the day
  windows, `trip_landing`, the audit), each after a scratch build traced kilogram by kilogram, and only after the
  multi-voyage case is fixed: on the 13,084 trips whose timed stations fall in two or more voyages, `T1`/`T2` from AIS
  must span those voyages, not the one `trip_voyage` names (decisions 155, 173, 174).
- **c. A fix inside two reconciled trips of one vessel:** no trip and a flag, until TODO 102 classes the overlaps.
- **d. The quota system's regime, gear and hand-baited flag:** carried onto the trip through the link, and the quota
  gear a third witness in `logbook_gear`, below the logbook's own gear and the landing's, with its own basis.
- **e. The kilograms accounted:** from 1950, every year the logbook holds, as accounting only: before 2007 a unit's
  outcome is "no fixes that year", and nothing is shared or given effort there. afli's 199.4 kt of monthly summaries
  become vessel × month × rectangle units, after a check that they do not repeat stations already held. This reopens
  decision 103's "years before 1990 out of scope" for the account; for effort and sharing it stands.
- **f. adb's ports:** mapped to `pid` once, in the merge; adb's departure port 0 (5,094 trips, decision 172) written NA
  with basis `none` there.
- **h. adb's conversion faults** (decision 171): a check in `curate/checks/` that the records read from 2025-11-19 do
  not carry them.
- **i. kvoti's `veidiferdir` and `nyting_haus`** (13,097 trips, 1991-2017): measured first, read-only, and staged as
  a witness in `trip_reconciled` only if they hold a departure that agrees with AIS where both exist.

## Left

Every ask of plan 038 is answered, so TODO 122 no longer waits on the maintainer. The work is the plan's §8 in the
order above; each phase is a scratch build, a decision, then the maintainer's build by name.
