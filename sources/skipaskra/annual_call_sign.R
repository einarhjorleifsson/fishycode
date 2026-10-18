# The annual ship register (Skipaskrá): the call sign each registered vessel carried in each year.
# Side: once (vessel key). See plan 014.
#
# Input:  raw/external/skipaskra/data-raw/skipaskra_tabulized_matrix_{2018,2019,2020,2021_2022}.rds
#         raw/external/skipaskra/data/skipaskra_2009-2017_almost-tidy.rds
#         raw/external/skipaskra/reports/Vefskipaskra-{2007,2008}.pdf (via pdftotext -layout)
# Output: staging/skipaskra/annual_call_sign.parquet - one row per (year, vid, cs)
#
# A call sign has ONE holder at a time, and this is the only source that says WHICH, per year, over the
# STK era: the registry's own dated call-sign history starts 2023-12-19 (decision 047, 049). Only vessels
# that carry a call sign appear (~370-400 a year).
#
# A year here is the register's state at the START of that year (~YEAR-01-01), not YEAR-12-31: no hull registered
# in 2008-2022 is listed in the year it was registered, nearly all the year after (asserted in
# curate/checks/ais_key_segments.R).
#
# Three layouts, three routes (`form` records which):
#   tidy    2009-2017  the maintainer's almost-tidy table (vid, cs columns);
#   matrix  2018-2022  the page matrices: the vid is the number that opens the call sign's row;
#   pdf     2007-2008  the printed register; each entry is a line starting with the registration number
#                      (Sknr.) and the next line carries class then call sign.
# 2004-2006 (card layout in the PDFs) are not read: the STK starts in 2007.
#
# No vessel name is read. The matrix 2004-2008 is NOT used: its card pages clip the registration number.

library(dplyr)
library(nanoparquet)

SK <- fd_raw("external", "skipaskra")

tidy <- readRDS(file.path(SK, "data", "skipaskra_2009-2017_almost-tidy.rds")) |>
  transmute(year = as.integer(year), vid = suppressWarnings(as.integer(vid)), cs = toupper(trimws(cs))) |>
  filter(!is.na(vid), grepl("^TF[A-Z]{2}$", cs)) |> mutate(form = "tidy")

# The registration number opens the row: alone in the first cell, or fused with the name ("5935 Selur I", most
# of 2022). The first bare 1-4 digit cell is NOT it where the number is fused: it is the build year (TFBS read as
# vid 1998, 17 rows in 2019-2022). The legend page's sample entry ("5. | Kallmerki | TFGH | ... | 431") opens with
# no number and is dropped.
matrix_cs <- function(file) {
  d <- readRDS(file); out <- list()
  for (yi in seq_along(d)) {
    yr <- suppressWarnings(as.integer(names(d)[yi]))
    for (m in d[[yi]]) {
      if (!is.matrix(m) || ncol(m) < 3) next
      hit <- which(matrix(grepl("^TF[A-Z]{2}$", m), nrow(m)), arr.ind = TRUE)
      for (k in seq_len(nrow(hit))) {
        row <- trimws(m[hit[k, 1], ]); first <- row[!is.na(row) & nzchar(row)][1]
        out[[length(out) + 1]] <- tibble(year = yr, vid = if (grepl("^[0-9]{1,4}(\\s|$)", first))
                                           as.integer(sub("^([0-9]{1,4}).*$", "\\1", first)) else NA_integer_,
                                         cs = m[hit[k, 1], hit[k, 2]])
      }
    }
  }
  bind_rows(out)
}
mat <- bind_rows(lapply(c("2018", "2019", "2020", "2021_2022"), function(f)
  matrix_cs(file.path(SK, "data-raw", paste0("skipaskra_tabulized_matrix_", f, ".rds")))))
message(sum(is.na(mat$vid)), " matrix call-sign rows open with no registration number (the legend's sample entry) and are dropped")
mat <- mat |> filter(!is.na(vid), !is.na(year)) |> mutate(form = "matrix")

pdf_cs <- function(file, year) {
  x <- system2("pdftotext", c("-layout", shQuote(file), "-"), stdout = TRUE)
  head <- grepl("^[0-9]{1,4} +\\S", x)
  nxt <- c(x[-1], "")
  cs <- sub("^\\s+\\S+\\s+(TF[A-Z]{2})\\s.*$", "\\1", nxt)
  ok <- head & grepl("^\\s+\\S+\\s+TF[A-Z]{2}\\s", nxt)
  tibble(year = year, vid = as.integer(sub("^([0-9]{1,4}) .*", "\\1", x[ok])), cs = cs[ok], form = "pdf")
}
pdf <- bind_rows(pdf_cs(file.path(SK, "reports", "Vefskipaskra-2007.pdf"), 2007L),
                 pdf_cs(file.path(SK, "reports", "Vefskipaskra-2008.pdf"), 2008L))

out <- bind_rows(pdf, tidy, mat) |> distinct(year, vid, cs, .keep_all = TRUE) |> arrange(year, vid)

# One holder per call sign per year is the register's own invariant; report, do not repair
dup <- out |> count(year, cs) |> filter(n > 1)
print(out |> group_by(year, form) |> summarise(vessels = n_distinct(vid), call_signs = n_distinct(cs), .groups = "drop") |>
        knitr::kable(caption = "annual_call_sign"))
message(nrow(dup), " (year, call sign) pairs have more than one vid")

write_parquet(out, fd_staging("skipaskra", "annual_call_sign.parquet"))
