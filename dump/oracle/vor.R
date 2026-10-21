# vor — the weighings, the catch's disposition and the fish markets, every table and view as Oracle holds it (plan 018, plan 037 phase 0).
#
# Input:  Oracle vor
# Output: raw/oracle/vor/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/vor.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Prepared 2026-10-21 (plan 037 §3.3, the maintainer's request to have the missing schemas that seem to warrant it
# ready), not yet run. Judged from raw/oracle/_catalogue/objects.parquet: 46 tables and 51 views, 24.6 M rows: weighings
# (vigt 4.0 M, vigt_linur 12.9 M), the catch's disposition (radstafanir 143,798, its lines 1.4 M), resale
# (endursala), market reports (mark_skyrslur 5.7 M), the fish markets' auction data (rsf_markadur, with
# rsf_markadur_xml) and summaries against LODS. Wanted as a second record of the weighings and the disposition
# (plan 036) and for the value.
# Its columns were not read before the script was written (Oracle did not answer that evening). Persons' data are
# kept (decision 159); _data-dict.yaml under $FISHYDATA holds examples of them.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "vor", fd_raw("oracle", "vor"), script = "dump/oracle/vor.R")
