# smb_stations.R — the tows of MFRI's spring groundfish survey (SMB), from the maintainer's public web space.
#
# Input:  https://heima.hafro.is/~einarhj/data/is_smb_stations.csv   (public; 4.0 MB, last modified 2024-01-05)
# Output: $FISHYDATA/raw/survey/is_smb_stations.csv                  the file as published, unchanged
#
# TODO 60: ground truth for tow times. One row per survey tow, 1990-2023: vid, the tow's start and end (t1, t2,
# UTC), its start and end positions, duration, speed and tow length, recorded under the survey protocol. The survey
# vessels are in the AIS trail. The autumn survey (SMH) is not published there (checked 2026-10-14), and the DATRAS
# haul file on ftp.hafro.is (datras_hh.R) holds the other countries' surveys, not these.
url <- "https://heima.hafro.is/~einarhj/data/is_smb_stations.csv"
out <- fd_raw("survey", "is_smb_stations.csv")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::download.file(url, out, mode = "wb", quiet = TRUE)
message(sprintf("%s: %s bytes", out, format(file.size(out), big.mark = ",")))
