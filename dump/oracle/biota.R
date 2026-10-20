# biota — MFRI's biological samples (measurements, otoliths), every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle biota
# Output: raw/oracle/biota/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/biota.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Asked for by the maintainer (2026-10-20) with channel. fiskar is not dumped: what it held is now in biota
# (maintainer, 2026-10-20). 65 tables and 31 views, 38.7 M rows
# (raw/oracle/_catalogue/objects.parquet); measure holds 25.9 M and otolith 5.7 M. Should a big table lose the
# connection through RJDBC, as afli's logger did, it goes by year of a time column (`partition`, as in afli.R), and
# `Rscript dump/oracle/biota.R --resume` keeps what was written and dumps the rest.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "biota", fd_raw("oracle", "biota"), script = "dump/oracle/biota.R")
