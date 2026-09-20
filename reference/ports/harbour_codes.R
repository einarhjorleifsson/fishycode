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
  read_sf(fd_raw("ports", "ports_iceland_faroe.gpkg")) |> st_drop_geometry() |>
  filter(!str_sub(pid, 1, 2) == "FO") |>
  select(hid, port, pid) |>
  full_join(harbours) |>
  mutate(port =
           case_when(is.na(port) ~ hafnarnumer_heiti,
                     .default = port)) |>
  arrange(hid) |>
  select(-hafnarnumer_heiti)
ports |> write_parquet(fd_curated("reference", "port.parquet"))
