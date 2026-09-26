# 008 — A north-Atlantic vessel registry, to feed the AIS trail build

**status:** proposal — nothing built, nothing moved into `$FISHYDATA` yet ·
**see:** `curate/plans/003-stk-vessel-identity.md` §4.5/§4.7 (the foreign-vessel
gap this extends), `TODO.md` item 17

*2026-09-26. Scoping only, at the maintainer's request, while source files are
still landing in `~/garbage/vessels_from_home-haf-einarhj-stasi-fishydata-dataraw`
— outside `$FISHYDATA`, so nothing here is a `$FISHYDATA` claim yet.*

## 1. Why this is its own plan, not plan 003 step 8

Plan 003 §4.5 scoped "the ASTD identity table" narrowly: look up STK's unmatched
foreign MMSIs in ASTD's broadcast data. What has actually landed is bigger than
that — five sources, of which one (§3 below) is not a national registry at all
but an **already-built match table** that answers plan 003's open question more
directly than ASTD would. This plan scopes the whole set; it does not replace
003 step 8, it absorbs and extends it.

## 2. What exists, measured 2026-09-26 (still copying — EU/ISL/marinetraffic
complete, FRO and gfw growing, NOR just finished)

| source | contents | join key | size | fill / coverage |
|---|---|---|---|---|
| `EU` | EU fishing fleet register, one row per registration **event** per vessel (`CFR` id) — 23 states, 1,079,982 rows | MMSI, IRCS (call sign) | 371M, 2 dated snapshots | MMSI populated on ~8% of rows sampled (only some events carry it) |
| `FRO` | Faroese registry, one file per vessel (`vid-NNNN.csv`, long key→value) — name, call sign, MMSI, IMO, owner, dimensions | MMSI, call sign (`Kallimerki`) | 2,257 files so far, 8.6M | MMSI populated on 859/2,257 (38%) sampled so far |
| `NOR` | Norwegian vessel register, one sheet per year 2001–2022, from Fiskeridirektoratet | call sign (`Radiokallesignal`) — **no MMSI column at all** | 18M, one file | call sign only; needs a separate MMSI source for Norway specifically |
| `gfw` | Two different things, now both present. The daily grids (`fleet-daily-csvs`, `mmsi-daily-csvs`) are **effort data** — `date, lat/lon cell, flag, geartype, hours, mmsi_present` — no identity. `fishing-vessels-v2.csv` (arrived 2026-09-27) **is** a vessel identity table — one row per MMSI, `flag_ais`/`flag_registry`/`flag_gfw`, `vessel_class_inferred`/`_registry`/`_gfw` (geartype), `length_m_*`, `engine_power_kw_*`, `tonnage_gt_*` (each as inferred-by-neural-net / from-registry / GFW-consolidated), `registries_listed` (which registries back the match — `EU`, `IMO`, `GFCM`, `WCPFC`, national codes, …), and 2012–2020 fishing hours per year | `mmsi` only — **no call sign column**, same limitation as `NOR` | grids: 5.7G (2020) + two more zips mid-copy; `fishing-vessels-v2.csv`: 17M, 114,191 vessels | **measured 2026-09-27**: resolves 515 of the 6,598 unmatched STK mobile-ids whose `glid` is itself an unmatched 9-digit MMSI — smaller than marinetraffic's 920 but real, and CC BY-SA 4.0 licensed (unlike Equasis's restricted terms) |
| `ISL` | Icelandic MMSI↔vessel spreadsheets, Fjarskiptastofa 2024/2025 | MMSI | 812K | this is the source for the 88 unmatched Icelandic vids item 17 already names |
| `marinetraffic` | **Two hand-built match tables**, keyed directly by STK's own `mobileid` — see §3 | `mobileid` (STK's own key) | 204K | see §3 — this is the standout |

## 3. The marinetraffic sheets are a finished input, not a raw source

`STK_MARINETRAFFIC_MATCTH.xlsx` (1,230 rows) and `CS_MARINE_TRAFFIC_MATCH4.xlsx`
already carry `mobileid, localid, globalid, name, cs, imo, mmsi, class` — and for
many rows, a candidate `vid` — cross-referenced against MarineTraffic by hand at
some point before this restructuring. Measured against the current
`vessel_ais_key.parquet`:

