# skipaskra_pdf.R — read the annual ship register PDFs (Skipaskrá) by word coordinates.
#
# Function definitions only (targets sources R/ wholesale). Used by sources/skipaskra/*.R (plan 028 step 1).
#
# Input:  raw/external/skipaskra/reports/*.pdf (19 editions, 2004-2022)
# Output: none; the scripts write staging/skipaskra/
#
# Why coordinates and not `pdftotext -layout`: the layout text places a word by its character column, and within one
# entry that column jitters by up to four characters (2004, p. 30: the yard on line 2 starts three columns left of the
# place built on line 1). In PDF points the columns are exact (x = 204 on all five lines). `pdftools::pdf_data()` gives
# every word with its x and y; a word split by kerning ("FISKIS" "K" "IP") is rejoined by its `space` flag.
#
# Owner and address (plan 028 §7): every entry prints the owner and the owner's address, on the left of lines 4 and 5
# in layout A and in two columns of the first line in layouts B and C. They are read as printed, kept under
# $FISHYDATA, and never published (maintainer, 2026-10-18; it replaces decision 121's default for the register).

# Editions ---------------------------------------------------------------------

# One row per PDF: its edition year and layout. A: five-line blocks (2004-2017); B: two-line rows with wrapped cells
# (2018); C: two-line rows, both lines opening with the registration number (2019-2022).
sk_editions <- function(dir = fd_raw("external", "skipaskra", "reports")) {
  f <- list.files(dir, pattern = "\\.pdf$", full.names = TRUE)
  ed <- as.integer(regmatches(basename(f), regexpr("20[0-9]{2}", basename(f))))
  d <- data.frame(edition = ed, file = f, stringsAsFactors = FALSE)
  d <- d[order(d$edition), ]
  d$layout <- ifelse(d$edition <= 2017, "A", ifelse(d$edition == 2018, "B", "C"))
  stopifnot(!anyDuplicated(d$edition))
  rownames(d) <- NULL
  d
}

# Words ------------------------------------------------------------------------

# Every word of a PDF with page, line, x, x2 (right edge), y. Lines are y-clusters 2.5 pt apart; kerning splits are
# rejoined. Returns a data frame sorted by page, y, x.
sk_words <- function(file) {
  pg <- pdftools::pdf_data(file)
  out <- vector("list", length(pg))
  for (p in seq_along(pg)) {
    d <- pg[[p]]
    if (!nrow(d)) next
    d <- d[order(d$y, d$x), ]
    d$line <- cumsum(c(TRUE, diff(d$y) > 2.5))
    d <- d[order(d$line, d$x), ]
    n <- nrow(d)
    brk <- c(TRUE, d$line[-1] != d$line[-n] | d$space[-n] | d$x[-1] - (d$x[-n] + d$width[-n]) > 1.5)
    g <- cumsum(brk)
    out[[p]] <- data.frame(
      page = p,
      line = tapply(d$line, g, `[`, 1),
      x    = tapply(d$x, g, min),
      x2   = tapply(d$x + d$width, g, max),
      y    = tapply(d$y, g, min),
      text = tapply(d$text, g, paste0, collapse = ""),
      stringsAsFactors = FALSE)
  }
  w <- do.call(rbind, out)
  w <- w[order(w$page, w$line, w$x), ]
  # a decimal part printed apart from its integer ("0 ,84", 2006): joined when they nearly touch
  j <- which(grepl("^,[0-9]+$", w$text) & c(FALSE, grepl("^-?[0-9]+$", w$text[-nrow(w)])) &
             c(FALSE, w$page[-1] == w$page[-nrow(w)] & w$line[-1] == w$line[-nrow(w)]) & c(FALSE, w$x[-1] - w$x2[-nrow(w)] < 6))
  if (length(j)) {
    w$text[j - 1] <- paste0(w$text[j - 1], w$text[j]); w$x2[j - 1] <- w$x2[j]
    w <- w[-j, ]
  }
  w <- w[order(w$page, w$y, w$x), ]
  rownames(w) <- NULL
  w
}

# Numbers ----------------------------------------------------------------------

# Icelandic print: decimal comma, an optional dot or space before each group of three ("1.694,21"). "-" and "–" are
# printed for none.
sk_num <- function(s) {
  s <- trimws(s)
  s[s %in% c("-", "–", "‐", "")] <- NA
  s <- sub(",$", "", s)
  s <- gsub("(?<=[0-9])[. ](?=[0-9]{3}(,|$))", "", s, perl = TRUE)
  suppressWarnings(as.numeric(sub(",", ".", s, fixed = TRUE)))
}
# A number as the register prints a measure: decimal comma, a trailing comma with the decimals cut ("1310,", 2004-2006),
# a bare integer where the decimals are zero ("3" for 3,00, 2005), or a dash for none. Years, IMO numbers and kW are
# taken out by type before measures are read.
sk_is_num <- function(s) grepl("^-?[0-9]{1,3}([. ][0-9]{3})*(,[0-9]*)?$|^-?[0-9]+(,[0-9]*)?$|^[-–‐]$", s)

# The district letters (umdæmisbókstafir) of the register's key, and the number that may follow
DISTRICTS   <- c("AK", "ÁR", "BA", "DA", "EA", "GK", "HF", "HU", "ÍS", "IS", "KE", "KO", "KÓ", "MB", "NK", "NS", "ÓF", "OF",
                 "RE", "SF", "SH", "SI", "SK", "ST", "SU", "VE", "VS", "ÞH")
DISTRICT_RE <- paste0("^(", paste(DISTRICTS, collapse = "|"), ")[-–‐]?[0-9]{0,3}\\.?$")   # "RE005", "AK-010", "EA."
CALLSIGN_RE <- "^TF[A-Z]{2}$"
CLASS_SET   <- c("SI", "SS", "LR", "NV", "BV", "GL", "AB", "RS", "KR", "DNV", "RINA", "IRS")
# Running heads, titles and page numbers, matched as whole lines: a boat owned by "Siglingastofnun Íslands" prints
# that name inside its entry (7385, 2009-2014)
PAGE_FURNITURE_RE <- paste0("^(Siglingastofnun [ÍíI]slands|Samgöngustofa|",
                            "Skrá yfir íslensk[a]? skip[a]? og báta( [0-9]{4})?(, bls\\. [0-9]+)?|",
                            "Skipaskrá 1\\. janúar [0-9]{4} - (þilfarsskip|opnir bátar)\\.?|Register of .*|",
                            "Skráð þilfarsskip samkvæmt.*|Skrá yfir opna báta.*|Skráðir opnir bátar.*|[0-9]{1,3})$|\\.qxd")

# Left-right edge -------------------------------------------------------------------

# Lines 4 and 5 hold the owner and the address on the left, the engine and the changes right of the middle column.
# When the left text runs up to that column the split by position may be wrong, and the entry is flagged.
sk_edge <- function(left, right, xmid) {
  nrow(left) > 0 && nrow(right) > 0 && (min(right$x) - max(left$x2) < 4 || max(left$x2) > xmid - 3)
}

# Layout A ---------------------------------------------------------------------

# Hull materials as the key lists them, and as printed (longest first, so "FURA OG EIK" wins over "EIK").
MATERIAL_RE <- paste0("(^| )(FURA OG EIK|FURA OG MAHÓGNI|FURA OG MAHÓ|TREFJAPLAST|STEINSTEYPA|KROSSVIÐUR|MAHÓGNI|MAHOGNI|",
                      "STEINSTEYP|MAHÓNÍ|TREFJAR|ÓÞEKKT|LERKI|PLAST|STÁL|FURA|EIK|ÁL|TRÉ|JÁRN|GÚMMÍ|ANNAÐ)$")
# A type of ship: the key's glossary ends nearly all of them in -SKIP or -BÁTUR; the rest are listed
SHIPTYPE_RE <- "(SKIP|BÁTUR|PRAMMI|FLOTBRYGGJA|FLOTKVÍ|ÓTILGREINT)$"

