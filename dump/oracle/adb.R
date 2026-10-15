# adb — the electronic logbooks, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle adb
# Output: raw/oracle/adb/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/adb.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "adb", fd_raw("oracle", "adb"), script = "dump/oracle/adb.R")
