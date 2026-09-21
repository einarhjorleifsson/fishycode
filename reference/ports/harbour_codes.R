library(sf)
library(nanoparquet)
library(tidyverse)
harbours <-
  read_parquet(fd_raw("landings", "agf", "aflagrunnur_v.parquet")) |>
  select(starts_with("hafnar")) |>
  distinct() |>
  rename(hid = hafnarnumer) |>
  arrange(hid)
ports <-
  # kaenugardr publishes two port artifacts and they are not interchangeable:
  #   ports_all.gpkg           6,019 global ports - used by shapes.R for the AIS
  #                            harbour spatial join
  #   ports_iceland_faroe.gpkg 159 Iceland+Faroe ports, hid typed numeric - the
  #                            one this crosswalk needs
  # Pointing this at ports_all.gpkg yields 6,003 rows of global ports instead of
  # the 143-row Icelandic harbour crosswalk the converts expect.
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
  full_join(read_parquet(fd_raw("ports", "ports_kvoti.parquet")) |>
              rename(hid = stad_nr, port_kvoti = port),
            by = "hid") |>
  mutate(port = coalesce(port, hafnarnumer_heiti, port_kvoti)) |>
  arrange(hid) |>
  select(-hafnarnumer_heiti, -port_kvoti)
ports |> write_curated(
  fd_curated("reference", "port.parquet"),
  inputs = c(fd_raw("landings", "agf", "aflagrunnur_v.parquet"),
             fd_staging("ports", "ports_all.gpkg")))
