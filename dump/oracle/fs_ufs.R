# fs_ufs — four of the Directorate of Fisheries' reference tables, every table as Oracle holds it (plan 018).
#
# Input:  Oracle fs_ufs
# Output: raw/oracle/fs_ufs/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/fs_ufs.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. landing_species (169 rows) links each
# landings species code to orri's code, MFRI's taxon number, its names, WoRMS id and target assemblage: the
# crosswalk TODO 10 lacks. fisktegundir (331), skip (5,413: vessel number, IMO, call sign) and postnumer are small.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "fs_ufs", fd_raw("oracle", "fs_ufs"), script = "dump/oracle/fs_ufs.R")
