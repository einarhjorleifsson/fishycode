# Trackwell's summary of its picklist of ground names: each name with its haul count and the hauls' extent and mean.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/trackwell/VeiðisvæðiSkipstjóraMeðMeðalStaðsetningu.xlsx, sheet "ISL Veiðisvæði með
#         staðsetningu" (the only sheet)
# Output: staging/ornefni/trackwell_area.parquet - one row per sheet row (1,096), keyed on `row`
#
# Source-shaped, under English names. The position is the mean of the hauls (`lon`, `lat`, basis `derived`), with
# their extent beside it.
# - `name_placeholder`: "Ekkert valið" (nothing chosen), the picklist's default, on 254,662 hauls. The per-haul file
#   (trackwell_haul) leaves those hauls out.
# - The file's name is in decomposed Unicode (NFD), which readxl cannot open, so it is read from a copy.

library(dplyr)

FILE <- list.files(fd_raw("external", "ornefni", "trackwell"), "[.]xlsx$", full.names = TRUE)
stopifnot("one workbook in trackwell/" = length(FILE) == 1)
MAP <- c(name_raw = "nafn", n_haul = "reg_count", lat_max = "max_lat", lat_min = "min_lat", lon_max = "max_lon",
         lon_min = "min_lon", lat = "avg_lat", lon = "avg_lon")

# Read ---------------------------------------------------------------------------------------------------------------
tmp <- tempfile(fileext = ".xlsx")
file.copy(FILE, tmp)
stopifnot(length(readxl::excel_sheets(tmp)) == 1)
raw <- readxl::read_excel(tmp, sheet = 1)
stopifnot("a column is not mapped" = setequal(names(raw), MAP))

# Shape --------------------------------------------------------------------------------------------------------------
out <- raw[unname(MAP)]
names(out) <- names(MAP)
out <- tibble(row = seq_len(nrow(out)), out) |>
  mutate(name = gsub("\\s+", " ", trimws(name_raw)), .after = name_raw) |>
  mutate(n_haul = as.integer(n_haul), name_placeholder = name == "Ekkert valið", source = "trackwell",
         position_basis = "derived", position_kind = "point")

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(nrow(out) == 1096L, !anyNA(out$name), !anyNA(out$lon), all(out$n_haul == raw$reg_count),
          sum(out$name_placeholder) == 1)

print(knitr::kable(tibble(
  rows = nrow(out), names = n_distinct(out$name), hauls = sum(out$n_haul),
  hauls_placeholder = out$n_haul[out$name_placeholder]), caption = "staging/ornefni/trackwell_area"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "trackwell_area.parquet"))
