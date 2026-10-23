# ops$sigfus — a former MFRI scientist's schema, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle ops$sigfus
# Output: raw/oracle/ops_sigfus/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/ops_sigfus.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Wanted whole (maintainer, 2026-10-23). afli's 40,967 monthly summary stations say they come from here
# ("Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt", "...GOMUL_RAEKJA..."; the seine's from afli.gomul_dragnot), and the
# schema may hold historical records seen nowhere else. The catalogue of 2025-03-31 statistics lists 47 tables
# (2.09 M rows: le_kv_nov_2011 1.45 M, ferill 0.36 M, gamall_humar 20,949, gomul_raekja 10,531, gomul_dragnot
# 2,792; foreign catch and effort, tuna, survey stations, place names, shrimp fjord areas) and 62 views.
# The notes study is $FISHYDATA/archive/2026-10-logbook-notes/ (README). An ops$ schema may hold persons' tables:
# read them by counts and columns only (decision 159).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ops$sigfus", fd_raw("oracle", "ops_sigfus"), script = "dump/oracle/ops_sigfus.R")
