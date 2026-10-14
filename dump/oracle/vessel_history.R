# Fiskistofa's dated vessel history, the source of the fisheries-management class over time (plan 016 §7 h).
#
# Input:  Oracle kvoti.skipasaga (what omar::vessel_history() reads; ~/stasi/skipaskra/data/history.rda is a 2021 extract
#         of it, reduced to one row per class change) and the list of kvoti's tables and views
# Output: raw/vessels/kvoti_skipasaga.parquet   every row and column, as Oracle returns it
#         raw/vessels/kvoti_overview.parquet    kvoti's tables and views, to find the class-name lookup
#
# Run by hand, with a connection to the MFRI Oracle database. Nothing is cleaned here (the rjdbc driver returns integer
# columns as doubles; the reader casts).

library(mar)
library(dplyr)
library(nanoparquet)

con <- connect_mar(rjdbc = TRUE)

bind_rows(mar_tables(con, "kvoti") |> collect() |> rename(name = table_name) |> mutate(type = "table"),
          mar_views(con, "kvoti") |> collect() |> rename(name = view_name) |> mutate(type = "view")) |>
  write_parquet(fd_raw("vessels", "kvoti_overview.parquet"))

d <- tbl_mar(con, "kvoti.skipasaga") |> collect()
write_parquet(d, fd_raw("vessels", "kvoti_skipasaga.parquet"))
cat("kvoti.skipasaga:", nrow(d), "rows,", ncol(d), "columns\n")