# The register's five-line blocks, 2004-2017. One row per entry, values as printed. `section` is decked or open by
# the page's place in the edition.
#
# An entry's cells are printed at tab stops, and in 2007 an empty cell is sometimes left out, so the cells after it
# stand one stop to the left (2007, p. 25: the place built in the district's column, the year in the place's). So a
# token is typed by what it is before where it stands: a 4-digit integer is a year, 7 digits an IMO number, a district
# from the key's letters, a material from the key's list, and a line's measures are taken in order when it has as
# many as it has numeric columns. Position decides only what content cannot: which measure a lone number is, and
# where the name ends and the place begins when no district is printed.
sk_parse_A <- function(file, edition) {
  W <- sk_words(file)
  # the first header line of a register page holds "Sknr."/"Skrnr." and "Smíðastaður"/"Smíðast"
  key <- paste(W$page, W$line)
  h1_keys <- unique(key[grepl("^S(k|kr)nr", W$text)])
  h1_keys <- h1_keys[h1_keys %in% unique(key[grepl("^Smíðasta", W$text)])]
  H1 <- W[key %in% h1_keys, ]
  reg_pages <- sort(unique(H1$page))
  if (!length(reg_pages)) stop("no register pages found in ", basename(file))
  pagetext <- tapply(W$text, W$page, paste, collapse = " ")
  open_hit <- as.integer(names(pagetext))[grepl("opna báta|opnir bátar|Open Boats|Undecked", pagetext, ignore.case = TRUE)]
  open_start <- suppressWarnings(min(open_hit[open_hit > min(reg_pages)]))
  rows <- vector("list", 0)
  for (p in reg_pages) {
    yh <- min(H1$y[H1$page == p])
    Wp <- W[W$page == p, ]
    # the header block: lines within 60 pt of its first, merged when 4.5 pt apart (2012-2013 print "IMO-nr." 3 pt
    # above the line it belongs to)
    hy <- sort(unique(Wp$y[Wp$y >= yh - 1 & Wp$y <= yh + 60]))
    grp <- cumsum(c(TRUE, diff(hy) > 4.5))
    hdr_y <- tapply(hy, grp, max)[1:5]
    if (anyNA(hdr_y)) stop("page ", p, " of ", basename(file), ": fewer than five header lines")
    hdr_top <- tapply(hy, grp, min)[1:5]
    off <- as.numeric(hdr_y - hdr_y[1])
    hl <- lapply(1:5, function(k) { w <- Wp[Wp$y >= hdr_top[k] - 1 & Wp$y <= hdr_y[k] + 1, ]; w[order(w$x), ] })
    a <- sk_anchors_A(hl)
    body <- Wp[Wp$y > max(hdr_y) + 2, ]
    bl <- stats::aggregate(list(y = body$y, x0 = body$x), by = list(line = body$line), FUN = min)
    bl$first <- vapply(bl$line, function(l) { b <- body[body$line == l, ]; b$text[which.min(b$x)] }, "")
    bl$txt <- vapply(bl$line, function(l) paste(body$text[body$line == l], collapse = " "), "")
    bl <- bl[order(bl$y), ]
    bl <- bl[!grepl(PAGE_FURNITURE_RE, bl$txt), ]
    heads <- which(abs(bl$x0 - a$xsk) < 14 & grepl("^[0-9]{1,5}$", bl$first))
    for (k in seq_along(heads)) {
      i <- heads[k]
      y0 <- bl$y[i]
      y1 <- if (k < length(heads)) bl$y[heads[k + 1]] else Inf
      cand <- bl[bl$y > y0 & bl$y < y1 & bl$y - y0 < off[5] + 22, ]
      # a line of measures alone at the left (2005, 2007: GRT and length printed under line 1) belongs to line 1
      stray <- vapply(cand$line, function(l) { b <- body[body$line == l, ]
        all(sk_is_num(b$text)) && any(grepl(",", b$text)) && min(b$x) < a$xmid - 4 }, TRUE)   # not an address "- 220"
      l1 <- c(bl$line[i], cand$line[stray])
      cand <- cand[!stray, ]
      # lines 2-5 in order, after joining lines under 4.5 pt apart (2017 prints the torque index 3 pt above the
      # address); by offset from the header only when more than four remain
      grp <- cumsum(c(TRUE, diff(cand$y) > 4.5))
      slot <- if (max(c(0, grp)) <= 4) grp + 1L else vapply(cand$y - y0, function(d) which.min(abs(off[2:5] - d)) + 1L, 1L)
      L <- lapply(1:5, function(s) {
        ln <- if (s == 1) l1 else cand$line[slot == s]
        w <- body[body$line %in% ln, ]
        w[order(w$x), ]
      })
      rows[[length(rows) + 1]] <- sk_fields_A(L, a, p, y0, edition,
                                              if (is.finite(open_start) && p >= open_start) "open" else "decked")
    }
  }
  out <- do.call(rbind, rows)
  out$open_start <- open_start
  out
}

# Column anchors of one register page, from its five header lines: the left edges of the text columns, and the right
# edges of the measure columns (measures are printed right-aligned under their label).
sk_anchors_A <- function(hl) {
  x_of  <- function(w, re) { i <- grep(re, w$text); if (length(i)) w$x[i[1]] else NA_real_ }
  x2_of <- function(w, re) { i <- grep(re, w$text); if (length(i)) w$x2[i[length(i)]] else NA_real_ }
  list(
    xsk = x_of(hl[[1]], "^S(k|kr)nr"), xumd = x_of(hl[[1]], "^Umd"), xmid = x_of(hl[[1]], "^Smíðasta"),
    has_class = any(grepl("^Flokkunarf", hl[[2]]$text)),
    x2year = x2_of(hl[[1]], "^Smíðaár"),
    num = list(c(grt = x2_of(hl[[1]], "^Brl"), length_reg = x2_of(hl[[1]], "^lengd")),
               c(gt = x2_of(hl[[2]], "^Bt"), breadth = x2_of(hl[[2]], "^breidd")),
               c(nt = x2_of(hl[[3]], "^Nt"), depth = x2_of(hl[[3]], "^dýpt")),
               c(loa = x2_of(hl[[4]], "^lengd")),
               c(power_index = x2_of(hl[[5]], "^Aflv"))))
}

# A line's measures. With as many measures as the line has measure columns, they are taken in order; otherwise each
# goes to the column whose label's right edge is nearest (within 22 pt). Returns the values and the words left over.
sk_assign_num <- function(w, anchors) {
  anchors <- anchors[!is.na(anchors)]
  val <- stats::setNames(rep(NA_character_, length(anchors)), names(anchors))
  isn <- if (nrow(w)) sk_is_num(w$text) else logical(0)
  if (!any(isn) || !length(anchors)) return(list(val = val, text = w, shifted = FALSE))
  j <- which(isn)
  if (length(j) == length(anchors)) {
    val[order(anchors)] <- w$text[j]
    d <- abs(w$x2[j] - sort(anchors))
    return(list(val = val, text = w[-j, , drop = FALSE], shifted = any(d > 22)))
  }
  used <- rep(FALSE, nrow(w))
  for (jj in j) {
    d <- abs(w$x2[jj] - anchors)
    if (min(d) < 22) { nm <- names(anchors)[which.min(d)]; if (is.na(val[nm])) { val[nm] <- w$text[jj]; used[jj] <- TRUE } }
  }
  list(val = val, text = w[!used, , drop = FALSE], shifted = FALSE)
}

