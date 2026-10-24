# 228 — The effort map shows the fixes as recorded or interpolated, by a switch

*2026-10-24. The maintainer, on the effort grid being interpolated always (decision 220): "user should be able to have
a choice to show the original data vs the interpolated data". Built, measured and written by Claude (AI); not checked
by a person. The switch was checked on the server first, and clicked in the page later the same evening (checklist
F6, its run log).*

## What was built

- **A second base grid:** `Rscript products/effort_map/grid.R fixes` writes `grid_fixes.parquet` and its 0.005-degree
  copy beside the interpolated grid, each fishing fix's hours in the cell of the fix itself. It is the same script,
  with no spreading (`MAX_GAP_MIN = 0`, and a fix whose next fix has the same second is not spread either).
- **The switch:** an "Interpolation" filter of the effort layer (`map.json`), "on" by default, so the page and every
  link look as before. "Off" reads the fixes grid (`map.R`). It goes into the address as `interp=off`, and from R as
  `effort_map(interpolate = FALSE)`. The page leaves it out when the fixes grid is not built.
- **The checklist's F6**, passed in the page: off draws the scattered fixes, on the tows as lines (zoom 11, 2025).

## What was measured

- **The totals are the same either way:** hours, kW-hours and fixes are equal in the two grids under both presets
  (`fishing` 9,154,737 hours). `grid.R`'s own check holds for the fixes grid: in 731 of 731 preset-gear-years its
  hours, kW-hours and fixes are the trail's.
- **Interpolation moves the hours, it does not add any:** the same `fishing` hours lie in 239,855,410 cells
  interpolated against 76,200,947 cells of fixes alone.
- **The fixes grid** is 1.36 GB, plus 480 MB for its copy, built in about 2.5 min. Its tiles are faster: on the same
  16 tiles at zoom 6-9, a median of 253 ms against 353 ms, and at most 461 against 591 ms.

## Not done

- **The fixes grid is rebuilt by hand** after a rebuild of the trail, like the interpolated one (TODO 140).
