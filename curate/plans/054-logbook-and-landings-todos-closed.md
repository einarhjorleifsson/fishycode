# 054 — The logbook and landings TODOs closed: what each needs, in one or two rebuilds, and one sitting of asks

**status:** proposal — written 2026-10-30 at the maintainer's request, in a side session; the items checked against
their own text and the code, and the cheap counts measured read-only on the store, the same day; asks a-r
answered by the maintainer the same day (§5), each as recommended but m b (not known: TODO 146 stays open on it, so
24 items are expected to close) and q (no recommendation: yes, the size stated and asked before any download); h d
amended the same day: the logger stays in the AIS track (decision 196); TODOs 24, 34, 95, 98, 110, 139, 142 and
151 added the same day for little cost (§7); step 0 done the same day (decision 247); step 1's studies recorded (decisions 248-251); §7's
small step 2 changes coded the same day (95, 139, 162, 34, 24); nothing built · **measured** (§1), by Claude, read-only, in counts only, not checked by a person, every number in
`$FISHYDATA/archive/2026-10-30-closing-plan/` (`measure.py`, its output `counts.txt`): the target graph, the afli east
longitudes, the overlapping trips, the handline hole against the tour app, adb's towed times, the Nephrops tails, the
stations outside their trip's days or without a window, the e-logbook apps; and what the code builds, by grep at
6a05855 · **assumed** (§2): the tour app's `ship_id` is the vid; a tour trip landing on a handline landing's vessel-day
is its trip; the counts of the items not re-measured stand as their records give them · **see:** plan 038 (§8, the
logbook flow's order, which this plan amends in §4), plans 027, 036, 037, 039, 050-053, TODO 122, decisions 098, 189,
191, 198, 199, 205, 206, 208, 210, 214, 240, 241, 244, 245

Drafted with AI assistance (Claude) on 2026-10-30; a person has not yet checked it, nor any number in it.

The maintainer asked for a plan whose goal is to close most of the open `TODO.md` items about the logbooks (afli,
fs_afladagbok, adb, the e-logbook feed, ERS) and the landings (lods, ask/agf, `lid_map`, the trip-landing match, whole
weight). It builds nothing. It says, item by item, what closing means, what blocks it and what it costs; it orders the
work so the live store is rebuilt as few times as possible; and it gathers every question for the maintainer in §5.

## 0. Scope

**In (32 items):** 62, 70, 73, 75, 81, 100, 101, 102, 103, 107, 111, 112, 115, 118, 122, 123, 126, 131, 135, 136, 137,
138, 141, 146, 152, 156, 157, 160, 162, 163, 165, 167. The 22 leads given, and ten found by reading every item: 75,
101, 102, 107, 111, 112, 115, 118, 122, 152.

**Left out, though they touch a logbook or a landing:**
- 24 (vessels landing with no AIS): an audit of the AIS key, not of the landings.
- 34, 98, 99, 105, 142, 147: windows, voyages and the logger on the track, AIS batch. Two pieces ride §4's rebuild
  as riders: 34's gillnet speed floor (through 138) and decision 198's drift rule (103's).
- 110 (`takt_json_form`): a fault of the dumper.
- 124: plan 040's phase 2 runs inside each step here, as plan 038 §8 says.
- 125 and 140: products.
- 130 and 133: parked by the maintainer, references.
- 134: sampling.
- 139 (ties): a rider.
- 151's second measurement (records shorter than four ping intervals): could ride §4, but it is not needed.

Of these, 24, 34, 98, 110, 139, 142 and 151 were added on 2026-10-30, with 95, because they cost little beside the
plan's own work (§7).

## 1. What was measured (read-only, 2026-10-30)

On the store as built 2026-10-29 and 2026-10-30: `station.parquet` at ea574e6, `catch_flag` at dbece0c, `gear_part` at
a5880c8, `fd.dirty` false. "Kept" means duplicate twins and deleted records out.

**The rebuild unit.** `tar_network()` (read-only) of the main project's 155 targets:
- `logbook` has 24 downstream targets, down to `ais_trail`. Every adapter (afli, fs_afladagbok, adb) and `landing`
  (through `aflaskeyti_trip`) sit above it, with 26-29 downstream targets each.
- `lid_map` has 16 downstream targets, `station_window` 9, both down to the trail.
- The leaves: `catch_by_species_station`, `catch_by_species_trip`, `logbook_part`, `station_note`.
- `check_allocation_audit` reads `ais_catch`, which the standing rule leaves out (decision 241).

So every change below but the records rebuilds the same chain, and they can share one rebuild.

**Counts.**

| item | measured | against the item |
|---|---|---|
| 162 | afli stations east of 10.75° E south of 67.66° N: 35 before 2000, 52 in 2000-06, 14 in 2007-09, 322 in 2010-20, 13 from 2021; **349 from 2007** | the same 436 |
| 141 | afli handline stations 2,851 in August 2020, 124 in September, 8 in December; fs_afladagbok 814 in April 2021, 4,335 in May | as the item |
| 141 | handline landings September 2020 to March 2021: 2,411, of which **2,091 (87 %) have no logbook trip**; for **1,442 of those (69 %)** a tour-app trip of the vessel lands that day. May-August 2020: 4,836 with no trip, 2,324 (48 %) with a tour trip | new |
| 73, 141 | the tour app (unread, `part.R` says so) holds 7,823 spots in 2020-01 to 2021-04 on vessel-days the merge lacks, 5,517 of them handline, 4,326 (2,483) in September-March; from May 2021 none, as the STOKKUR copies hold them | new |
| 102 | trips overlapping another of the same vessel and source by over 1 h (trip `T1`-`T2`): afli 12,045 (14,865 pairs), fs_afladagbok 3,862 (2,711), adb 576 (361) | lower than the item's 21,220, 4,116 and 624 of 2026-10-20 (another build, perhaps another definition; not reconciled) |
| 107 | adb's 36,689 trawl and dredge samples (OTB 32,640, OTM 1,367, DRB 2,682): `t2`, `t3` on all; `t1`, `t4`, `duration_m` on none. `calc_effort()` takes a mobile gear's `t2` → `t3` (`R/logbook_effort.R`) | the effort comes from the times, so the empty `duration_m` is no recorded duration, not a loss; the item's "`t1`/`t4` in `fishing_sample`" is outdated since decision 240 |
| 152 | Nephrops logged/landed per trip from 2019: 0.28 (vid 2048, 48 trips), 0.28 (173, 59), 0.34 (1645, 76), 0.35 (1752, 56); the next vessel 0.95 | unchanged on main |
| 101 | kept stations dated outside their trip's days: fs_afladagbok 11,153 of 370,984 (3.0 %), adb 3,140 of 88,200 (3.6 %), afli 2,741 of 6.83 M | as the item |
| 101 | kept stations with catch and no window: 42, 68.5 t, all afli; 38 from 2007, 57.5 t | the item's 43 and 57 t |
| 137 | kept e-logbook stations by app: STOKKUR 23,132 (21,485 trips), Marína raun 13,144, FRA TAKTIKAL 6,958; adb's 88,200 carry no app (`source` NA) | plan 053 step 2 carries it |

**The code** (grep at 6a05855):
- **Not built:** decision 198's drift rule (no trace in `R/trail_sql.R`); decisions 206 and 214 (no trace in `curate/`
  or `R/`); the tour app; `protected_bycatch`; an fs port override (none in `overrides/`); agf's `afdrif` (read
  nowhere); `trip_landing`; plan 053's profile (nothing reads `logbook_app_profile.yml`); 101's flag for stations
  dated outside their trip.
