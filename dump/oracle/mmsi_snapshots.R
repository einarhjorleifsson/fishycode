# The Oracle snapshots of the Icelandic MMSI allocation that the old MMSI archive was built from (plan 016 §4 step 1).
#
# Input:  Oracle ops$einarhj.vessel_mmsi_20190627, _20201215, _20220405 and ops$einarhj.mmsi_icelandic_registry - the
#         archive's sources 1-4, as fishydata_2024-2026/scripts/older/00_DATASET_ISL-mmsi_historical-consolidation_TOBEDELETED.R
#         read them
# Output: raw/mmsi/oracle_<table>.parquet, one file per table, as Oracle returns it
#
# Run by hand, with a connection to the MFRI Oracle database. Nothing is cleaned here: reference/vessels/mmsi.R reads
# these as they are (the rjdbc driver returns integer columns as doubles; the reader casts).

library(mar)
library(dplyr)
library(nanoparquet)

con <- connect_mar(rjdbc = TRUE)

tables <- c("vessel_mmsi_20190627", "vessel_mmsi_20201215", "vessel_mmsi_20220405", "mmsi_icelandic_registry")
for (tb in tables) {
  d <- tbl_mar(con, paste0("ops$einarhj.", tb)) |> collect()
  out <- fd_raw("mmsi", paste0("oracle_", tb, ".parquet"))
  write_parquet(d, out)
  cat(tb, ":", nrow(d), "rows ->", out, "\n")
}
