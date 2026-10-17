# catalogue — every table and view the account can see in MFRI's Oracle, from the data dictionary alone.
#
# Input:  Oracle's ALL_TABLES, ALL_VIEWS, ALL_TAB_COMMENTS, ALL_TAB_COLUMNS, ALL_USERS
# Output: raw/oracle/_catalogue/objects.parquet: one row per table and view, with Oracle's comment, row estimate
#         (tables), number of columns, and whether the schema is Oracle's own; stamped as a dump is (fd.dumped)
#
# Reads no table, so it takes about a minute. For choosing what to dump (oracle_catalogue(), R/dump_oracle.R): which
# schemas exist, how big they are, and which have a script in dump/oracle/. Not a schema dump, so all.R, run_dump()
# and sync.sh leave it out.
#
# Run from the repo root, with a connection to the MFRI Oracle database:
#   Rscript dump/oracle/catalogue.R

for (f in list.files("R", full.names = TRUE)) source(f)

con <- dump_connect()
run <- .dump_run(con, "dump/oracle/catalogue.R")
d <- oracle_catalogue(con)
DBI::dbDisconnect(con)
.write_raw(d, fd_raw("oracle", "_catalogue", "objects.parquet"), "oracle catalogue", run)

s <- d |>
  dplyr::filter(!oracle_maintained %in% TRUE) |>
  dplyr::summarise(tables = sum(type == "table"), views = sum(type == "view"),
                   rows = sum(num_rows, na.rm = TRUE), .by = owner) |>
  dplyr::mutate(script = sub("[$]", "_", owner) %in% .dump_schemas()) |>
  dplyr::arrange(dplyr::desc(rows))
message(sprintf("%d objects in %d schemas (%d not Oracle's own), %d with a dump script",
                nrow(d), dplyr::n_distinct(d$owner), nrow(s), sum(s$script)))
print(as.data.frame(s), row.names = FALSE)
