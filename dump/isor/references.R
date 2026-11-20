# The publications ÍSOR's seabed map cites, where they are open on the web: each fetched as it is served, its text drawn out
# beside it, with a checksum. The first, at the maintainer's word (2026-11-19, "get The 2023 mapping"): Erlendsson, Blischke,
# Hjartarson, Óðinsson and Vésteinsson, "The Geological mapping of Iceland's Insular Shelf and Adjacent Deep Ocean", EGU
# General Assembly 2023, EGU23-15536 (https://doi.org/10.5194/egusphere-egu23-15536): an abstract served as a web page only
# (no PDF or display material attached, 2026-11-19), CC BY 4.0. The 2023 mapping of plan 080's ÍSOR craters and guyots.
# Input:  the publications' pages (REFS below)
# Output: $FISHYDATA/raw/external/isor/references/<key>.html (as served) and <key>.txt (its text), _manifest.csv (key, url,
#         fetched, bytes, sha256, licence, citation)
# Run from the repo root: Rscript dump/isor/references.R (fetches only what is not there). Written by Claude (AI), 2026-11-19.
source("R/paths.R")
out <- fd_raw("external", "isor", "references"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
UA <- "fishycode data fetch"
REFS <- data.frame(
  key = "EGU23-15536",
  url = "https://meetingorganizer.copernicus.org/EGU23/EGU23-15536.html",
  licence = "CC BY 4.0 (the page: \"distributed under the Creative Commons Attribution 4.0 License\")",
  citation = paste("Erlendsson, Ö., Blischke, A., Hjartarson, Á., Óðinsson, D. Þ. and Vésteinsson, Á. Þ. (2023). The Geological",
                   "mapping of Iceland's Insular Shelf and Adjacent Deep Ocean. EGU General Assembly 2023, Vienna, 24-28 April 2023,",
                   "EGU23-15536. https://doi.org/10.5194/egusphere-egu23-15536"))
text_of <- function(f) {                                     # the page's text, scripts and markup left out
  s <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  s <- gsub("(?s)<script.*?</script>|<style.*?</style>", " ", s, perl = TRUE)
  s <- gsub("<[^>]+>", " ", s); s <- xml2::xml_text(xml2::read_html(paste0("<p>", s, "</p>")))
  trimws(gsub("[ \t\r\n]+", " ", s))
}
man_f <- file.path(out, "_manifest.csv")
man <- if (file.exists(man_f)) read.csv(man_f, encoding = "UTF-8") else REFS[0, ]
for (i in seq_len(nrow(REFS))) {
  r <- REFS[i, ]; html <- file.path(out, paste0(r$key, ".html"))
  if (file.exists(html)) next
  status <- system2("curl", c("-sSL", "-A", shQuote(UA), "-o", shQuote(html), "-w", "%{http_code}", shQuote(r$url)), stdout = TRUE)
  if (!identical(status, "200")) { unlink(html); stop(r$key, ": HTTP ", status) }
  writeLines(text_of(html), file.path(out, paste0(r$key, ".txt")), useBytes = TRUE)
  man <- rbind(man[man$key != r$key, intersect(names(man), c("key", "url", "fetched", "bytes", "sha256", "licence", "citation")), drop = FALSE],
               data.frame(key = r$key, url = r$url, fetched = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                          bytes = file.size(html), sha256 = digest::digest(file = html, algo = "sha256"),
                          licence = r$licence, citation = r$citation))
}
write.csv(man, man_f, row.names = FALSE, fileEncoding = "UTF-8")
print(man[c("key", "bytes", "fetched")])
