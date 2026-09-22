# Faroese vessel registry, scraped a page at a time from teyggjan.fo.
#
# Input:  https://www.teyggjan.fo/Pages/Ship/Details.aspx?shipId=<20001..40000>
# Output: raw/vessels/faroe/vid-NNNN.csv   (one file per ship that has a table)
#
# Moved here from reference/vessels/ on 2026-09-22: it is a web fetch, which by the
# layout table in AGENTS.md belongs in dump/, and it was writing CSVs to a relative
# path inside the repo rather than through fd_raw().
#
# 20,000 requests at Sys.sleep(2) is roughly 11 hours. Run it deliberately:
#   nohup Rscript -e 'source("R/paths.R"); source("dump/vessels/faroe.R")' --vanilla \
#     > faroe_$(date +%F).log 2>&1 &
#
# Nothing consumes the output yet - the cross-flag vessel consolidation it feeds was
# not carried across from fishyweb. See curate/plans/002-the-last-mile.md §4a.
library(tidyverse)
library(rvest)

out_dir <- fd_raw("vessels", "faroe")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for(v in 20001:40000) {
  print(v)
  url <- paste0("https://www.teyggjan.fo/Pages/Ship/Details.aspx?shipId=", v)
  page <-
    tryCatch(
      url %>%
        read_html(),
      error = function(e){NA}    # a function that returns NA regardless of what it's passed
    )
  if(!is.na(page)) {
    #print(v)
    tables <-
      page |>
      html_nodes("table") |>
      html_table(convert = FALSE)

    if(nrow(tables[[2]]) > 1) {

      tables[c(2, 4)] |>
        bind_rows() |>
        rename(variable = 1,
               value = 2) |>
        mutate(vid_id = v) |>
        mutate(variable = as.character(variable),
               variable = str_replace(variable, ",", "."),
               value = as.character(value),
               value = str_replace(value, ",", ".")) |>
        write_csv(file.path(out_dir, paste0("vid-", str_pad(v, side = "left", pad = "0", width = 4), ".csv")))
      Sys.sleep(2)
    }
  }
}

