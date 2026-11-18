# 327 — rebelrebel renamed ogis: its prefix `rr_` is `og_`, its folder, repository and site follow

*2026-11-18. At the maintainer's word ("Rename first", answering plan 077's ask a; "the rebelrebel joke has run its
course"). Done and checked by Claude (AI); no person has checked it beyond the maintainer renaming the GitHub
repository.*

## What was done

- **The name.** `ogis` was free: not on CRAN (never published or archived), r-universe (only `OGI`, another package),
  PyPI, nor as an R repository on GitHub.
- **The package** (ogis 2026.11.18.10, e8b4780): every `rr_` is `og_` (`og_map()`, `og_point()`, `og_serve()`, ...)
  and the classes `og_map`, `og_layer`, `og_section`; in the page, what a script of its own sees, the object `og`
  (`og.on()`, `og.state()`, `og.fetch()`), the features' key `og_row`, the classes `.og-panel` and the others, the
  notes' header `X-OG-Notes`; the engine's names left from ramb (`rb_`, `rb-`, `RB_BUNDLE`) `og` too. About 3,000
  replacements in 69 files by a script matching whole names only; nothing persisted (notes and verdicts files) carried
  a renamed name. NEWS's older entries keep the names of their day.
- **The folder and project** (5414fca): `~/R/Pakkar/ogis`, `ogis.Rproj`; this project's Claude memories copied to the
  new folder's.
- **GitHub**: the maintainer renamed the repository `einarhjorleifsson/ogis` (the old address redirects); its 17
  commits pushed (905b520), the site published clean at `einarhjorleifsson.github.io/ogis` (the old site's address
  now answers 404, as GitHub does not redirect Pages).
- **fishycode**: `products/port_map` calls `ogis::og_*` (94c5ba6; its map built, 7 layers). rebelrebel 2026.11.18.9
  stays installed beside ogis, so archived study scripts that load it still run.

## Checked

R CMD check 0/0/0; the knit and Rscript tests against ogis installed; the site's 13 article maps drawn with no error in
the page. CI's first run on the push failed on Ubuntu and Windows, on a test's timing and Chrome's temporary folder,
not on the rename (decision 328).

## Not changed

Plans 072, 076 and 077, the decisions before this and the archived studies keep the names of their day: read them as
`ogis`/`og_`.
