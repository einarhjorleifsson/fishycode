# 011 — Harbour stays: fix voyage segmentation in general, with STK events as one source of evidence

**status:** partly built — Phase 0 measured and Phase 1 seed built 2026-10-01 (§2, §2a, §4a); **paused 2026-10-01 for a separate harbour/port session (§4b)**; Phases 2–5 not started · **2026-10-01** · **see:** plans
`006-trip-identity-and-catch-to-ais-pings.md` (§4, and its correction), `010-ping-activity-link.md` (§3.3, the
correction at its end); `reference/ports/bootstrap_iceland_faroe.R`, `reference/ports/ports_all.R`,
`curate/ais_trip.R`, `curate/ais_ping_clean.R`.

Drafted with AI assistance (Claude), from measurements run in the session of 2026-10-01 and from the maintainer's
direction on what to build first. The numbers are reproducible from the scripts named in §2.

**Measured** (2026-10-01, `$FISHYDATA`, read-only, STK 2007–2025): §2.
**Assumed:** everything in §3–§5 is proposal; each assumption is marked **(assumed)** where it is made.

## 0. The goal

**Fix the voyage problem in general:** one AIS voyage per real harbour-to-harbour trip, for every vessel and every
provider, so that a voyage-only `.tid` (plan 010 §3.3) and the logbook link (`trip_voyage`) become reliable. STK's
`io` events are not the goal. They are one *evidence source* for a harbour stay, available for STK only; ASTD,
astdB and EMODnet carry nothing like them, and the fix must not be STK-specific. §3.0 is the general rule; §3.1–§3.4
are what the STK events add to it and how their errors are handled.

## 1. Why

A voyage-only `.tid` for the trail (plan 010 §3.3) needs one AIS voyage per logbook trip. About 20 % of voyages
are linked to several logbook trips, and the largest are whole-year "voyages" of 260–363 days (vid 2481, 2011:
185 logged day trips, one voyage). The cause is not missing data and not the polygons:

- STK ships an `io` flag (`I` in / `U` out) and a harbour code `hid`. A day-trip vessel's record is
  `... I AST`, silence of 12–17 h, `U AST ...`.
- The `I` ping is inside its harbour polygon (the polygon was drawn around the `I` points) and is tagged `pid`.
  The `U` ping is outside it, by design.
- `ais_trip.R` measures a harbour stay as the span of the *pings in the run*. A one-ping run has span 0 h, is
  shorter than `MIN_HARBOUR_H = 4`, and is bridged into the surrounding voyage. 208 of 208 harbour runs of vid
  2481 in 2011 were bridged, while the median time to the next ping was 17.4 h.

So the dwell rule discards exactly the evidence STK supplies. The `I`/`U` events are also erratic (§2), which is
why a rule that trusts them must be preceded by a way to tag the bad ones.

## 2. Measured

**Polygons.** They are convex hulls of the distinct, 4-decimal `io == "I"` points per `hid`, after a hand-written
recode and exclusion list (`bootstrap_iceland_faroe.R:267–396`). Rebuilt from the raw trail they match the
committed ones in 100 of 157 cases and are larger in 57, never smaller. Share of events inside any polygon:

| | committed | rebuilt from raw |
|---|---|---|
| `I` | 97.5 % | 98.6 % |
| `U` | 34.5 % | 35.2 % |

Enlarging the polygons gains about one point. **They are not the fix.** (The bootstrap script itself cannot run
as committed: its `ports_add` block uses `.lat` after `st_as_sf` has consumed it.)

**Events, all STK 2007–2025:** 4.39 M `I`, 6.77 M `U`; `U` has no `hid` in 40.2 % of cases (`I`: 0.7 %).
Consecutive-event transitions: `I→I` 5.0 %, `U→U` 26.2 %; same-harbour `I→U` within 1 min 14 %, within 10 min
37 %, median 50 min. Between 5.7 % and 31.7 % of `I` events per year (worst 2009, 2016, 2008) never reach
`ping_trail`; the cause is not isolated (measured in §2a: the whack filter in `ping_clean.R`).

**Position against harbour id** (`I` events; the polygon is built from them, so this is a floor): 97.1 % in the
own polygon, 1.48 % in a *different* harbour's polygon, 1.44 % in none. The wrong-polygon events concentrate in
code collisions: `THO`→`IS-THH` 19,969 events in `IS-THO`; `A`→`IS-KRS` 15,998 in `IS-AKU`; `STM`→`IS-STY` 11,592
in `IS-STK`; `R`→`IS-REY` 9,774 in `IS-VID`; also `THH`, `STY`. Aliases (many codes, one place) are numerous
and already recoded in the bootstrap script, but the events keep the raw code.

