# Merge agf and lods into unified landing tables.
# Side: preprocessing (landings). See plan 014.
# Input:  staging/landing/{agf,lods}/{landings,catch,catch_detail}.parquet
#         curated/reference/port_code.parquet   each code's class (harbour, disposition, abroad, transfer, placeholder)
# Output: curated/landing/{landings,catch}.parquet
#         curated/landing/catch_detail.parquet   the same catch by state, area and disposition, with the weight as
#         landed (plan 051 step 5): .lid schema sid gid stid kfteg hid_origin state area afdrif catch_landed
#         catch_gutted catch factor_landing disposition disposition_basis
#
# Decision rule (curate/plans/007 §2): agf wins wherever a (vid, date, hid)
# trip exists in agf, on both presence and value - lods contributes only the
# trips agf has nothing at all for. This is deliberately not a date cutoff:
# agf and lods run in parallel to the present, and a hard cutoff would
# misrepresent or silently drop both sides' exceptions to it (curate/plans/007
# §1-2). Real figures: see curate/plans/007's own measured section, re-run
# after the lods key fix below rather than duplicated here to avoid drift.
#
# .tid_land -> .lid (curate/plans/007 §3): agf's own staging catch table
# still carries the per-delivery raw id (.lid) it was built from (sources/
# aflagrunnur/convert.R); this collapses it away, grouping by (.tid_land,
# schema, sid, gid, stid, kfteg) and summing catch - species, gear and stock
# all vary within a real multi-delivery trip and are kept; only the raw
# per-delivery record id is dropped (curate/plans/007 §5). lods no longer has
# a per-delivery id to collapse (sources/lods/convert.R mints .tid_land
# directly from (vid, date, hid) - komunr turned out to be a recycled
# loading-batch code, not a stable per-delivery id), so this step is a no-op
# for it, just naming. The surviving trip-level key is renamed .tid_land ->
# .lid.
#
# The composite key is (.lid, schema), not .lid alone (curate/plans/007 §4):
# agf's and lods' own id domains can still coincide by chance even now that
# lods' own id is a hash, not a recycled raw field - the merge below keys
# uniqueness on (vid, date, hid) for the precedence decision, which is safe,
# but a consumer joining landing_catch on .lid alone (not .lid + schema) can
# still collide across schemas.
#
# The hid -> pid port join happens once here, not duplicated in each source
# adapter.
#
# catch_detail keeps what catch sums away (plan 051 step 5): the state the fish were landed in (agf's astand; NA for
# lods, whose weight is "gutted where it applies"), the area, the weight as landed (`catch_landed`, agf only), its
# gutted equivalent (`catch_gutted`) and the ungutted (`catch`), so a factor can be read back (`factor_landing`, the
# ungutted over the weight as landed, or over the gutted for lods) and re-applied. Its catch sums to catch.parquet's
# on every row, which keeps one row per landing, species, gear and stock, the gutted weight lods's only, as before.
#
# And what became of the catch, `disposition` (decision 208, plan 036 §3.3), with its basis, agf's own `afdrif` kept
# beside it. By the class of the landing's port code (reference/ports/port_code.R), then agf's afdrif:
#   abroad            a code of class abroad (a country, a sailing abroad)                          derived
#   transfer          a code of class transfer (to another vessel)                                  derived
#   unknown           a code of class placeholder, or no code                                       derived
#   export            LODS's 159 whose origin port is a harbour (exported in a container, to 2013-08) derived
#   export_or_abroad  LODS's 159 with no origin port, or one that is no harbour                     derived
#   export            agf's afdrif U at a harbour (from 2013-09)                                    recorded
#   home              agf's other afdrif at a harbour                                               recorded
#   home              LODS at a harbour (its exports are at 159)                                    derived
# The 159 landing stays a landing of its own (decision 208 b); curate/trip_landing.R joins it to its trip.

#
# In DuckDB, lazily, every table written by COPY (write_curated_sql()): nothing is collected into R. DuckDB runs on
# one thread here, so each sum adds its rows in the staged file's order, as R's grouped sum over the collected rows
# did, and catch.parquet is the same to the last bit. A join matches missing keys to each other, as dplyr's joins do.