sk_fields_A <- function(L, a, page, y, edition, section) {
  note <- character(0)
  xmid <- a$xmid
  lr <- function(w) list(left = w[w$x < xmid - 4, , drop = FALSE], right = w[w$x >= xmid - 4, , drop = FALSE])
  pc <- function(t) if (length(t)) paste(t, collapse = " ") else NA_character_
  # line 1: number, name, district, place built, year built, GRT, registered length. Read whole: none of it is personal.
  w1 <- L[[1]]
  j <- grep("[^0-9 ](1[5-9]|20)[0-9]{2}$", w1$text)            # a place printed into the year ("HAFNARFJÖRÐU1987")
  for (jj in rev(j)) {
    t <- w1$text[jj]; yr <- substr(t, nchar(t) - 3, nchar(t))
    w1 <- rbind(w1, transform(w1[jj, ], text = yr, x = x2 - 1))
    w1$text[jj] <- substr(t, 1, nchar(t) - 4)
    note <- c(note, "place_year_joined")
  }
  # the number opens the head line; measures merged in from a line below may stand left of it
  hd <- which(abs(w1$y - min(w1$y)) < 2.5)
  k1 <- hd[which.min(w1$x[hd])]
  sknr <- w1$text[k1]
  w1 <- w1[-k1, , drop = FALSE]
  # the head line reads before what wrapped below it: in 2007 the GRT stays at the line's end and the length wraps to
  # the next line's left margin (1764, 1929), so ordering by x alone swapped them
  w1 <- w1[order(w1$y > min(w1$y) + 2.5, w1$x), ]
  # the trailing run of numbers is year built, GRT and registered length, any of which may be blank. A 4-digit integer
  # opening the run is the year when the run has three, or when it stands nearer the year's column than the GRT's.
  # measures merged in from the line below (2005, 2007) are line 1's GRT and length; the head line's year is then its
  # 4-digit integer, wherever it stands
  below <- w1$y > min(w1$y) + 2.5
  if (any(below)) {
    iy <- which(!below & grepl("^((1[5-9]|20)[0-9]{2}|0000)$", w1$text))
    built_year <- if (length(iy)) w1$text[iy[length(iy)]] else NA_character_
    if (length(iy)) w1 <- w1[-iy[length(iy)], , drop = FALSE]
    note <- c(note, "line1_measures_below")
  }
  isn <- sk_is_num(w1$text) | grepl("^[0-9]{4}$", w1$text)
  run <- 0L
  while (run < min(3L, nrow(w1)) && isn[nrow(w1) - run]) run <- run + 1L
  if (!any(below)) built_year <- NA_character_
  if (!any(below) && run >= 2) {
    f <- nrow(w1) - run + 1
    nearer_year <- !is.na(a$x2year) && abs(w1$x2[f] - a$x2year) < abs(w1$x2[f] - a$num[[1]][["grt"]])
    # an unknown year is printed "0000", or in 2005 a bare "0" in the year's column
    yearish <- grepl("^((1[5-9]|20)[0-9]{2}|0000)$", w1$text[f]) || (w1$text[f] == "0" && nearer_year)
    if (yearish && (run == 3 || nearer_year)) { built_year <- w1$text[f]; w1 <- w1[-f, , drop = FALSE] }
  }
  n1 <- sk_assign_num(w1, a$num[[1]])
  r <- n1$text
  if (is.na(built_year)) {
    iy <- grep("^((1[5-9]|20)[0-9]{2}|0000)$", r$text)
    if (length(iy)) { built_year <- r$text[iy[length(iy)]]; r <- r[-iy[length(iy)], , drop = FALSE] }
  }
  # a district printed onto the name without a space ("GUÐBRANDSDÓTTIRAK"): split where the name's last word ends in one
  jn <- which(grepl(paste0("[A-ZÁÐÉÍÓÚÝÞÆÖ]{3}(", paste(DISTRICTS, collapse = "|"), ")[0-9]{0,3}$"), r$text) & !grepl(DISTRICT_RE, r$text) &
              !is.na(a$xumd) & r$x2 >= a$xumd)
  if (length(jn) && !length(grep(DISTRICT_RE, r$text))) {
    jj <- jn[1]; t <- r$text[jj]
    d <- regmatches(t, regexpr(paste0("(", paste(DISTRICTS, collapse = "|"), ")[0-9]{0,3}$"), t))
    r <- rbind(r[seq_len(jj), ], transform(r[jj, ], text = d, x = x2 - 1), r[-seq_len(jj), ])
    r$text[jj] <- substr(t, 1, nchar(t) - nchar(d))
    note <- c(note, "name_district_joined")
  }
  # the district is the first word after the name that reads as one: a place can hold a word like "OF" ("ISLE OF
  # WIGHT"), a name rarely does
  id <- grep(DISTRICT_RE, r$text)
  id <- id[id > 1]
  if (length(id)) {
    d <- id[1]
    district <- r$text[d]; nm <- r[seq_len(d - 1), , drop = FALSE]; place <- r[-seq_len(d), , drop = FALSE]
  } else {
    district <- NA_character_
    # no district: the name is the first run of words, the place what follows a wide gap or stands right of mid
    gap <- c(Inf, r$x[-1] - r$x2[-nrow(r)])
    cut <- which(seq_len(nrow(r)) > 1 & (gap > 12 | r$x >= xmid - 4))[1]
    if (is.na(cut)) { nm <- r; place <- r[0, ] } else { nm <- r[seq_len(cut - 1), ]; place <- r[cut:nrow(r), ] }
  }
  if (n1$shifted || (nrow(place) && min(place$x) < xmid - 4)) note <- c(note, "line1_shifted")
  # line 2: class society, call sign, home port | yard, GT, breadth
  l2 <- lr(L[[2]])
  bl <- l2$left$text
  cls <- NA_character_; cs <- NA_character_
  if (a$has_class && length(bl) && bl[1] %in% CLASS_SET) {
    cls <- bl[1]; bl <- bl[-1]
    if (length(bl) >= 2 && tolower(bl[1]) == "ex" && bl[2] %in% CLASS_SET) { cls <- paste(cls, "ex", bl[2]); bl <- bl[-(1:2)] }
  }
  if (length(bl) && grepl(CALLSIGN_RE, bl[1])) { cs <- bl[1]; bl <- bl[-1] }
  n2 <- sk_assign_num(l2$right, a$num[[2]])
  if (n2$shifted) note <- c(note, "line2_shifted")
  # line 3: previous name, type of ship, hull material, NT, depth
  w3 <- L[[3]]
  n3 <- sk_assign_num(w3, a$num[[3]])
  r3 <- n3$text
  hull <- NA_character_; ship_type <- NA_character_; prev <- NA_character_
  if (nrow(r3)) {
    gap <- c(Inf, r3$x[-1] - r3$x2[-nrow(r3)])
    cell <- cumsum(gap > 8 | (r3$x >= xmid - 4 & c(TRUE, r3$x[-nrow(r3)] < xmid - 4)))
    cells <- tapply(r3$text, cell, paste, collapse = " ")
    cx <- tapply(r3$x, cell, min)
    last <- cells[length(cells)]
    m <- regmatches(last, regexpr(MATERIAL_RE, last, ignore.case = TRUE))
    if (length(m)) {
      hull <- trimws(m)
      rest_last <- trimws(substr(last, 1, nchar(last) - nchar(m)))
      cells[length(cells)] <- rest_last
      cells <- cells[nzchar(cells)]; cx <- cx[names(cells)]
    } else if (grepl("(STÁL|EIK|TREFJAPLAST)$", last) && nchar(last) > 9) {
      # a type printed into the material's column, without a space ("ÞANGSKURÐARPRAMMSTÁL")
      hull <- regmatches(last, regexpr("(STÁL|EIK|TREFJAPLAST)$", last))
      cells[length(cells)] <- substr(last, 1, nchar(last) - nchar(hull))
      note <- c(note, "type_material_joined")
    } else note <- c(note, "no_hull_material")
    # the type is the cell right of mid, or, on a shifted line, the last cell that reads as a type
    rt <- which(cx >= xmid - 4)
    if (length(rt)) {
      ship_type <- paste(cells[rt], collapse = " "); prev <- pc(cells[-rt])
    } else if (length(cells) && grepl(SHIPTYPE_RE, cells[length(cells)])) {
      ship_type <- cells[length(cells)]; prev <- pc(cells[-length(cells)]); note <- c(note, "line3_shifted")
    } else prev <- pc(cells)
  }
  if (n3$shifted) note <- c(note, "line3_shifted")
  # line 4: owner | engine make, engine year, kW, IMO, length overall
  w4 <- L[[4]]
  kw <- NA_character_; eyear <- NA_character_; imo <- NA_character_
  ik <- which(w4$text == "kW")
  if (length(ik) && ik[1] > 1 && grepl("^[0-9]+$", w4$text[ik[1] - 1])) { kw <- w4$text[ik[1] - 1]; w4 <- w4[-c(ik[1] - 1, ik[1]), ] }
  ia <- grep("^árg\\.?$", w4$text)
  if (length(ia) && nrow(w4) > ia[1] && grepl("^[0-9]{4}$", w4$text[ia[1] + 1])) { eyear <- w4$text[ia[1] + 1]; w4 <- w4[-c(ia[1], ia[1] + 1), ] }
  else if (length(ia) && nrow(w4) > ia[1] && w4$text[ia[1] + 1] == "0") { eyear <- "0"; w4 <- w4[-(ia[1] + 1), ] }   # "árg. 0": unknown
  i7 <- grep("^[0-9]{7}$", w4$text)
  if (length(i7)) { imo <- w4$text[i7[1]]; w4 <- w4[-i7[1], ] }
  l4 <- lr(w4)
  if (sk_edge(l4$left, l4$right, xmid)) note <- c(note, "line4_edge")
  owner <- pc(l4$left$text)
  n4 <- sk_assign_num(l4$right, a$num[[4]])
  emake <- pc(n4$text$text[!n4$text$text %in% c("kW", "árg.", "árg")])
  # line 5: address | changes, IMO (2004-2007), torque index
  l5 <- lr(L[[5]])
  if (sk_edge(l5$left, l5$right, xmid)) note <- c(note, "line5_edge")
  address <- pc(l5$left$text)
  r5 <- l5$right
  i7 <- grep("^[0-9]{7}$", r5$text)
  if (length(i7)) { if (is.na(imo)) imo <- r5$text[i7[1]]; r5 <- r5[-i7[1], ] }
  n5 <- sk_assign_num(r5, a$num[[5]])
  changes <- pc(n5$text$text)
  g <- function(v, nm) if (nm %in% names(v)) v[[nm]] else NA_character_
  data.frame(
    edition = edition, section = section, page = page, y = round(y, 1),
    sknr = sknr, name = pc(nm$text), district = district,
    class_society = cls, call_sign = cs, home_port = pc(bl), previous_name = prev, owner = owner, address = address,
    built_place = pc(place$text), built_year = built_year, yard = pc(n2$text$text),
    ship_type = ship_type, hull_material = hull,
    engine_make = emake, engine_year = eyear, engine_kw = kw, imo = imo, changes = changes,
    grt = g(n1$val, "grt"), length_reg = g(n1$val, "length_reg"), gt = g(n2$val, "gt"), breadth = g(n2$val, "breadth"),
    nt = g(n3$val, "nt"), depth = g(n3$val, "depth"), loa = g(n4$val, "loa"), power_index = g(n5$val, "power_index"),
    n_lines = sum(vapply(L, nrow, 1L) > 0), note = pc(unique(note)),
    stringsAsFactors = FALSE)
}

