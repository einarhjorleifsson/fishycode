# 259 — The e-logbook's depth by the unit each app sends (plan 053 step 8)

*2026-10-30. Plan 054 step 2a, plan 053 step 8 (TODO 165). Coded and traced by Claude (AI) in a side session, not
checked by a person. The rows D1-D5 were reviewed by the maintainer on 2026-10-29 and 30. On main as bcb9db1. The
traces are in `$FISHYDATA/archive/2026-10-30-plan054-step2a/` (`draft-step8-depth-by-app.md`, `trace_step8*.txt`).
Nothing is built on the live store; the change rides rebuild A.*

## Why

Every fs_afladagbok and adb depth was read as fathoms and multiplied by 1.8288 (decision 022). The profile's rows say
that is wrong for some apps:
- Marína and Taktikal send metres (D2, decision 210's `fs_depth_units`, not built until now);
- STOKKUR sends 0 for none (D4);
- Reiknistofa's end depth copies the start (D5).

## Chosen

- **`depth_by_app()`** (`R/logbook_app_profile.R`) reads the rows by the station's app, feed and date, in the merge's
  section "Depth by app", once the station knows its app.
- **D2:** metres, × 1, basis `recorded`.
- **D1, D3, and any app no row names:** fathoms, × 1.8288, basis `reconstructed`, as before.
- **D4 and D5:** flagged and read as none, basis `none`, with `z1_flag` "default_zero" and `z2_flag` "end_copy" and
  their rule and action.
- **The value as sent** stays in `z1_raw` and `z2_raw`. The station gains `z_unit` and the depth flags.

## Checked on a scratch store

Main's lean merge with step 7, and this branch's, were built from the same staging, in about a minute each.
- **Five of the six files are equal** on every shared column.
- **`station.parquet`:** 54,961 rows differ, each in one outcome by app and rule:

  | app | rule | stations |
  |---|---|---:|
  | Marína raun | D2: metres | 19,077 |
  | FRA TAKTIKAL | D2: metres | 6,851 |
  | Marína, Taktikal | D2: a depth of 0, the basis only | 161 |
  | STOKKUR | D4: none | 23,136 |
  | Reiknistofa | D5: the end none | 5,736 |

  No afli or aflaskeyti row changes.

## Left

- `z_unit` "uncertain" for the vessels D2 and D3 note (Taktikal 37, Reiknistofa 34) needs a frozen list from the GEBCO
  witness. Not made.
- `docs/data-dict.yaml`, with rebuild A.
