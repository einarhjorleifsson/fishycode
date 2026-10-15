# orri — two gear code tables of MFRI's general schema, as Oracle holds them (plan 018).
#
# Input:  Oracle orri
# Output: raw/oracle/orri/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/orri.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# orri is MFRI's catch-all schema; only the two tables named are dumped, and the overview lists the rest.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_schema(con, "orri", fd_raw("oracle", "orri"), tables = c("veidarfaeri", "veidarfaeri_ny"),
                   script = "dump/oracle/orri.R")
