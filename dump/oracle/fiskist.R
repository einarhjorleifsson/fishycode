# fiskist — one table from the Directorate of Fisheries, every table and view as Oracle holds it (plan 018, plan 037 phase 0).
#
# Input:  Oracle fiskist
# Output: raw/oracle/fiskist/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fiskist.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Prepared 2026-10-21 (plan 037 §3.3, the maintainer's request to have the missing schemas that seem to warrant it
# ready), not yet run. Judged from raw/oracle/_catalogue/objects.parquet: 1 table, ttrail, 1.8 M rows: a track of some
# kind, to be looked at before deciding whether it is wanted.
# Its columns were not read before the script was written (Oracle did not answer that evening). Persons' data are
# kept (decision 159); _data-dict.yaml under $FISHYDATA holds examples of them.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "fiskist", fd_raw("oracle", "fiskist"), script = "dump/oracle/fiskist.R")
