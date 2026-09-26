# 003 — STK vessel identity: from a match script to an identity model

**status:** partly built — **steps 1–7 and 9 done, 2026-09-26**; step 8 open ·
**see:** `TODO.md` item 17, `curate/decisions/012-stk-entity-class.md`,
`curate/decisions/013-stk-derived-ids-are-equipment.md`,
`curate/decisions/014-stk-vid-assignment-checks.md`,
`curate/decisions/015-identity-is-separate-from-the-key.md`,
`curate/decisions/021-cascade-matches-on-evidence.md`,
`reference/vessels/ais_key.R`, `R/vid_match.R`, plan `002-the-last-mile.md` §4a

**Measured** — on 2026-09-22, against `$FISHYDATA` as it stands:

- every number in §2 and §3, from `raw/ais/stk/trail` (289,986,540 pings, 31,791
  mobile-ids), `raw/ais/stk/mobile.parquet`, `curated/vessel/vessel_ais_key.parquet`,
  `curated/vessel/vessel.parquet`, `raw/landings/agf/aflagrunnur.parquet` and
  `staging/ais/astd`;
- coverage recomputed at mid-**day** grain and joined exactly the way
  `sources/stk/convert.R:21` joins, so the percentages are what the pipeline actually
  sees, not what the key's own `pings` column implies;
- the ASTD identity table (§4.5) was built in a scratchpad to size it, then discarded.
  Nothing was written under `$FISHYDATA`.

**Assumed** — the whole of §4 and §5: the column names, the tier boundaries, the order
of work, and the judgement that an evidence-closed `d2` is safe downstream. None of it
has been built or tried.

**Corrects `TODO.md` item 17**, whose baseline was measured a different way. Four of
its numbers do not survive re-measurement; §2 says which and why.

---

## 1. What the key is, and the one sentence that explains its shape

`reference/vessels/ais_key.R` is 669 lines that turn `(mid, loid, glid)` into
`(mid, d1, d2) → vid`. It is the gate every STK ping passes to acquire an identity:
`sources/stk/convert.R:21` and `curate/ais_ping_union.R:25` both join through it with
`between(time, d1, d2)`, and `convert.R:28` then drops `is.na(vid)`.

The shape it has is explained by the problem, which the maintainer states plainly:

> The mobileid is just some sequential number that gets automatically generated —
> think when a new localid/globalid is encountered. The localid and globalid are a
> mixed bag. The problem is that mobileid is not unique to a vessel.

So there is no identifier in STK to join on. There are two free-text fields that
*sometimes* contain a vid, sometimes a call sign, sometimes an MMSI, sometimes a
harbour name, and sometimes the literal string `unkown`. The script's answer is a
cascade: classify both fields into a `type` (e.g. `vid_cs`), then apply one rule per
type in a fixed order, each rule filling `vid` only where it is still `NA`.

**That cascade is the right idea and should be kept.** What follows is not a proposal
to replace it. It is a proposal to give it an identity model, an entity class, a
closed time window and a cross-check — four things it does not have, each of which is
currently costing something measurable.

### The identity fact the model has to encode

The maintainer's second statement is the one the design turns on:

> The Icelandic vessel registration number (vid) is assigned to the keel of the
> vessel. A vessel may change name, call sign, local sign — but the vid stays with
> the vessel from cradle to grave. Sort of like the IMO number.

`vid` is therefore the **stable identity**, and `mmsi`, `cs`, `uid` and `vessel` are
**time-varying attributes of a vid**. The registry already half-says this: 2,554 of
its 7,043 rows carry `mmsi` with an `mmsi_t1`/`mmsi_t2` window and a `zombie_no`, and
21 MMSIs are genuinely reused across two vids in sequence (vid 2450 → 7839 on
251146240; vid 1337 → 3000 on 251158000; …).

The key throws that away. `ais_key.R:650` joins `v_mmsi_no_dupes` — one arbitrary row
per MMSI, chosen by `arrange(mmsi, desc(mmsi_t2), desc(vid)) |> slice(1)` — so a
vessel that changed MMSI is stamped with one MMSI over its entire history. And the
same collapse in the other direction is what produces the misassignment in §3.1.

**And the keel rule does not hold above 3700.** The maintainer again:

> Numbers between 3700-4999 are actually foreign vessels. Unlike for the Icelandic
> vessels the same vid may cover different vessels, or one vessel may have two
> different vid. Not over the same time period though.

