# The List of Lights in force (Vitaskrá, Landhelgisgæslan and Vegagerðin), one row per aid as the list gives it (plan 074 step
# 9, the aids; the named-features study's 86_vitaskra.py, the same reading in R).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 074 ask p, the maintainer, 2026-11-16:
# "Standalone in layers"); reference/aids/aid.R reads its output.
#
# Input:  raw/external/vegagerdin/Vitaskra_i_gildi.pdf (dump/vegagerdin/fetch.R), read by pdftotext -layout (poppler)
# Output: staging/vitaskra/aid.parquet - one row per aid: part (light, buoy, mark, racon), number (the list's own, lights
#         only), intl (the international, Admiralty, number), place, name, full_name ("Place - name"), lat, lon (WGS 84, as
#         printed), precision ("exact (1/100 minute)" or "approximate (1/10 minute)"), characteristic, height_m and range_nm
#         (as printed: "12-8-8"), topmark, description (the rest of the row and its continuation lines), page, line
#         staging/vitaskra/line.parquet - every line of the text, page, line, outcome, text
#
# The list's four parts: lights and leading lights (numbered from Reykjanes westward round the country, the Admiralty number
# beside), buoys, radar beacons (Racon), and sea and leading marks. A position to a hundredth of a minute where it is known
# exactly, else to a tenth (the list's own note). A child entry ("- leiðarljós II fremra", "- - ... aftara") takes its place
# from the entry above it; a buoy whose place column is blank, the place above. Every line of the text in one outcome.
# Source-shaped: the columns as the text lays them out; nothing corrected. The edition is the PDF's (November 2026 at the fetch).
# Run from the repo root: Rscript sources/vitaskra/aid.R. Written by Claude (AI).

