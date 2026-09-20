# fishydata

Detecting and correcting errors in Icelandic fisheries data — logbooks, landings,
vessel registry, AIS — and publishing the result as a sweep of parquet files that
can be analysed directly.

## Quick start

Data lives outside this repo. Set the root once:

```
# ~/.Renviron
FISHYDATA=/path/to/fishydata-store
```

Then:

```r
source("R/paths.R")
duckdbfs::open_dataset(fd_curated("logbook", "station.parquet"))
```

## Orientation

- `AGENTS.md` — the rules, the layout, the conventions.
- `curate/decisions/000-restructuring.md` — why the project is shaped this way.
- `docs/` — the Quarto site.

Supersedes `~/stasi/logbooks` and `~/stasi/fishydata_2024-2026`, both archived.
