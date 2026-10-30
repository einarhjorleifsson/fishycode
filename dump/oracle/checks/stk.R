# stk's read-only checks against Oracle: decision 196's three reads on the trail (its sequence, when its trigger and
# sequence were made, and its rows), the rows also by year to set the trail's overview row right (TODO 110).
#
# Input:  Oracle ALL_SEQUENCES, ALL_OBJECTS and ALL_TRIGGERS for the owner STK; stk.trail
# Output: raw/oracle/stk/_checks/sequences.parquet   STK's sequences, with their last number
#         raw/oracle/stk/_checks/objects.parquet     STK's triggers and sequences, with when each was created and changed
#         raw/oracle/stk/_checks/triggers.parquet    the triggers on stk.trail, without their bodies
#         raw/oracle/stk/_checks/trail_rows.parquet  stk.trail's rows by year of posdate, as the dump partitions it
#         each stamped as a dump is (fd.dumped, fd.driver, fd.commit)
#
# Run by hand from the repo root, with a connection to the MFRI Oracle database (plan 054 §7, the Oracle sitting):
#   Rscript dump/oracle/checks/stk.R
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.
#
# Decision 196 (TODO 117): the trail's order is its receipt order, and these reads date the sequence and trigger that
# number it. The count scans stk.trail once (about 304 M rows in the dump).

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
run <- .dump_run(con, "dump/oracle/checks/stk.R")
out <- fd_raw("oracle", "stk", "_checks")
get <- function(sql, file, what) {
  d <- DBI::dbGetQuery(con, sql)
  names(d) <- tolower(names(d))
  .write_raw(d, file.path(out, file), what, run)
  message(sprintf("%s: %d rows", what, nrow(d)))
  invisible(d)
}

get("SELECT sequence_owner, sequence_name, min_value, max_value, increment_by, cycle_flag, order_flag, cache_size,
            last_number
     FROM all_sequences WHERE sequence_owner = 'STK'",
    "sequences.parquet", "STK's sequences (decision 196)")
get("SELECT owner, object_name, object_type, created, last_ddl_time, status
     FROM all_objects WHERE owner = 'STK' AND object_type IN ('TRIGGER', 'SEQUENCE')",
    "objects.parquet", "STK's triggers and sequences (decision 196)")
get("SELECT owner, trigger_name, trigger_type, triggering_event, table_name, status, description
     FROM all_triggers WHERE table_owner = 'STK' AND table_name = 'TRAIL'",
    "triggers.parquet", "the triggers on stk.trail (decision 196)")
rows <- get("SELECT EXTRACT(YEAR FROM posdate) AS year, COUNT(*) AS n FROM stk.trail
             GROUP BY EXTRACT(YEAR FROM posdate) ORDER BY 1",
            "trail_rows.parquet", "stk.trail: rows by year of posdate (decision 196, TODO 110)")
message(sprintf("stk.trail: %s rows", format(sum(rows$n), big.mark = ",")))

DBI::dbDisconnect(con)