**Implied-speed jumps between consecutive events** (11.16 M pairs): 865,210 (7.7 %) over 40 kn.
**This measurement is anchored on the previous event, which may itself be the wrong one** (§3.3), so the count
mixes erroneous events with correct events that follow an erroneous one. Three vessels (2765, 2438, 239) give
186,144 of the 865,210; two vessels sharing one `vid` would look like this and were not checked.

**Open loose ends:** harbour `A` has 100 % of its `I` events inside the raw polygon but only 24.6 % carry a `pid` in
`ping_trail`, so polygons change between `raw/ports/ports_iceland_faroe.gpkg` and the `ports.fgb` that tags the
pings (**assumed:** the correction step or `ports_all.R`).

## 2a. Phase 0 results — full dataset (2026-10-01, read-only, all years 2007–2026)

First run on sample years (2011, 2019, 2023), then repeated on every year; the figures below are the full run. It took about 3 minutes in
total for the gap rule, event loss and jump measurements (one year of the gap rule: 5–9 s). 2007 is the first AIS year, and 2025–2026 are
partial years with an incomplete logbook, so their vessel-year comparisons are not trustworthy and are left out of the pooled figures.

**(i) The general gap rule.** Gaps of at least 4 h in `curated/ais/ping` whose two bounding pings lie within 2 km of the *same* harbour (nearest
`source == "einar"` polygon). All years: 2,634,574 gaps; 2,345,875 (89 %) are same-harbour; **717,485 are inside one current voyage and
would split** (636,229 at 1 km, 776,769 at 5 km). 69,755 (3 %) have neither end polygon-tagged and are found only by rule 4; the rest have
one end tagged (rule 2: the `I` ping, then silence) or both. In 2007–2012 every such gap is STK; from 2013 the other providers join and STK-to-STK gaps fall to
16–41 % of the same-harbour gaps, the rest being astd/astdB or mixed.

Splitting by year changes the picture of how bad the problem is. Median voyages per logbook trip, vessel-years with at least 20 logbook trips,
**now → with the split:** 2008–2016 **0.10–0.68 → ≈ 1.2** (the STK era); 2017–2024 **0.67–1.04 → 1.10–1.18**. Share within ±25 % of one voyage per
logbook trip, 2008–2024 pooled (13,551 vessel-years): **33 % → 59 %**; in the weakest years (2008–2012) 9–11 % → 52–58 %. The split
overshoots by more than 25 % in 36 % of vessel-years: it is applied to every same-harbour gap with no transit guard and no tuning of the
4 h, so some of the excess is mid-trip harbour calls and merged logbook trips. Phase 3 has to explain it.

**(ii) Lost `I` events.** The loss is in `ping_clean`; no event is lost before the tagging in any year. Events missing from `ping_clean`, all
years: **`I` 15.0 %, `U` 9.7 %**, against 0.4–0.6 % of all pings. By year: `I` 31.9 % (2009), 29.1 % (2016), 22.7 % (2008), 21.7 % (2010), 19 % (2013–14),
and 5–8 % from 2017. Where examined (2016) the dropped events have median implied speed of 1,158 kn in and 723 kn out of the event, so most are
genuinely bad positions; they are concentrated: vids 2765 (68,744), 2438 (38,492) and 2323 (14,380) are 57 % of the 208,496 events dropped
that year, and 1,416 vessels have any. The filter is mostly right; the cost falls on a few vessels.

**(iv) Two streams in one `mid`, and jumps.** Pre-clean STK, 35,234 vessel-years, 181.8 M pings: 1,040,184 jumps over 40 kn (0.57 % of pings). They
are concentrated: **49 vessel-years with more than 20 % jumps (≥ 1,000 pings) carry 31 % of all jumps**; the median vessel-year has 0.1 %, the
99th percentile 7 %. Every one examined has a single `mid`: vid 2765 (62 % jumps) sends **two interleaved streams from one `mid`**, alternating about every
minute, one stationary at the Siglufjörður quay (−18.91, 66.15; 0 kn; `I`/SIG), one 30 km away at sea (−19.32, 66.31; ~1 kn; `U`); `ping_clean` keeps
both at about 58 % each, so its cleaned track still alternates between two places. 2438 (23 %), 239 (35 %, four years), 2323 (49 %), 2287, 1054 and others
were not examined beyond the counts. Two transponders on one mobile id is consistent with 2765 but is not shown for the rest.

