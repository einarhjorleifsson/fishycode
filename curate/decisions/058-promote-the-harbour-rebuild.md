# 058 — The harbour bootstrap is re-run from the full trail, and its output promoted

*2026-10-01. Decided with the maintainer in the harbour/port session of plan 011
(§4b). Supersedes the "never re-run" part of decision 005; the rest of 005 (the
polygons are an input, not recomputed on a schedule) stands.*

## What was done

`reference/ports/bootstrap_iceland_faroe.R` was repaired and re-run against
`raw/ais/stk/trail` (all years). Its output replaces
`raw/ports/ports_iceland_faroe.gpkg`; the first bootstrap's file is kept at
`raw/ports/archive/ports_iceland_faroe_2026-09-21_first_bootstrap.gpkg`. The script now
refuses to overwrite the artifact. `curate/corrections/ports_iceland.R` is reduced to
a rename (`pid` → `pid_bootstrap`) and assertions that the fixes held.

## Measured against the first bootstrap

- 159 polygons (157 corrected + `IS-ANV` Álfsnes and `IS-HRN` Hornvík). No overlaps.
- 36 of the 157 grow (more years of `I` points), none shrink; every old polygon is
  covered by its new one.
- `IS-HVK` (Hólmavík) moved 90 km: the first bootstrap built it from the raw STK code
  `HVK`, which is Hornvík (66.4N). `IS-STK` (Stokkseyri) was a Stykkishólmur berth
  (typo `"STK2"` for `"STY2"`); `IS-STY` now holds that berth.
- STK codes `HOL`/`HK` → `IS-HVK` (Hólmavík), `STO` → `IS-STK`; `TMY` (one event)
  dropped; `VIS` left unmatched.

## Why it is still not circular evidence

It is the same source and the same circle described in 005: STK's per-ping harbour
flag drawn as a hull. The difference accepted here is only that there is more of it and
that known producer bugs are fixed. Independent geometry remains the way to break the
loop.

## Consequence

`ports_all.R` no longer chains two `einar` harbours into one `pid` (a cluster holding
several is split; Kópavogur, Viðey, Gufunes and Álfsnes were all `IS-REY`). The AIS
chain (`ping_tagged` onward) still uses the previous polygons until Phase 4 of plan 011.
