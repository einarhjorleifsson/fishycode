# harbour_codes.R — the crosswalk from Iceland's landing-harbour code (hid) to the standard harbour key (pid).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/oracle/agf/aflagrunnur.parquet      every hid a landing uses
#         raw/oracle/ask/londunarstadir.parquet   the landing system's port list: each hid's name and new code (id)
#         raw/oracle/kvoti/stadur.parquet         Fiskistofa's place list, the code authority
#         staging/ports/ports_all.gpkg            the pid of each Iceland polygon (source "einar"), by hid
# Output: curated/reference/port.parquet           one row per hid: hid, port, pid, hafnarnumer_id
#
# Every code in any of the three gets a row and a name; only a code with a harbour polygon
# gets a pid (decision 007: not every landing code is a harbour).

library(sf)
library(nanoparquet)
library(tidyverse)
# The tables, not the view aflagrunnur_v (decision 175): its party and vessel joins drop landings, and with them code
# 168 (Bretland, one landing in 2022). Its port names and new codes are londunarstadir's, which names every code.
harbours <-
  read_parquet(fd_raw("oracle", "agf", "aflagrunnur.parquet"), col_select = "hafnarnumer") |>
  distinct() |>
  left_join(read_parquet(fd_raw("oracle", "ask", "londunarstadir.parquet")) |>
              select(hafnarnumer, hafnarnumer_id = id, hafnarnumer_heiti = heiti),
            by = "hafnarnumer") |>
  rename(hid = hafnarnumer) |>
  arrange(hid)
# kvoti.stadur with the names and the selection the old dump (dump/oracle/ports_kvoti.R) made until plan 018: the
# dump is now Oracle's table as it is. Codes 155-212 and 300-999 are places abroad and districts, not harbours; a
# landing code among them still takes its name from stadur below.
stadur <- read_parquet(fd_raw("oracle", "kvoti", "stadur.parquet"))
ports_kvoti <-
  stadur |>
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
                          port == "Svalbarðsströnd" ~ "Svalbarðseyri",
                          port == "Skútustaðahreppur" ~ "Mývatn",
                          port == "Flatey á Breiðafirði" ~ "Flatey",
                          .default = port)) |>
  filter(!stad_nr %in% c(150, 153, 155:212, 300:999)) |>
  add_row(stad_nr = 140L, port = "Grundartangi")
ports <-
  # Superseded 2026-09-21. This used to warn against reading ports_all.gpkg,
  # back when it was a hand copy of a kaenugardr artifact carrying that repo's
  # own pid codes. It is now produced in this repo by reference/ports/ports_all.R
  # and is exactly the right source, because it is the only place the canonical
  # pid exists. Filtering to source == "einar" keeps this a crosswalk rather
  # than a global port list.
  # pid MUST come from the consolidated table, not from the Iceland file's own
  # pid column. ports_all.R reassigns pid globally (build_pid), so the bootstrap
  # codes are a stale namespace: Hellnar is IS-HLL in the Iceland file and
  # IS-HEN in the port database. Reading the former left 59 of 129 codes with a
  # pid that exists nowhere, silently breaking the hid -> pid -> geometry join
  # that the logbook and landings data depend on.
  read_sf(fd_staging("ports", "ports_all.gpkg")) |> st_drop_geometry() |>
  filter(source == "einar", !is.na(hid)) |>
  mutate(hid = as.integer(hid)) |>
  filter(!str_sub(pid, 1, 2) == "FO") |>
  select(hid, port, pid) |>
  distinct(hid, .keep_all = TRUE) |>
  full_join(harbours) |>
  # kvoti.stadur is the code authority, kaenugardr only supplies geometry. A
  # code must resolve to a NAME whether or not a polygon exists for it, or a
  # harbour that is correctly absent from the geometry becomes an unresolvable
  # code: removing Hellissandur (41) and Hnífsdalur (71) as non-harbours took
  # port.parquet from 143 rows to 141 and stranded 5,235 logbook trips.
  full_join(ports_kvoti |> rename(hid = stad_nr, port_kvoti = port), by = "hid") |>
  left_join(stadur |> select(hid = stad_nr, port_stadur = heiti) |> mutate(port_stadur = str_trim(port_stadur)), by = "hid") |>
  mutate(port = coalesce(port, hafnarnumer_heiti, port_kvoti, port_stadur)) |>
  arrange(hid) |>
  select(-hafnarnumer_heiti, -port_kvoti, -port_stadur)
ports |> write_curated(
  fd_curated("reference", "port.parquet"),
  inputs = c(fd_raw("oracle", "agf", "aflagrunnur.parquet"), fd_raw("oracle", "ask", "londunarstadir.parquet"),
             fd_raw("oracle", "kvoti", "stadur.parquet"), fd_staging("ports", "ports_all.gpkg")))
