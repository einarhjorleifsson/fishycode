# 018 — Opening a curated layer directory gives you five tables stacked into one

*2026-09-23. Found because the maintainer hit an error on
`open_dataset("~/stasi/fishydata/curated/ais")`. The error turned out to be the
best-behaved case.*

## What was reported

```
Binder Error: Hive partition mismatch between file
  ".../curated/ais/ping/year=2007/part_001.parquet" and ".../curated/ais/trip.parquet":
  key "year" not found
```

`curated/ais/` holds two tables: `ping/`, hive-partitioned by year, and
`trip.parquet`, flat. `open_dataset` globs both, finds one partitioned and one not,
and refuses. Opening either directly works.

## The part that matters

Six of the seven curated layer directories do **not** refuse. They succeed, and the
answer is wrong.

| layer | files | `open_dataset(dir)` |
|---|---|---|
| `curated/ais` | 1 file, 1 dir | **fails** — hive mismatch |
| `curated/check` | 2 | opens |
| `curated/landing` | 2 | opens |
| `curated/link` | 1 | opens |
| `curated/logbook` | 5 | opens |
| `curated/reference` | 6 | opens |
| `curated/vessel` | 3 | opens |

`curated/logbook` holds five unrelated tables:

| table | rows | cols |
|---|---|---|
| `catch.parquet` | 16,741,776 | 4 |
| `fishing_sample.parquet` | 7,219,248 | 37 |
| `lid_map.parquet` | 780,203 | 4 |
| `station.parquet` | 7,219,248 | 14 |
| `trip.parquet` | 1,815,425 | 12 |

`open_dataset("curated/logbook")` returns **33,775,900 rows and 4 columns** —
`.sid, sid, catch, schema`. That is every table concatenated (the five row counts sum
to exactly 33,775,900) under the schema of the **alphabetically first** file. Sixty-
three of the seventy-one columns are silently dropped. No error, no warning, and the
result looks like a perfectly ordinary 33.8 M-row table.

**So the failure the maintainer hit is the safe case**, and it is safe only by
accident — because `ping/` happens to be hive-partitioned. Had `trip.parquet` been a
directory too, `curated/ais` would have joined the other six in answering quietly and
wrongly.

## Why this is a defect and not user error

`AGENTS.md` states the deliverable as *"a sweep of parquet files an analyst opens and
works with directly, with no pipeline knowledge required."* Pointing a reader at
`curated/logbook` and having it return a plausible, wrong table is the precise failure
that sentence exists to prevent. Knowing that a layer directory is a namespace rather
than a dataset **is** pipeline knowledge.

## What would fix it, and why it is not done here

**One table, one directory.** `curated/logbook/trip/part-0.parquet` rather than
`curated/logbook/trip.parquet`. Then any path an analyst can point at is either a
table or a directory of tables that refuses to open as one, and the ambiguity is gone.

Not done, because it is the maintainer's call: it changes every `fd_curated()` path in
this repo, every `write_curated()` target, and any script an analyst already has. The
cost is real and the benefit is a class of silent wrong answers, so it should be
decided rather than slipped in.

**Interim, and true today:** open a table, never a layer.

```r
open_dataset(fd_curated("ais", "ping"))        # yes
open_dataset(fd_curated("ais", "trip.parquet")) # yes
open_dataset(fd_curated("ais"))                 # no - and the others do not even complain
```

## Not investigated

Whether `duckdbfs::open_dataset` can be given `union_by_name` so that a mixed
directory at least errors rather than truncating to the first schema. That would turn
six silent wrong answers into six loud ones without any layout change, and it is the
cheaper half of the fix if the restructure is declined.
