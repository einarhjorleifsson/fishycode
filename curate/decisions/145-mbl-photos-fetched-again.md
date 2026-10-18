# 145 — The 1,589 missing mbl photos fetched again by their logged URLs; the index now covers 2,129 vessels (plan 030 step 5)

*2026-10-18. On the maintainer's go (ask b, revised after the pilot of decision 141): "fetch the 1,589 missing photos
by their logged URLs into raw/external/skipaskra/jpg/ under their 2022 names, 1 s apart, checking each byte count
against the log, then rebuild mbl_photo". Run, checks and this record by Claude (AI-assisted). Numbered 145: main took
142 and 144 for plan 028 (the plan 028 session's request).*

## Fetched

`dump/vessels/mbl_photo_recover.R` took the `missing` rows of `staging/mbl/photo.parquet`, which carry the image's URL
and byte count from the 2022 logs. Only `static.mbl.is` was asked, which has no bot check; the vessel pages, which
have one, were not. For each image:
- it was written to a temporary file;
- it was moved into `raw/external/skipaskra/jpg/` under its 2022 name only when its size equalled the log's;
- it was recorded in `raw/external/skipaskra/mbl-photo-recover_2026-10-18.csv` (status, bytes, md5, time), with the
  run's log beside it.

**The pace.** The first 82 images were fetched 1 s apart, as the go said. Then the maintainer asked for more than 1 s
between fetches ("I think you should have more than 1s between fetch"). The run was stopped, checked (the folder held
the originals plus exactly those 82, none half-written) and restarted 4 s apart, the pace of the 2022 info scrape.
That is the script's default now.

## Checked

- 1,589 of 1,589 images `ok`, none failed or refused.
- Each file in the folder has the byte count and md5 its manifest row gives.
- The 1,000 original files are untouched, all still dated 2026-09-30. The folder holds 2,589 files.

## The index rebuilt

`sources/mbl/photo.R` reads the manifest and marks each fetched file `recovered` (the date it was fetched), NA for the
2022 copy. Checked in a scratch store first, then built from the worktree with `tar_make_isolated(names =
"mbl_photo")` in 20 s. The built file equals the scratch run, 2,589 rows, with no row on either side missing from the
other. It holds:

| | before (decision 138) | now |
|---|---|---|
| rows | 2,589 (1,000 files, 1,589 `missing`) | 2,589 (every one a file) |
| photos / thumbnails | 538 / 462 | 2,127 (1,589 recovered) / 462 |
| vessels with an image | 887 | 2,129 |
| best image a photo / a thumbnail | 537 / 350 | 2,126 / 3 |
| EXIF date / photographer / copyright | 393 / 82 / 63 | 1,584 / 298 / 234 |

The defects are those of decision 138: 1 truncated, 1 undersized, 11 files with no log line. They are among the 2022
copy, not the fetched files.

**Found on the way.** One fetched photo's EXIF photographer is written in Latin-1, not UTF-8. None of the first 1,000
was. `photo.R` trimmed the text before converting it, and stopped. The text is now made valid UTF-8 first.

**The overview's check** (`products/vessel_overview/check.R`) passes on the new index: 67 answers, 10 refusals, a
photo served byte for byte. The vessel list, computed once at the server's start, took 1.3 s on its first read after
the build and 0.6 s after, so it now has a limit of its own (5 s), and every per-request answer keeps 1 s.

## What it closes

- **Plan 030 is executed.** Steps 1-5 are built (decisions 138, 139, 140, 143 and this one), and step 2's scraper is
  written. A new scrape is closed while mbl's bot check stands (decision 141). TODO 85 is deleted.
- **What stays outside the plan:**
  - species names (TODO 10);
  - the gear read from the AIS track (TODO 86);
  - the previous-trip gear rule in the flow (decision 143);
  - where the app runs beyond the laptop (ask a: the laptop first).
- **The build is on the branch.** It was made in the worktree's own `_targets/` store, on branch
  `claude/dreamy-shirley-2a8ae2`. Once the branch is merged, main's `tar_outdated()` lists `mbl_photo_raw` and
  `mbl_photo`, and a build there (about 20 s) writes the same file.
- **A running overview server shows the new photos per vessel at once.** Its vessel list keeps the old "with a photo"
  flags until the server is restarted.
