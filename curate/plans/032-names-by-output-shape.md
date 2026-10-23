# 032 — Names by output shape: one verb for a table, one for a column, and "port call" for a stay

**status:** executed — asks a-e answered by the maintainer on 2026-10-19 (§7): `create` for a table, `add` for
columns, "port call" for a stay; ramb renamed (2026.10.19.2) and fishycode's callers on the new names the same day
(decision 147), and fishycode's tables rebuilt on the new keys the same evening (decision 149); not pushed; ramb's
pkgdown index on the new names 2026-10-23 (decision 186; ramb 8a0ae92, pushed) ·
**2026-10-19** · **see:** decision 186, decision 075 (the terms port, stay,
voyage), plan 013 (ramb's steps and its step registry), plan 014 (the flow as thin callers of ramb), plan 031 (the
voyage cascade and its bench), ramb `AGENTS.md` (naming), ramb `R/registry.R`

*Written by Claude (AI-assisted) from a discussion with the maintainer, 2026-10-19. The counts in §2 were read from
ramb's working tree and from the build at e2f741f; the rest is proposal.*

## 1. The question

Raised by the maintainer while the CNR and iapesca trip finders were brought into ramb (plan 031 §4.8):
- All voyage detection belongs in one ramb function, with the rule chosen by `method = "…"`.
- `rb_cut_trip_voyages()` is a poor name, and `rb_find_trip_voyages()` says the same noun twice in two languages.
- A function returns either a new table or the input with a variable added; its name should say which, in line
  with tidyverse naming in general.
- "Stay" means nothing outside this project, nor `method = "stays"`: it is a vessel in port.
- fishycode has no functions for the flow, only scripts, but they fall under the same thinking.

## 2. What exists (measured)

**ramb's step registry** (`R/registry.R`) already separates the two shapes: a "builder" returns a table of its own,
a "step" adds columns to the pings and passes every ping on. The verbs follow it only in part:

| shape | verbs in use |
|---|---|
| new table of objects (builders) | `find` 1 (`rb_find_trip_stays`), `cut` 2 (voyages, record stretches), `build` 3, `limit` 1, `share` 1 |
| new table of pairs (builders) | `link` 6 |
| pings with columns added (steps) | `flag` 4 (step 0), `assign` 4 (trip, record, fishing, effort), `link` 1 (`rb_link_trip_logbook`, adds `trip_id`) |
| a vector, for `mutate()` | `calc`, `bin`, `cap`, `classify`, `convert`, `create` (`rb_create_timestamp`), `detect`, `encode`, `extract`, `interpolate`, `lookup`, `number`, `pad` |

**fishycode's flow** splits the same way in its outputs: tables of objects (`curated/ais/port_stay`, `voyage`,
`voyage_gear`, `logbook/station_window`), tables of pairs (`curated/link/trip_voyage`, `station_event`), and the trail,
one row per fix, carrying keys (decision 075: values once in their table, fixes carry keys only). Its script rule 3,
"name for the output, not the action", is the table side. Its names differ from ramb's:

| concept | fishycode | ramb |
|---|---|---|
| stay key, voyage key | `stay`, `voyage` | `stay_id`, `voyage_id` |
| a stay's port | `pid` | `port_id`; `stay_port_id` on pings |
| a voyage's ports | `pid1`, `pid2` | `port_from`, `port_to` |
| declared trip, station | `.tid`, `.sid` (with `schema`) | `trip_id` |
| AIS times in links | `T1_ais`, `pid1_ais` | `T1_voyage`, `T2_voyage` |

The trail also repeats voyage values on each fix (`gid_voyage`, `s1_voyage`, `s2_voyage`, `gear_voyage_basis`,
`.tid_voyage`, `n_tid_voyage`), against 075's keys-only rule, with no record of that being a choice.

**Elsewhere:** jepol's `trip_id` is "vessel_n" (with "_1"/"_2" when a trip is split); CNR's `trip` is 1..k per
vessel; iapesca's `FISHING_TRIP_FK` is "FT" + date + number; vmstools' and the ICES data call's `FT_REF` and WKSSFGEO2's
`TRIP_ID` are declared trips.

## 3. Tidyverse precedent

dplyr `count()` / `add_count()` and `tally()` / `add_tally()`; broom `tidy()` / `augment()`; tibble `add_row()`,
`add_column()`. `add_` is the tidyverse word for "your data back, with columns added". Families share a prefix
(`str_`, `fct_`; here `rb_`), then the verb. Base R's `assign()` means binding a variable in an environment.

## 4. Proposal

*As proposed. The answers in §7 replace `find` with `create` and widen the scope; the rest stands.*

- **Tables of objects found in the data: `rb_find_*`.** `rb_find_voyages(pings, method = …)`,
  `rb_find_port_calls(pings, method = …)`, `rb_find_record_stretches()`. Port calls and voyages are the two halves of
  one partition of the track, so they share the methods; ramb's own stay rule becomes one of them.
- **The pings with keys added: `rb_add_*`.** `rb_add_voyages(pings, voyages, port_calls)` (now `rb_assign_trip()`;
  given `method` and no `voyages`, the one call that returns the pings with ids), likewise `rb_add_record()`,
  `rb_add_fishing()`, `rb_add_effort()`.
- **Kept:** `rb_flag_ping_*()` (a flag is a column) and `rb_link_*()` for tables of pairs. `rb_link_trip_logbook()`
  becomes an `add` or returns a pair table.
- **"Port call" for a stay** (the shipping term; Global Fishing Watch says "port visit"), key `port_call_id`.
  "Port" stays the place word (075), not "harbour".
