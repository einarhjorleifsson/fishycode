# 325 — The archive's bulk data deleted from ten finished studies; a study is kept as its record, not to be rerun

*2026-11-17. At the maintainer's word ("Yes, all of it"), after the question whether the archive's studies are now
redundant, "at least in terms of data stored". Measured, chosen and carried out by Claude (AI); no person has checked it.*

## The rule, in the maintainer's words

"I think in general what was archived was based on ad-hoc decision. What is not important is being able to rerun
things, more importantly is a bookeeping of what was tried, what worked, what not."

So a study under `$FISHYDATA/archive/` is kept for its record: the README (what was asked, tried and found), the
scripts, the notes, the logs and the small tables its numbers come from. Its bulk data need not be kept once the work
it served is finished and recorded.

## What was measured

After decision 324 the disk had 97 GiB free. `archive/` held 64 GiB in 194 studies; 21 of them held 58 GiB, the other
173 about 6. Each of the 21 was checked against what still reads it: fishycode's code, the open `TODO.md` items, and the
scripts of other studies.

## Deleted

| Study | What | Files | GiB |
|---|---|---:|---:|
| `2026-11-11-named-features` | `rerun/up` and `rerun/down`, the two fresh reads of every chart, compared on 2026-11-15 (its README, `out/cross/`) | 452,514 | 15.68 |
| `2026-10-freed-fixes` | parquet over 10 MB | 36 | 4.67 |
| `2026-11-06-plan048-step1` | parquet over 10 MB | 11 | 2.78 |
| `2026-10-30-plan054-ais-intervals-and-gap` | parquet over 10 MB | 16 | 2.05 |
| `2026-11-06-plan048-step3` | parquet over 10 MB | 10 | 0.90 |
| `2026-10-rebuild-prep` | the copies in `before/` | 11 | 0.88 |
| `2026-10-17-rebuild` | the copies in `before/` | 8 | 0.75 |
| `2026-11-07-plan048-step6` | parquet over 10 MB | 11 | 0.59 |
| `2026-11-07-port-call-by-vessel` | parquet over 10 MB | 11 | 0.59 |
| `2026-11-01-vms-clock-scan` | parquet over 10 MB | 8 | 0.41 |

29.3 GiB by file size. Each study keeps a list of what was deleted (path, bytes, modified) in
`deleted_2026-11-17.csv` (`.csv.gz` for named-features) and a dated note at the end of its README with the
maintainer's words. `2026-10-17-rebuild` had no README; one was written from its scripts and decisions 127-129.
Nothing linked into the deleted files, and none of the studies' plans or TODO items is open (plan 048, plan 054,
plan 060 executed; the rebuilds of October recorded).

Free disk: 97 GiB before, 121 GiB after (`df -g`). The difference, 24 GiB, is less than the files' sizes, most likely
because the fresh-run trees were partly APFS clones (`scripts/38_fresh_run.sh` cloned the chart windows and region
tables), whose blocks are shared with files that remain. Not measured further.

## Kept, because something still reads it

- `2026-10-28-duckdb2/synth/` (3.5 GiB): TODO 150 and `curate/issues/duckdb.yml`'s reprex.
- `2026-11-01-phase-model/` (1 GiB): read by six other label studies, among them the one TODO 72 cites.
- `2026-11-01-labels-out-of-sample/` (1.8 GiB): TODO 72.
- `2026-10-xml-oracle-map/` (1 GiB): TODO 115 and the evidence in `dump/oracle/meta/afli.yml`.
- `2026-10-time-offsets-towed/`: TODO 115. `2026-11-04-chart-names-coast/`: TODO 186.
  `2026-11-11-local-features/`: TODO 199. `2026-11-14-port-layer/` (plan 075, parked) and
  `2026-10-afli-layers/` (parked).
- `2026-11-11-named-features/out/` (15 GiB): plan 074 is open. Its text-recognition tiles (about 285,000 small images)
  are the study's own to prune when it closes.

## Left

- 40 of the 194 studies have no README, the largest `2026-10-28-duckdb2` (3.6 GiB); by the rule above their record is
  incomplete. Not taken up here.
- The rule is written here only: neither `AGENTS.md` nor `check_session_close()` says what a study keeps.