**(iii) The `A` gap.** Polygons were not lost; `ports_all.R` reassigns `pid` globally, so `IS-STY`→`IS-STI`, `IS-RIF`→`IS-AMG`, etc. But three
polygons that STK events fall into have no counterpart in `staging/aux/ports.fgb`: `IS-KRS` Kristnes (44,729 of `A`'s 60,726 `I`
events, 0.74 km from Akureyri), `IS-STK` (11,592 `STM` events; labelled Stokkseyri in the raw gpkg but located at Stykkishólmur, about 1 km from the Stykkishólmur polygon, so a second berth with a wrong label) and `IS-VID` Viðey (5,310 `R` events). Those events carry no
`pid`. (76 raw pids are absent from the file; most are renames, which I did not map one by one.)

**(v) Transits.** Run-level speed cannot identify a transit in STK: STK is silent at the quay, so a harbour run is usually just the
arrival and departure pings, both at steaming speed. In 2011, 98.9 % of the 117,812 polygon runs contain an `I`/`U` event (the polygon was built
from them) and only 104 (0.1 %) are event-free fast runs; run-level figures were measured for 2011 and 2019 only. The useful measure is the `I`→`U` pair
at one harbour, **all years, 2,448,620 pairs**:

| stay length | pairs | speed at `I` / at `U` (median, kn) | both > 4 kn |
|---|---|---|---|
| < 1 min | 14.0 % | 0.0 / 0.1 | 14 % |
| 1–10 min | 23.5 % | 0.0 / 1.2 | 28 % |
| 10–60 min | 13.9 % | 1.4 / 4.5 | 31 % |
| 1–4 h | 7.9 % | 4.2 / 6.3 | 40 % |
| ≥ 4 h | 40.7 % | 5.6 / 6.6 | 50 % |

**265,245 pairs (10.8 %) last 1–60 min with both ends above 4 kn: the pass-through candidates.** (The two-year sample had given 17 %; the
full data is lower.) The `< 1 min` pairs at about 0 kn are a vessel at rest whose in/out flag flickers, not a transit. The guard in §3.0 therefore
keys on the length of the `I`→`U` pair and the speeds at its ends, not on the speed of the run.

## 2b. Per harbour, and harbours STK does not cover (2026-10-01, all years, read-only)

The `r` of §3.0 is not a buffer on the polygon: it is how far from the polygon a bounding ping may lie and still count as "at the
harbour". Phase 0 used one value (2 km) for every harbour. A constant is too crude, for these measured reasons:

- **Polygons differ 100× in size:** 0.035 to 3.1 km² (10th–90th percentile 105–500 m equivalent radius; Reykjavík 3.1 km², Hrísey 0.10).
- **Most gap ends sit close.** Same-harbour gaps (2.46 M, within 10 km), the farther end within 250 m / 500 m / 1 km / 2 km / 5 km of the
  polygon: **82 / 88 / 92 / 96 / 98 %**. Hrísey, Árskógssandur, Dalvík and Akureyri keep 99–100 % within 1 km–2 km.
- **Neighbouring polygons are rarely close enough to confuse:** of 141 polygons only 4 pairs are within 2 km and 24 within 5 km. The nearest-polygon
  test already separates them. Hrísey–Árskógssandur is 3.4 km, Hauganes–Árskógssandur 3.2 km.
- **Where 2 km does fail it is the polygon, not the radius:** 14 of 96 harbours with ≥ 200 gaps keep under 80 % of their gaps, e.g. Drangsnes
  (45 %, p90 7.7 km) and Njarðvík (59 %): the code collisions of §2 (`DRA`/`DRN`, `NJA`/`NJ`) and remote fjord landing places.
- **Harbours differ in what a call is.** From the `I`→`U` pairs per STK code (≥ 3,000 pairs; 108 codes), share of pairs that are 1–60 min with both ends above 4 kn
  ("fast through") ranges from 2.7 % (10th percentile) to 27 % (90th), maximum 88.9 %. Árskógssandur (`ASS` 34 %, `AR` 46 %, median stay 15 min, 87 %
  under an hour) is transient, the mainland end of the Hrísey ferry. Hrísey (`HRI`) is mixed: 7.7 % fast, median stay 77 min, 21 % under an hour,
  17 % over 4 h. Dalvík (`DAL`/`DL`) is a landing harbour: median stay ≈ 16 h, 65–69 % over 4 h. The yacht-harbour codes (`RYH`, `IYH`, `GYH`, `GRYYH`:
  79–89 % fast through, median 5–10 min, 0 % over 4 h) are excluded from the polygon set by the bootstrap script.

So **a harbour needs its own profile** (radius, and what counts as a stay), derived from its own `I`→`U` and gap statistics and open to a
human override, not one global radius.

