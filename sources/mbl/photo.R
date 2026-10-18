# The vessel photos scraped from Morgunblaðið's online register (200 mílur) in December 2022, indexed by vid.
# Side: preprocessing (an index of image files; it feeds no flow step, its reader is products/vessel_overview). Plan 030
# step 1; decision 137.
#
# Input:  raw/external/skipaskra/jpg/<vid>-<image_no>[-thumb].jpg (1,000 files on 2026-10-18)
#         raw/external/skipaskra/{nohup_2022-12-27,nohup2,mbl-scrape_2022-12-28_*}.log - the photo scrape's eight logs
# Output: staging/mbl/photo.parquet - one row per file, and one per logged download that has no file (kind "missing")
#
# The files were made by raw/external/skipaskra/R/mbl-scrape_jpg.R, which took the first image of each vessel page's
# gallery from static.mbl.is, and R/create_thumbs.R, which scaled each to 120 px high beside it as "-thumb". mbl's own
# image id is not in the file name, only in the logs, so it comes from there with the URL and the byte count.
#
# - The folder is about a quarter of the scrape: the logs record 2,120 downloads and 538 photos are here (plan 030
#   §1.3). Each logged download with no file is a row of kind "missing", so the gap shows in the table. If the whole
#   set is found (decision 137, ask b) it lands in the same folder and the index grows.
# - `defect`, first rule that applies: a photo 120 px high or less is "undersized" (0078: a thumbnail-sized image under
#   a photo's name); a photo with fewer bytes than its log says is "truncated" (1722: the download that halted the
#   first run), more is "size_differs"; a file whose vid no log covers is "no_log".
# - `best` marks one image per vid: a photo without an image defect, else the thumbnail, else a defective photo.
# - A vid in two logs (2184 ends one run and starts the next) takes the later log's line. The logs are listed in the
#   order they were run: each starts where the one before halted or ended.
# - EXIF is read as printed. `exif_date` is the day on the camera's clock (DateTimeOriginal, else DateTime), in no
#   known time zone. It is NA where the camera printed its default, 2000-01-01 (17 photos: a clock never set);
#   `exif_date_txt` keeps what was printed. The other dates run from 2003 to 2016-09-04. Thumbnails carry no EXIF.
#
# Use: the photos are a newspaper's images, for internal use only (plan 030 §4.5): `use` says so on every row.
# Personal data: the EXIF `Artist` and `Copyright` strings name photographers, some with an e-mail address and a phone
# number. They are what a public source printed, so they are kept as printed (plan 028 §7, decision 130), under
# $FISHYDATA only, never shown or published. The app shows `exif_artist` as a credit, never `exif_copyright`.

library(dplyr)

DIR  <- fd_raw("external", "skipaskra", "jpg")
LOGS <- c("nohup_2022-12-27.log", "nohup2.log",
          sprintf("mbl-scrape_2022-12-28_%s.log", c("153000", "160000", "163000", "170000", "173000", "180000")))
SCRAPED <- "2022-12-27/2022-12-28"
USE <- "internal only (mbl.is)"
NAME <- "^([0-9]{4})-([0-9]{4})(-thumb)?[.]jpg$"

