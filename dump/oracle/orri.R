# orri — MFRI's general schema, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle orri
# Output: raw/oracle/orri/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/orri.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Until 2026-10-17 only the two gear tables were dumped. The whole schema is wanted for its species list
# (fisktegundir, the code of the logbooks; fao_fisktegund_vorpun to FAO 3-alpha), the FAO gear and area mappings and
# the place names (ornefni) (maintainer, 2026-10-17; TODO 10).
# The national register of persons (thjodskra, br_thjodskra, einst), the staff (starfsmenn and its three views) and
# the company register (fyrirt, sole traders among them) hold names, kennitala and home addresses; left out from
# 2026-10-17 to 2026-10-21.
# Persons' data are dumped since 2026-10-21 (maintainer): kennitala may be carried up to curated/ (2026-10-18), under
# $FISHYDATA only and never published; _data-dict.yaml holds examples of their values there too.
# A dump resumed from the one of 2026-10-16 keeps its two gear files (--resume, dump/oracle/README.md).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "orri", fd_raw("oracle", "orri"),
                   script = "dump/oracle/orri.R")
