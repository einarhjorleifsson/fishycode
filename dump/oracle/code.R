# code — the SQL behind every dumped schema, from Oracle's data dictionary (decision 166).
#
# Input:  Oracle's ALL_OBJECTS, ALL_TAB_COLUMNS, ALL_COL_COMMENTS, ALL_VIEWS, ALL_MVIEWS, ALL_SOURCE, ALL_TRIGGERS,
#         ALL_SYNONYMS and ALL_DEPENDENCIES, for each schema with a dump script that has been dumped
#         (raw/oracle/<schema>/_overview_tables.parquet)
# Output: raw/oracle/<schema>/_code/: <dictionary view>.parquet, the schema's rows as Oracle holds them, and
#         _overview.parquet: per dictionary view, the rows written or the refusal with Oracle's code, and notes; every
#         file stamped as a dump is (fd.dumped). This run's log: raw/oracle/_logs/<time>_code.log
#
# Reads the dictionary only, no table: 1 min 53 s for the 28 schemas on 2026-10-22, most of it the views' and
# triggers' text. The text is LONG, which RJDBC reads and ROracle cannot (dump_oracle_code(), R/dump_oracle.R), so it
# is run on the Mac, where dump_connect() is RJDBC.
# Not a schema dump, so all.R, run_dump() and sync.sh leave it out.
#
# Run from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/code.R              every dumped schema
#   Rscript dump/oracle/code.R adb kvoti    some
# The password comes from the macOS keychain, so it runs in your own terminal, not in Claude's.

for (f in list.files("R", full.names = TRUE)) source(f)

args <- commandArgs(trailingOnly = TRUE)
dirs <- if (length(args)) args else .dump_schemas()
log <- fd_raw("oracle", "_logs", sprintf("%s_code.log", format(Sys.time(), "%Y%m%dT%H%M%S")))
dir.create(dirname(log), showWarnings = FALSE)
say <- function(x) cat(x, if (!grepl("\n$", x)) "\n", file = log, append = TRUE, sep = "")

withCallingHandlers({
  message(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " the SQL behind ", length(dirs), " schemas; log ", log)
  dumped <- file.exists(fd_raw("oracle", dirs, "_overview_tables.parquet"))
  if (any(!dumped)) message("never dumped, so left out: ", paste(dirs[!dumped], collapse = ", "))
  dirs <- dirs[dumped]

  con <- dump_connect()
  if (.oracle_driver(con) == "ROracle")
    message("through ROracle, which cannot fetch a LONG: the text of views, materialized views and triggers will fail")
  ov <- list()
  for (s in dirs) {
    if (!.oracle_alive(con)) con <- dump_connect()
    ov[[s]] <- dump_oracle_code(con, sub("^ops_", "ops$", s), fd_raw("oracle", s, "_code"),
                                script = "dump/oracle/code.R")
  }
  DBI::dbDisconnect(con)

  o <- do.call(rbind, ov)
  w <- stats::reshape(data.frame(schema = o$owner, source = sub("^all_", "", o$source),
                                 n = ifelse(o$status == "written", format(o$rows, big.mark = ",", trim = TRUE),
                                            "failed")),
                      idvar = "schema", timevar = "source", direction = "wide")
  names(w) <- sub("^n[.]", "", names(w))
  message("\nrows per schema and dictionary view (failed: the refusal is in the schema's _code/_overview.parquet)")
  message(paste(utils::capture.output(print(w, row.names = FALSE)), collapse = "\n"))
  message(sprintf("%s done: %d schemas, %d dictionary views read, %d failed", format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                  length(ov), sum(o$status == "written"), sum(o$status == "failed")))
}, message = function(m) say(conditionMessage(m)),
   warning = function(w) say(paste0("Warning: ", conditionMessage(w), "\n")),
   error = function(e) say(paste0("Error: ", conditionMessage(e), "\n")))
