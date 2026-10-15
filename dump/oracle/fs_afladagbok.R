# fs_afladagbok — the Directorate of Fisheries' electronic logbooks (Oracle schema fs_afladagbok), every table and
# view as it is. The merge reads it through the end of its dump and adb beyond (decision 000).
#
# Input:  Oracle fs_afladagbok
# Output: raw/logbooks/fs_afladagbok/<name>.parquet, _overview_tables.parquet, _overview_fields.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fs_afladagbok.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "fs_afladagbok", fd_raw("logbooks", "fs_afladagbok"),
                   script = "dump/oracle/fs_afladagbok.R")
