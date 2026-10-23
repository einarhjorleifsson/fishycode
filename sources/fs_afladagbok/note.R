# fs_afladagbok's free-text notes, as entered (decision 213; decision 210: the text stays in staging)
# Side: preprocessing (fs_afladagbok). See plan 014.
# Input:  raw/oracle/fs_afladagbok/{ws_veidi,ws_medafli}.parquet
# Output: staging/fs_afladagbok/note.parquet  .sid, schema, note_field, note: one row per station and field with a note
#
# The station's note (ws_veidi.athugasemd_txt) and the mammal and bird bycatch note (ws_medafli.ath, one per animal
# record, so a station may hold several). A note may name a person: never printed (decision 159; MFRI's data policy).
# curate/station_note.R classifies them.

library(tidyverse)
library(duckdbfs)

SCHEMA <- "fs_afladagbok"

note <- bind_rows(
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_veidi.parquet")) |>
    filter(!is.na(athugasemd_txt)) |>
    select(.sid = id, note = athugasemd_txt) |> collect() |>
    mutate(note_field = "ws_veidi.athugasemd_txt"),
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_medafli.parquet")) |>
    filter(!is.na(ath)) |>
    select(.sid = veidi_id, note = ath) |> collect() |>
    mutate(note_field = "ws_medafli.ath")) |>
  mutate(.sid = as.numeric(.sid), schema = SCHEMA) |>
  select(.sid, schema, note_field, note) |>
  arrange(.sid, note_field)

message(sprintf("fs_afladagbok notes: %s (%s)", format(nrow(note), big.mark = ","),
                paste(names(table(note$note_field)), table(note$note_field), collapse = ", ")))
note |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "note.parquet"))