So `vid` is two different kinds of thing in one column, and only the part below 3700
is a keel. Any confidence measure that does not separate them is meaningless. §4.5.

---

## 2. Corrected baseline

| | measured 2026-09-22 |
|---|---|
| pings in `raw/ais/stk/trail` | **289,986,540** |
| distinct `mid` in the trail | 31,791 — and the key has a row for every one |
| key rows / rows carrying a `vid` | 31,859 / 3,144 |
| distinct `vid` assigned | 3,009 |
| **pings that acquire a `vid`** | **180,923,978 = 62.39 %** |
| **pings that acquire an `mmsi`** | **173,247,971 = 59.74 %** |
| pings falling in *no* declared period (silent loss) | 35,683 on 54 mids |
| ping duplication from overlapping periods on one mid | **none — 0 rows** |
| rows with a real `d2` | 68 of 31,859 |
| `mid` mapping to >1 `vid` | 67 |
| `vid` whose two mids have **overlapping** windows | **124**, carrying 12.4 M pings |
| distinct match rules (`step`) | **10**, not 61 |

### Four corrections to item 17

1. **The ping totals there are inflated by 10.9 M.** The key's `pings` column is the
   *mid* total repeated on every period row of that mid, so summing it over 31,859
   rows double-counts the 67 multi-period mids. 300.9 M is not a ping count. Coverage
   is 62.39 %, not 63.8 %.
2. **"61 distinct match rules" counted `step`×`type` pairs.** There are ten rules:
   `vid_vid` (1,864), `manuals` (503), `vid_cs` (359), `vid2_vid2` (162), `NA_vid`
   (100), `NA_mmsi` (94), `vid2_cs` (27), `older` (19), `NA_csts` (14), `uid_cs` (2).
3. **`TF??_NET_` is already classified.** All 107 mids and 8,410,241 pings carry
   `type == "NA_net"` — caught by `str_detect(tolower(glid), "_net")` at `:391`, not
   missed. Item 17 called this "the review's cheapest win"; it does not exist. The
   `fixed` list still needs replacing, but for the reason in §3.3, not this one.
4. **The reassigned-mid worry does not materialise.** Item 17 feared that a mid with
   more than one vid "either duplicates pings or silently attributes them to the wrong
   vessel". Measured: the 67 multi-period mids have **no overlapping periods at all**,
   and the between-join returns 456 *fewer* rows than the input, never more. The
   manual dual entries do this part correctly. The overlap that is real is on the
   **vid** side, which is a different defect — §3.2.

### Where the 109.1 M unassigned pings are

| bucket | mids | pings |
|---|---|---|
| declared non-vessel — `fixed` (shore) | 213 | 56,002,205 |
| declared non-vessel — `net` relay | 287 | 11,790,928 |
| declared non-vessel — MMSI 98x/99x | 2,041 | 6,509,441 |
| declared non-vessel — `kvi` aquaculture | 12 | 3,897,965 |
| declared non-vessel — `hafro` institute | 12 | 2,977,341 |
| **subtotal: already known to be non-vessel** | **2,565** | **81,177,880** |
| `NA_cs4` — glid opens with a valid call-sign prefix, not in the registry | 5,798 | 19,243,886 |
| `NA_NA` — no classification at all | 2,093 | 3,423,232 |
| `NA_mmsi` — glid is a 9-digit MMSI, not Icelandic | 17,751 | 2,792,109 |
| `NA_cs3` — call sign of a *foreign* vid 3700–4999 | 49 | 1,000,818 |
| everything else (17 further types) | ~800 | ~1.6 M |

**74 % of the coverage "gap" is not a gap.** It is knowledge the script already has and
the schema has nowhere to put. That single fact sets the priority order in §5.

---

## 3. Six defects, each measured

### 3.1 A call sign is reused and the key follows the wrong keel — 235,121 pings

`TFBR` belongs to two vids: **1473** (HÓLMBERG, registry `yh2` = 2006) and **3047**
(HILDUR SH777). `mid 101759` has `loid = 1473`, `glid = TFBR`, first ping
**2011-07-22**, and the key assigns it **vid 1473** with MMSI 251176000, step `vid_cs`,
for 2011 → the sentinel.

The landings cross-check the maintainer proposed settles it in one query:

| vid | landings | first | last |
|---|---|---|---|
| 1473 | **0** | — | — |
| 3047 | **3,770** | 2025-01-11 | 2026-04-14 |

