# 121 — orri and ops$einarhj dumped whole, seven schemas added, and a catalogue of what Oracle holds

*2026-10-17. Written by Claude (AI-assisted) at the maintainer's request: dump the whole of `orri` and `taxon` for a
proper species table, all of `ops$einarhj`, and name any other raw data that is sorely missing. The choices below
are the maintainer's, made the same day. Measured: Oracle's data dictionary only, read from Claude's shell with the
maintainer's leave. No table was read, so every row count here is Oracle's estimate as of its last analysis
(`last_analyzed`). Nothing is dumped yet: the dumps run on the server (`dump/oracle/README.md` §12).*

## The catalogue

Until now a schema was found by name, from `mar`'s readers or a remark. `dump/oracle/catalogue.R` (with
`oracle_catalogue()`, `R/dump_oracle.R`) lists every table and view the account can see, with Oracle's comment, row
estimate and number of columns, to `raw/oracle/_catalogue/objects.parquet`. Its first run (RJDBC from the Mac, 12 s)
found 14,057 objects in 128 schemas, of which 5,687 objects in 112 schemas are not Oracle's own, and 30 of those are
personal `ops$` schemas. 13 had a dump script. The file is stamped `dirty`: its code was not committed when it ran.

## What is dumped now

| schema | how | why |
|---|---|---|
| `taxon` | whole: 16 objects, ~11 k rows | MFRI's species register. `tegund_v` gives each species number its names, rank, hierarchy, WoRMS id, FAO taxon id and FAO 3-alpha code (TODO 10) |
| `orri` | whole but 8 objects: 22 of 30 | `fisktegundir` (686, the logbook codes), `fao_fisktegund_vorpun` to FAO 3-alpha, the FAO gear and area mappings, place names (`ornefni`). Before, only the two gear tables |
| `ops$einarhj` | whole: 52 tables, ~20 M rows | the MMSI list of 2023-01-15 (TODO 71) and the earlier versions of the STK key that plan 022 §3 reviews. Before, the five tables the pipeline reads |
| `ufs` | whole but 18 objects: 45 of 63, ~0.6 M rows | the Directorate's reference tables: `fisktegundir`, the landed species with FAO code, which agf's views read; ports, gear, operator classes; `skipasaga`, its vessel history (56,986 rows) |
| `fs_ufs` | whole: 4 tables | `landing_species` (169): each landings species code to orri's code, MFRI's taxon number, names, WoRMS id and target assemblage |
| `uv` | whole but 3 objects: 9 of 12 | 5,948 areas (real-time closures, regulations, protected areas) with valid from and to, 25,929 boundary points, and the gear and species each concerns |
| `rdbes` | whole: 43 objects, ~0.2 M rows | `metier` (72,147: allowed metiers by area, gear, target assemblage and mesh range) for metier level 6 (plan 015 §4 a); ICES's harbour, species and AphiaID-to-ASFIS lists |
| `dw` | whole but 7 objects: 24 of 31 | `dw_aflaskeyti`, 21,627 rows of ERS catch messages with flag state, haul positions and FAO codes: a first lead to TODO 62's foreign logbooks; the FAO code lists |
| `fs_afli` | whole but 6 tables: 74 of 80, ~115 M rows | the Directorate's copy of the logbook schema. Its estimates, older than afli's, are still larger than afli's dump: `rafr_stofn` 1,318,771 against 1,149,278, `rafr_afli` 4,159,300 against 3,625,502. It may hold records afli lacks (TODO 76) |

**Left out, and why (maintainer, 2026-10-17):** registers of persons and companies, staff lists, contact details,
e-mails, user logs and IP addresses: `orri`'s `thjodskra`, `br_thjodskra`, `einst`, `fyrirt` and `starfsmenn` with its
three views; `ufs`'s `adilar` (commented "Þjóðskrá!") and its journal, the three views that add owners' kennitala and
names, and its logs; `uv`'s staff; `dw`'s owner tables; `fs_afli`'s recipients, applicants, agents, skippers and
e-mails. fishycode has no use for them, and `_data-dict.yaml` copies examples of every column. `dw`'s four copies of
the landings (15 M rows) are left out as copies. Each script names what it leaves out.

Overturned for persons by decision 159 (2026-10-21): orri's, ufs's, uv's and fs_afli's are dumped; dw's skips stay.

**Not changed:** the dumps made before hold such tables: `afli`'s copies of the same contact tables, and the
vessel register's owners. Whether to drop them is not asked here.

## Code

- `.dump_schemas()` runs the 20 schemas small first, `fs_afli` before `stk`; it and `sync.sh` leave out `catalogue.R`.
- `.dump_finished()` counts an overview that lists objects without dumping them as unfinished. So
  `all.R --resume orri ops_einarhj` now dumps the rest of both and keeps the files of 2026-10-16. Before, `--resume`
  skipped both as finished; and a run without `--resume` restamps the five files `_targets.R` reads (`mmsi_raw`).
- `dump_oracle_by_year()` counts the years a resumed run keeps. `afli.sjalfvirkir_maelar`'s overview said 2,714 rows,
  the years fetched in the last run. The files hold all 28,234,223, by their `fd.rows` stamps and by a count.

## Found, not dumped

- `bathymetry.olex_island`: 20.1 M Olex depth soundings around Iceland (2016), finer than GEBCO near the coast.
- `fiskist.ttrail`: 1.8 M positions with the STK trail's columns; its time span and source are not known.
- `fiskifelagid`: landings 1966-1981 by vessel, and before 1994 by vessel, gear, month and port. Decision 103 puts the
  years before 1990 out of scope.
- `kvotix` (quota and landing logs), `itis` and `worms` (taxonomies; `taxon` carries WoRMS ids), `channel`, `biota`,
  `fiskar`, `hafvog` (surveys and biology), `afladagbok` (a smaller copy of the tour app in `fs_afladagbok`, plan 019),
  `taxon_log` (a journal).

Outside Oracle the legal lines are still missing: Iceland's baselines, the 12-mile line and the EEZ (plan 012 step 5,
TODO 34). `uv` may hold the trawl limits; that is not checked.