- **Built:** deleted stations are out of `station_window` and `voyage_gear` (`eytt_deleted`).
- **Unchanged:** 139's ties (`arg_max` in `voyage_gear.R`, `row_number()` in `trip_reconciled.R`).
- Plan 050 step 5 is on branch `plan-050-step5-tails`, off main.
- `effort_count` can be read from the part tables without a cycle: `afli_part`, `fs_afladagbok_part` and `adb_part`
  do not read `logbook`; only `logbook_part` does.
- Plan 036's header still says "seven asks open", though decision 208 answered them.

## 2. What is assumed

- The tour app's `ship_id` is the vid, as plan 019 assumed. Not checked here.
- A tour trip that lands on a handline landing's vessel-day is that landing's trip. The day is matched, not the catch.
- The counts of items not re-measured here (75, 81, 112, 118, 160, 163) stand as their records give them.
- A live rebuild of the chain without `ais_catch` takes about an hour, as decision 241's did.
- The changes of §4 step 2 interact no further than the combined scratch build shows.
- Every live rebuild waits for the maintainer's go, as plan 053 step 9 and TODO 137 say.

## 3. The items

Cost: **rec** a record only (a decision, a doc edit); **ro** a read-only measurement; **scr** code and a scratch store;
**live** a live rebuild. Step: §4's.

