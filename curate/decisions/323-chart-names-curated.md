# 323 — The sea-chart names in one curated table, 8,207 labels on nine charts; the chart windows in raw

*2026-11-15. Built and checked by Claude (AI) on plan 074's step 1b, at the maintainer's word ("Yes, start"; then, on the
scope, "I thought as long as we did have a list of all the örnefni, with coordinates and writing angle we would then just
need to build a single file from those"). The counts are measured; no person has checked them. No table the flow reads
changed.*

## What was done

- **The windows, one home.** The 2,351 chart windows the chart-name studies fetched from gis.natt.is (the WMS of
  Sjómælingar Íslands' charts, 1024 px at twice print scale), 915 MB, were moved from `archive/2026-11-04-chart-names-coast/
  img/` and `archive/2026-11-11-named-features/out/scale/*/windows/` into `raw/external/sjokort/<series>/` by
  `dump/sjokort/adopt_windows.R`, decision 295's way: each file's md5 checked before and after, a relative link left at the
  old path (none broken), `_manifest.csv` with each window's md5, size, time, source study, extent and chart share,
  `README-provenance.txt`. 63 windows held twice with the same bytes became links; none differed. The pilot study's windows
  (another grid) and the old charts' scans stay where they are. `dump/sjokort/fetch.R` fetches more on the same grid, the
  same requests (not yet run).
- **One table.** `reference/chart_names.R`, the targets `chart_names_frozen` (the nine frozen tables, `frozen_input()`) and
  `chart_names`, and `curated/reference/chart_names.parquet`: a row a label kept on a chart, keyed on (chart, label_id),
  with the name as frozen and as read, its kind and class, the text read, spaced or not, the writing angle (`runs_deg`) and
  length, the box's middle (lon, lat) and the box itself (WKB, WGS 84), the outcome and who settled it (`judged_by`), the
  corrections and hand boxes, the notes, the freeze's date and round. Written by `write_curated()`, stamped.
- **Who settled the 8,207 labels**: the maintainer 1,043 by answer or card and 1,203 seen on a chart he reviewed whole and
  left unmarked (1:2 000 000, 1:1 000 000, 1:300 000); Claude's look 475; the witnesses 287; the checks, confident and not
  judged, 4,307; no one, 892 land names kept as read. 5,036 distinct names.
- **His name check counted first**: his 312 answers on 1:100 000 (`65_name_check_map.R`) go into its freeze through 28, 311
  applied (the twelfth on a box since replaced), all "the right name"; on a box judged part of its lettering his "right"
  confirms the name and the box stays part (the Fljótagrunn piece, cut at a window seam, his note on it).

## Why

- **The lighter step.** Plan 074's 1b named five layers (raw, once, staging, curated, overrides). The frozen tables already
  hold the reviewed lettering, so the table is built from them; the read (a Mac's recognizer) and the freeze with its
  verdict files stay in the study, and a chart frozen again there rebuilds the table. Staging from the read and the
  verdicts as `overrides/` wait until the freeze itself is wanted in the pipeline.
- **The frozen tables read in the study's folder**, through `frozen_input()` (decision 075's way for a reviewed one-time
  output): moving them would break the study's scripts, and they are not raw data.
- **Each chart's own print**: a name on two charts is two rows (the maintainer, 2026-11-13).

## Checked

- The table against the frozen tables: 8,207 rows each side, none in one only, no name or outcome differing; no empty
  geometry; lon -30.3 to -1.0, lat 58.1 to 67.6.
- The windows: 2,351 in the manifest and on disk, every extent known, no broken link.
- `check_bookkeeping()`.

## Left

- Nothing reads the table yet: step 1c (each feature's place, across the charts) is its first reader; the place-name
  explorer and the maps may follow.
- The maintainer's name check on 1:100 000 is open (316 answered, regions not yet marked "gone through"); the other charts
  are not checked by him. A chart frozen again rebuilds the table.