**Harbours STK does not cover.** STK has no harbours on the European mainland or Greenland, so there are no `I`/`U` events and no
STK-derived (`einar`) polygons for them; a stay there can be found only from the other polygon sources in `ports_all` (gisco, jeppe/NW Europe, gfw, osm) and the gap
rule. Measured on the gaps of 2019 and 2023: 92–93 % are same-harbour in the Iceland/Faroe polygons, 1.5–2.1 % in another source's polygon
(of which 2,146 and 4,109 are *Icelandic* harbours without an `einar` polygon; only ~100 (2019) and ~330 (2023) are abroad: GB, PL, NO, DK,
IE, GL, RU), and 5.5–6.0 % are at no harbour within 2 km. That last group mixes real sea gaps with foreign harbours that have no polygon at all, and cannot be
separated from this data. The logbook cannot size it either: `pid2` resolves only to Icelandic harbours (the crosswalk is built from the Icelandic list), so a
foreign landing is invisible there.

## 3. Design

### 3.0 The general rule: a stay is elapsed time at a harbour, from whatever evidence there is
`ais_trip.R` today asks "is there a run of harbour-tagged pings, and is the *span of those pings* at least 4 h?".
The span of a run of one ping is zero, however long the vessel then stays silent. The general rule replaces the
span with **elapsed time**, and replaces "harbour-tagged ping" with "evidence of being at a harbour":

A **stay** is an interval `[T_in, T_out]` at one harbour, evidenced by any of, in this order of strength:
1. an STK `I`…`U` pair at the same standard harbour, both clean (§3.1–§3.3);
2. a harbour-tagged ping (polygon) followed by a **gap**: the next ping is at least `G` hours later *and* lies
   within `r` km of the harbour (**assumed:** `G` = the current 4 h, `r` ≈ 2 km; both to be set from the data);
3. harbour-tagged pings spanning at least `G` hours (the existing rule, unchanged);
4. a gap of at least `G` hours whose **both** bounding pings lie within `r` km of the *same* harbour, even when
   neither is polygon-tagged (a vessel that is silent in port and not heard at the quay).

Rule 4 is what makes the fix provider-independent. It must be guarded against satellite or coverage gaps at sea:
a gap counts only when both ends are at the same harbour, so a vessel that vanishes offshore and reappears
elsewhere is not turned into a stay. **Logbook landings are not an input** (AGENTS: cycles are broken outside the
DAG); they are the validation in §4 Phase 3. Phase 0 measures how many gaps rule 4 would convert, by provider.

**Pass-through guard.** A vessel can cross a harbour polygon only because the polygon is in its way, without calling
there. Today any run of polygon-tagged pings is a harbour run, so a transit is a (short, usually bridged) harbour
run; the bridging by `MIN_HARBOUR_H` is what has kept transits from becoming voyage boundaries, and it is the same
rule that swallows real stays. Once dwell is measured in elapsed time that protection is gone, so the rule needs an
explicit guard, and it matters twice: for **where a voyage is cut**, and for **which harbour is its departure
(`hid1`) and arrival (`hid2`)**. A transit must neither cut a voyage nor be named as its arrival harbour. A
polygon-tagged run is a *transit*, not a stay, when none of the stronger evidence holds (no `I`…`U` pair, no
following gap that ends at the same harbour) **and** the vessel does not slow: **(assumed)** median speed over the
run above a threshold `S_t` (a few knots) and a short span. `hid1`/`hid2` are then the harbours of the stays
either side of the sea run, never of a transit. A stay that follows a transit at the same harbour on the way out
(a vessel that slows to a stop at the quay) is still a stay.

### 3.1 An event table, not a rewrite of the pings
`curated/ais/stk_event` (one row per STK `I`/`U` ping): `vid, time, io, hid, lon, lat` as recorded, plus tags
that **add** columns and never overwrite (AGENTS rule). Candidate tags:

| column | meaning |
|---|---|
| `hid_pid` | standard harbour key, see §3.2 |
| `io_pos` | `own` / `other_harbour` / `outside` — event position against the polygon of its `hid_pid` |
| `io_dup` | `I` after `I`, or `U` after `U`, for the vessel |
| `io_short` | `I` then `U` at the same harbour in under a minute |
| `io_jump` | inconsistent with its *cleaned-track* neighbours, §3.3 |
| `io_ok` | none of the above |

`U` cannot use the polygon test (66 % of `U` are outside every polygon). **(assumed)** its position test is the
distance to the harbour's `I`-cluster centre.

