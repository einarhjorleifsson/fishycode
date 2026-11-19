# 078 — ogisdata: an internal R package with the depth model and the effort, so an ogis map needs no path

**status:** partly built — steps 1 and 2 built 2026-11-19 at the maintainer's word ("Yes, build"; §4.1): the effort
file and ogisdata 2026.11.19 in `~/R/Pakkar/ogisdata`, checked, installed into an empty library and its demo's maps
drawn on this Mac; committed (79b33a4; ogisdata 0f8912f) and ogisdata 2026.11.19.1 made from the effort rebuilt at that commit (899a38a); step 3 the maintainer's, who copies the folder to the institute's computer
("i will need to copy the package to the institute computer, you can not do that"), and step 4. Written
2026-11-19 at the maintainer's word ("Yes, write it"), from the maintainer's idea of the
same day, after a trial the same morning; asks a and b answered the same day ("call the package ogisdata";
"placenames - not now", so the depth model and the effort alone); §3.3 revised the
same day at the maintainer's word: ogisdata a package folder of its own, whose `data-raw/` copies the files in from
`$FISHYDATA`; ask e answered the same day: installed as mardata is, from its folder on the share (osmx's README, §3.4);
a demo script added the same day at the maintainer's word, its three maps drawn on this Mac (§3.7; an ogis fault
first recorded there was none, the page not yet finished opening); asks c, d, f, g and h answered the same day (the
0.005° grid; everyone at the institute reads the share; ogis's error as it is; `~/R/Pakkar/ogisdata`; R's `demo/`),
and what g's "code only" meant set out in §3.3 at the maintainer's question. **Measured** (by Claude, 2026-11-19, on the maintainer's Mac,
R 4.5.2, ogis 2026.11.18.17): a throwaway package holding fishycode's `depth.mbtiles` builds, installs and is found by
ogis with no path (§2). **Assumed, not measured:** installing ogisdata from the share over MFRI's network, about 0.93
GB, five times mardata (174 MB installed); Windows, though mardata installs there the same way; that colleagues have
about 2 GB free while it installs · **see:** TODO 204, TODO 205, decision 330,
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
the share by the maintainer, by hand (2026-11-19: "i will need to copy the package to the institute computer, you can
not do that"; the script in `tools/` first proposed for it is not made). `data-raw/` is in `.Rbuildignore`. Rerun
after each rebuild of the products it carries.

**What "code only" means** (the maintainer asked, 2026-11-19). The package carries both files: they are in the
folder's `inst/extdata/`, in the folder on the share and in every install. Only the folder's git leaves them out
(`.gitignore` names the two data files): git keeps every version of every file it tracks, so 0.93 GB a release would
sit in its history for good, and the files are copies whose source of record is `$FISHYDATA`, rebuilt by fishycode.
Git does keep `inst/extdata/files.csv`, so each commit records which builds of the two files that version carried.

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
- **ogis itself** from GitHub, `remotes::install_github("einarhjorleifsson/ogis")` (ogisdata's README since
  2026-11-19, at the maintainer's word: "Yes, update README"). ogis's own README installs with `install_git(git =
  "external")`, which needs Git and Git LFS, for its example data; without them only `og_example()` fails, which
  ogisdata does not use. The note to colleagues (step 4) gives the same three lines.

Each install copies about 0.93 GB into the person's library, and again after each R minor version (a new library).

### 3.5 What stays internal

The depth model and the effort are internal (ogis's rules). The filled package lives on MFRI's share alone, inside
its firewall: never GitHub, r-universe or a public host, and a bundle made from it (`og_bundle()` copies its tiles) is
internal too. Its source folder's git holds no data and has no public remote (§3.3, ask g).
The effort is summed over vessels, but at 0.005° a cell may hold one vessel's fishing; everyone at the institute may
read the share (ask d), under MFRI's gagnastefna.

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

# 2. The fishing effort over the depth, the contours on top: hours per square kilometre, every gear and year
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
served. All three drew in the app's browser: the depth with its relief over the EMODnet base map; the effort over it,
every gear, 2007-2026; and bottom trawl, 2015-2024. **Map 3 was first recorded here as an ogis fault, wrongly.**
Screenshots 5 and 10 s after it opened showed no map and its controls at "all" with no years, and this plan said
`og_cells(filter = )` failed on a served map (commit e427649). A side session the same day found no fault: ogis's own
example with `filter`, as a data frame and as Parquet, an 8-million-row file of the same shape, and map 3 itself on
the real effort file all opened at their filter and drew, in headless Chrome and the app's browser. The page sets its
controls only after `/meta` and MapLibre's first frame, and the screenshots came before both. Checked again here the
same day: map 3 alone had not drawn 10 s after it opened and had drawn bottom trawl, 2015-2024, by 20 s. Nothing in
ogis needs fixing for the demo; the side session added a browser test of `og_cells(filter = )` on a served map as a
guard (ogis 2026.11.19, cf66ca5, pushed), and suggests, not built, that the page set its controls as soon as `/meta`
arrives, so a page still loading shows its starting choices.

**The contours** (the maintainer, the same day: "the one with nice breaks and labels and then fine lines in
between") are `og_contour()`'s defaults, the charts' isobaths labelled and finer lines between. They show in full only
from zoom 5 on the shelf, so map 1 opens off the Westfjords at zoom 7.5, and all three maps carry them. Tried the same
day: at that view the labelled lines (10, 25, 50, 100, 200 and 1,000 m) and the finer ones drew over the relief, and
over the effort when `og_contour()` comes after `og_cells()`. Over dense effort the finer lines are hard to see in the
default colour; `og_contour(colour = )` lightens them.

## 4. Steps

1. **The effort file**, TODO 205: from a committed script in `products/`, with its dictionary: the 0.005° grid, the
   `fishing` preset (ask c).
2. **The package**, §3.2-3.3 and §3.7: `~/R/Pakkar/ogisdata` with `data-raw/files.R`, the demo and its tests; the
   tests pass from a temporary library on this Mac, and the demo's three maps draw.
3. **To the share and from it**, by the maintainer: the folder, its data files with it and `.git` left out, copied to
   `R:/R/Pakkar/ogisdata`; then `remotes::install_local("R:/R/Pakkar/ogisdata", force = TRUE)` into an empty library on
   a Windows machine at MFRI, one map of each kind drawn, the install's time recorded.
4. **Its README sent to colleagues**, with the install line and one map script; the kit of TODO 185 then retired or
   kept, at the maintainer's word.

### 4.1 Built (2026-11-19)

By Claude, on the maintainer's Mac (R 4.5.2, ogis 2026.11.18.17, DuckDB 1.5.6), at the maintainer's word ("Yes,
build").

- **Step 1.** `products/effort_map/cells.R` writes `$FISHYDATA/products/effort_map/cells.parquet` from
  `grid_005.parquet` (built 2026-11-17) in 3 s: 32,382,226 cells, 381 MB, 9,102,210 hours, the grid's own `fishing`
  hours to the hour, or nothing is replaced. It stops if a gear has no name in `gear.parquet`. It carries ogis's data
  dictionary and the `fd.*` stamps of `write_curated()`, though the file is not curated (`.curated_kv()`; the
  dictionary's JSON quoted for SQL, not by `shQuote()`).
- **Step 2.** `~/R/Pakkar/ogisdata`, a git repository with nothing committed: `R/ogisdata.R` (`.onLoad`,
  `depth_file()`, `cells_file()`, `files()`, the startup line), `data-raw/files.R`, `demo/maps.R` as §3.7 (its km²
  written out: R CMD check wants a demo in ASCII), four tests, `README.md`, `LICENSE` (MFRI staff only, nothing
  outside the institute). `data-raw/files.R` cloned both files in 3 s and set the version, 2026.11.19. The depth model
  carries no build stamps, so `files()` gives its file time (2026-11-03) and no commit.
- **Checked.** `R CMD build` in 23 s (a 925 MB tarball); `R CMD check --no-manual` status OK, its only remark the
  installed size (885 MB, as INFO). `remotes::install_local()` from the folder into an empty library in 38 s, 885 MB;
  the tests' 10 expectations pass against that install. With `OGIS_DEPTH` and `OGIS_CELLS` emptied first, the
  demo's three maps, built from the installed demo file and served, drew in the app's browser from the install's own
  files: the depth with relief and contours off the Westfjords; the effort, every gear, 2007-2026; bottom trawl,
  2015-2024, its controls at that filter. The tarball, the check folder and the test library were deleted after.
- **Committed** at the maintainer's word ("Yes, commit"): fishycode 79b33a4, ogisdata 0f8912f (2026.11.19). Then
  `cells.R` and `data-raw/files.R` rerun, which made ogisdata 2026.11.19.1 (899a38a), its tests passing against a fresh
  install: the effort built at 79b33a4, the version to copy to the share. Its stamp still says `fd.dirty` true:
  `.git_info()` counts an untracked file, and the tree held one, `products/exports/ramb_example_iceland_map.R`, of
  another session's work, which `cells.R` does not read; NEWS.md says so. Steps 3 and 4 remain.

## 5. Asks

a. **The name.** Answered 2026-11-19: "call the package ogisdata". Claude had proposed a name not starting with `og`,
   so it is not taken for part of ogis; its README and `DESCRIPTION` therefore say it is MFRI's, internal, and not
   part of the public ogis.
b. **The place names in it too?** Answered 2026-11-19: "placenames - not now". They stay out; Claude had
   recommended them (1.9 MB, read by `og_names()` the same way), and they can come in later as a third file.
c. **Which effort** (TODO 205's ask). Answered 2026-11-19: "go with 0.005", the trial's 0.005° grid with the
   `fishing` preset alone (381 MB). Not more presets, nor the finer grid (`grid.parquet`, 5.1 GB as the effort map's
   base, too large here).
d. **Who reads the share.** Its place is given by e (`R:/R/Pakkar/ogisdata`). Answered 2026-11-19: "all at the
   institute can read", so the folder is not limited to staff who need the effort. The ask's second half, the depth
   model spread this way inside MFRI, answered the same day: "you can distribute the depth model this way, it is only
   for mfri staff".
e. **How colleagues install it.** Answered 2026-11-19: as mardata, `remotes::install_local()` from its folder on the
   share (osmx's README). Claude had recommended a package repository on the share, so that `update.packages()`
   finds new versions; with mardata's way an update is the same line again.
f. **ogis's error for a missing variable** says to set it in `.Renviron`. Should it also say "or load a package that
   sets it"? Answered 2026-11-19: "leave as is", as Claude recommended; the package's README carries the `library()`
   line.
g. **Where its source lives.** Answered 2026-11-19: `~/R/Pakkar/ogisdata`, beside ogis and ramb ("location
   correct"), a git repository with no remote, or a private one if MFRI has a place for it. The maintainer asked what
   "code only" meant, thinking the files were to be in the package: they are, and only its git leaves them out (§3.3).
h. **The demo's form.** Answered 2026-11-19: "go with R demo/", R's own `demo/` (§3.7), not osmx's R Markdown
   template.