- **1,219 of 1,230** `mobileid`s are mobile-ids that survive into today's key at
  all (11 were filtered out — worth checking against decision 033's `n >= 10`
  population once this is picked up for real).
- **920 of those are currently unmatched** (no `vid` in the key today).

That is 920 mobile-ids with a name/call-sign/IMO/MMSI candidate sitting unused,
which is a larger and faster win than the ASTD lookup plan 003 scoped, and it
needs no new registry at all — it needs review and, where a human agrees, entry
through `overrides/` (per `AGENTS.md`'s cycle rule — this script does not get to
assign a vid from a spreadsheet on its own authority, however well-sourced).

## 4. What already exists — this changes where the new pieces land

`reference/vessels/` and `$FISHYDATA` already have a vessel pipeline, and this
plan has to be scoped against it, not next to it:

- **`$FISHYDATA/raw/vessels/`** is the *Icelandic Oracle dump* —
  `vessel.parquet`, `vessel_v.parquet`, `vessel_owners_hist.parquet`, etc.,
  written by `raw/vessels/DUMP_vessels.R` (an extraction script, per
  `AGENTS.md`'s `dump/` layer, even though it currently sits inside `raw/`
  rather than `dump/`). **This directory is reserved for that dump.** The new
  EU/FRO/NOR/marinetraffic files are not Oracle output and do not belong here —
  see §5.
- **`reference/vessels/registry.R`** reads `raw/vessels/vessel_v.parquet` +
  `mmsi_iceland_archieves.parquet` and writes `curated/vessel/vessel.parquet`.
  It already carries a `source` column, but only ever sets it to `"ISL"` —
  including for the 3700–4999 range, which is **Iceland's own bookkeeping
  number for foreign vessels that fished or landed there**, not a foreign
  country's registry id. A Faroese `vid`, an EU `CFR`, and Norway's `Fartøy ID`
  are three more numbering spaces, none of them the same as Icelandic `vid` —
  so foreign-registry rows cannot simply be appended into `vessel.parquet`
  keyed by `vid` the way `registry.R` currently keys everything. They need
  their own external-id keyspace, joined to a `vid` (if one is ever
  established) via MMSI/call sign — never merged into it as more `vid` rows.
- **`reference/vessels/identity.R`** builds `vessel_identity.parquet` from
  `vessel.parquet` alone (decision 015) — one row per `(vid, period)`. It is
  the model this plan's foreign table should resemble in *shape* (time-aware
  attribute periods, same reasoning about `mmsi_t1`/`mmsi_t2` vs. hull
  lifetime), but it should stay a **separate table**, not a fifth `source`
  folded into this one — same reasoning as above.