### 3.2 Standard names on the polygon data
Add to the polygon data the **standard name** produced by `reference/ports/ports_all.R` (the consolidated harbour
table, the former `kaenugardr`): `pid` and `port` from `staging/ports/ports_all.gpkg`. This is the key the logbook
and landings already join on (`harbour_codes.R`), so STK events join to it too. The raw STK alpha code `hid`
(`AST`, `OFS`, `THO`, ...) is a different namespace from the logbook's numeric `hid`; a reviewed crosswalk
`overrides/stk_hid_pid.csv` maps one to the other, seeded from the bootstrap recode table and from the geometry
(which `hid` lands in which polygon), then human-confirmed. A cycle is broken by a human, as the rules say.
The collisions in §2 (`A`, `R`, `THH`/`THO`, `STM`/`STY`/`STK`) are decided there, not in code.

### 3.3 Judging an event against robust anchors
The implied-speed test above is wrong in principle: if the point measured *from* is the erroneous one, the next
point is blamed. `ping_clean.R` already avoids this for pings with a second pass against the last **retained**
ping (`whack_forward`, in `ramb`). Events are pings, so:

1. Run the checks on the **cleaned** track: for each event, the nearest retained non-event ping before and after.
2. Compute the implied speed to each. An event is `io_jump` only when it is inconsistent with **both**
   neighbours *and* the two neighbours are consistent with each other. If the neighbours disagree, the fault is
   theirs and the event is not blamed.
3. Reuse `ramb`'s functions; do not copy them (AGENTS rule).

This also needs the lost-`I` question answered first: if `ping_clean` drops 6–32 % of the `I` events, the cleaned
track is missing exactly the events the stays are built from.

### 3.4 Stays, and the dwell rule
`curated/ais/harbour_stay`: one row per stay, `vid, hid_pid, T_in, T_out, basis`, with `basis` naming which rule of §3.0
produced it (`event_pair`, `tag_then_gap`, `tag_span`, `gap_near_harbour`). An `I` with no `U`, or the reverse, is kept and
marked, not completed by guesswork. `ais_trip.R` then cuts voyages at stays whose duration is `T_out - T_in` (the
elapsed time) and keeps the polygon tag for providers that carry no `io`. `MIN_HARBOUR_H` keeps its job but is
applied to elapsed time.

### 3.5 Where it lives

Nothing is marked in the raw STK table, and nothing in the source adapter. Raw is immutable; a correction adds
columns and never overwrites; corrections live in `curate/`, and an adapter that reads another source stops being an
adapter (AGENTS rules). The existing precedent is `ping_clean`, which keeps `whack`/`whack2` as flag columns
for audit instead of deleting silently.

```
raw/ais/stk/trail                       immutable, as dumped
  -> staging/ais/stk                    adapter: mid -> vid only; io and hid pass through untouched
  -> staging/ais/ping_union             STK + ASTD + astdB + EMODnet in one table
  -> staging/ais/ping_tagged            + pid (polygon)
  -> staging/ais/ping_clean             + whack flags
  -> curated/ais/stk_event      NEW     tags for the I/U events (§3.1); original io/hid kept beside them
  -> curated/ais/harbour_stay   NEW     stays from all evidence (§3.0)
  -> curated/ais/trip, ping             ais_trip.R cuts voyages at stays
  -> link/trip_voyage -> ais_trail()    unchanged
```

- **Why the event tags are not an STK-level step.** The robust test (§3.3) judges an event against its neighbours in
  the *cleaned merged track*, and those neighbours can be ASTD pings where STK is silent. Some checks are STK-internal
  (duplicate `I`, `I`->`U` within a minute) but they need the harbour polygons, a second source; splitting the tags
  across layers would only make them harder to find.
- **The tags are a side table keyed on `(vid, time)`**, not columns on the pings. The pings stay as they are apart from
  the existing whack flags.
- **Non-STK providers get no event tags.** They enter the stay rule only through the polygon tag (rules 2 and 3 of
  §3.0) and the gap rule (rule 4). ASTD pings at a quay are polygon-tagged and form a tagged run, which the existing
  span rule already handles.
- **Which pings can be used.** The tests run on `ping_clean`, so an `I` that the whack filter drops cannot be judged or
  used, even if it was a real harbour entry. Phase 0 (ii) must settle whether `ping_clean` removes real events
  before this layering is final.
- **Target graph.** Stays are built from `ping_clean`; `ais_trip.R` consumes them. No cycle, but `ais_trip.R` and
  everything that reads `curated/ais/ping` gain one upstream edge in `_targets.R`.

### 3.6 Harbour profile and class (a data rule, with human override)

Each standard harbour (`pid`) gets a profile derived from its own data, not one global setting:

