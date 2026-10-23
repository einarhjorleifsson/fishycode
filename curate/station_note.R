# station_note.R — every logbook note classified: its class, tags and the species it names, without its text.
# Side: preprocessing (logbook). See plan 014 and decision 213.
#
# Input:  staging/{fs_afladagbok,adb,afli,afli_sent}/note.parquet (the notes as entered),
#         curated/logbook/station.parquet (the stations the merge keeps)
# Output: curated/logbook/station_note.parquet
#         .sid schema note_field vid date note_class note_tags note_species in_logbook basis
#
# One row per station, schema and note field (the lumpsucker effort notes have no station: vid and date instead).
# The text stays in staging (decision 210); a note may name a person (decision 159). The rules are R/logbook_notes.R.
# in_logbook: the merge kept that station (curate/logbook.R), so a join on (.sid, schema) to curated/logbook/station
# finds it; adb's notes before 2025-11-19 are fs_afladagbok's copies (decision 160) and are FALSE. A note the app sent
# that afli.stofn holds unchanged (folded alike) is the same note and is left out; one Oracle lost or changed is kept,
# with note_field "STOFN/ATHS_TEXTI" or "HRINGNOT/ATHS". basis is "derived": classes read from free text, never
# recorded. The classes and their meaning: note_classes().

library(tidyverse)
library(duckdbfs)

rd <- function(...) duckdbfs::open_dataset(fd_staging(...)) |> collect()
fs   <- rd("fs_afladagbok", "note.parquet") |> mutate(vid = NA_integer_, date = as.Date(NA))
adb  <- rd("adb", "note.parquet") |> mutate(vid = NA_integer_, date = as.Date(NA))
afli <- rd("afli", "note.parquet") |> select(-copy)
sent <- rd("afli_sent", "note.parquet") |> select(-.xid, -layer) |> mutate(vid = NA_integer_, date = as.Date(NA))

# The sent note that afli.stofn (or hringn) already holds for the station is the same note
held <- afli |> filter(note_field %in% c("stofn.aths_texti", "hringn.athskipst")) |>
  transmute(.sid, key = if_else(note_field == "stofn.aths_texti", "STOFN/ATHS_TEXTI", "HRINGNOT/ATHS"),
            held = note_fold(note))
sent <- sent |> mutate(key = note_field, f = note_fold(note)) |>
  left_join(held, by = c(".sid", "key"), relationship = "many-to-many") |>
  group_by(.sid, note_field, note) |> summarise(same = any(f == held, na.rm = TRUE), .groups = "drop") |>
  filter(!same) |> select(-same) |> mutate(schema = "afli", vid = NA_integer_, date = as.Date(NA))

note <- bind_rows(fs, adb, afli, sent)
bycatch <- note$note_field %in% c("ws_medafli.ath", "medafli.ath", "spendyr.aths")
note <- bind_cols(note, classify_notes(note$note, bycatch_table = bycatch))

kept <- duckdbfs::open_dataset(fd_curated("logbook", "station.parquet")) |> select(.sid, schema) |> collect() |>
  mutate(in_logbook = TRUE)
out <- note |>
  left_join(kept, by = c(".sid", "schema"), relationship = "many-to-one") |>
  mutate(in_logbook = coalesce(in_logbook, FALSE), basis = "derived") |>
  select(.sid, schema, note_field, vid, date, note_class, note_tags, note_species, in_logbook, basis) |>
  arrange(schema, .sid, note_field)

write_curated(out, fd_curated("logbook", "station_note.parquet"),
              inputs = c(fd_staging("fs_afladagbok", "note.parquet"), fd_staging("adb", "note.parquet"),
                         fd_staging("afli", "note.parquet"), fd_staging("afli_sent", "note.parquet"),
                         fd_curated("logbook", "station.parquet")))
message(sprintf("station_note: %s notes, %s on stations the logbook keeps", format(nrow(out), big.mark = ","),
                format(sum(out$in_logbook), big.mark = ",")))
print(out |> count(schema, note_field, in_logbook))
print(out |> filter(in_logbook) |> count(note_class, sort = TRUE))
