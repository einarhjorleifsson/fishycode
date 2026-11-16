# curated_list.R — the machinery of a curated list from several witnesses (plan 074 step 9: the aids, and to come the wrecks,
# harbours and bottom type; first written in the named-features study's 91_wrecks.R and 93_aids.R). Each list is staged as
# delivered; its records are joined across lists, the joined sets are places, every record is put in one outcome, and each
# attribute of a place is taken from its best witness with its basis beside it (the maintainer, 2026-11-16).
#
# cl_blank(x)                  trimmed text, "" and "NA"-like values as NA
# cl_digits_min(lat, lon)      the resolution of a position's digits in minutes of arc: the coarsest of 1, 0.1, 0.01, 0.001
#                              that fits, the finer of latitude's and longitude's (one may be round by chance); NA if finer
# cl_name_keys(x, generic)     a name's keys: Icelandic letters to ASCII (ð, and NGA's dh, to d; þ to th; æ to ae), the words
#                              of `generic` and Roman numerals dropped, -viti/-vitinn/-vita cut from a word, words of 4
#                              letters or more; a list of character vectors
# cl_names_agree(ka, kb)       TRUE where any key of one agrees with any of the other: equal, one within the other (5 letters
#                              or more), one the other's start, a shared start of 5 letters or more that is 0.6 of the
#                              shorter (Icelandic cases: Arnarfirði, Arnarfjörður), or Jaro-Winkler 0.9; NA if either has none
# cl_pairs(xy, list, keep, max_m)  every pair of kept records of two different lists within max_m metres (xy projected, m):
#                              a data frame of i < j and dist_m
# cl_mutual(pr, list, ok, prefer)  of the pairs where `ok`, those where each record is the other's nearest of its list (ties
#                              broken by `prefer`, then by row); a logical vector over pr
# cl_places(n, pr, joined, members)  the connected sets of `members` (record indices) under the joined pairs: a place id per
#                              record (its smallest member), NA for records not members
# cl_best(ix, value, list, order)  the value of the first record of `ix` (in the order of `order`'s lists, then of ix) whose
#                              value is not NA: c(value, its list), or c(NA, "none")
# cl_long(rid, df)             a data frame of descriptive fields as long rows (rid, field, text), the empty left out
# cl_utf8(df)                  every character column valid UTF-8 and marked so; stops naming the column otherwise

cl_blank <- function(x) { x <- trimws(as.character(x)); x[x %in% c("", "NA", "n/a", "N/A")] <- NA; x }

cl_digits_min <- function(lat, lon) {
  one <- function(v) vapply(abs(v) * 60, function(z) { if (is.na(z)) return(NA_real_)
    for (k in c(1, 0.1, 0.01, 0.001)) if (abs(z / k - round(z / k)) < 0.02) return(k); NA_real_ }, numeric(1))
  suppressWarnings(pmin(one(lat), one(lon), na.rm = TRUE))
}

cl_name_keys <- function(x, generic = character()) lapply(ifelse(is.na(x), "", x), function(s) {
  k <- tolower(s); k <- gsub("þ", "th", k); k <- gsub("ð", "d", k); k <- gsub("æ", "ae", k); k <- gsub("ö", "o", k)
  k <- chartr("áéíóúýäüøå", "aeiouyauoa", k); k <- gsub("dh", "d", k)
  w <- strsplit(k, "[^a-z]+")[[1]]; w <- w[nchar(w) >= 4 & !w %in% generic & !grepl("^[ivx]+$", w)]
  w <- sub("(vitinn|viti|vita)$", "", w); unique(w[nchar(w) >= 4]) })

.cl_key_agree <- function(a, b) { s <- if (nchar(a) <= nchar(b)) a else b; l <- if (nchar(a) <= nchar(b)) b else a
  d <- which(strsplit(s, "")[[1]] != strsplit(substr(l, 1, nchar(s)), "")[[1]])[1]; cp <- if (is.na(d)) nchar(s) else d - 1
  a == b || (nchar(s) >= 5 && grepl(s, l, fixed = TRUE)) || startsWith(l, s) || (cp >= 5 && cp >= 0.6 * nchar(s)) ||
    stringdist::stringsim(a, b, method = "jw", p = 0.1) >= 0.9 }

cl_names_agree <- function(ka, kb) mapply(function(a, b) { if (!length(a) || !length(b)) return(NA)
  any(outer(a, b, Vectorize(.cl_key_agree))) }, ka, kb, USE.NAMES = FALSE)

cl_pairs <- function(xy, list, keep, max_m) {
  K <- which(keep); if (length(K) < 2) return(data.frame(i = integer(), j = integer(), dist_m = numeric()))
  p <- sf::st_as_sf(data.frame(x = xy[K, 1], y = xy[K, 2]), coords = c("x", "y"))
  nb <- sf::st_is_within_distance(p, p, max_m)
  pr <- do.call(rbind, lapply(seq_along(K), function(a) { b <- nb[[a]]; b <- b[b > a]
    if (length(b)) data.frame(i = K[a], j = K[b]) else NULL }))
  if (is.null(pr)) return(data.frame(i = integer(), j = integer(), dist_m = numeric()))
  pr <- pr[list[pr$i] != list[pr$j], ]
  pr$dist_m <- round(sqrt((xy[pr$i, 1] - xy[pr$j, 1])^2 + (xy[pr$i, 2] - xy[pr$j, 2])^2), 1)
  rownames(pr) <- NULL; pr
}

cl_mutual <- function(pr, list, ok, prefer = rep(FALSE, nrow(pr))) {
  out <- rep(FALSE, nrow(pr)); k <- which(ok); if (!length(k)) return(out)
  # each pair seen from both its ends, so a record's nearest of a list is judged over every pair it is in, first or second
  e <- data.frame(k = c(k, k), r = c(pr$i[k], pr$j[k]), other = c(list[pr$j[k]], list[pr$i[k]]),
                  d = rep(pr$dist_m[k], 2), pref = rep(prefer[k], 2))
  e <- e[order(e$d, -e$pref, e$k), ]
  n <- table(e$k[!duplicated(e[, c("r", "other")])])
  out[as.integer(names(n)[n == 2])] <- TRUE; out
}

cl_places <- function(n, pr, joined, members) {
  parent <- seq_len(n); find <- function(x) { while (parent[x] != x) x <- parent[x]; x }
  for (k in which(joined)) { a <- find(pr$i[k]); b <- find(pr$j[k]); if (a != b) parent[max(a, b)] <- min(a, b) }
  pl <- rep(NA_integer_, n); pl[members] <- vapply(members, find, integer(1)); pl
}

cl_best <- function(ix, value, list, order) {
  ix <- ix[!is.na(value[ix]) & list[ix] %in% order]; if (!length(ix)) return(c(NA_character_, "none"))
  ix <- ix[order(match(list[ix], order), ix)]; c(as.character(value[ix[1]]), list[ix[1]])
}

cl_long <- function(rid, df) { stopifnot(length(rid) == nrow(df))
  if (!nrow(df)) return(data.frame(rid = integer(), field = character(), text = character()))
  d <- do.call(rbind, lapply(names(df), function(f) data.frame(rid = rid, field = f, text = cl_blank(as.character(df[[f]])))))
  d[!is.na(d$text), ] }

cl_utf8 <- function(df) { for (v in names(df)) if (is.character(df[[v]])) { df[[v]] <- enc2utf8(df[[v]])
  bad <- !is.na(df[[v]]) & !validUTF8(df[[v]]); if (any(bad)) stop(sprintf("%s: %d values not UTF-8", v, sum(bad)), call. = FALSE) }; df }
