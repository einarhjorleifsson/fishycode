# ops$einarhj — the maintainer's own tables that the pipeline reads, as Oracle holds them (plan 018).
#
# Input:  Oracle ops$einarhj
# Output: raw/oracle/ops_einarhj/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/ops_einarhj.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# A personal schema: only the tables named are dumped, and the overview lists the rest.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ops$einarhj", fd_raw("oracle", "ops_einarhj"),
                   tables = c("mobile_vid",                 # the old STK mobile-id -> vid matches (ais_key_cascade)
                              "vessel_mmsi_20190627",       # the MMSI archive's sources 1-4 (plan 016)
                              "vessel_mmsi_20201215",
                              "vessel_mmsi_20220405",
                              "mmsi_icelandic_registry"),
                   script = "dump/oracle/ops_einarhj.R")
