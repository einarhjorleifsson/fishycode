# datras_hh.R — the haul records (DATRAS HH) of MFRI's trawl surveys, from MFRI's public FTP site.
#
# Input:  ftp://ftp.hafro.is/pub/data/datras/HH.parquet   (public; 6.9 MB on 2026-10-14, last modified 2025-12-09)
# Output: $FISHYDATA/raw/survey/datras_HH.parquet          the file as published, unchanged
#
# Fetched for TODO 60 (ground truth for tow times), and found not to serve it: it is the ICES DATRAS haul table of
# the other countries' surveys (all of DATRAS), with 94 Icelandic hauls of a 2009 deep-water survey and none of the
# Icelandic groundfish surveys. Kept as raw: it is public, small, and the other countries' tows are a test set for
# ramb. The Icelandic spring survey's tows come from smb_stations.R.
url <- "ftp://ftp.hafro.is/pub/data/datras/HH.parquet"
out <- fd_raw("survey", "datras_HH.parquet")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::download.file(url, out, mode = "wb", quiet = TRUE)
message(sprintf("%s: %s bytes", out, format(file.size(out), big.mark = ",")))
