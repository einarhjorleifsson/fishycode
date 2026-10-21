# dwstg — the staging of the Directorate's data warehouse, every table and view as Oracle holds it (plan 018, plan 037 phase 0).
#
# Input:  Oracle dwstg
# Output: raw/oracle/dwstg/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/dwstg.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Prepared 2026-10-21 (plan 037 §3.3, the maintainer's request to have the missing schemas that seem to warrant it
# ready), not yet run. Judged from raw/oracle/_catalogue/objects.parquet: 20 tables, 69,922 rows: the ERS hauls, logs and
# species before dw_aflaskeyti (stg_catch_haul_hst, stg_catch_log_hst, stg_catch_species_hst), their error tables
# (catch_*_error) and port notifications (stg_port_notification_hst). Wanted as the layer upstream of the ERS
# reports fishycode reads (plan 026), with what was rejected.
# Its columns were not read before the script was written (Oracle did not answer that evening). Persons' data are
# kept (decision 159); _data-dict.yaml under $FISHYDATA holds examples of them.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "dwstg", fd_raw("oracle", "dwstg"), script = "dump/oracle/dwstg.R")
