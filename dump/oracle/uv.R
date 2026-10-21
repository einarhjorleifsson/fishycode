# uv — fishing areas, closures and regulation areas, every table and view as Oracle holds it (plan 018).
#
# Input:  Oracle uv
# Output: raw/oracle/uv/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/uv.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. veidisvaedi holds 5,948 areas with their
# type (teg_veidisvaeda: real-time closure, regulation, protected area, ...), valid from and to, and reason; hnit
# their 25,929 boundary points (hnit_n, hnit_v, which mar::get_skyndilokun() converts with geoconvert(), negating the
# longitude); veidisv_veidarf and veidisv_fteg the gear and species each area concerns.
# For fixes that fish inside a closed area, and perhaps the trawl limits of TODO 34 (not checked).
# The staff (starfsm: kennitala and names; veidisv_starfsm, which links them to areas; hafro_notendur_v: names and
# e-mail) were left out from 2026-10-17 to 2026-10-21. The areas keep the name of whoever entered them (sng, sbg).
# Persons' data are dumped since 2026-10-21 (maintainer): kennitala may be carried up to curated/ (2026-10-18), under
# $FISHYDATA only and never published; _data-dict.yaml holds examples of their values there too.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "uv", fd_raw("oracle", "uv"),
                   script = "dump/oracle/uv.R")
