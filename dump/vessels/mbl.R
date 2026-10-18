# Morgunblaðið's online vessel register (200 mílur), scraped a vessel page at a time: the page as it is, and every image
# in its gallery. Plan 030 step 2; decision 137.
#
# Input:  https://www.mbl.is/200milur/skipaskra/skip/<vid>, and each gallery image from
#         https://static.mbl.is/generic/sax/skipamyndir/<id>.jpg
# Output: raw/external/mbl/<run date>/
#           html/vid-NNNN.html        the page as served: its fields, gallery and any captions or credits
#           jpg/NNNN-JJJJ.jpg         every gallery image, JJJJ its place in the gallery
#           pages.csv                 one row per vid tried: URL, status, time
#           images.csv                one row per image: mbl's image id, URL, file, bytes, md5, alt, title, caption, time
#
# Replaces the two 2022 scripts in raw/external/skipaskra/R/ (mbl-scrape_info.R, mbl-scrape_jpg.R), which stay there as
# the record of the files they made (decision 137, ask f). What changes:
# - one request per page gives both the fields and the gallery;
# - the page is kept as it is. The 2022 run kept a CSV of the first four tables with the first comma turned into a
#   point, which left thousands points in ("1.100.0" hp, sources/mbl/register.R). Parsing is the adapter's job;
# - every image in the gallery, not only the first, with whatever text the gallery item carries;
# - no thumbnails: they are derived, not dumped;
# - a run can be resumed: a vid whose page is already saved in the run's folder is skipped.
#
# The selectors are the 2022 scripts' (`.carousel-item`, an image named <id>.jpg). Whether mbl's pages still have them,
# and where a caption or credit sits, is unknown until a pilot run: run a few vids first and read the pages.
#
# The images are a newspaper's, for internal use only (plan 030 §4.5): they stay under $FISHYDATA.
#
# Run it deliberately, with the maintainer's go. DRY_RUN = TRUE (the default) sends no request; it prints what would be
# fetched. A pilot of five vessels:
#   Rscript -e 'source("R/paths.R"); VIDS <- c(78, 1977, 2184, 2757, 9810); DRY_RUN <- FALSE; source("dump/vessels/mbl.R")'
# The whole register, 1-9999 at SLEEP = 4 s, is about 11 hours for the pages alone, plus the images:
#   nohup Rscript -e 'source("R/paths.R"); DRY_RUN <- FALSE; source("dump/vessels/mbl.R")' > mbl_$(date +%F).log 2>&1 &
# To resume a halted run, set RUN to its folder's date.

if (!exists("VIDS"))    VIDS    <- 1:9999
if (!exists("DRY_RUN")) DRY_RUN <- TRUE
if (!exists("RUN"))     RUN     <- format(Sys.Date())
if (!exists("SLEEP"))   SLEEP   <- 4

PAGE  <- "https://www.mbl.is/200milur/skipaskra/skip/%d"
IMAGE <- "https://static.mbl.is/generic/sax/skipamyndir/%s.jpg"
OUT   <- fd_raw("external", "mbl", RUN)

page_file  <- function(vid) file.path(OUT, "html", sprintf("vid-%04d.html", vid))
image_file <- function(vid, j) file.path(OUT, "jpg", sprintf("%04d-%04d.jpg", vid, j))

# The gallery: one row per image, in page order, with the text its item carries, as printed
gallery <- function(page) {
  items <- rvest::html_elements(page, ".carousel-item")
  if (!length(items)) return(data.frame())
  rows <- lapply(items, function(it) {
    id <- regmatches(as.character(it), regexpr("[0-9]+(?=[.]jpg)", as.character(it), perl = TRUE))
    if (!length(id)) return(NULL)
    img <- rvest::html_element(it, "img")
    text <- function(x) { x <- trimws(x); if (length(x) && !is.na(x) && nzchar(x)) x else NA_character_ }
    data.frame(mbl_image_id = id, alt = text(rvest::html_attr(img, "alt")), title = text(rvest::html_attr(img, "title")),
               caption = text(rvest::html_text2(it)))
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) data.frame() else cbind(image_no = seq_len(nrow(out)), out)
}

append_csv <- function(d, f) utils::write.table(d, f, sep = ",", row.names = FALSE, col.names = !file.exists(f),
                                                append = file.exists(f), qmethod = "double", fileEncoding = "UTF-8")

# Run ----------------------------------------------------------------------------------------------------------------
cat(sprintf("mbl register: %d vids, run %s, %s\n", length(VIDS), RUN, if (DRY_RUN) "DRY RUN, no request" else OUT))
if (!DRY_RUN) for (d in c("html", "jpg")) dir.create(file.path(OUT, d), recursive = TRUE, showWarnings = FALSE)

for (vid in VIDS) {
  url <- sprintf(PAGE, vid)
  if (DRY_RUN) { cat(vid, url, "->", page_file(vid), "\n"); next }
  if (file.exists(page_file(vid))) next
  page <- tryCatch(xml2::read_html(url), error = function(e) e)
  status <- if (inherits(page, "error")) conditionMessage(page) else "ok"
  if (status == "ok") {
    xml2::write_html(page, page_file(vid))
    g <- gallery(page)
    for (i in seq_len(nrow(g))) {
      src <- sprintf(IMAGE, g$mbl_image_id[i])
      f <- image_file(vid, g$image_no[i])
      ok <- tryCatch(utils::download.file(src, f, mode = "wb", quiet = TRUE) == 0, error = function(e) FALSE)
      append_csv(data.frame(vid = vid, g[i, ], url = src, file = if (ok) basename(f) else NA_character_,
                            bytes = if (ok) file.size(f) else NA_real_,
                            md5 = if (ok) unname(tools::md5sum(f)) else NA_character_,
                            fetched = format(Sys.time(), tz = "UTC", usetz = TRUE)),
                 file.path(OUT, "images.csv"))
      Sys.sleep(1)
    }
    cat(vid, "ok,", nrow(g), "images\n")
  }
  append_csv(data.frame(vid = vid, url = url, status = status, fetched = format(Sys.time(), tz = "UTC", usetz = TRUE)),
             file.path(OUT, "pages.csv"))
  Sys.sleep(SLEEP)
}
