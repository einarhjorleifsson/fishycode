# afli's free-text notes, as entered (decision 213; decision 210: the text stays in staging)
# Side: preprocessing (afli). See plan 014.
# Input:  raw/oracle/{afli,fs_afli}/{stofn,hringn,medafli,spendyr}.parquet, raw/oracle/afli/grasl_sokn.parquet
# Output: staging/afli/note.parquet  .sid, schema, copy, vid, date, note_field, note: one row per record and field
#
# The copies are the adapter's (sources/afli/convert.R): afli's whole, and fs_afli's for the paper stations afli
# lacks. The notes: the station's (stofn.aths_texti, the 40,967 monthly summary stations' system stamp among them,
# which convert.R writes to aggregate.parquet), the purse seine skipper's (hringn.athskipst), and the mammal and bird
# bycatch notes (medafli.ath, spendyr.aths). The lumpsucker effort table (grasl_sokn) has no station: its notes carry
# the vessel and day, and an empty .sid. The loaded layer's rafr_ tables are left out: their notes moved to these
# tables, and the sent layer's (staging/afli_sent/note.parquet) holds what the apps sent.
# A note may name a person: never printed (decision 159; MFRI's data policy). curate/station_note.R classifies them.

library(tidyverse)
library(duckdbfs)

SCHEMA <- "afli"

stofn_afli_sid <- duckdbfs::open_dataset(fd_raw("oracle", "afli", "stofn.parquet")) |> distinct(visir) |> collect() |> pull(visir)
FS_SID <- duckdbfs::open_dataset(fd_raw("oracle", "fs_afli", "stofn.parquet")) |>
  filter(visir > 0) |> distinct(visir) |> collect() |> pull(visir) |> setdiff(stofn_afli_sid)

# A note field of a table keyed on visir, from both copies
read_note <- function(table, column) {
  bind_rows(
    duckdbfs::open_dataset(fd_raw("oracle", "afli", paste0(table, ".parquet"))) |>
      filter(!is.na(.data[[column]])) |> select(visir, note = all_of(column)) |> collect() |>
      mutate(copy = "afli"),
    duckdbfs::open_dataset(fd_raw("oracle", "fs_afli", paste0(table, ".parquet"))) |>
      filter(!is.na(.data[[column]]), visir %in% FS_SID) |> select(visir, note = all_of(column)) |> collect() |>
      mutate(copy = "fs_afli")) |>
    mutate(note_field = paste0(table, ".", column))
}

note <- bind_rows(
  read_note("stofn", "aths_texti"),
  read_note("hringn", "athskipst"),
  read_note("medafli", "ath"),
  read_note("spendyr", "aths")) |>
  rename(.sid = visir) |>
  mutate(.sid = as.numeric(.sid), vid = NA_integer_, date = as.Date(NA))
grasl <- duckdbfs::open_dataset(fd_raw("oracle", "afli", "grasl_sokn.parquet")) |>
  filter(!is.na(athugasemd)) |>
  select(vid = skipnr, date = vedags, note = athugasemd) |> collect() |>
  mutate(.sid = NA_real_, vid = as.integer(vid), date = as_date(date), copy = "afli",
         note_field = "grasl_sokn.athugasemd")

note <- bind_rows(note, grasl) |>
  mutate(schema = SCHEMA) |>
  select(.sid, schema, copy, vid, date, note_field, note) |>
  arrange(note_field, .sid, date)

message(sprintf("afli notes: %s (%s)", format(nrow(note), big.mark = ","),
                paste(names(table(note$note_field)), table(note$note_field), collapse = ", ")))
note |> duckdbfs::write_dataset(fd_staging("afli", "note.parquet"))
