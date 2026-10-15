# adb — the electronic logbooks (Oracle schema adb), every table and view as it is.
#
# Input:  Oracle adb
# Output: raw/logbooks/adb/<name>.parquet, _overview_tables.parquet, _overview_fields.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/adb.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "adb", fd_raw("logbooks", "adb"), script = "dump/oracle/adb.R")
