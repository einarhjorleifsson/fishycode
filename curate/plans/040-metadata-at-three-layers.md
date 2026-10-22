# 040 — What each column means, in its metadata: units, formats, precision and codes, at raw, staging and curated

**status:** partly built — phase 1 built 2026-10-22 (decision 176): the overlay's format (`dump/oracle/meta/README.md`),
the dumper's merge and its S12 and S07 fixes, `rewrite_data_dict()` and `check_data_dict()` (`R/data_dict.R`), overlays
seeded for kvoti, adb, afli, dw and stk, all tested on clones of the dumps; the real raw dictionaries not yet rewritten
(the maintainer's go); written 2026-10-22 at the maintainer's request, the three layers measured read-only the same day
(§2); ask a answered, f implemented in its reversible form (§6) · **2026-10-22** · **see:** plans 037, 038 and 039,
TODO 51, 110, 111, 113, 114, 119, 120 and 124, decisions 029, 109, 111, 165, 166, 169, 170 and 176, `docs/grammar.qmd`
(Units), `docs/data-dict.yaml`, `R/dump_oracle.R`, `R/data_dict.R`, `R/write_curated.R`, `curate/corrections/`

Drafted with AI assistance (Claude) on 2026-10-22. The aim and the split of the work are the maintainer's: "the yaml
metadata, run via the data-dict, and there the unit is important to keep account of"; "also important to keep track
of is precision (like lon-lat), formats of lon lats"; "what codes stand for, e.g. 'I' into harbour, 'U' out of
harbour ... can also be part of the metadata yaml". The phasing of §4 was agreed the same day: the convention first,
filled in by plans 038 and 039 as they open each reader, the curated layer after them.

## 1. Why

Every unit, format and code defect found so far was stated somewhere upstream, but only in free text, a view or a
trigger, and was found late, by accident or by a study:

- lods' herring, capelin and blue whiting are tonnes (decision 169): said in two views and a trigger, not in the
  column;
- adb's positions are ddmmss integers that `station_v` reads as ddmm.hh (decision 165), and its depths are
  fathoms, its trawl headline feet, its dredge feet taken as 0.3042 m (decisions 165, 170);
- afli's depths move from fathoms to metres vessel by vessel over 2010-2012 (`afli_depth_units`), its end depth is
  1.83 times the depth sent (TODO 113), its end longitude a copy of the latitude in 2010-2012 (`afli_end_longitude`),
  its gutted catch x 1.25 labelled recorded (TODO 114);
- `dw_aflaskeyti` has latitude and longitude swapped on every row (`aflaskeyti_coordinates`) and gutted weight
  labelled live for some vessels (`aflaskeyti_weight`);
- STK's pings with longitude equal to latitude are placeholders (`ais_invalid_position`);
- codes whose meaning decides a sum: lods' `gerd` A is the export surcharge that K carries (decision 169, amended),
  STK's `I`/`U` rows are port events, not fixes (decision 164).

Each is now known, in a decision or a correction, but none sits next to the column it is about, and nothing checks a
new dump against it. The data-dict format can hold all of it (§3.1), and its validator can test a claim on the data.

## 2. What exists (measured 2026-10-22, read-only)

**Raw.** `dump_oracle_schema()` writes a `_data-dict.yaml` beside each schema's dump: 27 files (kvoti's comes with
the re-dump of 2026-10-22, decision 167), 13,481 columns, 7,181 of them numeric. Descriptions are Oracle's comments;
ranges cover the file, examples come from its first 10,000 rows. Every numeric column is typed plain `number`, so
none can carry `units`, and none does. 289 of the 7,181 name a unit in their comment. In the tables the adapters read:
lods 2 of 11 numeric columns (and not the tonnes), afli 12 of 107, fs_afladagbok 17 of 54, adb 13 of 58, agf 0 of 17,
dw 5 of 16. `data-dict validate-spec` fails 21 of the 27 files, nearly all on two causes: S12, a datetime range
written `2003-06-18 17:56:20` where the spec wants `2003-06-18T17:56:20Z` (the dumper's formatting), and S07, a
column with no examples (empty tables and columns). asfis, ask, fiskifelagid, fs_ufs, kvotix and ufs pass. The files
are rewritten by every dump, so nothing written into them by hand survives.

**Staging.** No YAML: 0 files beside 768 parquet files in 24 source folders. The conversions the adapters make
(fathoms x 1.8288, feet x 0.3048, tonnes x 1000, ddmmss decoded, signs turned) are in their code and comments only.

**Curated.** `docs/data-dict.yaml` in the repo: 51 tables, 766 columns, covering 41 of the 105 curated tables (a
partitioned dataset counted once): all of `ais`, `landing` and `link`, 8 of 10 `logbook`, 7 of 9 `reference`, 12 of
36 `check`, 3 of 13 `vessel`, none of the 26 in `vessel/register` and `vessel/skipaskra`. 387 numeric columns, none
typed `number(quantity)`, none with `units`; 71 name a unit in their description. 223 spec errors (S07 examples and
ranges, 11 S28 for the types `timestamp` and `double`) and 276 open `todo`s, so `validate-meta`, which stops at any
spec error, cannot run (TODO 51). The grammar's rule (`docs/grammar.qmd`, Units): metric everywhere, the unit in the
column name where the name alone would not say it, a conversion recorded in the dictionary. It is followed in part.

**The spec** (data-dict 0.0.3, `data-dict spec`), tested on a scratch file:
- `units`, free text, only on `number(quantity)` (S08 otherwise);
- an `enum`'s `values` may be a map, code to label (`{I: into port, U: out of port}`), the codes always strings;
- `time_zone: UTC` on a datetime;
- `relationships`, including a join on a date range, to a code table;
- `definitions`: named expressions (a derived value such as a column in standard units), parsed and type-checked by
  `validate-spec`, never evaluated;
- `constraints` with `assert`: row-level or aggregate expressions that `validate-data` evaluates;
- no fields of one's own: a property the spec does not define is an error (Q-1-18), so precision and position format
  go in `details`, with an `assert` that tests them.

## 3. The design

### 3.1 Raw: a hand-kept overlay per schema, merged by the dumper

A file per source schema in the repo, `dump/oracle/meta/<schema>.yml` (ask a), holding only the columns fishycode reads, in data-dict form, so
that the merged file still validates. For each column, what applies of:

- the measure (`number(id)`, `number(ordinal)`, `number(quantity)`) and `units`;
- a unit that depends on another column as a `definition` giving the value in standard units, e.g. lods'
  `magn_oslaegt_kg: magn_oslaegt * CASE WHEN fteg IN (30, 31, 34) THEN 1000 ELSE 1 END`;
- a position's stored form and sign in `details` (decimal degrees, ddmm.mm, a ddmmss integer, west positive or
  negative, WGS84 or not stated) and its decoding as a `definition`;
