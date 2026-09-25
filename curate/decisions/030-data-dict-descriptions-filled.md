# Every table and column in `docs/data-dict.yaml` given a grounded description

*Decided and implemented 2026-09-25.*

## What this is

Decision 029 introduced `docs/data-dict.yaml` as a structural draft — every
column's name and type checked against the real data, every `description`
left as a `todo` because writing what a column *means* is domain work, not
something to draft mechanically.

This pass fills that in: all 26 tables and 298 columns now carry a
`description`, each traced to a script, a `docs/*.md` page, or a
`curate/decisions/*`/`curate/plans/*` record — never inferred from the
column name alone. Two columns were checked and found genuinely
ungrounded (`reference_port.hafnarnumer_id`,
`reference_harbour.hid_new`'s exact relationship to `hid`) and say so in
the dictionary rather than guessing.

## How

1. Read directly: `docs/output-schema.md`, `docs/grammar.qmd`,
   `docs/landings-match.qmd`, `curate/ais_trip.R`, `curate/ais_ping_union.R`,
   `curate/ais_ping_tag.R`, `curate/logbook_sensor_gps.R`,
   `curate/link_lid_map.R`, `curate/link_trip_voyage.R`,
   `curate/catch_by_species_trip.R`, `sources/aflagrunnur/convert.R` — 13
   tables (`ais_trip`, `ais_ping`, `landing_catch`, `landing_landings`,
   `link_trip_voyage`, `logbook_catch`, `logbook_catch_by_species_trip`,
   `logbook_fishing_sample`, `logbook_lid_map`, `logbook_sensor_gps`,
   `logbook_station`, `logbook_trip`).
2. Three parallel research passes (one each for `vessel/*`, `reference/*`,
   `check/*`) read the remaining producing scripts
   (`reference/vessels/{registry,identity,ais_key,mmsi}.R`,
   `reference/geo/h3_index.R`, `reference/dictionary.R`,
   `reference/gear/mapping.R`, `reference/ports/*.R`,
   `curate/checks/*.R`) and the decisions/plans that explain them
   (007, 010, 012, 013, 015, plans 003 and 005), citing file:line for every
   column.
3. Applied programmatically: an R script inserts each `description:` at the
   right point in the existing YAML text (splicing lines, not a full
   `yaml::as.yaml()` round-trip, which would have reformatted the
   hand-written `relationships`/`glossary` comments and lost them) and drops
   the now-resolved `- Add a \`description\`.` bullet from that column's
   `todo`, removing the `todo:` block entirely where that was its only item.

## What went wrong building the applier, and the fix

- First attempt spliced a replacement block into a fixed-length subset of
  the line vector (`block[cstart:cend] <- list(cblock)`), which doesn't
  work in R for a replacement of different length — it blew the 2,967-line
  file up to 4.4 million lines silently. Fixed by writing a real `splice()`
  helper (`c(before, new_block, after)`) and testing on a copy before
  touching the real file, per `AGENTS.md`'s "measure before claiming".
- `data-dict validate-spec` panicked (Rust byte-index-not-a-char-boundary)
  on a description containing an em dash, apparently because a warning's
  span calculation is byte- not char-based and this description happened to
  shift one across a warning boundary. Worked around by writing the new
  descriptions in plain ASCII punctuation; the pre-existing em dashes
  elsewhere in the file didn't trigger it, so this is narrow and specific,
  not "no non-ASCII text anywhere" — worth reporting upstream to
  `~/garbage/data-dict` at some point, not done here.
- The drafted YAML quotes column names that collide with YAML 1.1 boolean
  literals (`vessel_ais_key`'s `no` column became `- name: "no"`); the
  applier's name-matching regex didn't strip the quotes and silently missed
  it. Caught by counting: 298 columns, only 297 descriptions applied.

## Not done

- `reference_gear.gid`'s 59-vs-37 duplicate split and `reference_port.pid`'s
  duplicates/missing values (decision 029) are described honestly but not
  investigated further.
- No `validate-data` pass.
- `fishyweb/data-sources/data-dictionary.qmd` regenerated from this file and
  re-rendered clean, same as decision 029.