# Layouts B and C --------------------------------------------------------------

# Header label (as printed in 2018-2022) -> field.
BC_LABELS <- list(
  row1 = c("^(Nr|Númer)" = "sknr", "^[Nn]afn$" = "name", "^fl\\." = "class_society", "^[Ff]yrra" = "previous_name",
           "^[Ee]igandi" = "owner", "^[Hh]eimili" = "address", "^[Kk]all" = "call_sign", "^[Uu]md" = "district",
           "^[Hh]eimah" = "home_port", "sta[ðd]ur" = "built_place", "st(ö|o)[ðd]" = "yard",
           "([Ss]m[ií][ðd]a?(ár|aar|ar)$|(-|‐) ár$|^ár$)" = "built_year"),
  row2 = c("^(Nr|Númer)" = "sknr", "^([Nn]otk|Notkunarteg)" = "ship_type", "^[Ee]fni" = "hull_material", "^Aðalvél" = "engine_make",
           "^br\\. r" = "grt", "^br\\. tonn" = "gt", "^(nt\\.|nettó)" = "nt", "^IMO" = "imo", "^[Ss]kr\\. lengd" = "length_reg",
           "breidd" = "breadth", "d[ýy]pt" = "depth", "^[Mm]esta" = "loa", "^aflv" = "power_index", "^afl vélar" = "engine_kw"))
# The words that make up those labels; anything else in the header band is a wrapped cell of the first entry.
BC_HEADER_WORDS <- paste0("^(Nr\\.|Númer|Nafn|nafn|fl\\.|fél\\.?|[Ff]yrra|[Ee]igandi|[Hh]eimilisfang|[Hh]eimili|heimilieiganda|eiganda|",
                          "[Kk]all(-|‐)|merki|[Uu]md\\.?(nr\\.?)?|umdnr|nr\\.|[Hh]eimah(ö|o)fn|smidaár|smidaar|Smíðaár|[Ss]m[ií]ða(-|‐)|ár|",
                          "[Ss]m[ií]ðastaður|smidastadur|staður|[Ss]m[ií]ð(a)?stöð|smidastod|stöð|[Ss]kr\\.|breidd|d[ýy]pt|Notkunarteg|",
                          "[Nn]otk\\.|teg|[Ee]fni|Aðalvél|br\\.|r[úu]ml\\.|tonn|nt\\.|nettó|IMO|lengd|[Mm]esta|aflv\\.|afl|vélar)$")

BC_NUMERIC <- c("sknr", "built_year", "grt", "gt", "nt", "imo", "length_reg", "breadth", "depth", "loa", "power_index", "engine_kw")

# Columns of one header block: words clustered left to right (a new column where a word starts clear of the last),
# each named by its label.
sk_columns_BC <- function(hw, labels, gap = 4) {
  hw <- hw[order(hw$x), ]
  col <- integer(nrow(hw)); k <- 0L; right <- -Inf
  for (i in seq_len(nrow(hw))) { if (hw$x[i] > right + gap) k <- k + 1L; col[i] <- k; right <- max(right, hw$x2[i]) }
  lab <- tapply(seq_len(nrow(hw)), col, function(ii) { o <- ii[order(hw$y[ii], hw$x[ii])]; paste(hw$text[o], collapse = " ") })
  x0 <- tapply(hw$x, col, min)
  field <- vapply(lab, function(l) {
    hit <- which(vapply(names(labels), function(re) grepl(re, l), TRUE))
    if (length(hit)) unname(labels[hit[1]]) else "?"
  }, "")
  data.frame(x = as.numeric(x0), label = unname(lab), field = unname(field), stringsAsFactors = FALSE)
}

