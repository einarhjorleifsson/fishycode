# Dump the ITU call-sign prefix -> flag state table from Oracle.
#
# Input:  Oracle, ops$einarhj.vessel_cs_itu_prefix
# Output: raw/aux/callsign_prefix.parquet
#
# Consumed by reference/vessels/ais_key.R to drop Icelandic call signs (TF) when
# matching STK mobile ids to vessels.
#
# This lived disabled inside an if(FALSE) block in reference/lookups.R, so that
# script silently produced two of its three declared outputs. It needs the
# server; run it there, not on a laptop.

library(mar)
library(tidyverse)

con <- connect_mar()

tbl_mar(con, "ops$einarhj.vessel_cs_itu_prefix") |>
  collect() |>
  nanoparquet::write_parquet(fd_raw("aux", "callsign_prefix.parquet"))
