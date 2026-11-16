# IS 50V's place names, every bearer: the three name layers of Náttúrufræðistofnun's GeoServer (gis.natt.is, the national map
# service), IS_50V:ornefni_punktar, ornefni_linur and ornefni_flakar, whole. Plan 074 step 9: the maintainer (2026-11-16),
# of IS 50V's islets with no island or skerry name, "Link every IS 50V name, any bearer, to the islets? Yes, link them"; the
# six bearers fetched before (raw/external/is50v/ornefni_*_eyjar_sker.json: eyja, eyjaklasi, hólmi, sker, boði, drangur)
# left 3,212 of 6,243 coast polygons nameless, most of the 30 largest named as a point, a sand, a reef or a grassland.
# Input: https://gis.natt.is/geoserver/ows (WFS 2.0.0 GetFeature, GeoJSON in EPSG:4326), paged by the server's natural order
# (startIndex, count, sortBy the feature id so that pages neither skip nor repeat).
# Output: $FISHYDATA/raw/external/is50v/ornefni_all/<layer>_<page>.json, each page as delivered, and README-provenance.txt
# there (the requests, the date, every page's bytes and sha256, the features against the server's own count).
# Run once, from the repo root: Rscript dump/natt/ornefni.R  (resumes: a page whose file exists and reads whole is kept)
# Open data of Náttúrufræðistofnun Íslands (IS 50V); cite "IS 50V, Náttúrufræðistofnun Íslands" where it is shown.
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "is50v", "ornefni_all"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
UA <- "fishycode data fetch"; PAGE <- 20000L
LAYERS <- c("ornefni_punktar", "ornefni_linur", "ornefni_flakar")
base <- function(ly) paste0("https://gis.natt.is/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=IS_50V:", ly)
get <- function(url, path = NULL) { r <- httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |>
  httr2::req_retry(max_tries = 4, backoff = function(i) 10 * i)
  if (is.null(path)) httr2::resp_body_string(httr2::req_perform(r)) else httr2::req_perform(r, path = path) }
reads_whole <- function(f) file.exists(f) && isTRUE(tryCatch(nrow(sf::read_sf(f, quiet = TRUE)) >= 0, error = function(e) FALSE))
note <- c("# IS 50V's place names, every bearer, fetched by dump/natt/ornefni.R (plan 074 step 9, the islets' names).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                 ". Open data of Náttúrufræðistofnun Íslands (IS 50V); not for navigation."), "")
for (ly in LAYERS) {
  matched <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", get(paste0(base(ly), "&resultType=hits"))))
  n_pages <- ceiling(matched / PAGE); got <- 0L
  note <- c(note, paste0("## ", ly, ": the server's count ", matched, ", ", n_pages, " pages of ", PAGE))
  for (p in seq_len(n_pages) - 1L) {
    f <- file.path(out_dir, sprintf("%s_%02d.json", ly, p))
    url <- paste0(base(ly), "&outputFormat=application/json&srsName=EPSG:4326&sortBy=id&count=", PAGE, "&startIndex=", p * PAGE)
    if (!reads_whole(f)) { message(ly, " page ", p + 1, " of ", n_pages); get(url, f) }
    x <- sf::read_sf(f, quiet = TRUE); got <- got + nrow(x)
    note <- c(note, paste0(basename(f), ": ", nrow(x), " features, ", file.size(f), " bytes, sha256 ",
                           digest::digest(f, algo = "sha256", file = TRUE)), paste0("  request: ", url)) }
  stopifnot("every feature of the layer fetched" = got == matched)
  note <- c(note, paste0("features in all: ", got, " (the server's own count ", matched, ")"), "") }
x <- sf::read_sf(file.path(out_dir, "ornefni_punktar_00.json"), quiet = TRUE)
note <- c(note, paste0("attributes: ", paste(names(sf::st_drop_geometry(x)), collapse = ", ")),
          paste0("edition (gagnasafn): ", paste(unique(x$gagnasafn), collapse = "; ")))
writeLines(note, file.path(out_dir, "README-provenance.txt")); cat(note, sep = "\n")
