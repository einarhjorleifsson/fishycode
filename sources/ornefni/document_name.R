# Place names in two kinds of document: the Skjálfandi report's table of fishing grounds, and ÍSOR's proposed names.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/documents/Fiskimið.pdf ("Fiskimið á Skjálfanda", 2004, the appendix tables 7.1-7.3);
#         documents/GRG-ISOR-08041.pdf, -08045.pdf, -08125.pdf (ÍSOR's "Örnefnagjöf á landgrunninu og utan þess", 2008)
# Output: staging/ornefni/document_name.parquet - one row per entry, keyed on (`document`, `entry`)
#
# Read with poppler's pdftotext, the text as printed:
# - Skjálfandi: each word is placed in its column by its position under the table's header (pdftotext -bbox): `nr`,
#   `name`, `description` (Staðsetning/Lýsing á viðmiði: the place, or the landmarks lined up to find it), `class`
#   (Flokkur), `position_text` (Nánari staðsetning, in table 7.1 only), `informant` (Heimild/Heimildarmenn), `recorder`
#   (Skrásetjari). A line with no number continues the row above. The notes after the tables (7.4 Athugasemdir) are
#   not rows. "II" is the table's ditto mark: kept as printed, with
#   `class_filled`, `informant_filled` and `recorder_filled` beside it. A coordinate in the row ([66°25,6N 17°10,1V])
#   is read into `lon`/`lat`, basis `recorded`; else the position is the description, kind `text`.
# - ÍSOR: an entry is "Name. Description. Enska: English name." with ◊ where the author coined the name (`coined`). A
#   line that is a name and a colon ("Völsungur:") heads the entries under it: `group`; a heading line with no full stop
#   ("Önnur fyrirbrigði á og við Bergrisann") is `section`. Figure captions (Mynd 1) are not entries. The names' positions are on
#   each report's map only (plan 043 ask d): kind `text`.
# `informant` and `recorder` name people: kept under $FISHYDATA only. The Vestmannaeyjar map has no text: not staged.

library(dplyr)

DIR <- fd_raw("external", "ornefni", "documents")
SKJ <- "Fiskimið.pdf"
ISOR <- c("GRG-ISOR-08125.pdf", "GRG-ISOR-08041.pdf", "GRG-ISOR-08045.pdf")
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }

# Skjálfandi ---------------------------------------------------------------------------------------------------------
bbox_words <- function(path) {
  tmp <- tempfile(fileext = ".html")
  stopifnot(system2("pdftotext", c("-bbox", shQuote(path), tmp)) == 0)
  x <- readLines(tmp, encoding = "UTF-8", warn = FALSE)
  page <- cumsum(grepl("<page ", x))
  w <- grepl("<word ", x)
  m <- stringi::stri_match_first_regex(x[w], 'xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)</word>')
  unesc <- function(s) gsub("&amp;", "&", gsub("&lt;", "<", gsub("&gt;", ">", gsub("&quot;", "\"", s, fixed = TRUE), fixed = TRUE), fixed = TRUE), fixed = TRUE)
  tibble(page = page[w], x0 = as.numeric(m[, 2]), y0 = as.numeric(m[, 3]), x1 = as.numeric(m[, 4]), word = unesc(m[, 6])) |>
    arrange(page, y0, x0) |>
    group_by(page) |> mutate(line = cumsum(c(TRUE, diff(y0) > 2))) |> ungroup()
}
HEAD <- c(nr = "NR.", name = "Nafn", description = "Staðsetning/Lýsing", class = "Flokkur", position_text = "Nánari",
          informant = "Heimild/Heimildarmenn", recorder = "Skrásetjari")