| TODO | closes when (its check, short) | blocked by | cost | step | expected |
|---|---|---|---|---|---|
| 62 | foreign logbooks 2019-2025 dumped, staged, their catch on the record path in `ais_catch` | outside: the files (Norway's open ERS for half; no lead for the rest); `ais_catch` held out | scr, live | later | open (ask q) |
| 70 | the rows `TO_CHAR` rejects recorded | maintainer: plan 018 §3's query, on Oracle | rec | 0 | close (ask n) |
| 73 | plans 019 and 020 each built, parked or abandoned | plan 020: nothing, it is built as plan 052 (decisions 244, 245; `g_*` is 163's). Plan 019: the tour app, a port override (reviewed), `protected_bycatch`; its fs depth is plan 053's D2; its `rekjanleiki` is 160's | rec, scr, live | 0, A | close with A (ask k) |
| 75 | the ~410 lost trips and 1,854 rows before 2007-09 decided, with evidence | nothing: decision 098's rule (kept in phase 2 by decision 189), now testable against landings, since `lid_map` reads LODS from its start (decision 205) | ro, rec | 1 | close; a class that the evidence would admit goes to the maintainer |
| 81 | a trip's further landings join it; kg on the fixes, raised, equals kg landed per vessel-year | maintainer: plan 027's asks a-d; the kg half needs `ais_catch` | scr, live | B | close with B (asks b, p) |
| 100 | decided whether sensor readings are a product, and which column measures what | nothing: plan 052 made the per-haul readings a product (`sensor_summary`, decision 244), with every unit in the overlay (decision 245); the logger's stream is 163's `vessel_sensor` | rec | 0 | close |
| 101 | each chosen fix built or declined; the audit read after the rebuild | the outside-trip flag and `voyage_gear`'s tie (139) ride A; two fixes and the audit sit in `ais_catch`, held out | scr, live | A, B | close with B (asks o, p) |
| 102 | the overlapping trips classed with counts, and each class's treatment | a read-only study, then a treatment per class | ro, scr, live | 1, A | close with A (ask f) |
| 103 | decision 198's rule built and traced; the gillnet sets in port explained or listed; the Trackwell draft sent or dropped | the rule rides A; the draft waits for the hold on outside contact | ro, scr, live | 1, A | close with A (asks e, o) |
| 107 | each draft decided and recorded | nothing: decision 206 decided every draft, and plan 053's review amended it (its ask d: Trackwell raun's tow starts at the departure are real); adb's empty `duration_m` is declared (§1) | rec | 0 | close; the build is 165's |
| 111 | the page's column tables retired, or both kept by decision | maintainer: yes or no | rec | 0 | close (ask l) |
| 112 | landings, trips and their catch carry a disposition; landed kg unchanged | plan 027's `trip_landing` (decision 208 joins through it) | scr, live | B | close with B (ask b) |
| 115 | plan 037's phases built or declined | nothing new: every ask answered (decision 189). Large: the afli layers' precedence, then phase 2 | scr, live | later | open; rebuild C |
| 118 | each of the 23,513 and 14,759 in one outcome, admission decided per class, no haul staged twice | nothing: decision 098's rule (decision 189); the admission's build is plan 037's | ro, rec | 1 | close; a class to admit goes to the maintainer |
| 122 | plan 038's phases built, or the plan closed | an umbrella | — | — | open; this plan amends its §8 |
| 123 | every period's landings in one shape, every layer in one outcome | outside: the Directorate's and a DBA's answers; plan 039 is large | scr, live | later | open; its `withdrawn` and the (`.lid`, `schema_land`) key may ride B |
| 126 | each source's ends in one kind (point, cell, none); the per-app check | parked by the maintainer | scr, live | A | close with A if unparked (ask g) |
| 131 | the metier per operation, a2 answered | parked by the maintainer | — | — | parked (ask r) |
| 135 | pumped catch on the catcher | parked by the maintainer | — | — | parked (ask r) |
| 136 | afli's monthly summaries in the logbook | parked by the maintainer | — | — | parked (ask r) |
| 137 | the trip-timed records typed and windowed as decision 214 says, traced | the maintainer's go for the build | scr, live | A | close with A |
| 138 | the three faults decided | parked by the maintainer | scr, live | A | close with A if unparked (ask g) |
| 141 | the missing trips read from a source, or the gap declared where the analyst reads it | the tour app fills 69 % of the hole's landings (§1); the rest is declared | scr, live | A | close with A (ask j) |
| 146 | towed `t3` named one event; the protocol's cruise named | maintainer: two answers | rec | 0 | close (ask m) |
| 152 | tail weight converted by rule with its basis, or declined | nothing new: plan 050 ask c and plan 051 ask a are answered; the tails become a state in plan 051 step 4 | scr, live | A | close with A |
| 156 | plan 050 executed or parked | step 5 lands with 157; ask f waits for the hold | scr, live | A | close with A (ask e) |
| 157 | plan 051 executed or parked | the lumpfish rows wait for HV 2020-33's authors | scr, live | A | close with A (ask d) |
| 160 | the id taken as a witness or not; if taken, dumped, built, measured | maintainer: the choice, and the dump of `ops$rafn.rekjanleikanumer` | scr, live | B | close with B (ask c) |
| 162 | those from 2007 judged by the track; flagged | nothing: 349 stations (§1); a correction only by decision | ro, scr, live | 1, A | close with A |
| 163 | `effort_count` from the part tables; `vessel_sensor` built or declined | plan 052's asks d and e; `g_*` out "a release later" | scr, live | A | close with A (asks h, i) |
| 165 | plan 053's asks answered; the profile, the flags and the check built; the windows traced | its steps 2 and 4-9 need none of the open asks f and g | scr, live | A | close with A (ask e) |
| 167 | staged and merged, every record in one outcome | plan 051's table; HV 2020-33's authors | scr, live | A | close with A (ask d) |

**Expected to close, if §5 is answered as recommended:** 25 of 32. In step 0: 70, 100, 107, 111, 146. In step 1: 75,
118. With rebuild A: 73, 102, 103, 126, 137, 138, 141, 152, 156, 157, 162, 163, 165, 167 (126 and 138 only if
unparked). With rebuild B: 81, 101, 112, 160.

**Close without an answer from the maintainer** (beyond the go for rebuild A): 75, 100, 107, 118, 137, 152 and 162,
and plan 020's half of 73.

**Left open, and why:**
- 62: the files are outside, and its check needs `ais_catch`.
- 115: plan 037 is large, and it is a rebuild of its own (C).
- 122: an umbrella.
- 123: outside answers are pending, and plan 039 is large.
- 131, 135, 136: parked by the maintainer.

## 4. Order of work

Plan 038 §8 stands, and this amends it: plans 050-053 came after it and are decided, so their builds move ahead of
phase 3 (the link) and phase 4 (the sources).
- The tour app moves into A, because 141's gap is mostly its own (§1).
- Plan 037's phases 1 and 2 follow A, as rebuild C.

Each change follows plan 037 §6: a scratch store of its own, traced before and after against the live store; then a
decision record; then the maintainer's build by name.

**Step 0 — records only, no data** (Claude, after the sitting):
- 100 and 107 closed by decisions that cite what already decided them;
- plan 020 marked built as plan 052;
- 70, 111 and 146 recorded from the answers;
- the outside TODO of ask e;
- plan 036's header brought up to decision 208.

**Step 1 — read-only studies, each ending in a decision** (Claude, every record in one outcome):
- 75 and 118 as one study: afli's records outside `afli.stofn`, judged by decision 098's rule against the landings.
- 162: the 349 judged by the track.
- 102: the overlaps classed: resubmissions decision 094 misses, test entries, several boats under one vid, real
  overlaps.
- 103: the gillnet sets in port that plan 053's rows do not flag, listed.

**Step 2 — code, each change on its own scratch store:**
- a. **Plan 053's steps 2 and 4-8**: the app carried, the check, the flags, the windows reading them, the decoders, depth
  by app. This carries 107's drafts, 103's other patterns, fs depth (73), 126's forms if unparked, and 138's
  handline dummies.
- b. **Decision 214 (137)**: the trip-timed records typed by what they cover, the voyage as their window. After a,
  since it reads the app.
- c. **Plan 051's steps 3-5 with 152**: the factor table, `calc_whole_weight()` reading it, the landings keeping state
  and weight as landed. The tails branch's detection is merged into step 4, and its 3.3 gives way to the table's row.
- d. **TODO 167's adapter**, after c's table.
- e. **Plan 019's remainder (73, 141)**: the tour app staged, its spot time read as the end of fishing (decision 214);
  its trips never in fs_afladagbok classed and admitted per class (decision 210); the tour app's port code read as `hid` (decision 252), with no
  override; `protected_bycatch`.
- f. **The merge's flags**: 162's east longitudes; 101's stations outside their trip; 102's twin rule widened, 138's
  Marína re-entries with it.
- g. **163**: `effort_count` read from the part tables, so `logbook` reads them; `vessel_sensor`, a leaf.
- h. **Riders**: decision 198's drift rule in `R/trail_sql.R` (103); 139's tie-breaks; the nets' 0.2 kn floor (138,
  TODO 34).
