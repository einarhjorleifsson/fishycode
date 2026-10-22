# fiskifelagid — Fiskifélag Íslands' historical registers, every table and view as Oracle holds it (plan 018, plan 037 phase 0).
#
# Input:  Oracle fiskifelagid
# Output: raw/oracle/fiskifelagid/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fiskifelagid.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Prepared 2026-10-21 (plan 037 §3.3, the maintainer's request to have the missing schemas that seem to warrant it
# ready); run on the server 2026-10-21 at c27886a and adopted (decision 162). Judged from raw/oracle/_catalogue/objects.parquet: 3 tables, 2.3 M rows: the weighing register and the
# disposition register of 1966-1981 (vigtarskra66_81, radstofunarskra66_81) and landed catch before 1994
# (landed_catch_pre94). Wanted for the history only, before the AIS.
# Its columns were not read before the script was written (Oracle did not answer that evening). Persons' data are
# kept (decision 159); _data-dict.yaml under $FISHYDATA holds examples of them.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "fiskifelagid", fd_raw("oracle", "fiskifelagid"), script = "dump/oracle/fiskifelagid.R")
