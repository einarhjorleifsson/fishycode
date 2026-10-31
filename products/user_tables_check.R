# The candidate's check (plan 056 §6): what publish_release() requires has passed before a release is frozen.
# Side: flow. It checks the candidate, which links the AIS tables. See plan 014.
#
# Input:  $FISHYDATA/products/v0/{logbook,aggregate,landing,vessel,reference}/ (products/user_tables.R)
#         curated/logbook/{trip,station,catch,catch_flag}.parquet, staging/ops_sigfus/*_monthly.parquet: what each
#         written table is set against
#         products/repository/meta.yml, docs/data-dict.yaml: every column described
# Output: curated/check/user_tables.parquet   one row per check: its rows or kg on each side, and whether it passed
#         $FISHYDATA/products/v0/meta.yml, meta.html   the candidate's metadata, as a release will carry it
#
# Every row of a written table in one outcome, every kilogram once: the user tables leave out the duplicates (decision
# 094) and nothing else. A link into curated/ is the curated file itself, so only that it is there is checked.

source("R/paths.R")
source("R/write_curated.R")
source("R/data_dict.R")
source("R/release.R")
suppressMessages(library(DBI))
Sys.setenv(TZ = "UTC")

V0 <- fd_path("products", "v0")
con <- dbConnect(duckdb::duckdb())
n1 <- function(sql) as.numeric(dbGetQuery(con, sql)[[1]])
pq <- function(p) sprintf("read_parquet('%s')", p)
lb <- function(t) pq(fd_curated("logbook", paste0(t, ".parquet")))
v0 <- function(t) pq(file.path(V0, paste0(t, ".parquet")))
kept <- function(alias) sprintf("(%1$s.twin IS NULL OR %1$s.twin <> 'duplicate')", alias)
checks <- list()
check <- function(name, release, source, tol = 0) {
  checks[[name]] <<- data.frame(check = name, release = release, source = source,
                                pass = isTRUE(abs(release - source) <= tol))
}

# Rows and kilograms -------------------------------------------------------------
check("logbook/trip rows", n1(paste("SELECT count(*) FROM", v0("logbook/trip"))),
      n1(sprintf("SELECT count(*) FROM %s t WHERE %s", lb("trip"), kept("t"))))
check("logbook/station rows", n1(paste("SELECT count(*) FROM", v0("logbook/station"))),
      n1(sprintf("SELECT count(*) FROM %s s WHERE %s", lb("station"), kept("s"))))
kept_catch <- sprintf("FROM %s c JOIN %s s ON s.\".sid\" = c.\".sid\" AND s.schema = c.schema WHERE %s",
                      lb("catch"), lb("station"), kept("s"))
check("logbook/catch rows", n1(paste("SELECT count(*) FROM", v0("logbook/catch"))),
      n1(paste("SELECT count(*) FROM (SELECT DISTINCT c.\".sid\", c.schema, c.sid, c.condition", kept_catch, ")")))
check("logbook/catch kg", n1(paste("SELECT sum(catch) FROM", v0("logbook/catch"))),
      n1(paste("SELECT sum(c.catch)", kept_catch)), tol = 1)
# A flag is a (station, species)'s; a species logged in two states carries it on both rows.
check("logbook/catch flags", n1(sprintf("SELECT count(*) FROM (SELECT DISTINCT \".sid\", schema, sid FROM %s
                                         WHERE flag IS NOT NULL)", v0("logbook/catch"))),
      n1(sprintf("SELECT count(*) FROM %s f JOIN %s s ON s.\".sid\" = f.\".sid\" AND s.schema = f.schema
                  WHERE f.flag <> 'landed_not_logged' AND %s", lb("catch_flag"), lb("station"), kept("s"))))
check("logbook/landed_not_logged rows", n1(paste("SELECT count(*) FROM", v0("logbook/landed_not_logged"))),
      n1(sprintf("SELECT count(*) FROM %s WHERE flag = 'landed_not_logged'", lb("catch_flag"))))
summaries <- pq(fd_staging("ops_sigfus", "*_monthly.parquet"))
aggregate <- sprintf("(SELECT catch FROM %s UNION ALL SELECT catch FROM %s)", v0("aggregate/logged_monthly"),
                     v0("aggregate/nephrops_fleet"))
check("aggregate summary rows", n1(paste("SELECT count(*) FROM", aggregate)), n1(paste("SELECT count(*) FROM", summaries)))
check("aggregate summary kg", n1(paste("SELECT sum(catch) FROM", aggregate)), n1(paste("SELECT sum(catch) FROM", summaries)),
      tol = 1)

# Every table there, every column described, no person's column -------------------------------------------------
files <- .release_files(file.path(V0, RELEASE_FOLDERS))
tables <- unique(.table_of(sub(paste0("^", V0, "/"), "", files)))
expected <- c("logbook/trip", "logbook/station", "logbook/catch", "logbook/landed_not_logged", "logbook/environment",
              "logbook/gear", "logbook/rigging", "logbook/sensor_summary", "logbook/sensor_gps",
              "aggregate/logged_monthly", "aggregate/nephrops_fleet", "aggregate/ices", "landing/landing",
              "landing/catch", "vessel/vessel", "vessel/vessel_year", "reference/species", "reference/gear",
              "reference/port")
check("tables present", length(intersect(expected, tables)), length(expected))
check("tables not expected", length(setdiff(tables, expected)), 0)
undescribed <- release_undescribed(V0)
if (length(undescribed)) message("undescribed:\n", paste(undescribed, collapse = "\n"))
check("columns without a description", length(undescribed), 0)
persons <- tryCatch(check_no_persons(file.path(V0, RELEASE_FOLDERS)), error = function(e) { message(conditionMessage(e)); FALSE })
check("no person's column", as.numeric(isTRUE(persons)), 1)

# The metadata, as a release carries it --------------------------------------------------------------------------
if (!length(undescribed)) {
  meta <- tryCatch(release_meta(V0, file.path("products", "repository", "meta.yml")),
                   error = function(e) { message(conditionMessage(e)); NULL })
  check("meta.yml validate-spec clean", as.numeric(!is.null(meta)), 1)
  if (!is.null(meta)) {
    vd <- .dd_json(.dd_bin(), c("validate-data", meta))
    fails <- sum(vapply(vd$tables %or% list(), \(t) sum(unlist(lapply(t$checks %or% list(),
                                                                       \(c) c$failed_row_count %or% 0))), 0))
    check("meta.yml validate-data failed rows", fails, 0)
  }
}

out <- do.call(rbind, checks)
rownames(out) <- NULL
print(out)
write_curated(out, fd_curated("check", "user_tables.parquet"),
              inputs = c(file.path(V0, "logbook", c("trip.parquet", "station.parquet", "catch.parquet")),
                         file.path(fd_curated("logbook"), c("trip.parquet", "station.parquet", "catch.parquet",
                                                            "catch_flag.parquet"))))
dbDisconnect(con, shutdown = TRUE)
