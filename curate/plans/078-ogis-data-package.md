# 078 — ogisdata: an internal R package with the depth model and the effort, so an ogis map needs no path

**status:** proposal — written 2026-11-19 at the maintainer's word ("Yes, write it"), from the maintainer's idea of the
same day, after a trial the same morning; asks a and b answered the same day ("call the package ogisdata";
"placenames - not now", so the depth model and the effort alone); §3.3 revised the
same day at the maintainer's word: ogisdata a package folder of its own, whose `data-raw/` copies the files in from
`$FISHYDATA`; ask e answered the same day: installed as mardata is, from its folder on the share (osmx's README, §3.4);
a demo script added the same day at the maintainer's word, its maps tried on this Mac, which found an ogis fault
(§3.7); nothing built; asks c, d, f, g and h need the maintainer. **Measured** (by Claude, 2026-11-19, on the maintainer's Mac,
R 4.5.2, ogis 2026.11.18.17): a throwaway package holding fishycode's `depth.mbtiles` builds, installs and is found by
ogis with no path (§2). **Assumed, not measured:** installing ogisdata from the share over MFRI's network, about 0.93
GB, five times mardata (174 MB installed); Windows, though mardata installs there the same way; that colleagues have
about 2 GB free while it installs; that the share can limit who reads it · **see:** TODO 204, TODO 205, decision 330,
`$FISHYDATA/archive/2026-11-18-depth-model-in-ogis/report.md` §3 and §5, osmx's README
(https://github.com/einarhjorleifsson/osmx)

Drafted with AI assistance (Claude) on 2026-11-19; a person has not yet checked it. What §2 calls measured, Claude
measured.

## 1. Why

ogis's `og_relief()`, `og_contour()`, `og_cells()` and `og_names()` read, with no argument, the files named by
`OGIS_DEPTH`, `OGIS_CELLS` and `OGIS_NAMES`, each a line in a person's `.Renviron`. That spares a shared script its
paths, but every colleague must still get the files and write the lines, and write them again when a file moves. The
maintainer's idea (2026-11-19): a small R package holding the files as they are, in `inst/`, on MFRI's server,
installed with `remotes::install_local()`, "so they do not need to remember any path when it comes to creating ogis
maps".

**The depth study of 2026-11-18 said no to this** (its option G: "possible, but the wrong vehicle"): 0.17-0.54 GB in
every R library, updated by reinstalling, and once there is a host ogis can read from it. That verdict was too strong,
for three reasons it did not weigh:

- **The effort.** `og_cells()` queries a Parquet file through DuckDB in R. The study's route, option C (TODO 204), is
  the depth's tiles in a bucket for the browser; nothing comparable is studied for the effort.
- **Who option C reaches.** A bucket readable from MFRI's network only leaves out ship crew and VPN users whose
  traffic does not pass through MFRI (the study's §4.3). An installed package works offline, at sea included.
- **What option C costs.** IT's work (a bucket, its policy, CORS, a role) and one to two days in ogis. The package
  needs neither, and ogis stays as it is (§2).

The two routes do not compete: the package is for R users now; the bucket, if it comes, is for pages with no R behind
them, and the package can then hand ogis the depth's address in place of its file (§3.6).

Two precedents. **mardata**, MFRI's data package behind the survey dashboard of osmx, not public, is installed inside
MFRI's firewall from its folder on the share: `remotes::install_local("R:/R/Pakkar/mardata", force = TRUE)` (osmx's
README); on the maintainer's Mac it is 174 MB installed, from `/Volumes/u2/reikn/R/Pakkar/mardata`, the same folder
mounted. And the bathymetry map's kit (TODO 185, `products/bathymetry_map/kit.R`) went to colleagues through a share,
2.6 GB with its own copy of the map's code and ramb. ogisdata carries data only, and goes the way mardata goes.

## 2. Measured: the trial (2026-11-19)

How: a package `ogistrial` in the session's scratchpad, its `inst/extdata/` holding a clone of
`$FISHYDATA/products/bathymetry_map/depth.mbtiles` (546,840,576 bytes) and an `.onLoad` of three lines that sets
`OGIS_DEPTH` to the installed file when the variable is empty. Built with `R CMD build`, installed with
`R CMD INSTALL` into a library of its own, and read from Rscript with an empty `.Renviron`. Deleted with the
scratchpad.

| check | result |
|---|---|
| `R CMD build` | 12 s; the tarball 544 MB (gzip saves 0.5 %: the tiles are WebP already) |
| `R CMD INSTALL` from the tarball, on local disk | 6 s; 547 MB installed |
| `library(ogistrial)`, then `og_tiles_mbtiles()` and `og_map() \|> og_relief()`, no path given | the installed model read; ogis says "Tiles from …/ogistrial/extdata/depth.mbtiles (OGIS_DEPTH)" |
| `OGIS_DEPTH` already set by the person, then the package loaded | the person's path kept |
| a tile at zoom 5 over Iceland, the installed package made read-only | read, 202,840 bytes (ogis opens MBTiles read-only) |

The files the package would hold, by size: the depth model 547 MB; the effort, as the trial of decision 330 wrote it
for `og_cells()` (the 0.005° grid, the `fishing` preset, gear, year and cell, no vessel), 381 MB. About 0.93 GB in
all, in every library it is installed in (the place names, 1.9 MB, are left out for now: ask b). Not measured: how
long that takes from the share.

## 3. Design

### 3.1 What it holds

Two files in `inst/extdata/`, as fishycode's products write them: `depth.mbtiles` (from
`products/bathymetry_map/dem.R`) and the effort for `og_cells()` (built by TODO 205, with its data dictionary in the
Parquet metadata). No code beyond §3.2, no compiled code, no copy of ogis. The place names for `og_names()` are left
out for now (ask b); they would come in as a third file, read the same way through `OGIS_NAMES`.

### 3.2 How ogis finds them

- **`.onLoad` sets `OGIS_DEPTH` and `OGIS_CELLS`, each only when it is empty**, so a person's own `.Renviron` still wins. ogis
  reads them at each call (`Sys.getenv()`), so a script needs one line, `library(ogisdata)`, and no path.
- **Two path functions** (`depth_file()`, `cells_file()`) for an explicit call
  (`og_relief(ogisdata::depth_file())`) and for use outside ogis: the effort opened with DuckDB, say.
- **`files()`**: one row a file, with its bytes, md5, the date it was built and the fishycode commit it was built
  from (the Parquet files' `fd.*` stamps; the depth model's from its build). A map's maker can then say which effort
  it shows.
- **One startup line**, the package's version and the effort's build date, so a stale install is seen.
- **ogis does not change, and does not learn of the package.** It stays general (ogis's `AGENTS.md`).

### 3.3 Where it is built

ogisdata is a package folder of its own, beside ogis (`~/R/Pakkar/ogisdata`, ask g), not inside fishycode: its
`inst/extdata/` holds the data, and nothing is written into fishycode's tree. Its `data-raw/` holds the scripts that
copy the files in from `$FISHYDATA` (the maintainer, 2026-11-19: a `data-raw` folder whose scripts "copies" the data
from fishydata to ogisdata), as usethis lays out a package's data:

- **`data-raw/files.R` copies the two files as they are**, a clone on APFS so no second copy on disk, and writes
  their provenance to `inst/extdata/files.csv`, which `files()` reads. For the Parquet files that is their `fd.*`
  stamps; for each file, its bytes and md5.
- **It makes nothing.** The effort file is built by a fishycode `products/` script (TODO 205); a change to what is
  in it is made there.
- **It bumps the version** in `DESCRIPTION` (`YYYY.MM.DD`, `.1` for a second build in a day, as ogis) and adds a NEWS
  line naming the files' builds.

Then `R CMD build`, the package's tests (§2's checks from a temporary library: the variables set, a person's own
kept, each file read through ogis, skipped where ogis is absent), and the filled folder, without `.git`, copied to
the share by a script in `tools/` (§3.4). `data-raw/` and `tools/` are in `.Rbuildignore`; `inst/extdata/` is in
`.gitignore`, so the folder's git holds code only. Rerun after each rebuild of the products it carries.

### 3.4 How colleagues get it

As mardata (the maintainer, 2026-11-19, pointing to osmx's README): the package's folder on the share, beside
mardata's, and inside MFRI's firewall a colleague installs it with

```r
remotes::install_local("R:/R/Pakkar/ogisdata", force = TRUE)
```

- **The first install and every update are the same line.** `force = TRUE` installs again whatever version is in
  the library; the startup line (§3.2) shows which one a person has, and the README names the latest.
- **remotes builds the package from the folder first**, so the 0.93 GB are read from the share and written twice on
  local disk (the tarball, then the library). If that proves slow on Windows (step 3), a built tarball beside the
  folder is installed by the same function and skips the build.
- **ogis itself** is installed as its own README says.

Each install copies about 0.93 GB into the person's library, and again after each R minor version (a new library).

### 3.5 What stays internal

The depth model and the effort are internal (ogis's rules). The filled package lives on MFRI's share alone, inside
its firewall: never GitHub, r-universe or a public host, and a bundle made from it (`og_bundle()` copies its tiles) is
internal too. Its source folder's git holds code only, with no public remote (ask g).
The effort is summed over vessels, but at 0.005° a cell may hold one vessel's fishing; who may read the share is ask
d, under MFRI's gagnastefna.

### 3.6 With the bucket later

If TODO 204's bucket is built and ogis gains its tile address, the depth model may leave the package: `.onLoad` sets
its address instead, and the package shrinks to the effort. Nothing in §3.2 needs to change for a
script.

### 3.7 A demo script

The maintainer, 2026-11-19: "a demo script that shows how to plot the depth and the effort map via ogis within the
ogisdata package". It is `demo/maps.R` (listed in `demo/00Index`), so a colleague runs it with
`demo("maps", package = "ogisdata")`, or copies it to edit, as its head says. Each map is served when it is printed at
the console and opens in RStudio's Viewer or a browser (ogis's `print()`); the choices in a call can be changed again
in the page's sidebar.

```r
# The depth model and the fishing effort on ogis maps, from ogisdata.
#
# Run it:   demo("maps", package = "ogisdata")
# Copy it:  file.copy(system.file("demo", "maps.R", package = "ogisdata"), "maps.R")
#
# A map opens in RStudio's Viewer or a browser when it is printed at the console. Every choice
# made in a call (colours, gear, years) can be changed again in the page's sidebar.

library(ogis)
library(ogisdata)   # tells ogis where the depth model and the effort are: no path below

iceland    <- list(bounds = c(-30, 62, -8, 68.5))
westfjords <- list(center = c(-24, 66.4), zoom = 7.5)

# 1. The depth: colour, shading and contours. The contours are the charts' isobaths (10, 25, 50,
#    100, 150, 200, 300, 400, 500, 1000 m and deeper), heavier and labelled, with finer lines
#    between them that close up as you zoom in. The map opens off the Westfjords, where both
#    show; over all of Iceland only the 500 m lines do.
og_map(title = "Depth", view = westfjords) |>
  og_relief() |>
  og_contour()
# the same contours, spelled out:
#   og_contour(major = c(10, 25, 50, 100, 150, 200, 300, 400, 500, 1000, 1500, 2000, 2500,
#                        3000, 4000, 5000),
#              minor = TRUE,    # the finer lines between
#              labels = TRUE)   # the depth on each heavier line

# 2. The fishing effort over the depth, the contours on top: hours per km², every gear and year
og_map(title = "Fishing effort", view = iceland) |>
  og_relief() |>
  og_cells(name = "Fishing effort") |>
  og_contour()

# 3. One gear and a span of years when the page opens: bottom trawl, 2015-2024
trawl <- og_map(title = "Bottom trawl, 2015-2024", view = iceland) |>
  og_relief() |>
  og_cells(name = "Fishing effort", filter = list(gid = 6, year = c(2015, 2024))) |>
  og_contour()
trawl

# 4. The files the maps were drawn from, and when fishycode built them
files()

# 5. A map as a folder that opens from its index.html, with no R. It carries the data, so it
#    stays inside MFRI.
# og_bundle(trawl, "bottom_trawl_map")
```

**Tried 2026-11-19** (by Claude, on the maintainer's Mac, ogis 2026.11.18.17): maps 1-3 built from these calls in
0.9 s, `OGIS_DEPTH` from `.Renviron` and `OGIS_CELLS` naming an effort file written by decision 330's trial script
to the session's scratchpad (381 MB, 2007-2026, 21 gears; deleted after), as `library(ogisdata)` would set them, and
served. Maps 1 and 2 drew in the app's browser: the depth with its relief over the EMODnet base map; the effort over
it, every gear, 2007-2026. **Map 3 did not:** its page asked for no effort tile, drew nothing, and its controls showed
"all" and no years, though its configuration starts at gear 6 and 2015-2024. The same choices given in map 2's
address (`?cells_gid=6&cells_year_from=2015&cells_year_to=2024`) drew bottom trawl, 2015-2024. So `og_cells(filter =
)` fails on a served map: an ogis fault, fixed in ogis with a test before step 2, since the demo shows it.

**The contours** (the maintainer, the same day: "the one with nice breaks and labels and then fine lines in
between") are `og_contour()`'s defaults, the charts' isobaths labelled and finer lines between. They show in full only
from zoom 5 on the shelf, so map 1 opens off the Westfjords at zoom 7.5, and all three maps carry them. Tried the same
day: at that view the labelled lines (10, 25, 50, 100, 200 and 1,000 m) and the finer ones drew over the relief, and
over the effort when `og_contour()` comes after `og_cells()`. Over dense effort the finer lines are hard to see in the
default colour; `og_contour(colour = )` lightens them.

## 4. Steps

1. **The effort file**, TODO 205: from a committed script in `products/`, with its dictionary, the preset and grid
   by ask c.
2. **The package**, §3.2-3.3 and §3.7: `~/R/Pakkar/ogisdata` with `data-raw/files.R`, the demo, its tests and the
   script in `tools/` that copies it to the share; the tests pass from a temporary library on this Mac, and the
   demo's three maps draw. Needs ogis's `og_cells(filter = )` fixed first (§3.7).
3. **From the share**, by the maintainer or a colleague: `remotes::install_local("R:/R/Pakkar/ogisdata", force =
   TRUE)` into an empty library on a Windows machine at MFRI, one map of each kind drawn, the install's time
   recorded.
4. **Its README sent to colleagues**, with the install line and one map script; the kit of TODO 185 then retired or
   kept, at the maintainer's word.

## 5. Asks

a. **The name.** Answered 2026-11-19: "call the package ogisdata". Claude had proposed a name not starting with `og`,
   so it is not taken for part of ogis; its README and `DESCRIPTION` therefore say it is MFRI's, internal, and not
   part of the public ogis.
b. **The place names in it too?** Answered 2026-11-19: "placenames - not now". They stay out; Claude had
   recommended them (1.9 MB, read by `og_names()` the same way), and they can come in later as a third file.
c. **Which effort** (TODO 205's ask): the trial's 0.005° grid with the `fishing` preset alone (381 MB), or more
   presets or the finer grid (`grid.parquet`, 5.1 GB as the effort map's base, too large here).
d. **Who reads the share.** Its place is given by e (`R:/R/Pakkar/ogisdata`). Left: whether the folder can be limited
   to staff who need the effort, and whether the depth model's owner agrees to its spreading this way inside MFRI.
e. **How colleagues install it.** Answered 2026-11-19: as mardata, `remotes::install_local()` from its folder on the
   share (osmx's README). Claude had recommended a package repository on the share, so that `update.packages()`
   finds new versions; with mardata's way an update is the same line again.
f. **ogis's error for a missing variable** says to set it in `.Renviron`. Should it also say "or load a package that
   sets it"? Claude recommends no change: the package's README carries the `library()` line.
g. **Where its source lives.** Claude proposes `~/R/Pakkar/ogisdata`, beside ogis and ramb, a git repository of code
   only, with no remote, or a private one if MFRI has a place for it.
h. **The demo's form.** Claude proposes R's own `demo/` (§3.7). The other way is osmx's: an R Markdown template
   (File > New File > R Markdown > From Template), which opens as a document of the user's own.
