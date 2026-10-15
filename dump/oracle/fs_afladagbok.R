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

con <- dump_connect()
# takt_json_form (6,912 rows) is left out. Its CLOB columns, json_clob and file_base64 (whole files as base64), came at
# about 3 MB/s, one LOB fetch per row, at 2 % CPU; after 10+ minutes it had not finished, and it was stopped
# (2026-10-15). The wait is the round trips, not R. Getting it means a tool that fetches LOBs in bulk, outside R or
# with JDBC's LOB prefetch, sized first with SUM(DBMS_LOB.GETLENGTH(...)). It was not in the April dump either.
dump_oracle_schema(con, "fs_afladagbok", fd_raw("oracle", "fs_afladagbok"), skip = "takt_json_form",
                   script = "dump/oracle/fs_afladagbok.R")
