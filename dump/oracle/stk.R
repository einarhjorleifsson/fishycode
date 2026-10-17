# stk — the STK vessel-monitoring system (position reports and mobile units), every table and view as Oracle holds
# it (plan 018).
#
# Input:  Oracle stk
# Output: raw/oracle/stk/: <name>.parquet per table and view, the trail as trail/year=<y>/data_0.parquet,
#         _overview_tables.parquet, _overview_fields.parquet, _data-dict.yaml; every file stamped with the dump's
#         time (fd.dumped)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/stk.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# The trail is about 300 M rows: by year of recdate, the receipt time, which is indexed and puts each report in one
# year. A year is fetched again until it reaches 31 December. The whole trail takes roughly 2-3 h on first run.
# Its preferred form (lon/lat in degrees, knots, .id, mid) is stk_trail(), not this dump (plan 018).

for (f in list.files("R", full.names = TRUE)) source(f)

# Left out (hafdruna, 2026-10-16): tilk_stk_por_v, departures paired with arrivals, which Oracle did not finish
# evaluating in over 2 h, twice; tilk_stk_allt holds voyages, each a departure and its arrival, and tilk_stk the events
# behind both (TODO 68). toti2_mobile_skip_v holds mobile_skip_mv's columns (plan 022),
# which is dumped. Its ORA-00942 was not Oracle's: the dumper upper-cased its mixed-case name, toti2_MOBILE_SKIP_V,
# which it now spells as Oracle does (decision 122); mobile_skip_v, mobile_skip_mv and mobile_tab hold mobile ids with
# vessels.
con <- dump_connect()
dump_oracle_schema(con, "stk", fd_raw("oracle", "stk"), partition = list(trail = "recdate"),
                   skip = c("tilk_stk_por_v", "toti2_mobile_skip_v"), script = "dump/oracle/stk.R")