# A column's cells start left of its header, so each column starts after the empty vertical strip nearest its header
# on the left, found in that page's own words. A column empty on a page (the finer position, in table 7.1) cedes the
# strip to the next one.
col_starts <- function(ww, head_x) {
  cov <- logical(1000)
  for (k in seq_len(nrow(ww))) cov[max(1, floor(ww$x0[k])):min(1000, ceiling(ww$x1[k]))] <- TRUE
  r <- rle(cov); to <- cumsum(r$lengths); from <- to - r$lengths + 1
  gap <- data.frame(from, to)[!r$values & r$lengths >= 2, ]
  st <- c(nr = -Inf)
  for (k in seq_along(head_x)[-1]) {
    g <- gap[gap$from < head_x[k] + 5 & gap$to > head_x[k - 1], ]
    st[names(head_x)[k]] <- if (nrow(g)) max(g$to) + 1 else head_x[k]
  }
  st
}
w <- bbox_words(file.path(DIR, SKJ))
lines <- w |> group_by(page, line) |> summarise(y0 = min(y0), txt = paste(word, collapse = " "), .groups = "drop")
head_lines <- lines |> filter(grepl("^NR\\.? Nafn", txt))
stopifnot("the three appendix tables' headers" = nrow(head_lines) == 3)
first <- head_lines[1, ]
skip <- function(txt) grepl("^7(\\.[0-9])? (Fylgiskjöl|Fiskimið)", txt) || grepl("^[0-9]{1,2}$", txt)
end_at <- lines |> filter(grepl("^7\\.[0-9] ", txt), !grepl("Fiskimið", txt), page >= first$page)      # 7.4 Athugasemdir
stopifnot("the notes after the tables" = nrow(end_at) == 1)
body <- lines |> filter((page > first$page | (page == first$page & y0 >= first$y0)),
                        page < end_at$page | (page == end_at$page & y0 < end_at$y0))
rows <- list(); cur <- NULL; head_x <- NULL; starts <- list()
for (i in seq_len(nrow(body))) {
  ln <- body[i, ]; ww <- w |> filter(page == ln$page, line == ln$line)
  if (grepl("^NR\\.? Nafn", ln$txt)) {
    hx <- vapply(HEAD, function(h) { k <- which(ww$word == h | (h == "NR." & ww$word == "NR")); if (length(k)) ww$x0[k[1]] else NA_real_ }, 0)
    head_x <- sort(hx[!is.na(hx)]); next
  }
  if (skip(ln$txt)) next
  key <- as.character(ln$page)
  if (is.null(starts[[key]])) {
    pw <- body |> filter(page == ln$page, !grepl("^NR\\.? Nafn", txt), !vapply(txt, skip, TRUE))
    starts[[key]] <- col_starts(w |> semi_join(pw, by = c("page", "line")), head_x)
  }
  st <- starts[[key]]
  so <- st[order(st, match(names(st), names(HEAD)))]               # on a tie the later column takes the cell
  ww$col <- names(so)[findInterval(ww$x0, so)]
  nr_txt <- paste(ww$word[ww$col == "nr"], collapse = " ")
  if (grepl("^[0-9]+$", nr_txt)) {
    if (!is.null(cur)) rows[[length(rows) + 1]] <- cur
    cur <- list(page = ln$page, nr = as.integer(nr_txt))
  } else if (is.null(cur)) next
  for (cl in setdiff(unique(ww$col), "nr")) cur[[cl]] <- paste(c(cur[[cl]], ww$word[ww$col == cl]), collapse = " ")
}
rows[[length(rows) + 1]] <- cur
skj <- bind_rows(lapply(rows, as_tibble))
for (cl in setdiff(names(HEAD), names(skj))) skj[[cl]] <- NA_character_
fill_ditto <- function(x) { x <- squeeze(x); y <- x; for (k in seq_along(y)[-1]) if (y[k] %in% "II") y[k] <- y[k - 1]; y }
coord <- stringi::stri_match_first_regex(paste(skj$description, skj$position_text),
                                         "(\\d{2})°\\s*(\\d+(?:,\\d+)?)\\s*N\\s*(\\d{1,2})°\\s*(\\d+(?:,\\d+)?)\\s*V")
num <- function(x) as.numeric(sub(",", ".", x, fixed = TRUE))
skj <- skj |>
  mutate(document = SKJ, entry = row_number(), name_raw = name, name = squeeze(name),
         description = squeeze(description), class = squeeze(class), position_text = squeeze(position_text),
         informant = squeeze(informant), recorder = squeeze(recorder),
         class_filled = fill_ditto(class), informant_filled = fill_ditto(informant), recorder_filled = fill_ditto(recorder),
         lat = num(coord[, 2]) + num(coord[, 3]) / 60, lon = -(num(coord[, 4]) + num(coord[, 5]) / 60))

