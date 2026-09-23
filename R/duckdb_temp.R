# duckdb_temp.R — work around duckdbfs's own connection default.
#
# duckdbfs::cached_connection() configures `temp_directory = tempfile()` — a
# name that does not exist as a directory yet, and DuckDB does not reliably
# create it on demand: the first query in a session big enough to spill to
# disk fails with
#   IO Error: Failed to create directory ".../duckdb/temp": No such file or directory
# First hit on the `stk` target (2026-09-23) — the earlier reference/harbour
# targets never spill, so this only surfaces once the AIS chain runs.
#
# Deliberately a FUNCTION, not a top-level assignment in _targets.R: an
# earlier version did `duckdb_temp_dir <- file.path(tempdir(), ...)` as a
# bare global, and tempdir() is a fresh, random path every R session -
# targets' pipeline-environment tracking picked that up as churn, so
# `logbook`/`lid_map`/`logbook_sensor_gps`/`trip_voyage` looked outdated on
# every invocation regardless of whether anything had actually changed,
# costing a real ~13-minute rebuild each time. A function's tracked identity
# is its (unchanging) body, not a value computed when it happens to run -
# the same reason this file lives in R/ rather than being top-level code in
# it (see this repo's own rule about R/oracle.R at the top of AGENTS.md's
# layout table).
configure_duckdb_temp <- function() {
  dir <- file.path(tempdir(), "duckdb_temp")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  DBI::dbExecute(duckdbfs::cached_connection(), sprintf("SET temp_directory = '%s';", dir))
  invisible(dir)
}
