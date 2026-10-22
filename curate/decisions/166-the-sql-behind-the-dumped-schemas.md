# 166 — The SQL behind the dumped schemas, kept from Oracle's data dictionary beside each dump

*2026-10-22. The maintainer asked: have we dumped the SQL behind the schemas we have dumped, and if not, we should,
if possible. Written by Claude (AI). The code, the checks and the counts are Claude's and have not been checked by a
person. The maintainer ran it twice the same day, and Claude checked the files (below). The second run added the
fields table (the columns with their defaults and comments), which the maintainer asked for after the first.*

## The answer: no

Checked on the store, 2026-10-22. Each of the 28 dumped schemas in `raw/oracle/` holds its tables' and views' rows,
`_overview_tables.parquet`, `_overview_fields.parquet` and `_data-dict.yaml` (27 of them: kvoti has none). Between
them they carry Oracle's comments, types, row counts and the dump stamps, and no definition: no `.sql` file, no text
column in any overview, none in `_catalogue/objects.parquet`. `_catalogue/` also holds eight CSV files of 2026-10-16
that no script in the repo writes. They are dictionary probes: names (six KVOTI code objects whose source the account
sees, five materialized views, the dependencies of AGF's views) and two lines of code, not the definitions.

## What the account can read

Measured before this record, read-only, through `dump_connect()` (RJDBC):

- **Every view's text.** `ALL_VIEWS.TEXT`, a LONG, gave all 1,574 views outside Oracle's own schemas, each as long as
  `TEXT_LENGTH` says, in 77 s, 1.26 MB (the maintainer's probe, 2026-10-22, in
  `$FISHYDATA/archive/2026-10-view-sql-probe/`). `TEXT_VC` cuts 27 of them at 4,000 bytes. `DBA_VIEWS` is refused
  (ORA-00942), and so is `DBMS_METADATA.GET_DDL` (ORA-31603). The account has `SELECT ANY TABLE`, but not
  `SELECT_CATALOG_ROLE`, `SELECT ANY DICTIONARY` or DBA.
- **Stored code in part.** `ALL_SOURCE` shows the code the account owns or may execute: on 2026-10-16, KVOTI's
  packages `KVUTIL`, `KVOTASTADA` and `GENGI` and three functions, and nothing of AGF's. `KVOTI.LINU_IVILNUN` is not
  shown (decision 163). Nor is `ADB.LATLON2DEC`, which `ADB.STATION_V` calls to decode positions: `ALL_DEPENDENCIES`
  names it, but it has no row in `ALL_OBJECTS`, no line in `ALL_SOURCE`, and calling it gives ORA-01031 (the same
  probe). So the dependencies say which code a view calls even where its source is hidden.
- **Triggers with their bodies** (STK.TRAIL's two, decision 163), **dependencies** (a view to the function it calls)
  and **synonyms**.

## What is built

- `oracle_code()` and `dump_oracle_code()` (`R/dump_oracle.R`), run for every dumped schema by `dump/oracle/code.R`.
  Each schema gets `raw/oracle/<schema>/_code/`, with one parquet file per dictionary view, named after it. A file
  holds the schema's rows as Oracle holds them, the columns named as Oracle names them, in lower case:
  - `all_objects`: every object, with its status, creation time and last DDL time;
  - `all_tab_columns` and `all_col_comments`: the fields table, every column of its tables and views with its type,
    width, nullability and default, and its comment (both added after the first run, at the maintainer's request:
    `_overview_fields.parquet` has the comments but no default, since a default is a LONG);
  - `all_views`: each view's text;
  - `all_mviews`: each materialized view's query;
  - `all_source`: stored PL/SQL, line by line;
  - `all_triggers`: each trigger's header and body;
  - `all_synonyms`;
  - `all_dependencies`.

  Beside them, `_overview.parquet` gives per dictionary view the rows written, or the refusal with Oracle's code, the
  seconds taken, and notes. The notes say whether each LONG text is as long as Oracle says, and which of the
  schema's code objects show no source. Every file carries the dump stamps (`fd.dumped`, ...).
- An empty dictionary view is written, as a file of no rows: it is a result. A refused one writes nothing, and an
  earlier file stays, as in `dump_oracle_schema()`.
- The run's log is `raw/oracle/_logs/<time>_code.log`. `.dump_schemas()` and `sync.sh` leave `code.R` out, as they
  leave out `catalogue.R`.
- `tests/test_dump_oracle_code.R` runs on a DuckDB stand-in, with `dump_connect()` refused.

## Choices, and why

- **Parquet, not `.sql` files.** It is one record, stamped like the rest of the dump, with the text kept byte for
  byte (Icelandic letters, carriage returns), and it is read the way the rest is. A `.sql` file per object would be
  a second copy with no stamp. Names also collide as file names: a package and its body share one, quoted names that
  differ only in case meet on a case-blind disk, and names hold `$` and `#`. The text is one query away, e.g. in
  DuckDB: `SELECT text FROM '<schema>/_code/all_views.parquet' WHERE view_name = 'STATION_V'`.
- **A file per dictionary view, not a `view_sql` column in `_overview_tables.parquet`** (the probe's proposal).
  Every data dump rewrites that overview, and it has no row for a package, a trigger or a synonym. The sources'
  header columns differ, and a source that fails keeps its own earlier file.
- **A run of its own, not a step of `dump_oracle_schema()`.** The text is LONG: RJDBC reads it, and ROracle cannot
  (`oracle_fields()`, hafdruna 2026-10-16). The schema dumps run on the server through ROracle (decision 109), so
  there the text would fail every time. This run reads the dictionary only and takes minutes, so it runs from the
  Mac through what `dump_connect()` returns there, RJDBC, as `catalogue.R` does. `DBMS_XMLGEN.GETXML` would give
  ROracle the text as a CLOB: it did through RJDBC on six views. But parsing XML turns a carriage return into a line
  feed, and the route is untried with ROracle, so it is not built.
- **The schema's rows only.** A trigger is the schema's when it owns the trigger or its table, so one on another
  dumped schema's table is in both files. A synonym is the schema's when it owns it, or when it is a public one naming
  the schema's object. A dependency is the schema's when it owns the dependent object. So the files say what the
  schema's objects read, not who reads them; the union over all schemas gives the other direction, within those dumped.
- **A column's default in a query of its own.** A query with a LONG is fetched a row at a time, about 55 ms a row
  (the first run), so the 21,869 columns of the dumped schemas would take 20 minutes. `oracle_code()` reads the
  other columns of `ALL_TAB_COLUMNS` for every row, and `DATA_DEFAULT` only where `DEFAULT_LENGTH > 0`, joined on
  the table and column.
- **Left out:** constraints and indexes. `ALL_CONSTRAINTS` keeps its search condition as a LONG, one row for every
  NOT NULL column, and a LONG costs about 50 ms a row through RJDBC (1,574 views in 77 s). They define tables rather
  than the SQL behind the data, and the columns are in `_overview_fields.parquet` already.
- **Persons' data.** The code text is kept whole under `$FISHYDATA`, as the dumps are; at least one view's text names
  a personal account. Read it by counts and names of objects, never by printing the text of a personal schema.

## The first run

The maintainer ran `Rscript dump/oracle/code.R` on 2026-10-22, 12:32 to 12:33 (1 min 53 s), through RJDBC at 9c607b5,
with this code not yet committed (`dirty = true`). The log is `raw/oracle/_logs/20261022T123204_code.log`. Claude
checked the files against `_catalogue/objects.parquet`:

- **28 schemas, 196 dictionary views read, none refused.**
- **Views.** The 617 views in the files are the catalogue's 617 views of these schemas, both ways. Every one has its
  text, its bytes equal to `TEXT_LENGTH`. 15 are longer than 4,000 bytes, which `TEXT_VC` would have cut (kvoti 6,
  ask 4, agf 2, biota, gear and vor 1 each). 116 hold letters outside ASCII. 550 kB in all.
- **Objects.** `all_objects`' tables and views are the catalogue's 1,913, both ways. Besides them: 1,278 indexes, 169
  synonyms, 18 functions, 5 sequences, 4 packages and 4 materialized views.
- **Stored code is shown in three schemas only.**
  - channel: 15 functions (geographic conversions and date parts, 295 lines);
  - kvoti: the specifications of the packages `KVUTIL`, `KVOTASTADA` and `GENGI`, and 3 functions (1,096 lines), with
    no package body;
  - afli: the package `RANDOM_GEN` (15 lines).
- **Code the dumped schemas call but cannot show.** `all_dependencies` names it, and it has no line in
  `all_source`:
  - `ADB.LATLON2DEC`, which decodes `adb.station_v`'s positions;
  - `AGF.LODS_SLAEGT_PKG`;
  - ASK's `ADGANGUR_PKG`, `LANDANIR_PKG`, `VEIDARFAERI_PKG` and `VIGTUNARTEGUNDIR_PKG`;
  - `KVOTI.MILLIFAERSLUR_BIDLARI`;
  - VOR's `LODS_VIGT_STUDULL`, `PKSTUDLAR` and `UTBUAVIGTOGRAD`;
  - `VIGTUNARLEYFI_PKG`, in a schema not dumped;
  - and Oracle's own (SYS, MDSYS).
- **Triggers.** 393 rows hold 378 triggers: 15 of afli's and fs_afli's are in both schemas' files. 291 are enabled
  and 102 disabled, and every one has its body. Four are owned by `FS_ASK` and fire on `ASK.VEIDARFAERI`.
- **Materialized views.** 4, each query as long as `QUERY_LEN`: kvoti's three, last refreshed 2021-04-28, and
  `STK.MOBILE_SKIP_MV`, refreshed that day but in `COMPILATION_ERROR`.
- **Synonyms and dependencies.** 104 synonyms (15 public, none through a database link) and 1,847 dependencies.

## The second run: the fields table

The maintainer ran it again on 2026-10-22, 12:40 to 12:43 (2 min 31 s), at the same commit and with the same
uncommitted code (`dirty = true`). The log is `raw/oracle/_logs/20261022T124034_code.log`. 252 dictionary views were
read in 28 schemas, and none was refused. The first run's files were written again; Claude checked the two new ones:

- **`all_tab_columns`** holds the same 21,869 columns as the schemas' `_overview_fields.parquet`, schema by schema,
  both ways. 493 have a default, each as long as `DEFAULT_LENGTH`. The most common are `0` (195), `SYSDATE` (111),
  `USER` (28) and the session user in other forms: the account that entered the row. No column is an identity
  column. Reading the defaults in a query of their own kept the 28 schemas' columns to 38 s.
- **`all_col_comments`** gives every one of those columns the same comment as `_overview_fields.parquet`, NULLs
  included. It also holds 2,781 rows on 114 tables in Oracle's recycle bin (named `BIN$...`: dropped, and not in
  `all_objects` or the catalogue): rdbes 2,539 on 81 tables, logbook 179 on 22, fs_ufs 29, channel 24 and biota 10.
  They are kept as Oracle holds them. A join on `all_tab_columns` (table and column) leaves them out.
