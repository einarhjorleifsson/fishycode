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
| `gfw` | Global Fishing Watch daily fishing-**effort grid** (`date, lat/lon cell, flag, geartype, hours, mmsi_present`) — **not vessel identity**, no names or MMSI values, just per-cell presence counts | none usable | 2.5G, one year (2020) so far | not useful for identity matching as currently landed; the maintainer expects a real vessel-registry table may still arrive from the same GFW copy |
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
(source, external id, attribute period):

```
source, external_id, name, cs, mmsi, imo, flag, t1, t2, loa, tonnage
```

`source` distinguishes `marinetraffic_match` (already vid-candidate, highest
trust), `fro`, `nor`, `eu`. (`isl_fjarskiptastofa` drops out of this table —
see §4, it is `mmsi.R`'s job, into the existing Icelandic `vid` keyspace, not
this one.) **`cs` is the primary join key, `mmsi` secondary** — §6's EU
measurement shows why: Ireland and the UK carry a call sign on essentially
every active vessel and an MMSI on none, and NOR (§4's finding) has no MMSI
column at all. Leading with `cs` also matches how `R/vid_match.R`'s cascade
already prioritizes call sign over MMSI for the Icelandic fleet, so this table
slots into the existing match order rather than requiring a new one. Feeds two
consumers:

- **§3's 920 mobile-ids** → a candidate list for direct human review into
  `overrides/`, no registry dependency.
- **The remaining foreign residual** (NA_cs4's 19.2M pings, foreign call signs
  with no registry at all per plan 003 §4.7) → matched against `fro`/`nor`/`eu`
  by call sign, same cycle rule, same route through `overrides/`.

## 6. Open, before this is built for real

- **`gfw`**: confirm whether a vessel-identity table (not the effort grid) is
  still landing before spending time on it for this purpose. The maintainer
  expects an R script may arrive alongside it — likely the fetch/build script,
  which would also be where its own provenance note belongs, same as `NOR`'s
  `downlod_vessels.R`.
- **EU scope — measured 2026-09-27.** 23 states, 1,079,981 rows, 183,748
  distinct vessels (`CFR`), but this is an event ledger (`Event` = `CEN` first
  registration, `MOD` modified, `RET`/`DES`/`EXP` exit, etc.) — most of those
  183,748 are **historical**, not fishing today. Taking each vessel's own
  latest event as "current" and excluding the three exit event types leaves
  the real active-fleet count, and it changes the picture a lot:

  | flag | CFRs (all history) | **active** | active w/ MMSI | active w/ IRCS |
  |---|---|---|---|---|
  | ESP | 27,384 | 8,533 | 5,868 (69%) | 1,991 (23%) |
  | FRA | 19,270 | 6,000 | 4,518 (75%) | 4,971 (**83%**) |
  | PRT | 22,088 | 6,861 | 2,098 (31%) | 2,374 (35%) |
  | IRL | 4,988 | 2,028 | **0 (0%)** | 2,001 (99%) |
  | DNK | 8,118 | 1,774 | 194 (11%) | 708 (40%) |
  | DEU | 4,189 | 1,144 | 147 (13%) | 341 (30%) |
  | SWE | 3,802 | 977 | 287 (29%) | 977 (100%) |
  | POL | 1,598 | 824 | 205 (25%) | 588 (71%) |
  | NLD | 2,755 | 766 | 369 (48%) | 451 (59%) |
  | BEL | 252 | 60 | 60 (100%) | 60 (100%) |
  | GBR | 91 | 50 | **0 (0%)** | 47 (94%) |

  Two things follow. **The active fleet across these 11 flags is ~29,000
  vessels, not 183,748** — that is the number to plan matching effort against.
  And **IRCS (call sign), not MMSI, is the join key to lead with**: Ireland and
  the UK carry a call sign for essentially every active vessel and an MMSI for
  none, and several other flags are IRCS-heavier too. That matches how STK's
  own cascade already prioritizes call sign over MMSI (`R/vid_match.R`), so no
  new matching strategy is needed — just this registry joined the same way.
  GBR's 91 total rows (down from a UK-wide fleet Brexit removed from the EU
  register) is a leftover, not a gap worth chasing.

  DNK, DEU, GBR, IRL, NLD, POL, FRA, SWE, BEL are the plausible north-Atlantic
  flags; ESP/PRT fish there too (distant-water/NAFO fleets) but are large and
  mostly non-north-Atlantic-resident — worth a maintainer call on whether to
  keep them at full size or filter by gear/area. The remaining ~14 EU states
  (ITA, GRC, HRV, CYP, MLT, BGR, ROU, LVA, LTU, EST, SVN, FIN) are dead weight
  for this purpose.
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
3. Land `fro`/`nor`/`eu` under `$FISHYDATA/raw/external/`, one adapter each in
   `sources/`, writing the shape in §5 to its own `curated/vessel/` table —
   not into `vessel.parquet`/`vessel_identity.parquet`.
4. Match the NA_cs4 residual against the consolidated table by call sign,
   time-aware, same construction as `R/vid_match.R`.
5. Only then revisit whether `gfw` contributes anything beyond effort data.