- i. **The link (B)**: plan 027's `trip_landing` (81), the disposition through it (112), the Directorate's id as a
  witness (160), and plan 039's `withdrawn` and key if ready. With them, 101's two `ais_catch` fixes.

Then plan 051's step 6 account, and one combined scratch build of every change, traced as plan 053 step 9 says. The
trace covers the windows, `station_event`, the fishing fixes, effort, the stations' outcomes, and kg in = kg out. The
live rebuild then holds no surprise. The catch halves (81, 101) are checked on that scratch store, with `ais_catch` and
the audit built there (ask p).

**Rebuild A (+B).** One live rebuild by name of the chain:
- adapters → `landing` → `logbook` → `lid_map` → windows → trail, and the leaves;
- fingerprints before and after;
- `ais_catch` and `check_allocation_audit` left out;
- no tracked edit while it runs.

If asks b and c are answered and 2i is ready, A and B are one rebuild. Otherwise A goes first, and B rebuilds the same
24 targets later.

**Later.** Rebuild C: plan 037's phases (115), with any class step 1 admits (75, 118), TODO 62's data when they come,
and plan 039 when its outside asks are answered. The parked items stay parked.

§7 adds items to steps 0, 1 and 2, to rebuild A and to the time after it, and gathers every Oracle read into one
sitting of the maintainer's.

