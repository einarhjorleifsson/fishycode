# port_code.R — the landing system's port codes (hid) as it lists them (harbours.R until plan 014).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/oracle/agf/aflagrunnur.parquet      every hid a landing uses
#         raw/oracle/ask/londunarstadir.parquet   the landing system's port list: each hid's name and new code (id)
# Output: curated/reference/port_code.parquet   one row per code: hid, hid_new (hafnarnumer_id), port (name)
#
# The raw list only; reference/ports/harbour_codes.R joins it to the standard harbour key. The tables, not the view
# aflagrunnur_v, whose party and vessel joins drop code 168 (decision 175).

read_parquet(fd_raw("oracle", "agf", "aflagrunnur.parquet"), col_select = "hafnarnumer") |>
  distinct() |>
  left_join(read_parquet(fd_raw("oracle", "ask", "londunarstadir.parquet")), by = "hafnarnumer") |>
  select(hid = hafnarnumer,
         hid_new = id,
         port = heiti) |>
  arrange(hid) |>
  write_curated(fd_curated("reference", "port_code.parquet"),
                inputs = c(fd_raw("oracle", "agf", "aflagrunnur.parquet"), fd_raw("oracle", "ask", "londunarstadir.parquet")))
