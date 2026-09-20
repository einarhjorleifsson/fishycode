library(mar)
con <- connect_mar()
library(tidyverse)
library(nanoparquet)


# tbl_mar(con, "afli.ra_email_skeyti") |> collect() -> d
# # creates an error d |> write_parquet("testo.parquet")

OUT_DIR <- "data-dump/vessels"
SCHEMA <- "vessel"
get_tables_and_views <- function(con, owner) {
  bind_rows(mar_tables(con, owner) |> collect() |>
              rename(name = table_name) |>
              mutate(type = "table"),
            mar_views(con, owner) |> collect() |>
              rename(name = view_name) |>
              mutate(type = "view"))
}
get_fields <- function(schema.table) {
  mar_fields(con, schema.table) |>
    collect() |>
    rename(table = table_name,
           column = column_name)
}


ov <- get_tables_and_views(con, SCHEMA)
ov |> write_parquet(paste0(OUT_DIR, "/", "_overview_tables.parquet"))

ov |>
  unite(owner, name, col = name, sep = ".") |>
  pull(name) |>
  purrr::map_df(get_fields) |>
  write_parquet(paste0(OUT_DIR, "/", "_overview_fields.parquet"))

for(i in 1:nrow(ov)) {
  table <- paste0(ov$owner[i], ".", ov$name[i])
  result <-
    try(tbl_mar(con, table) |> collect(),
        silent = FALSE)

  if (class(result)[1] == "try-error") {
    print(paste0("An error reading:", table))
    #print(geterrmessage())
  } else {
    print(table)
    if(!table %in% "afli.ra_email_skeyti") {
      result |>
        write_parquet(paste0(OUT_DIR,
                             "/",
                             str_remove(table,
                                        paste0(SCHEMA, ".")),
                             ".parquet"))
    }
  }
}