## 5. Asks

Ordered by how many items each unblocks. The first option is the recommendation.

- a. **The batching (§4):** each change on its own scratch store, then all together, then one live rebuild (A and B
  together if b and c are answered in time), or one rebuild per change. Recommended: the first. Shapes every row of §3.
  *Answered (maintainer, 2026-10-30):* the first.
- b. **Plan 027's four asks (81, and 112 through it):**
  - a: a flow table, `trip_landing` (recommended), not `lid_map` with a date rule.
  - b: any port, up to 7 days, until the vessel next goes fishing (recommended).
  - c: in-port landings the logbook lacks (C) joined, so the raising carries their catch (recommended).
  - d: the voyage rule for `lid_map`'s misses as a TODO of its own (recommended), not in B.

  *Answered (maintainer, 2026-10-30):* all four as recommended.
- c. **TODO 160:** the Directorate's id as a witness column on every link, and the resolver for swaps and step 05, as
  its findings propose (recommended). And the maintainer dumps `ops$rafn.rekjanleikanumer` (`run_dump`, one table)
  before B. *Answered (maintainer, 2026-10-30):* as recommended; the maintainer dumps the table before B.
- d. **The lumpfish rows (157, 167):** build plan 051's table and TODO 167's source now, the lumpfish rows marked
  provisional (basis `derived`, witness HV 2020-33), the authors' answers amending them later (recommended). Or hold
  both for the authors. *Answered (maintainer, 2026-10-30):* built now, the lumpfish rows provisional.
- e. **One TODO for every outside wait** ("when contact resumes", `needs: maintainer`), recommended. It takes:
  - plan 050's ask f and plan 053's ask f (the live fs_afladagbok, and read access to `mfriops/Landings`);
  - plan 053's ask g (Trackwell's own file);
  - TODO 103's Trackwell draft;
  - TODO 141's question to the Directorate;
  - plan 051 c's questions to HV 2020-33's authors.

  156, 165, 103 and 141 can then close on what fishycode does, and the waits are kept in one place. Or each wait stays
  in its item. *Answered (maintainer, 2026-10-30):* one TODO for every outside wait.
