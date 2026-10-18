# The annual ship register's lists after the register (2004-2013) and its summary tables (2004-2022), as printed.
# Side: preprocessing (vessels). See plan 014; plan 028 step 1.
#
# Input:  raw/external/skipaskra/reports/*.pdf          the 19 editions (R/skipaskra_pdf.R reads them)
# Output: staging/skipaskra/draught.parquet             draught, dimensions and weight by number, 2004-2006
#         staging/skipaskra/index_list.parquet          the vessels by registration number and by call sign, 2004-2013
#         staging/skipaskra/summary.parquet             the preface's tables by year (counts and tonnage), 2004-2022
#         staging/skipaskra/name_prerogative.parquet    the names reserved for a holder, with holder (and kennitala,
#                                                       2013-2015), 2004-2022
#
# These repeat the register in another order, or sum it, so they serve the checks (plan 028 §5.1): every number in the
# register and in its list, every call sign once, the counts the preface prints against the entries. The draught
# table is the only source of weight and light draught. The call-sign list holds every sign of the TF block, held
# or free. The name prerogative is read since the maintainer's rule of 2026-10-18 keeps what a public source prints,
# holders' names and kennitala included, under $FISHYDATA only (decision 130). Not read: the district list, which
# repeats the register.

library(dplyr)
library(nanoparquet)

eds <- sk_editions()

li <- bind_rows(lapply(which(eds$edition <= 2013), function(i) sk_parse_lists(eds$file[i], eds$edition[i])))
n0 <- nrow(li)
li <- li |> distinct(edition, list, key, name, district, length, breadth, weight, draft_light, draft_loaded, .keep_all = TRUE)
message(n0 - nrow(li), " list rows printed twice dropped")

draught <- li |>
  filter(list == "draught") |>
  transmute(edition, page, vid = as.integer(key), length = sk_num(length), breadth = sk_num(breadth),
            weight = sk_num(weight), draft_light = sk_num(draft_light), draft_loaded = sk_num(draft_loaded)) |>
  arrange(edition, vid)

index_list <- li |>
  filter(list != "draught") |>
  transmute(edition, page, list, key, vid = ifelse(list == "number", suppressWarnings(as.integer(key)), NA_integer_),
            call_sign = ifelse(list == "call_sign", key, NA_character_), name, district) |>
  arrange(edition, list, key)

summ <- bind_rows(lapply(seq_len(nrow(eds)), function(i) sk_parse_summary(eds$file[i], eds$edition[i]))) |>
  mutate(value = sk_num(printed))

pre <- bind_rows(lapply(seq_len(nrow(eds)), function(i) sk_parse_prerogative(eds$file[i], eds$edition[i])))

stopifnot(!anyNA(draught$vid), !anyNA(index_list$key), !anyNA(pre$name))
print(index_list |> count(edition, list) |> tidyr::pivot_wider(names_from = list, values_from = n, values_fill = 0) |>
        left_join(draught |> count(edition, name = "draught"), by = "edition") |>
        full_join(pre |> count(edition, name = "prerogative"), by = "edition") |> arrange(edition) |>
        knitr::kable(caption = "lists: rows per edition"))
message(nrow(summ), " summary cells from ", n_distinct(paste(summ$edition, summ$table)), " tables")

write_parquet(draught, fd_staging("skipaskra", "draught.parquet"))
write_parquet(index_list, fd_staging("skipaskra", "index_list.parquet"))
write_parquet(summ, fd_staging("skipaskra", "summary.parquet"))
write_parquet(pre, fd_staging("skipaskra", "name_prerogative.parquet"))