# The register's two-line rows, 2018-2022. One row per entry, values as printed.
sk_parse_BC <- function(file, edition, layout) {
  W <- sk_words(file)
  # a header line holds "Nr."/"Númer" at the left margin, and "Nafn" and "fl." on the same line (a vessel named
  # "Flotkví Nr. 1" holds the first only)
  key <- paste(W$page, W$line)
  hk <- intersect(intersect(key[grepl("^(Nr\\.|Númer)$", W$text) & W$x < 80], key[grepl("^[Nn]afn$", W$text)]),
                  key[grepl("^fl\\.", W$text)])
  nr <- W[key %in% hk & grepl("^(Nr\\.|Númer)$", W$text), ]
  hpages <- sort(unique(nr$page))
  if (length(hpages) < 2) stop(basename(file), ": expected two section headers, found ", length(hpages))
  sec <- data.frame(page = hpages[1:2], section = c("decked", "open"))
  cols <- list(); body <- list()
  for (s in 1:2) {
    p <- sec$page[s]
    Wp <- W[W$page == p, ]
    y1 <- min(nr$y[nr$page == p])
    y2 <- min(Wp$y[grepl("^(Notkunarteg|notk|Notk)", Wp$text) & Wp$y > y1])
    hb <- Wp[grepl(BC_HEADER_WORDS, Wp$text), ]
    c1 <- sk_columns_BC(hb[hb$y >= y1 - 13 & hb$y <= y1 + 8, ], BC_LABELS$row1)
    c2 <- sk_columns_BC(hb[hb$y >= y2 - 8 & hb$y <= y2 + 8, ], BC_LABELS$row2)
    bad <- c(c1$label[c1$field %in% "?"], c2$label[c2$field %in% "?"])
    if (length(bad)) stop(basename(file), " ", sec$section[s], ": unread header labels: ", paste(bad, collapse = ", "))
    cols[[s]] <- list(row1 = c1, row2 = c2, y_end = max(hb$y[hb$y <= y2 + 8]))
  }
  last_page <- max(W$page)
  rows <- list()
  for (s in 1:2) {
    p0 <- sec$page[s]; p1 <- if (s == 1) sec$page[2] - 1 else last_page
    cc <- cols[[s]]
    xsk <- cc$row1$x[cc$row1$field %in% "sknr"]
    B <- W[W$page >= p0 & W$page <= p1 & !(W$page == p0 & W$y <= cc$y_end), ]
    ln <- stats::aggregate(list(y = B$y, x0 = B$x), by = list(page = B$page, line = B$line), FUN = min)
    ln$first <- mapply(function(p, l) { b <- B[B$page == p & B$line == l, ]; b$text[which.min(b$x)] }, ln$page, ln$line)
    ln$txt <- mapply(function(p, l) paste(B$text[B$page == p & B$line == l], collapse = " "), ln$page, ln$line)
    ln <- ln[order(ln$page, ln$y), ]
    ln$row <- abs(ln$x0 - xsk) < 10 & grepl("^[0-9]{1,4}$", ln$first)
    # stop at the end of the register (the name-prerogative list follows the open boats)
    stop_at <- which(grepl("Einkaréttur|Sérleyfisnafn", ln$txt))
    if (length(stop_at)) ln <- ln[seq_len(stop_at[1] - 1), ]
    titles <- grepl(PAGE_FURNITURE_RE, ln$txt) & !ln$row
    # a page number or title line far from any row is furniture; a lone number next to a row is a wrapped cell
    near_row <- vapply(seq_len(nrow(ln)), function(i) any(ln$row & ln$page == ln$page[i] & abs(ln$y - ln$y[i]) < 16), TRUE)
    ln <- ln[!(titles & !(grepl("^[0-9]+$", ln$txt) & near_row)), ]
    R <- which(ln$row)
    # pair the two lines of each vessel
    k <- 1
    pairs <- list()
    while (k <= length(R)) {
      i <- R[k]
      if (k < length(R) && ln$first[R[k + 1]] == ln$first[i]) { pairs[[length(pairs) + 1]] <- c(i, R[k + 1]); k <- k + 2 }
      else { pairs[[length(pairs) + 1]] <- c(i, NA); k <- k + 1 }
    }
    frag <- which(!ln$row)
    owner_of <- rep(NA_integer_, nrow(ln))        # the row line a fragment belongs to
    for (f in frag) {
      cand <- R[ln$page[R] == ln$page[f]]
      if (!length(cand)) next
      d <- ln$y[cand] - ln$y[f]
      if (layout == "C") {
        # 2019-2022 wrap a cell upwards, up to two lines above its row (25 pt: "Elding / Hvalaskoðun / Reykjav ehf.",
        # 2020); a fragment goes to a row below it within 30 pt where its words fall in columns of their kind
        pick <- which(d > 0 & d < 30)
        if (length(pick) > 1 || !length(pick)) {
          if (!length(pick)) pick <- which(abs(d) < 16)
          fw <- B[B$page == ln$page[f] & B$line == ln$line[f], ]
          fit <- vapply(cand[pick], function(j) {
            cdef <- if (j %in% vapply(pairs, `[`, 1, 1)) cc$row1 else cc$row2
            fld <- cdef$field[pmax(findInterval(fw$x + 6, cdef$x), 1)]
            sum((fld %in% BC_NUMERIC) == (sk_is_num(fw$text) | grepl("^[0-9]+$", fw$text)))
          }, 0)
          pick <- pick[fit == max(fit)]
        }
        pick <- if (length(pick)) pick[which.min(abs(d[pick]))] else NA
      }
      else {
        # 2018 centres a two-line cell on its row, so a fragment may stand as near the next vessel's first line as this
        # one's second ("Köfunar-" 7 pt under 1629's measures): it goes where its words fall in columns of their kind
        pick <- which(abs(d) < 16)
        if (length(pick) > 1) {
          fw <- B[B$page == ln$page[f] & B$line == ln$line[f], ]
          fit <- vapply(cand[pick], function(j) {
            first_row <- j %in% vapply(pairs, `[`, 1, 1)
            cdef <- if (first_row) cc$row1 else cc$row2
            fld <- cdef$field[pmax(findInterval(fw$x + 6, cdef$x), 1)]
            sum((fld %in% BC_NUMERIC) == (sk_is_num(fw$text) | grepl("^[0-9]+$", fw$text)))
          }, 0)
          pick <- pick[fit == max(fit)]
        }
        pick <- if (length(pick)) pick[which.min(abs(d[pick]))] else NA
      }
      if (length(pick) && !is.na(pick)) owner_of[f] <- cand[pick]
    }
    for (pr in pairs) {
      rec <- list()
      for (r in 1:2) {
        i <- pr[r]
        if (is.na(i)) next
        lines_r <- c(i, which(owner_of == i))
        w <- do.call(rbind, lapply(lines_r, function(j) B[B$page == ln$page[j] & B$line == ln$line[j], ]))
        cdef <- if (r == 1) cc$row1 else cc$row2
        ci <- findInterval(w$x + 6, cdef$x)
        w$field <- ifelse(ci >= 1, cdef$field[pmax(ci, 1)], NA)
        w <- w[!is.na(w$field), ]                   # words left of the first column
        w <- w[order(w$y, w$x), ]
        for (f in unique(w$field)) rec[[f]] <- paste(w$text[w$field == f], collapse = if (f == "imo") "" else " ")
      }
      rec$sknr <- ln$first[pr[1]]
      rec$page <- ln$page[pr[1]]; rec$y <- round(ln$y[pr[1]], 1)
      rec$n_lines <- sum(!is.na(pr))
      rows[[length(rows) + 1]] <- c(rec, section = sec$section[s])
    }
  }
  fields <- c("sknr", "name", "district", "class_society", "call_sign", "home_port", "previous_name", "owner", "address", "built_place",
              "built_year", "yard", "ship_type", "hull_material", "engine_make", "engine_kw", "imo", "grt", "length_reg",
              "gt", "breadth", "nt", "depth", "loa", "power_index")
  out <- do.call(rbind, lapply(rows, function(r) {
    v <- lapply(fields, function(f) if (is.null(r[[f]])) NA_character_ else r[[f]])
    names(v) <- fields
    data.frame(edition = edition, section = r$section, page = r$page, y = r$y, v, n_lines = r$n_lines,
               stringsAsFactors = FALSE)
  }))
  # text in the call-sign column that is no call sign has run over from the address: moved back to it, flagged
  odd <- !is.na(out$call_sign) & !grepl(CALLSIGN_RE, out$call_sign)
  out$note <- ifelse(odd, "address_into_callsign_column", NA_character_)
  out$address[odd] <- trimws(paste(ifelse(is.na(out$address[odd]), "", out$address[odd]), out$call_sign[odd]))
  out$call_sign[odd] <- NA_character_
  out$note[out$n_lines < 2] <- paste(na.omit(c(out$note[out$n_lines < 2], "second_line_missing")), collapse = "; ")
  out$engine_year <- NA_character_; out$changes <- NA_character_
  out
}