- f. **TODO 102's treatment, by class:** set now, applied once step 1 counts the classes. A class over 1 % of trips,
  or one these do not fit, comes back to the maintainer. Recommended:
  - a resubmission decision 094 misses: `duplicate`, by a widened twin rule (with 138's 125 Marína re-entries);
  - a test entry: flagged, left out of the links;
  - several boats under one vid: listed for the register's review (TODO 25, 65);
  - a real overlap: kept; a fix inside both trips gets no trip and a flag (decision 191 c).

  *Answered (maintainer, 2026-10-30):* as proposed, a class over 1 % or one that fits none coming back.
- g. **Unpark 126 and 138, to ride A** (recommended):
  - 126: decision 211's representation and the per-app check, built with plan 053 step 7's decoders;
  - 138's handline dummies: under plan 053's window rule;
  - 138's Marína re-entries: under f's twin rule;
  - 138's nets: a speed floor of 0.2 kn, TODO 34's measured value.

  Or both stay parked. *Answered (maintainer, 2026-10-30):* both unparked, to ride A.
- h. **Plan 052's asks d and e (163; d touches TODO 98):**
  - d: the logger taken out of the AIS union, its readings in `vessel_sensor`, recommended, as the maintainer said
    on 2026-10-29: "including them in the ais is not the way". The union's change goes to the next AIS batch, and
    `vessel_sensor` is built in A.
  - e: the 848,306 readings dated 1899-12-30 dated from the record that carried them, basis `reconstructed`, flagged
    (recommended).

  *Answered (maintainer, 2026-10-30):* d and e as recommended. *Amended by the maintainer the same day:* d's
  recommendation misread its quote, which was on the logger's depth readings not becoming AIS columns (plan 052's
  opening), not on its fixes. Decision 196 keeps the logger in the track for its speed and heading, which place the
  fishing between AIS pings. So d: the logger stays in the AIS union as decision 196 has it, nothing changes in the
  next AIS batch, and only its other readings go into `vessel_sensor`, long, with no positions (plan 052 §5, amended).
  e stands.
- i. **163's `g_*` columns:** kept until TODO 140 versions the product, and 163's check narrowed to `effort_count`
  and `vessel_sensor` (recommended). Or dropped in A. *Answered (maintainer, 2026-10-30):* kept until TODO 140.
- j. **TODO 141:** closed by the tour app and the remainder declared in `docs/merge.qmd` and the landings' dictionary
  entry (recommended). Or held for the Directorate's answer. *Answered (maintainer, 2026-10-30):* closed by the tour
  app, the remainder declared.
- k. **TODO 73's port translation:** Claude drafts the override from the codes, and the maintainer reviews it before
  A (recommended), as `stk_hid_pid.csv` was. Or the translation is parked, and 73 closes with it parked.
  *Answered (maintainer, 2026-10-30):* Claude drafts, the maintainer reviews before A. *Superseded the same day by
  decision 252:* the codes are the landing system's own, translated by `curated/reference/port.parquet`; no override.
- l. **TODO 111:** the page's four column tables deleted for `docs/data-dict.yaml`, and the dictionary rendered as a
  page of the book (recommended). *Answered (maintainer, 2026-10-30):* as recommended.
- m. **TODO 146:**
  - a: towed gear's `t3` is the start of hauling (E), as Hafriti and fs_afladagbok record it, and the grammar's table
    follows (recommended);
  - b: the protocol's cruise, and whether its A-J records exist. Only the maintainer knows.

  *Answered (maintainer, 2026-10-30):* a as recommended. b is not known: TODO 146 stays open, narrowed to it.
- n. **TODO 70:** plan 018 §3's `DUMP()` query run at the maintainer's next Oracle session (one scan of `afli.afli`).
  Claude then records the rows. *Answered (maintainer, 2026-10-30):* yes, at the next Oracle session.
- o. **The riders on A:**
  - decision 198's drift rule (103);
  - 139's ties: `voyage_gear` by decision 199 (kilograms, then gear code, the gear and its class from one row);
    `trip_reconciled`'s STK witness by the later return, then the lower voyage id (recommended), or read as
    `ambiguous`.
  - TODO 34's gillnet floor (with g).

  *Answered (maintainer, 2026-10-30):* all three as recommended, ties broken as stated.
- p. **The catch halves of 81 and 101:** checked on the scratch store with `ais_catch` and the audit built there,
  the live store kept without them, as decision 241 left it (recommended). Or both built live once. Or the halves left
  open. *Answered (maintainer, 2026-10-30):* on the scratch store only.
