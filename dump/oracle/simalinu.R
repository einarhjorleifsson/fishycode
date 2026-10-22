# simalinu — the line-fishing phone notifications (símalína), every table and view as Oracle holds it (plan 018; found for decision 163).
#
# Input:  Oracle simalinu
# Output: raw/oracle/simalinu/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/simalinu.R
# The password comes from the macOS keychain, so it runs in your own terminal. The first dump (2026-10-21 21:14) ran
# through RJDBC from Claude's shell at the maintainer's request, before this file was committed (`dirty = true`); a
# server run replaces it (decision 162).
#
# Added 2026-10-21 (plan 037): kvoti.ivln_tilk_slina_stk_v, the line-incentive check, takes the phone times of a landing's
# departure and arrival from simalinu.tilk_linu_sokn (263,326 rows by Oracle's estimate), a table the catalogue did not
# list. The schema has 7 tables: that one, skip_lykilnumer (the ships registered for line fishing, with the key number the
# owner gives when calling before a trip, no call needed from fishing year 2014/15) with its backup and journal, tilk_vss
# (a copy of the Coast Guard's calls) and two temporary tables. Persons' data are kept (decision 159): the actor and
# account columns (`gerandi`, `sng`, `sbg`) are never printed.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "simalinu", fd_raw("oracle", "simalinu"), script = "dump/oracle/simalinu.R")