235,121 pings are attributed to a vessel that has never landed a fish in the database,
while the vessel that has landed 3,770 times has **no AIS identity at all**. This is
the error class `_targets.R:123` says is known — and the check it points at does not
exist.

The cause is structural, not a bad row: `CS` and `VID` at `:245–288` are *flat sets*
built with `pull(cs) |> unique()`, so a call sign that moved keel is matched without
reference to when. The fix is in §4.1, and it is the same fix that repairs the
`v_mmsi_no_dupes` collapse.

### 3.2 The sentinel makes 124 vessels exist twice at once

31,791 of 31,859 rows run to the `2028-12-24` sentinel, written unconditionally at
`:659` for the last `no` of every mid. When a vessel changes transponder it acquires a
second mid — and the *old* mid's window is still open. 124 vids therefore have two mids
claiming them simultaneously, across 12,364,676 pings. The largest:

| vid | mid A (to sentinel) | mid B starts | pings on A |
|---|---|---|---|
| 1902 | 101406 from 2007-06-04 | 143788, 2021-09-23 | 430,497 |
| 89 | 101671 from 2007-06-01 | 147513, 2023-07-16 | 393,474 |
| 3002 | 101092 from 2021-05-13 | 141628, **same day** | 386,318 |
| 2426 | 105294 from 2008-07-25 | 105694, 2009-02-06 | 320,707 |

If the old mid really fell silent, this is harmless. If it did not, the vessel has two
simultaneous tracks and trip segmentation is wrong for it. **Which of the two is the
case has never been measured, and it is cheap to measure** — §4.3.

### 3.3 The entity class is a substring of a string

`fixed`, `kvi`, `hafro`, `net`, `unknown` and `mmsi.other` are classifications the
script *makes* and then discards into the `type` string. Nothing downstream can ask
"is this a vessel?"; it can only ask "does `type` contain the word `fixed`". The
`fixed` vector at `:163` is ~200 hand-maintained nine-character Icelandic place names
and it is the only classifier that has ever existed — searched all eight sibling repos.

What it costs is not in the big families (those are caught by rules already). It is in
the schema: 81.2 M pings across 2,565 mids are *known* non-vessel and are
indistinguishable, at the point of use, from 3.4 M pings on 2,093 mids that are simply
unclassified. §4.2.

### 3.4 Three rules the cascade is missing

- **`loid` carries the vid and `glid` does not classify — no rule fires.** The cascade
  has `NA_vid` but no `vid_NA`: 45 mids / 159,913 pings, plus `vid_cs4` 17 mids /
  205,260, `vid2_fixed` 2 mids / 710,309, `vid_fixed` 1 mid / 103,011. The evidence is
  sitting in `loid` and is not read.
- **Icelandic call sign with a suffix.** 42 unmatched mids / 372,247 pings whose `glid`
  is a registry call sign plus a trailing digit or underscore — `TFPO2`, `TFBY2`,
  `TFFY_2`, `TFMS_2`. Several of them *also* carry the vid in `loid` (1395, 2750, 2699,
  1585). Two of these mids alone are 275,140 and 23,051 pings.
- **One-character call-sign prefixes.** `:378` and `:397` test `str_sub(x, 1, 2) %in%
  cs.prefix$cs_prefix`, but 10 of the 711 prefixes are a single character — France,
  the UK, Italy and others. `FMSN`, `GCFW`, `FFZJ`, `ICPE`, `MRUB7`, `NBID` and the
  rest of the `NA_NA` residual are foreign call signs the rule cannot see.

### 3.5 A filter that has never filtered

```r
STK |> group_by(mid, year) |> mutate(n = n()) |> ungroup() |>
  mutate(n = n()) |>            # <- overwrites the per-mid-year count with nrow()
  filter(n >= 10)               # <- therefore always TRUE
```

`ais_key.R:301–305`. The second `mutate` runs on ungrouped data, so `n` becomes the
total row count and the threshold never applies. Confirmed: the trail has 31,791
distinct mids and the key has 31,791. Either restore the intent or delete the lines —
but not silently, because whichever is chosen changes the denominator of every
coverage number above.

### 3.6 Corrupt timestamps set the window

