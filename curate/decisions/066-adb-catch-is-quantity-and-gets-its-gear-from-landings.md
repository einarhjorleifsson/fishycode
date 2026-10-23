# 066 — adb catch is `quantity`, adb gear comes from the landing, and the catch is also kept as whole weight

*2026-10-03. Closes TODO 20. Adds `target`, `target2`, `s1`, `s2` to the trail. The gear half superseded 2026-10-20 by
decision 154: adb's code is the old code, read through adb's own table, and the landing's gear wins where it names
one.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person). "`catch_round` for
afli is therefore `recorded`" below does not hold: on gutted items afli's `afli.afli` holds round(gutted × 1.25), a
computed whole weight, and the weight as logged and its state are in the message the logbook sent (TODO 114, parked
for plan 037).*

## Found

- adb's `weight` is fs_afladagbok's `afli` (whole-fish weight) and `quantity` is fs's `magn` (weight in the state `condition`/`astand` names): equal on 100 % of the
  1.39 M (station, species) rows the two share. fs stopped filling `afli` in 2023 (97-99 % NULL) and adb copied that. `sources/adb/convert.R` summed `weight` with
  `na.rm`, so most 2026 trips got catch 0; `lid_map` keeps `catch > 0`, so 3,937 of 4,962 adb trips were never matched to a landing, 3,913 of them having one within a day.
- Condition codes: GUTT = S, UNGU = O, RELE = L (cross-tab on shared rows). GUTT weight is 0.80 of whole weight (5-95 %: 0.789-0.80); UNGU and RELE are 1.00.

## Done

- `sources/adb/convert.R` and `sources/fs_afladagbok/convert.R` write `catch` (as recorded), `catch_whole` (NA, not 0, when never recorded) and `condition`, one row per (.sid, sid, condition).
- `curate/corrections/adb_gear.R` (side table, `gid_basis = "reconstructed"`): adb stations take the gear of the landing their trip matched, when it names one gear. After the
  catch fix 20,274 of 20,530 stations have one (54 % before). No crosswalk fallback; the 256 left are trips with no unambiguous landing.
- `curate/catch_by_species_station.R`: `catch_round` (whole weight; GUTT / 0.8 where `catch_whole` is missing, basis `reconstructed`), `catch_recorded`, `catch_released`,
  one row per (.sid, schema, sid); the way onto the trail is `(.sid, schema)`. The afli schema does record whole weight: on 167,320 (vessel, date, species) shared with fs_afladagbok it equals fs whole weight in 99.6 % of 166,713 comparable cases, and GUTT weight x 1.25 (median 1.250, 93 % within 0.03) / UNGU weight x 1.00 otherwise. `catch_round` for afli is therefore `recorded`.
- Trail: `target`, `target2` (from `reference/gear`, via `station_window`) and `s1`, `s2` (the speed range `fishing` is tested against), filled when `n_sid == 1`.
- `curate/station_window.R`: for adb stations of a towed gear, t1/t4 become t2/t3 (fs convention; adb t1 = fs t2 and adb t4 = fs t3 on 100 % of the shared
  OTB, OTM, DRB and SDN stations). Before, adb's raw start/end sat in t1/t4, which a tow window ignores, so all 15,343 adb towed stations of 2026 were whole-day windows;
  now 594,454 fixes of the 2026 trail are in a tow window (87 % `fishing`). The other 1.57 M day-only towed windows are afli: Danish seine (SDN, 84 % of its stations)
  and the pre-2014 logbooks recorded no times.

## Not done

- The trail itself is not rebuilt: `station_window` and `ais_trail` are outdated (`tar_invalidate(ais_trail)` is also needed, targets cannot see `R/trail_sql.R`).
- fs `catch` stays `magn`, a mix of gutted and whole weights; use `catch_by_species_station.catch_round` for a whole-weight total.
