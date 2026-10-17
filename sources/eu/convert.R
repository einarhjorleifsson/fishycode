# The EU Fishing Fleet Register.
# Side: preprocessing (eu). See plan 014.
#
# Input:  raw/external/eu/vesselRegistryListResults.csv
# Output: staging/eu/vessel_event.parquet — one row per (cfr, event)
#
# This is an event ledger, not a snapshot: `event`/`t1`/`t2` are the source's
# own registration-event boundaries (CEN first registration, MOD modified,
# RET/DES/EXP exit). Plan 008 §5.0 measured these as already the right period
# grain for a time-aware identity match - kept as-is here, not collapsed to
# "current," so reference/vessels/identity_foreign.R (where periods actually get
# used for matching) has the real boundaries to work with.
#
# Fishing vessels only, by construction - CFR registration is fisheries-
# specific (plan 008 §6, confirmed from the Vessel Type gear-segment codes).
#
# uvi -> imo only where it passes the IMO check-digit algorithm. Confirmed
# 2026-09-27: every populated UVI in this file does (3,753 of 183,748
# vessels) - asserted here rather than assumed, since a future export could
# differ.

library(DBI)
library(duckdb)
library(dplyr)
library(nanoparquet)

is_valid_imo <- function(x) {
  ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  digs <- matrix(NA_integer_, length(x), 7)
  digs[ok, ] <- do.call(rbind, lapply(x[ok], function(s) as.integer(strsplit(s, "")[[1]])))
  checksum <- digs[, 1] * 7 + digs[, 2] * 6 + digs[, 3] * 5 +
              digs[, 4] * 4 + digs[, 5] * 3 + digs[, 6] * 2
  ok & (checksum %% 10) == digs[, 7]
}

con <- dbConnect(duckdb())

f <- fd_raw("external", "eu", "vesselRegistryListResults.csv")
dbExecute(con, sprintf("
  CREATE VIEW eu AS
  SELECT * FROM read_csv('%s', delim=';', header=true, quote='\"',
    null_padding=true, strict_mode=false, max_line_size=1000000)
", f))

eu <- dbGetQuery(con, '
  SELECT
    "CFR"                          AS cfr,
    CAST("UVI" AS VARCHAR)         AS uvi,
    "Country of Registration"      AS flag,
    "Event"                        AS event,
    "Event Start Date"             AS t1,
    "Event End Date"               AS t2,
    "Registration Number"          AS registration_number,
    "External marking"             AS external_marking,
    "Name of vessel"               AS name,
    "Place of registration"        AS place_of_registration,
    "Place of registration name"   AS place_of_registration_name,
    "IRCS"                         AS cs,
    CAST("MMSI" AS VARCHAR)        AS mmsi,
    "Vessel Type"                  AS vessel_type,
    "Main fishing gear"            AS gear_main,
    "Subsidiary fishing gear 1"    AS gear_subsidiary_1,
    "Subsidiary fishing gear 2"    AS gear_subsidiary_2,
    "Subsidiary fishing gear 3"    AS gear_subsidiary_3,
    "Subsidiary fishing gear 4"    AS gear_subsidiary_4,
    "Subsidiary fishing gear 5"    AS gear_subsidiary_5,
    "LOA"                          AS loa,
    "LBP"                          AS lbp,
    "Tonnage GT"                   AS gross_tonnage,
    "Other tonnage"                AS other_tonnage,
    "Power of main engine"         AS engine_power_kw,
    "Power of auxiliary engine"    AS engine_power_aux_kw,
    "Hull material"                AS hull_material,
    "Segment"                      AS segment,
    "Year of construction"         AS year_of_build
  FROM eu
')

n_uvi <- sum(!is.na(eu$uvi))
n_valid <- sum(is_valid_imo(eu$uvi))
cat("rows:", nrow(eu), "  distinct cfr:", length(unique(eu$cfr)), "\n")
cat("uvi populated:", n_uvi, "  passing IMO checksum:", n_valid, "\n")
stopifnot(n_valid == n_uvi)  # confirmed 2026-09-27; assert it stays true

eu <- eu |>
  mutate(imo = if_else(is_valid_imo(uvi), uvi, NA_character_),
         t1 = as.Date(t1), t2 = as.Date(t2),
         # a literal string "null" (3 rows, cs only) - an export artifact,
         # not a real NA, found while resolving reference/vessels/
         # ais_key_foreign.R's cs_overlap flags on 2026-09-27 (a false
         # positive traced to this)
         cs = na_if(cs, "null")) |>
  select(-uvi)

eu |>
  nanoparquet::write_parquet(fd_staging("eu", "vessel_event.parquet"))

dbDisconnect(con, shutdown = TRUE)
