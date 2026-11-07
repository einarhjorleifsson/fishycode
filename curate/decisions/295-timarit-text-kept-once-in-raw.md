# 295 — timarit.is's page text kept once, in `raw/external/timarit/`: one folder per issue, one fetcher, a staged table

*2026-11-07. Plan 067 (ask c, how timarit.is's text is had), TODO 193, at the maintainer's word. Written, moved, tested
and counted by Claude (AI); no person has checked the code or the counts.*

## Why

Four studies of 2026-11-05 to -07 fetched timarit.is's text, each into its own `text/` folder and in its own layout:
the place-name study (`archive/2026-11-05-timarit-ornefni/`), early Ægir, Bjarni Sæmundsson in Andvari, and the
seabed articles of Trausti Einarsson and Þorvaldur Thoroddsen (`archive/2026-11-07-seabed-landscape/`). Nothing kept
a page from being fetched twice, and no study could find another's text. The maintainer, 2026-11-07: "Can we make sure
that the minded text is somewhere systematically stored - i foresee that we will accumulate more as time goes by.
should this not be in fishydata/raw?". Offered three layouts and three forms, the maintainer chose "Flat, by issue id"
and "Text files and a parquet".

## What

- **The store**, `raw/external/timarit/`, one folder per issue, keyed by timarit.is's own ids:
  `<issue id>/page_<page id>.txt` (a page view's OCR text as served), `<issue id>/issue_view.html` (one view of the
  issue, whole: its page ids in order and its article menu), and the adopted ZIPs, `<issue id>/issue.zip` with their
  pages as the ZIP named them (`<date>i<n>p<k>.txt`). `_manifest.csv` has a row per file (issue, publication, issued,
  page id, place in the issue, file, how, bytes, md5, fetched, study); `_requests.csv` a row per request;
  `README-provenance.txt` is written by the script, never by hand.
- **One way in:** `dump/timarit/fetch.R` (`page`, `article`, `issue`), on the functions of `R/timarit.R`. Only
  `/page/<id>` and `/issue/<id>` are asked, which robots.txt allows; one request at a time, 10-30 s apart; a page in the
  store is never asked again. `/files` (the issue ZIPs), which robots.txt disallows, is never asked again either.
  `timarit_text()` and `timarit_article_text()` read the store by page id.
- **What was there first:** `dump/timarit/adopt_studies.R` moved the four studies' text in (a rename within
  `$FISHYDATA`, each file's md5 checked before and after) and left a relative link at each old path, so the studies'
  scripts and READMEs still resolve. Tried first on a clone, where a second run moved nothing. On the live store:
  2,434 files into 63 issue folders, 18 MB: 144 page views, 58 ZIPs with 2,226 pages, 6 issue views; 2,434 links, none
  broken. The four `article_*.txt` the studies assembled from pages stay in the studies.
- **The table:** `sources/timarit/page.R`, target `timarit_page`, writes `staging/timarit/page.parquet`: a row per
  page (2,370 in 62 issues on the clone; Ægir 1,088, Sjómannablaðið Víkingur 484, Fiskifréttir 352, Andvari 350, Bændablaðið 56,
  Náttúrufræðingurinn 24, Fréttir 16), the text as the OCR gives it, every file's md5 checked against the manifest.
  Nothing in the flow reads it.
- **The issues' article menus** (added the same day, at the maintainer's question: "we are keeping a track of
  volume articles overviews, right? meaning they get stored for potential later retievals"): each issue's view, with
  its menu, is kept once as `issue_view.html`; `sources/timarit/issue_article.R` (target `timarit_issue_article`)
  stages the menus as `staging/timarit/issue_article.parquet`, a row per article: title, timarit.is's article id (not
  unique within an issue: errata share one), the Gegnir record id, the issue's pages. At first 49 Andvari volumes
  (1885-1940, 324 articles), opened for Bjarni Sæmundsson's articles. The menu gives no author and no page; the
  volumes' contents pages, stored as pages, do.

## Not done

- The 1,860 pages of the 2026-11-05 study's 48 ZIP issues have no page id: that study logged one page per issue, not
  the issue's page ids. One issue view each (`fetch.R issue <id>`) would give them; not asked.
- The text is published but under copyright (timarit.is's terms: personal use, nr. 73/1972): it stays under
  `$FISHYDATA`, never in the repo or anything published. Bulk text is still plan 067's ask c, for the maintainer.
