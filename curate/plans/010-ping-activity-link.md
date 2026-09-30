# 010 — Linking pings to trips and fishing activity (the `trail`)

**status:** proposal — Phase 0 measured 2026-09-30 (§9), nothing built · **2026-09-30** · **see:** plans `002-the-last-mile.md`
(§2 the tail, §3 `t1`..`t4`), `004-behavioural-fishing-windows.md`,
`006-trip-identity-and-catch-to-ais-pings.md` (§4, §5, §6); decisions `010`, `028`, `053`;
`corrections/station_time_whole_day.yml`

**Revised 2026-09-30 (same day), on the maintainer's instruction:** (a) the target pipeline
may be reshaped wholesale to get this; (b) the logbook GPS logger **is included** as a ping
source with `provider = "gps"`, placed directly after the interpolation (§5). Its lon/lat are
interpolated; its speed is measured. *Phase 0 (§9) found it is **not** finer in time than AIS*
(10-minute steps), so it earns its place through the recorded `.sid` and the measured speed.

**This plan settles what 006 §5 left open** — `w1`/`w2` versus raw `t1`..`t4` plus speed — by
proposing a per-gear *window rule* that can be replaced later without rebuilding anything
downstream. It does **not** design catch allocation (006 §6).

**Measured** — 2026-09-30, `$FISHYDATA/curated/`, read-only:

- `ais/ping/` already carries `trip` (the AIS voyage number) and `pid`, but **no** `.tid`,
  `.sid`, gear or fishing flag. 12 columns; the sweep is partitioned by `year`.
- `logbook/fishing_sample.parquet`: 7,239,778 rows, 7,224,594 distinct `.sid` (≈ 1 row per station).
  It has `.tid`, `.sid`, `gear`, `t1`..`t4` but **no `vid` and no `date`** — `vid` comes from
  `logbook/trip.parquet` via `.tid`, `date` from `logbook/station.parquet` via `.sid`.
- Event-time coverage by gear (share of rows non-null), which drives the window rule:

  | gear | rows | t1 | t2 | t3 | t4 | duration_m |
  |---|---|---|---|---|---|---|
  | OTB bottom trawl | 4.27 M | 0 | .87 | .87 | 0 | .97 |
  | SDN Danish seine | 1.15 M | 0 | .16 | .16 | 0 | .16 |
  | LLS longline | 0.54 M | .30 | 0 | .05 | .30 | .78 |
  | LHM jiggers | 0.50 M | .19 | 0 | 0 | .18 | .95 |
  | GNS gillnet | 0.40 M | .23 | 0 | .05 | .23 | .99 |
  | OTM, DRB, PS | 0.35 M | mobile: t2/t3 .92 / .30; PS ≈ none |

  So the maintainer's picture is right for trawl, but for **static gear the recorded times are
  the exception**: longline has `t3` on 5 %, `t1`/`t4` on 30 %; jigger and gillnet on under a
  quarter. Most static-gear stations therefore fall back to the day window, as in the old trail.
- `logbook/sensor_gps`: 49,324,452 fixes, 788,558 stations, 436 vessels, 2007-03 → 2024-06;
  99.5 % carry a position. Every fix **already carries its `.sid`** from the source
  (`visir`), so its station is *recorded*, not inferred. Positions are
  `interpolated_within_voyage` (49.07 M) or `outside_voyage` (0.25 M, lon/lat NA), with
  `dt_sec` = the AIS gap the position was interpolated across: **median 370 s**. So the logger's
  time, speed and heading are sound, and its position is only as good as that gap.
- `logbook/sensor_gps` is built *downstream* of the AIS chain on purpose (decision 000,
  "the logger approximation moves downstream of the merge"): putting it back into
  `ais_ping_union` recreated a cycle in which the union held 26.9 M positions interpolated from
  itself. That decision still stands — §5 satisfies the instruction without undoing it.
- `link/trip_voyage.parquet`: 808,744 links onto 720,330 AIS voyages (more logbook trips than
  voyages — several `.tid` share a voyage). Mean overlap fraction 0.78.

- Recorded tow windows (mobile gear, both `t2` and `t3` present), 2026-09-30: `t3 < t2` in 0
  rows; `t3` later than the same vessel's next `t2` in **0.13 % of OTB, 0.11 % OTM, 0.22 % SDN**
  stations (0.05–0.11 % by more than an hour). Median tow 210 min (OTB), 419 (OTM), 46 (SDN).
  Overlap is rare, so a cap (§2) costs little; it is also the only repair that needs no other data.
