# 207 — A logbook haul end holds what was reported: a point with its precision, a cell, or nothing; the ambiguous kinds judged against the AIS track

*2026-10-23. The maintainer's answers to TODO 126, asked by Claude (AI) in a status review of the repository, on the
study of 2026-10-22 (`$FISHYDATA/archive/2026-10-afli-minutes60/`, scripts 01-10), measured by Claude with the
maintainer and not yet checked by another person. Nothing is built.*

## Chosen

- **Each haul end is one kind:** a point with its precision; a cell (whole degree, statistical rectangle, quarter) with
  lon/lat NA and the cell recorded; or nothing, basis `none`. A derived centre only in a column of its own, never in
  lon/lat, and a per-row column naming the kind and the precision.
- **The formats live in the overlays:** each source's position format and precision by app and period in
  `dump/oracle/meta/<schema>.yml` (plan 040 phase 2), with a new fs_afladagbok overlay, and per-app checks in
  `curate/checks/`.
- **The ambiguous kinds are judged against the vessel's AIS track that day**, read-only, as a diagnostic (logbook
  positions never join the track): whole degrees (STOKKUR 2021-22: corner or midpoint, truncated or rounded), afli's
  rectangle-centre fills of the 1990s, afli's 61-99 "minutes", and Marína's hundredths and its 59 longitudes too long
  (decision 165). A side session started the same day; its result goes into the overlays and a decision of its own.

## Left (TODO 126)

The AIS check's result; then the representation built in the adapters and the merge as a step of the logbook batch,
`R/logbook_position.R` with it.