- q. **TODO 62:** may Claude fetch Norway's open ERS catch messages for 2019-2025, the size stated and asked before
  the download? The Faroese half goes to e's TODO. 62 stays open either way: its check needs `ais_catch`.
  *Answered (maintainer, 2026-10-30):* yes; Claude names the files, their source and size, and downloads only on the
  maintainer's yes.
- r. **131, 135 and 136:** kept parked (recommended), since A is large enough. *Answered (maintainer, 2026-10-30):*
  kept parked.

## 6. What it changes

Nothing until §5 is answered. Then the TODO items of §3 (25 deleted as they close, each recorded in a decision), one
new TODO (ask e), and plan 038 §8, which gets a pointer here. Plan 020 is marked built, and plan 036's header is brought
up to date. Plans 050, 051 and 053 are executed through rebuild A, and plan 027 through B. Rebuild C and the parked
items are not this plan's.

## 7. Added along the way

*The maintainer, 2026-10-30: "check if there is anything in the TODO's that could be handled cheaply along the way",
then "fold them in". Each item was checked by Claude the same day, read-only, against its text, the code, the store
and the targets graph; not checked by a person.*

These items lie outside §0's scope. They are added because they cost little beside the plan's own work. Each stays a
TODO of its own and closes by its own check.

| TODO | what is added | step | expected |
|---|---|---|---|
| 34 | the gillnet floor, 0.2 kn (ask o), built with the riders; the item's status says so now | 0, A | stays blocked on the regulation and shoreline shapefiles |
| 110 | `--resume` counts a schema unfinished when its overview lists as skipped an object its script no longer skips; tested on the DuckDB stand-in, no Oracle | 0 | partly; the rest at the Oracle sitting below |
| 151 | its two measurements, which need no decision: the ping interval of each AIS stream by year, and the share of logbook records shorter than four ping intervals, by gear and year | 1 | partly; the four wishes are the maintainer's |
| 98 | the gap limit measured (decision 196): logger fixes kept, and those over 5 km from the recorded track, at 15, 30 and 60 min; the logger stays in the track (ask h, amended) | 1 | open; the maintainer picks the limit, and its build is the next AIS batch's |
| 24 | each of the 107 Icelandic vids that land with no AIS given a reason (no transponder expected, an STK unit or MMSI found, a match missed), from the register, the key and decision 161's units; an override marking 8008 and 8009 as divers, left out of `landed_but_no_ais` | 1, 2 | close |
| 95 | `sources/stk/convert.R` clears `staging/ais/stk` before it writes; `stk`, `stk_event`, `port_call` and `ais_voyage` join rebuild A (the rest of `stk`'s 16 downstream targets are in it already; 38 min at their last build times); only `stk` and `stk_event` change, by vid 2618's two rows of 2006; the STK page drops `unify_schemas` | 2, A | close |
| 139 | the tie-breaks of ask o; each step run twice on the scratch store gives identical files | 2, A | close |
| 142 | its counts rerun on the rebuilt trail, to show what plan 053's windows and decision 198's drift rule changed | after A | open; the decision is the maintainer's |

**The maintainer's next Oracle sitting**, one session for every Oracle read the plan and these items need:
- TODO 70's `DUMP()` query on `afli.afli` (ask n);
- `ops$rafn.rekjanleikanumer`, one table by `run_dump()` (ask c), before B;
- decision 196's three read-only STK reads (TODOs 110 and 117): `ALL_SEQUENCES` for the trail's sequence,
  `ALL_OBJECTS.CREATED` for its trigger and sequence, and a count of `stk.trail`;
- the stale overview rows of `stk.trail` and `afli.sjalfvirkir_maelar`, recomputed or re-dumped (TODO 110).

The sitting is three commands, from the repo root in the maintainer's own terminal (written 2026-10-30, not yet run):
`Rscript dump/oracle/ops_rafn.R`, `Rscript dump/oracle/checks/afli.R` and `Rscript dump/oracle/checks/stk.R`. Whether
the dump account can read `ops$rafn` is not known until then.

`fs_afladagbok.takt_json_form` (TODO 110) needs a decision first, its JSON dumped whole or left out, and is not in the
sitting until then.

**After A**, as after every rebuild: the user tables rerun (`products/user_tables.R`, decision 219), and the effort
map's grids (decisions 220, 228).

**Expected to close, with these:** 27 items: the plan's own 24, and TODOs 24, 95 and 139.