- The **old trail** (`/Volumes/fishydata/data/ais/trail`, 2019; 53 columns, one `.sid` and a ping
  id `.rid` per row): 50.3 M rows, 50.19 M distinct `.rid` — a ping is duplicated only when
  several stations claim it. Of the 9.71 M station-tagged rows, 98.9 % are a single station,
  55,081 pings have 2, 30,692 have 3, and a few hundred have 5–9. So ambiguity is real but ~1 %.
  (A per-vessel-day table I also computed looked implausible — ~1,000 vessel-days for 115,680
  stations — and is not used; treat the old trail as a reference, not as truth.) Every
  station-tagged old-trail row carries a `t1` — the whole-day fill, unflagged.

- **Static gear overlaps in a different way from tows** (maintainer, 2026-09-30: gear is put out
  in several places and retrieved in another order; commoner for nets than longline).
  Measured on stations with both `t1` and `t4` (gear-in-water span `[t1,t4]`): the span overlaps
  another of the same vessel's in **75 % of GNS** (67,251 / 90,025), **16 % of LLS** and **9 %
  of LHM**; it is *crossed* — another station's set began earlier and was hauled inside this
  one's span — in 59 %, 3.8 % and 4.0 %. So `[t1,t4]` is gear-in-water time and is **not** a
  vessel-activity window for nets. Recorded hauls should not overlap but do against the next
  haul's `t3` in **1.9 % of LLS and 2.4 % of GNS** — rare, not zero, so the cap of §2 applies to
  hauls too.

**Assumed** — all of it below: the window rules per gear, that a ping's station assignment can
be made directly from `(vid, time)` without going through `trip_voyage`, runtime of a live
join, and that `(vid, time)` identifies a ping (**unchecked** — plan 009's twin mids suggest it
may not). Phase 0 measures these before anything is built.

## 1. Shape of the answer

Do **not** add columns to the 44 GB ping sweep. Build two small tables and one function layer:

| Piece | Grain | Holds |
|---|---|---|
| `logbook/station_window` | one row per station **and phase** (tow, set, haul, day) | `vid`, `.tid`, `.sid`, `gear`, `gear_class`, `w_start`, `w_end`, `win_basis`, `phase`, raw `t1`..`t4`, `s1`, `s2` |
| `ais/ping_trail` | one row per **fix** (AIS ∪ gps), partitioned by `year`, sorted `vid, time`, unique on `(vid,time)` | the ping columns + `provider`, `pos_basis`, `speed_basis`, `speed_gps`, `dt_sec`, `.tid`, `trip`; speed in knots throughout |
| `ais/ping_activity` | one row per **(fix, station)** match, same partitioning | fix key, `.sid`, `phase`, `phase_frac`, `win_basis`, `win_speed_ok`, `n_sid` |
| `ais_trail(years, vids)` | function | `ping_trail ⟕ ping_activity ⟕ station_window`, returns the old trail's wide shape |

Why a bridge and not wide columns: several stations can own the same ping (static gear's
full-day windows overlap; a vessel can set on one station and haul another). One row per match
keeps that visible, and `n_sid` says how ambiguous a ping is. A wide `trail` parquet is then a *view
materialised from these*, optional, and never the source of truth.

Everything enters `curated/` through `write_curated()` (AGENTS.md; TODO 12).

## 2. The window rule — per gear class, in `reference/gear/`

The window is computed by one rule table, not scattered through code, so plan 004's behavioural
windows replace a row, not a script. Stored raw times are never overwritten (AGENTS.md: never
destroy the original); `win_basis` says which rule fired.

| class | gears | preferred | fallback 1 | fallback 2 |
|---|---|---|---|---|
| towed | OTB, OTM, SDN, DRB | `[t2, t3]` recorded | `[t2, t2+duration_m]` | day |
| static | LLS, GNS, LHM | two short vessel windows per station: `set` from `t1`, `haul` = `[t3,t4]` | haul `[t4 − typical haul, t4]` when only `t4` is present, typical haul = per-gear median of recorded `t4 − t3` (LLS 498 min, GNS 295; `synthesised`). **`duration_m` is not used** — Phase 0 showed it is not the haul time (§9) | day for the station date |
| other | PS, FPO, NA | day | — | — |

