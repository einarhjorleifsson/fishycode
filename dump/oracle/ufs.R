# ufs — the Directorate of Fisheries' reference tables, every table and view as Oracle holds it, except Oracle's
# own Java tables (plan 018).
#
# Input:  Oracle ufs
# Output: raw/oracle/ufs/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/ufs.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. agf's views read ufs.fisktegundir, the
# landed species with their FAO code (TODO 10). Its ports (stadir), gear and operator classes are the landings';
# skipasaga is the Directorate's vessel history (56,986 rows: name, signs, home port, operator class, tonnage, length,
# valid from and to).
# About 0.6 M rows in all. The _jn tables are Oracle Designer's change journals; they name the Oracle user who made
# each change, as ask's do.
# The register of persons and companies (adilar and its journal, commented "Þjóðskrá!"), the views that add owners'
# kennitala and names to the vessel tables (skipasaga_v, skipaskra_v, skip_aukaadilar_v: who owned and ran each
# vessel when), and the user and session logs and IP addresses (iptolur, log_*, notenda_log_*, errlog) were left out
# from 2026-10-17 to 2026-10-21. Oracle's own Java tables still are.
# Persons' data are dumped since 2026-10-21 (maintainer): kennitala may be carried up to curated/ (2026-10-18), under
# $FISHYDATA only and never published; _data-dict.yaml holds examples of their values there too.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ufs", fd_raw("oracle", "ufs"),
                   skip = c("create$java$lob$table", "java$options"),
                   script = "dump/oracle/ufs.R")
