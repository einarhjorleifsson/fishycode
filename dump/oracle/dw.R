# dw — the Directorate of Fisheries' data warehouse, every table and view as Oracle holds it, except its copies of
# the landings and quotas and its owner tables (plan 018).
#
# Input:  Oracle dw
# Output: raw/oracle/dw/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/dw.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Added 2026-10-17 (maintainer), found through raw/oracle/_catalogue/. dw_aflaskeyti holds 21,627 rows of ERS catch
# messages, with the vessel's flag state, haul positions and times, FAO gear and species and kg: the exchange with
# Norway and the Faroes of 2014-2018, measured in decision 126: the Norwegian and Faroese rows are haul-level logbook
# records, and the latitude and longitude columns are swapped. The FAO code lists (species, gear, areas, countries)
# and the warehouse's own species, gear, area and port lists are small.
# Left out: dw_afli, dw_afli_test, dw_afli_v and dw_heildarafli, copies of the landings that agf and kvoti hold
# (15 M rows by Oracle's estimates), and dw_skip, dw_millifaerslur and dw_uthlutanir. Five of the seven carry owners'
# kennitala (dw_skip their names too), which fishycode has no use for (as for orri).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "dw", fd_raw("oracle", "dw"),
                   skip = c("dw_afli", "dw_afli_test", "dw_afli_v", "dw_heildarafli",
                            "dw_skip", "dw_millifaerslur", "dw_uthlutanir"),
                   script = "dump/oracle/dw.R")
