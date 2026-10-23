# 199 — The allocation audit's choices: deleted stations out everywhere, transfer trips flagged and not raised, a deterministic voyage gear

*2026-10-23. The maintainer's answers to TODO 101 (the errors decision 155's allocation audit finds), asked by Claude (AI)
in a status review of the repository. The numbers are the audit's and the record's of 2026-10-20 to 23, measured by
Claude and not yet checked by a person. Nothing is built.*

## Chosen

- **Stations deleted in the source are out everywhere** (352 stations, 4,238 t, `eytt_deleted`). Today they count in
  `lid_map`'s trip catch, the catch by species and `landed_logged`, but not in the windows, `voyage_gear` or
  `ais_catch`. A source's deletion is its own verdict, so they leave every sum and link, as duplicate twins do
  (decision 094), and stay in `station_fate` (decision 194) as deleted in the source, so their kilograms are still
  accounted.
- **Pelagic transfer trips are flagged and not raised** (decisions 103, 104): 2,548 trip-species landed 2-300 times
  their logged catch (1.0 against 0.19 Mt). A flag on the trip; the logged catch goes on its fixes as logged, and the
  excess landed weight goes to an outcome of its own, landed but caught by another vessel, so kg in still equals kg
  out and no vessel carries another's catch.
- **`voyage_gear` is deterministic:** a tie-break by kilograms, then the gear code; `gid` and the gear class from the same
  row; a count of gear labels per voyage. Decision 154 read a tie as a wrong allocation; plan 031 step 4 found most of
  the 323 tied voyages are not missed calls, and today 5 voyages change gear from run to run. Built with the AIS batch.
- **Catch on stations with no window goes to a coarser unit** (57 t on 43 stations): the vessel-day or the trip, by
  plan 038 §7.1's cascade, instead of nowhere.
- **A station dated outside its trip's days is flagged in the merge** (3.5 % of adb, 3.0 % of fs_afladagbok stations): a
  record error, not corrected.
- **The two landing-to-voyage rules are compared in the audit**, read-only: `voyage_gear`'s window plus 7 days against
  `ais_catch`'s `rb_link_trip_landings()`.
- **The audit as a generic ramb tool is parked** until plan 038's phases are built.

## Answered elsewhere

- The trail's trip from one voyage only: plan 038 step 2, the trail reading the reconciled trip, which spans every
  voyage of a trip's stations (decision 193).
- Station times inside port calls, and trips landing before their voyage ended: decision 197 (plan 031 asks i and j) and
  TODO 81.
