# gear — the gear code lists, as they are.
#
# Input:  Oracle orri.veidarfaeri, orri.veidarfaeri_ny, gear.veidarfaeri_v, gear.fishing_gear,
#         gear.gear_category, gear.isscfg
# Output: raw/gear/<schema>_<table>.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/gear.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
# snt, snn, sbt, sbn: the row audit stamps, left out since the first version of this dump
dump_oracle_table(con, "orri.veidarfaeri", fd_raw("gear", "orri_veidarfaeri.parquet"),
                  drop = c("snt", "snn", "sbt", "sbn"))
dump_oracle_table(con, "orri.veidarfaeri_ny", fd_raw("gear", "orri_veidarfaeri_ny.parquet"))
dump_oracle_table(con, "gear.veidarfaeri_v",  fd_raw("gear", "gear_veidarfaeri_v.parquet"))
dump_oracle_table(con, "gear.fishing_gear",   fd_raw("gear", "gear_fishing_gear.parquet"))
dump_oracle_table(con, "gear.gear_category",  fd_raw("gear", "gear_gear_category.parquet"))
dump_oracle_table(con, "gear.isscfg",         fd_raw("gear", "gear_isscfg.parquet"))
