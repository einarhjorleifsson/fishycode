# 293 — Short voyages kept and labelled: every stretch at sea with a recorded ping is a voyage; 3,066 trips more with AIS times

*2026-11-07. Plan 031 §4.7, after decision 292, at the maintainer's word ("Yes, test it", then "Yes, apply it"). Measured,
tested, built and counted by Claude (AI); no person has checked the code or the counts. The study, its scripts and every
table: `$FISHYDATA/archive/2026-11-07-sea-pings-no-voyage/` (its README).*

## Why

Decision 292 left the voyages 14,376 under their count before plan 048, and asked whether 10 recorded pings was still
the right minimum. The maintainer: the earlier count "may have been an overcount", STK's event rows having made up some
of it; "but if we are missing true pings at sea that are not part of voyage, we should take care of those", unless they
are mostly the vessels 3700-4999.

`curate/ais_voyage.R` made a voyage of a stretch at sea between two port calls only if it held 10 recorded pings or more,
and dropped the rest. Their fixes stayed in the trail with no voyage. Measured on the store of decision 292:

- 813,367 fixes at sea were in no voyage. Vessels 3700-4999 had only 11,187 of them, with no logbook station and no
  fishing hours, so they are not the cause.
- The other vessels had 802,180 of them (0.28 % of their fixes at sea), in 184,689 stretches. Each stretch is in one
  outcome:

| outcome | stretches | fixes | fishing hours | logbook stations |
|---|---|---|---|---|
| a fix in a logbook station's window | 7,047 | 37,633 | 3,668 | 8,081 |
| 2 nm across or more, no logbook | 59,618 | 361,261 | 953 | 0 |
| under 2 nm, mostly outside a port polygon | 96,219 | 339,816 | 185 | 0 |
| under 2 nm, mostly inside one | 21,805 | 63,470 | 11 | 0 |

- **The logbook stretches are real trips.** Most are small boats on longline (LLS), handline (LHM) or gillnet (GNS)
  that leave and return to the same port. The median stretch has 5 recorded pings at STK's 10-minute reports and
  1.5 h between its port calls. At that interval, 10 pings means a trip of at least 1.5 h; on an hourly VMS stream, 9 h.
- **No rule that sees only the track separates them** from the noise at the edge of a port call. A quarter of the
  logbook stretches move under 4.6 kn and get no further than 1.1 nm from the port. A rule of 2 pings, reach 1 nm or
  3 kn would keep 84 % of their stations and 129,713 stretches with no logbook.

Plan 031 §4.7 had already decided the way: "Short voyages are kept and labelled". A label lets a consumer leave a short
voyage out, and no fix is left without a voyage. ramb's `rb_create_voyages(min_pings = 1, short_pings = 10)` has
given the label all along.

## What was done

- **`curate/ais_voyage.R`** (ecc5c4f): `MIN_PINGS` 10 → 1, `SHORT_PINGS` 10. `voyage.parquet` carries `short`, true
  for a voyage of fewer than 10 recorded pings.
- **Tested first on a scratch store** (`cp -c` clones, the code from a `git clone`), the 12 targets from `ais_voyage`
  down. The scratch store was deleted before the live build, at the maintainer's word. The patch is kept in the study.
- **Rebuilt** at ecc5c4f, ramb 2026.11.06.3 and DuckDB 1.5.6: `ais_voyage` invalidated by hand (targets cannot see a
  script edit), then the 14 targets below it, from 13:19 to 14:13. Every one of the 368 curated files that changed is
  stamped ecc5c4f with a clean tree. Only `ais_catch` and `check_allocation_audit` are outdated (decision 261). The
  effort map's grids were rerun.

## What changed

| | before | now |
|---|---|---|
| voyages | 1,414,461 | 1,601,182 (186,721 `short`) |
| fixes at sea in no voyage | 813,367 | 1,424 (all the GPS logger's reconstructed fixes) |
| port calls that cut voyages, inside one | 0 of 1,620,310 | 0 |
| trips linked to a voyage (`trip_voyage`) | 859,363 | 862,429 |
| trips with AIS times (`trip_reconciled`: `trip_voyage`, `stations`) | 843,327 + 16,041 | 846,128 + 16,306 |
| fixes with the voyage's logbook trip (`.tid_voyage`) | 216,674,340 | 216,689,163 |
| fishing fixes; their hours | 113,780,857; 9,178,966 | the same fixes; 9,178,234 (−0.008 %) |
| `fishing_flow` fixes; their hours | 138,879,002; 11,361,142 | 138,882,222; 11,360,483 (−0.006 %) |

- **The voyages that were there** are 1,414,447 of 1,414,461 the same in key, times, pings and ports. The other 14
  changed their departure port only, and this change is not the cause. 147 pairs of port calls overlap (61 vessels,
  each pair at two ports, 91 with an STK event pair). A voyage after such a pair takes its departure port from
  whichever call sorts first, and a tie in time order decides that: the same vessel rerun under the same rule gave
  IS-OLV once and IS-ARN the next time. The scratch test had 15.
- **The short voyages**: 34,857 have one recorded ping, 15,709 have nine. 2,920 belong to vessels 3700-4999.
- **The trips.** 3,066 more trips take a voyage, each a short one, and with it AIS departure and return times.
  - The departure was before taken from STK (2,189), none (527), the logbook (278), the quota (60) or the phone (12).
  - The return was before taken from STK (2,119), the logbook (717), the landing (117), the quota (59), none (47) or
    the phone (7).
  - The departure moved by more than 6 h for 673 trips and the return for 1,134: a trip dated by day now has the
    track's times.
  - 62 trips changed to a short voyage.
  - 216 trips changed from one voyage's times to the span of the voyages their stations lie in (decision 193): a
    station of theirs now lies in a short voyage. 5 trips went the other way.
- **Effort.** The fixes judged fishing are the same. Their hours fell by 732 because `rb_add_effort(by = "voyage_id")`
  ends a fix's interval at its voyage's end. Before, the fixes with no voyage made one group per vessel, so an interval
  could reach across a port call to the next such fix (up to the 2 h cap).
- **Elsewhere:** `station_event` is unchanged. `trip_landing` lost 96 of 1,625,542 links and gained 39, because some
  trips' returns moved. 372 of the voyages' gear rows changed (`voyage_gear`).

## What it leaves

- **The overlapping port calls**, and the departure port that a tie decides after them (147 pairs, 61 vessels): plan
  048's event pairs (TODO 148).
- **Which consumers should leave short voyages out.** None does now: a trip linked to one takes its times. The label is
  there for a consumer that wants to leave them out.
