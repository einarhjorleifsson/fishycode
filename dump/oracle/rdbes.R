# rdbes — MFRI's tables for ICES's Regional Database and Estimation System, every table and view as Oracle holds it
# (plan 018).
#
# Input:  Oracle rdbes
# Output: raw/oracle/rdbes/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/rdbes.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. For the datacall's metier level 6 (plan 015
# §4 a): metier (72,147 rows: the metiers allowed by area, gear, target assemblage and mesh range). Also ICES's
# harbour LOCODEs, species codes, AphiaID to ASFIS, FAO areas, and effort_v and landing_v, MFRI's own effort and
# landings with metier6. About 0.2 M rows in all; the RDBES upload tables name vessels by
# an encrypted code.
# Oracle gives effort_v's and landing_v's columns no type (UNDEFINED), which marks a view that does not compile, and
# area's polygons may pass the 4,000 characters a geometry is read in (.oracle_text): either is recorded as failed.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "rdbes", fd_raw("oracle", "rdbes"), script = "dump/oracle/rdbes.R")
