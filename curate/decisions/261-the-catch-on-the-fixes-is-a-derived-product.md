# 261 — The catch on the fixes is a derived product, the user's: no step or check here builds or relies on `ais_catch`

*2026-10-30. The maintainer's word, given while plan 054's step 2i was checking its catch on a scratch build of
`ais_catch`: "forget ais_catch here altogether - that stuff is something the user will do, based on the products we
provide", "you should not need to rely on ais_catch for the processes here", and "ais_catch is a derived project it is
not data". Recorded by Claude (AI). The scratch run of `ais_catch` was ended.*

## Chosen

- **fishycode's product is the data and the link** (decision 215): the fixes linked to their logbook and landing events,
  with every value's basis. **The catch spread over the fixes is derived from that by the user,** with the filter of
  their choice and ramb's split. It is not data, and fishycode does not make it.
- **No step, check or plan here builds, reads or waits for `ais_catch`,** nor for the allocation audit, which reads
  it. A check of the catch is made at the trip: logged against landed, every landing in one outcome, kg in = kg out per
  vessel and year.
- **`curate/ais_catch.R` and its target stay in the repository, unbuilt**, as decision 241 left them. Removing them is
  a decision of its own.

## What this changes

- **AGENTS.md:** "All six steps of the flow belong here, effort and catch included" now says that the last of them,
  the catch on the fixes, is the user's.
- **Plan 054:** ask p, the catch halves checked on scratch with `ais_catch`, is superseded. 2i is checked at the trip,
  and its change to `ais_catch.R` is reverted on its branch.
- **TODO 81:** its check is now the trip's catch raised to the landed kg per vessel and year, not the kg on the fixes.
- **TODO 101:** the fixes that live in `ais_catch` are declined: the transfer trips' excess as an outcome there, the
  catch on stations with no window, and the audit read after the rebuild. Its other fixes stand.
- **TODO 62:** the foreign logbooks end staged and merged. Their catch on the fixes is the user's.
- **Decision 241's rule** (rebuilds leave `ais_catch` and the audit out) becomes the standing scope.
