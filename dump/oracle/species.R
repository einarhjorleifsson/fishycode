library(nanoparquet)
library(tidyverse)
library(omar)
con <- connect_mar()


tbl_mar(con, "asfis.asfis") |>
  collect() |>
  write_parquet(fd_staging("data-dump", "species", "asfis.parquet"))