# Registrations and deregistrations ---------------------------------------------------

# Header label -> field, for the lists of the previous year's registrations and deregistrations (all layouts).
EVENT_LABELS <- c("^(Sknr|Skipanr|Skrnr|Skr\\.nr|Skipa(-|‐)?$|Skipa(-|‐)? ?nr|[Nn]r\\.?$)" = "sknr", "^(Nafn|Heiti)" = "name", "^Umd" = "district",
                  "^Heimah" = "home_port", "^(BT|Br\\.? ?[Tt]onn)" = "gt", "^(Afdrif|Athugasemd)" = "fate",
                  "^(Dags|Afskráð|afskráningar)" = "date", "^Frumskráð$" = "date", "^Gerð" = "deck_code",
                  "^Aths" = "remark", "^Síð" = "last_rereg")
DATE_RE <- "^[0-9]{1,2}\\.[0-9]{1,2}\\.(19|20)[0-9]{2}\\.?$"

# Every row of those lists in one edition, with the list it stands in (kind, sub-kind, section from the title above
# it) and the totals the lists print, for the checks. The lists stand before the register's first page.
sk_parse_events <- function(file, edition) {
  W <- sk_words(file)
  reg1 <- min(W$page[grepl("^Smíðasta", W$text) & W$page > 8])
  W <- W[W$page > 2 & W$page < reg1, ]
  ln <- stats::aggregate(list(y = W$y, x0 = W$x), by = list(page = W$page, line = W$line), FUN = min)
  ln$txt <- mapply(function(p, l) { w <- W[W$page == p & W$line == l, ]; paste(w$text[order(w$x)], collapse = " ") }, ln$page, ln$line)
  ln$first <- mapply(function(p, l) { w <- W[W$page == p & W$line == l, ]; w$text[which.min(w$x)] }, ln$page, ln$line)
  ln <- ln[order(ln$page, ln$y), ]
  squash <- function(t) tolower(gsub("\\s+", "", t))
  ln$is_header <- grepl("^(sknr|skipanr|skrnr|skr\\.nr|skipa|nr\\.?$)", squash(ln$first)) & grepl("(nafn|heiti)", squash(ln$txt))
  ln$nwords <- lengths(strsplit(trimws(ln$txt), "\\s+"))
  ctx <- list(kind = NA_character_, subkind = NA_character_, section = NA_character_)
  cols <- NULL; xsk <- NA
  rows <- list(); totals <- list(); row_line <- integer(0)
  for (i in seq_len(nrow(ln))) {
    t <- squash(ln$txt[i]); p <- ln$page[i]
    if (ln$is_header[i]) {
      hw <- W[W$page == p & abs(W$y - ln$y[i]) < 8, ]
      cols <- sk_columns_BC(hw, EVENT_LABELS, gap = 1.5)   # "Gerð" and "Br.Tonn" stand 3 pt apart (2016)
      cols <- cols[cols$field != "?", ]
      xsk <- cols$x[cols$field %in% "sknr"][1]
      next
    }
    count_line <- grepl("^[0-9]+$", ln$first[i]) && grepl("^[0-9.]+ ?(skip|bátar|bátur|opnir|opinn)", tolower(ln$txt[i]))
    if (grepl("(samtals|fjöldi|heildarfjöldi)[^0-9]*[0-9]", t) || count_line) {
      totals[[length(totals) + 1]] <- data.frame(edition = edition, page = p, kind = ctx$kind, subkind = ctx$subkind,
                                                 section = ctx$section, text = ln$txt[i], stringsAsFactors = FALSE)
      next
    }
    is_row <- !is.null(cols) && grepl("^[0-9]{1,5}$", ln$first[i]) && !is.na(xsk) && abs(ln$x0[i] - xsk) < 16
    if (!is_row) {
      # a short line is a title: it sets the list's kind, sub-kind and section; a paragraph of the preface does not
      if (nchar(t) > 55 || grepl("^[0-9]", ln$first[i])) next   # by letters: 2004 spaces its titles ("Af skr á ð")
      if (grepl("(íslenskþilfarsskip|aldurísl|meðalaldur|vélategund|skýringar|yfirlit|skoðunaraðili|fjöldiogstærð)", t)) {
        cols <- NULL; ctx$kind <- NA_character_; next          # the aggregate tables after the lists
      }
      has_kind <- grepl("(afskr|nýskr|frumskr|endurskr)", t)
      if (grepl("afskr", t)) ctx$kind <- "deregistration" else if (has_kind) ctx$kind <- "registration"
      if (has_kind || grepl("breytt", t)) {
        ctx$subkind <- if (grepl("opnumvélbátumbreytt", t)) "open_to_decked" else if (grepl("þilfarsskipibreytt", t)) "decked_to_open"
                       else if (grepl("endurskr", t) && !grepl("frumskr", t)) "re" else if (grepl("frumskr", t) && !grepl("endurskr", t)) "first"
                       else NA_character_
        sub_title <- grepl("^[a-c]\\)", t)              # "A) Frumskráð", "C) Endurskráðir": the section is the title's above
        ctx$section <- if (grepl("breytt", t)) { if (grepl("opnumvélbátumbreytt", t)) "decked" else "open" }
                       else if (grepl("(opnirbát|opinnbát|opnumbát|opnirbat)", t)) "open"
                       else if (grepl("(þilfarsskip|þilfasskip)", t)) "decked"
                       else if (sub_title) ctx$section else NA_character_
      }
      next
    }
    row_line <- c(row_line, i)
    rows[[length(rows) + 1]] <- list(i = i, page = p, y = ln$y[i], ctx = ctx, cols = cols)
  }
  if (!length(rows)) return(list(events = NULL, totals = do.call(rbind, totals)))
  # wrapped cells: a line with no number within 8 pt of a row on the same page joins the nearest row
  rl <- vapply(rows, function(r) r$i, 1L)
  out <- lapply(seq_along(rows), function(k) {
    r <- rows[[k]]
    near <- which(ln$page == r$page & abs(ln$y - r$y) < 8 & !seq_len(nrow(ln)) %in% rl & !ln$is_header)
    near <- near[vapply(near, function(j) { d <- abs(ln$y[rl] - ln$y[j]) + ifelse(ln$page[rl] == ln$page[j], 0, 1e6); rl[which.min(d)] == r$i }, TRUE)]
    w <- do.call(rbind, lapply(c(r$i, near), function(j) W[W$page == ln$page[j] & W$line == ln$line[j], ]))
    ci <- findInterval(w$x + 6, r$cols$x)
    w$field <- ifelse(ci >= 1, r$cols$field[pmax(ci, 1)], NA)
    # names may start left of their label (2012-2013: 45 pt): a word in the number's column is the name's
    first <- which(w$y == min(w$y) & w$x == min(w$x[w$y == min(w$y)]))[1]
    w$field[seq_len(nrow(w)) != first & w$field %in% "sknr"] <- "name"
    # cells do not always stand under their labels (2004: the fate 70 pt left of "Afdrif"; 2010: the date in the
    # district's column), so tokens are typed by content where position misleads
    has <- function(f) f %in% r$cols$field
    if (has("district") && !any(w$field %in% "district")) {
      jd <- which(grepl(DISTRICT_RE, w$text) & w$field %in% c("name", "fate", "home_port"))
      if (length(jd)) w$field[jd[1]] <- "district"
    }
    jd <- which(grepl(DATE_RE, w$text) & w$field %in% "district")
    w$field[jd] <- if (has("date")) "date" else "fate"
    if (has("date") && !any(w$field %in% "date")) {
      jd <- which(grepl(DATE_RE, w$text) & !w$field %in% "name")
      if (length(jd)) w$field[jd[length(jd)]] <- "date"
    }
    jn <- which(w$field %in% "date" & !grepl(DATE_RE, w$text) & sk_is_num(w$text))
    if (length(jn) && has("gt") && !any(w$field %in% "gt")) w$field[jn] <- "gt"
    if (has("gt")) {
      # GT holds the measure only: a word past it is a remark ("Endurskráð", 2012); a GT left of its label (2004) is the
      # row's last measure, wherever it stands
      w$field[w$field %in% "gt" & !sk_is_num(w$text)] <- "remark"
      if (!any(w$field %in% "gt")) {
        jg <- which(sk_is_num(w$text) & grepl(",", w$text) & w$field %in% c("home_port", "fate", "district", "remark"))
        if (length(jg)) w$field[jg[length(jg)]] <- "gt"
      }
    }
    if (identical(r$ctx$kind, "deregistration") && has("fate")) {
      nm <- which(w$field %in% "name"); nm <- nm[order(w$x[nm])]
      if (length(nm) > 1) {
        gap <- w$x[nm[-1]] - w$x2[nm[-length(nm)]]
        cut <- which(gap > 12)[1]
        if (!is.na(cut)) w$field[nm[(cut + 1):length(nm)]] <- "fate"
      }
    }
    w <- w[order(w$y, w$x), ]
    get <- function(f) { v <- w$text[w$field %in% f]; if (length(v)) paste(v, collapse = " ") else NA_character_ }
    vals <- stats::setNames(lapply(c("sknr", "name", "district", "home_port", "gt", "fate", "date", "deck_code", "remark", "last_rereg"), get),
                            c("sknr", "name", "district", "home_port", "gt", "fate", "date", "deck_code", "remark", "last_rereg"))
    vals$sknr <- ln$first[r$i]
    # the date of a deregistration may stand left of its label (2004): the row's last date is the date, an earlier one
    # belongs to the fate ("BRENNDUR 31.12.2001")
    if (is.na(vals$date) && "date" %in% r$cols$field && !is.na(vals$fate)) {
      ft <- strsplit(vals$fate, " ")[[1]]
      dd <- grep(DATE_RE, ft)
      if (length(dd)) { vals$date <- ft[dd[length(dd)]]; ft <- ft[-dd[length(dd)]]; vals$fate <- if (length(ft)) paste(ft, collapse = " ") else NA_character_ }
    }
    # a row of an aggregate table has no name; a note ("5 opnum vélbátum breytt í þilfarsskip") a lower-case one
    if (is.na(vals$name) || !grepl("^[A-ZÁÐÉÍÓÚÝÞÆÖ0-9]", vals$name)) return(NULL)
    data.frame(edition = edition, page = r$page, y = round(r$y, 1), kind = r$ctx$kind, subkind = r$ctx$subkind,
               section = r$ctx$section, vals, n_lines = 1 + length(near), stringsAsFactors = FALSE)
  })
  list(events = do.call(rbind, out), totals = do.call(rbind, totals))
}

