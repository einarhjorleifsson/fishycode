# all.R — every Oracle schema, one after the other, each with its own log (plan 018, decision 109).
#
# Input:  dump/oracle/<schema>.R
# Output: raw/oracle/<schema>/ for each schema, its log in raw/oracle/<schema>/_logs/, and this run's own log in
#         raw/oracle/_logs/<time>_all.log: the whole sweep under raw/oracle/, so one copy takes it all
#
# Made for the server, where it runs through ROracle (mar::connect_mar(rjdbc = FALSE)) unless told --driver=RJDBC.
# Step by step, from clone to the copy back to the Mac: dump/oracle/README.md.
# From the repo root, with a .Renviron there holding FISHYDATA=/path/to/fishydata, LANG=en_US.UTF-8 and
# FD_DUMP_DRIVER=ROracle:
#   Rscript dump/oracle/all.R --check                                  is this machine ready? dumps nothing
#   nohup Rscript dump/oracle/all.R > /dev/null 2>&1 &                 every schema; leave it
#   nohup Rscript dump/oracle/all.R --resume > /dev/null 2>&1 &        after a failure: picks up where it stopped
#   nohup Rscript dump/oracle/all.R kvoti stk > /dev/null 2>&1 &       some schemas only
# With --resume a schema that finished with nothing failed is skipped, and the others keep every file the driver
# completed (a file cut off mid-write is redone) and dump the rest.
# Follow it with `tail -f $FISHYDATA/raw/oracle/_logs/*_all.log`. When it is done, copy the whole of
# $FISHYDATA/raw/oracle/ to the Mac's raw/oracle_server/ (rsync -a), and compare it there with compare_dumps().
# A $FISHYDATA that does not exist yet, raw/oracle/ and each schema's directory are created. Details in
# run_dump_all() and dump_check() (R/run_dump.R).

args <- commandArgs(trailingOnly = TRUE)
driver <- sub("^--driver=", "", grep("^--driver=", args, value = TRUE))
driver <- if (length(driver)) driver else Sys.getenv("FD_DUMP_DRIVER", "ROracle")
schema <- grep("^--", args, value = TRUE, invert = TRUE)
schema <- if (length(schema)) schema else NULL

root <- Sys.getenv("FISHYDATA")
if (!nzchar(root) && file.exists(".Renviron")) { readRenviron(".Renviron"); root <- Sys.getenv("FISHYDATA") }

for (f in list.files("R", full.names = TRUE)) source(f)

if ("--check" %in% args) {
  ok <- dump_check(schema, driver = driver)
  quit(status = if (isTRUE(ok)) 0 else 1)
}

if (!nzchar(root)) stop("FISHYDATA is not set: add FISHYDATA=/path/to/fishydata to .Renviron", call. = FALSE)
if (!dir.exists(root)) { dir.create(root, recursive = TRUE); message("created ", root) }
run_dump_all(schema, driver = driver, resume = "--resume" %in% args)
