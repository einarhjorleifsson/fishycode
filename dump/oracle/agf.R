# agf — the landings (Oracle schema agf), every table and view as it is.
#
# Input:  Oracle agf
# Output: raw/landings/agf/<name>.parquet, _overview_tables.parquet, _overview_fields.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/agf.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# The LODS landings (kvoti.lods_*) are dumped by dump/oracle/lods.R.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
# The two views were left out of every earlier dump; the reason was not recorded.
dump_oracle_schema(con, "agf", fd_raw("landings", "agf"),
                   skip = c("aflagrunnur_sec_v", "aflagrunnur_th_igildi_v"),
                   script = "dump/oracle/agf.R")