- **`reference/vessels/mmsi.R`** already maintains a Fjarskiptastofa MMSI
  archive, reading a dated `mmsi-iceland_fjarskiptastofa_YYYY-MM-DD.xlsx` from
  `staging/mmsi/` (which does not exist yet under this `$FISHYDATA` — the
  script's hardcoded paths point at files that were never copied over). The
  `ISL` files in `~/garbage/...` (2024-08-21, 2025-04-10) are **this same
  input**, not a new source — and a newer one (`2026-03-09`) already exists,
  unmoved, in `~/stasi/fishydata_2024-2026/data-raw/mmsi/`. This is item 17's
  "88 unmatched Icelandic vids... Fiskistofa/Fjarskiptastofa lookup" ask,
  answerable by running `mmsi.R` once `staging/mmsi/` and the newest xlsx are
  in place — a small, separate, likely-quick piece, not part of the
  foreign-vessel gap this plan is about.
- **`reference/vessels/marinetraffic_scrape.R`** already exists — a
  single-vessel headless-Chrome scraper (`chromote`), prototype-stage, not yet
  run at scale. It is a *plausible origin* for the two hand-built xlsx match
  sheets in §3, or a predecessor to whatever produced them, but they are not
  its output as they stand — they are already-compiled results sitting ahead
  of where this script's own work would resume.

## 5. Proposed shape (not built)

A **new, separate** table — not a `vessel.parquet` extension — one row per
(source, external id, attribute period). The columns needed for AIS matching
are just `external_id, name, cs, mmsi, imo, flag, t1, t2` — but the maintainer's
instruction is to make this a real registry an analyst can open for its own
sake, not a matching key with a few extras bolted on. Each source already
carries far more than identity, measured against what actually landed:

### 5.0 Identity is a hierarchy, not one key — and the maintainer's point applies here too

Decision 015 already established this for the Icelandic fleet: `vid` is the
keel, everything else is an attribute of it *at a time*. The maintainer's
correction extends the same reasoning to the foreign sources, with a stability
ranking: **IMO** (assigned once, follows the hull like `vid` does) >
**MMSI** (mostly stable — reassignment is rare even outside Iceland, per the
maintainer, though not never) > **call sign** ("more notorious", i.e. changes
more often) > **vessel name** (least stable of all). Measured against the EU
file, which is the one source with enough history to check this directly —
grouping by `CFR` (its own keel-equivalent id) across each vessel's full event
history:

| attribute | CFRs where it changed at least once |
|---|---|
| MMSI | 119 |
| IRCS (call sign) | 2,369 |
| Name of vessel | 29,290 (16% of all 183,748) |

One example makes the point concretely: `CFR BEL030151975` kept the same call
sign (`OPAO`) across eleven registry events from 1989 to 2021, while being
renamed twice (`STEPHANIE` → `ZILVERMEEUW` → `CALYPSO`) and having its MMSI
appear from nothing, then change again, all under the one stable `CFR`. A flat
join on name or a "current" MMSI snapshot would have silently attributed
pings from the wrong period to the wrong identity — precisely the class of bug
decision 015 fixed for `TFBR`/HÓLMBERG (§3.1 of plan 003), now shown to apply
to the foreign fleet too.

**Consequence for `external_id`**: use IMO (or the EU/UVI field, where it is
an IMO number — needs confirming against the EU documentation when this is
built, since UVI is IMO for larger vessels and an EU-only scheme number for
smaller ones) wherever it exists — it is the only identifier safe to match
**across** sources. Where IMO is absent, fall back to the source's own
registration id (`CFR`, FRO's `vid`, `Fartøy ID`) — safe **within** that
source only, never merged across sources on the strength of a shared MMSI,
call sign or name alone.

**Consequence for the table's shape**: this is not one flat row per vessel.
It is `vessel_identity.parquet`'s own shape (decision 015), generalized from
`vid` to `external_id` — one row per `(source, external_id, period)`, and the
period's grain follows what each source actually evidences, not a single
assumed cadence:

- `eu`: the registry's own `Event Start Date`/`Event End Date` **are** the
  attribute-period boundaries already — don't collapse to "current" the way
  §6's active-fleet count did for measurement purposes; that collapse was for
  counting vessels, not for this table.
- `nor`: one sheet per year (2001–2022) — a change window can be inferred by
  diffing consecutive years' call sign/name per `Fartøy ID`.
- `fro`/`gfw`: no observed change history — one open window per vessel,
  `window_basis = "unbounded"` (mirroring `identity.R`'s own column of that
  name), not evidence of stability, just absence of a second observation.

**Consequence for matching**: joining this table against STK/AIS must go
through the attribute's own window at the ping's time, exactly like
`R/vid_match.R`'s `match_time_aware()`/`confirm_vid()`/`match_identity_pair()`
already do against `vessel_identity.parquet` — those functions generalize
directly from `vid` to `external_id` with no new logic needed. A flat join
(candidate MMSI or call sign against whatever this table's "latest" row says)
is exactly the mistake decision 015 fixed once already; it should not be
reintroduced here by accident.

| group | column | eu | fro | nor | astd | gfw | marinetraffic |
|---|---|---|---|---|---|---|---|
| identity | `name`, `cs`, `mmsi`, `imo` | ✓ | ✓ | ✓ (no mmsi) | ✓ (no cs) | `mmsi` only (no name, no cs) | ✓ |
| registration | `registration_number`, `place_of_registration`, `first_registered_date`, `status` | ✓ | ✓ | — | — | — | — |
| dimensions | `loa`, `lbp`/`length_registered`, `breadth`, `depth`, `draught` | ✓ (no draught) | ✓ | `loa`, `breadth` only | `length_registered`, `draught` | `length_m` (×3, see below) | — |
| tonnage/capacity | `gross_tonnage`, `net_tonnage`, `deadweight`, `passenger_capacity` | ✓ (no deadweight/pax) | `gross_tonnage`, `net_tonnage` | — | ✓ (all four) | `tonnage_gt` (×3) | — |
| propulsion | `engine_power_kw`, `engine_power_aux_kw`, `n_engines`, `engine_type`, `engine_build_year` | `engine_power_kw`/`aux` only | ✓ (all but n_engines) | `engine_power_kw`, `engine_build_year` | — | `engine_power_kw` (×3) | — |
| construction | `year_of_build`, `shipyard`, `hull_material`, `ice_class` | `year_of_build`, `hull_material` | ✓ (all four) | `year_of_build` | `year_of_build`, `ice_class` (`arcticshiptype`) | — | — |
| classification | `vessel_type`/`segment`, `gear_main`, `gear_subsidiary_1..5`, `lloyds_cat`, `astd_cat` | ✓ (all, fishing-specific) | `vessel_type` (`Slag`, general) | — | `astd_cat`, `lloyds3_cat`/`lloyds5_cat` | `vessel_class` (×3, GFW's own geartype taxonomy — see README-fishing-vessels-v2.txt) | `class` (general) |
| ownership | `owner_name`, `owner_id`, `ownership_share`, `org_form` | — | `owner_name` | ✓ (all four) | — | — | — |
| activity | — | — | — | — | — | `fishing_hours_2012`..`2020` per vessel, `registries_listed` (which registries corroborate the match) | — |
| provenance | `source_file`, `retrieved_date`, `basis` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (`basis = "recorded"`, hand-curated — §6) |

`gfw`'s three-way columns (`_inferred` from GFW's neural net, `_registry` from
whichever registries it cross-referenced, `_gfw` its own consolidated best
guess) are themselves a `basis` distinction already made for us — `_registry`
is `"recorded"`, `_inferred` is `"reconstructed"`, and keeping the split rather
than collapsing to `_gfw` alone means a value's provenance survives.

This is deliberately wider than `vessel.parquet`'s own columns
(`loa`/`kw`/`n_engines`/`kw_total`/`grt`/`bwt`/`nwt`) — matching or exceeding it
is the right bar, not falling short of what the Icelandic fleet already gets.
Every column is sparse by source (NOR alone has no dimensions beyond `loa`/
`breadth` and no tonnage at all; ASTD has no registration or ownership
information at all — it is a broadcast feed, not a registry) — that sparsity
is real and should show as `NA`, not be hidden by narrowing the schema to
whatever the thinnest source provides. `basis` (`AGENTS.md`'s "recorded" /
"reconstructed" / "synthesised") matters here specifically for
`marinetraffic`, which §6 confirms is one person's manual lookup rather than a
registry extract.

`source` distinguishes `marinetraffic_match` (already vid-candidate, highest
trust), `fro`, `nor`, `eu`, `astd`. (`isl_fjarskiptastofa` drops out of this
table — see §4, it is `mmsi.R`'s job, into the existing Icelandic `vid`
keyspace, not this one.) **`cs` is the primary join key for matching, `mmsi`
secondary** — §6's EU measurement shows why: Ireland and the UK carry a call
sign on essentially every active vessel and an MMSI on none, and NOR has no
MMSI column at all. This is a statement about *evidence availability*, not
stability — §5.0 already measured `cs` as the more *volatile* of the two. The
two facts don't conflict: leading with `cs` because it's there more often is
safe only because the match goes through its own time window (§5.0), the same
way `R/vid_match.R`'s cascade already prioritizes call sign over MMSI for the
Icelandic fleet without that being unsafe — time-awareness is precisely what
makes preferring a volatile-but-available field over a stable-but-sparse one
work. The wider metrics columns above ride along on whatever row the identity
join resolves. Feeds four consumers:

- **§3's 920 mobile-ids** → a candidate list for direct human review into
  `overrides/`, no registry dependency.
- **The fishing-vessel share of the remaining foreign residual** (NA_cs4's
  19.2M pings, foreign call signs with no registry at all per plan 003 §4.7)
  → matched against `fro`/`nor`/`eu` by call sign, unfiltered by flag (§6),
  same cycle rule, same route through `overrides/`.
- **515 more of the unmatched-MMSI population** (§2, measured 2026-09-27) →
  matched against `gfw`'s `fishing-vessels-v2.csv` by MMSI — this is the one
  source in the table with no call sign at all, so it only ever reaches the
  same population `NOR` does, from a different angle (GFW's own
  registry-cross-referenced identity rather than a national register).
- **The non-fishing share** (cargo/tanker/passenger/yacht — §6) is out of
  reach for `fro`/`nor`/`eu`/`gfw` by construction (`gfw`'s own README:
  "fishing vessels... which were not identified as non-fishing vessels" — it
  is fishing-only by design, same boundary as `eu`/`nor`). This is where §6's
  ASTD-derived identity table does the work plan 003 §4.5 originally scoped as
  a one-off lookup: a **second table**, same `(external_id, period)` shape,
  `source = "astd"`, `external_id = mmsi`, built for every MMSI seen in
  `ping_union` or the unmatched residual — **not filtered by `astd_cat`** (§6:
  the maintainer finds it unreliable — real fishing vessels land in
  `Unknown`/`Other activities`) and not a global ASTD summary. `astd_cat`
  rides along as a reference column only; whether a row is "the fishing share"
  or "the non-fishing share" is decided by whether it also resolves against
  `eu`/`nor`/`fro`/`gfw`, not by this field. Equasis (§6) stays a later,
  maintainer-gated option, not part of what gets built first.

## 6. Open, before this is built for real

- **`gfw`**: resolved 2026-09-27 — `fishing-vessels-v2.csv` is the vessel-identity
  table (§2/§5), CC BY-SA 4.0 licensed (its own README states this, so no
  licensing question the way Equasis has one), and its README doubles as the
  provenance note (methodology paper cited: Kroodsma et al., *Science* 2018).
  One file, `dffc3970-22a2-11ef-aa23-732e8218fbea.zip`, was still mid-copy as
  of this measurement (growing from 803M to 818M in five seconds) — unidentified,
  check again once it finishes. The daily-effort grids remain effort data, not
  identity, and stay out of scope for this plan (§2).
- **EU scope — measured 2026-09-27, revised same day.** First pass wrongly
  scoped this by *assumed* geography (a "north Atlantic flags" whitelist). The
  maintainer's correction: STK/ASTD will show a Cyprus- or Malta-flagged
  vessel exactly when a flag-of-convenience hull turns up near Iceland, which
  is precisely the case a geography assumption is blind to. Measured instead,
  against the actual unmatched population — every `entity_class == "vessel"`
  mobile-id in today's key with no `vid`, its `glid` matched against
  `staging/aux/callsign_prefix.parquet` (longest-prefix match, so this is a
  flag-state guess, not a country in the strict sense — Denmark's block also
  covers Faroese-administered call signs, which is why it dominates by ping
  count and is not evidence of that many literally-Danish vessels):

  | guessed flag | mobile-ids | pings |
  |---|---|---|
  | Denmark (incl. Faroese-administered call signs) | 959 | 12.1M |
  | United Kingdom | 4,315 | 2.77M |
  | Norway | 530 | 2.48M |
  | Netherlands | 382 | 1.00M |
  | France | 204 | 0.60M |
  | Sweden | 248 | 0.54M |
  | **Bahamas** | 206 | 0.51M |
  | Iceland | 15 | 0.46M |
  | **Antigua and Barbuda** | 188 | 0.40M |
  | **Cyprus** | 97 | 0.30M |
  | **Malta** | 235 | 0.29M |
  | Portugal | 128 | 0.29M |
  | **Barbados** | 96 | 0.23M |
  | **Liberia** | 285 | 0.16M |
  | **Marshall Islands** | 331 | 0.13M |
  | **Panama** | 293 | 0.11M |
  | … 88 more, smaller | | |

  Bahamas/Antigua/Cyprus/Malta/Barbados/Liberia/Marshall Islands/Panama
  (bold) are exactly the flag-of-convenience registries a "north Atlantic"
  assumption would have dropped — 105 guessed flags appear at all, and this
  covers 23.5M of the 23.8M unmatched pings. **Conclusion: don't pre-filter
  the EU file by flag at all.** At 371M/1.08M rows it is cheap enough to keep
  whole and query by demand — filter at match time (which flags actually
  appear in the residual, this table, re-measured as the residual changes),
  never by an assumption made once up front.

  Still measured and worth keeping regardless of the flag question: this is an
  **event ledger** (`Event` = `CEN` first registration, `MOD`, `RET`/`DES`/`EXP`
  exit, etc.), and taking each vessel's latest event while excluding the three
  exit types separates the ~29,000 active vessels (across DNK/DEU/GBR/IRL/NLD
  /POL/FRA/SWE/BEL alone) from the 183,748-row historical total — worth
  re-running per-flag once flag scope is demand-driven rather than assumed.
  And **IRCS, not MMSI, is the join key to lead with**: Ireland and the UK
  carry a call sign on essentially every active vessel and an MMSI on none,
  matching how `R/vid_match.R`'s cascade already prioritizes call sign for the
  Icelandic fleet — no new matching strategy needed, just this registry joined
  the same way.

- **Fishing vessels are not the whole target — confirmed 2026-09-27.** The
  maintainer's second correction: AIS/STK carries every vessel type, and two
  of these three sources structurally cannot help with most of them. The EU
  file's `Vessel Type` codes (`FX`, `GO`, `TO`, `MOX`, …) are EU fleet-segment
  gear codes — it is the **EU Fishing Fleet Register**, fishing vessels only,
  by construction (`CFR` registration itself is fisheries-specific). `NOR`
  comes from Fiskeridirektoratet (the Directorate of *Fisheries*) and is very
  likely the same, unconfirmed. `FRO` is the outlier and is **not**
  fishing-only: its own `Slag` (type) field spans `Fiskiskip` (fishing, 291),
  `Handilsskip` (merchant, 151), general cargo, tug, offshore supply, RO-RO,
  container, passenger and tanker types (`fro` sample, 530 vessels checked).
  So EU and (likely) NOR bound only the fishing-vessel share of the unmatched
  residual. `marinetraffic`'s `class` field (§3) already spans cargo, tanker,
  passenger, yacht, sailing vessel — further evidence the target population is
  not fishing-only. Two ways to close the rest, one already in hand:

  **ASTD itself, measured 2026-09-27** — `astd_cat` (a category ASTD assigns
  to every broadcast, not something this plan has to derive) breaks 2.77
  billion pings as: `Unknown` 1.13B (41%), `Fishing vessels` 552M (20%),
  `Other activities` 332M (12%), `Passenger ships` 299M (11%), `General cargo
  ships` 209M (8%), and eight more categories (bulk carriers, tankers of four
  kinds, container, Ro-Ro, cruise, refrigerated cargo) at 8–46M each.

  **The maintainer flags `astd_cat` itself as unreliable** — a lot of genuine
  fishing vessels land in `Unknown` and `Other activities` rather than
  `Fishing vessels`, so `astd_cat != 'Fishing vessels'` is **not** a safe
  fishing/non-fishing split (it would silently keep real fishing vessels in
  what's meant to be the non-fishing table, duplicating EU/NOR/FRO rather than
  complementing them). This still confirms plan 003 §4.5's original idea is
  worth building out properly rather than as a one-off lookup, just without
  trusting `astd_cat` as the filter: a real ASTD-derived identity table — one
  row per `mmsi` with `vesselname`/`imonumber`/`flagcode`/`gross_tonnage`/
  `astd_cat` carried along **for reference, not as a filter** — built for
  every MMSI that actually appears in `staging/ais/ping_union` or the
  unmatched STK residual (2.77B rows is not something to summarize globally).
  Fishing/non-fishing then has to be decided the same way the rest of this
  plan already decides identity: by whether the MMSI/call sign also resolves
  against `eu`/`nor`/`fro`, not by asking ASTD what it thinks it is. This needs
  no new source and no licensing question — ASTD is already a consumed input
  here.

  **Equasis** (EMSA-backed, free after registration, ~85,000 merchant ships
  over 100 GT, all types including fishing) is the "EU registry of all
  vessels" the maintainer asked to check — it exists, and it does carry
  MMSI/IMO/call sign/flag/GT/type per ship. But its own terms of use say the
  data "may [not] be stored in a retrieval system... without prior permission
  in writing," which is exactly what landing it under `$FISHYDATA` would be —
  unlike NOR/EU/FRO's open-data exports, this is a **maintainer licensing
  call, not a scoping one**, before any automated use. Its 100 GT floor also
  means it mainly reaches the larger end of the non-fishing gap (cargo, tanker,
  passenger, bulk) that ASTD's own `astd_cat` already surfaces — so it would
  be corroboration for names ASTD already gives, not a new population, and
  the ASTD-derived table above is the lower-friction path to try first.
- **Provenance/licensing**: these are vendor/scraped files, not Oracle — worth
  a line in the eventual `dump/` or `sources/` script about where each came
  from and when, matching how `raw/external/hreidar/` and
  `raw/external/BrimAfladag2022-2026/` already record theirs. Losing this fact
  is exactly what cost plan 003 §4.5 a session already.

  **Partly answered, 2026-09-26**: a `README` dropped into
  `~/garbage/vessels_from_...` gives NOR, FRO and EU their source URL and
  download date —
  [fiskeridirektoratet.no](https://www.fiskeridirektoratet.no/Tall-og-analyse/AApne-data/Fiskere-fartoey-og-fisketillatelser)
  (2024-02-17), [teyggjan.fo](https://www.teyggjan.fo) via
  `data-external/vessel/faero-scrape_vessel-info.R` (2024-02-19, script itself
  not found under that path — likely renamed; log files for that date survive
  under `fishydata_2024-2026/scripts/log/`), and the
  [EU fleet register webgate](https://webgate.ec.europa.eu/fleet-europa/results_en)
  (2024-02-19). `marinetraffic` is confirmed hand-curated — built from manual
  lookups on marinetraffic.com, not a bulk export or the `marinetraffic_scrape.R`
  prototype (§4), which matters for §3's review: it is one person's judgement
  call per row, not a mechanical match, so treat disagreements with the
  registries as "which one is wrong" rather than "the scrape mis-parsed
  something." `gfw` still carries no source note — capture before moving.
- **Destination**: `$FISHYDATA/raw/external/<source>/` — following the
  `hreidar`/`BrimAfladag` precedent for non-Oracle vendor data, **not**
  `raw/vessels/`, which §4 establishes is reserved for the Oracle dump. Not
  moved yet, per the maintainer's own hold.

## 7. Proposed order, once the copy is done and files are moved into `raw/`

1. Review the 920-mobile-id marinetraffic candidate list by hand → `overrides/`.
   No registry dependency; can happen before anything else here.
2. Separately, and independently of the rest of this plan: run `mmsi.R` against
   the newest Fjarskiptastofa xlsx (§4) to close item 17's 88-vid gap.
3. Land `fro`/`nor`/`eu`/`gfw` (`fishing-vessels-v2.csv` only, not the effort
   grids) under `$FISHYDATA/raw/external/`, one adapter each in `sources/`,
   writing the shape in §5 to its own `curated/vessel/` table — not into
   `vessel.parquet`/`vessel_identity.parquet`, and **not filtered by flag**
   (§6) — keep the full EU file, query by demand.
4. Match the NA_cs4 residual against the `eu`/`nor`/`fro`/`gfw` table — call
   sign first, `gfw` by MMSI only since it has none — time-aware, same
   construction as `R/vid_match.R`.
5. Build the ASTD-derived identity table (§5/§6) for whatever is left
   unresolved by step 4 — every MMSI in `ping_union`/the residual, `astd_cat`
   kept as reference only, not a filter. What resolves against step 3's table
   is the fishing share; what doesn't is the non-fishing share, decided by
   that join, not by asking ASTD what it thinks a vessel is.
6. Confirm what `dffc3970-....zip` (§6, still mid-copy) turns out to be, and
   whether Equasis's licensing question is worth raising with the maintainer.
