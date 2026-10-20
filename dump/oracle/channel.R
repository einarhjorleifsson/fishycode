# channel — MFRI's research cruises and stations (survey and other sampling), every table and view as Oracle holds it
# (plan 018).
#
# Input:  Oracle channel
# Output: raw/oracle/channel/: <name>.parquet per table and view, _overview_tables.parquet,
#         _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/channel.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Asked for by the maintainer (2026-10-20) with biota: the survey tows, timed by the scientific crew, are a witness
# of when a trawl fished that does not come from the logbook. 26 tables and 16 views, 1.1 M rows
# (raw/oracle/_catalogue/objects.parquet); among them cruise, station, station_environment and their $err tables.

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
dump_oracle_schema(con, "channel", fd_raw("oracle", "channel"), script = "dump/oracle/channel.R")
