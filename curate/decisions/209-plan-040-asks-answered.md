# 209 — Plan 040's asks answered: precision per row, English labels with the Icelandic kept, a failing assert blocks a dump until explained, every curated table in the dictionary

*2026-10-23. The maintainer's answers to plan 040 §6 b-f (TODO 124), asked by Claude (AI) in a status review of the
repository. Nothing is built beyond decision 176's phase 1.*

## Chosen

- **b. Precision where one curated column mixes sources is a per-row column,** as `basis` is (the logbook's positions,
  TODO 126's decision of the same day), with each source's format and precision by app and period stated in its
  overlay too.
- **c. Code labels in English, with Oracle's Icelandic label kept beside them** as given.
- **d. A failing `assert` blocks a dump's adoption until it is explained:** the data changed (the assert is amended,
  with why) or the dump is wrong (re-dumped). Every difference explained, as the checks rule asks.
- **e. Every curated table gets a dictionary entry;** the check tables in short (the table, its key and verdict
  columns), since the rest of a check's columns are its own working.
- **f. Confirmed:** a column with no values in a dump stays named but untyped, Oracle's declared type in `details` and a
  `todo`, until a dump holds a value (decision 176's reversible form).

## Left (TODO 124)

Plan 040's phase 2 runs inside plans 038 and 039 (each reader writes its overlay and its staging dictionary in the same
change); phase 3, the curated dictionary carried in the files, after them.
