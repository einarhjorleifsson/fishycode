# smb_biological.R — the catch of MFRI's spring groundfish survey (SMB) by tow and species, from the maintainer's
# public web space.
#
# Input:  https://heima.hafro.is/~einarhj/data/is_smb_biological.csv   (public; 2.2 MB, last modified 2024-01-05)
# Output: $FISHYDATA/raw/survey/is_smb_biological.csv                  the file as published, unchanged
#
# The companion of smb_stations.R: its `id` is the tow's id there (ramb's trawlsurveytows calls it `id.lgs`). Read
# for plan 033's first chapter, the scientist's side of a day at sea; the maintainer cleared it for the book
# (2026-10-19).
url <- "https://heima.hafro.is/~einarhj/data/is_smb_biological.csv"
out <- fd_raw("survey", "is_smb_biological.csv")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::download.file(url, out, mode = "wb", quiet = TRUE)
message(sprintf("%s: %s bytes", out, format(file.size(out), big.mark = ",")))