59 mids carry ping times outside 2007-06-01 … 2027, on 16,642,175 pings — 5.74 % of
the trail. They are Unix epoch zeros (`1970-01-01`), a cluster at `1984-08-11
16:27:44`, another at `1997-01-01`, and futures out to `2106-02-06` and `2088`.
Because `d1`/`d2` are `min(time)`/`max(time)`, **the corruption propagates straight
into the join window**: 40 key rows open before STK existed, three of them carrying a
vid — `mid 101121` (vid 155, `TFQL`, 141,276 pings) opens on 1970-01-01.

Most of the affected mids are shore stations, so the damage today is small; 9 carry a
vid. But this is upstream of everything and is declared separately as a correction,
not fixed inside the key.

---

## 4. The design

### 4.1 Split the key in two: identity, then attributes

One table conflates two questions. Replace it with two, joined on `vid`:

**`curated/vessel/vessel_ais_key.parquet`** — *which keel emitted this ping.*

```
mid, period_no, d1, d2, vid, entity_class, rule, tier, loid, glid, pings, basis
```

No `mmsi`. `vid` is the keel and nothing else belongs beside it.

**`curated/vessel/vessel_identity.parquet`** — *what that keel was called, when.*

```
vid, t1, t2, mmsi, cs, uid, vessel, flag, imo, source
```

One row per (vid, attribute period). The registry already carries `mmsi_t1`/`mmsi_t2`
and `zombie_no`; this table is mostly a reshape of it, not new information.

A consumer that wants an MMSI on a ping joins the ping's `time` through *both*
windows. That is the only construction in which §3.1 cannot happen, because `TFBR` in
2011 resolves against HÓLMBERG's attribute window (ends 2006) and fails, instead of
matching a flat set.

**Every lookup set in the cascade becomes time-aware by the same move.** `CS`, `CS2`,
`CS3`, `UID`, `UID2`, `VID`, `VID2` at `:245–288` stop being `pull() |> unique()`
vectors and become joins against `vessel_identity` constrained by the mid's own
`d1`/`d2`. This is the single largest change in the plan and it subsumes §3.1.

### 4.2 Emit a real entity class

A column, not a substring:

`vessel` · `shore_station` · `aquaculture` · `institute` · `navaid` · `beacon` ·
`net_relay` · `unknown`

Derived, in order, from rules that already exist in the script plus `ramb`:

| class | rule | mids | pings |
|---|---|---|---|
| `navaid` / `beacon` / other non-ship | `ramb::rb_mmsi_category(glid)` on the 9-digit glids — 98x child, 99x aid, 970/972/974 SART/MOB/handheld, 111x SAR aircraft | 3,818 | 7.1 M |
| `net_relay` | `_net` in `glid` (already at `:391`) | 287 | 11.8 M |
| `institute` | `Hafro_*`, `Rannsokn_` (already) | 12 | 3.0 M |
| `aquaculture` | `Kvi*`, `Sjokvi*` (already) | 12 | 3.9 M |
| `shore_station` | the `fixed` list, **plus** `*AIS*`/`*_P`/`*_B` station suffixes and `*dufl*`/`*bauja*` | 213 + | 56.0 M + |
| `vessel` | anything that resolved to a vid, or whose `glid` is a vessel-range MMSI | | |
| `unknown` | the residual, which is then the honest number | | |

Two constraints on this, both from `AGENTS.md`. The class carries a **`basis`** —
`recorded` where STK says it (a 99x MMSI *is* a navaid), `reconstructed` where a
pattern says it, `synthesised` where only the hand list says it. And the `fixed` list
does not disappear: it moves to `overrides/` as a reviewed input, because a nine-
character truncated place name is not derivable and a human decided each one.

**`basis` is also what lets the list shrink safely.** Anything a pattern rule can
reach stops being an override; what is left is the genuinely ad-hoc remainder, and it
is visible rather than buried in a 200-element vector.

### 4.3 Close `d2` from evidence — measure first, then decide

The measurement that decides it costs one grouped query, already run once for this
plan: last ping per mid. For each of the 124 vids in §3.2, compare the old mid's last
real ping against the new mid's first.

- If the old mid is silent before the new one starts, close `d2` at the last ping and
  the overlap disappears with no loss. **This is the expected case** and should be
  confirmed, not assumed.
