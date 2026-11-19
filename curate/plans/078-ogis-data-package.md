# 078 — ogisdata: an internal R package with the depth model, the effort and the place names, so an ogis map needs no path

**status:** proposal — written 2026-11-19 at the maintainer's word ("Yes, write it"), from the maintainer's idea of the
same day, after a trial the same morning; ask a answered the same day ("call the package ogisdata"); §3.3 revised the
same day at the maintainer's word: ogisdata a package folder of its own, whose `data-raw/` copies the files in from
`$FISHYDATA`; nothing built; asks b-g need the maintainer. **Measured** (by Claude, 2026-11-19, on
the maintainer's Mac, R 4.5.2, ogis 2026.11.18.17): a throwaway package holding fishycode's `depth.mbtiles` builds,
installs and is found by ogis with no path (§2). **Assumed, not measured:** installing from MFRI's share over its
network; Windows (a package of R code alone installs without Rtools; a `file:` repository on a UNC path); that
colleagues have about 1 GB free; that the share can limit who reads it · **see:** TODO 204, TODO 205, decision 330,
`$FISHYDATA/archive/2026-11-18-depth-model-in-ogis/report.md` §3 and §5

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

A precedent: the bathymetry map's kit (TODO 185, `products/bathymetry_map/kit.R`) already went to colleagues through a
share, 2.6 GB with its own copy of the map's code and ramb. The package carries data only.

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
for `og_cells()` (the 0.005° grid, the `fishing` preset, gear, year and cell, no vessel), 381 MB; the place names 1.9
MB. About 0.93 GB in all, in every library it is installed in. Not measured: how long that takes from the share.

## 3. Design

### 3.1 What it holds

Three files in `inst/extdata/`, as fishycode's products write them: `depth.mbtiles` (from
`products/bathymetry_map/dem.R`), the effort for `og_cells()` and the place names for `og_names()` (both built by
TODO 205, each with its data dictionary in the Parquet metadata). No code beyond §3.2, no compiled code, no copy of
ogis.

### 3.2 How ogis finds them

- **`.onLoad` sets the three variables, each only when it is empty**, so a person's own `.Renviron` still wins. ogis
  reads them at each call (`Sys.getenv()`), so a script needs one line, `library(ogisdata)`, and no path.
- **Three path functions** (`depth_file()`, `cells_file()`, `names_file()`) for an explicit call
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

- **`data-raw/files.R` copies the three files as they are**, a clone on APFS so no second copy on disk, and writes
  their provenance to `inst/extdata/files.csv`, which `files()` reads. For the Parquet files that is their `fd.*`
  stamps; for each file, its bytes and md5.
- **It makes nothing.** The effort and names files are built by fishycode's `products/` scripts (TODO 205); a change
  to what is in them is made there.
- **It bumps the version** in `DESCRIPTION` (`YYYY.MM.DD`, `.1` for a second build in a day, as ogis) and adds a NEWS
  line naming the files' builds.

Then `R CMD build`, the package's tests (§2's checks from a temporary library: the variables set, a person's own
kept, each file read through ogis, skipped where ogis is absent), and the tarball into the share's repository by a
script in `tools/` (§3.4). `data-raw/` and `tools/` are in `.Rbuildignore`; `inst/extdata/` is in `.gitignore`, so
the folder's git holds code only. Rerun after each rebuild of the products it carries.

### 3.4 How colleagues get it

The tarballs in a package repository on MFRI's share (`src/contrib/`, indexed by `tools::write_PACKAGES()`), so:

- the first install is `install.packages("ogisdata", repos = <the share>)`;
- `update.packages()` finds a new version;
- a tarball there can still be installed by its path, `remotes::install_local()` or
  `install.packages(<file>, repos = NULL)`, as the maintainer first proposed;
- the repository can hold ogis's own tarball too, so one line installs or updates both (ogis's packages from CRAN).

Each install copies about 0.93 GB into the person's library, and again after each R minor version (a new library).

### 3.5 What stays internal

The depth model, the effort and the place names are internal (ogis's rules). The package's tarballs live on MFRI's
share alone: never GitHub, r-universe or a public host, and a bundle made from it (`og_bundle()` copies its tiles) is
internal too. Its source folder's git holds code only, with no public remote (ask g).
The effort is summed over vessels, but at 0.005° a cell may hold one vessel's fishing; who may read the share is ask
d, under MFRI's gagnastefna.

### 3.6 With the bucket later

If TODO 204's bucket is built and ogis gains its tile address, the depth model may leave the package: `.onLoad` sets
its address instead, and the package shrinks to the effort and the names. Nothing in §3.2 needs to change for a
script.

## 4. Steps

1. **The files**, TODO 205: the effort and the place names from committed scripts in `products/`, with their
   dictionaries, the preset and grid by ask c.
2. **The package**, §3.2-3.3: `~/R/Pakkar/ogisdata` with `data-raw/files.R`, its tests and the publishing script in
   `tools/`; the tests pass from a temporary library on this Mac.
3. **From the share**, by the maintainer or a colleague: installed from the repository into an empty library on a
   Windows machine at MFRI, one map of each kind drawn, the time recorded.
4. **Its README sent to colleagues**, with the install line and one map script; the kit of TODO 185 then retired or
   kept, at the maintainer's word.

## 5. Asks

a. **The name.** Answered 2026-11-19: "call the package ogisdata". Claude had proposed a name not starting with `og`,
   so it is not taken for part of ogis; its README and `DESCRIPTION` therefore say it is MFRI's, internal, and not
   part of the public ogis.
b. **The place names in it too?** Claude recommends yes: 1.9 MB, and `og_names()` reads them the same way.
c. **Which effort** (TODO 205's ask): the trial's 0.005° grid with the `fishing` preset alone (381 MB), or more
   presets or the finer grid (`grid.parquet`, 5.1 GB as the effort map's base, too large here).
d. **The share and who reads it**: its path, whether it can be limited to staff who need the effort, and whether
   the depth model's owner agrees to its spreading this way inside MFRI.
e. **A repository on the share** (§3.4), or tarballs installed by path alone. Claude recommends the repository: the
   effort is rebuilt often, and `update.packages()` then reaches everyone.
f. **ogis's error for a missing variable** says to set it in `.Renviron`. Should it also say "or load a package that
   sets it"? Claude recommends no change: the package's README carries the `library()` line.
g. **Where its source lives.** Claude proposes `~/R/Pakkar/ogisdata`, beside ogis and ramb, a git repository of code
   only, with no remote, or a private one if MFRI has a place for it.
