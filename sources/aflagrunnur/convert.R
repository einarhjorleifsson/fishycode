library(nanoparquet)
library(tidyverse)
ports <- read_parquet(fd_curated("reference", "port.parquet"))
aflagrunnur <-
  read_parquet(fd_raw("landings", "agf", "aflagrunnur.parquet")) |>
  select(.lid = londun_id, vid = skip_numer, date = londun_hefst,
         hid = hafnarnumer, gid = veidarfaeri, sid = fisktegund,
         stid = veidistofn,
         catch = magn_oslaegt) |>
  mutate(date = as_date(date)) |>
  group_by(.lid, vid, date, hid, gid, sid, stid) |>
  summarise(catch = sum(catch, na.rm = TRUE),
            .groups = "drop") |>
  group_by(.lid, date, vid, hid) |>
  mutate(.tid = min(.lid),
         .before = ".lid") |>
  ungroup()
landings <-
  aflagrunnur |>
  distinct(.tid, vid, date, hid) |>
  # hid is Fiskistofa's hafnarnumer; pid is the standard port key, so landings
  # join to the same port identity as the logbooks and the AIS trail.
  left_join(ports |> select(hid, höfn = port, pid), by = "hid")
catch <-
  aflagrunnur |>
  select(.tid, .lid, gid, sid, stid, catch)
landings |> duckdbfs::write_dataset(fd_curated("landing", "landings.parquet"))
catch    |> duckdbfs::write_dataset(fd_curated("landing", "catch.parquet"))
