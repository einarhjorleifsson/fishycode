# A person's plotter tracks (TimeZero): every track point in the GPX exports.
# Side: preprocessing (ornefni). See plan 043 (ask b, taken as staged); decision 221.
#
# Input:  raw/external/ornefni/fra_gudmundi-a-bjarna/: every .gpx with tracks
# Output: staging/ornefni/plotter_track.parquet - one row per track point, keyed on (`file`, `trk`, `point`)
#
# Source-shaped: the track's name and guid, each point's position and time as written (seconds; the fraction of a
# second dropped).
# - Both exports of `vesturhluti 2` end mid-file (no `</gpx>`, the last point cut off): truncated where they were made.
#   Their last, unclosed track is kept; a point the cut falls in is dropped (none in the 2022 file).
# - `older/vesturhluti 2.gpx` is an earlier, shorter export of the west tracks. Its points are tested against
#   `GS_hlutar_2022-11-01/vesturhluti 2.gpx` and staged only if some are not there.
# - `time_placeholder`, `time_suspect`: as in plotter_mark (1984-12-31; before 1985 or after 2022-11-10).

library(dplyr)

DIR <- fd_raw("external", "ornefni", "fra_gudmundi-a-bjarna")
GPX <- sort(list.files(DIR, "[.]gpx$", recursive = TRUE), method = "radix")
OLD <- "older/vesturhluti 2.gpx"
NEW <- "GS_hlutar_2022-11-01/vesturhluti 2.gpx"
LAST <- as.POSIXct("2022-11-10 23:59:59", tz = "UTC")

# Read ---------------------------------------------------------------------------------------------------------------
trk <- lapply(setNames(GPX, GPX), function(f) read_gpx_tracks(file.path(DIR, f)))
cut <- vapply(trk, function(d) isTRUE(attr(d, "truncated")), TRUE)
trk <- trk[vapply(trk, nrow, 0L) > 0]
key <- function(d) paste(d$lat, d$lon, d$time_txt)
old_in_new <- key(trk[[OLD]]) %in% key(trk[[NEW]])
cat(OLD, ":", sum(old_in_new), "of", length(old_in_new), "points in", NEW, "\n")
if (all(old_in_new)) trk[[OLD]] <- NULL

# Shape --------------------------------------------------------------------------------------------------------------
out <- bind_rows(lapply(names(trk), function(f) tibble(file = f, trk[[f]]))) |>
  mutate(time = as.POSIXct(substr(time_txt, 1, 19), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
         time_placeholder = !is.na(time) & format(time, "%Y-%m-%d") == "1984-12-31",
         time_suspect = !time_placeholder & (is.na(time) | time < as.POSIXct("1985-01-01", tz = "UTC") | time > LAST),
         source = "plotter", position_basis = "recorded", position_kind = "point") |>
  select(file, trk, trk_name, guid, point, time, lon, lat, time_placeholder, time_suspect, source, position_basis,
         position_kind)

# Check and write ----------------------------------------------------------------------------------------------------
n_tag <- function(f, tag) sum(stringi::stri_count_fixed(readLines(file.path(DIR, f), warn = FALSE), tag))
n_open <- vapply(names(trk), n_tag, 0, tag = "<trkpt ")
n_shut <- vapply(names(trk), n_tag, 0, tag = "</trkpt>")
stopifnot("every closed <trkpt> is a row" = all(table(factor(out$file, names(trk))) == n_shut),
          "an unclosed point only at a truncated file's end" = all(n_open - n_shut == ifelse(cut[names(trk)], n_open - n_shut, 0)),
          all(n_open - n_shut <= 1), !anyNA(out$lon), !anyNA(out$lat), !anyNA(out$time))
cat("points cut off at a truncated file's end, dropped:", sum(n_open - n_shut), "\n")

print(knitr::kable(out |> group_by(file) |> summarise(
  years = paste(range(format(time[!time_suspect & !time_placeholder], "%Y")), collapse = "-"),
  tracks = n_distinct(trk), points = n(), n_placeholder = sum(time_placeholder), n_suspect = sum(time_suspect)),
  caption = "staging/ornefni/plotter_track"))

write_parquet_group(out, fd_staging("ornefni", "plotter_track.parquet"))
