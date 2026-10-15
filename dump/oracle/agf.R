# agf — the landings, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle agf
# Output: raw/oracle/agf/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/agf.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# The two views left out of every earlier dump (aflagrunnur_sec_v, aflagrunnur_th_igildi_v, reason not recorded)
# are tried too; a failure is recorded in the overview.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "agf", fd_raw("oracle", "agf"), script = "dump/oracle/agf.R")
