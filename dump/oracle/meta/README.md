# dump/oracle/meta — what each column means, kept by hand, merged into the dump's dictionary

Plan 040, phase 1. One file per dumped Oracle schema, `<schema>.yml`, named as its dump folder
(`raw/oracle/<schema>/`, so `ops_einarhj.yml`). It holds what Oracle does not say in a form a machine can read: a
column's measure and unit, a position's stored form, sign and precision, what a code stands for, the evidence for each,
and an `assert` for each claim the data can test.

The dumper writes `_data-dict.yaml` beside every schema it dumps (`dump_oracle_schema()`, `R/dump_oracle.R`), with
Oracle's comments as descriptions and ranges and examples from the files. It then lays this file over it, and
`rewrite_data_dict()` does the same on a dump already made. `check_data_dict()` validates the merged file and runs its
asserts when a dump is adopted (`dump/oracle/README.md`, section 11).

## The format

A file is a data-dict document (`data-dict spec`; version 0.1.0), holding only what this layer adds. The merged file
must validate, and the spec allows no field of our own (Q-1-18): everything below is a data-dict property.

```yaml
$version: 0.1.0
name: kvoti
tables:
  - name: lods_slaegt                 # the table's file name, lower case, as in the dump
    details: |                        # what this layer says of the table, with its evidence
      ...
    definitions:                      # a value in standard units, where the unit depends on another column
      - name: magn_oslaegt_kg
        expr: magn_oslaegt * CASE WHEN fteg IN (30, 31, 34) THEN 1000 ELSE 1 END
    constraints:                      # asserts over several columns
      - assert: fteg NOT IN (30, 31, 34) OR magn = 0 OR thorskigildi = 0 OR thorskigildi / magn >= 10
        description: the claim, and what the dump it was tested on gave
    columns:
      - name: magn_oslaegt
        label: Ungutted weight
        type: number(quantity)
        units: kg; t where fteg is 30, 31 or 34
        details: |
          Evidence: ...
      - name: gerd
        type: enum
        values:
          'K': counted against quota
          'A': export surcharge taken off again (negative)
relationships:                        # joins between this schema's tables, to a code table
  - join: lods_slaegt.veidisvaedi = veidisv.veidisvaedi
    cardinality: many-to-one
```

Per column, what applies of:

- **`type` with its measure.** `number(id)` for keys and numeric codes, `number(ordinal)` for years and sequence
  numbers, `number(quantity)` for a measure, with **`units`** (free text, only on `number(quantity)`: S08). A unit
  that depends on another column is said in `units` and given as a table `definition` holding the value in standard
  units (`<column>_kg`, `<column>_m`, `<column>_dd` for decimal degrees). A definition is parsed and type-checked,
  never evaluated, and its name may not be a column's.
- **Codes.** A short set as `type: enum` with `values` a map from code to an English `label`. Oracle's Icelandic
  comment stays the column's `description`, written by the dump; the code table's own Icelandic text goes in
  `details`. A code whose meaning is not established gets a label saying so and a `todo`. An enum is a test: a value
  outside the map fails the data check (D04). A long or changing list (species, gear, ports) stays `number(id)`, with
  a `relationship` to its code table.
- **Positions.** The stored form and sign in `details` (decimal degrees, ddmm.mm, a ddmmss integer; west positive or
  negative; datum where stated), the precision (whole minutes, about 1.8 km of latitude; hundredths of a minute, about
  18 m; seconds, about 30 m), per period where it changes, and the decoding as a `definition`.
- **`time_zone: UTC`** on a datetime known to be UTC (Iceland's clock is UTC since 1968-04-07; decision 111 for the
  dumps). Where a midnight means "no time recorded", `details` says so.
- **`label`** where the name is cryptic, in English.
- **Evidence** in `details`, a line starting `Evidence:`: Oracle's comment, a view or trigger (`raw/oracle/<schema>/_code/`),
  a data test with its date and counts, a decision or correction.
- **`constraints`** with an `assert` for each claim the data can test, in data-dict's expression language: one table
  at a time, row-level or aggregate. Each has a `description` with the claim and its result on the dump it was tested
  on. A known defect is bounded in the assert (by period, code or source) so that the assert passes on the dump it was
  tested on, and a failing assert at adoption is news; where it cannot be bounded within the table, the description
  gives the count expected to fail.
- **`todo`** for what is not established. It is reported as a warning (S31), never an error.

## What the merge does

- The overlay wins on every property it sets. The dump fills `range`, `examples` and `description` (Oracle's
  comment); a table's `details` is the overlay's, then the dump's note on the file, if any.
- The representative values follow the merged type: an `enum` keeps its `values` and drops the dump's examples and
  range; a datetime with a `time_zone` gets its range zoneless (`2003-06-18T17:56:20`), one without gets it with `Z`.
- A column with no value in the dump is kept by name only, with Oracle's comment, its declared type in `details` and a
  `todo` (plan 040, ask f); the next dump with values types it again. An `enum` keeps its values, and an ordered type
  an open range (`[-.inf, .inf]`).
- A table or column the overlay names that the dump does not hold is left out and listed in the dictionary's top-level
  `todo`, so `validate-spec` reports it.
- Overlays are read as data-dict reads YAML (1.2): `Y`, `N`, `on`, `off`, `yes`, `no` are strings, only `true` and
  `false` booleans. Quote codes anyway: `'N': northern area`.

## Rules

- Only columns fishycode reads, or that decide a sum. Phase 2 of plan 040 adds a reader's columns when plans 038 and 039
  open it.
- No data: no examples, no values from a persons' table (AGENTS.md, Rules). Codes and their labels come from code
  tables and comments.
- Not `range`, `examples` or `description`: the dump writes them. Set one only with the reason in `details`.
- Every claim with its evidence, and an `assert` where the data can test it.
