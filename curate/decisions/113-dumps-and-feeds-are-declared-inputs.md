# 113 — The STK trail and the AIS feeds are declared inputs; `astd.R` skips a month before unzipping it

*2026-10-16. Written by Claude (AI-assisted), on a brief from the session that ran decision 112. Verified read-only:
`tar_validate()`, `tar_outdated()` (the store's meta file has the same md5 before and after) and two scratch
targets projects. No target of this project was built.*

## What was wrong

`stk`, `stk_hid_pid` and `ais_ping_union` read the STK trail through `stk_trail()` (`raw/oracle/stk/trail/`,
decision 111). `ais_ping_union` also reads `staging/ais/astd/`, `staging/ais/astdB/` and `raw/ais/EmodNet/is2017.csv`.
`_targets.R` declared none of them, so a new STK dump or ASTD month left `tar_outdated()` empty. Decisions 107 and
111 invalidated these targets by hand. The brief named `stk` and `ais_ping_union`; `stk_hid_pid` reads the trail
the same way (decision 111 invalidated it with the others), so it gets the edge too.

## What was chosen

Four input targets with no script, each `format = "file"`: `stk_trail_raw`, `astd_staged`, `astd_b_staged` and
`emodnet_raw`. The three partitioned inputs are listed at the top of `_targets.R` by `input_files()`
(`R/source_script.R`): the parquet files under the directory, sorted by radix so that the locale cannot change the
order. The target's command is that list.

Where the listing is made decides what targets can see. A scratch project tested three forms (targets 1.12.0). Each
row lists the forms that marked themselves and their downstream outdated:

| change | listed at the top (chosen) | listed in the command (as `mmsi_raw` does) | the directory itself |
|---|---|---|---|
| a new partition | yes | **no** | yes |
| content changed, same size | yes | yes | yes |
| file touched, same content | no | no | no |
| a `.DS_Store` added | no | no | **yes** |
| a partition removed | yes | yes | yes |

A command runs again only when its code or its dependencies change. So a listing made inside the command is never
redone, and it misses a new partition. A listing made outside is a global the command depends on, and adding or
removing a file changes it. The directory form catches everything, but it also marks the chain outdated for any
stray file. For a new partition it has to rehash the whole directory, in every `tar_outdated()`, until the next
build. The chosen form avoids that, because `tar_outdated()` makes the same check as the build
(`builder_should_run()`), which compares dependencies before files. A changed file inside the listing is left to
targets' own check: mtime and size first, and the content hash only when one of those differs.

`emodnet_raw` is one file that never gains partitions, so it is declared by its path, as `vessel_raw` is.

## Cost

| | |
|---|---|
| no-op `tar_outdated()` before (0 outdated) | 1.89, 1.46, 1.44 s |
| the same after the edit (23 outdated, inputs not yet built) | 1.49, 1.44, 1.41 s |
| the four inputs' share of a no-op check (scratch project over the real files, 5 runs each) | 0.49-0.56 s with them, 0.41-0.42 s without: **about +0.1 s** |
| full hash of the four inputs | 47.6 s, about 3.5 GB/s |

What one input costs to rehash when it changes:

| input | files | GB | rehash |
|---|---|---|---|
| `stk_trail_raw` | 24 | 11.1 | 3.1 s |
| `astd_staged` | 160 | 140.0 | 38.0 s |
| `astd_b_staged` | 132 | 22.8 | 7.6 s |
| `emodnet_raw` | 1 | 3.4 | 0.9 s |

After the next build, a no-op `tar_outdated()` should take about 1.5 s. A rehash is paid only on a change. A
rewritten file, such as a re-dumped trail year, is rehashed in each `tar_outdated()` until the build, and once in
the build: 3 s for the trail. A new ASTD month is seen from the listing, without a hash, and its input is hashed
once, when the build reaches it: 38 s.

## What the edit costs once

The edit changes the commands of `stk`, `stk_hid_pid` and `ais_ping_union`, so `tar_outdated()` now lists 23
targets: the four inputs, those three and everything below them. The next `tar_make_isolated()` hashes the inputs
(48 s) and reruns `stk` (2.6 min in decision 112), `stk_hid_pid` and `ais_ping_union` (2.8 min).

`stk_hid_pid` writes through `write_curated()`, whose `fd.built` stamp changes the file's bytes, so `stk_event`,
`port_stay` and everything below them rerun too. By decision 112's step times, `port_stay`, `ais_voyage`,
`ais_trail` and `ais_catch` alone take 73 min. If rewriting `ais_ping_union` with the same rows also changes its
bytes (not known), the whole chain reruns, about two hours. The next STK dump reruns that chain anyway, so the
cheapest time to build is with the next delivery.

## `dump/ais/astd.R`

The skip test, whether `year=Y/month=M/astd_YYYYMM.parquet` exists, now comes before the unzip. So adding a month
no longer decompresses the other 160 (decision 107). The output directory is still created only once a CSV has been
found, as before. The script was parsed, not run. Running it needs a new zip, and it writes into `staging/`.

## Left

- Other raw inputs are still undeclared. The adapters that decision 111 invalidated by hand (`gear`, `port`,
  `port_code`, `afli`, `fs_afladagbok`, `adb`, `aflagrunnur`, `lods`) read `raw/oracle/` files that `_targets.R` does
  not name. `mmsi_raw` lists `raw/mmsi/*.xlsx` inside its command, so it would miss a new list, as the table above
  shows. `input_files()` is the form for both.
- The `once` project's key scripts read the trail too. They are redone only by decision (075), so nothing changes
  there.
- TODO 69 (stale partitions in `staging/ais/stk`) is untouched.
