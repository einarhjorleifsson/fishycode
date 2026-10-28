# 236 — The vessel overview as a named bundle on MFRI's share: every vessel from 2024 on, no photos

*2026-10-28. The maintainer: colleagues who have seen the vessel overview ask how to run it on their own computers; a
bundle of the data from 2024 on, put on the institute's share, "leave the vessel image out", and "the default time
window should be set to the 2024-2026 range at startup". They asked for it to be kept light ("do not dig deep"). Built
and written by Claude (AI); the numbers come from its runs, and no person has checked them.*

## Done

- **`products/exports/vessel_bundle.R`** writes `$FISHYDATA/exports/vessel_overview_<year>/` (`index.html`, `data/`,
  a README for colleagues). `Rscript products/exports/vessel_bundle.R 2024`; a second argument, a list of vids, makes a
  test build in `..._test/`. It is decision 153's bundle mode, named:
  - The vessels: every vid with a ping, a logbook trip (by its return) or a landing from the year on.
  - Each answer is the service's own (`api.R`: its SQL and column allowlist) for the years from 2024 to the trail's
    last, so the page reads the bundle as it reads the service. The latest landing and trip, their hauls and the
    landings' links are those from 2024 on; the History tab's effort and cells too.
  - Kept: names, call signs, MMSI, the register and its history to 2023-12-19, owners' names included. Never kennitala,
    addresses or phones (`PERSONAL`). Left out: the photos. The list's first year on AIS is the vessel's own, not 2024.
- **The page** (`products/vessel_overview/www/`): a meta tag `bundle-names` = `shown` makes a bundle named. Without it a
  bundle stays anonymised as before (no register, call sign or MMSI, no Vessel tab). Any bundle now opens on its whole
  window (`win` = `range`), loads it whole, and greys out the year pickers, since it holds one window; the photo panel
  says the photos are left out. The service's page is unchanged.

## Measured

- **2024 on:** 94 M pings (2024 33.0 M, 2025 37.4 M, 2026 23.5 M) of 1,829-1,909 vessels a year; 2,162 vessels in all.
- **The build:** 31 minutes, 2,163 files, 2.2 GB (2,231.7 MB). The largest, vid 2917, is 13 MB.
- **Opened as a file** in headless Chrome: vid 2917, 394,404 pings in 0.8 s; vid 1977, 388,428 in 0.75 s; vid 2652
  (pings in 2024 only). The window runs 2024-01-01 to 2026-10-16, the Vessel and History tabs load, no console error.

## Not settled

- **Edge and Firefox on Windows, and opening it from the share,** are untested. It needs the internet: the libraries
  come from jsdelivr, the map from Esri.
- **Who may read it** is set by the share folder's permissions: MFRI staff only (gagnastefna), since it holds owners'
  names. The maintainer copies it there.
- **The 2018 demo** (`vessel_demo_2018-06/`) still holds the page as it was built; rebuild it to take this one.
- **`b64()`, `write_js()`, `read_text()` and `swap()`** are copied from `vessel_demo.R`: two builders share them now.
