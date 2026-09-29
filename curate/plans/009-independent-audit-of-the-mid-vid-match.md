# 009 — An independent audit of the mid→vid match, from every witness that does not read the key

**status:** partly executed 2026-09-29 — W1, W2, W3, W6, W8 done, W7 as stratifier only, W8 tested (triage only), 2016-06 sweep open; results in `curate/decisions/047-independent-audit-of-the-mid-vid-match.md` · **see:** plans `003`, `008`;
decisions 021, 044, 045, 046; `TODO.md` item 17

*Plan drafted with Claude (AI-assisted); the maintainer set the scope and lifted the
decision rules for the exploration.*

**Measured** (2026-09-29, against `$FISHYDATA`): STK trail 2007–2026 keyed by `mid`;
other-provider pings (`astd` from 2013, `astdB` from 2014, `emodnet` 2017 only) in
`curated/ais/ping`, keyed by `vid` through MMSI; logbook stations 2007–2026 (7.2 M rows
overall) carry a **date only** (hour is always 0); landings 2.17 M rows with `vid`,
`date`, `hid`; the manual ODS has 508 rows; the machine has 25.8 GB RAM, 14 cores.

**Assumed** — the whole method below: that a co-located ping is a strong witness, that
a logbook position is a usable one, that in-harbour coincidence carries any signal. Each
is tested in §3 *before* it is allowed to judge anything.

## 1. The question, and why the earlier checks do not answer it

The key says: mobile-id `M`, over `[d1,d2]`, *is* vessel `V`. Every check so far
(014, 020, 021, 044, 045, 046) asks whether that claim is **consistent with the
registry** (lifetimes, call sign, MMSI) — the same registry the cascade built the key
from — or looks for the claim's failure only where a landing is missing. They cannot
find an error the registry itself shares, and they look at whole mid windows, not at
what the mid did in a given year.

This plan asks the other question: **does the physical behaviour of `M` match the
independent record of what `V` did?** A vessel's transponder sends positions; a vessel's
logbook and landing records say where and when it was. Three witnesses read neither the
key nor the cascade:

