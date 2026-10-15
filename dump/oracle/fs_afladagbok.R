# fs_afladagbok — the Directorate of Fisheries' electronic logbooks (read through the end of this dump, then adb;
# decision 000), every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle fs_afladagbok
# Output: raw/oracle/fs_afladagbok/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fs_afladagbok.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "fs_afladagbok", fd_raw("oracle", "fs_afladagbok"), script = "dump/oracle/fs_afladagbok.R")