- **The recorded times are themselves suspect** (maintainer, 2026-09-30): where one tow's `t3`
  passes the same vessel's next `t2`, **cap `t3` at that next `t2`** and set `win_basis =
  "capped"` (raw `t3` kept). Crude but mechanical and rare (0.1–0.2 %). Order by `t2` within
  `vid`; the cap is applied to the window, never to the stored time.
- **Speed is a second opinion on the window, not a replacement for it (yet).** High-resolution
  tracks (gps fixes, dense AIS) show a trawl's speed profile — slow-down at shooting, steady
  towing, haul-back — which can confirm or correct a recorded window. The plan adds *diagnostic*
  columns, not a new window: `win_speed_ok` (share of in-window pings with `speed` in
  `[s1,s2]`) and `win_n_pings`. A window that fails it is flagged, and plan 004 is where the
  inferred window replaces the recorded one. Keeping it diagnostic first avoids building the
  classifier inside this plan.
- **day** = `00:00:00`–`23:59:59` of the station date, `win_basis = "synthesised"`; this is the
  old trail's behaviour, made explicit and flagged instead of silent (correction
  `station_time_whole_day`).
- The speed filter is **not** baked into the window. `station_window` carries `s1`/`s2` from the
  gear table (still to be ported, plan 002 §4) and `ais_trail` exposes
  `fishing = in_window & between(speed, s1, s2)`, with the parts kept so an analyst can redo it.
- **Static gear, settled by the maintainer:** `t1` is the moment setting *starts*; `t3`–`t4` is
  the haul, which is slower than the set and so easier to locate (more pings). **`t2` (setting
  completed) is not in the data**, so the set has a start but no end.
- **Phase marker on every ping (maintainer, Q2):** each matched ping carries `phase` and
  `phase_frac` (0–1, position within the phase; 0.3 = 30 % through the tow or haul).
  Values: `tow` (mobile, `[t2,t3]`), `set`, `haul` (`[t3,t4]`), `day` (fallback, `phase_frac`
  NA). **There is no per-station `soak` phase** (amended 2026-09-30): soak is gear-in-water time,
  it overlaps other stations' sets and hauls in 75 % of net stations, and the vessel is
  elsewhere — a ping in it belongs to whatever the vessel is doing, not to that station.
  `set` runs from `t1` for a per-gear maximum set duration, **closed early at the vessel's next
  event** (any station's next `t1` or `t3`), so two sets never claim the same ping; its open end
  is an assumption and carries `basis = "synthesised"`.
- **Set–haul pairing is taken from the logbook, never inferred.** Because gear is retrieved in a
  different order, pairing "the nth set with the nth haul" would be wrong; a station's `t1` and
  `t3`/`t4` are paired only because they sit on the same `.sid`. Nothing in the plan orders
  sets against hauls across stations except the closing rule above.

## 3. How a ping finds its station (and its trip)

1. Match **directly** on `vid` and `time between w_start and w_end`, year by year (DuckDB
   range/IEJoin on the year's partitions only — decision 055 is the precedent for pruning).
2. `.tid` comes from the station, not from `trip_voyage`. That makes the ping↔trip link a
   by-product of station evidence and sidesteps the 39 % `afli` trip-level link rate
   (006 §4), at the price of covering only pings inside some window.
3. Pings outside every window but inside an AIS voyage that `trip_voyage` links to a `.tid` get
   that `.tid` with `.sid` NULL (`win_basis = "trip_only"`): steaming, not fishing.
4. **Ambiguity stays ambiguous (maintainer, Q3; the old trail agrees, ~1 % of station pings).**
   `ping_activity` keeps every (fix, station) match; `n_sid` counts them; there is **no
   `primary` flag**. A wide `ais_trail()` row gets a `.sid` only when `n_sid = 1`, otherwise
   `.sid` is NA and `n_sid > 1` — the analyst chooses, knowing the choice exists.
5. Harbour (`.cid`/port tag) and `whack` flags stay where `ais_ping_clean/tag` put them and are
   only read, never recomputed here.

## 4. Live join or materialised? — answered by Phase 0

Phase 0 timed the live alternative on 2017, the heaviest year: a range join of every window
onto the year's ≈ 50 M pings ran in **6.2 s** (§9). So `ais_trail()` **joins live** from
`station_window` and `ping_trail`. `ping_activity` is materialised only if a later consumer
(catch allocation, plan 006 §6) needs the matches stored; it is an optimisation, not the design.

## 5. The GPS logger as a ping source

Added to the **downstream** table `ais/ping_trail` (new, after `ais_trip` and
`logbook_sensor_gps`), never to `ais_ping_union`; the cycle in decision 000 stays broken.

- Rows are `sensor_gps` fixes renamed to the ping schema: `provider = "gps"`,
  `speed` **converted from m/s to knots** (× 1.9438; §9) and `heading` from the logger, `lon`/`lat` the interpolated pair, `w_lon`/`w_lat` kept
  (never overwrite the original), `dt_sec` carried.
- **Per-column basis**, because one row mixes provenances (AGENTS.md rule): `pos_basis =
  "reconstructed"` for gps, `"recorded"` for AIS; `speed_basis = "recorded"` for both.
  Anyone who needs real positions filters `provider != "gps"`; anyone who needs speed uses both.
- Nothing that measures *where* may silently mix them: speed-derived checks (`dd`, `whack`,
  implied speed) must not be computed on gps rows, since their positions are interpolated from
  the same AIS track. `dt_sec` is the trust gauge and the plan exposes it.
- **Station is recorded for gps fixes:** their `.sid` is copied straight into `ping_activity`
  (`win_basis = "recorded"`, `in_window = TRUE` by construction) — no window needed. Only AIS
  pings go through the §3 window join. **Identical timestamps are removed** (maintainer, 2026-09-30): downstream
  analyses use the interval between consecutive fixes (e.g. speed = distance / duration), and a
  zero interval breaks them. Rule: per `(vid, time)` keep one row; precedence **AIS over gps**
  for position (recorded beats reconstructed). Mixing provenance in one cell is avoided: the kept
  AIS row stays whole, and the dropped gps row's speed is stored beside it as `speed_gps`. Near-duplicates (different seconds)
  both stay; `provider` tells them apart. The same uniqueness is enforced across `gps1`/`gps2`.
- **Payoff for plan 004:** the gps fixes are a station-stamped, *measured* speed trace. The
  behavioural fishing window (plan 004) can be inferred from them and then *applied to the AIS
  pings of stations that have no logger*, which is most of the static-gear problem in §2. It is
  not higher-resolution than AIS (§9).
- Limit, measured: 436 vessels and 788,558 stations — a small part of the 7.2 M stations. The
  logger is not a general fix for missing times.
- **Two collapses happen in this step:** `gps1`+`gps2` → one row per `(vid,time,.sid)` with
  `speed = coalesce(gps1, gps2)` (§9), then gps against AIS on `(vid,time)` as above.

## 6. The pipeline gets reshaped, not patched

Allowed and expected. Target layout proposed (names follow AGENTS.md script rules):

```
ais_ping_union → ais_ping_tag → ais_ping_clean → ais_trip → logbook_sensor_gps
reference gear (s1,s2,class) → station_window
ais_ping_clean ∪ logbook_sensor_gps → ais_ping_trail → ais_ping_activity ← station_window
                                                        link_trip_voyage (fallback/check)
