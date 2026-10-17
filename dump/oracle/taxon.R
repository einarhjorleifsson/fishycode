# taxon — MFRI's species register, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle taxon
# Output: raw/oracle/taxon/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/taxon.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# The species reference of TODO 10 (maintainer, 2026-10-17). tegund_v gives each MFRI species number its names, rank
# and hierarchy, WoRMS id, FAO taxon id and FAO 3-alpha code; species, taxon, taxon_unit and vernacular are its
# tables. 16 objects, about 11 thousand rows (Oracle's estimates, raw/oracle/_catalogue/objects.parquet). The
# $err tables are dumped too: they hold rows the load rejected. Its journal schema, taxon_log, is not dumped.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "taxon", fd_raw("oracle", "taxon"), script = "dump/oracle/taxon.R")
