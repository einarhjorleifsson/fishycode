# Objective ------------------------------------------------------------------
# Side: preprocessing (landings). See plan 014.
# Convert agf (aflagrunnur, the current landings system, live since 2007-09-01)
# into source-shaped staging tables. Merged with lods (curate/plans/007) in
# curate/landing.R, which also does the hid -> pid port join - not duplicated
# here since lods needs the same join.
#
# Input:  raw/oracle/agf/aflagrunnur.parquet
# Output: staging/landing/agf/landings.parquet
#         staging/landing/agf/catch.parquet
#         staging/landing/agf/catch_detail.parquet
#
# catch_detail keeps the state the fish were landed in and the weight as landed beside the ungutted equivalent (plan
# 051 step 5), so a factor can be read back and re-applied: per landing, gear, species, stock, `state` (astand,
# ask.astand's code) and `area` (veidisvaedi, IS for Iceland's waters), the weights `catch_landed` (magn, as landed),
# `catch_gutted` (magn_slaegt, its gutted equivalent) and `catch` (magn_oslaegt, the ungutted equivalent). The landing
# system's own factor is catch / catch_landed. And `afdrif`, what became of each row's catch, as agf records it (V to
# processing, U exported unprocessed, and seven more; plan 036 §2): curate/landing.R reads the disposition from it
# (decision 208).
#
# In DuckDB, lazily: the rows never enter R. DuckDB runs on one thread here, so each sum adds its rows in the file's
# order, as R's sum over the collected rows did, and every total is the same to the last bit; on four threads the
# order varies, and about 0.2 % of the sums differ in it. One thread sums the 5.4 M rows in seconds. The persons'
# columns (seljandi, kaupandi, vidtakandi, sng) are never read.

SCHEMA <- "agf"

con <- duckdbfs::cached_connection()
threads <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS n")$n
DBI::dbExecute(con, "SET threads = 1")
q <- function(sql) dplyr::tbl(con, dplyr::sql(sql))
DBI::dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP VIEW agf_rows AS
  SELECT londun_id AS \".lid\", skip_numer AS vid, CAST(londun_hefst AS DATE) AS date,
         hafnarnumer AS hid, veidarfaeri AS gid, fisktegund AS sid, veidistofn AS stid, astand AS state,
         veidisvaedi AS area, afdrif, magn AS catch_landed, magn_slaegt AS catch_gutted, magn_oslaegt AS catch
  FROM read_parquet('%s')", fd_raw("oracle", "agf", "aflagrunnur.parquet")))

# A landing trip is a vessel's day at a port; its id is the lowest delivery id in it.
DBI::dbExecute(con, "
  CREATE OR REPLACE TEMP VIEW agf_catch AS
  SELECT min(\".lid\") OVER (PARTITION BY date, vid, hid) AS \".tid_land\", *
  FROM (SELECT \".lid\", vid, date, hid, gid, sid, stid, coalesce(sum(catch), 0) AS catch, 'agf' AS schema
        FROM agf_rows GROUP BY \".lid\", vid, date, hid, gid, sid, stid)")

landings <- q('SELECT DISTINCT ".tid_land", vid, date, hid, schema FROM agf_catch ORDER BY ".tid_land", vid, date, hid')
catch <- q('SELECT ".tid_land", ".lid", gid, sid, stid, catch, schema FROM agf_catch
            ORDER BY ".lid", vid, date, hid, gid, sid, stid')
catch_detail <- q('
  SELECT t.".tid_land", d.* FROM (
    SELECT ".lid", gid, sid, stid, state, area, afdrif, coalesce(sum(catch_landed), 0) AS catch_landed,
           coalesce(sum(catch_gutted), 0) AS catch_gutted, coalesce(sum(catch), 0) AS catch,
           \'agf\' AS schema
    FROM agf_rows GROUP BY ".lid", gid, sid, stid, state, area, afdrif) d
  JOIN (SELECT DISTINCT ".lid", ".tid_land" FROM agf_catch) t USING (".lid")
  ORDER BY d.".lid", gid, sid, stid, state, area, afdrif')

landings     |> duckdbfs::write_dataset(fd_staging("landing", "agf", "landings.parquet"))
catch        |> duckdbfs::write_dataset(fd_staging("landing", "agf", "catch.parquet"))
catch_detail |> duckdbfs::write_dataset(fd_staging("landing", "agf", "catch_detail.parquet"))
DBI::dbExecute(con, sprintf("SET threads = %d", threads))
