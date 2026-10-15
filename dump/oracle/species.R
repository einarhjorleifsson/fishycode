# species — the FAO ASFIS species list, as it is.
#
# Input:  Oracle asfis.asfis
# Output: raw/species/asfis.parquet
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/species.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- mar::connect_mar(rjdbc = TRUE)
dump_oracle_table(con, "asfis.asfis", fd_raw("species", "asfis.parquet"))