con <- duckdbfs::cached_connection()
threads <- DBI::dbGetQuery(con, "SELECT current_setting('threads') AS n")$n
DBI::dbExecute(con, "SET threads = 1")
ex <- function(sql) invisible(DBI::dbExecute(con, sql))
n_of <- function(view) DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM %s", view))$n
rd <- function(...) sprintf("read_parquet('%s')", fd_staging("landing", ...))
pc <- sprintf("read_parquet('%s')", fd_curated("reference", "port_code.parquet"))

# .tid_land -> .lid, collapsing the per-delivery .lid out (agf only; a no-op regrouping for lods, which arrives
# already at this grain) -------------------
# lods only (decision 169): the port an export was landed at, the gutted weight and komunr; NULL for agf.
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW agf_catch AS
  SELECT ".tid_land" AS ".lid", schema, sid, gid, stid, CAST(NULL AS INTEGER) AS kfteg,
         CAST(NULL AS INTEGER) AS hid_origin, coalesce(sum(catch), 0) AS catch,
         CAST(NULL AS DOUBLE) AS catch_gutted, CAST(NULL AS INTEGER) AS komunr
  FROM %s GROUP BY ".tid_land", schema, sid, gid, stid]", rd("agf", "catch.parquet")))
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW lods_catch AS
  SELECT ".tid_land" AS ".lid", schema, sid, gid, stid, kfteg, hid_origin, coalesce(sum(catch), 0) AS catch,
         sum(catch_gutted) AS catch_gutted, first(komunr) AS komunr
  FROM %s GROUP BY ".tid_land", schema, sid, gid, stid, kfteg, hid_origin]", rd("lods", "catch.parquet")))
for (s in c("agf", "lods"))
  ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW %s_landings AS
    SELECT ".tid_land" AS ".lid", vid, date, hid, schema FROM %s]", s, rd(s, "landings.parquet")))

# The same catch by state and area, from the adapters' catch_detail (plan 051 step 5).
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW agf_detail AS
  SELECT ".tid_land" AS ".lid", schema, sid, gid, stid, CAST(NULL AS INTEGER) AS kfteg,
         CAST(NULL AS INTEGER) AS hid_origin, state, area, afdrif, sum(catch_landed) AS catch_landed,
         sum(catch_gutted) AS catch_gutted, coalesce(sum(catch), 0) AS catch
  FROM %s GROUP BY ".tid_land", schema, sid, gid, stid, state, area, afdrif]", rd("agf", "catch_detail.parquet")))
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW lods_detail AS
  SELECT ".tid_land" AS ".lid", schema, sid, gid, stid, kfteg, hid_origin, CAST(NULL AS INTEGER) AS state, area,
         CAST(NULL AS VARCHAR) AS afdrif, CAST(NULL AS DOUBLE) AS catch_landed, sum(catch_gutted) AS catch_gutted,
         coalesce(sum(catch), 0) AS catch
  FROM %s GROUP BY ".tid_land", schema, sid, gid, stid, kfteg, hid_origin, area]", rd("lods", "catch_detail.parquet")))

# Precedence: agf wherever present ---------------------------------------------
ex(r"[CREATE OR REPLACE TEMP TABLE lods_only_lid AS
  SELECT DISTINCT l.".lid" FROM lods_landings l
  WHERE NOT EXISTS (SELECT 1 FROM agf_landings a WHERE a.vid IS NOT DISTINCT FROM l.vid
                    AND a.date IS NOT DISTINCT FROM l.date AND a.hid IS NOT DISTINCT FROM l.hid)]")