# The logs: vid, mbl's image id, URL, byte count, outcome ------------------------------------------------------------
read_log <- function(f) {
  x <- readLines(fd_raw("external", "skipaskra", f), warn = FALSE, encoding = "UTF-8")
  out <- list(); vid <- NA_integer_; cur <- NULL
  flush <- function() if (!is.null(cur)) out[[length(out) + 1]] <<- cur
  for (l in x) {
    if (grepl("^\\[1\\] [0-9]+$", l)) {
      vid <- as.integer(sub("^\\[1\\] ", "", l))
    } else if (grepl("^trying URL '.*/skipamyndir/[0-9]+[.]jpg'", l)) {
      flush()
      url <- sub("^trying URL '([^']+)'.*$", "\\1", l)
      cur <- list(vid = vid, mbl_image_id = as.integer(sub("^.*/([0-9]+)[.]jpg$", "\\1", url)), url = url,
                  logged_bytes = NA_real_, logged_status = NA_character_, log = f)
    } else if (!is.null(cur) && grepl("^Content type 'image/jpeg' length [0-9]+ bytes", l)) {
      cur$logged_bytes <- as.numeric(sub("^.* length ([0-9]+) bytes.*$", "\\1", l))
    } else if (!is.null(cur) && grepl("^downloaded ", l)) {
      cur$logged_status <- "downloaded"
    } else if (!is.null(cur) && grepl("^  download from '.*' failed", l)) {
      cur$logged_status <- "failed"
    }
  }
  flush()
  bind_rows(out)
}
logged <- purrr::map(LOGS, read_log) |>
  bind_rows() |>
  mutate(run = match(log, LOGS)) |>
  group_by(vid) |>
  slice_max(run, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(-run)
stopifnot("a logged download has no vid" = !anyNA(logged$vid),
          "a logged download has no byte count" = !anyNA(logged$logged_bytes))

# The files: size, checksum, pixels, EXIF ---------------------------------------------------------------------------
files <- sort(list.files(DIR), method = "radix")
stopifnot("a file in jpg/ is not named <vid>-<image_no>[-thumb].jpg" = all(grepl(NAME, files)))

exif_text <- function(x) {
  x <- trimws(x)
  bad <- !is.na(x) & !validUTF8(x)
  x[bad] <- iconv(x[bad], "latin1", "UTF-8")
  na_if(x, "")
}
read_image <- function(f) {
  im <- tryCatch(magick::image_read(f), error = function(e) stop("does not decode: ", f, ": ", conditionMessage(e)))
  i  <- magick::image_info(im)
  a  <- magick::image_attributes(im)
  e  <- setNames(a$value, a$property)
  g  <- function(k) if (k %in% names(e)) unname(e[[k]]) else NA_character_
  tibble(width = i$width, height = i$height, format = i$format,
         exif_date_txt = coalesce(g("exif:DateTimeOriginal"), g("exif:DateTime")),
         exif_camera = exif_text(trimws(paste(coalesce(g("exif:Make"), ""), coalesce(g("exif:Model"), "")))),
         exif_artist = exif_text(g("exif:Artist")), exif_copyright = exif_text(g("exif:Copyright")))
}
paths <- file.path(DIR, files)
img <- bind_cols(
  tibble(file = files,
         vid = as.integer(sub(NAME, "\\1", files)), image_no = as.integer(sub(NAME, "\\2", files)),
         kind = ifelse(grepl("-thumb[.]jpg$", files), "thumbnail", "photo"),
         path = file.path("raw", "external", "skipaskra", "jpg", files),
         bytes = file.size(paths), md5 = unname(tools::md5sum(paths))),
  purrr::map(paths, read_image) |> bind_rows())
stopifnot("an image is not a JPEG" = all(img$format == "JPEG"))

# One table: the files, then the logged downloads that have no file --------------------------------------------------
img <- img |>
  left_join(logged |> select(vid, mbl_image_id, url, log, logged_bytes, logged_status), by = "vid") |>
  mutate(logged_bytes = if_else(kind == "photo", logged_bytes, NA_real_),
         logged_status = if_else(kind == "photo", logged_status, NA_character_),
         defect = case_when(kind == "photo" & height <= 120 ~ "undersized",
                            kind == "photo" & !is.na(logged_bytes) & bytes < logged_bytes ~ "truncated",
                            kind == "photo" & !is.na(logged_bytes) & bytes > logged_bytes ~ "size_differs",
                            is.na(log) ~ "no_log"))
missing <- logged |>
  anti_join(img |> filter(kind == "photo"), by = "vid") |>
  mutate(image_no = 1L, kind = "missing")

out <- bind_rows(img |> select(-file, -format), missing) |>
  mutate(exif_date = as.Date(as.POSIXct(exif_date_txt, format = "%Y:%m:%d %H:%M:%S", tz = "UTC")),
         exif_date = if_else(exif_date == as.Date("2000-01-01"), as.Date(NA), exif_date),
         scraped = SCRAPED, use = USE,
         rank = case_when(kind == "photo" & (is.na(defect) | defect == "no_log") ~ 1L,
                          kind == "thumbnail" ~ 2L,
                          kind == "photo" ~ 3L)) |>
  group_by(vid) |>
  mutate(best = !is.na(rank) & rank == suppressWarnings(min(rank, na.rm = TRUE))) |>
  ungroup() |>
  select(vid, image_no, kind, path, bytes, md5, width, height, mbl_image_id, url, log, logged_bytes, logged_status,
         defect, exif_date, exif_date_txt, exif_camera, exif_artist, exif_copyright, scraped, use, best) |>
  arrange(vid, image_no, kind)

# Check and write ----------------------------------------------------------------------------------------------------
with_file <- unique(out$vid[out$kind != "missing"])
stopifnot(
  "rows are not files plus missing downloads" = nrow(out) == length(files) + nrow(missing),
  "a file has two rows" = !anyDuplicated(out$path[!is.na(out$path)]),
  "a (vid, image_no, kind) repeats" = !anyDuplicated(out[c("vid", "image_no", "kind")]),
  "a logged download has no photo row" = all(logged$vid %in% out$vid[out$kind %in% c("photo", "missing")]),
  "a missing row is not a logged download" = all(out$vid[out$kind == "missing"] %in% logged$vid),
  "a vid with a file has no best image, or two" =
    all(tapply(out$best[out$vid %in% with_file], out$vid[out$vid %in% with_file], sum) == 1),
  "a missing row is marked best" = !any(out$best & out$kind == "missing"))

print(knitr::kable(out |> count(kind, defect), caption = "staging/mbl/photo: rows by kind and defect"))
print(knitr::kable(tibble(
  files = length(files), vids_with_file = length(with_file), logged_downloads = nrow(logged),
  logged_without_file = nrow(missing), exif_date = sum(!is.na(out$exif_date)), exif_artist = sum(!is.na(out$exif_artist)),
  exif_copyright = sum(!is.na(out$exif_copyright)), best = sum(out$best)),
  caption = "staging/mbl/photo"))

write_parquet_group(out, fd_staging("mbl", "photo.parquet"))
