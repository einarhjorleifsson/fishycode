# The Icelandic rows of the two hand-made MarineTraffic match sheets: a dated witness for a few MMSIs, IMOs and call
# signs.
# Side: preprocessing (vessels). See plan 014; plan 028 step 2.
#
# Input:  raw/external/marinetraffic/STK_MARINETRAFFIC_MATCTH.xlsx (1,230 rows) and CS_MARINE_TRAFFIC_MATCH4.xlsx (823)
# Output: staging/marinetraffic/icelandic.parquet - one row per sheet row that is Icelandic, with its `file`
#
# The sheets are STK mobile-ids matched by hand to what MarineTraffic showed (plan 008 §3), mostly foreign vessels.
# reference/vessels/marinetraffic.R reads all of them for the foreign key; here they are a witness for the register
# (plan 028 §3.8), and their mobile-id is kept but not used as a key.
#
# - A row is Icelandic when its call sign starts TF, its MMSI starts 251, or its vid is 1-3699 or 5000-9999.
# - Read as text. `date_recorded` (Excel serials, only in the first workbook) becomes a date; the second has no date.
# - Both workbooks' one sheet is named CS_MARINE_TRAFFIC_MATCH4, so `file` tells them apart. The second is a subset
#   of the first by mobile-id, and its rows repeat here with their own values.

library(dplyr)
library(nanoparquet)

FILES <- c("STK_MARINETRAFFIC_MATCTH.xlsx", "CS_MARINE_TRAFFIC_MATCH4.xlsx")
KEEP <- c("mobileid", "name", "cs", "imo", "mmsi", "class", "date_recorded", "vid", "comment")

# Read ---------------------------------------------------------------------------------------------------------------
read_sheet <- function(f) {
  p <- fd_raw("external", "marinetraffic", f)
  sh <- readxl::excel_sheets(p)
  stopifnot("a workbook has more than one sheet" = length(sh) == 1)
  suppressMessages(readxl::read_excel(p, sheet = sh, col_types = "text")) |> mutate(file = f, sheet = sh)
}
all_rows <- bind_rows(purrr::map(FILES, read_sheet))

# Shape --------------------------------------------------------------------------------------------------------------
out <- all_rows |>
  select(any_of(KEEP), file, sheet) |>
  mutate(across(everything(), trimws),
         mobileid = as.integer(mobileid), vid = as.integer(vid),
         date_recorded = as.Date(as.numeric(date_recorded), origin = "1899-12-30")) |>
  filter(grepl("^TF", toupper(cs)) | grepl("^251", mmsi) | vid %in% c(1:3699, 5000:9999)) |>
  relocate(all_of(KEEP), file, sheet)

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(all(KEEP %in% names(out)), !anyNA(out$mobileid), !anyDuplicated(out[c("file", "mobileid")]))
PERSONAL <- "owner|operator|eigand|eigend|utgerdaradil|útgerðaraðil|kennitala|^kt|_kt|phone|sími|simi|address|heimilisfang"
stopifnot("a personal column is in the output" = !any(grepl(PERSONAL, names(out), ignore.case = TRUE)))

print(knitr::kable(out |> group_by(file) |>
                     summarise(rows = n(), tf_call_sign = sum(grepl("^TF", toupper(cs))), mmsi_251 = sum(grepl("^251", mmsi)),
                               icelandic_vid = sum(vid %in% c(1:3699, 5000:9999)),
                               recorded = paste(unique(na.omit(date_recorded)), collapse = ", "), .groups = "drop") |>
                     left_join(all_rows |> count(file, name = "of"), by = "file"),
                   caption = "staging/marinetraffic/icelandic"))

write_parquet(out, fd_staging("marinetraffic", "icelandic.parquet"))
