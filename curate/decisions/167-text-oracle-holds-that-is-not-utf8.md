# 167 — Text Oracle holds that is not UTF-8: the dumper makes it valid and says so

*2026-10-22. Asked by the session of decision 166, whose check found kvoti without a `_data-dict.yaml`. Written by
Claude (AI). The scan, the code and the test are Claude's and have not been checked by a person. Nothing under
`$FISHYDATA` was changed: the files stay as they are until the maintainer re-dumps them (below). **Re-dumped and
adopted 2026-10-22:** both files read whole in DuckDB with the dumper's note naming the bytes, and kvoti has its
`_data-dict.yaml` (`$FISHYDATA/archive/raw-oracle-redump_2026-10-22/README.md`).*

## Found

kvoti's four dump logs (hafdruna, ROracle, 2026-10-16 and 17) end with `_data-dict.yaml not written`: DuckDB refuses
`kvotategundir_heiti_jn.parquet`, whose value `"Makr\xEDll"` is not valid UTF-8. DuckDB refuses the whole file, so
every reader fails, not only the dictionary.

Every parquet file under `raw/oracle/` was scanned on 2026-10-22: 2,627 files, 10,277 text columns. The reader was
arrow, which reads text without checking it. All of them were read, and two files hold text that is not UTF-8. DuckDB
refuses both whole:

- **`kvoti.kvotategundir_heiti_jn`**: one row of 107, in three columns (`heiti`, `heiti_skammstofun`, `vefheiti`). They
  hold `Makr` ED `ll`, Latin-1's í, where UTF-8 has C3 AD. It is the journal's insert of quota species 36 (mackerel) on
  2019-06-28 08:20. The update at 09:37 and the table itself hold valid UTF-8. The journal's triggers write `:new` for
  both (`kvoti/_code/all_triggers.parquet`, decision 166), so the insert is the value as it was first written.
- **`ops_einarhj.ices_landed_catch`**: 7 rows of 416,353, all in `species`, all one value: `Henslow`, then FC BE 8C A3
  A4 BC, then `s swimming crab`. The six bytes encode the four characters `<92>` as one, most likely, and `<92>` is how
  R prints Windows-1252's ’. Its `_data-dict.yaml` was written on 2026-10-17 only because that step reads the first
  10,000 rows for its examples, and these 7 rows lie further on.

**The bytes are as Oracle holds them.** The same ROracle query gave valid UTF-8 for the table's own row and for the 96
other journal rows with Icelandic letters. A driver converts text by the column's character set, not row by row. From a
single-byte set, every byte would have become a valid character. So the database's set is UTF-8, and the bytes were
stored as a client sent them, most likely a client that said it sent UTF-8 and sent Latin-1. This was not looked into
further, because it decides nothing (the maintainer, 2026-10-22: "do we need to know the root cause?").

**Found while testing.** `yaml::write_yaml()` aborts R (SIGABRT, no message) on text that is not UTF-8. The dictionary
took Oracle's table and column comments from memory, not from the checked file. So one stray byte in a comment would
have killed a dump at its last step: the overview written, the dictionary not, and no summary in the log.

## Chosen

The dumper's defect is that it wrote a parquet file whose text is not UTF-8, which the format requires, and said
nothing about it. Now `.write_raw()` checks every text column of every frame it writes (`.utf8_valid()`, `R/dump_oracle.R`):
tables, the years of a partitioned table, both overviews, the code dump and the catalogue.

- A byte outside a valid UTF-8 sequence is read as Windows-1252, or as Latin-1 where 1252 has no character. Valid
  sequences are kept.
- The note names the columns, the number of values and the bytes. It goes to `fd.note`, to the overview's `note` and
  to the table's `details` in `_data-dict.yaml`, as the NUL fallback's note does.
- `dump_oracle_schema()` makes Oracle's comments valid before the overviews and the dictionary use them.

**Why Windows-1252.** It reads the kvoti value as the table corrected it: Makríll. For the ops_einarhj value it gives
`Henslowü¾Œ£¤¼s swimming crab`. That is wrong, but every stray byte keeps a character of its own, and the note gives the
bytes. Replacing them with U+FFFD, or escaping them as `<ed>`, would turn kvoti's value away from what it says. This is
not a correction. The dump stays as Oracle holds it, as near as UTF-8 text can come. A correction, if one is wanted,
belongs in `curate/`.

**Not measured.** Through RJDBC, Java's decoder most likely replaces such bytes with U+FFFD before R sees them. The check
cannot see that. Sessions cannot reach Oracle, so it was not tried.

**Tested** on the DuckDB stand-in, which hands R the bytes as ROracle did: `tests/test_dump_oracle_text.R` (29 pass).
It covers a table, both overviews, a table comment and a column comment, and `_data-dict.yaml` being written. The
dumper's other two tests still pass (`test_dump_oracle.R` 42, `test_dump_oracle_code.R` 47).

## The maintainer's to run

A resumed run keeps both files, because their overviews say `written`, so `run_dump("kvoti", resume = TRUE)` would not
touch them. Instead, run both schemas in full on hafdruna, once this change is pulled there:

```r
run_dump(c("kvoti", "ops_einarhj"))
```

kvoti took 1 h 43 min on 2026-10-16, and its five views that fail in Oracle itself will fail again. Then copy to the Mac
(`dump/oracle/sync.sh`) and run `compare_dumps()` before the copy replaces the Mac's. **Check:** DuckDB reads both files
whole, each overview row carries the note, and kvoti has its `_data-dict.yaml`. TODO 110 holds this.