- If they genuinely overlap, that is either a transponder swap with a handover period
  (benign, document it) or a matcher error (§3.1's class, route to `overrides/`).

Keep the sentinel **only** on the currently-live period of each mid, and record it as
an explicit `d2_is_open` boolean rather than a magic date, so downstream can tell "runs
to now" from "ends 2028-12-24". The 2028 date is the maintainer's retirement, which is
a fine joke and a poor schema.

**What breaks downstream if `d2` closes** (item 17's question 2): nothing, for the
between-joins, provided the live period stays open — a closed `d2` can only remove
pings that fall after a mid's own last ping, of which there are none by construction.
The risk is entirely in the *next* STK dump: a mid whose `d2` was closed at its last
2026 ping and which then resumes. `d2_is_open` handles that; a bare closed date does
not.

### 4.4 Rule tiers, and making the `AGENTS.md` claim true

`AGENTS.md` says `vessel_ais_key` "carries confidence". It does not. Either delete the
sentence or earn it. Earning it is cheap, because the rules are already ordered by
reliability — the cascade *is* a confidence ranking, unlabelled:

| tier | rules | rows | what it rests on |
|---|---|---|---|
| A — identifier stated twice, agreeing | `vid_vid`, `vid2_vid2` | 2,026 | `loid == glid` and both parse as a vid |
| B — identifier stated once, corroborated by the registry | `vid_cs`, `uid_cs`, `vid2_cs`, `NA_vid` | 488 | two fields, cross-checked |
| C — human review | `manuals` | 503 | the duals spreadsheet |
| D — single weak field | `NA_csts`, `NA_mmsi` | 108 | one field, no corroboration |
| E — inherited guess | `older` (`pings > 100`, "hail mary" in the script's own comment at `:588`) | 19 | a previous match, threshold-gated |

Tier is a column, not a document. And tier A is not automatically best: `vid_vid` is
what mid 101661 fired on, and that mid's vid is written `-2605` — a negative vid,
which nothing validates.

### 4.5 Foreign vessels: the registry is already on disk

The maintainer asked whether sibling repos hold foreign registries worth moving.
**Checked on local disk: not there.** `fishyweb/scripts/01_DATASET_vessels_combine-
registry.R` consumes `data-raw/vessels/{FRO,NOR,EU,gfw}/…`, and no `data-raw`
directory survives in any repo under `~/stasi`. The *code* is worth porting (plan 002
§4a already assigns it), but it has no inputs here.

**Searched, 2026-09-22: not on the institute share either.** `/Volumes/einarhj` is an
SMB mount of `hfs-lifs01.ad.hafogvatn.is:/heima/einarhj`, 5.4 TB. A depth-3 directory
map of the eight candidate trees under `stasi/` completed: `data-raw/` exists in only
three of them — `fishydata_backup` (one subdirectory, `ad-hoc`), `logbooks`
(`data-dump/`) and `logbooks_2026-02-12` (empty) — and **no `vessels`, `FRO`, `NOR`,
`EU` or `gfw` directory exists in any of them.** A depth-6 filename sweep of
`stasi/fishydata` found scripts only, no data: the consolidator and the Faroese
scraper, both of which `fishyweb` already has, plus Norwegian *ingest* scripts that
are not registries.

Two caveats, both cheap to close and neither closed: the directory map lists
directories, so a loose `vesselRegistryListResults.csv` sitting straight in a
`data-raw/` would not have shown; and a dozen smaller trees under `stasi/` were not
surveyed. Reading the share is slow — one depth-6 sweep of a single repo took eleven
minutes — and it is invisible to the agent session, which runs on
`sjavarafli.hafro.is` while the maintainer works from a second host,
`HAFRO-EINARHJ-2`. Check `hostname` on both sides before arranging for one to write a
file the other reads; three attempts were lost to that.

**Found by the maintainer, 2026-09-22, after the searches above.** The Faroese,
Norwegian, EU and GFW registries exist and are in hand. **Deliberately parked**: the
Icelandic fleet is the priority, and the Icelandic side does not depend on them. Their
location is not recorded here yet — record it before acting on this section, because
the searches above establish only that they are not where the old scripts expect them.

What they unblock, when picked up: the 19.2 M `NA_cs4` pings, which are foreign call
signs with no registry to match against, and the 352 foreign vids in the key that carry
6.3 M pings and no MMSI at all.

Two files the search turned up that are worth more than the registries, and that no
script here reads. At the share root: `stk_mobile_match-and-duals.ods` (the duals
spreadsheet §6 asks to be corrected — the copy in `raw/ais/stk/` may be older) and
`AdditionalMMSI20190327.csv`, whose name reads like the Fiskistofa-side supplement §6
asks for. And in `stasi/fishydata/scripts/`: `00_DATASET_mmsi_icelandic.R` and
`00_DATASET_ISL-mmsi_historical-consolidation_TOBEDELETED.R`, which are the only
Icelandic-MMSI consolidation code found anywhere and bear directly on the 88 vids.

### 4.6 The cross-checks, and where they are allowed to live

`_targets.R:123` promises a vid-assignment check in `curate/checks/`. Write two, both
of which found real defects while this plan was being measured:

**`curate/checks/ais_key_landings.R`** — vessels that landed but have no AIS identity,
and vids assigned in AIS that have never landed. Today: of 2,369 vessels landing since
2007-06, **254 are absent from the key** (14,728 landings, 0.28 %). Most are foreign
(3700–4999, landing in Iceland), but the head of the list is not: vid 3047, 3,770
landings in 2025–26, whose call sign *is* in STK and is assigned to someone else
(§3.1). Vid 2605 (382 landings) and vid 1599 (340) were named here as "likewise" -
**measured 2026-09-23, and only half true.** 2605's call sign TFOE is genuinely in
STK, but it is a two-real-vessel case (also covers vid 2640, 12,845 landings, same
years) - not decidable without the maintainer. 1599 is NOT a call-sign-reuse case at
all: no STK mobile id, ever, broadcasts its local sign BA021. It is a genuine "never
transmitted to STK" vessel, not a wrong match. See `curate/checks/ais_key_reused_callsign.R`,
written to answer this precisely (from raw/ais/stk/, not off the finished key), and
`curate/corrections/ais_key_callsign_reuse.yml`'s scope section for the full,
categorised count: 30 domestic vessels total, of which only 12 are as clean a case as
3047.

**`curate/checks/ais_key_registry.R`** — the tier-A invariants, which are assertions
the script currently prints as `knitr::kable(caption = "Expect none")` into a console
nobody reads: no negative vid; no vid outside the registry; no assignment whose
`d1` precedes the vessel's `yh1` or follows its `yh2`; no vid with two open mids.

**Both are checks, not corrections.** They emit `curated/check/` tables. Anything they
conclude by reasoning from logbooks or landings back onto the vid assignment closes the
cycle `AGENTS.md` warns about, and re-enters only through `overrides/` after a human
has looked at it.

### 4.7 What "assign every vessel mobileid an MMSI" actually requires

The maintainer's stated goal, decomposed against the measurements:

| population | mids | pings | route | reachable? |
|---|---|---|---|---|
| assigned a vid, vid has a registry MMSI | | 173.2 M | already done | ✅ |
| assigned a vid < 3700, no registry MMSI (88 vids) | | 3.7 M | Fiskistofa / Fjarskiptastofa lookup | maintainer |
| assigned a foreign vid 3700–4999 (352 vids) | 352 | 6.3 M | ASTD name match → `overrides/` | partial, §4.5 |
| `glid` **is** a vessel MMSI | 16,040 | 2.3 M | read it — 66.8 % also nameable from ASTD | ✅ trivially |
| `NA_cs4` — foreign call sign, no registry | 5,798 | 19.2 M | needs FRO/NOR/EU registries | **blocked**, §6 |
| `NA_NA` residual after §3.4's three rules | ~440 | ~0.4 M | case by case | tail |
| non-vessel (5 classes) | 2,565 | 81.2 M | **not a target** — class them and stop | ✅ |

The honest summary: **an MMSI for every *Icelandic* vessel is within reach** and is
mostly a matter of §4.1 plus 88 lookups. An MMSI for every *foreign* mid is not, and
the binding constraint is the three missing national registries, not the matcher.

---

## 5. Order of work

Ordered by measured payoff per unit of risk, not by interest.

1. ~~**Declare the two corrections**~~ — **done 2026-09-22**.
   `stk_trail_time_outliers`, `ais_key_callsign_reuse`.
2. ~~**`entity_class` + `basis`** (§4.2)~~ — **done 2026-09-22**, recorded in
   `curate/decisions/012-stk-entity-class.md`. Gated: all fourteen pre-existing
   columns identical row for row, two columns added. 82.3 M of the 109.0 M unassigned
   pings are now declared non-vessel and 23.7 M are vessels that did not match, so
   the honest residual is **2,996,632 pings — 1.03 %** on 2,098 mobile-ids. Eleven
   classes rather than the eight proposed in §4.2, and a call-sign rule that was not
   proposed at all; the decision record says why.
3. ~~**The three missing rules** (§3.4)~~ — **done 2026-09-22**,
   `curate/decisions/013-stk-derived-ids-are-equipment.md`. One of the three was
   wrong and one was harmful, which is why this is worth reading rather than
   skimming.

   **§3.4's second rule was backwards.** The `TF???2` family is not "Icelandic
   fishing vessels the matcher misses" — it is those vessels' *net buoys*, registered
   under a made-up id derived from the ship's (maintainer, 2026-09-22). Confirmed: of
   78 mobile-ids the drafted rule would have matched, 42 were transmitting while the
   vessel's own mobile-id was also transmitting. It became a classifier instead —
   34 mobile-ids, 118,351 pings, now `entity_class == "buoy"`.

   **§3.4's third rule is harmful and was reverted.** Widening the call-sign prefix
   test to one character assigns no vid and *unmatches four vessels*, because `type`
   is pasted from both fields and the steps match it as a literal: `NA_cs` becomes
   `cs4_cs` and the `NA_cs` step stops firing. The classifier cannot be corrected
   while the rules key on its output — which is a stronger argument for step 5 than
   anything written below.

   **§3.4's first rule stands**, narrowed to undecorated agreement only: 16 mobile-ids,
   54,326 pings. Plus a rule the plan did not anticipate — `afmáður`, "erased", is how
   STK labels a vessel that has left the Icelandic registry and goes on transmitting;
   GNÚPUR's begins the day after the registry records *Seldur*. 5 of 18 assigned,
   68,721 pings; the rest held back where the vessel's own mobile-id overlaps.

   Gated: no existing vid changed, none lost, no step or mmsi changed. Coverage
   62.39 % → **62.43 %** vid, 59.74 % → **59.77 %** mmsi.
4. ~~**The two checks** (§4.6)~~ — **done 2026-09-22**,
   `curate/decisions/014-stk-vid-assignment-checks.md`. Both are targets depending on
   `vessel_ais_key`, both emit into `curated/check/`, and neither is empty:
   `two_mids_open` 137, `outside_vessel_lifetime` 111, `negative_vid` 15,
   `landed_but_no_ais` 253 (86 of them Icelandic), `ais_but_never_landed` 813.

   A third check was added that the plan did not have, and it is the one that
   measures the maintainer's actual target: **`icelandic_vessel_not_in_ais`, 1,244
   hulls** whose registry lifetime reaches into the STK era and which have no
   mobile-id. Stratified, because 959 of them have no `yh2` and 141 are small-boat
   classes that may carry no transponder — **144 have an MMSI or are 15 m and over,
   and those are the real gap.**

   Also found: the 21 `knitr::kable(caption = "Expect none")` assertions inside
   `ais_key.R` have never been seen by anyone. `source()` does not echo a top-level
   value and `produces()` runs every script through `source()`, so they print into
   nothing. §4.6's claim that "the diagnostics are the valuable part" was right for
   a worse reason than it knew.
5. **Split identity from attributes** (§4.1) — **done 2026-09-23**,
   `curate/decisions/015-identity-is-separate-from-the-key.md` and
   `curate/decisions/021-cascade-matches-on-evidence.md`.

   **Built:** `curated/vessel/vessel_identity.parquet`, 5,169 periods, asserting that
   `(mmsi, time)` resolves to one hull; a `lifetime_conflict` flag on the key; and —
   not in this plan, because the plan had missed the second consumer — the
   commercial-feed joins in `curate/ais_ping_union.R` now resolve through it. Those
   were `distinct(mmsi, vid)` with no time at all, so for each of the 21 reissued
   MMSIs the earlier hull's entire ASTD/ASTDB era was attributed to its successor,
   21 times out of 21.

   **Two things §4.1 got wrong.** `mmsi` must stay on the key — removing it breaks
   `sources/stk/convert.R` and three joins in `ais_ping_union.R` for no gain. And
   the identity window must be the *intersection* of the MMSI window and the hull
   lifetime, not a preference: `mmsi.R:23` writes the MMSI bounds as defaults, so
   preferring them keeps dead hulls matchable, which is how TFBR survived.

   **The guard flags, it does not withdraw**, and that is measured rather than
   cautious: withdrawing the 81 conflicts would have discarded 1.39 M pings from 20
   vessels that were landing fish throughout the window the registry says they did
   not exist in — `curate/corrections/vessel_registry_stale_lifetime.yml`.

   **Finished 2026-09-23** (decision 021): the flat `CS`/`CS2`/`CS3`/`UID`/`UID2`
   lookups and the pasted `type` string are gone. `R/vid_match.R` gives the cascade
   three time-aware operations against `vessel_identity`, and every tier is rebuilt
   on them. Six mobile-ids / 441K pings move to the vid their own window actually
   covers (`TFAJ`, `TFFS`, others); one newly matches (`TFJI`, 275K pings). Two
   large mobile-ids (`TFPH`, `TFUT`) lose a flat-lookup match that happened to be
   right and become visible AIS/landings disagreements instead — a genuine
   residual, not an oversight: a single STK mobile-id carries one `[d1,d2]` span,
   and when the same physical device changes hands without STK splitting the
   period, no amount of identifier-matching on that one row recovers the split.
   `staging/ais/ping_union` remains stale from step 5's first half.
6. ~~**Close `d2`** (§4.3), with `d2_is_open`~~ — **done 2026-09-26**,
   `curate/decisions/032-d2-closed-from-evidence.md`. Measured 123 multi-mid vids,
   172 mobile-id periods: 49 clean handovers closed at their real last ping, 82
   genuine overlaps left open and unresolved (a human call for `overrides/`).
   `ais_key_registry.R`'s `two_mids_open` 137 → 95, no vid assignment changed.
7. ~~**Tier column** (§4.4), then make `AGENTS.md` true or delete the sentence~~
   — **done 2026-09-26**, `curate/decisions/034-tier-column-earns-the-agents-claim.md`.
   A–E from the cascade's own step order, `loid_cs`/`afmadur` placed (they
   postdate this section); no assigned vid goes untiered. `AGENTS.md`'s claim
   is left as written — it is now true.
8. **ASTD identity table** (§4.5), and the foreign-vid candidates into `overrides/`.
9. ~~**Resolve the `n >= 10` filter** (§3.5) deliberately~~ — **done 2026-09-26**,
   `curate/decisions/033-n10-filter-resolved-at-mid-level.md`. Restored, not
   deleted, but at mobile-id lifetime total rather than the original per-year
   grouping — the literal fix orphans 166 MMSI-or-15m+ vids' only AIS trace, the
   lifetime version orphans 0. Key rows 31,862 → 19,234; distinct assigned vid
   3,038 → 2,820; coverage essentially unchanged (62.39% → 62.48% vid).

Steps 1–4 are additive: nothing already assigned changes, so they can land without
rebuilding the AIS trail. Step 5 changes assignments and forces a rebuild of
`staging/stk` downstream — it should land alone.

**One structural note.** `ais_key.R` is an interactive script: `I AM HERE` at `:638`,
five `if(FALSE)` blocks, and 21 `knitr::kable()` diagnostics printed to a console.
That is a reasonable way to have *built* it and a poor way to *run* it as a target. The
diagnostics are the valuable part and should become the checks in §4.6; the cascade
should become functions. But that is a refactor, and it should follow the six changes
above rather than being bundled with them — a rewrite that changes behaviour and shape
at once cannot be reviewed.

---

## 6. For the maintainer

- ~~Three national registries need re-fetching~~ — **the maintainer has them,
  2026-09-22, and parked them deliberately in favour of the Icelandic fleet.** The
  consumers are ready: `fishyweb/scripts/01_DATASET_vessels_combine-registry.R` is the
  consolidator and `00_DATASET_vessel-scrape_FRO.R` the Faroese scraper, both to be
  ported per plan 002 §4a. Where the files now live is not written down; that is the
  one thing to capture before the work resumes.
- **88 Icelandic vids in the key have no MMSI** in the registry, on 3.7 M pings, plus
  the three named in the script header at `:16–19` (mids 114902, 118765, 139879).
  Fiskistofa / Fjarskiptastofa lookup.
- **The ODS date error is confirmed and priced**: `mid 101097` (vid 1328) loses
  **34,307 pings** — 96 % of all silently-dropped pings in the whole key. The header at
  `:20–22` already states the fix (`d1 = 2007-06-01`, `d2 = 2023-09-06`); it has not
  been applied to the spreadsheet.
- **Is `vid = -2605` meaningful?** `mid 101661` carries a negative vid from the duals
  sheet, and `mid 100193` carries `-467`. If negative means "reviewed and rejected",
  that is a fine convention and belongs in the schema as a flag; if it is a typo, two
  rows need fixing.
