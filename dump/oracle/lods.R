# lods — the LODS landings, as they are.
#
# Input:  Oracle kvoti.lods_oslaegt, kvoti.lods_londun
# Output: raw/landings/kvoti/lods_oslaegt.parquet (read by sources/lods/convert.R), lods_londun.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/lods.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_table(con, "kvoti.lods_oslaegt", fd_raw("landings", "kvoti", "lods_oslaegt.parquet"))
dump_oracle_table(con, "kvoti.lods_londun",  fd_raw("landings", "kvoti", "lods_londun.parquet"))