| column | from |
|---|---|
| `r_m` | radius: a high quantile (≈ p95) of the observed distance of same-harbour gap ends to the polygon, with a floor and a ceiling |
| `class` | the rule below |
| `min_stay_h` | minimum stay for that class (default 4 h for `landing`) |
| `evidence` | pairs, vessels, shares behind the class, so a reviewer sees why |

**The class rule** is applied to the harbour's `I`→`U` pairs (STK harbours only; §2b). First cut, to be tuned in Phase 2 against the anchors:

- `landing`: at least 25 % of stays reach 4 h.
- `marina`: under 2 % reach 4 h, median stay under 30 min, at least 50 % are fast pass-throughs (1–60 min, both ends above 4 kn).
- `transient`: otherwise.
- `flicker` (to add): median stay a few minutes, almost no fast pass-throughs, nearly all stays under an hour. The `I`/`U` flag flaps on a vessel at rest, so
  the events are unreliable there and the stay must come from the polygon and gap rules instead.

On the 136 STK codes with at least 1,000 pairs the first cut gives 107 `landing` (75 % of pairs), 5 `marina` (1.6 %) and 24 `transient` (24 %). The anchors behave as
expected: Reykjavík, Vestmannaeyjar, Akureyri, Ólafsvík, Dalvík `landing`; the four yacht-harbour codes `marina`; Árskógssandur (`ASS`, `AR`), Hrísey
(`HRI`), `HJA`, `SUD` `transient`. The two largest `transient` codes, `NJA` (218,865 pairs, median stay 4 min, 0 % fast) and `FA` (110,421 pairs, median 1 min),
are not transient but flicker harbours, which is why `flicker` is added.

**Override.** A reviewed override file `overrides/harbour_class.csv` (`pid`, `class`, optionally `r_m`, `min_stay_h`, `reason`) re-enters as an *input*, never as a
computed output (AGENTS rule on cycles). The data rule runs first; an override wins, and the profile records which rows were overridden.

**Foreign harbours — later, and by a data rule, not a hand-kept list.** STK has no harbours on the European mainland or Greenland, so there are no events to profile there.
When this is taken up the profile must come from the vessel data alone (where vessels repeatedly fall silent or stop, matched to the other `ports_all` sources
for a name and a polygon), so that a harbour nobody has listed is still found. Deferred; nothing in Phases 0–3 depends on it, but the rule is then
Iceland/Faroe only.

## 4. Phases

0. **Measurement — done 2026-10-01, see §2a.** Originally: (i) For every provider, how many gaps of at least `G` hours have both bounding pings
   within `r` km of the same harbour (rule 4), and how many voyages that would split, per vessel-year; (ii) where the
   5.7–31.7 % of `I` events are lost; (iii) the `A` polygon-to-tag gap; (iv) whether vids 2765/2438/239 are shared
   identifiers; (v) **transits:** among polygon-tagged runs, how many have no `I`/`U` event and a median speed above a
   few knots, how often they sit between two stays of the same vessel on a straight course, and how many voyages' `hid1`/`hid2`
   currently name a harbour that is only a transit. Read-only.
1. **Crosswalk** `overrides/stk_hid_pid.csv` and the standard name on the polygons (§3.2). Maintainer review.
2. **Event table** with tags (§3.1, §3.3). Report the share of each tag by year before anything consumes it.
3. **Stays** from the general rule first (§3.0), the STK event pairs added as the strongest evidence once they are
   tagged (§3.1–§3.3). Checked against the logbook: for 2008+ `afli` trips (≈ 99 % link to a voyage today, plan 010
   correction) the number of stays per vessel-year should be close to the number of logbook landings.
4. **`ais_trip.R`** uses the stays. Rebuild `ais/trip`, `ais/ping`, `link/trip_voyage`. Expensive and wide: a
   decision record before it runs.
5. **Voyage-only `.tid`** in `ais_trail()` as a separate column `.tid_voyage` (plan 010 §3.3), so `.tid` stays
   station evidence.

## 4a. Phase 1 built (2026-10-01): the `hid` → `pid` seed crosswalk

`reference/ports/stk_hid_pid.R` → `curated/reference/stk_hid_pid.parquet` (target `stk_hid_pid`, 15 s), one row per STK code (245), with `pid`, standard `port`, the
logbook's numeric `hid_logbook`, `status`, `basis`, and the evidence (events, share in the modal polygon, second candidate, share outside every polygon). The seed is the
data rule of §3.2: the polygon holding most of a code's `I` events. A reviewed decision enters through `overrides/stk_hid_pid.csv` (`hid`, `pid`, `reviewed_date`, `reason`;
`pid = NONE` means "this code names no harbour"), currently empty, and wins over the seed (`basis = recorded`, `status = override`).