# ÍSOR ---------------------------------------------------------------------------------------------------------------
isor_entries <- function(f) {
  n_page <- as.integer(sub(".*Pages:\\s+", "", grep("^Pages:", system2("pdfinfo", shQuote(file.path(DIR, f)), stdout = TRUE), value = TRUE)))
  L <- bind_rows(lapply(seq_len(n_page), function(p) tibble(page = p, txt = system2("pdftotext", c("-f", p, "-l", p,
         shQuote(file.path(DIR, f)), "-"), stdout = TRUE)))) |>
    mutate(txt = trimws(gsub("\f", "", txt, fixed = TRUE))) |> filter(nzchar(txt), !grepl("^[0-9]{1,2}$", txt), !grepl("^Mynd [0-9]", txt))
  # two short entries can share a printed line: cut after a ◊ that has text behind it
  L <- L |> mutate(txt = strsplit(gsub("◊\\s+(?=\\S)", "◊\n", txt, perl = TRUE), "\n")) |> tidyr::unnest(txt)
  start <- which(grepl("^Örnefni", L$txt) & !grepl("^Örnefnagjöf", L$txt))[1]
  stopifnot("the entries' heading" = !is.na(start))
  L <- L[start:nrow(L), ]
  ent <- list(); cur <- NULL; group <- NA_character_; section <- NA_character_
  done <- function(e) !is.null(e) && grepl("Enska:?\\s", e$text) && grepl("(◊|\\.)\\s*$", e$text)
  para <- function(e) !is.null(e) && nchar(sub("[.:].*$", "", e$text)) > 45      # a paragraph under a heading, not an entry
  notes <- 0L
  for (i in seq_len(nrow(L))) {
    s <- L$txt[i]
    if (s == "◊" && !is.null(cur)) { cur$text <- paste(cur$text, s); next }
    heading <- grepl("^Örnefni", s) || ((is.null(cur) || done(cur)) && !grepl("[.:]", s) && nchar(s) < 70)
    if (heading || grepl("^[^.:]{1,40}:$", s)) {
      if (!is.null(cur)) ent[[length(ent) + 1]] <- cur
      cur <- NULL
      if (heading) { section <- s; group <- NA_character_ } else group <- sub(":$", "", s)
      next
    }
    starts <- grepl("^[[:upper:]ÁÉÍÓÚÝÞÆÖÐ][^.:]{0,40}[.:]( |$|Enska)", s)        # "Niði.Enska:" has no space
    if (is.null(cur) || (done(cur) && starts) || (para(cur) && starts)) {
      if (para(cur)) notes <- notes + 1L else if (!is.null(cur)) ent[[length(ent) + 1]] <- cur
      cur <- list(page = L$page[i], section = section, group = group, text = s)
    } else cur$text <- paste(cur$text, s)
  }
  if (!is.null(cur)) ent[[length(ent) + 1]] <- cur
  message(f, ": ", notes, " paragraph(s) under a heading, not entries")
  bind_rows(lapply(ent, as_tibble)) |>
    mutate(document = f, entry = row_number(), text = squeeze(text),
           name_raw = sub("^([^.:]+)[.:].*$", "\\1", text), name = squeeze(name_raw),
           name_en = squeeze(sub("[.]?\\s*◊?\\s*$", "", ifelse(grepl("Enska:?\\s", text), sub("^.*Enska:?\\s*", "", text), NA))),
           description = squeeze(sub("^[^.:]+[.:]\\s*", "", sub("\\s*Enska:?\\s.*$", "", text))),
           coined = grepl("◊", text, fixed = TRUE))
}
isor <- bind_rows(lapply(ISOR, isor_entries))
n_enska <- vapply(ISOR, function(f) sum(stringi::stri_count_regex(system2("pdftotext", c(shQuote(file.path(DIR, f)), "-"), stdout = TRUE), "Enska:?(\\s|$)")), 0)

# Shape, check and write ---------------------------------------------------------------------------------------------
out <- bind_rows(
  skj |> select(document, entry, page, nr, name_raw, name, description, class, class_filled, position_text, lat, lon,
                informant, informant_filled, recorder, recorder_filled),
  isor |> select(document, entry, page, section, group, name_raw, name, name_en, description, coined, text)) |>
  mutate(source = if_else(document == SKJ, "skjalfandi", "isor"),
         position_basis = if_else(is.na(lon) | is.na(lat), "none", "recorded"),
         position_kind = if_else(position_basis == "recorded", "point", "text"))

stopifnot("Skjálfandi: one row per number" = !anyDuplicated(skj$nr) && all(skj$nr == seq_along(skj$nr)),
          "ÍSOR: one entry per 'Enska'" = all(table(factor(isor$document, ISOR)) == n_enska),
          "ÍSOR: every entry has its English name" = !anyNA(isor$name_en),
          !anyNA(out$name))
print(knitr::kable(out |> group_by(document) |> summarise(entries = n(), names = n_distinct(name),
  with_position = sum(position_basis == "recorded"), coined = sum(coined, na.rm = TRUE), grouped = sum(!is.na(group))),
  caption = "staging/ornefni/document_name"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "document_name.parquet"))