- precision in `details` (whole minutes, about 1.8 km of latitude; hundredths of a minute, about 18 m; seconds, about
  30 m; decimals of degrees), measured per period where it changes;
- code meanings: a short code set as an `enum` with labels in English, Oracle's Icelandic kept in `description`; a
  long or changing list (species, gear, ports) as `number(id)` with a `relationship` to the dumped code table, by date
  where codes change meaning (gear's old and new codes, `lods_fragang`'s periods);
- `time_zone: UTC` on every datetime (decision 111), and in `details` where a midnight means "no time recorded";
- `details: evidence ...`: Oracle's comment, a view or trigger (`_code/`), a data test, a decision or correction;
- an `assert` for each claim the data can test: `MOD(lat, 100) < 60` for ddmmss, the cod-equivalent ratio for lods'
  units, a range per vessel and period for depths.

`dump_oracle_schema()` writes its generated entry as now, then lays the overlay over it: the overlay wins on every
property it sets, the dump fills `range`, `examples` and `description`. The same function writes datetime ranges in
ISO 8601 with `Z` (the S12 fault) and handles a column with no values (S07; ask f). When a dump is adopted (decision
109's swap, after `compare_dumps()`), `validate-spec` and `validate-data` run on the merged file, and a failing
`assert` is explained before the dump replaces the old one: a source that changed its units or format shows there,
not years later.

### 3.2 Staging: a dictionary beside each adapter's output

Each adapter writes a `_data-dict.yaml` beside its tables, from a short column table in the adapter read by one
shared function in `R/`: name, type and measure, units, basis, and `details: from <schema.table.column> (<its unit>),
x <factor>` or the decoding used. This is the ledger of conversions from raw units to the grammar's, the one place
where "this metre came from those fathoms" is written for a machine. `validate-meta` checks it against the files the
adapter wrote.

### 3.3 Curated: the dictionary made true, then carried in the files

`docs/data-dict.yaml`, after plans 038 and 039 have settled the curated columns:

- every measure `number(quantity)` with `units`, every key `number(id)`, every code an `enum` with labels or a
  `relationship`;
- positions in decimal degrees with the precision of each source and period in `details`, or in a column of its own
  per row where one column mixes sources (ask b);
- the 223 errors fixed so `validate-meta` runs (TODO 51), and the 64 tables it lacks written or declared out (ask e);
- `write_curated()` stamps each file's own dictionary entry, units included, into its parquet metadata, as ramb does
  (`ramb.data_dict`), with a check that file and dictionary agree, so a file that leaves `$FISHYDATA` takes its
  meaning with it.

## 4. The phases

1. **The convention and its machinery** (now, alongside plans 038 and 039, touching none of their files). The overlay's
   format and place; the dumper's merge, its S12 and S07 faults, the checks at adoption; the overlay seeded with the
   cases of §1, each already established in a decision or correction. Done when the 27 raw files and kvoti's validate,
   and the seeded `assert`s pass, or fail where §1 says they should, on the current dumps. **Built 2026-10-22
   (decision 176)**, on clones: all 28 dictionaries rewritten validate, every seeded check comes out as its
   description says. The measurements of §5 are in the decision. Left: rewriting the real dictionaries.
2. **Filled in by plans 038 and 039.** Whoever opens a reader writes its columns' overlay and its adapter's staging
   dictionary, as the rule "tables, not views" is applied (AGENTS.md). Both plans say so in their §8.
3. **The curated layer** (after plans 038 and 039): §3.3.

## 5. What is measured before each phase

- Phase 1: which of the 21 failing raw files pass after the S12 fix alone; how many columns are empty (S07), and
  whether they are empty in Oracle or only in the first 10,000 rows; each seeded `assert` on the current dump, so the
  check is known to work before it guards a new one.
- Phase 2: per reader, its columns' units, formats and codes against the data, by vessel and period where the source
  is known to change (afli's depths), not only by Oracle's word.
- Phase 3: per curated column, the sources and periods that feed it, to see where one column mixes precisions.

Assumed, not measured: that the data-dict tool's `validate-data` runs on files of our size in reasonable time (it
has been run only on scratch files); that an overlay of a few hundred columns stays cheaper to keep than the
corrections it would have caught.

## 6. Asks

a. Where the overlay lives. **Answered 2026-10-22:** `dump/oracle/meta/<schema>.yml`, beside the dumper that merges
   it (the maintainer: "overlay in dump/oracle/meta"). It holds no data and no persons.
b. Precision where one curated column mixes sources (the logbook's positions): a per-row column, as `basis` is, or
   stated per source and period in the dictionary only.
c. The labels' language: English labels with Oracle's Icelandic kept beside them (proposed).
d. Whether a failing `assert` blocks a dump's adoption, or is reported and explained after.
e. Which curated tables need a dictionary: all 105, or all but the checks, whose columns are the check's own.
f. A column with no values in a dump: drop its `examples` requirement by typing it from Oracle's declaration only, or
   mark it with a `todo` until it has values. **Implemented in the reversible form, to be confirmed (decision 176):**
   the column is named, not typed, with Oracle's declared type in `details` and a `todo`, until a dump holds a value.

## 7. The TODO items this plan touches

| Item | How |
|---|---|
| 51 (`docs/data-dict.yaml` against the spec) | phase 3 fixes it; until then it stays open |
| 110 (the dumper's open ends) | phase 1 adds the S12 fix and the checks at adoption |
| 111 (`docs/output-schema.md`'s column tables) | phase 3 makes `docs/data-dict.yaml` the one description of the columns |
| 113, 114 (afli's end depth, gutted catch) | their units and labels become overlay entries with an `assert` |
| 119, 120 (lods' units, readers on views) | lods' tonnes and the switched readers are seeded in phase 1 |
| plans 037, 038, 039 | 037's "the layer that states its unit" reads the overlay; 038 and 039 fill it (phase 2) |
