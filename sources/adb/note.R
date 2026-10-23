# adb's free-text notes, as entered (decision 213; decision 210: the text stays in staging)
# Side: preprocessing (adb). See plan 014.
# Input:  raw/oracle/adb/{fishing_station,catch}.parquet
# Output: staging/adb/note.parquet  .sid, schema, note_field, note: one row per station and field with a note
#
# Every adb note, whatever its date: before 2025-11-19 adb is fs_afladagbok's copy note for note, and the merge keeps
# fs's station there (decision 160), so curate/station_note.R flags which notes the logbook keeps. The catch row's note
# (catch.note) is put on its station. A note may name a person: never printed (decision 159; MFRI's data policy).

library(tidyverse)
library(duckdbfs)

SCHEMA <- "adb"

note <- bind_rows(
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "fishing_station.parquet")) |>
    filter(!is.na(note)) |>
    select(.sid = fishing_station_id, note) |> collect() |>
    mutate(note_field = "fishing_station.note"),
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "catch.parquet")) |>
    filter(!is.na(note)) |>
    select(.sid = fishing_station_id, note) |> collect() |>
    mutate(note_field = "catch.note")) |>
  mutate(.sid = as.numeric(.sid), schema = SCHEMA) |>
  select(.sid, schema, note_field, note) |>
  arrange(.sid, note_field)

message(sprintf("adb notes: %s (%s)", format(nrow(note), big.mark = ","),
                paste(names(table(note$note_field)), table(note$note_field), collapse = ", ")))
note |> duckdbfs::write_dataset(fd_staging("adb", "note.parquet"))
