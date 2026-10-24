# A person's plotter marks (TimeZero): every waypoint in the GPX exports and every object in the TimeZero export.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/fra_gudmundi-a-bjarna/: every .gpx, and the TimeZero objects
#         GS_nofn-og-flok_2022-10-18/{Nöfn, Nöfn og flök}/UserObjects.json
# Output: staging/ornefni/plotter_mark.parquet - one row per mark per file, keyed on (`file`, `mark`)
#
# Source-shaped: the name and comment as written (`name_raw`, `comment_raw`) beside trimmed copies, the time, the
# position, the plotter's symbol and colour; for TimeZero objects also their type, guid, layer, deletion flag and
# modification time. A mark in several files is a row in each.
# - The three large GPX files lost the Icelandic letters: "?" stands in their place. `text_lost` flags a "?" in the
#   name, `comment_text_lost` in the comment. The TimeZero export (2021) keeps the letters (ask c of plan 043).
# - `name_is_number`: a name that is a number, with or without a unit (depths or marks rather than names).
# - `time_placeholder`: dated 1984-12-31, the plotter's date for a mark with none set (49,348 marks).
#   `time_suspect`: any other time before 1985 or after 2022-11-10, the last delivery (8,284 marks, to 2033).
# - TimeZero's geometry, decoded here and verified on the 191 marks of the same name in `nofn og flok.gpx` (within
#   0.58 m): one type byte (01), then x and y as big-endian 32-bit integers in centimetres of World Mercator
#   (EPSG:3395), then four bytes of zeros. Five named marks of 9 bytes start with 00 and are read the same way; no GPX
#   copy checks them, but Gígurinn falls where Trackwell's tows of that name centre. Every object's geometry is kept as
#   written in `geometry_raw` (base64), `geometry_decoded` says which were read. Not decoded, so with no position: 7 unnamed objects of type 3 (first byte 04) and 5 longer geometries of types 4 and 8
#   (first byte 02, lines or areas). Times are seconds since 2000-01-01 UTC, verified on the same 191 marks.
# - The GPX files with tracks only (austurhluti 2, vesturhluti 2, older/vesturhluti 2) hold no marks: plotter_track.
# - The .tzx files and the delivery's zip hold the same objects and are not read again.

library(dplyr)

DIR <- fd_raw("external", "ornefni", "fra_gudmundi-a-bjarna")
GPX <- sort(list.files(DIR, "[.]gpx$", recursive = TRUE), method = "radix")
TZX <- file.path("GS_nofn-og-flok_2022-10-18", c("Nöfn", "Nöfn og flök"), "UserObjects.json")
LAST <- as.POSIXct("2022-11-10 23:59:59", tz = "UTC")
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }
is_number <- function(x) grepl("^[+-]?[0-9]+([.,][0-9]+)?\\s*(fa|f|fm|m)?[.]?$", trimws(x), ignore.case = TRUE)

