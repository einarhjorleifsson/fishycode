# 187 — `fishydata` stays on this laptop for now; its backup is the essentials at MFRI, once IT names the place; the layer layout is kept and documented

*2026-10-23. The maintainer's answers to plan 001 §5 and decision 018's open end, asked by Claude (AI) in a status
review of the repository. The sizes were measured read-only by Claude the same day; nothing was moved or built.*

## Asked

TODO 15 had three questions left: where `fishydata` lives once it leaves this laptop, whether it is backed up, and
(decision 018, carried by TODO 15 since the audit of 2026-10-23) whether a curated layer directory should hold one
table only, since `open_dataset()` on a layer directory stacks unrelated tables under the first file's schema without
an error.

## Measured (2026-10-23)

- `$FISHYDATA` is 552 GB, not the 404 GB plan 001 §5 recorded: `staging/` 233, `raw/` 195 (`raw/ais/astd` 128,
  `astdB` 17, `EmodNet` 3.3, `raw/oracle` 42, `raw/external` 1.3), `legacy/` 60, `curated/` 49, `archive/` 15,
  `exports/` 0.01.
- The `once` project's outputs under `curated/` and `staging/` are 56 paths, 17.8 GB (`tar_meta()` of
  `TAR_PROJECT=once`).
- The disk is 88 % full: 112 GB free of 926.
- This Mac has no Time Machine destination (`tmutil destinationinfo`), and nothing else seen copies the store.
- Nothing in fishycode or the two predecessor repositories reads `$FISHYDATA/legacy/` (a search of their code and
  pages): it holds the `logbooks` repository's last outputs, parked there in September as the restructuring gate's
  baseline (decision 000), and the old repository's links to it are broken (decision 168).

What cannot simply be rebuilt is `raw/` (the ASTD deliveries, the Oracle dumps as they were on their day, the
external sources, among them the mbl scrape that a bot check now closes, decision 141), `archive/` (the review drafts
and study scripts, such as TODO 25's lists) and the `once` outputs (frozen and reviewed, decision 075): about 230 GB.
`staging/` and `curated/` rebuild from these and the code.

## Chosen (the maintainer)

- **Backup:** the essentials go to MFRI (`raw/`, `archive/`, the `once` outputs, `exports/`), but not yet: "I need to
  talk to the IT about where this should go." TODO 15 is now that one question, blocked on IT. Until then the store has
  no copy.
- **Home:** this laptop for now. The home is revisited when free space falls below about 50 GB. `legacy/` (60 GB) is
  a candidate for removal, since nothing reads it.
- **Layout:** kept. Each table is a file of its own, or a directory of its own when partitioned, and a layer directory
  is never opened whole. `docs/pipeline.qmd` says so where it introduces the three layers, and the data dictionary
  names each table's path. No path changes, no rebuild.

## Also

ramb 8a0ae92 (TODO 91's pkgdown index) was pushed on the maintainer's word in the same sitting (decision 186).
