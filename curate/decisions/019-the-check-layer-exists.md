# 019 — `curated/check/` exists, and what a check owes its reader

*2026-09-23. Closes the first half of TODO item 10, which asserted that
`curated/check/` did not exist. Two tables were already in it and a third was added
the same day; the item's claim had gone stale without anyone noticing, which is the
usual reason for writing one of these down.*

## What it is

The plan's phrase was that cross-check disagreement tables are **"part of the
product, not a by-product"** — an analyst asking *"can I trust this row?"* should get
a dataset to join against, not a paragraph in a document. That now exists:

| table | produced by | asks |
|---|---|---|
| `ais_key_landings.parquet` | `curate/checks/ais_key_landings.R` | does the STK vessel match agree with who actually lands fish? |
| `ais_key_registry.parquet` | `curate/checks/ais_key_registry.R` | does it agree with the vessel registry? |
| `afli_rafr_stofn_loss.parquet` | `curate/checks/afli_rafr_stofn_loss.R` | which vessels are missing logbook stations, and how badly? |

## The contract, as the three of them already practise it

Written down here because the fourth check will be written by someone reading this
and not those.

1. **A check reports; it never corrects.** `ais_key_landings.R` says it outright:
   reasoning from landings back onto the vid assignment would close the
   AIS → vid → logbook → AIS cycle `AGENTS.md` warns about. A reviewed conclusion
   re-enters through `overrides/` as an *input*. `afli_rafr_stofn_loss.R` is the same
   shape for a different reason — its repair is held pending an upstream answer
   (item 19), and the check is what makes the silence safe.
2. **One row per entity in question**, not one row per finding, so the table joins.
3. **It carries its own verdict.** A severity or `usable` column, so the consumer is
   not left to pick a threshold the check's author already had to pick. Where a
   threshold exists it is a named constant with the reason beside it —
   `MIN_STATIONS <- 50L`, because a vessel with six stations reads 17% on one lost
   row and that is noise, not a finding.
4. **It prints.** `source()` does not echo top-level values, which is how 21
   `knitr::kable` diagnostics in `ais_key.R` printed into nothing for months.
5. **It writes through `write_curated()`**, naming every input, so the table says
   what built it.

## What made this one worth adding

`afli_rafr_stofn_loss.R` was written to carry a warning rather than a fix: 53 vessels
lose 5% or more of their 2003–2019 logbook stations, seven lose a quarter or more,
one loses 78.4%, and until this ran nothing in the curated data said which they were.
Re-deriving the defect from the raw tables also reproduced every number in
`curate/corrections/afli_rafr_stofn_stations_dropped.yml` independently, and turned
up one the original measurement had missed: as a *rate* the loss falls monotonically
from 19.1% in 2004 to 0.02% in 2019, where the raw counts had suggested a 2008–2014
era effect. The counts peak where the volume is.

It is surfaced in `docs/afli-dropped-stations.qmd`, which is the first page of the
Quarto site that actually reads `curated/` — see below.

## The half of item 10 that is still open

`reference/species/` is an empty directory and `curated/reference/` has no species
table. That clause stays in TODO item 10, which is now only about that.

## A thing this uncovered

`docs/` "reads `curated/`" is stated in `AGENTS.md` and had never once happened.
The reason was mechanical: R reads `.Renviron` from the working directory at
startup, this repo keeps its `.Renviron` at the root, and quarto runs each `.qmd`
with `docs/` as the working directory — so `FISHYDATA` was unset for every page, and
any page that opened a dataset would have failed to render. `fishydata_root()` now
walks up to the repo root and reads it. Every existing page's data path
(`data/trail`, `data-dump/logbooks/...`) is inherited from the old tree and resolves
to nothing, which is why the gap never surfaced as a broken render.
