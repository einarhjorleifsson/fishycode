# ops$einarhj — the maintainer's own schema, every table as Oracle holds it (plan 018).
#
# Input:  Oracle ops$einarhj
# Output: raw/oracle/ops_einarhj/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/ops_einarhj.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Until 2026-10-17 only the five tables the pipeline reads were dumped (mobile_vid for ais_key_cascade; the three
# vessel_mmsi snapshots and mmsi_icelandic_registry for the MMSI history, plan 016). The whole schema is wanted
# (maintainer, 2026-10-17): it holds the MMSI list of 2023-01-15 (TODO 71) and the earlier versions of the STK key
# that plan 022 §3 reviews. 52 tables, about 20 M rows (heildarafli 6.7 M, the two lb_gear_correction 4.8 M each).
# A dump resumed from the one of 2026-10-16 (--resume, dump/oracle/README.md) keeps the five files, so the targets
# that track them (mmsi_raw in _targets.R) do not go outdated on a new stamp alone.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ops$einarhj", fd_raw("oracle", "ops_einarhj"), script = "dump/oracle/ops_einarhj.R")
