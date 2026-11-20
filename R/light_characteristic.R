# light_characteristic.R — a light's characteristic read one way, from any list or a chart's reading (plan 082, the
# aids; first written in the named-features study's 93_aids.R).
#
# light_char_parse(x)   one row per string: rhythm (F, Fl, LFl, Q, VQ, UQ, IQ, Iso, Oc, Mo, with "Al." for alternating,
#                       "Dir." for directional, "+LFl" appended; "Dir" alone where a directional light gives no rhythm,
#                       "" for a period alone), group ("2", "3", "2+1", a Morse letter; "" none), colours (a set, in the
#                       order W R G Y Bu), period (s), has_s (the period was read with its "s"). NA where nothing parses.
# light_char_text(p)    the parse written one way: "Fl(3) WRG 20s"
# light_char_agree(a, b)  TRUE, FALSE or NA (either missing or not comparable), for two vectors of characteristics; a string
#                       may hold several, "A | B" (a tower of two lights, a list's several values): any pair agreeing agrees
#
# Two characteristics agree when the rhythm and the group are the same; the periods too where both are read with their "s";
# and the colours where both have some, one set within the other (a sectored light's colours against one sector's). A period
# alone is compared by its period only; "Dir" with no rhythm by its colours only.
# The charts' reads give l as I or 1 (FI G 3s, F1 R): F followed by I, 1 or L is Fl, F followed by a colour or a space is
# fixed. A period read without its "s" is not compared (the charts' "FIR 35" is Fl R 3s).

light_char_parse <- function(x) {
  s <- toupper(ifelse(is.na(x), "", trimws(as.character(x)))); s <- gsub("AERO\\s*", "", s); s <- gsub("\\bDIR\\.?\\s*", "DIR ", s)
  s <- gsub("F[I1L]", "FL", s); s <- gsub("\\bAL\\.?\\s*", "AL ", s)
  rx <- "^\\s*(AL )?(DIR )?(LFL|FL|VQ|UQ|IQ|Q|ISO|OC|MO|F)?\\s*(\\(([^)]*)\\))?\\s*(\\+\\s*LFL)?\\s*((?:BU|[WRGY])*)\\s*(?:(\\d+(?:[.,]\\d+)?)\\s*(S\\b)?)?"
  m <- regmatches(s, regexec(rx, s, perl = TRUE))
  per <- regmatches(s, regexec("^\\s*(\\d+(?:[.,]\\d+)?)\\s*S\\s*$", s, perl = TRUE))
  RH <- c(LFL = "LFl", FL = "Fl", VQ = "VQ", UQ = "UQ", IQ = "IQ", Q = "Q", ISO = "Iso", OC = "Oc", MO = "Mo", F = "F")
  none <- data.frame(rhythm = NA_character_, group = NA_character_, colours = NA_character_, period = NA_real_, has_s = NA)
  out <- lapply(seq_along(m), function(k) { z <- m[[k]]
    empty <- !length(z) || (!nzchar(z[4]) && !nzchar(z[3]))
    if (empty && length(per[[k]]))
      return(data.frame(rhythm = "", group = "", colours = "", period = as.numeric(sub(",", ".", per[[k]][2])), has_s = TRUE))
    if (empty) return(none)
    rh <- paste0(if (nzchar(z[2])) "Al." else "", if (nzchar(z[3])) paste0("Dir", if (nzchar(z[4])) "." else "") else "",
                 if (nzchar(z[4])) RH[[z[4]]] else "", if (nzchar(z[7])) "+LFl" else "")
    col <- intersect(c("W", "R", "G", "Y", "BU"), regmatches(z[8], gregexpr("BU|[WRGY]", z[8]))[[1]])
    data.frame(rhythm = rh, group = if (nzchar(z[6])) gsub("\\s", "", z[6]) else "", colours = paste(col, collapse = ""),
               period = suppressWarnings(as.numeric(sub(",", ".", z[9]))), has_s = nzchar(z[10])) })
  if (!length(out)) return(none[0, ])
  do.call(rbind, out)
}

light_char_text <- function(p) { plus <- grepl("\\+LFl$", p$rhythm)          # Q(6)+LFl: the group before the long flash
  ifelse(is.na(p$rhythm), NA_character_,
    gsub("\\s+", " ", trimws(paste0(sub("\\+LFl$", "", p$rhythm), ifelse(nzchar(p$group), paste0("(", p$group, ")"), ""),
                                    ifelse(plus, "+LFl", ""), " ", p$colours,
                                    ifelse(is.na(p$period), "", paste0(" ", format(p$period, drop0trailing = TRUE), "s")))))) }

.light_colours <- function(x) strsplit(x, "(?<=.)(?=[WRGY]|BU)", perl = TRUE)[[1]]
.light_agree1 <- function(a, b) {
  if (is.na(a$rhythm) || is.na(b$rhythm)) return(NA)
  if (!nzchar(a$rhythm) || !nzchar(b$rhythm)) {
    if (is.na(a$period) || is.na(b$period) || !isTRUE(a$has_s) || !isTRUE(b$has_s)) return(NA)
    return(abs(a$period - b$period) <= 0.05) }
  if (a$rhythm == "Dir" || b$rhythm == "Dir") {
    if (!nzchar(a$colours) || !nzchar(b$colours)) return(NA)
    ca <- .light_colours(a$colours); cb <- .light_colours(b$colours); return(all(ca %in% cb) || all(cb %in% ca)) }
  if (a$rhythm != b$rhythm || sub("^1$", "", a$group) != sub("^1$", "", b$group)) return(FALSE)
  if (!is.na(a$period) && !is.na(b$period) && isTRUE(a$has_s) && isTRUE(b$has_s) && abs(a$period - b$period) > 0.05) return(FALSE)
  if (nzchar(a$colours) && nzchar(b$colours)) {
    ca <- .light_colours(a$colours); cb <- .light_colours(b$colours); if (!(all(ca %in% cb) || all(cb %in% ca))) return(FALSE) }
  TRUE }
.light_cache <- new.env()
.light_parts <- function(txt) { if (is.na(txt)) return(NULL); hit <- .light_cache[[txt]]; if (!is.null(hit)) return(hit)
  p <- light_char_parse(trimws(strsplit(txt, " | ", fixed = TRUE)[[1]])); p <- p[!is.na(p$rhythm), , drop = FALSE]
  assign(txt, p, envir = .light_cache); p }

light_char_agree <- function(a, b) mapply(function(a, b) {
  pa <- .light_parts(a); pb <- .light_parts(b); if (is.null(pa) || is.null(pb) || !nrow(pa) || !nrow(pb)) return(NA)
  r <- unlist(lapply(seq_len(nrow(pa)), function(i) vapply(seq_len(nrow(pb)), function(j) .light_agree1(pa[i, ], pb[j, ]), logical(1))))
  if (any(r %in% TRUE)) TRUE else if (any(r %in% FALSE)) FALSE else NA },
  as.character(a), as.character(b), USE.NAMES = FALSE)
