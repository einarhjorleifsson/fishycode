# The bathymetry map: a kit to run it in R

The seabed around Iceland from Olex's 50 m depth grid with GEBCO (Julian Burgos, MFRI), on an interactive map in your
browser: the depth in colour, the relief shaded, contours, and the place names of MFRI's gazetteer. Each of the depth's
colours, the contour levels and the shading's intensity can follow the view as you move, or stay as you set them.

**For use inside MFRI only.** The place names include names from Trackwell's hauls and fishermen's plotters, which are
not public. Do not pass the kit, or screenshots of names, outside MFRI.

Prepared with AI assistance (Claude) from fishycode's `products/bathymetry_map/` (TODO 185, plan 063); `VERSION` says
which commits it was made from.

## What is in the folder (about 2.7 GB)

- `data/` — the elevation tiles (`depth.mbtiles`), the 50 m depth grid at three levels, the place names
- `code/` — the map's R code, `start.R`, and an RStudio project
- `ramb/` — the ramb package: a source package, and a binary for a Mac with Apple silicon and R 4.5
- `VERSION` — when and from what the kit was made

**Copy the whole folder to your own computer first.** It runs from the share too, but every move of the map reads from
the disk, and a local disk is much quicker.

## Install, once

In R (RStudio or the console):

```r
install.packages(c("DBI", "duckdb", "RSQLite", "httpuv", "jsonlite", "nanoparquet", "sf", "dplyr", "dbplyr",
                   "lubridate", "purrr", "Rcpp", "readr", "rlang", "stringr", "tibble", "tidyr"))
```

Then ramb, from the kit's `ramb/` folder. Open `code/bathymetry_map.Rproj` (in RStudio) so that R starts in `code/`, then:

- **Mac with Apple silicon and R 4.5:**

  ```r
  install.packages(list.files("../ramb", "[.]tgz$", full.names = TRUE), repos = NULL, type = "binary")
  ```

- **Any other computer** (Windows, an Intel Mac, another R): from source, which needs a C++ compiler (Rtools on
  Windows, the Xcode command line tools on a Mac):

  ```r
  install.packages(list.files("../ramb", "[.]tar[.]gz$", full.names = TRUE), repos = NULL, type = "source")
  ```

## Run

Open `code/bathymetry_map.Rproj` in RStudio and run:

```r
source("start.R")
```

Without RStudio, start R in the kit's `code/` folder (or `setwd()` there) and run the same line. The map opens in
RStudio's Viewer or your browser, at `http://localhost:8798`. It answers while the R console is idle.

- Another place to start: `bathymetry_map(center = c(-22.5, 64.3), zoom = 9)` (Faxaflói),
  `bathymetry_map(center = c(-23.0, 66.15), zoom = 9, lang = "is")` (Ísafjarðardjúp, in Icelandic)
- Stop it: `bathymetry_map_stop()`
- Port 8798 taken: `bathymetry_map(port = 8799)`

## On the map

- **Depth:** the palette, floor and cap, scale (log, linear, equal shares), a ramp or the charts' depth bands, a cut of
  the shallowest water (poorly covered under 10-20 m), opacity. "Follow the view" fits the colours to what is on the
  screen each time the map settles; setting the floor or cap by hand stops it.
- **Contours:** spaced by depth and zoom, or "levels from the view": about a dozen lines where the view's area is.
  Their depth labels show from zoom 11.
- **Relief:** the shading's method, the light's direction and height, intensity, opacity and colours; "intensity from
  the view" shades gentle seabed harder.
- **Depth by cell:** off at first; on, a click on a cell gives its depth.
- **Place names:** one label per place, its proposed name; a click gives the name's sources and its other spellings.
- The link button copies the view, with every setting, as an address. It opens only where the kit runs (localhost).

## When something is wrong

- A blank map that says "loading tiles…": the browser window may be hidden or minimised; the map draws only when shown.
- An error about `FISHYDATA`, or a file not found: R is not in the kit's `code/` folder.
- An error installing ramb from source: the compiler is missing (see above).
- Anything else: Einar Hjörleifsson.
