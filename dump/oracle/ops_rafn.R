# ops$rafn — one table of a colleague's schema, `rekjanleikanumer`: the landing side of the Directorate's trace id
# (plan 018).
#
# Input:  Oracle ops$rafn
# Output: raw/oracle/ops_rafn/: rekjanleikanumer.parquet, _overview_tables.parquet, _overview_fields.parquet,
#         _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/ops_rafn.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Wanted for TODO 160 (plan 054 ask c, decision 247). The trip side of the trace id is fs_afladagbok's
# ws_rekjanleiki; the landing side is in no dumped table, only here (178,555 rows, 2026-10-29), and is never to be
# read from the new mar's parquet on S3. Only this table is taken (`tables =`): the schema's other objects are listed,
# not dumped, so all.R --resume dumps this one table again on every run (.dump_finished()). An ops$ schema may hold
# persons' tables: read them by counts and columns only (decision 159).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "ops$rafn", fd_raw("oracle", "ops_rafn"), tables = "rekjanleikanumer",
                   script = "dump/oracle/ops_rafn.R")
