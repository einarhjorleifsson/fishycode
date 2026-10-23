# 210 — fs_afladagbok's tables and the gear detail: the tour app replaces STOKKUR, mammals and birds as a table with every measure, gear parts as recorded

*2026-10-23. The maintainer's answers to plan 019 §6 and plan 020 §5 (TODO 73), asked by Claude (AI) in a status
review of the repository. The plans' numbers are Claude's of 2026-10-15, not yet checked by a person. Nothing is
built.*

## Plan 019 (fs_afladagbok by the grammar)

1. **The tour app replaces the `STOKKUR` copies** (2020-01 to 2022-03): as the more upstream layer (plan 037), with
   decimal positions and hours at sea where `STOKKUR` has whole degrees and no effort. Its 9,821 trips that never
   reached fs_afladagbok (9.9 kt, 85 % landed) are staged, flagged and each classed, then admitted per class, as decision
   189 treats afli's never-loaded records.
2. **The port translation is a reviewed override** in `overrides/`, like `stk_hid_pid.csv`: derived once, reviewed, and
   a new code drafted and reviewed when it appears.
3. **Implausible catch is flagged against the trip's landing:** a haul's kilograms of a species above the trip's landed
   kilograms of it by a margin; with no landing, against the gear and species' own distribution. Never corrected.
4. **Mammal and bird bycatch becomes a table, `protected_bycatch`,** one row per station and taxon, with every measure
   the source holds (count, and length and sex where `ws_medafli` has them), each with its basis, as the grammar's
   observation; implausible counts flagged. The maintainer: this follows the grammar, and opens commercial sampling (a
   sample from a trip or haul, then measured), a pending step now TODO 134.
5. **`rekjanleiki_id` is measured:** whether it matches anything in the dumped schemas; kept on the trip as recorded
   until known.
6. **fs depth by a declared correction, `fs_depth_units`:** the Trackwell apps converted from fathoms, Marína and
   Taktikal kept, the mixed apps' stations classed against GEBCO per vessel-period as `afli_depth_units` does; the
   original kept, the basis of a unit conversion `recorded` (the grammar's rule).

## Plan 020 (gear detail and environment)

1. **A jig's hooks as recorded:** a part `hook_per_jig`; the total (jigs × hooks) derived when wanted.
2. **`medal_lengd_neta`'s unit is measured first**, against the net counts and usual gillnet lengths, and written with
   its evidence in the overlay (plan 040).
3. **fishing_sample's `g_*` columns** (`g_mesh`, `g_width`, `g_height`, `g_length`, whose units and meanings change with
   the gear) stay one release beside `gear_part`, then go.
4. **Grid types** are mapped to a short code list, with the text as entered beside it.
5. **`environment`** is built with plan 037 phase 2, from afli's right layer.
6. **The free-text notes** stay in staging, and every note is classified in a read-only study started the same day: a
   first count found two trawls and partner vessels, catch pumped between vessels (the missing piece of decision 199's
   transfer trips), gear trouble and lost gear, MFRI samples, and released catch (halibut, Greenland shark, birds). Its
   structured values become proposed columns in staging, basis `derived`.
