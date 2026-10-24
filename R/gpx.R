# read_gpx_marks(), read_gpx_tracks() — a GPX file's waypoints, or its track points, read as text rather than as XML.
#
# Input:  the path of a GPX 1.1 file
# Output: a data frame, one row per element, its text as written:
#         marks:  mark (order in the file), lat, lon, time_txt, name, cmt, symbol (MxTimeZeroSymbol), colour (T0Color)
#         tracks: trk (order in the file), trk_name, guid, point (order within the track), lat, lon, time_txt
#
# The TimeZero plotter's exports in raw/external/ornefni (plan 043) are not valid XML: an unescaped &, @ or ; in a name
# makes xml2 and GDAL refuse some of them. So each element is cut out by pattern, the way the plotter writes it (one
# attribute order, no nesting). An empty element (`<name />`) is NA. Times stay text here: the caller parses them.
# A file cut off before its end (no `</gpx>`: both exports of `vesturhluti 2`) keeps its last, unclosed track; the
# point the cut falls in is dropped. `attr(, "truncated")` says whether the file ends early.
read_gpx_marks <- function(path) {
  x <- .gpx_text(path)
  w <- stringi::stri_extract_all_regex(x, "<wpt [^>]*>.*?</wpt>", opts_regex = list(dotall = TRUE))[[1]]
  if (length(w) == 1 && is.na(w)) w <- character()
  data.frame(mark = seq_along(w), lat = .gpx_num(w, "lat"), lon = .gpx_num(w, "lon"),
             time_txt = .gpx_tag(w, "time"), name = .gpx_tag(w, "name"), cmt = .gpx_tag(w, "cmt"),
             symbol = as.integer(.gpx_tag(w, "MxTimeZeroSymbol")), colour = as.integer(.gpx_tag(w, "T0Color")))
}

read_gpx_tracks <- function(path) {
  x <- .gpx_text(path)
  trk <- stringi::stri_extract_all_regex(x, "<trk>.*?(?:</trk>|\\z)", opts_regex = list(dotall = TRUE))[[1]]
  if (length(trk) == 1 && is.na(trk)) return(data.frame())
  head <- stringi::stri_replace_all_regex(trk, "<trkseg>.*", "", opts_regex = list(dotall = TRUE))
  pts <- stringi::stri_extract_all_regex(trk, "<trkpt [^>]*>.*?</trkpt>", opts_regex = list(dotall = TRUE))
  n <- vapply(pts, function(p) sum(!is.na(p)), 0L)
  p <- unlist(pts[n > 0])
  out <- data.frame(trk = rep(seq_along(trk), n), trk_name = rep(.gpx_tag(head, "name"), n), guid = rep(.gpx_tag(head, "guid"), n),
             point = unlist(lapply(n, seq_len)), lat = .gpx_num(p, "lat"), lon = .gpx_num(p, "lon"),
             time_txt = .gpx_tag(p, "time"))
  attr(out, "truncated") <- !grepl("</gpx>", x, fixed = TRUE)
  out
}

.gpx_text <- function(path) {
  x <- readLines(path, encoding = "UTF-8", warn = FALSE)
  x[1] <- sub("^﻿", "", x[1])
  paste(x, collapse = "\n")
}
.gpx_num <- function(el, attr) as.numeric(stringi::stri_match_first_regex(el, sprintf('%s="([^"]*)"', attr))[, 2])
.gpx_tag <- function(el, tag) stringi::stri_match_first_regex(el, sprintf("<%1$s>(.*?)</%1$s>", tag),
                                                             opts_regex = list(dotall = TRUE))[, 2]
