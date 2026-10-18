# 138 — The mbl photo index built: `staging/mbl/photo.parquet` (plan 030 step 1)

*2026-10-18. Built on the maintainer's go ("build mbl_photo now from this worktree"); code, checks and this record by
Claude (AI-assisted). A person has not yet checked the table.*

## Built

`sources/mbl/photo.R`, target `mbl_photo` (with `mbl_photo_raw`: the 1,000 files and the scrape's eight logs), built
with `tar_make_isolated(names = "mbl_photo")` in 13 s. It writes `staging/mbl/photo.parquet`, 2,589 rows, 108 KB:

| kind | defect | rows |
|---|---|---|
| photo | none | 529 |
| photo | `no_log` | 7 |
| photo | `truncated` (1722) | 1 |
| photo | `undersized` (0078) | 1 |
| thumbnail | none | 458 |
| thumbnail | `no_log` | 4 |
| missing (a logged download with no file) | none | 1,589 |

- 887 vids have a file, and each has one `best` image: 537 photos and 350 thumbnails.
- 2,120 logged downloads, each with mbl's image id, URL, byte count and outcome (one `failed`, 1722's).
- 886 of the 887 vids are in mbl's own register. Vid 1031 is the exception.
- EXIF: a date on 393 photos (2003 to 2016-09-04), a photographer on 82, a copyright string on 63.
- Every file decodes. The script's checks hold: rows are files plus missing downloads; no file or (vid, image_no,
  kind) repeats; every logged download has a photo row; one best image per vid with a file.

## How it was checked

- **In a scratch store first**, with `R_ENVIRON_USER` pointing at a scratch `$FISHYDATA` whose `raw/` links to the
  real one. Nothing in the real store changed (checked with `find -newer`).
- **The build against the scratch run:** the same 2,589 rows, with no row on either side missing from the other
  (`EXCEPT ALL` both ways), and the same columns and types.
- **The only file the build wrote** under `$FISHYDATA` is `staging/mbl/photo.parquet`.

## Found on the way

**Plan 030 §1.4 was wrong about the EXIF dates.** It said 17 are "before 2000". All 17 are 2000-01-01, a camera's
default date (a clock never set). The first measurement's year bins put 2000 in the bin before it. `exif_date` is NA
for them, `exif_date_txt` keeps what was printed, and the plan is corrected.

## Where the build stands

- The target was built from the worktree of branch `claude/dreamy-shirley-2a8ae2`, into that worktree's own
  `_targets/` store. The main checkout's store does not know it yet. Once the branch is merged into `main`, its
  `tar_outdated()` will list `mbl_photo_raw` and `mbl_photo`, and building them there (about 13 s) writes the same
  file.
- Nothing in the flow reads the table. Its reader is the vessel overview (plan 030 steps 3-4).
- The photos are a newspaper's images, for internal use only. `use` says so on every row. The EXIF photographer and
  copyright strings are kept as printed, under `$FISHYDATA` only.
