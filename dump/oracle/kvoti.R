# kvoti — the Directorate of Fisheries' quota system (LODS landings, vessel history skipasaga, port codes stadur),
# every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle kvoti
# Output: raw/oracle/kvoti/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/kvoti.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# 748 objects on 2026-10-14: 435 tables holding 60.7 M rows (the largest, lods_afli, 11.3 M), and 313 views.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "kvoti", fd_raw("oracle", "kvoti"), script = "dump/oracle/kvoti.R")
