# kvotix — the quota system's history and logs, every table and view as Oracle holds it (plan 018, plan 037 phase 0).
#
# Input:  Oracle kvotix
# Output: raw/oracle/kvotix/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/kvotix.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Prepared 2026-10-21 (plan 037 §3.3, the maintainer's request to have the missing schemas that seem to warrant it
# ready), not yet run. Judged from raw/oracle/_catalogue/objects.parquet: 28 tables and 1 view, 22.0 M rows by Oracle's
# estimates: the logs of the landings' changes (log_lods, 2.6 M, the master of log_lods2_londun and others), the
# landing notifications (log_ivln_tilkynning_londun, 1.7 M), the catch error checks (kvoti_afli_villutekk, 90,739;
# its detail 272,883), the quota-status history (kv_stada_saga, 13.9 M) and the vessel-history log (log_skipasaga).
# Wanted as the layers above the landings: their in-house edits and the checks behind them.
# Its columns were not read before the script was written (Oracle did not answer that evening). Persons' data are
# kept (decision 159); _data-dict.yaml under $FISHYDATA holds examples of them.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "kvotix", fd_raw("oracle", "kvotix"), script = "dump/oracle/kvotix.R")
