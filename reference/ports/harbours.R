read_parquet(fd_raw("landings", "agf", "aflagrunnur_v.parquet")) |>
  select(starts_with("hafnar")) |>
  distinct() |>
  arrange(hafnarnumer_id) |>
  select(hid = hafnarnumer,
         hid_new = hafnarnumer_id,
         harbour = hafnarnumer_heiti) |>
  arrange(hid) |>
  write_parquet(fd_curated("reference", "harbour.parquet"))
