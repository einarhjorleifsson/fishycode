# vessels — the vessel registry (Oracle schema vessel), every table and view as it is.
#
# Input:  Oracle vessel
# Output: raw/vessels/<name>.parquet, _overview_tables.parquet, _overview_fields.parquet
#         (raw/vessels/ also holds files from dump/oracle/vessel_history.R and the MMSI archive)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/vessels.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "vessel", fd_raw("vessels"), script = "dump/oracle/vessels.R")