# The lists after the register ----------------------------------------------------------

# Pages after the register, 2004-2013, hold two-block lists: draught and weight by number (2004-2006), the vessels by
# registration number and by call sign. One row per entry: the list, its key, and the entry's fields. The district
# list is not read: it repeats the register. The name prerogative has its own reader below.
sk_parse_lists <- function(file, edition) {
  W <- sk_words(file)
  lastreg <- max(W$page[grepl("^Smíðasta", W$text)])
  W <- W[W$page > lastreg, ]
  ln <- stats::aggregate(list(y = W$y), by = list(page = W$page, line = W$line), FUN = min)
  first_of <- function(p, l) { w <- W[W$page == p & W$line == l, ]; w$text[which.min(w$x)] }
  second_of <- function(p, l) { w <- W[W$page == p & W$line == l, ]; w <- w[order(w$x), ]; if (nrow(w) > 1) w$text[2] else "" }
  ln$first <- mapply(first_of, ln$page, ln$line); ln$second <- mapply(second_of, ln$page, ln$line)
  kind_of_line <- ifelse(grepl(CALLSIGN_RE, ln$first), "call_sign",
                  ifelse(grepl("^[0-9]{1,4}$", ln$first) & sk_is_num(ln$second) & grepl(",", ln$second), "draught",
                  ifelse(grepl("^[0-9]{1,4}$", ln$first) & grepl("^[A-ZÁÐÉÍÓÚÝÞÆÖ]", ln$second), "number", NA)))
  page_kind <- tapply(kind_of_line, ln$page, function(k) { k <- k[!is.na(k)]; if (length(k) < 5) NA else names(sort(table(k), decreasing = TRUE))[1] })
  out <- list(); anchors <- NULL
  for (p in as.integer(names(page_kind)[!is.na(page_kind)])) {
    kind <- page_kind[[as.character(p)]]
    Wp <- W[W$page == p, ]
    key_re <- if (kind == "call_sign") CALLSIGN_RE else "^[0-9]{1,4}$"
    # blocks: the first key of each line stands at the left margin; a second block (2004-2009) starts where most lines
    # have another key well to the right. Measures that read as integers (a weight of "198") do not line up as keys do.
    kl <- ln$line[ln$page == p & kind_of_line %in% kind]
    x_left <- stats::median(vapply(kl, function(l) min(Wp$x[Wp$line == l]), 0))
    cand <- Wp[grepl(key_re, Wp$text) & Wp$x > x_left + 150 & Wp$line %in% kl, ]
    tab <- table(round(cand$x))
    if (length(tab) && max(tab) >= 0.3 * length(kl)) {
      x_right <- as.numeric(names(tab)[which.max(tab)])
      split_x <- x_right - 6; starts <- c(x_left, x_right)
    } else { split_x <- Inf; starts <- c(x_left, NA) }
    if (kind == "draught") {
      h <- Wp[Wp$text %in% c("L", "B", "Þ", "dL", "dl", "dm"), ]
      if (nrow(h) >= 4) anchors <- data.frame(field = c(L = "length", B = "breadth", "Þ" = "weight", dL = "draft_light", dl = "draft_light", dm = "draft_loaded")[h$text],
                                               dx = h$x2 - ifelse(h$x < split_x, starts[1], starts[2]))
      if (is.null(anchors)) next
    }
    for (l in ln$line[ln$page == p & kind_of_line %in% kind]) {
      w <- Wp[Wp$line == l, ]; w <- w[order(w$x), ]
      # a second block too short to set the page's split (2007, p. 310: five lines) starts at a number after a district
      sx <- split_x
      if (!is.finite(sx) && kind == "number" && nrow(w) > 2) {
        j <- which(grepl(DISTRICT_RE, w$text[-nrow(w)]) & grepl(key_re, w$text[-1]) & w$x[-1] > x_left + 150)
        if (length(j)) sx <- w$x[j[1] + 1] - 1
      }
      for (b in if (is.finite(sx)) 1:2 else 1L) {
        wb <- if (b == 1) w[w$x < sx, ] else w[w$x >= sx, ]
        if (!nrow(wb) || !grepl(key_re, wb$text[1])) next
        rec <- list(edition = edition, page = p, list = kind, block = b, key = wb$text[1])
        rest <- wb[-1, , drop = FALSE]
        if (kind == "draught") {
          for (f in unique(anchors$field)) rec[[f]] <- NA_character_
          for (j in seq_len(nrow(rest))) {
            d <- abs((rest$x2[j] - starts[b]) - anchors$dx)
            if (min(d) < 12) { f <- anchors$field[which.min(d)]; if (is.na(rec[[f]])) rec[[f]] <- rest$text[j] }
          }
        } else {
          tx <- rest$text
          dist <- NA_character_
          if (length(tx) && (grepl(DISTRICT_RE, tx[length(tx)]) || tx[length(tx)] %in% c("-", "‐", "–"))) { dist <- tx[length(tx)]; tx <- tx[-length(tx)] }
          rec$name <- if (length(tx)) paste(tx, collapse = " ") else NA_character_
          rec$district <- dist
        }
        out[[length(out) + 1]] <- as.data.frame(rec, stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(out)) return(NULL)
  dplyr::bind_rows(out)
}

# The summary tables ----------------------------------------------------------------

# The preface's tables by year: a line of years (the register on 1 January of each), then labelled lines of numbers,
# one per year ("Þilfarsskip 1.128 1.123 ..."). One row per table, label and year. The table is named by the title
# above its years. 2006's summary is an image and is not read; later editions repeat its years.
sk_parse_summary <- function(file, edition) {
  W <- sk_words(file)
  reg1 <- min(W$page[grepl("^Smíðasta", W$text) & W$page > 8])
  W <- W[W$page > 2 & W$page < reg1, ]
  ln <- stats::aggregate(list(y = W$y), by = list(page = W$page, line = W$line), FUN = min)
  ln <- ln[order(ln$page, ln$y), ]
  words <- function(i) { w <- W[W$page == ln$page[i] & W$line == ln$line[i], ]; w[order(w$x), ] }
  out <- list(); title <- NA_character_; years <- NULL; label_seen <- character(0)
  for (i in seq_len(nrow(ln))) {
    w <- words(i)
    yr <- grepl("^(19|20)[0-9]{2}$", w$text)
    if (sum(yr) >= 3 && sum(yr) >= nrow(w) - 6) {          # a line of years (perhaps with a label before them)
      years <- as.integer(w$text[yr]); label_seen <- character(0)
      lab <- paste(w$text[!yr], collapse = " ")
      prev <- if (i > 1) paste(words(i - 1)$text, collapse = " ") else ""
      title <- if (nzchar(lab)) lab else prev
      next
    }
    if (is.null(years)) next
    num <- grepl("^[0-9]{1,3}([.][0-9]{3})*(,[0-9]+)?$|^[0-9]+(,[0-9]+)?$", w$text)
    lab <- paste(w$text[!num], collapse = " ")
    vals <- w$text[num]
    if (length(vals) == length(years) && nzchar(lab) && grepl("^[A-ZÁÐÉÍÓÚÝÞÆÖ]", lab)) {
      k <- sum(label_seen == lab) + 1L; label_seen <- c(label_seen, lab)
      out[[length(out) + 1]] <- data.frame(edition = edition, page = ln$page[i], table = title, label = lab, occurrence = k,
                                           year = years, printed = vals, stringsAsFactors = FALSE)
    } else if (!length(vals) && nzchar(lab) && nrow(w) > 3) years <- NULL   # prose: the table has ended
  }
  dplyr::bind_rows(out)
}

# The name prerogative --------------------------------------------------------------------------------------------

# The last table of every edition: names reserved for a holder (einkaréttur á skipsnöfnum), with the holder's name and,
# in 2013-2015, kennitala. One row per reserved name. Read since the maintainer's rule of 2026-10-18 keeps what a public
# source prints (decision 130). 2007-2022 print a header ("Sérleyfisnafn Nafn eiganda [Kennitala]"); 2004-2006 print
# two blocks of name and holder with no header, under a title in spaced letters, so their columns come from the data.
sk_parse_prerogative <- function(file, edition) {
  W <- sk_words(file)
  ln <- stats::aggregate(list(y = W$y), by = list(page = W$page, line = W$line), FUN = min)
  ln$sq <- mapply(function(p, l) tolower(paste(W$text[W$page == p & W$line == l][order(W$x[W$page == p & W$line == l])], collapse = "")),
                  ln$page, ln$line)
  title <- ln$page[grepl("(einkarétt|einkarøtt|sérleyfisnafn)", ln$sq) & ln$page > 4 & !grepl("\\.\\.\\.|qxd", ln$sq)]
  if (!length(title)) return(NULL)
  W <- W[W$page >= min(title), ]
  hdr_re <- "^(Sérleyfisnafn|Skipsheiti|Skipsnafn)$"
  has_lower <- function(t) grepl("[a-záðéíóúýþæö]", t)
  mode_x <- function(x) { if (!length(x)) return(NA_real_); t <- table(round(x)); as.numeric(names(t)[which.max(t)]) }
  out <- list(); cols <- NULL
  for (p in sort(unique(W$page))) {
    Wp <- W[W$page == p, ]
    h <- Wp[grepl(hdr_re, Wp$text), ]
    if (nrow(h)) {
      yh <- min(h$y); hl <- Wp[abs(Wp$y - yh) < 2.5, ]
      cols <- list(blocks = list(c(name = min(h$x), holder = min(hl$x[grepl("^(Nafn|Eigandi)", hl$text)]),
                                   kennitala = suppressWarnings(min(hl$x[grepl("^Kennitala", hl$text)])))))
      body <- Wp[Wp$y > yh + 2.5, ]
    } else {
      body <- Wp
      if (!any(grepl(hdr_re, W$text))) {
        # no header in this edition: name at the margin, holder where the mixed-case text starts, two blocks
        lines <- split(body, body$line)
        firsts <- vapply(lines, function(w) min(w$x), 0)
        x1 <- mode_x(firsts)
        right <- body[body$x > x1 + 180 & !has_lower(body$text) & grepl("^[A-ZÁÐÉÍÓÚÝÞÆÖ]{2,}", body$text), ]
        x3 <- mode_x(vapply(split(right, right$line), function(w) min(w$x), 0))
        h1 <- vapply(lines, function(w) { k <- which(has_lower(w$text) & w$x < (if (is.na(x3)) Inf else x3) - 4); if (length(k)) w$x[k[1]] else NA }, 0)
        h2 <- vapply(lines, function(w) { k <- which(has_lower(w$text) & !is.na(x3) & w$x > x3); if (length(k)) w$x[k[1]] else NA }, 0)
        x2 <- mode_x(h1[!is.na(h1)]); x4 <- mode_x(h2[!is.na(h2)])
        if (is.na(x1) || is.na(x2)) next
        cols <- list(blocks = Filter(function(b) !anyNA(b[c("name", "holder")]),
                                     list(c(name = x1, holder = x2, kennitala = Inf, end = if (is.na(x3)) Inf else x3),
                                          c(name = x3, holder = x4, kennitala = Inf, end = Inf))))
      }
    }
    if (is.null(cols)) next
    for (l in unique(body$line[order(body$y)])) {
      w <- body[body$line == l, ]; w <- w[order(w$x), ]
      if (grepl(PAGE_FURNITURE_RE, paste(w$text, collapse = " "))) next
      for (b in cols$blocks) {
        end <- if ("end" %in% names(b)) b[["end"]] else Inf
        wb <- w[w$x >= b[["name"]] - 6 & w$x < end - 4, ]
        if (!nrow(wb) || min(wb$x) > b[["holder"]] - 6) next
        kt_col <- is.finite(b[["kennitala"]])
        nm <- wb$text[wb$x < b[["holder"]] - 6]
        hd <- wb$text[wb$x >= b[["holder"]] - 6 & (!kt_col | wb$x < b[["kennitala"]] - 6)]
        kt <- if (kt_col) wb$text[wb$x >= b[["kennitala"]] - 6] else character(0)
        if (!length(nm) || !grepl("^[A-ZÁÐÉÍÓÚÝÞÆÖ]", nm[1]) || has_lower(nm[1])) next
        out[[length(out) + 1]] <- data.frame(edition = edition, page = p, name = paste(nm, collapse = " "),
                                             holder = if (length(hd)) paste(hd, collapse = " ") else NA_character_,
                                             kennitala = if (length(kt)) paste(kt, collapse = "") else NA_character_,
                                             stringsAsFactors = FALSE)
      }
    }
  }
  dplyr::bind_rows(out)
}