| # | witness | says | covers | reads the key? |
|---|---|---|---|---|
| W1 | **co-location** — other-provider AIS (`astd`/`astdB`/`emodnet`), keyed by MMSI→vid | "vid `V`'s transponder was at (t, x, y)" | 2013→, vessels the providers hear | no; depends on registry MMSI |
| W2 | **logbook stations** | "vid `V` fished at (x, y) on day d" | fishing vessels, 2007→; date only | no |
| W3 | **landings** | "vid `V` landed at harbour h on day d" | fishing vessels with agf/lods | no |
| W6 | **mid-clock** — `mid` is a sequential number issued when a new (`loid`,`glid`) pair is first seen (maintainer, 2026-09-29) | when the mid was *created*, independent of any ping | all mids | no |
| W7 | **usage class** (`mclass`, and Hreidar's `Notkunarteg`) | what kind of vessel the register says it is | all | no — a prior and a coverage stratifier: logbook/landing witnesses exist only for fishing classes (33, 35, 36, 37, 64, 68); class can change over a hull's life |
| W8 | **behaviour change-points** in a mid's own STK series (speed, reporting interval, footprint), esp. across a hiatus | a takeover often leaves a silent gap and a different behaviour profile | all mids | no; needs a seasonal null (some vessels are seasonal) and a class-change null |
| W4 | **registry** | lifetime, call sign, MMSI | all | it *is* the cascade's input — used only as a prior, never as a witness |
| W5 | **manual ODS** | a person's mid→vid | 508 rows | it is *part of* the key — audited, not trusted |

W1 is the strongest: two independent receivers hearing one transponder agree to metres.
W2 and W3 are weak per observation and become strong only in aggregate, so they are
scored by **rate against a null**, not as yes/no.

## 2. The stance: what is suspended, and what is not

Lifted for exploration, per the maintainer: the "decision rules" — the
`ais_key.R` cascade order, the tier boundaries, the assumption that a `vid_vid` row is
right because two fields agree, and that a `manuals` row is right because a person
wrote it. Every one of them is a *hypothesis under test* here, and the record of which
were relaxed is in the result.

**Not** lifted: nothing is written into `curated/`; nothing is reassigned; a conclusion
is a *proposal* that re-enters only through `overrides/` (`AGENTS.md`, cycles broken by
a human). Scratch scripts and outputs go in the session scratchpad; only what survives
review is promoted into `curate/checks/`.

## 3. Method

### 3.0 Unit of analysis: the mid-year, not the mid

The key holds one vid per period row, and the reused-call-sign defect shows a mid can
belong to two hulls inside one row. All witnesses are therefore tallied per
**(mid, year, candidate vid)**. A mid whose evidence changes vid between years is the
finding.

### 3.0b The mid-clock, and real activity spans (added 2026-09-29, from the maintainer)

`mid` is issued sequentially the first time a new identifier pair is seen, so its number
is a clock: measured, Spearman(mid, first ping) = **0.992** over 31,777 mids. Three uses:

1. **A mid's lifetime is its real first/last ping, not the key's `d1`/`d2`** (`d2` is a
   sentinel on 31,791 of 31,859 rows). Every earlier overlap test used the sentinels. The
   "one vid, two mobile-ids open" question is re-asked on real spans.
2. **Anachronism:** pings *earlier* than the mid's own creation date (mid-clock) mean
   back-filled history or wrong timestamps; a mid created long *before* its first ping is
   dormant hardware. Both are places to look for a mid whose first era belongs to someone
   else.
3. **Mechanism:** a new mid appears when the identifier strings change, so a vessel that
   changes name/call sign gets a *new* mid, while a vessel that *replaces* another under
   the same strings keeps the old mid. That is exactly the reused-call-sign failure, and
   it says where the errors can be: reuse lives in **old, long-lived mids**, not in
   recently created ones. The sweep of 2016-06 (mids 122xxx–123xxx, ~1,800 mids in a
   week) is a bulk re-issue and needs its own look.

### 3.0c Behaviour change-points (W8; maintainer, 2026-09-29)

A takeover of a mid by another vessel may leave a hiatus and a different speed / reporting /
footprint profile afterwards. Two traps the maintainer named, both built into the test as
nulls rather than caveats: **seasonality** (a seasonal fisher differs between quarters
without any takeover — so a profile change is compared with the same calendar window in
adjacent years, and only the excess counts) and **class change** (a hull can be
re-registered to another usage class — so `mclass` history is read first and a change that
coincides with a registry class change is not a takeover signal). Calibrated on the
takeovers W1 has already confirmed (TFPH, TFBR, TFHW, TFBK, …): if a change-point test
does not fire at those, it is not used.

### 3.1 Calibrate each witness before using it (the step earlier checks skipped)

A witness that is wrong 30 % of the time produces 30 % false alarms and, worse, a
sense of rigour. So each witness is first run on rows where the key is *most* likely
right and on a null:

- **Positive control:** tier A `vid_vid` rows (`loid` and `glid` each independently
  state the vid, 1,842 rows). The witness should confirm nearly all of them; the rate it
  does is its **sensitivity**, and the misses are inspected by hand (they are either
  witness blind spots — no logbook, no other-provider coverage — or real key errors).
- **Negative control:** re-pair each mid with a *different* vid drawn from the same
  year and fleet segment. The confirm rate is the **false-positive rate**.
- A witness enters the synthesis only if the gap between the two is wide, and its
  threshold is set from these two numbers, not chosen.

### 3.2 W1 — co-location

Moving pings only (speed ≥ 2 kn): in harbour, many vessels sit within metres of each
other for hours and coincidence proves nothing. STK ping `(M, t, x, y)` is a **hit for
V** if a `V` ping from another provider lies within ±30 min and ≤ 2 km. Blocked on
hour × 0.25° cell, exact distance after; year by year to bound memory. Per
`(M, year, V)`: hits, STK moving pings, and V's other-provider pings. Score =
hits / min(STK pings, V pings) — normalised by the smaller side so a sparse receiver is
not punished. Then rank all V for each `(M, year)`.

### 3.3 W2 — logbook stations

A station `(V, d, x, y)` is a hit for `M` if any moving STK ping of `M` on that UTC
day lies within 10 km. Logbook coordinates are the noisiest input (`corrections/
afli_coords.yml`, positive-longitude endemic), so: use `-lon` when the recorded point
falls on land, drop `coord_flag` stations, and run it also with the wide 25 km ring as a
sensitivity test. Per `(M, year, V)`: stations, hits, hit rate; **null** = the same
stations against all other mids active that day (fishing grounds are crowded, so a
raw rate is meaningless without it).

### 3.4 W3 — landings

Landing `(V, d, h)` is a hit for `M` if `M` has a ping in harbour `h` on `d±1`. The
weakest witness; used only as a tie-breaker between candidates W1/W2 already
rank, and never alone.

### 3.5 Synthesis: a verdict per mid-year

For each `(M, year)` with key vid `K`, using only witnesses that *cover* it:

- **confirmed** — `K` is the top candidate in ≥ 1 calibrated witness and no witness
  prefers another vid;
- **refuted** — a calibrated witness ranks another vid `V*` clearly above `K`, or
  covers `K` heavily and finds none (coverage is measured by `K`'s own pings/stations);
- **conflicted** — two witnesses point to different vids;
- **uncovered** — no witness has data. **This is not a pass**: it is reported as its
  own class with its ping count, so silence is never counted as agreement.

Alongside, the **recall direction**: for each vid with strong witness evidence, which
mid(s) are best for it, and is that mid keyed to it. This is what finds vessels the key
gave no mid at all.

### 3.6 Audit of the human-made rows

The ODS's 508 rows, and every `step == "manuals"` row, are scored by the same synthesis,
reported apart from the cascade rows. Result to state: how often the human row agrees
with the witnesses, and whether the disagreements cluster (a reviewer's habit) or are
scattered (typos).

## 4. What could make this wrong

- **W1's vid labels come from registry MMSI.** A wrong MMSI in the registry corrupts
  the *witness*, not the key. Guard: a mid–vid pair confirmed by W1 *and* W2 is
  robust to it; a pair that only W1 refutes is checked against the MMSI window.
- **Providers may relay STK.** If an "independent" provider's positions are STK's, W1
  is circular. Guard: measure the fraction of hits at *exactly* the same timestamp and
  coordinate to the 5th decimal; if it is high, W1 is discounted and reported so.
- **Timestamps.** STK and other providers must be compared in one time base; the
  distribution of nearest-in-time offsets among confirmed pairs is inspected before any
  threshold is fixed.
- **Multiple-testing on a large table.** ~3,000 mids × 15 years is ~45,000 cells; a 1 %
  false-alarm rate is 450 spurious refutations. Hence the null in §3.1 and reporting
  rates with the calibration next to them.
- **The 2007–2012 blind spot.** Before 2013 there is no other-provider AIS, so W1
  cannot cover the years when the STK trail is denser than later. Those years are
  W2/W3 only and are reported as such.

## 5. Order of work, and stop conditions

1. Load, count, and characterise the three sources (offsets, coverage per year).
2. Build W1, calibrate on tier A and the null; build W6 (cheap, no calibration needed beyond its own monotone fit). **Stop and report if W1's sensitivity on
   tier A is below ~90 %, or if it is circular.**
3. Build W2, calibrate the same way.
4. W3 as tie-breaker.
5. Synthesis, recall direction, ODS audit.
6. Decision record with counts; proposed overrides as a CSV *proposal*, not entered.

## 6. Output

A decision record (`047`) stating what was measured and what was found, with the
calibration numbers first. A proposal CSV in the scratchpad and named in the record.
No change to the key, to `overrides/`, or to `curated/`.
