# 147 — Names by output shape: `create` for a table, `add` for columns, and a port call for a stay (plan 032; ramb 2026.10.19.2)

*2026-10-19. The choices are the maintainer's: plan 032's asks a-e and three follow-ups, answered in chat the same
day. The ramb renames, the fishycode callers, the docs and this record were drafted by Claude (AI-assisted), and the
real-data check below was run by Claude. Committed the same day on the maintainer's word (ramb a312781 and the
fishycode commit that adds this record), not pushed; ramb 2026.10.19.2 installed from that commit. Supersedes decision
075's term "stay". TODO 91 carries what is left.*

## Decided (the maintainer)

- **a, b. One verb for each output shape**, after tidyverse's `count()`/`add_count()`. `rb_create_*()` is for a
  function that returns a table of its own, not `find` as plan 032 proposed. `rb_add_*()` is for one that returns
  its input with columns added, not `assign`. `rb_flag_*()` (a flag column) and `rb_link_*()` (a table of pairs)
  keep their verbs.
- **The scope** (follow-up): plan 032's list and the `build_` tables, each by its shape. `rb_limit_record_duration()`,
  `rb_share_catch()` and `rb_interpolate_track()` keep their names, because each verb says what the function does.
  `rb_create_timestamp()` becomes `rb_add_timestamp()`, which takes the data and adds the column (follow-up). In
  all, twelve renames, each old name kept for one release as a warning alias.
- **c. "Port call"** replaces "stay", which means nothing outside this project. The method `"stays"` becomes
  `"dwell"`, the argument `min_stay_h` becomes `min_dwell_h`, and voyages and port calls share all five methods.
  "Port" is still the place word. `rb_pad_harbour()` and `rb_read_harbours_mfri()` are not renamed.
- **d. The keys alike, at a rebuild.** `port_call_id` and `voyage_id` are used in ramb now. fishycode's tables take
  the same names (`port_call.parquet`, `port_call_id`, `voyage_id`) at a rebuild done as its own piece, because
  code and data change together. Until then the callers map ramb's names onto today's columns. `pid`, `pid1`/`pid2`
  and `.tid` keep a mapping, recorded in `docs/grammar.qmd`.
- **The port-call key per vessel** (follow-up, which overrides d's "per vessel-year" for port calls). A port call is
  not cut at New Year, so under per-year numbering a ping on 2 January in a call that began on 28 December would
  carry the previous year's number, and its own year would find the wrong call. `port_call_id` is therefore
  numbered per vessel by `T_in`, as fishycode's `stay` already is; the table keeps `year` (of `T_in`). `voyage_id`
  stays per vessel-year, because voyages are cut at New Year.
- **e. The trail keeps its voyage values**: `gid_voyage`, `s1_voyage`, `s2_voyage`, `gear_voyage_basis`,
  `.tid_voyage` and `n_tid_voyage`. They are a deliberate exception to 075's keys-only rule, so that the analyst can
  open the trail alone.

## What this supersedes

Decision 075's term **stay** ("the interval in port. Its values live only in the stay table, and pings carry a
key"). It is now a **port call**, with the same rule. The keys-only rule otherwise stands for port calls and
voyages, with the exception in e. `AGENTS.md` (Terms), `docs/grammar.qmd` and `docs/one_flow.qmd` say so.

## Built

- **ramb 2026.10.19.2** (a312781; NEWS.md lists every rename and the fishycode fix list). The twelve renames
  are below. The old names are aliases in `R/renamed.R`. Each warns once per session, takes the old argument names
  and gives the old result: `rb_find_trip_stays()` without `year` and `port_call_id`, `rb_assign_trip()` with
  `stay_port_id` and `stay_id`, `rb_create_timestamp()` a vector.

  | old | new |
  |---|---|
  | `rb_find_trip_stays()` | `rb_create_port_calls()` |
  | `rb_cut_trip_voyages()` | `rb_create_voyages()` |
  | `rb_cut_record_stretches()` | `rb_create_record_stretches()` (argument `stay` is now `port_call`) |
  | `rb_build_record_windows()` | `rb_create_record_windows()` |
  | `rb_build_record_pings()` | `rb_create_record_pings()` |
  | `rb_assign_trip()` | `rb_add_voyages()` (`stays` is now `port_calls`; adds `port_call_port_id`, `port_call_id`) |
  | `rb_assign_record()` | `rb_add_record()` |
  | `rb_assign_fishing()` | `rb_add_fishing()` |
  | `rb_assign_effort()` | `rb_add_effort()` |
  | `rb_link_trip_logbook()` | `rb_add_logbook_trip()` |
  | `rb_build_catch_units()` | `rb_add_catch_units()` |
  | `rb_create_timestamp()` | `rb_add_timestamp()` |

- **Port calls under every method.** `rb_create_port_calls(method = "dwell")` is the old stay rule. For `"runs"`,
  `"jepol"`, `"cnr"` and `"iapesca"`, a port call is the time in port between two of the method's voyages, at the
  port the first ended in, else the port the second began from. Where neither voyage reaches a port (a jepol split,
  a silence at sea), there is no port call between them. The registry, its test (a step's verb is `add` or `flag`;
  step 1 names `voyages` and `port_calls` where the other steps name their stage), the help, the articles that
  ramb owns, and ramb's `AGENTS.md` naming rule follow.
- **fishycode's callers**, on the new names and arguments, with today's columns on disk:
  `curate/port_stay.R`, `curate/ais_voyage.R`, `curate/station_window.R`, `curate/ais_catch.R`, `R/trail_sql.R`,
  `curate/voyage_gear.R`, `curate/checks/survey_tow_times.R`. The vessel overview's lane label reads "in port (port
  call)". They need ramb ≥ 2026.10.19.2 (`AGENTS.md`, "Which ramb"), installed after the commit; until then
  ramb 2026.10.16.1 was installed.

## Measured

- **ramb's full suite**: 136 tests and 802 expectations, none failed, none skipped, no warnings. This includes the
  new `test-renamed.R` and the tests of the other methods' port calls, which are checked against port calls built
  from the voyages in R, independently of the SQL.
- **Real data** (2023, 30 vessels spread over the vessel ids, 713,340 pings). Step 1 was run as `port_stay.R` and
  `ais_voyage.R` call it, under ramb 2026.10.16.1 with the old names and under the working tree with the new ones,
  each in a scratch library. The 1,356 port calls, the 1,254 voyages and the ping keys were identical between the
  two. From the stays on disk, the new code reproduces `curated/ais/voyage.parquet` and the `stay` and `voyage`
  keys of `curated/ais/ping` exactly for those vessels and that year, and its port calls match
  `curated/ais/port_stay.parquet`. The bodies of the steps 2-6 functions are the same as before the renames,
  except for the stretch function's renamed argument.

## Not done

- **fishycode's tables under the new keys**: `port_stay.parquet` → `port_call.parquet` with `port_call_id`, the
  ping and trail columns `stay` → `port_call_id` and `voyage` → `voyage_id`, and their readers (the vessel overview,
  `docs/ais_trail.qmd`, the checks). This is a rebuild of its own, kept in TODO 91.
- **ramb's `_pkgdown.yml`**, which belongs to another session's uncommitted work, still lists the old names in its
  reference index, so a pkgdown build fails until it lists the new ones. Done 2026-10-23 (decision 186).
- The one-call `rb_add_voyages(pings, method = …)` of plan 032 §4 was not built.
