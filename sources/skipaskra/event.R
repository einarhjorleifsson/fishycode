# The annual ship register's lists of the previous year's registrations and deregistrations, 2004-2022, as printed.
# Side: once (register history). See plan 014; plan 028 step 1; decision 132.
#
# Input:  raw/external/skipaskra/reports/*.pdf          the 19 editions (R/skipaskra_pdf.R reads them)
# Output: staging/skipaskra/event.parquet               one row per listed registration or deregistration
#         staging/skipaskra/event_total.parquet         the totals each list prints, for the checks
#
# The edition of year Y lists the events of year Y-1. A registration is a first registration (`subkind` first), a
# re-registration (re), or a hull moved between the decked and open sections; 2010 onward print one list of both
# kinds, marked by `remark` or not at all. A deregistration carries its date and its fate in words (sold abroad,
# scrapped, sank, burned). 2006 prints no lists (its first pages are images of the summaries). A list may be shorter
# than the total it prints (2016: 36 rows, "Fjöldi: 44"): kept as printed, a finding for the checks.

library(dplyr)
library(nanoparquet)

eds <- sk_editions()
res <- lapply(seq_len(nrow(eds)), function(i) sk_parse_events(eds$file[i], eds$edition[i]))
ev  <- bind_rows(lapply(res, `[[`, "events"))
tot <- bind_rows(lapply(res, `[[`, "totals"))

# 2008 prints its page of new decked ships twice: an exact repeat is kept once
n0 <- nrow(ev)
ev <- ev |> distinct(edition, kind, subkind, section, sknr, name, date, gt, fate, .keep_all = TRUE)
message(n0 - nrow(ev), " rows printed twice dropped")

parse_date <- function(s) as.Date(sub("\\.$", "", s), format = "%d.%m.%Y")

ev <- ev |>
  mutate(vid = suppressWarnings(as.integer(sknr)),
         date_printed = date,
         date = parse_date(date),
         last_rereg = parse_date(last_rereg),
         gt = sk_num(gt),
         subkind = ifelse(is.na(subkind) & grepl("^Endurskr", ifelse(is.na(remark), "", remark)), "re", subkind)) |>
  select(edition, page, y, kind, subkind, section, vid, sknr, name, district, home_port, date, date_printed,
         last_rereg, deck_code, gt, fate, remark, n_lines) |>
  arrange(edition, kind, vid)

tot <- tot |>
  filter(grepl("^(Samtals|Fjöldi|Heildarfjöldi|[0-9])", trimws(text)), grepl("(skip|bát|opn|^Fjöldi: ?[0-9]+$)", text)) |>
  mutate(printed = suppressWarnings(as.integer(sub("^\\D*?([0-9]+).*$", "\\1", gsub("(?<=[0-9])\\.(?=[0-9]{3})", "", text, perl = TRUE)))))

stopifnot(!anyNA(ev$vid), !anyNA(ev$kind))
print(ev |> count(edition, kind) |> tidyr::pivot_wider(names_from = kind, values_from = n, values_fill = 0) |>
        knitr::kable(caption = "event: rows per edition"))
message(sum(is.na(ev$date) & !is.na(ev$date_printed)), " printed dates did not parse; ",
        sum(ev$kind == "deregistration" & is.na(ev$fate)), " deregistrations print no fate")

write_parquet(ev, fd_staging("skipaskra", "event.parquet"))
write_parquet(tot, fd_staging("skipaskra", "event_total.parquet"))
