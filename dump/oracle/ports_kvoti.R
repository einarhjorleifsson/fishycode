# kvoti.stadur — the Icelandic harbour CODE authority (stad_nr -> name).
# Output: raw/ports/ports_kvoti.parquet
#
# This is the code authority. Harbour GEOMETRY comes from a separate chain
# (reference/ports/ports_all.R), and a code must resolve to a name whether or
# not a polygon exists for it (TODO 12b).
library(sf)
library(tidyverse)
library(nanoparquet)
library(mar)
con <- connect_mar()

ports_kvoti <-
  tbl_mar(con, "kvoti.stadur") |>
  collect() |>
  select(stad_nr, port = heiti) |>
  arrange(stad_nr) |>
  filter(stad_nr > 0) |>
  mutate(port = str_trim(port),
         port = case_when(port == "Vík í Mýrdal" ~ "Vík",
                          port == "Miðsandur, Hvalfirði" ~ "Miðsandur",
                          port == "Borgarfjörður Eystri" ~ "Borgarfjörður",
                          port == "Núpsskóli, Dýrafirði" ~ "Alviðruvör",
                          port == "Núpskatla" ~ "Núpskatla",
                          stad_nr == 102 ~ "Litli Árskógssandur",
                          #pid == 103 ~ "Árskógsströnd",
                          #port == "XXX Arnarstapi ekki nota" ~ NA,
                          port == "Svalbarðsströnd" ~ "Svalbarðseyri",
                          #port == "Reyðarfjörður" ~ "Búðareyri",
                          port == "Skútustaðahreppur" ~ "Mývatn",
                          port == "Flatey á Breiðafirði" ~ "Flatey",
                          .default = port)) |>
  filter(!stad_nr %in% c(150, 153, 155:212, 300:999)) |>
  add_row(stad_nr = 140, port = "Grundartangi")
# Read by reference/ports/harbour_codes.R, and by the frozen bootstrap
# reference/ports/bootstrap_iceland_faroe.R.
#
# The comment that stood here until 2026-09-22 said this wrote to the repo root.
# It did once - and the write was fixed to fd_raw() in the same commit that
# carried the comment across from kaenugardr (b7aa258), so the note described
# behaviour that no longer existed and contradicted the Output line above.
ports_kvoti |> write_parquet(fd_raw("ports", "ports_kvoti.parquet"))