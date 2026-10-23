# 213 — The logbooks' free-text notes staged per source, and classified in curated/logbook/station_note

*2026-10-23. The maintainer's go ("should we at least not complete that"), with the classes in `curated/logbook` and a
build by name; written and built by Claude (AI), not checked by a person. It carries out decision 210's item 6 (plan
020 question 6), with the rules of the notes study of the same day (plan 020 §6;
`$FISHYDATA/archive/2026-10-logbook-notes/README.md`).*

## Chosen

- **The notes in staging, one table per source, as entered** (the text stays in staging, decision 210):
  `staging/fs_afladagbok/note.parquet` (`ws_veidi.athugasemd_txt`, `ws_medafli.ath`), `staging/adb/note.parquet`
  (`fishing_station.note`, `catch.note`), `staging/afli/note.parquet` (`stofn.aths_texti`, `hringn.athskipst`,
  `medafli.ath`, `spendyr.aths` from afli's two copies as its adapter reads them, and `grasl_sokn.athugasemd`, which has
  no station and carries the vessel and day), and `staging/afli_sent/note.parquet` (the apps' `STOFN/ATHS_TEXTI` and
  `HRINGNOT/ATHS` on the staged record). Keyed on (`.sid`, `schema`) and the field. Each is its own target, so no
  earlier target changed but afli_sent, which nothing reads.
- **The rules in `R/logbook_notes.R`**, moved from the study unchanged: `classify_notes()` gives the same class, tags
  and species as the study on all 128,574 notes. 73 rules in 18 classes, in priority order (`note_classes()`).
- **The classes in `curated/logbook/station_note.parquet`** (`curate/station_note.R`, target `station_note`): station,
  schema, field, class, tags, species named, `in_logbook` (the merge kept that station: adb's notes before 2025-11-19
  are fs's copies, decision 160) and basis `derived`. No text. A sent note that afli.stofn holds unchanged is left out.
- **afli_sent reads two free-text elements**, into `note.parquet` only; the kennitala, the name and the software key
  stay unread, and no printed line holds a note (decision 159).

## Not here

- The transfer, released, sample and gear-lost tables of plan 020 §6, and moving any catch: asks a-d of the study,
  plans 041 and 042.
- afli's coded remark (`stofn.athugas`, 6.9 M stations) as a structured column beside the notes' classes.
- The fishing-ground gazetteer (TODO 73, parked for a person's read).
