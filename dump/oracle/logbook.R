# logbook — Oracle schema logbook, every table and view as it is.
#
# Input:  Oracle logbook
# Output: raw/logbooks/logbook/<name>.parquet, _overview_tables.parquet, _overview_fields.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/logbook.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "logbook", fd_raw("logbooks", "logbook"), script = "dump/oracle/logbook.R")
