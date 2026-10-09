# port_code.R — the landing system's port codes (hid) as it lists them (harbours.R until plan 014).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/landings/agf/aflagrunnur_v.parquet
# Output: curated/reference/port_code.parquet   one row per code: hid, hid_new (hafnarnumer_id), port (name)
#
# The raw list only; reference/ports/harbour_codes.R joins it to the standard harbour key.

read_parquet(fd_raw("landings", "agf", "aflagrunnur_v.parquet")) |>
  select(starts_with("hafnar")) |>
  distinct() |>
  arrange(hafnarnumer_id) |>
  select(hid = hafnarnumer,
         hid_new = hafnarnumer_id,
         port = hafnarnumer_heiti) |>
  arrange(hid) |>
  write_curated(fd_curated("reference", "port_code.parquet"),
                inputs = fd_raw("landings", "agf", "aflagrunnur_v.parquet"))
