# Trackwell's ground names per haul: its own copy of its logbook app's hauls, delivered in November 2022.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/trackwell/trackwell_2022-11-07.csv (and the 2022-11-03 file, checked, not staged)
# Output: staging/ornefni/trackwell_haul.parquet - one row per file row (484,734), keyed on `row`
#
# Source-shaped: the name as written (`name_raw`) beside `name` (spaces trimmed and squeezed), the vessel, the haul's start
# and end (`t1`, `t2`, to the minute), positions and depths (`z1`, `z2`, metres to two decimals) as Trackwell wrote
# them. No link to the logbook here: 92 % of the rows are curated logbook hauls by vid and start minute, but the names
# go on no haul (the maintainer, 2026-10-24).
# - The file has no header: ";" between fields, a decimal comma, a byte-order mark, names in double quotes.
# - The vessel field holds a vid (Icelandic vessels), a call sign (Faroese and Danish, OY../OW.., 6,077 rows) or a
#   colour (Red, Orange, White, Yellow: 186 rows, around and south of the Faroes; what they are is not known). Kept as
#   written in `vessel_raw`, and split into `vid`, `call_sign` and `vessel_other`.
# - `name_placeholder`: "FROM SHIP", a value the app wrote, not a place. The picklist's default "Ekkert valið"
#   (nothing chosen) is not in the file at all (decision 221).
# - `time_suspect`: a start outside 2003-2022 (29 rows: 4 dated 2000, 12 in 2095, 13 in 2099).
# - The names are noisy: skippers often switch name late in a new area (plan 043 §3.1). Kept as given.
# - The 2022-11-03 file is the same hauls without vid, time or depth: 484,289 of its 484,306 named rows are in this
#   file. Its rows are counted below and it stays in raw.

library(dplyr)

FILE  <- fd_raw("external", "ornefni", "trackwell", "trackwell_2022-11-07.csv")
FILE0 <- fd_raw("external", "ornefni", "trackwell", "trackwell_2022-11-03.csv")
COLOURS <- c("Red", "Orange", "White", "Yellow")
squeeze <- function(x) gsub("\\s+", " ", trimws(x))
read_tw <- function(f) read.table(f, sep = ";", dec = ",", quote = "\"", comment.char = "", fill = TRUE,
                                  colClasses = "character", encoding = "UTF-8", fileEncoding = "UTF-8-BOM")
num <- function(x) as.numeric(sub(",", ".", x, fixed = TRUE))

# Read ---------------------------------------------------------------------------------------------------------------
raw <- read_tw(FILE)
stopifnot("the 2022-11-07 file has 10 fields" = ncol(raw) == 10, nrow(raw) == length(readLines(FILE)))
names(raw) <- c("name", "vid", "lat1", "lon1", "t1", "z1", "lat2", "lon2", "t2", "z2")

# Shape --------------------------------------------------------------------------------------------------------------
out <- tibble(
  row = seq_len(nrow(raw)), name_raw = raw$name, name = squeeze(raw$name),
  vessel_raw = raw$vid,
  vid = suppressWarnings(as.integer(ifelse(grepl("^[0-9]+$", raw$vid), raw$vid, NA))),
  call_sign = ifelse(grepl("^[A-Z]{4}$", raw$vid), raw$vid, NA_character_),
  vessel_other = ifelse(raw$vid %in% COLOURS, raw$vid, NA_character_),
  t1 = as.POSIXct(substr(raw$t1, 1, 19), format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
  t2 = as.POSIXct(substr(raw$t2, 1, 19), format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
  lon1 = num(raw$lon1), lat1 = num(raw$lat1), lon2 = num(raw$lon2), lat2 = num(raw$lat2),
  z1 = num(raw$z1), z2 = num(raw$z2)) |>
  mutate(name_placeholder = name == "FROM SHIP",
         time_suspect = is.na(t1) | !between(as.integer(format(t1, "%Y")), 2003L, 2022L),
         source = "trackwell", position_basis = if_else(is.na(lon1) | is.na(lat1), "none", "recorded"),
         position_kind = "track")

# Check and write ----------------------------------------------------------------------------------------------------
stopifnot(nrow(out) == 484734L,
          "the vessel field is a vid, a call sign or a known colour" =
            all(xor(xor(!is.na(out$vid), !is.na(out$call_sign)), !is.na(out$vessel_other))),
          "every time parses" = !anyNA(out$t1) && !anyNA(out$t2), !any(out$name == ""))

# The 2022-11-03 file, row by row: in this file, NULL name, or neither.
old <- read_tw(FILE0)
stopifnot(ncol(old) == 5, nrow(old) == 485154L)
key <- function(n, a, b, c, d) paste(squeeze(n), round(num(a), 5), round(num(b), 5), round(num(c), 5), round(num(d), 5))
k_new <- key(raw$name, raw$lat1, raw$lon1, raw$lat2, raw$lon2)
k_old <- key(old[[1]], old[[2]], old[[3]], old[[4]], old[[5]])
outcome <- ifelse(squeeze(old[[1]]) == "NULL", "name NULL", ifelse(k_old %in% k_new, "in 2022-11-07", "not found"))
print(knitr::kable(as.data.frame(table(outcome)), caption = "trackwell_2022-11-03.csv, each row"))

print(knitr::kable(tibble(
  rows = nrow(out), vessels = n_distinct(out$vessel_raw), vids = n_distinct(out$vid, na.rm = TRUE),
  call_sign_rows = sum(!is.na(out$call_sign)), colour_rows = sum(!is.na(out$vessel_other)), names = n_distinct(out$name),
  years = paste(range(format(out$t1[!out$time_suspect], "%Y")), collapse = "-"), time_suspect = sum(out$time_suspect),
  from_ship = sum(out$name_placeholder), no_position = sum(out$position_basis == "none"),
  name_trimmed = sum(out$name != out$name_raw)), caption = "staging/ornefni/trackwell_haul"))

write_parquet_group(out, fd_staging("ornefni", "trackwell_haul.parquet"))
