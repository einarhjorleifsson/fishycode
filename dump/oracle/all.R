# all.R — every Oracle schema, one after the other, each with its own log (plan 018, decision 109).
#
# Input:  dump/oracle/<schema>.R
# Output: raw/oracle/<schema>/ for each schema, its log in raw/oracle/<schema>/_logs/, and this run's own log in
#         raw/oracle/_logs/<time>_all.log: the whole sweep under raw/oracle/, so one copy takes it all
#
# Made for the server: from the repo root, with $FISHYDATA set (the repo's .Renviron or ~/.Renviron), start it and
# leave it:
#   nohup Rscript dump/oracle/all.R --driver=ROracle > /dev/null 2>&1 &
#   nohup Rscript dump/oracle/all.R --driver=ROracle kvoti stk > /dev/null 2>&1 &     some schemas only
#   nohup Rscript dump/oracle/all.R --driver=ROracle --resume > /dev/null 2>&1 &      after a failure: picks up
# With --resume a schema that finished with nothing failed is skipped, and the others keep every file the driver
# completed (a file cut off mid-write is redone) and dump the rest.
# Follow it with `tail -f $FISHYDATA/raw/oracle/_logs/*_all.log`, or dump_status() in R. A $FISHYDATA that does not
# exist yet, raw/oracle/ and each schema's directory are created. Details in run_dump_all() (R/run_dump.R).

args <- commandArgs(trailingOnly = TRUE)
driver <- sub("^--driver=", "", grep("^--driver=", args, value = TRUE))
schema <- grep("^--", args, value = TRUE, invert = TRUE)

root <- Sys.getenv("FISHYDATA")
if (!nzchar(root) && file.exists(".Renviron")) { readRenviron(".Renviron"); root <- Sys.getenv("FISHYDATA") }
if (!nzchar(root)) stop("FISHYDATA is not set: add FISHYDATA=/path/to/fishydata to .Renviron", call. = FALSE)
if (!dir.exists(root)) { dir.create(root, recursive = TRUE); message("created ", root) }

for (f in list.files("R", full.names = TRUE)) source(f)

run_dump_all(if (length(schema)) schema else NULL, driver = if (length(driver)) driver else NULL,
             resume = "--resume" %in% args)