pdf <- fd_raw("external", "vegagerdin", "Vitaskra_i_gildi.pdf")
txt <- paste(system2("pdftotext", c("-layout", shQuote(pdf), "-"), stdout = TRUE), collapse = "\n")
pages <- strsplit(txt, "\f", fixed = TRUE)[[1]]
POS <- "(?<!\\d)(6[3-7]) (\\d{2},\\d{1,2})\\s+([12]\\d) (\\d{2},\\d{1,2})(?!\\d)"
PARTS <- c("Vitar og leiðarljós" = "light", "Dufl" = "buoy", "Radarsvarar" = "racon", "Sjó- og leiðarmerki" = "mark")
rows <- list(); lines_out <- list(); part <- NA_character_; last <- NA_integer_
parent <- c(light = "", buoy = "", mark = "", racon = "")
for (pg in seq_along(pages)) {
  ls <- strsplit(pages[pg], "\r\n|\n|\r")[[1]]
  for (ln in seq_along(ls)) {
    line <- ls[ln]; s <- trimws(line)
    out1 <- function(o) lines_out[[length(lines_out) + 1]] <<- data.frame(page = pg, line = ln, outcome = o, text = s)
    if (s %in% names(PARTS)) { part <- PARTS[[s]]; last <- NA_integer_; out1("a part's heading"); next }
    if (startsWith(s, "Nr.") && grepl("Staðarlýsing", s, fixed = TRUE)) { part <- "light"; last <- NA_integer_; out1("a table's head"); next }
    m <- regexpr(POS, line, perl = TRUE)
    if (m == -1 || is.na(part)) {
      indent <- nchar(line) - nchar(sub("^\\s+", "", line))
      if (!nzchar(s)) o <- "blank"
      else if (!is.na(last) && !is.na(part) && indent > 4 && !grepl("^\\d+$", s)) {
        rows[[last]]$more <- c(rows[[last]]$more, s); o <- "a continuation of the aid above" }
      else if (!is.na(last) && !is.na(part) && grepl("^[A-ZÁÉÍÓÚÝÞÆÖÐa-záéíóúýþæöð]", s) && nchar(s) < 40 && !grepl(POS, s, perl = TRUE)) {
        rows[[last]]$more <- c(rows[[last]]$more, s); o <- "a continuation of the aid above" }
      else o <- "text (no aid: notes, headings, page numbers)"
      out1(o); next
    }
    g <- regmatches(line, regexec(POS, line, perl = TRUE))[[1]]
    head <- sub("\\s+$", "", substr(line, 1, m - 1)); tail <- trimws(substr(line, m + attr(m, "match.length"), nchar(line)))
    lat <- as.integer(g[2]) + as.numeric(sub(",", ".", g[3])) / 60
    lon <- -(as.integer(g[4]) + as.numeric(sub(",", ".", g[5])) / 60)
    exact <- nchar(sub(".*,", "", g[3])) == 2 && nchar(sub(".*,", "", g[5])) == 2
    num <- intl <- ""; h <- trimws(head)
    if (part == "light") {
      mm <- regmatches(h, regexec("^(\\d+(?:,\\d+)?)\\s+(L?\\d+(?:\\.\\d+)?)?\\s*(.*)$", h, perl = TRUE))[[1]]
      if (length(mm)) { num <- mm[2]; intl <- mm[3]; h <- trimws(mm[4]) } }
    lead <- regmatches(h, regexpr("^(?:-\\s+)*", h, perl = TRUE))
    depth <- nchar(gsub(" |\\s", "", lead))
    name <- if (depth > 0) trimws(substr(h, depth * 2 + 1, nchar(h))) else h
    name <- trimws(sub("^(-\\s*)+", "", name, perl = TRUE))
    if (part == "buoy" && !nzchar(h)) depth <- 1
    if (depth == 0) {
      place <- if (grepl(" - ", name, fixed = TRUE) || grepl("\\s-\\s", name, perl = TRUE)) trimws(strsplit(name, "\\s+-\\s+", perl = TRUE)[[1]][1]) else name
      parent[[part]] <- place; full <- name
    } else full <- paste0(parent[[part]], " - ", name)
    rows[[length(rows) + 1]] <- list(part = part, number = num, intl = intl, place = parent[[part]], name = name,
                                     full_name = gsub("\\s+", " ", full), lat = round(lat, 6), lon = round(lon, 6),
                                     precision = if (exact) "exact (1/100 minute)" else "approximate (1/10 minute)",
                                     rest = tail, page = pg, line = ln, more = character())
    last <- length(rows); out1(paste0("an aid (", part, ")"))
  }
}
# the rest of each row: characteristic, height, range, topmark, structure, remarks (the columns as the text lays them out)
CHAR <- "^((?:Aero\\s+)?(?:Al\\s+)?(?:L?Fl|Oc|Iso|Q|VQ|UQ|Mo|F|Dir|LFI|FI)\\S*(?:\\s*\\([^)]*\\))?(?:\\s?[WRGYBu]{1,4})?(?:\\s+\\d+(?:,\\d+)?s)?)"
aid <- do.call(rbind, lapply(rows, function(r) {
  t <- r$rest; ch <- hm <- rn <- tm <- ""
  if (r$part %in% c("light", "buoy")) { m <- regmatches(t, regexec(CHAR, t, perl = TRUE))[[1]]
    if (length(m)) { ch <- trimws(m[2]); t <- trimws(substr(t, nchar(m[1]) + 1, nchar(t))) } }
  if (r$part == "light") { m <- regmatches(t, regexec("^(\\d+(?:,\\d+)?)?\\s*(\\d+(?:-\\d+)*)?\\s*(.*)$", t, perl = TRUE))[[1]]
    if (length(m)) { hm <- m[2]; rn <- m[3]; t <- m[4] } }
  if (r$part %in% c("buoy", "mark")) { m <- regmatches(t, regexec("^([▯△▽○♢◇⧫●□■◆▲▼]+)\\s*(.*)$", t, perl = TRUE))[[1]]
    if (length(m)) { tm <- m[2]; t <- m[3] } }
  data.frame(part = r$part, number = r$number, intl = r$intl, place = r$place, name = r$name, full_name = r$full_name,
             lat = r$lat, lon = r$lon, precision = r$precision, characteristic = ch, height_m = hm, range_nm = rn, topmark = tm,
             description = gsub("\\s+", " ", trimws(paste(t, paste(r$more, collapse = " ")))), page = r$page, line = r$line) }))
lines <- do.call(rbind, lines_out)
stopifnot(nrow(aid) == sum(grepl("^an aid", lines$outcome)))
dir.create(fd_staging("vitaskra"), recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(aid, fd_staging("vitaskra", "aid.parquet"))
nanoparquet::write_parquet(lines, fd_staging("vitaskra", "line.parquet"))
message(sprintf("vitaskra: %d aids (%s), %d exact; %d lines", nrow(aid), paste(names(table(aid$part)), table(aid$part), collapse = ", "),
                sum(startsWith(aid$precision, "exact")), nrow(lines)))
