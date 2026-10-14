# 089 — The trail rebuild of 2026-10-14: station events, afli's early tow starts, a fixed ping choice

*2026-10-14. Rebuild and comparison run by Claude (AI-assisted), on the maintainer's request to do TODOs 54 and 55
and rebuild the trail. fishycode 2660738..6207a75, ramb 2026.10.14.1 (79aab8a, committed, not pushed: held by the
maintainer, TODO 56). Logs, scripts and fingerprints are in `$FISHYDATA/archive/2026-10-trail/`. Closes TODOs 54
and 55.*

## What was run

- **Before:** 846 files, 3,453,806,694 rows: the state after decision 086.
- **First pass:** `afli`, `ais_ping_clean` and `ais_trail` were invalidated by hand, because `targets` cannot see
  edits to their scripts. 18 targets rebuilt, 06:35–07:42 UTC, with no stops. `station_event` ran with the nearest-fix
  rule.
- **Second pass:** the maintainer changed the rule to a start taking the next fix and an end the previous
  (decision 088). With ramb 2026.10.14.1, `station_event` was invalidated and 4 targets rebuilt, 07:46–08:07 UTC.
- **After:** 847 files, 3,460,950,411 rows, and `tar_outdated()` at 0.
- **Step times:** `ais_trail` 20.3 min, `ais_ping_clean` 19.0, `ais_voyage` 14.1 (TODO 48's check is 10), `port_stay`
  5.5, `afli` 2.8. `station_event` took 25 s.

**Stamps.** 305 files of the second pass carry `fd.dirty = true` at commit 6207a75: most of `ais/trail` and
`trail_match`, and the two trail checks. While they were being built, Claude edited `TODO.md` and plan 013, which
are tracked documents. The code that built them is exactly 6207a75. The stamp records that the tree was dirty, not
which file was. **Restamped the same morning** (maintainer's go): `ais_trail` and its two checks were rebuilt from the
clean tree at 7e873dc (08:13–08:36 UTC). The 456 files are identical in rows, schema and all 13,639 column hashes,
and only the stamps changed. Every file of this rebuild is now stamped clean (456 at 7e873dc, 137 at fab4052,
`station_event` at 6207a75).

## Identical

Stays, voyages, `trip_voyage`, `lid_map`, both catch-by-species tables, the logbook trip, catch and gear tables, and
every reference. `station_type` (decision 084) is unchanged.

## Changed, and why

| output | change | cause |
|---|---|---|
| `staging/ais/ping_clean` → `curated/ais/ping` → trail | `speed`, `speed_raw`, `heading` in about 90 files; the vid, time and position hashes unchanged | TODO 55: a total order before the filters, so the kept reading of a same-position pair is fixed |
| `staging/afli/fishing_sample`, `curated/logbook/fishing_sample` | t2, t3, `.checks` | decision 087: tow starts 00:00–00:59 kept |
| `staging/afli/depth`, `curated/logbook/station` | z1, z2 and their basis | the restored t2 changes the within-day order of the depth correction's switch scan: the mechanism of decision 086, finding B2 |
| `station_window` | 7,494,007 rows, same count; windows changed | the restored tows: a tow window in place of a day window |
| `trail_match` | 190,783,745 → 186,935,616 | a tow window claims fewer fixes than a day window. By basis: recorded +2,241,991, synthesised −6,100,889, capped +10,769, derived unchanged |
| `ais/trail` | station columns; new `nearest_event` | the windows; decision 088 |
| `curated/link/station_event.parquet` | new, 10,991,846 rows | decision 088 |
| `check/trail_agreement`, `check/trail_sid_coverage` | counts | the trail |

Nothing else differs.

## `station_event` on the full data (the bounding fix)

- **Event times:** 6,765,999 recorded, 4,216,961 derived (afli's tow end) and 8,886 flagged `suspect_clock`.
- **With a fix within the hour:** 2,595,394, 994,398 and 3,448 of them. Most afli events predate the AIS record.
- **Distance to the bounding fix:** the median is 150–260 s by source and event.
- **Hauls:** 4,398 of the 263,489 with both a t3 and a t4 fix (1.7 %) hold no fix inside, so their labels cross.
- **No setting has both t1 and t2:** static gear does not report t2, and towed gear has no t1.
- **The trail:** 3,510,654 fixes carry a `nearest_event`, and 57,953 of them bound two events or more.

**Provisional.** The maintainer and Claude agreed on 2026-10-14 that the time reconciliation needs voyage-wide
boundary finding first (plan 013 phase 4, TODO 56). `station_event` stays as the declarations' anchor. Its role on
the trail is decided after that exploration, so its labels are not to be read as the reconciled tow boundaries.