lods_only <- r"[WHERE ".lid" IN (SELECT ".lid" FROM lods_only_lid)]"
ex(sprintf("CREATE OR REPLACE TEMP VIEW merged_landings AS
  SELECT * FROM agf_landings UNION ALL SELECT * FROM lods_landings %s", lods_only))
ex(sprintf("CREATE OR REPLACE TEMP VIEW merged_catch AS
  SELECT * FROM agf_catch UNION ALL SELECT * FROM lods_catch %s", lods_only))
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW merged_detail AS
  SELECT d.*, CASE WHEN catch_landed > 0 THEN catch / catch_landed
                   WHEN catch_landed IS NULL AND catch_gutted > 0 THEN catch / catch_gutted END AS factor_landing,
         CASE WHEN k.class = 'abroad' THEN 'abroad'
              WHEN k.class = 'transfer' THEN 'transfer'
              WHEN k.class = 'placeholder' OR l.hid IS NULL THEN 'unknown'
              WHEN k.class = 'disposition' AND o.class = 'harbour' THEN 'export'
              WHEN k.class = 'disposition' THEN 'export_or_abroad'
              WHEN k.class = 'harbour' AND d.afdrif = 'U' THEN 'export'
              WHEN k.class = 'harbour' THEN 'home' END AS disposition,
         CASE WHEN k.class = 'harbour' AND d.afdrif IS NOT NULL THEN 'recorded'
              WHEN k.class IS NOT NULL OR l.hid IS NULL THEN 'derived' END AS disposition_basis
  FROM (SELECT * FROM agf_detail UNION ALL SELECT * FROM lods_detail %s) d
  LEFT JOIN merged_landings l ON l.".lid" = d.".lid" AND l.schema = d.schema
  LEFT JOIN %s k ON k.hid = l.hid
  LEFT JOIN %s o ON o.hid = d.hid_origin]", lods_only, pc, pc))

# kg in = kg out: the details sum to the catch on every row of catch.parquet
key <- sprintf('"%s"', c(".lid", "schema", "sid", "gid", "stid", "kfteg", "hid_origin"))
chk <- DBI::dbGetQuery(con, sprintf("
  WITH d AS (SELECT %s, sum(catch) AS catch FROM merged_detail GROUP BY ALL)
  SELECT (SELECT count(*) FROM d) AS n_detail, (SELECT count(*) FROM merged_catch) AS n_catch,
         count(*) FILTER (WHERE abs(d.catch - c.catch) <= 1e-6) AS n_agree
  FROM d JOIN merged_catch c ON %s", paste(key, collapse = ", "),
  paste(sprintf("d.%s IS NOT DISTINCT FROM c.%s", key, key), collapse = " AND ")))
stopifnot(chk$n_detail == chk$n_catch, chk$n_agree == chk$n_catch)
# every row has a disposition and a basis: a code with no class stops port_code.R before this
disp <- DBI::dbGetQuery(con, "SELECT schema, disposition, disposition_basis, count(*) AS n, round(sum(catch) / 1e6, 1) AS kt
                               FROM merged_detail GROUP BY ALL ORDER BY ALL")
print(disp)
stopifnot(!anyNA(disp$disposition), !anyNA(disp$disposition_basis))

# Summary ------------------------------------------------------------------
cat(sprintf("agf trips:        %d\n", n_of("agf_landings")))
cat(sprintf("lods-only trips:  %d\n", n_of("lods_only_lid")))
cat(sprintf("merged trips:     %d\n", n_of("merged_landings")))
cat(sprintf("merged catch:     %d\n", n_of("merged_catch")))

# Port join ------------------------------------------------------------------
# hid is Fiskistofa's hafnarnumer; pid is the standard port key, so landings
# join to the same port identity as the logbooks and the AIS trail.
ex(sprintf(r"[CREATE OR REPLACE TEMP VIEW landings_port AS
  SELECT m.*, p.port AS "höfn", p.pid
  FROM merged_landings m LEFT JOIN read_parquet('%s') p ON p.hid IS NOT DISTINCT FROM m.hid]",
  fd_curated("reference", "port.parquet")))

# Export -----------------------------------------------------------------------
landing_inputs <- c(fd_staging("landing", "agf",  "landings.parquet"), fd_staging("landing", "agf",  "catch.parquet"),
                    fd_staging("landing", "lods", "landings.parquet"), fd_staging("landing", "lods", "catch.parquet"),
                    fd_staging("landing", "agf", "catch_detail.parquet"), fd_staging("landing", "lods", "catch_detail.parquet"),
                    fd_curated("reference", "port.parquet"), fd_curated("reference", "port_code.parquet"))
write_curated_sql(con, "SELECT * FROM landings_port", fd_curated("landing", "landings.parquet"), inputs = landing_inputs)
write_curated_sql(con, "SELECT * FROM merged_catch", fd_curated("landing", "catch.parquet"), inputs = landing_inputs)
write_curated_sql(con, "SELECT * FROM merged_detail", fd_curated("landing", "catch_detail.parquet"),
                  inputs = landing_inputs)
DBI::dbExecute(con, sprintf("SET threads = %d", threads))