# GPX ----------------------------------------------------------------------------------------------------------------
gpx <- bind_rows(lapply(GPX, function(f) {
  m <- read_gpx_marks(file.path(DIR, f))
  if (!nrow(m)) return(NULL)
  tibble(file = f, format = "gpx", mark = m$mark, name_raw = m$name, comment_raw = m$cmt,
         time = as.POSIXct(substr(m$time_txt, 1, 19), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
         lon = m$lon, lat = m$lat, symbol = m$symbol, colour = m$colour)
}))

# TimeZero -----------------------------------------------------------------------------------------------------------
tz_point <- function(b64) {
  b <- lapply(b64, jsonlite::base64_dec)
  pt <- lengths(b) %in% c(9L, 13L) & vapply(b, function(v) length(v) > 0 && v[1] %in% as.raw(0:1), TRUE)
  xy <- t(vapply(seq_along(b), function(i) if (pt[i]) c(readBin(b[[i]][2:5], "integer", size = 4, endian = "big"),
                                                       readBin(b[[i]][6:9], "integer", size = 4, endian = "big"))
                 else c(NA_integer_, NA_integer_), integer(2))) / 100
  ll <- matrix(NA_real_, length(b), 2)
  if (any(pt)) ll[pt, ] <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(data.frame(x = xy[pt, 1], y = xy[pt, 2]), coords = c("x", "y"), crs = 3395), 4326))
  list(lon = ll[, 1], lat = ll[, 2], decoded = pt)
}
tzx <- bind_rows(lapply(TZX, function(f) {
  txt <- paste(readLines(file.path(DIR, f), warn = FALSE, encoding = "UTF-8"), collapse = "")
  o <- jsonlite::stream_in(textConnection(gsub('}{"Object"', '}\n{"Object"', txt, fixed = TRUE)), verbose = FALSE)$Object
  p <- tz_point(o$Geometry)
  tibble(file = f, format = "tzx", mark = seq_len(nrow(o)), name_raw = o$Name, comment_raw = o$Comment,
         time = as.POSIXct(o$CreationDate, origin = "2000-01-01", tz = "UTC"), lon = p$lon, lat = p$lat,
         symbol = as.integer(o$Icon), colour = as.integer(o$Color), object_type = as.integer(o$ObjectType),
         guid = o$Guid, layer_guid = o$UserLayerGuid, deleted = o$Deleted == 1,
         time_modified = as.POSIXct(o$LastModificationDate, origin = "2000-01-01", tz = "UTC"),
         geometry_raw = o$Geometry, geometry_decoded = p$decoded)
}))

# Shape --------------------------------------------------------------------------------------------------------------
out <- bind_rows(gpx, tzx) |>
  mutate(name = squeeze(name_raw), .after = name_raw) |>
  mutate(comment = squeeze(comment_raw), .after = comment_raw) |>
  mutate(text_lost = grepl("?", name, fixed = TRUE), comment_text_lost = grepl("?", comment, fixed = TRUE),
         name_is_number = !is.na(name) & is_number(name),
         time_placeholder = !is.na(time) & format(time, "%Y-%m-%d") == "1984-12-31",
         time_suspect = !time_placeholder & (is.na(time) | time < as.POSIXct("1985-01-01", tz = "UTC") | time > LAST),
         source = "plotter", position_basis = if_else(is.na(lon) | is.na(lat), "none", "recorded"),
         position_kind = if_else(is.na(lon) | is.na(lat), NA_character_, "point"))

# Check and write ----------------------------------------------------------------------------------------------------
n_wpt <- vapply(GPX, function(f) length(gregexpr("<wpt ", paste(readLines(file.path(DIR, f), warn = FALSE), collapse = ""),
                                                 fixed = TRUE)[[1]] |> (\(g) g[g > 0])()), 0L)
stopifnot("every <wpt> in a row" = all(table(factor(gpx$file, GPX)) == n_wpt),
          "every TimeZero object in a row" = nrow(tzx) == 580L,
          "every GPX mark has a position and a time" = !anyNA(gpx$lon) && !anyNA(gpx$time),
          "a TimeZero position only where its geometry decoded" = all((out$format == "tzx" & !out$geometry_decoded %in% TRUE) == (out$position_basis == "none")))

print(knitr::kable(out |> group_by(file) |> summarise(
  years = paste(range(format(time[!time_suspect & !time_placeholder], "%Y")), collapse = "-"),
  marks = n(), named = sum(!is.na(name)), names = n_distinct(name, na.rm = TRUE), not_number = sum(!is.na(name) & !name_is_number),
  n_text_lost = sum(text_lost), no_position = sum(position_basis == "none"), n_placeholder = sum(time_placeholder),
  n_suspect = sum(time_suspect)), caption = "staging/ornefni/plotter_mark"))
dup <- out |> filter(position_basis == "recorded") |> count(lon = round(lon, 5), lat = round(lat, 5), time, name) |> filter(n > 1)
cat("marks in more than one file (position, time and name equal):", nrow(dup), "\n")

write_parquet_group(out, fd_staging("ornefni", "plotter_mark.parquet"))
