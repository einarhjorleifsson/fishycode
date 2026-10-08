# harbours.R — the landing-harbour codes as the landings system lists them.
#
# Input:  raw/landings/agf/aflagrunnur_v.parquet
# Output: curated/reference/harbour.parquet   one row per code: hid, hid_new (hafnarnumer_id), harbour (name)
#
# The raw list only; reference/ports/harbour_codes.R joins it to the standard harbour key.

read_parquet(fd_raw("landings", "agf", "aflagrunnur_v.parquet")) |>
  select(starts_with("hafnar")) |>
  distinct() |>
  arrange(hafnarnumer_id) |>
  select(hid = hafnarnumer,
         hid_new = hafnarnumer_id,
         harbour = hafnarnumer_heiti) |>
  arrange(hid) |>
  write_curated(fd_curated("reference", "harbour.parquet"),
                inputs = fd_raw("landings", "agf", "aflagrunnur_v.parquet"))