| status | codes | `I` events | meaning |
|---|---|---|---|
| `auto` | 178 | 88.9 % | ≥ 90 % in one polygon (counting events within 1.5 km of it, for an anchored code) and no far second candidate |
| `collision` → `override` | 2 | 2.0 % | a second polygon holds ≥ 5 % of the events and lies ≥ 5 km away: `THH`, `THO` (386 km apart: Þorlákshöfn and Þórshöfn). **Confirmed `BY_POSITION` by the maintainer, 2026-10-01** (`resolve = "position"`); the table now shows them as `override` |
| `review` | 2 | 0.1 % | `BAK`, `HVF`: 62 % / 72 % inside, the rest 1.5–5 km away |
| `unmatched` | 29 | 5.7 % | more than half outside every polygon |
| `bootstrap_excluded` | 13 | 3.2 % | codes the bootstrap dropped on purpose (yacht harbours, `R`, ...) |
| `low_n` | 10 | 0.0 % | under 50 `I` events |
| `no_I_events` | 11 | — | appear on `U` events only |

**Two refinements after the first review (same day).** (1) *Tolerance:* an event outside every polygon but within 1.5 km of its code's modal polygon counts toward it, but only for a code
already *anchored* (≥ 50 % of its events inside that polygon); an unanchored code (`A`, `STY`, `KEF`, ...) keeps its misses, so the rule cannot silently merge a harbour that has no
polygon into its nearest neighbour. This moved `STM` (25 % of its events were within 1.5 km), `FO-LOP` and `KDN` to `auto`. (2) *Collision:* detected by data (two far-apart polygons), and an
override value `BY_POSITION` records the decision that the code cannot resolve a harbour (`pid` empty, `resolve = "position"`: take the pid from the event's own polygon). The `THH`/`THO` rows are live in
`overrides/stk_hid_pid.csv`; `BAK` → `IS-BAK` and `HVF` → `IS-HVR` were accepted as drafted by the maintainer on 2026-10-01 (the 38 % / 28 % of their events 1.5–5 km outside the polygon remain unverified, and the reason text says so); both are live in the same file. `STY` was left `unmatched` by the rule (31 % inside `IS-STI`, so not anchored, the other 69 % being 0.5–1.5 km away at a second berth), though it is at the same place as `STM`; the maintainer
added the row `STY` → `IS-STI` on 2026-10-01 (live in `overrides/stk_hid_pid.csv`). Whether `STY` follows `STM` in time was not checked.

The `auto` codes reach about 124 distinct `pid`; many of those `pid` are reached by more than one code (the aliases: `OLV`/`OFS`, `DAL`/`DL`, `ASS`/`AR`, `NJA`/`NJ`, ...). The collisions
known from §2 are caught: `THO`/`THH` are `collision`; `A` (74 % outside) and `STY` (69 % outside) are `unmatched`.

**The `unmatched` group is mostly missing polygons, not bad codes.** 25 of the 29 have no polygon at all in the Iceland/Faroe (`einar`) set: 196,850 `I` events. Nearest-feature
checks put them at real harbours that were merged into a neighbour or dropped: `KEF`/`KF` (1.1–1.2 km from Njarðvík), `HEL` (3.6 km), `KOV`/`KV` (4 km from Reykjavík), `STV`
(3.4 km from Hafnarfjörður), `MJH` (4.5 km from Reyðarfjörður), `KRS` (0.6 km from Akureyri), `SNF` (0.3 km from Reykjavík); `HOL` and `HK` lie on a `gisco` feature
(`IS-HVK`), so a polygon of another source exists for them. Which of these should become their own standard harbour is for the maintainer; the names above are my reading of the codes
and are unconfirmed.

**For review (needs: maintainer):** the 29 `unmatched` rows, and whether the `bootstrap_excluded` codes (notably the yacht harbours) get a `pid` or `NONE`.
Standard name on the polygon data is done in the sense that every resolved row carries `pid` and `port` from `ports.fgb`; polygons for the unmatched harbours are not created.

## 4b. Direction set on 2026-10-01: harbour polygons first, in their own session

New Icelandic harbour polygons (§4a: about 25 `unmatched` codes, about 197,000 `I` events, with no polygon) are to be made **within the original bootstrap script**, not as a separate
correction. The maintainer's reasoning, which supersedes the objection I raised: the bootstrap's input was absent only in the sense of its path (`data-raw/ais/stk/stk_trail`); the raw STK
trail is in this project (`$FISHYDATA/raw/ais/stk/trail`), it is the same source, and nothing about the source has changed except that there is more of it. I ran the script's `ports`
block against the raw trail on 2026-10-01 (read-only, in a scratch session): it rebuilds in 4 s to 162 polygons.

What a re-run changes, so the next session decides it knowingly, not by accident:
- 57 of the 157 existing hulls grow (none shrink): more years of `I` points. Share of events inside a polygon moves 97.5 % → 98.6 % (`I`) and 34.5 % → 35.2 % (`U`).
- 5 polygons appear (`ANV`, `HOL`, `STO`, `TMY`, `VIS`), 2 committed ones are absent (`IS-HLS`, `IS-HDL`, deliberately dropped 2026-09-21).
- The script cannot run as committed: its `ports_add` block uses `.lat` after `st_as_sf` has consumed it; it also reads the old input path; the 2026-09-21 latitude-corrected buffer is
  in the correction, not the producer.
- Any polygon change alters `pid` tagging of the pings and cascades through `ping_tagged`, `ping_clean`, `ais/trip`, `ping`, `trip_voyage` and the trail. It should be batched with Phase 4 so
  the chain is rebuilt once.

**Sequence agreed:** (1) close this session; (2) a **harbour/port session** that takes the "native" (STK-derived Iceland/Faroe) harbours and the global ones (`ports_all`) in one pass, with the
standard name and `pid` issued once; (3) return to the **voyage session** (Phases 2–5 of this plan). Phase 2 depends on the new polygon set, so it waits for (2).

## 4c. Harbour/port session closed (2026-10-01)

Done and recorded in `decisions/058-promote-the-harbour-rebuild.md`: the bootstrap was repaired and re-run from the full trail and promoted to `raw/ports/ports_iceland_faroe.gpkg` (159
polygons; the first bootstrap is in `raw/ports/archive/`); `IS-ANV` Álfsnes and `IS-HRN` Hornvík added; `IS-HVK` is Hólmavík and `IS-STK` Stokkseyri; `ports_all.R` never merges two `einar`
harbours (Kópavogur, Viðey, Gufunes, Álfsnes were all `IS-REY`). `stk_hid_pid`: `unmatched` 28 → 3 (`VIS`, `MAN`, `TMY`), 9 overrides (`THH`/`THO` by position; `BAK`, `HVF`, `STY`, `VID`, `A`
accepted; `LH`, `TRAD` `NONE`). Hornvík's raw STK code is `HVK`, not Hólmavík. The class per harbour and period is TODO 33. The AIS chain still uses the previous polygons (25 outdated
targets) and is rebuilt once, after Phase 3.

