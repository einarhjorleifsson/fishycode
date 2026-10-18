# The 2022 mbl vessel photos the folder lacks, fetched again by the URLs the scrape's logs give. Plan 030 step 5;
# decision 141. The maintainer's go of 2026-10-18: "fetch the 1,589 missing photos by their logged URLs into
# raw/external/skipaskra/jpg/ under their 2022 names, 1 s apart, checking each byte count against the log". After 82
# images the maintainer asked for more than 1 s between fetches: 4 s, the pace of the 2022 info scrape.
#
# Input:  staging/mbl/photo.parquet - its `missing` rows: vid, image_no, url and logged_bytes, read from the 2022 logs
# Output: raw/external/skipaskra/jpg/<vid>-<image_no>.jpg - each image whose byte count equals its log's
#         raw/external/skipaskra/mbl-photo-recover_<run date>.csv - one row per URL tried: status, bytes, md5, time
#
# - Each image is written to a temporary file first, and moved into the folder only when its size equals the log's.
#   A file already in the folder is never replaced, so a halted run resumes where it stopped.
# - Only static.mbl.is is asked, which has no bot check. The vessel pages, which have one, are not (decision 141).
# - A run stops after MAX_FAILS images in a row fail. No thumbnails are made: the app scales images itself.
# - The images are a newspaper's, for internal use only (plan 030 §4.5).
#
# Run from the repository root, with the maintainer's go:
#   nohup Rscript -e 'source("R/paths.R"); source("dump/vessels/mbl_photo_recover.R")' > <log> 2>&1 &
# N limits the run to the first N images (a pilot). Rebuild the index after it: tar_make_isolated(names = "mbl_photo").

if (!exists("N"))         N         <- Inf
if (!exists("SLEEP"))     SLEEP     <- 4
if (!exists("MAX_FAILS")) MAX_FAILS <- 10

DIR <- fd_raw("external", "skipaskra", "jpg")
MANIFEST <- fd_raw("external", "skipaskra", sprintf("mbl-photo-recover_%s.csv", format(Sys.Date())))

todo <- nanoparquet::read_parquet(fd_path("staging", "mbl", "photo.parquet"))
todo <- todo[todo$kind == "missing" & !is.na(todo$url), c("vid", "image_no", "url", "logged_bytes")]
todo$file <- sprintf("%04d-%04d.jpg", todo$vid, todo$image_no)
todo <- todo[!file.exists(file.path(DIR, todo$file)), ]
stopifnot("an image would land on another's name" = !anyDuplicated(todo$file),
          "a URL is not static.mbl.is's" = all(grepl("^https://static[.]mbl[.]is/generic/sax/skipamyndir/[0-9]+[.]jpg$", todo$url)))
todo <- todo[seq_len(min(nrow(todo), N)), ]
cat(sprintf("mbl photos to fetch: %d, into %s\n", nrow(todo), DIR))

append_csv <- function(d, f) utils::write.table(d, f, sep = ",", row.names = FALSE, col.names = !file.exists(f),
                                                append = file.exists(f), qmethod = "double", fileEncoding = "UTF-8")
fails <- 0
for (i in seq_len(nrow(todo))) {
  x <- todo[i, ]
  tmp <- tempfile(fileext = ".jpg")
  r <- tryCatch(curl::curl_fetch_disk(x$url, tmp), error = function(e) e)
  bytes <- if (file.exists(tmp)) file.size(tmp) else NA_real_
  status <- if (inherits(r, "error")) conditionMessage(r)
            else if (r$status_code != 200) sprintf("HTTP %d", r$status_code)
            else if (!identical(as.numeric(bytes), as.numeric(x$logged_bytes))) "size differs from the log"
            else "ok"
  md5 <- if (status == "ok") unname(tools::md5sum(tmp)) else NA_character_
  if (status == "ok") {
    target <- file.path(DIR, x$file)
    if (file.exists(target)) status <- "exists, not replaced"
    else if (!file.rename(tmp, target) && !(file.copy(tmp, target) && file.remove(tmp))) status <- "could not move"
  }
  unlink(tmp)
  append_csv(data.frame(vid = x$vid, image_no = x$image_no, file = x$file, url = x$url, logged_bytes = x$logged_bytes,
                        bytes = bytes, md5 = md5, status = status, fetched = format(Sys.time(), tz = "UTC", usetz = TRUE)),
             MANIFEST)
  fails <- if (status == "ok") 0 else fails + 1
  if (i %% 50 == 0 || status != "ok") cat(sprintf("%d of %d: %s %s\n", i, nrow(todo), x$file, status))
  if (fails >= MAX_FAILS) stop(sprintf("%d images in a row failed, the last with \"%s\": stopped", fails, status))
  Sys.sleep(SLEEP)
}
cat("done\n")