```

- `ais_ping_trail` and `ais_ping_activity` are new targets; both written with `write_curated()`.
- `ais_ping_activity` runs **per year** (dynamic branching over `year`), so one bad year does not
  invalidate the graph and 2017 is the only memory-heavy branch.
- `link_trip_voyage` moves from "the" ping↔trip link to a consistency check on it (§3).
- Anything in `products/` that opens `staging/ais/ping_union` and filters on the missing columns
  (`products/ices_vms_datacall/build.R:72`) is repointed to `ais_trail()`. This is the datacall
  fix plan 002 §2 already asked for.
- Verifying the new graph is read-only first (`tar_outdated()`, per the memory rule); the full
  rebuild is one deliberate `tar_make()`, inspected afterwards, not trusted on green alone.

## 7. Order

0. **Measure** (read-only) — **done 2026-09-30**, results in §9.
1. **Gear table** — **done 2026-09-30**: `reference/gear/windows.R` → `curated/reference/gear_window.parquet`
   (target `gear_window`). Per new-version gid: `gear_class`, `s1`, `s2`, `s_basis`, `set_max_min`
   (NA until Q9). `s1`/`s2` are **fleet-wide declared values** (maintainer: they work reasonably
   and could be refined), ported from the old `00_DATASET_gear.R`; `s_basis = "declared_fleet"`
   so a refinement can sit beside them. Checked against AIS speed inside recorded windows: trawls
   88–96 % and longline 91 % inside `[s1,s2]`; Danish seine 70 %; nets 53–86 % (their recorded
   hauls include steaming, so the window is the doubtful part there).
2. **`logbook/station_window`** — **done 2026-09-30**: `curate/station_window.R` →
   `curated/logbook/station_window.parquet` (target `station_window`), one row per (station,
   phase), 7.2 M stations → see §10 for what was built, what changed from this plan, and the
   check against the old trail.
3. **`ais/ping_trail`** — **done 2026-09-30** (`curate/ais_ping_trail.R`, target `ais_ping_trail`):
   AIS ∪ gps, unique on `(vid,time)` and sorted by `vid, time` (checked on every written file),
   gps included from the first build, directly after the interpolation. The `(vid,time)` dedupe and
   the speed test live **here**, not in `ais_ping_clean` as §9 proposed: the 50 GB cleaning chain
   would have had to be rerun for 0.03 % of rows. `ais/ping_activity` was **not** built (§4); see §11.
4. **`ais_trail()`** in `R/` — **done 2026-09-30** (`R/ais_trail.R`); the line in `docs/` is still to do.
5. **Validate** against the 2019 old trail: fishing-ping counts per vid-month, and the share of
   old-trail `.sid` matches reproduced. Reading `/Volumes/fishydata` needs the terminal tool,
   never a recursive scan. Also conservation: no station's window assigned to a different vid.
6. Catch allocation (006 §6) and plan 004's behavioural windows then plug into the same bridge.

## 8. Open questions for the maintainer

1. ~~haul window~~ answered: `[t3,t4]` is the haul, `t1` starts the set, `t2` does not exist.
   Still open: a per-gear **maximum set duration** to close the open-ended `set` phase.
2. ~~phase marker~~ answered: `phase` + `phase_frac` on every ping (§2); soak is not a phase.
3. ~~ambiguity~~ answered: stays ambiguous (§3.4).
4. ~~tie between AIS and gps~~ answered (maintainer): identical timestamps are removed, AIS kept, gps speed stored as `speed_gps` (§5). Near-ties (seconds apart) stay.
5. ~~old-trail column compatibility~~ answered: exact compatibility not needed; this is an
   improved trail, and the contract in plan 002 §1 is the floor.
6. ~~higher-rate logger stream~~ answered (maintainer): none. The logger stays in, directly after the interpolation (§5), for its recorded `.sid` and measured speed.
7. ~~gps1 vs gps2~~ answered by data: same fixes, speeds never disagree; collapse with `coalesce` (§9).
8. ~~`duration_m`~~ answered (maintainer): soak is variable — longline usually hauled soon after
   setting, occasionally longer, **max ≈ 12 h**; nets' soak runs to days, notably Greenland-halibut
   (grálúða) and lumpfish (grásleppa) nets. Data agree for nets: by target, median `t4 − t1` and
   `duration_m` are equal (DEF 24.5 vs 24.0 h, GAD 21.1 vs 21.1, LUM 47 vs 47, GHL 107 vs 107 h),
   so **`duration_m` is gear-in-water time for nets** (corr with `t3 − t1` 0.65). For longline it
   is not (corr 0.09; `t4 − t1` median 12.5 h, q90 24 h — longer than the stated 12 h max, so some
   recorded hauls are late or wrong). Consequence: for nets, `t1 = t4 − duration_m` can **rebuild a
   missing set start** (`basis = "derived"`, to validate on stations that have all three); it is
   *not* a haul length.
9. ~~set duration~~ **estimated 2026-09-30 (§10): longline 150 min, nets 60 min**, from the speed profile after `t1`; confirm or correct. Original question: **set duration (the old Q1 remainder) is a different number from soak.** Soak is `t1 → t3/t4`,
   gear in water, vessel elsewhere. The *set* is the vessel busy putting the gear out, `t1 → t2`,
   and `t2` is not recorded, so nothing in the data gives it. Plan: estimate it per gear in Phase 1
   from the speed profile after `t1` (setting is faster than hauling) rather than guess; until
   then the set window is closed only by the vessel's next event. A rough figure from you (longline
   set ≈ hours? nets ≈ 1–2 h?) would serve as a sanity check on that estimate.

## 9. Phase 0 results — measured 2026-09-30 (read-only, `$FISHYDATA/curated/`)

Scripts in the session scratchpad; all numbers below were printed by them.

**Decisions the numbers force**

| # | finding | consequence |
|---|---|---|
| 1 | **Live join is cheap.** A range join of every 2016–17 window onto all 2017 pings (≈ 50 M) matched 12.76 M pings in **6.2 s**; 2019 coverage in 2.4 s | `ais_trail()` can join live; the materialised bridge becomes optional, not the design. §4 is superseded |
| 2 | **`duration_m` is not haul time for static gear.** For mobile gear it equals `t3 − t2` (corr 1.00, derived from them). For static: GNS median 1,472 min vs recorded `t4 − t3` 295 (corr 0.26); LLS 796 vs 498 (0.56); vs `t4 − t1` corr 0.02–0.17 | my `[t4 − duration_m, t4]` fallback was wrong and is withdrawn (§2). It would have made 300,958 static windows a median 6 h wide. Replaced by the per-gear median haul. Answered since: for nets `duration_m` is gear-in-water time (§8 Q8) |
| 3 | **Static gear is mostly day-window.** Of 1.48 M static stations: recorded `t3`+`t4` 50,887 (3 %), `t4` only ≈ 0.30 M, day **1.13 M (76 %)**. Towed: recorded 4.09 M, day 1.58 M (28 %) | the day fallback is the majority case for nets/longline; `win_basis` must be in every wide row, and phase marks will be absent for most static pings |
| 4 | **Ambiguity is a day-window artefact.** Among *recorded* windows only, 2017 has max 2 stations per ping and 0.00 % ambiguous; with day windows 20.7 % of day-matched pings and 12.1 % of recorded-matched pings sit in ≥ 2 stations (max 22) | add a **precedence rule**: a day window claims only pings *not* inside any recorded/derived window of the same vessel. Tows 3.9 stations per vessel-day (max 29), static 1.1 (max 10) |
| 5 | **Recorded windows still contain pings.** Stations whose window holds ≥ 1 ping, 2019: recorded 98.4 %, day 98.5 %, (wrong) derived 99.7 % | coverage is not the discriminator; window *quality* needs the speed diagnostic (§2) |

**The GPS logger**

- **Units: `sensor_gps.speed` is in m/s, not knots.** On exact `(vid,time)` ties with AIS the
  gps/AIS ratio is 0.517 (q10–q90 0.48–0.61, corr 0.91); during recorded OTB tows AIS speed is
  median 3.64 kn and gps 1.90 (× 1.944 = 3.69 kn). `logbook_sensor_gps.R` copies `skip_hradi`
  unconverted. `ais_trail`/`ping_trail` must convert (× 1.9438) and say so, or `speed` would mix
  units in one column. **Not fixed here.** Side finding for a separate item: `curate/corrections/
  afli_coords.R:64-72` multiplies the logger speed by 0.514444 as if it were knots, so if the
  unit really is m/s its dead-reckoning is out by ×1.94.
- **Time resolution is not finer.** Median step between logger fixes within a station is
  **600 s in every year 2007–2023** (300 s in 2024); AIS on the same vessels is 600 s until 2013,
  then 360 s (2014–16), **134–180 s (2017–19)**, 220 s (2020), 360 s since. Logger steps ≤ 60 s:
  0.9 %; ≤ 180 s: 7.6 %. Speed *values* are coarse too (0.1 m/s ≈ 0.19 kn steps). So in 2019 the
  logger adds **no** resolution: AIS has median 69 pings vs 54 gps fixes inside the same
  station, and 98.3 % of gps stations already have AIS of the same vessel. What the logger does
  give: a station-stamped, *measured* speed and a recorded `.sid`; its value is greatest in
  2007–2013, when AIS was also 10-minute and the logger is the only station-stamped source.
  Maintainer confirmed there is no higher-rate stream, so the case for gps rests on the `.sid`
  and the measured speed, not on resolution.
- **Duplicates: half of `sensor_gps` is a duplicate.** 2019: 5,358,797 rows, 2,678,128 distinct
  `(vid,time)`. `sensor_src` names the two raw Oracle tables the logger fixes come from:
  `gps1` = `sjalfvirkir_maelar`, `gps2` = `rafr_sjalfvirkir_maelar`. They hold the **same fixes**
  in 2008–2019 (row counts equal year by year), `gps2` thins out in 2020 (1.38 M against 2.59 M)
  and ends in 2020; `gps1` runs to 2024. In 2,676,960 of 2019's pairs (same `(vid,time)`, same
  `.sid`, same raw position) the **speed never differs where both have one**; 11.4 % of fixes
  have a NULL speed. *An earlier draft of this section said speeds differ in 11 % of pairs; that
  was wrong — those were pairs with NULL speed in both.* Only 15,026 pairs (0.6 %) have a speed in
  one table and not the other. Rule: collapse to one row per `(vid,time,.sid)`, `speed =
  coalesce(gps1, gps2)`, so the choice between the tables does not matter. Another ≈ 600 keys carry
  4+ rows with *different* `.sid`: one fix stamped to several stations.
- **AIS/gps exact-time ties:** only 30,212 of 5.36 M gps fixes (0.6 %) share `(vid,time)` with an
  AIS ping; speeds differ in 98.8 % (median 1.6, which is the unit gap above). The tie rule
  matters little numerically.

**AIS ping key**
- `(vid,time)` is **not** strictly unique in `ais/ping`: 2008: 9 duplicates, 2014: 306, 2019: 101,
  2023: 9,806 (0.03 %). 2019's are `astd`+`astd` (68 keys), `astd`+`stk` (32), `stk` (1); 32 %
  differ in position, all in speed. Rule: keep one per `(vid,time)`, `stk` over `astd` (assumed).
  The wide table's ping key can therefore be `(vid,time)` once deduplicated; no `.pid` column
  needed, but the dedupe must live in `ais_ping_clean`, not here.
- `ais/ping.speed` has garbage: max 8,565,166.8; 0.019 % over 30 kn in 2019. `whack` does not
  cover speed. A speed clamp/flag belongs in `ais_ping_clean` before any `fishing` filter.

**Not yet done:** the per-gear set duration (§8 Q9) and the `win_speed_ok` diagnostic
(needs the window table built). `duration_m`'s real meaning for nets.

## 10. Phase 2 — `station_window` built 2026-09-30

`curate/station_window.R`; per (station, phase): `tow`, `set`, `haul`, `jig`, `day`, with
`win_basis` (recorded / derived / synthesised / capped), `win_closed_by`, and the raw `t1`..`t4`,
`duration_m`, `s1`, `s2` beside the window.

**What changed from §2 because of the data**
- **Keys: `.sid` and `.tid` are unique only within a schema.** `afli` and `fs_afladagbok` number
  independently; 15,184 station ids and 6,565 trip ids occur in both (and 6,563 of those trip ids
  carry different vessels). Every join is on `(id, schema)`; with that, only **21** stations have no
  unambiguous vessel. **Everything downstream (`ping_activity`, `ais_trail`) must carry `schema`.**
  A join on `.sid` alone attaches one schema's pings to the other's station.
- **Jiggers (LHM) are a separate class, `jigged`, with one active window `[t1,t4]`:** `duration_m`
  equals `t4 − t1` in 98.6 % of rows and the speed after `t1` is a steady ≈ 1 kn (drifting, jigging).
  Not set/haul/soak. (`reference/gear/windows.R` updated.)
- **The "rebuild a net's `t1` from `t4 − duration_m`" idea (§8 Q8) is withdrawn:** only 25 % of net
  stations agree to 5 min (median error 193 min), and only 1 gillnet station has `t4` and
  `duration_m` but no `t1` — nothing to rebuild.
- **Set duration (Q9) estimated from the AIS speed profile after a recorded `t1`** (2014–2023,
  before the station's own haul and the vessel's next event): longline speed stays ≈ 6 kn for
  ~2 h then drops to ≈ 1.8 kn → **150 min**; gillnet 2.7 kn in the first half hour, ≈ 1.2 after →
  **60 min**. Stored in `gear_window.set_max_min` with `set_max_basis`. An estimate, not a record.
- Typical haul (for stations with `t4` only), median of recorded `t4 − t3`: LLS 498 min, GNS 295.
  A record with `t1 = t3 = t4` (duration 0; 329 longline stations) is a stamp, not a haul, and
  gets the typical haul ending at `t4`.

**Built (rows, median window)**

| class | phase | basis | n | median min |
|---|---|---|---|---|
| towed | tow | recorded | 4,075,797 | 210 |
| towed | tow | capped | 396 | 156 |
| towed | day | synthesised | 1,584,520 | 1440 |
| static | haul | recorded / synthesised / capped | 47,312 / 205,799 / 354 | 415 / 498 / 36 |
| static | set | synthesised | 257,490 | 150 |
| static | day | synthesised | 687,384 | 1440 |
| jigged | jig | recorded / derived | 76,231 / 13,036 | 480 / 574 |
| jigged | day | synthesised | 414,417 | 1440 |
| other | day | synthesised | 109,467 | 1440 |

Capping is rarer than §9 predicted (396 tows, 354 hauls): most of the earlier "overlap" count
was stations with an *identical* start (one tow logged twice), which a strict "next start" cap does
not touch. Duplicate windows therefore stay as ambiguity, handled at the join.

**Checked against the current (old) trail, 2019** — as a test that this is not a tangent:
- **Towed, recorded `[t2,t3]`:** the old trail's window has the same start and end within 1 min in
  **98.9 %** of 39,359 matched tows; per-station ping counts are identical in **90.6 %** of 48,604
  stations (median 40 pings new, 41 old). Danish seine agrees too (median start/end difference 0).
- **Static gear differs, and only as designed:** of the old-trail pings that no new window claims,
  **99.9 %** for longline (1,047,351 of 1,047,980) and 97 % for nets fall inside the same station's
  `t1..t4` — the soak, which the old trail tagged as fishing and this table does not.
- **Totals:** 9.78 M pings tagged by any new window vs 9.59 M by the old trail; 82 % of the old
  set is also in the new set, 87 % of the new non-`day` pings are in the old set. New non-`day` pings
  the old trail lacks: `set` 586,213 of 633,410 (it had no set window), `haul` 321,049 of 2.29 M, `tow`
  69,818 of 4.04 M, `jig` 13,492 of 84,730; why the haul and tow ones differ was not examined.
- **Not explained:** old code 5 (Danish seine) has 94,157 pings (19 %) in 2,232 old windows that
  overlap a new tow window but are not claimed by it; windows match in the typical case, so this
  is a subset (edge, duplicate or capped windows) to look at in Phase 3 when pings are joined.
- Gaps the old trail could not show: it had a `t1` on every station-tagged row (the whole-day
  fill, unflagged); here 28 % of towed, 76 % of static and 82 % of jigged stations are `day` and say so.

## 11. Phase 3 — `ping_trail` and `ais_trail()` built 2026-09-30

**`curated/ais/ping_trail/year=*`** (2007–2026, 20 files, 2.3 min for all): 12 of the
ping columns plus `speed_raw`, `pos_basis`, `speed_basis`, `speed_gps`, `dt_sec`, `sid_gps`,
`n_sid_gps`. 2019: 52,584,477 rows, of which 2,645,070 gps. Unique on `(vid,time)` and ordered by
`vid, time` in every file (checked after writing; the build stops otherwise). Each file carries its
`fd.*` provenance stamps through the new `write_curated_sql()` (`R/write_curated.R`), which does
for a table too big for R what `write_curated()` does for a data frame.
- **Speed in knots throughout.** The gps speed was converted from m/s (× 1.9438). Check: median
  speed inside recorded OTB tows, 2019 — gps 3.69 kn, stk 3.70, astd 3.63.
- `speed` is NA where the value is < 0 or > 40 kn (2019: 3,803 rows; 2017: 20,980); `speed_raw`
  keeps the knots value. Gps fixes that tie an AIS ping's `(vid,time)` (13,371 in 2019) are
  dropped, the AIS row kept, the logger's speed stored as `speed_gps`.
- Gps fixes with no position (outside any voyage) are not in the table. Gps rows carry no `pid`
  (harbour tag) and `mmsi`; `w_lon`/`w_lat` stay in `sensor_gps`, not here.
- **Speed is not one kind of measurement (found 2026-09-30).** `stk` and `gps` carry a measured
  speed; `astd`, `astdB` and `emodnet` have none and derive it from the distance to the next ping
  over the interval (`ais_ping_union.R`). `speed_basis` now says `recorded` for stk and gps and
  `derived` for the rest (it said `recorded` for all AIS in the first build).
- **astdB reads 2.1 kn in trawl tows (10 vessels): not a defect.** The same vessels tow at the same
  speed in their other feeds (vid 1848: 2.40 kn astdB, 2.30 other; 1787: 1.90 / 1.90; 2070: 2.50 /
  2.40). They are slower vessels (maintainer's reading, confirmed).
- **emodnet speed is wrong: lon and lat were swapped** in the call to `ramb::rb_speed(lon, lat,
  time)` in `ais_ping_union.R`. Not a unit problem: emodnet read 5.8 kn in tows against 3.6 for
  the same 78 vessels in stk/astd (ratio 1.47–1.92 per vessel, not constant, and not 1.85); a
  constructed 6.0 kn leg reads 13.6 kn when swapped. 19.3 M pings (2017 only); positions are fine
  and the whack filter does not use the column. Fixed in the source; registered as
  `curate/corrections/emodnet_speed_args_swapped.yml`. **The data is not rebuilt**, so
  `ping_trail` sets emodnet `speed` to NA meanwhile (one test in `ais_ping_trail.R`, to delete
  after the chain is rebuilt from `ais_ping_union`).

**`ais_trail(years, vids = NULL, long = FALSE, sorted = TRUE)`** — a lazy table, joined on the way
out. One whole year takes ≈ 9 s unsorted. `sorted = TRUE` (default) sorts by `vid, time`, which is
right for vessels and gears and runs a busy year out of memory if you aggregate the whole year —
pass `sorted = FALSE` for that (DuckDB does not keep the order through the join: 3.2 M violations
in 2019). Tier rule: a `day` window claims only fixes no recorded, derived, capped or set/haul window
claims; ambiguity stays (`n_sid`, and `sid`/`tid`/`phase`/`phase_frac`/`win_basis` filled only when
one station claims the fix); `fishing` = a tow, haul, jig or day window whose own `[s1,s2]` holds the speed.

**2019 result:** 11,564,744 of 52.6 M fixes are in a window: 11,269,374 uniquely, 295,370 (2.6 %)
ambiguous; 8.16 M `fishing`.

**Against the current trail, 2019 (old fishing = station-tagged and speed in `[s1,s2]`):**
- Tow windows on AIS fixes agree: **94 %** of the new fishing fixes in a recorded tow from `astd`
  and from `stk` are also fishing in the old trail. The new fishing fixes that are *not* in the
  old trail are almost entirely the **gps logger's** (921,391 tow fixes, 0.1 % of them in the old
  trail) - the old trail carried none of them as fishing.
- The old trail's fishing fixes with **no** new window: 831,230, of which 708,442 are old code 1
  (longline) and 70,777 old code 2 (nets) - the soak - plus 41,163 old code 5 (Danish seine, the
  subset flagged in §10). A further 285,692 have a window but the speed is outside its range.
- Overall: 8.16 M new vs 7.76 M old fishing fixes, 6.07 M in common.

**Not done:** `ais/ping_activity` (the live join was fast enough, §4); the `.tid` for fixes in an
AIS voyage but no window (plan §3.3, via `link_trip_voyage`); the `docs/` line; `tar_make()` has not
run these targets, so the new parquet files are stamped `fd.dirty`. Whether to also store a sorted
wide `ais/trail` (≈ 2 GB a year) is a decision for the maintainer.

**Longline events (maintainer, 2026-09-30: keep track of all three).** Every `station_window` row
now lists the events its station recorded (`events`, `n_events`) next to the raw `t1`, `t2`, `t3`,
`t4`, and `ais_trail()` passes `events` through. Longline rows by events recorded (`station_window`
rows, both phases counted): none 377,765 · `t1+t4` 275,754 · `t1+t3+t4` 51,196 · `t1` 1,141 ·
`t4` 7. The old trail's longline windows end at the recorded `t4` and start somewhere between 3 and
22 h earlier (median 8.1 h), matching neither `t1`, `t3` nor `duration_m`; this table also ends the
haul at `t4`, and starts it at `t3` when recorded, else at `t4` minus the median recorded haul.