- **Methods named for their rule:** `"dwell"` (in port for a minimum time, with the departure radius; now `"stays"`),
  `"runs"`, `"jepol"`, `"cnr"`, `"iapesca"`.
- **Keys:** `port_call_id` and `voyage_id`, integers numbered per vessel-year by start time, NA on pings outside them;
  stable only for one run of one method, so never kept as a key across rebuilds.
- **Rejected:** `rb_find_trip_voyages()` (the noun twice), `rb_create_*` for tables (`rb_create_timestamp()` already
  returns a vector), `rb_assign_*` kept for columns (base R's `assign()`).

## 5. What a decision would change

- ramb: the renames, each old name kept one release as a warning alias (ramb's compatibility policy), NEWS, the
  registry rows, the articles, and AGENTS.md's naming rule (`voyage` and `port_call` as nouns without the `trip` stage
  word).
- fishycode: a decision record superseding 075's "stay": `curated/ais/port_stay.parquet` and its `stay` column, the
  trail's `stay`, `docs/grammar.qmd`, `docs/one_flow.qmd`, plan 011; the callers in `curate/` and `products/`; and
  whether its own key names follow ramb's (§2's table) or keep a recorded mapping.

## 6. Asks

a. The verb for a new table: `find` (proposed) or `create`?
b. The verb for the input with columns added: `add` (proposed, tidyverse) or keep `assign`?
c. The term for a vessel's time in port: "port call" (proposed) or "port visit"?
d. Keys: `port_call_id` and `voyage_id` numbered per vessel-year, in ramb and in fishycode's tables alike?
e. The voyage values the trail repeats on each fix: keep them for analysts (and record it), or keys only?

## 7. Answers (maintainer, 2026-10-19)

*Recorded by Claude from the maintainer's answers in chat, the same day. a-e and the two follow-ups are the
maintainer's; "To settle in the build" is Claude's reading, for review.*

a. **`create`** for a function that returns a table of its own, not `find`. `rb_create_timestamp()`, which used the
   word for a vector, becomes **`rb_add_timestamp(data, …)`**: the data with the column added (follow-up).
b. **`add`** for the input with columns added. **Scope** (follow-up): plan 032's list and `build_*`, each by its
   shape. Kept, because each verb says what the function does: `rb_limit_record_duration()`, `rb_share_catch()`,
   `rb_interpolate_track()`, `rb_flag_ping_*()`, `rb_link_*()` (pair tables).
c. **"Port call"**, key `port_call_id`, with `method = "dwell"` for `"stays"` in both functions. The argument
   `stays =` becomes `port_calls =`, and `min_stay_h` (`min_stay`) becomes `min_dwell_h` (`min_dwell`). For `"runs"`,
   `"jepol"`, `"cnr"` and `"iapesca"`, a port call is the time in port between two of their voyages. Not renamed:
   `rb_pad_harbour()`, `rb_read_harbours_mfri()` (plan 013's keep).
d. **Alike, at a rebuild.** `port_call_id` and `voyage_id`, numbered per vessel-year by start time, in ramb now.
   fishycode's tables take the same names (`port_call.parquet`, `port_call_id`, `voyage_id`) at a rebuild done as its
   own piece, since the code and the data change together. Until then the callers map ramb's names onto today's
   columns, so nothing on disk breaks. `pid`, `pid1`/`pid2` and `.tid` keep a mapping recorded in `docs/grammar.qmd`.
e. **Keep the voyage values on the trail**, recorded as a deliberate exception to 075's keys-only rule: the analyst
   opens the trail alone.

| now | becomes | shape |
|---|---|---|
| `rb_find_trip_stays()` | `rb_create_port_calls(method = )` | table |
| `rb_cut_trip_voyages()` | `rb_create_voyages(method = )` | table |
| `rb_cut_record_stretches()` | `rb_create_record_stretches()` | table |
| `rb_build_record_windows()` | `rb_create_record_windows()` | table |
| `rb_build_record_pings()` | `rb_create_record_pings()` | table |
| `rb_assign_trip()` | `rb_add_voyages()` | pings + columns |
| `rb_assign_record()` | `rb_add_record()` | pings + columns |
| `rb_assign_fishing()` | `rb_add_fishing()` | pings + columns |
| `rb_assign_effort()` | `rb_add_effort()` | pings + columns |
| `rb_link_trip_logbook()` | `rb_add_logbook_trip()` | pings + columns |
| `rb_build_catch_units()` | `rb_add_catch_units()` | events + columns |
| `rb_create_timestamp()` (a vector) | `rb_add_timestamp()` (data + column) | data + column |

Each old name is kept for one release as a warning alias, under ramb's compatibility policy. The aliases accept the
old argument names and `method = "stays"`; the new functions take only the new ones.

**A third follow-up** (maintainer, during the build). A port call is not cut at New Year, so a key numbered per
vessel-year would leave a ping on 2 January, in a call begun on 28 December, carrying last year's number. Its own
year would then find the wrong call. So **`port_call_id` is numbered per vessel** by `T_in`, as fishycode's `stay`
is, and the table keeps `year` (of `T_in`). `voyage_id` stays per vessel-year, since voyages are cut at New Year.
`rb_create_port_calls()` has no `by_year`.

**Settled in the build** (Claude's proposal, for review):
- The port column on the pings (`stay_port_id`) becomes `port_call_port_id`. It is kept, not dropped, in line with e.
- The one-call `rb_add_voyages(pings, method = …)` with no `voyages` table (§4) is not part of this build.
- What was built and measured is in decision 147.