## 5. Decisions

**Settled 2026-10-01 (maintainer):** the harbour class is assigned by the data rule of §3.6 and the maintainer overrides it by file; foreign harbours are deferred, and
when taken up are a data rule, not manual curation.

**needs: maintainer** — (a) the tags live in a curated check table (recommended) or in `sources/stk` staging;
(b) the reviewed `hid → pid` crosswalk for the collisions in §2 and the yacht-harbour codes and the three missing polygons (Kristnes, the second Stykkishólmur berth labelled Stokkseyri, Viðey);
(c) `U` position test by distance to the `I` cluster, or no `U` test (distance of `U` events not yet measured); (d) `.tid_voyage` as a separate column;
(e) ~~whether the polygons are not rebuilt~~ — superseded: they are rebuilt in the harbour/port session, §4b; (f) the class thresholds and the transit test (1–60 min `I`→`U`, both ends above 4 kn),
which Phase 2 tunes on the anchors of §3.6.

## 6. What would say it worked

- Voyages shared by more than one logbook trip fall from ≈ 23 % (`afli`) and 19 % (`fs_afladagbok`) to a
  small, explained residue; no voyage spans more than a few days without a stay.
- vid 2481, 2011 has ≈ 185 stays and ≈ 185 voyages, not one voyage.
- `hid1`/`hid2` of a voyage name a harbour where the vessel stopped: for 2008+ `afli` trips the arrival harbour agrees with the
  logbook landing port in a share to be stated after Phase 3, and no voyage is named after a pure transit.
- Every tag has a count by year, and `io_ok` is the majority of events in every year.
- `check_bookkeeping()` clean.

**Two separate defects, both handled in Phase 2 (not yet built).** The crosswalk only answers "which harbour does this *code* name?" and marks `THH`/`THO` as unable to say. (1) *Code against position:* the event
tag `io_pos` (`own` / `other_harbour` / `outside`) compares each event's position with the harbour its code resolves to, so a wrong id given the position is tagged per event, for every code and not only `THH`/`THO`.
(2) *Erratic jumps between harbours:* the event tag `io_jump` judges an event against the cleaned-track neighbours on both sides (§3.3), not against the previous event. The two are independent and are
tagged separately.

