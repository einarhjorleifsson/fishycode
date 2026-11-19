# wreck.R — the curated list of wrecks from several witnesses: every record of every wreck list in one outcome, each attribute
# of a wreck from its best witness with its basis beside it (plan 074 steps 9 and 12; the named-features study's 91_wrecks.R
# and 92_wrecks_check.R, the prototype and its check, moved into the layers as the aid list was).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 074 ask p, the maintainer, 2026-11-16:
# "we do not at this moment really want this to be part of the huge rebuild / target flow"; "Standalone in layers").
#
# Input:  staging/isor/wreck.parquet (sources/isor/wreck.R: ÍSOR's four layers, Landhelgisgæslan's list 279, SKFI's 18,
#         ÍSOR's own 16 points, the diving map's 57 sites)
#         staging/hi/wreck.parquet (sources/hi/wreck.R: Háskóli Íslands' list, 80, internal)
#         staging/emodnet/wreck.parquet (sources/emodnet/wreck.R: UKHO's wrecks as EMODnet Human Activities serves them, 283)
#         staging/osm/{wreck,wreck_tag}.parquet (sources/osm/wreck.R: OpenStreetMap's, 22)
#         staging/ornefni/{plotter_wreck_tz,plotter_wreck_gpx}.parquet (sources/ornefni/plotter_wreck.R: a skipper's plotter,
#         its 2021, 2022 and 2025 exports, internal)
# Output: curated/reference/wreck.parquet - one row per wreck (a place): position (WKB geometry, lon, lat), name, the date
#         sunk (ISO 8601 truncated to what is known, its precision; year_sunk), the seabed depth (its unit as read) and the
#         least depth, each with its basis (the list it came from); the witnesses, their counts, the spread; outcome and the
#         conflict's reasons; in_box; internal (any attribute from an internal list), only_internal; the free text gathered
#         (description, description_internal, n_descriptions); maybe_same_as, maybe_same_m, maybe_same_names (other wrecks
#         that may be the same one, ask o)
#         curated/reference/wreck_record.parquet - every record of every list, one row each: list, role (witness, copy,
#         not_a_wreck), name as given and read, its key, position, the precision of its coordinates' digits, the depths
#         (seabed, least) with their unit, text and pattern, the date sunk with its precision, text and pattern, each with its
#         outcome; a copy's original and how; wreck, outcome
#         curated/reference/wreck_pair.parquet - every pair of witnesses of two lists within 5 km: distance, names, mutual,
#         joined, maybe_same (ask o's flag) and its reach, the agreement of names, years and dates sunk
#         curated/reference/wreck_description.parquet - every descriptive field of every record, one row a field, as delivered;
#         internal where the list is
#         curated/check/wreck_depth_read.parquet, wreck_date_read.parquet - every depth and date read (the record, the text, the
#         number, the unit, metres, the pattern; the date, its precision), and every one not read, with why
#         curated/check/wreck_depth_compare.parquet - the seabed depths of every two witnesses of a wreck side by side (a test of
#         the units)
#
# The lists (each staged as delivered, one row a record):
#   lhg   Landhelgisgæslan's wrecks, layer 2 of ÍSOR's Infrastructure (279). 257 are LHG's own (a plotter's symbol, an 8-letter
#         ID, coordinates in their own columns); 22 were appended to the layer (symbol 0, coordinates 0 in the columns):
#         copies of the diving map's wrecks and of ÍSOR's points, not witnesses, or a list of their own (lhg_appended) where no
#         original lies within 50 m. Some IDs and comments were stored in Mac Icelandic and read as Windows-1252
#         ("ARINBJ…R"); kept as given, with a repaired reading beside (id_read, comment_read).
#   dive  the diving sites, "Köfunarstaðir á Íslandi" (layer 3, 57): its folder Flök (18) are wrecks, the sea and fresh-water
#         sites (39) are not. skfi, layer 1 (18), is the same 18 wrecks, at the same places: a copy.
#   isor  ÍSOR's own wreck points (layer 0, 16 points in two multipoints; made for EMODnet Geology, no names).
#   hi    Háskóli Íslands' list (80; INTERNAL: to be asked before anything from it is published). Positions from fishermen
#         (snags, inexact) and from LHG (exact); no field says which.
#   ukho  the UK Hydrographic Office's wrecks, served by EMODnet Human Activities (283 in the box 32 W to 6 W, 59 N to 70 N).
#   osm   OpenStreetMap's seamark:type=wreck and historic=wreck in the same box (22).
#   plotter  a skipper's TimeZero plotter (INTERNAL, like hi): its marks in three states, one witness. tz2021 the TimeZero
#         export of 30.7.2021 (339 marks; its second folder holds one area), gpx2022 the GPX export of 2022-10-18 (260
#         waypoints), tz2025 the TimeZero export of 20.6.2025 (257 marks; its other formats hold the same marks, checked by
#         curate/checks/wreck_accounting.R). Marks only (TimeZero's object types 0 and 7); its ground names (type 1), lines and
#         areas are counted, not records.
#         A wreck mark: the plotter's wreck icons, 310 (Landhelgisgæslan's list read into the plotter) and 10 (the owner's
#         own), or a name saying so (Flak..., Flugvél). Not: depth marks (icon 20, type 7), an anchor and chain (Akkeri), and
#         marks with neither (unnamed, "Event nnnn").
#         Copies: a mark within 1 m of another list's record is copied from it; an own mark within 50 m of an icon-310 mark
#         whose name agrees (or with none) re-marks it; a mark's other states (the same TimeZero guid; a 2022 waypoint by its
#         position and time) are copies of its latest state, which is the witness.
# Not a witness: Trackwell's ground names (one names a wreck, with no position for the wreck; plan 074 step 9).
#
# The join (ask o): two records of two lists are one wreck when each is the other's nearest record of that list and they lie
# within D m (500), in ISN93 (EPSG:3057); wrecks are the connected sets. A wreck is in conflict when it holds two records of
# one list, when its witnesses' names or dates sunk disagree, or when a record of another list lies within D but was not
# joined (crowded). The conflicts are listed, not resolved (the maintainer, 2026-11-16). The names never make a join:
# wreck_pair shows the pairs out to 5 km with their names' agreement. Ask o settled without a knife edge (the maintainer,
# 2026-11-16: "Do we really need to do this here - as long as we flag a potential issue. I hate knife edge decisions, at
# least on this one"): the join stays at D; two wrecks whose witnesses are each other's nearest of their lists but were not
# joined, within MAYBE_M m (1 km) or the two records' coordinate digits, are flagged as maybe one wreck (maybe_same on the
# pair, maybe_same_as on both wrecks), never joined, their outcomes unchanged.
# Depth and the date sunk (the maintainer, 2026-11-16: "Be careful with units"; the date sunk "as a common variable if
# possible"): two quantities, one column each, the seabed depth at the wreck (depth_m) and the least depth over it
# (least_depth_m), each read with its unit as written and the pattern that read it; a number whose unit is not stated is
# not read, and is listed (HI's Z read in metres, measured against the witnesses and the depth model by the study's
# 99_hi_depth_unit.R). The date sunk in one form, ISO 8601 truncated to what is known ("1941-05-24", "1941-05", "1941") with
# its precision and the pattern that read it, year_sunk its year; witnesses compared at their common precision.
# Best witness: position LHG, UKHO, OSM, the diving map, HI, the plotter, ÍSOR, LHG's appended; name HI, UKHO, OSM, the diving
# map, LHG, the plotter; the date sunk HI, UKHO, OSM, the diving map, LHG, the plotter; the seabed depth UKHO, LHG, OSM, the
# diving map, HI, the plotter; the least depth UKHO, OSM.
# Internal: HI's list and the plotter; a wreck taking any attribute from them is internal, one known from them alone
# only_internal, their descriptions internal. Every descriptive field of every list is kept (the maintainer: keep any
# "description" information), and all text is UTF-8 (the maintainer: "All text in the final curated files should be
# UTF-8"). Nothing in the flow reads these tables yet.
# Run from the repo root: Rscript reference/wrecks/wreck.R   (D=, RULE=digits, MAYBE_M= give the alternatives' own outputs,
# under curated/scratch/). Written by Claude (AI), 2026-11-19.
library(sf)
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R", "R/curated_list.R")) source(f)   # standalone: not targets'
INTERNAL <- c("hi", "plotter")   # lists kept internal: nothing from them is published
D <- as.numeric(Sys.getenv("D", "500"))
# RULE=digits (ask o's other answer): the distance widened to the two records' coordinate digits, max(D, res_i + res_j)
RULE <- Sys.getenv("RULE", "fixed")
MAYBE_M <- as.numeric(Sys.getenv("MAYBE_M", "1000"))   # the flag's reach: maybe one wreck, not joined (ask o)
ALT <- !(RULE == "fixed" && D == 500 && MAYBE_M == 1000)
OUT <- if (ALT) fd_curated("scratch", paste0("wreck_", RULE, "_", D, "_", MAYBE_M)) else fd_curated("reference")
CHK <- if (ALT) OUT else fd_curated("check")
staged <- function(...) as.data.frame(nanoparquet::read_parquet(fd_staging(...)))
staged_sf <- function(...) read_curated_sf(fd_staging(...))   # the staged lists' WKB geometry, decoded
INPUTS <- c(fd_staging("isor", "wreck.parquet"), fd_staging("hi", "wreck.parquet"), fd_staging("emodnet", "wreck.parquet"),
            fd_staging("osm", "wreck.parquet"), fd_staging("osm", "wreck_tag.parquet"),
            fd_staging("ornefni", "plotter_wreck_tz.parquet"), fd_staging("ornefni", "plotter_wreck_gpx.parquet"))
in_box <- function(lon, lat) lon >= -32 & lon <= -6 & lat >= 59 & lat <= 70

# The resolution of a coordinate's digits, in minutes of arc (0.001, 0.01, 0.1, 1): the finest step it lies within 2 % of, NA
# when none fits; a record's the coarser of latitude's and longitude's. The prototype's rule, kept: cl_digits_min() (the aid
# list's) takes the coarsest step that fits, and the finer of the two.
digits_min <- function(v) vapply(abs(v) * 60, function(z) {
  if (is.na(z)) return(NA_real_)
  for (k in c(0.001, 0.01, 0.1, 1)) if (abs(z / k - round(z / k)) < 0.02) return(k)
  NA_real_ }, numeric(1))

# Mac Icelandic read as Windows-1252, character by character (measured on LHG's IDs and comments, 2026-11-16)
MOJI <- c("Ý" = "ð", "’" = "í", "…" = "Ö", "ç" = "Á", "î" = "Ó", "œ" = "ú", "Ü" = "Ð", " " = "Ý", "—" = "ó",
          "‡" = "á", "¾" = "æ", "Ž" = "é")
unmoji <- function(x) { for (k in names(MOJI)) x <- gsub(k, MOJI[[k]], x, fixed = TRUE); x }

# Depth from free text, by unit and quantity -----------------------------------------------------------------------------------
# The maintainer (2026-11-16): "Be careful with units". A depth is read only where the text states its unit (m, metra,
# metrar, metrum; fm, faðmar) and says it is a depth (dýpi, dýpt) or is in fathoms (a sea depth). A number in metres with no
# depth word is not read ("SöKKT AF U 99 M TUNDURSK" is sunk by U 99 með tundurskeyti, torpedoed; "100 m á lengd" a length).
# Every text depth is the depth of the sea at the wreck (seabed); a range gives its deeper end; a range's second number may
# drop leading digits ("189-90FM", LHG's ID "103-7FM"). The least depth over the wreck comes from UKHO and OSM's charted depth
# only.
SPACES <- "[\u00a0\u2000-\u200b\u202f]"   # no-break and other spaces read as one (the diving map writes "Dýpi:\u00a090-100 m")
FATHOM_M <- 1.8288   # the international fathom, 6 feet, exactly
D_NUM <- "[0-9]+(?:[.,][0-9]+)?"
D_RANGE <- sprintf("(%s)(?:\\s?(?:-|–|TIL)\\s?(%s))?", D_NUM, D_NUM)
D_UNIT <- "(M|METR\\p{L}*|FM|FA[ÐD?]M\\p{L}*)(?![\\p{L}?])"   # ? the plotter's lost letter ("2.5 M?N" is minutes)
D_WORD <- "(?:BOTN)?D[ÝY?]P[IT]Ð?(?!\\p{L})"
D_PAT <- c(word_first = sprintf("%s[\\s:|]{0,4}(?:UM\\s|CA\\.?\\s)?%s\\s?%s", D_WORD, D_RANGE, D_UNIT),
           number_first = sprintf("(?<![0-9.,])%s\\s?%s\\s(?:Á\\s)?%s", D_RANGE, D_UNIT, D_WORD),
           fathoms = sprintf("(?<![0-9.,])%s\\s?(FM|FA[ÐD?]M\\p{L}*)(?![\\p{L}?])", D_RANGE))
D_DETECT <- sprintf("(?<![0-9.,])%s\\s?%s|%s[^0-9]{0,12}[0-9]", D_RANGE, D_UNIT, D_WORD)
d_num <- function(s) as.numeric(sub(",", ".", s, fixed = TRUE))
# one row a text: the reading (the text matched as given, the number, the unit as read, metres) or why none was taken
depth_read <- function(x) do.call(rbind, lapply(x, function(s0) {
  out <- data.frame(text = NA_character_, number = NA_character_, unit = NA_character_, low = NA_real_, high = NA_real_,
                    metres = NA_real_, pattern = NA_character_, outcome = "no_depth_text", why = NA_character_)
  if (is.na(s0) || !nzchar(trimws(s0))) return(out)
  s <- gsub("[\r\n]+", " | ", gsub(SPACES, " ", s0)); S <- toupper(s)
  for (p in names(D_PAT)) {
    m <- regexec(D_PAT[[p]], S, perl = TRUE)[[1]]
    if (m[1] < 0) next
    g <- substring(S, m, m + attr(m, "match.length") - 1)
    a <- g[2]; b <- if (nzchar(g[3])) g[3] else NA_character_
    if (!is.na(b) && !grepl("[.,]", paste(a, b)) && nchar(b) < nchar(a)) b <- paste0(substr(a, 1, nchar(a) - nchar(b)), b)
    u <- if (grepl("^(FM|FA)", g[4])) "fm" else "m"
    out$text <- substring(s, m[1], m[1] + attr(m, "match.length")[1] - 1)
    out$number <- if (nzchar(g[3])) paste0(g[2], "-", g[3]) else g[2]
    out$unit <- u; out$low <- d_num(a); out$high <- if (is.na(b)) NA else d_num(b)
    out$metres <- round(max(out$low, out$high, na.rm = TRUE) * if (u == "fm") FATHOM_M else 1, 1)
    out$pattern <- p; out$outcome <- "read"
    return(out)
  }
  if (grepl("^\\s*[0-9]+(?:[.,][0-9]+)?(?:\\s?-\\s?[0-9]+)?\\s*$", s)) {   # a bare number: its unit not stated
    out$text <- trimws(s); out$outcome <- "ambiguous"; out$why <- "a bare number, no unit"; return(out) }
  g <- gregexpr(D_DETECT, S, perl = TRUE)[[1]]
  if (g[1] < 0) return(out)
  ends <- g + attr(g, "match.length") - 1
  kind <- vapply(seq_along(g), function(k) {
    before <- substr(S, max(1, g[k] - 6), g[k] - 1); after <- substr(S, ends[k] + 1, ends[k] + 14); hit <- substr(S, g[k], ends[k])
    if (grepl("U\\s?-?$", before) && grepl("M$", hit)) "not a depth: sunk by a U-boat, M(EÐ) TUNDURSK(EYTI), torpedoed"
    else if (grepl("^\\s(?:Á\\s)?(LENGD|BREIDD|HÆÐ|LANG|BREIÐ|ÚT|FRÁ|FYRIR|Í ÞVERMÁL)", after) || grepl("LANG|BREIÐ", hit)) "not a depth: a length or distance"
    else if (grepl(D_WORD, hit, perl = TRUE)) "a depth word and a number, no unit"
    else "metres with no depth word: a depth or a length?" }, "")
  out$text <- paste(substring(s, pmax(1, g - 20), pmin(nchar(s), ends + 20)), collapse = " … ")
  if (all(startsWith(kind, "not a depth"))) { out$outcome <- "not_a_depth"; out$why <- paste(unique(kind), collapse = "; ") }
  else { out$outcome <- "ambiguous"; out$why <- paste(unique(kind[!startsWith(kind, "not a depth")]), collapse = "; ") }
  out }))

# The date the vessel was lost, as ISO 8601 truncated to what is known ---------------------------------------------------------
# "1941-05-24" (day), "1941-05" (month), "1941" (year), with its precision. In a short comment (LHG's, the plotter's) a date
# is read only where a word says the vessel was lost (sökk, sökkt, fórst, strandaði; the plotter writes s?kk), the first
# date after the first such word, else the last before it; in the diving map's prose only within that word's sentence
# (its other dates are of building, finding, diving). A date with no year, a range of years, a decade ("197?"), an
# uncertain year ("1944?") or a malformed one ("13.0701978") is not read, and is listed.
YR <- "(1[6-9][0-9]{2}|20[0-2][0-9])(?![0-9])"
MON_RX <- c("JAN", "FEB", "MAR", "APR", "MA[IÍ?Y]", "J[UÚ?]N", "J[UÚ?]L", "(?:[AÁ?]G[UÚ?]|AUG)", "SEP", "(?:OKT|OCT)", "N[OÓ?]V", "(?:DES|DEC)")
MON <- sprintf("(%s)[\\p{L}?]*\\.?", paste(MON_RX, collapse = "|"))
mon_no <- function(w) which(vapply(MON_RX, function(r) grepl(paste0("^", r), w, perl = TRUE), logical(1)))[1]
LOSS <- "(?<![\\p{L}?])(S[ÖO?]KKT?|S[ÖO?]KT?|SANK|SUNK|SCUTTLED|F[ÓO?]RST|STRANDA[ÐD?]I)(?![\\p{L}?])"
DT_PAT <- list(   # in this order; each gives year, month, day from its groups
  dmy = list(rx = sprintf("(?<![0-9])([0-3]?[0-9])\\s?[.\\-/ ]\\s?([01]?[0-9])\\s?[.\\-/ ]\\s?%s", YR), f = function(g) c(g[4], g[3], g[2])),
  ddmm_y = list(rx = sprintf("(?<![0-9])([0-3][0-9])([01][0-9])\\s%s", YR), f = function(g) c(g[4], g[3], g[2])),
  dm_mon_y = list(rx = sprintf("(?<![0-9])([0-3]?[0-9])\\.([01]?[0-9])\\s?%s\\s?%s", MON, YR),
                  f = function(g) if (as.integer(g[3]) == mon_no(g[4])) c(g[5], g[3], g[2]) else NULL),
  d_mon_y = list(rx = sprintf("(?<![0-9])([0-3]?[0-9])\\.?\\s?%s\\s?(?:ÁRIÐ\\s)?%s", MON, YR), f = function(g) c(g[4], mon_no(g[3]), g[2])),
  y_d_mon = list(rx = sprintf("(?<![0-9])%s\\s([0-3]?[0-9])\\.?\\s?%s", YR, MON), f = function(g) c(g[2], mon_no(g[4]), g[3])),
  m_y = list(rx = sprintf("(?<![0-9.])([01]?[0-9])\\.\\s?%s", YR), f = function(g) c(g[3], g[2], NA)),
  mon_y = list(rx = sprintf("(?<!\\p{L})%s\\s?(?:ÁRIÐ\\s)?%s", MON, YR), f = function(g) c(g[3], mon_no(g[2]), NA)),
  y = list(rx = sprintf("(?<![0-9])%s(?![?0-9]|\\s?-\\s?[0-9])", YR), f = function(g) c(g[2], NA, NA)))
DT_ODD <- c("a range of years" = sprintf("(?<![0-9])%s\\s?-\\s?[0-9]{2,4}(?![0-9])", YR),
            "an uncertain year" = sprintf("(?<![0-9])%s\\?", YR), "a decade" = "(?<![0-9])1[6-9][0-9]\\?",
            "a day and month, no year" = sprintf("(?<![0-9])[0-3]?[0-9]\\.?\\s?%s", MON))
DT_DETECT <- sprintf("(?<![0-9])%s|(?<![0-9])1[6-9][0-9]\\?|(?<![0-9])[0-3]?[0-9]\\.?\\s?%s|(?<![0-9])[0-3][0-9][01][0-9]\\s%s", YR, MON, YR)
iso <- function(y, m, d) { y <- as.integer(y); m <- as.integer(m); d <- as.integer(d)
  if (is.na(m)) return(c(sprintf("%04d", y), "year"))
  if (m < 1 || m > 12) return(NULL)
  if (is.na(d)) return(c(sprintf("%04d-%02d", y, m), "month"))
  v <- sprintf("%04d-%02d-%02d", y, m, d); if (is.na(as.Date(v, optional = TRUE))) return(NULL); c(v, "day") }
# every date in S by every pattern, as (start, end, date, precision, pattern); a date inside a longer one is dropped
# ("2003" inside "20.07.2003"), and at one start the pattern earlier in DT_PAT wins
dt_all <- function(S) {
  a <- do.call(rbind, lapply(names(DT_PAT), function(p) {
    g <- gregexpr(DT_PAT[[p]]$rx, S, perl = TRUE)[[1]]; if (g[1] < 0) return(NULL)
    do.call(rbind, lapply(seq_along(g), function(k) {
      seg <- substr(S, g[k], g[k] + attr(g, "match.length")[k] - 1)
      m <- regexec(DT_PAT[[p]]$rx, seg, perl = TRUE)[[1]]; gr <- substring(seg, m, m + attr(m, "match.length") - 1)
      v <- DT_PAT[[p]]$f(gr); if (is.null(v)) return(NULL); v <- iso(v[1], v[2], v[3]); if (is.null(v)) return(NULL)
      data.frame(start = g[k], end = g[k] + attr(g, "match.length")[k] - 1, date = v[1], precision = v[2], pattern = p,
                 rank = match(p, names(DT_PAT))) })) }))
  if (is.null(a) || !nrow(a)) return(NULL)
  inside <- vapply(seq_len(nrow(a)), function(i) any(a$start <= a$start[i] & a$end >= a$end[i] &
    (a$end - a$start > a$end[i] - a$start[i] | (a$end - a$start == a$end[i] - a$start[i] & a$rank < a$rank[i]))), logical(1))
  a <- a[!inside, ]; a[order(a$start), ] }
DT_MALFORMED <- paste0(LOSS, ".{0,12}[0-9]{6,}")   # "s?kkt 13.0701978"
# one row a text; mode "comment" (a loss word needed, the whole comment), "prose" (a loss word's sentence), "field" (the
# field is the loss date)
date_read <- function(x, mode = c("comment", "prose", "field")) { mode <- match.arg(mode)
  do.call(rbind, lapply(x, function(s0) {
    out <- data.frame(text = NA_character_, date = NA_character_, precision = NA_character_, pattern = NA_character_,
                      outcome = "no_date_text", why = NA_character_)
    if (is.na(s0) || !nzchar(trimws(s0))) return(out)
    s <- trimws(gsub("[ \t]*[\r\n]+[ \t]*", if (mode == "prose") "\n" else " ", gsub(SPACES, " ", s0))); S <- toupper(s)
    if (!grepl(DT_DETECT, S, perl = TRUE) && !grepl(DT_MALFORMED, S, perl = TRUE)) return(out)
    # the windows to read: the whole text, or each sentence (cut in the text's own case) holding a loss word
    if (mode == "prose") {
      cut <- gregexpr("\n|(?<=[.!?])\\s+(?=[A-ZÁÐÉÍÓÚÝÞÆÖ])", s, perl = TRUE)[[1]]
      st <- c(1, if (cut[1] > 0) cut + attr(cut, "match.length")); en <- c(if (cut[1] > 0) cut - 1, nchar(S))
      win <- which(vapply(seq_along(st), function(k) grepl(LOSS, substr(S, st[k], en[k]), perl = TRUE), logical(1)))
      st <- st[win]; en <- en[win]
    } else { st <- 1; en <- nchar(S) }
    for (k in seq_along(st)) {
      W <- substr(S, st[k], en[k]); lw <- regexpr(LOSS, W, perl = TRUE)
      if (mode == "comment" && lw < 0) next
      odd <- vapply(DT_ODD, function(r) grepl(r, W, perl = TRUE), logical(1))
      a <- dt_all(W)
      if (!is.null(a)) {
        if (mode != "field") { aft <- a[a$start > lw, ]; a <- if (nrow(aft)) aft[1, ] else a[nrow(a), ] } else a <- a[1, ]
        if (a$precision == "year" && any(odd[1:3])) { out$text <- substr(s, st[k], en[k]); out$outcome <- "ambiguous"
          out$why <- paste(names(DT_ODD)[1:3][odd[1:3]], collapse = "; "); return(out) }
        out$text <- substr(s, st[k] + a$start - 1, st[k] + a$end - 1); out$date <- a$date; out$precision <- a$precision
        out$pattern <- a$pattern; out$outcome <- "read"; return(out)
      }
      if (any(odd)) { out$text <- substr(s, st[k], en[k]); out$outcome <- "ambiguous"; out$why <- paste(names(DT_ODD)[odd], collapse = "; "); return(out) }
      if (grepl(DT_MALFORMED, W, perl = TRUE)) { out$text <- substr(s, st[k], en[k]); out$outcome <- "ambiguous"; out$why <- "a date not read (malformed)"; return(out) }
    }
    out$text <- s
    if (mode == "prose") { out$outcome <- "no_loss_date"; out$why <- "dates in the text, none in a sentence saying the vessel was lost" }
    else if (mode == "comment" && !grepl(LOSS, S, perl = TRUE)) { out$outcome <- "ambiguous"; out$why <- "a date with no word saying the vessel was lost" }
    else if (mode == "comment") { out$outcome <- "no_loss_date"; out$why <- "a word saying the vessel was lost, no date beside it" }
    else { out$outcome <- "ambiguous"; out$why <- "a date not read" }
    out })) }

# Names as keys: Icelandic letters to ASCII, no prefixes (HMS, ES ...), no registration (ÍS 74, NS-7), letters only.
# A key is left empty for what is not a name (W011, FLAK3, GPS0, a depth).
name_key <- function(x) {
  k <- toupper(trimws(x))
  k <- gsub("Þ", "TH", k); k <- gsub("Ð", "D", k); k <- gsub("Æ", "AE", k); k <- gsub("Ö", "O", k)
  k <- chartr("ÁÉÍÓÚÝÄÜØÅ", "AEIOUYAUOA", k)
  notname <- is.na(k) | grepl("^(W[0-9]+|FLAK[0-9]*|FLAK .*|EVENT [0-9]+|GPS[0-9]*|-?TROLL.*|[0-9].*FM.*|SKIPSFL.K|PLACEMARK.*|BRAK|BLETTUR|FESTA|HUGSANL|OTHEKKT|UNKNOWN|FLUGVEL|FLUGV.L)$", k)
  k <- gsub("\\((PROBABLY|POSSIBLY)\\)|\\b(PROBABLY|POSSIBLY)\\b|,? ?FLAK$", "", k)
  k <- gsub("\\b(HMS|HMT|HMCS|RMAS|RFA|USS|USAT|SS|MS|ES|MV|MB|TS|SKIPSFLAK)\\b", " ", k)
  reg <- "\\b(IS|ÍS|NS|VE|RE|GK|KE|SH|BA|EA|TH|SI|ST|HF|AK|SU|GY|H|BK|ÞH|ÓF|DA|GR|SK|NK|ÁR|FD|BOLUNGARVÍK)[- ]?[0-9]{1,4}\\b"
  k <- gsub(reg, " ", k)
  k2 <- gsub("[^A-Z0-9]", "", k)
  k3 <- gsub("[0-9]", "", k2); w <- which(nchar(k3) >= 3); k2[w] <- k3[w]   # digits kept only where they are the name (U 273)
  k2[notname | is.na(k2) | nchar(k2) < 3] <- NA
  k2 }
# Two keys agree when equal, when one holds the other (5 letters or more: "BRAEKIR" in "THOROLFURBRAEKIR"), or when the shorter
# is close to the longer's start (Jaro-Winkler 0.9: LHG's IDs are cut at 8 letters, "ALECANDE" for Alexander Hamilton)
agree <- function(a, b) mapply(function(a, b) {
  if (is.na(a) || is.na(b)) return(NA)
  s <- if (nchar(a) <= nchar(b)) a else b; l <- if (nchar(a) <= nchar(b)) b else a
  a == b || (nchar(s) >= 5 && grepl(s, l, fixed = TRUE)) || (nchar(s) >= 4 && startsWith(l, s)) ||
    (nchar(s) >= 5 && stringdist::stringsim(s, substr(l, 1, nchar(s)), method = "jw", p = 0.1) >= 0.9) ||
    stringdist::stringsim(a, b, method = "jw", p = 0.1) >= 0.9 }, a, b, USE.NAMES = FALSE)
rec_of <- function(list, id, name, given, lon, lat, res_min = NA_real_, role = "witness", note = NA_character_)
  data.frame(list = list, record_id = as.character(id), name_given = cl_blank(given), name = cl_blank(name), lon = lon, lat = lat,
             res_min = res_min, role = role, note = cl_blank(note), stringsAsFactors = FALSE)

# Records ----------------------------------------------------------------------------------------------------------------------
isr <- staged_sf("isor", "wreck.parquet"); layer <- function(k) isr[isr$layer == k, ]
## LHG: own and appended -------------------------------------------------------------------------------------------------------
lhg <- layer(2); xy <- st_coordinates(lhg)
own <- lhg$Symbol != 0 & !(lhg$Longitude == 0 & lhg$Latitude == 0)
id_read <- ifelse(own, unmoji(lhg$ID), lhg$ID); com_read <- ifelse(own, unmoji(lhg$Comment), lhg$Comment)
r_lhg <- rec_of("lhg", lhg$OBJECTID, id_read, lhg$ID, xy[, 1], xy[, 2],
                res_min = ifelse(own, pmax(digits_min(lhg$Latitude), digits_min(lhg$Longitude)), NA),
                role = ifelse(own, "witness", "copy"),
                note = paste0("symbol ", lhg$Symbol, "; ", gsub("[\r\n]+", " | ", com_read)))
## Diving sites and SKFI -------------------------------------------------------------------------------------------------------
dive <- layer(3); xy <- st_coordinates(dive); wreck_folder <- grepl("/Flök$", dive$FolderPath)
r_dive <- rec_of("dive", dive$OBJECTID, dive$Name, dive$Name, xy[, 1], xy[, 2], role = ifelse(wreck_folder, "witness", "not_a_wreck"),
                 note = sub("^Köfunarstaðir á Íslandi/", "", dive$FolderPath))
skfi <- layer(1); xy <- st_coordinates(skfi)
r_skfi <- rec_of("skfi", skfi$OBJECTID, skfi$Name, skfi$Name, xy[, 1], xy[, 2],
                 role = "copy", note = "the diving map's folder Flök")
## ÍSOR's own: one record a point of its multipoints ---------------------------------------------------------------------------
isor0 <- layer(0); xy <- st_coordinates(isor0)
r_isor <- rec_of("isor", paste0(isor0$OBJECTID, "_", isor0$point), NA, NA, xy[, 1], xy[, 2],
                 note = "Skipsflök (ÍSOR), no attributes")
## HI (internal) ---------------------------------------------------------------------------------------------------------------
hi <- staged_sf("hi", "wreck.parquet"); xy <- st_coordinates(st_transform(hi, 4326))
hname <- ifelse(is.na(cl_blank(hi$REGISTRATI)), hi$SHIP_NAME, paste(hi$SHIP_NAME, hi$REGISTRATI))
r_hi <- rec_of("hi", hi$ID, hi$SHIP_NAME, hname, xy[, 1], xy[, 2],
               res_min = pmax(digits_min(hi$Y), digits_min(hi$X)),
               note = paste0(cl_blank(hi$TYPE), "; ", cl_blank(hi$NATIONALIT)))
## UKHO ------------------------------------------------------------------------------------------------------------------------
uk <- staged_sf("emodnet", "wreck.parquet"); xy <- st_coordinates(uk)
pos_res <- vapply(strsplit(uk$position, ","), function(p) {
  d <- nchar(sub("^[^.]*\\.?", "", sub(" [NSEW]$", "", trimws(sub("^[0-9]+ ", "", trimws(p))))))
  d <- ifelse(grepl("\\.", p), d, 0); max(10^-d) }, numeric(1))
num <- function(x) suppressWarnings(as.numeric(cl_blank(x)))
r_uk <- rec_of("ukho", uk$wreck_id, sub(" *\\((PROBABLY|POSSIBLY)\\)", "", cl_blank(uk$name)), uk$name, xy[, 1], xy[, 2],
               res_min = pos_res,
               note = paste0(uk$wreck_cate, "; ", uk$status, "; ", cl_blank(uk$type), "; ", cl_blank(uk$flag)))
## OSM -------------------------------------------------------------------------------------------------------------------------
osm <- staged_sf("osm", "wreck.parquet"); ot <- staged("osm", "wreck_tag.parquet"); xy <- st_coordinates(osm)
osm_tags <- lapply(split(ot, factor(ot$osm_id, levels = osm$osm_id)), function(d) setNames(d$value, d$key))
tg <- function(k) vapply(osm_tags, function(t) if (k %in% names(t)) t[[k]] else NA_character_, character(1), USE.NAMES = FALSE)
osm_name <- dplyr::coalesce(tg("name"), tg("seamark:name"), sub("^Trawler ", "", tg("inscription")), tg("name:en"))
osm_name[osm_name %in% c("Shipwreck")] <- NA
r_osm <- rec_of("osm", osm$osm_id, osm_name, osm_name, xy[, 1], xy[, 2],
                note = paste0(dplyr::coalesce(tg("seamark:wreck:category"), ""), "; ", dplyr::coalesce(tg("description"), "")))
## The plotter (internal): three states of one TimeZero plotter ----------------------------------------------------------------
xy_df <- function(g) { xy <- st_coordinates(g); d <- st_drop_geometry(g); d$lon <- xy[, 1]; d$lat <- xy[, 2]; d }
tzo <- xy_df(staged_sf("ornefni", "plotter_wreck_tz.parquet"))
tz <- list(tz2021 = tzo[tzo$export == "tz2021", ], tz2025 = tzo[tzo$export == "tz2025", ])
g22 <- xy_df(staged_sf("ornefni", "plotter_wreck_gpx.parquet"))
TZ_MARK <- c(0, 7)   # TimeZero's marks and depth marks; 1 its text names, 3, 4 and 8 lines and areas
tz_marks <- function(o, state) { o <- o[o$ObjectType %in% TZ_MARK, ]; stopifnot("every TimeZero mark has a point" = all(o$decoded))
  data.frame(state = rep(state, nrow(o)), id = o$Guid, guid = o$Guid, type = o$ObjectType, icon = o$Icon, name = o$Name,
             comment = o$Comment, time = as.POSIXct(o$CreationDate, origin = "2000-01-01", tz = "UTC"), lon = o$lon, lat = o$lat) }

pm <- rbind(tz_marks(tz$tz2021, "tz2021"),
            data.frame(state = "gpx2022", id = as.character(g22$mark), guid = NA_character_, type = NA_integer_, icon = g22$symbol,
                       name = g22$name, comment = g22$cmt, time = as.POSIXct(substr(g22$time_txt, 1, 19), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
                       lon = g22$lon, lat = g22$lat),
            tz_marks(tz$tz2025, "tz2025"))
# A 2022 waypoint is a TimeZero mark when one lies within 1 m with the same creation time (to the second)
m_lat <- function(lon1, lat1, lon2, lat2) sqrt(((lon1 - lon2) * cos(lat1 * pi / 180))^2 + (lat1 - lat2)^2) * 111320
tzi <- which(pm$state != "gpx2022")
for (i in which(pm$state == "gpx2022")) { c <- tzi[pm$time[tzi] == pm$time[i]]
  c <- c[m_lat(pm$lon[i], pm$lat[i], pm$lon[c], pm$lat[c]) < 1]; if (length(unique(pm$guid[c])) == 1) pm$guid[i] <- pm$guid[c[1]] }
pm$mark_id <- dplyr::coalesce(pm$guid, paste0("gpx2022:", pm$id))
# What each mark is: the plotter's wreck icons (310 the imported LHG list, 10 the owner's own) or a name saying so
pm$kind <- ifelse(pm$type %in% 7 | pm$icon %in% 20, "depth mark",
           ifelse(grepl("^\\s*akkeri", pm$name, ignore.case = TRUE), "anchor and chain",
           ifelse(pm$icon %in% c(10, 310) | grepl("^\\s*(flak|flugv.l|sj.flugv|kafb.t)", pm$name, ignore.case = TRUE), "wreck",
                  "no wreck icon or name")))
pm$wreck_basis <- ifelse(pm$kind != "wreck", NA, ifelse(pm$icon %in% c(10, 310), paste("icon", pm$icon), "name"))
r_pl <- rec_of("plotter", paste0(pm$state, ":", pm$id), pm$name, pm$name, pm$lon, pm$lat,
               role = ifelse(pm$kind == "wreck", "witness", "not_a_wreck"),
               note = paste0(pm$state, "; icon ", pm$icon, "; ", ifelse(pm$kind == "wreck", paste("wreck by", pm$wreck_basis), pm$kind),
                             ifelse(is.na(cl_blank(pm$comment)), "", paste0("; ", gsub("[\r\n]+", " | ", trimws(pm$comment))))))

rec <- rbind(r_lhg, r_dive, r_skfi, r_isor, r_hi, r_uk, r_osm, r_pl)
rec$rid <- seq_len(nrow(rec)); rec$key <- name_key(rec$name); rec$in_box <- in_box(rec$lon, rec$lat)

## Descriptions: every list's descriptive fields, one row a field of a record, as given ----------------------------------------
# The maintainer (2026-11-16): keep any "description" information; later sources (timarit.is and others) may add rows to this
# table, which is why it is long and keyed by record, not columns of the wreck table.
long_desc <- function(list, df) cl_long(rec$rid[rec$list %in% list], df)
html_text <- function(h) trimws(gsub("[ \t]+", " ", gsub("&nbsp;", " ", gsub("<[^>]+>", " ", gsub("<br ?/?>", "\n", h)))))
uk_d <- st_drop_geometry(uk); uk_d <- uk_d[, setdiff(names(uk_d), c("id", "wreck_id", "latitude", "longitude", "horizontal", "name"))]
# The plotter: every field of every TimeZero mark as given (its Geometry is the position), its times read beside; the 2022
# waypoints' fields as given; in the order of pm
pl_desc <- function() {
  txt <- function(df) { df[] <- lapply(df, as.character); df }
  tzd <- function(o, state) { o <- o[o$ObjectType %in% TZ_MARK, setdiff(names(o), c("export", "file", "Geometry", "lon", "lat", "decoded")), drop = FALSE]
    o$created_utc <- format(as.POSIXct(o$CreationDate, origin = "2000-01-01", tz = "UTC"), "%Y-%m-%d %H:%M:%S")
    o$modified_utc <- format(as.POSIXct(o$LastModificationDate, origin = "2000-01-01", tz = "UTC"), "%Y-%m-%d %H:%M:%S")
    txt(cbind(export = rep(state, nrow(o)), o)) }
  d <- dplyr::bind_rows(tzd(tz$tz2021, "tz2021"),
                        txt(data.frame(export = "gpx2022", name = g22$name, cmt = g22$cmt, time = g22$time_txt, sym = g22$symbol, color = g22$colour)),
                        tzd(tz$tz2025, "tz2025"))
  stopifnot(nrow(d) == nrow(pm)); d }
desc <- rbind(
  long_desc("lhg", data.frame(comment = lhg$Comment, comment_read = ifelse(own & com_read != lhg$Comment, gsub("[\r\n]+", " | ", com_read), NA),
                              id_read = ifelse(own & id_read != lhg$ID, id_read, NA), symbol = lhg$Symbol)),
  long_desc("dive", data.frame(folder = dive$FolderPath, popup = html_text(dive$PopupInfo))),
  long_desc("skfi", data.frame(folder = skfi$FolderPath, popup = html_text(skfi$PopupInfo))),
  long_desc("hi", st_drop_geometry(hi)[, intersect(c("TYPE", "SHIP_TYPE", "SITE", "REGISTRATI", "NATIONALIT", "LOSS_DATE", "Date", "Z", "NET_TONNAG",
                                                      "LOSS_LIFE", "POINT_ORIG", "POINT_DEST", "REASON_LOS", "WRITTEN_SO", "NOTES", "Cluster_ID"), names(hi))]),
  long_desc("ukho", uk_d),
  data.frame(rid = rec$rid[rec$list == "osm"][match(ot$osm_id, osm$osm_id)], field = ot$key, text = ot$value),   # as given
  long_desc("plotter", pl_desc()))
desc <- desc[!(desc$field == "LOSS_LIFE" & desc$text %in% "0"), ]
# the free-text fields gathered on the wreck table (the rest stay in wreck_description)
FREE <- c(lhg = "comment_read|comment", dive = "popup", hi = "REASON_LOS|NOTES|WRITTEN_SO", ukho = "circumstan|general_co|surveying_",
          osm = "description|inscription", plotter = "Comment|cmt")
rec$res_m <- round(rec$res_min * 1852, 1)
stopifnot(table(rec$list)[c("lhg", "dive", "skfi", "isor", "hi", "ukho", "osm", "plotter")] ==
            c(nrow(lhg), nrow(dive), nrow(skfi), nrow(isor0), nrow(hi), nrow(uk), nrow(osm), nrow(pm)))

## Depth and the date sunk, each read with its unit or precision and the pattern that read it ----------------------------------
# One row a reading (depth_rd: a record may give the seabed depth and the least depth; date_rd: one a record). The text
# lists are read by the readers above; UKHO, OSM and HI by their fields. A record that is not a wreck is not read.
# HI's Z: its unit is stated nowhere (the shapefile, its e-mail). Metres, measured against the witnesses and the depth model:
# against another witness's seabed metres 18 of 25 pairs within 25 % (wreck_depth_compare); against the Olex depth model
# (the study's 99_hi_depth_unit.R) 33 of 41 fit only as metres, 6 either way (shallow water), 1 fits neither within 500 m but metres
# within 1 km, 1 only as fathoms; the model's median ratio 0.98 (fathoms would give 0.55). The maintainer: "Yes, metres".
# NA here leaves the column out, listed.
HI_Z_UNIT <- "m"
HI_Z_BASIS <- "measured against the witnesses and the depth model (99_hi_depth_unit.R)"
# HI's records whose Z fits the depth model only as fathoms (99's outcome within 500 m; curate/checks/wreck_accounting.R
# checks the two agree): flagged and
# left out, not converted. 886: 180, the model 309-347 m within 500 m (180 fm = 329 m), the plotter's 185-7 fm there.
HI_Z_NOT_METRES <- "886"
blank_na <- function(n) rep(NA_character_, n)
src <- rbind(   # in the order of rec
  data.frame(depth_field = "ID | comment", depth_txt = paste(id_read, com_read, sep = " | "),
             date_field = "comment", date_txt = com_read, date_mode = ifelse(own, "comment", "prose")),   # appended: the dive map's prose
  data.frame(depth_field = "popup", depth_txt = html_text(dive$PopupInfo), date_field = "popup", date_txt = html_text(dive$PopupInfo), date_mode = "prose"),
  data.frame(depth_field = "popup", depth_txt = html_text(skfi$PopupInfo), date_field = "popup", date_txt = html_text(skfi$PopupInfo), date_mode = "prose"),
  data.frame(depth_field = blank_na(nrow(isor0)), depth_txt = NA, date_field = NA, date_txt = NA, date_mode = NA),
  data.frame(depth_field = blank_na(nrow(hi)), depth_txt = NA, date_field = "LOSS_DATE", date_txt = hi$LOSS_DATE, date_mode = "field"),
  data.frame(depth_field = blank_na(nrow(uk)), depth_txt = NA, date_field = NA, date_txt = NA, date_mode = NA),
  data.frame(depth_field = blank_na(nrow(osm)), depth_txt = NA, date_field = NA, date_txt = NA, date_mode = NA),
  data.frame(depth_field = "name | comment", depth_txt = ifelse(is.na(pm$comment), pm$name, paste(pm$name, pm$comment, sep = " | ")),
             date_field = "comment", date_txt = pm$comment, date_mode = "comment"))
stopifnot(nrow(src) == nrow(rec))
wreck_rec <- rec$role != "not_a_wreck"
tx <- which(!is.na(src$depth_txt) & wreck_rec)
depth_rd <- cbind(rid = rec$rid[tx], field = src$depth_field[tx], depth_read(src$depth_txt[tx]), quantity = "seabed")
fld <- function(rid, field, value, metres, quantity, pattern, outcome, why = NA_character_)
  data.frame(rid = rid, field = field, text = value, number = value, unit = ifelse(outcome == "read", "m", NA), low = metres, high = NA_real_,
             metres = ifelse(outcome == "read", metres, NA), pattern = pattern, outcome = outcome, why = why, quantity = quantity)
# UKHO: water_dept the seabed, depth the least depth over the wreck, metres both (the maintainer); 0 is given where the
# depth is unknown or the wreck dries, so it is not read
ru <- rec$rid[rec$list == "ukho"]; wd <- num(uk$water_dept); ld <- num(uk$depth)
depth_rd <- rbind(depth_rd,
  fld(ru, "water_dept", cl_blank(uk$water_dept), wd, "seabed", "ukho water_dept",
      ifelse(is.na(wd), "no_depth_text", ifelse(wd == 0, "ambiguous", "read")), ifelse(wd %in% 0, "0 m given: unknown or drying", NA)),
  fld(ru, "depth", cl_blank(uk$depth), ld, "least", "ukho depth", ifelse(is.na(ld), "no_depth_text", "read")))
# OSM: wreck:depth the depth from the surface (the wiki's historic=wreck: "The depth (in metres) from the surface of the water"),
# depth and seamark:wreck:depth the charted depth of the feature, its least depth (Key:depth: "The depth of a feature, in
# metres", "according to charted depth"; equal to UKHO's least depth where both are charted)
ro <- rec$rid[rec$list == "osm"]
osm_m <- function(v) ifelse(grepl("^\\s*[0-9]+(\\.[0-9]+)?\\s*(m)?\\s*$", v), suppressWarnings(as.numeric(sub("\\s*m?\\s*$", "", v))), NA)
od <- tg("wreck:depth"); oc <- tg("depth"); os <- tg("seamark:wreck:depth"); ol <- dplyr::coalesce(oc, os)
ol_txt <- ifelse(is.na(oc) & is.na(os), NA, paste0(ifelse(is.na(oc), "", paste0("depth=", oc)), ifelse(!is.na(oc) & !is.na(os), "; ", ""),
                                                  ifelse(is.na(os), "", paste0("seamark:wreck:depth=", os))))
ol_ok <- is.na(oc) | is.na(os) | oc == os
depth_rd <- rbind(depth_rd,
  fld(ro, "wreck:depth", od, osm_m(od), "seabed", "osm wreck:depth",
      ifelse(is.na(od), "no_depth_text", ifelse(is.na(osm_m(od)), "ambiguous", "read")), ifelse(!is.na(od) & is.na(osm_m(od)), "not a number in metres", NA)),
  fld(ro, "depth | seamark:wreck:depth", ol_txt, osm_m(ol), "least", "osm depth",
      ifelse(is.na(ol), "no_depth_text", ifelse(!ol_ok | is.na(osm_m(ol)), "ambiguous", "read")),
      ifelse(!is.na(ol) & !ol_ok, "the two tags differ", ifelse(!is.na(ol) & is.na(osm_m(ol)), "not a number in metres", NA))))
# HI: Z, its unit stated nowhere; 0 where no depth was given
rh <- rec$rid[rec$list == "hi"]; hz <- ifelse(hi$Z %in% 0, NA, hi$Z)
depth_rd <- rbind(depth_rd,
  fld(rh, "Z", ifelse(is.na(hz), NA, as.character(hi$Z)), if (is.na(HI_Z_UNIT)) NA_real_ else abs(hz), "seabed", "hi Z",
      ifelse(is.na(hz), "no_depth_text", if (is.na(HI_Z_UNIT)) "ambiguous" else ifelse(as.character(hi$ID) %in% HI_Z_NOT_METRES, "ambiguous", "read")),
      ifelse(is.na(hz), NA, if (is.na(HI_Z_UNIT)) "HI's Z: its unit stated nowhere"
             else ifelse(as.character(hi$ID) %in% HI_Z_NOT_METRES,
                         "HI's Z fits the depth model only as fathoms (99_hi_depth_unit.R): flagged, not read",
                         paste("HI states no unit; metres", HI_Z_BASIS)))))
depth_rd <- depth_rd[depth_rd$outcome != "no_depth_text" & rec$role[depth_rd$rid] != "not_a_wreck", ]
depth_rd$unit[depth_rd$outcome != "read"] <- NA
stopifnot("one seabed and one least reading a record at most" = !anyDuplicated(depth_rd[, c("rid", "quantity")]))
# UKHO's two quantities: a least depth below the seabed is listed, kept as given
lw <- merge(depth_rd[depth_rd$quantity == "least" & depth_rd$outcome == "read", c("rid", "metres")],
            depth_rd[depth_rd$quantity == "seabed" & depth_rd$outcome == "read", c("rid", "metres")], by = "rid", suffixes = c(".least", ".seabed"))
odd_q <- lw$rid[lw$metres.least > lw$metres.seabed]
k <- depth_rd$rid %in% odd_q & depth_rd$quantity == "least"; depth_rd$why[k] <- "the least depth is greater than the seabed depth (kept as given)"
take <- function(q, col) { r <- depth_rd[depth_rd$quantity == q & depth_rd$outcome == "read", ]; r[[col]][match(rec$rid, r$rid)] }
rec$depth_m <- take("seabed", "metres"); rec$depth_unit <- take("seabed", "unit"); rec$depth_text <- take("seabed", "text")
rec$depth_pattern <- take("seabed", "pattern"); rec$least_depth_m <- take("least", "metres"); rec$least_depth_pattern <- take("least", "pattern")
oc_of <- function(rd, read_word, wreck) { o <- tapply(rd$outcome, rd$rid, function(v) intersect(c(read_word, "ambiguous", "not_a_depth", "no_loss_date"), v)[1])
  r <- unname(o[as.character(rec$rid)]); r[is.na(r)] <- "none"; r[!wreck] <- "not_a_wreck"; r }
rec$depth_outcome <- oc_of(depth_rd, "read", wreck_rec)

# The date sunk: the text lists by the reader; HI's LOSS_DATE (its Date column is the same date, but one day later in 2 of 51,
# listed); UKHO's date_sunk (yyyymmdd); OSM's wreck:date_sunk (ISO 8601 by the wiki)
dx <- which(!is.na(src$date_txt) & wreck_rec)
date_rd <- cbind(rid = rec$rid[dx], field = src$date_field[dx],
                 do.call(rbind, lapply(dx, function(i) date_read(src$date_txt[i], src$date_mode[i]))))
hd <- date_rd$rid %in% rh; hdate <- as.character(hi$Date)[match(date_rd$rid[hd], rh)]
date_rd$why[hd] <- ifelse(!is.na(hdate) & !is.na(date_rd$date[hd]) & hdate != date_rd$date[hd],
                          paste0("HI's Date gives ", hdate), date_rd$why[hd])
iso_field <- function(rid, field, v, pattern) {
  v <- cl_blank(v); ok8 <- grepl("^[12][0-9]{3}(-?[0-9]{2}(-?[0-9]{2})?)?$", v)
  d <- vapply(seq_along(v), function(i) { if (!ok8[i]) return(NA_character_); z <- gsub("-", "", v[i])
    yy <- substr(z, 1, 4); mm <- if (nchar(z) >= 6) substr(z, 5, 6) else "00"; dd <- if (nchar(z) == 8) substr(z, 7, 8) else "00"
    r <- if (mm == "00") yy else if (dd == "00") paste(yy, mm, sep = "-") else paste(yy, mm, dd, sep = "-")
    if (nchar(r) == 10 && is.na(as.Date(r, optional = TRUE))) NA_character_ else r }, "")
  data.frame(rid = rid, field = field, text = v, date = d, precision = c(`4` = "year", `7` = "month", `10` = "day")[as.character(nchar(d))],
             pattern = pattern, outcome = ifelse(is.na(v), "no_date_text", ifelse(is.na(d), "ambiguous", "read")),
             why = ifelse(!is.na(v) & is.na(d), "not a date in the list's form", NA)) }
date_rd <- rbind(date_rd, iso_field(ru, "date_sunk", uk$date_sunk, "ukho yyyymmdd"), iso_field(ro, "wreck:date_sunk", tg("wreck:date_sunk"), "osm iso"))
date_rd <- date_rd[date_rd$outcome != "no_date_text" & rec$role[date_rd$rid] != "not_a_wreck", ]
stopifnot("one date a record" = !anyDuplicated(date_rd$rid))
rd <- date_rd[date_rd$outcome == "read", ]; mt <- match(rec$rid, rd$rid)
rec$date_sunk <- rd$date[mt]; rec$date_precision <- rd$precision[mt]; rec$date_text <- rd$text[mt]; rec$date_pattern <- rd$pattern[mt]
rec$year_sunk <- as.integer(substr(rec$date_sunk, 1, 4))
rec$date_outcome <- oc_of(date_rd, "read", wreck_rec)
# two dates agree at their common precision (ISO 8601 truncated: the shorter one's length)
date_cmp <- function(a, b) { n <- pmin(nchar(a), nchar(b)); ifelse(is.na(a) | is.na(b), NA, substr(a, 1, n) == substr(b, 1, n)) }
P <- st_transform(st_as_sf(rec, coords = c("lon", "lat"), crs = 4326, remove = FALSE), 3057)
XY <- st_coordinates(P)
dist_m <- function(i, j) sqrt((XY[i, 1] - XY[j, 1])^2 + (XY[i, 2] - XY[j, 2])^2)

# Copies: each to its original, the nearest witness of the lists it may copy ---------------------------------------------------
rec$copy_of <- NA_integer_; rec$copy_m <- NA_real_; rec$copy_how <- NA_character_
for (i in which(rec$role == "copy")) {
  from <- which(rec$role == "witness" & rec$list %in% if (rec$list[i] == "skfi") "dive" else c("dive", "isor"))
  d <- dist_m(i, from); rec$copy_of[i] <- from[which.min(d)]; rec$copy_m[i] <- round(min(d), 1)
  rec$copy_how[i] <- if (rec$list[i] == "skfi") "the diving map's folder Flök" else "appended to LHG's layer"
}
# An appended record with no original within 50 m is a witness after all, of the layer's own
lone <- which(rec$list == "lhg" & rec$role == "copy" & rec$copy_m > 50)
rec$role[lone] <- "witness"; rec$list[lone] <- paste0(rec$list[lone], "_appended"); rec$copy_of[lone] <- NA; rec$copy_how[lone] <- NA

## The plotter's copies: what it took from another list, its own re-marks, and its earlier states ------------------------------
ip <- which(rec$list == "plotter"); pm$rid <- rec$rid[ip]   # in the order of pm
icon_of <- setNames(pm$icon, pm$rid); state_of <- setNames(pm$state, pm$rid)
pw <- ip[rec$role[ip] == "witness"]   # its wreck marks
oth <- which(rec$role == "witness" & rec$list != "plotter")
PREF <- c("lhg", "ukho", "hi", "osm", "dive", "isor", "lhg_appended")   # at a shared position (LHG and UKHO share 13), LHG's first
set_copy <- function(i, j, how) { if (rec$role[j] == "copy") j <- rec$copy_of[j]
  rec$role[i] <<- "copy"; rec$copy_of[i] <<- j; rec$copy_m[i] <<- round(dist_m(i, j), 1); rec$copy_how[i] <<- how }
# (a) within 1 m of another list's record: copied from it (icon 310 is Landhelgisgæslan's list read into the plotter)
for (i in pw) { d <- dist_m(i, oth); near <- d < 1
  if (any(near)) { j <- oth[near][order(match(rec$list[oth[near]], PREF), d[near])][1]
    set_copy(i, j, paste0("at a record of ", rec$list[j], " (under 1 m)")) } }
# (b) an own mark (not icon 310) within 50 m of an icon-310 mark of the same state whose name does not disagree: a re-mark
is310 <- icon_of[as.character(pw)] %in% 310
for (i in pw[rec$role[pw] == "witness" & !is310]) {
  c <- pw[is310 & state_of[as.character(pw)] == state_of[[as.character(i)]]]
  d <- dist_m(i, c); ok <- d <= 50 & !(agree(rep(rec$key[i], length(c)), rec$key[c]) %in% FALSE)
  if (any(ok)) set_copy(i, c[ok][which.min(d[ok])], "re-marks an icon-310 mark (within 50 m)") }
# (c) a mark's other states are copies of its latest, the witness (the same TimeZero guid; a 2022 waypoint by position and time)
STATES <- c("tz2021", "gpx2022", "tz2025")
for (g in split(pw, pm$mark_id[match(pw, pm$rid)])) if (length(g) > 1) {
  latest <- g[which.max(match(state_of[as.character(g)], STATES))]
  for (i in setdiff(g, latest)) if (rec$role[i] == "witness") set_copy(i, latest, "an earlier state of the same mark") }
stopifnot("a plotter copy's original is a witness" = rec$role[rec$copy_of[ip[rec$role[ip] == "copy"]]] == "witness")

# Pairs of witnesses of two lists within 5 km ----------------------------------------------------------------------------------
W <- which(rec$role == "witness")
pr <- cl_pairs(XY, rec$list, rec$role == "witness", 5000)
# each record's nearest of every other list: mutual where each is the other's
pr$mutual <- cl_mutual(pr, rec$list, rep(TRUE, nrow(pr)))
lim <- if (RULE == "digits") pmax(D, dplyr::coalesce(rec$res_m[pr$i], 0) + dplyr::coalesce(rec$res_m[pr$j], 0)) else D
pr$joined <- pr$mutual & pr$dist_m <= lim
pr$names_agree <- agree(rec$key[pr$i], rec$key[pr$j])
pr$years_agree <- ifelse(is.na(rec$year_sunk[pr$i]) | is.na(rec$year_sunk[pr$j]), NA, rec$year_sunk[pr$i] == rec$year_sunk[pr$j])
pr$dates_agree <- date_cmp(rec$date_sunk[pr$i], rec$date_sunk[pr$j])
pr$same_position <- pr$dist_m < 1

# Places: connected sets of joined witnesses -----------------------------------------------------------------------------------
rec$place <- cl_places(nrow(rec), pr, pr$joined, W)
cp <- which(rec$role == "copy"); rec$place[cp] <- rec$place[rec$copy_of[cp]]
rec$place <- match(rec$place, sort(unique(rec$place)))
# Maybe one wreck (ask o): mutual nearest witnesses of two lists, not joined, in two places, within MAYBE_M or their digits
pr$maybe_lim_m <- pmax(MAYBE_M, dplyr::coalesce(rec$res_m[pr$i], 0) + dplyr::coalesce(rec$res_m[pr$j], 0))
pr$maybe_same <- pr$mutual & !pr$joined & rec$place[pr$i] != rec$place[pr$j] & pr$dist_m <= pr$maybe_lim_m

# Outcomes ---------------------------------------------------------------------------------------------------------------------
pl <- split(W, rec$place[W])
why <- vapply(pl, function(ix) {
  r <- character()
  if (anyDuplicated(rec$list[ix])) r <- c(r, "one_list_twice")
  jp <- pr[pr$joined & pr$i %in% ix, ]
  if (any(jp$names_agree %in% FALSE)) r <- c(r, "names_differ")
  dt <- rec$date_sunk[ix][!is.na(rec$date_sunk[ix])]   # every two witnesses of the place, at their common precision
  if (length(dt) > 1 && any(outer(dt, dt, date_cmp) %in% FALSE)) r <- c(r, "dates_differ")
  near <- pr[!pr$joined & pr$dist_m <= D & (pr$i %in% ix | pr$j %in% ix), ]
  if (nrow(near)) r <- c(r, "crowded")
  paste(r, collapse = ",") }, character(1))
n_lists <- vapply(pl, function(ix) length(unique(rec$list[ix])), integer(1))
place_outcome <- ifelse(nzchar(why), "conflict", ifelse(n_lists >= 2, "several_witnesses", "one_witness"))
names(place_outcome) <- names(why) <- names(n_lists) <- names(pl)
rec$outcome <- ifelse(rec$role == "not_a_wreck", "not_a_wreck", ifelse(rec$role == "copy", "copy",
                      place_outcome[as.character(rec$place)]))
rec$outcome[is.na(rec$outcome)] <- "copy"   # a copy whose original is itself in no place cannot occur; kept explicit
stopifnot(!is.na(rec$outcome), sum(table(rec$outcome)) == nrow(rec))

# The curated list: one row a place, each attribute from its best witness ------------------------------------------------------
# The plotter after the published lists and HI: a skipper's marks, internal; its names after LHG's (some lost their letters)
ORDER <- list(position = c("lhg", "ukho", "osm", "dive", "hi", "plotter", "isor", "lhg_appended"),
              name = c("hi", "ukho", "osm", "dive", "lhg", "plotter", "lhg_appended", "isor"),
              date_sunk = c("hi", "ukho", "osm", "dive", "lhg", "plotter"),
              depth_m = c("ukho", "lhg", "osm", "dive", "hi", "plotter"),
              least_depth_m = c("ukho", "osm"))
basis <- function(k) if (is.na(k)) "none" else rec$list[k]
wk <- do.call(rbind, lapply(names(pl), function(p) { ix <- pl[[p]]
  pos <- cl_best_which(ix, rec$lon, rec$list, ORDER$position)
  n <- cl_best_which(ix[!is.na(rec$key[ix])], rec$name, rec$list, ORDER$name)   # a name only where it is one (not W011, FLAK3)
  y <- cl_best_which(ix, rec$date_sunk, rec$list, ORDER$date_sunk); d <- cl_best_which(ix, rec$depth_m, rec$list, ORDER$depth_m)
  l <- cl_best_which(ix, rec$least_depth_m, rec$list, ORDER$least_depth_m)
  data.frame(place = as.integer(p), lon = rec$lon[pos], lat = rec$lat[pos], position_basis = rec$list[pos],
             name = rec$name[n], name_basis = basis(n), date_sunk = rec$date_sunk[y], date_precision = rec$date_precision[y],
             year_sunk = rec$year_sunk[y], date_basis = basis(y),
             depth_m = rec$depth_m[d], depth_unit = rec$depth_unit[d], depth_basis = basis(d),
             least_depth_m = rec$least_depth_m[l], least_depth_basis = basis(l),
             witnesses = paste(sort(unique(rec$list[ix])), collapse = ","), n_lists = length(unique(rec$list[ix])),
             n_records = length(ix), spread_m = round(if (length(ix) > 1) max(dist(XY[ix, , drop = FALSE])) else 0),
             outcome = place_outcome[[p]], why = why[[p]], in_box = rec$in_box[pos], stringsAsFactors = FALSE) }))
wk$internal <- wk$name_basis %in% INTERNAL | wk$date_basis %in% INTERNAL | wk$depth_basis %in% INTERNAL | wk$least_depth_basis %in% INTERNAL |
  wk$position_basis %in% INTERNAL
wk$only_internal <- vapply(strsplit(wk$witnesses, ","), function(w) all(w %in% INTERNAL), logical(1))
desc$list <- rec$list[desc$rid]; desc$record_id <- rec$record_id[desc$rid]; desc$internal <- desc$list %in% INTERNAL
desc$place <- rec$place[desc$rid]
free <-desc[mapply(function(l, f) l %in% names(FREE) && grepl(paste0("^(", FREE[[l]], ")$"), f), desc$list, desc$field), ]
free <- free[!(free$field == "comment" & paste(free$rid, "comment_read") %in% paste(free$rid, free$field)), ]   # the read, not both
free <- free[rec$role[free$rid] == "witness", ]   # a copy repeats its original's text
wk$description <- vapply(wk$place, function(p) { f <- free[free$place %in% p, ]; if (!nrow(f)) return(NA_character_)
  paste(sprintf("[%s] %s", f$list, f$text), collapse = " || ") }, character(1))
wk$description_internal <- vapply(wk$place, function(p) any(free$internal[free$place %in% p]), logical(1))
wk$n_descriptions <- vapply(wk$place, function(p) sum(desc$place %in% p), integer(1))
# the flag on both places of every maybe pair: the other places, the nearest distance, and their names (agree, differ, mixed,
# unknown where either has no name)
mp <- data.frame(pi = rec$place[pr$i], pj = rec$place[pr$j], pr[, c("dist_m", "names_agree")])[pr$maybe_same, ]
wk$maybe_same_as <- vapply(wk$place, function(p) { o <- sort(unique(c(mp$pj[mp$pi == p], mp$pi[mp$pj == p])))
  if (length(o)) paste(o, collapse = ",") else NA_character_ }, character(1))
wk$maybe_same_m <- vapply(wk$place, function(p) { d <- mp$dist_m[mp$pi == p | mp$pj == p]; if (length(d)) min(d) else NA_real_ }, numeric(1))
wk$maybe_same_names <- vapply(wk$place, function(p) { a <- mp$names_agree[mp$pi == p | mp$pj == p]; if (!length(a)) return(NA_character_)
  if (any(a %in% TRUE) && any(a %in% FALSE)) "mixed" else if (any(a %in% FALSE)) "differ" else if (any(a %in% TRUE)) "agree" else "unknown" }, character(1))

# Write ------------------------------------------------------------------------------------------------------------------------
# All text UTF-8 (the maintainer, 2026-11-16: "All text in the final curated files should be UTF-8"): every character column
# valid UTF-8 and marked so; the curated table free of the Mac Icelandic misreading (the record and description tables keep
# LHG's text as delivered beside the reading)
SCRIPT <- "reference/wrecks/wreck.R"
rec <- cl_utf8(rec); desc <- cl_utf8(desc); wk <- cl_utf8(wk)
MOJI_RX <- paste0("[", paste(names(MOJI), collapse = ""), "]|Ã.|Â.")
# only in what came from LHG: a no-break space is the diving map's own (valid UTF-8), and stands for Ý only in LHG's text
lhg_free <- free$text[free$list == "lhg" & free$field == "comment_read" | (free$list == "lhg" & free$field == "comment" & !free$rid %in% free$rid[free$field == "comment_read"])]
moji_left <- c(name = sum(grepl(MOJI_RX, wk$name[wk$name_basis == "lhg"])), description = sum(grepl(MOJI_RX, lhg_free)))
if (sum(moji_left)) message("misread left: ", paste(c(wk$name[wk$name_basis %in% "lhg" & grepl(MOJI_RX, wk$name)], lhg_free[grepl(MOJI_RX, lhg_free)]), collapse = " | "))
# A text depth (read as the seabed) equal to the least depth UKHO or OSM give at its place, and to no seabed depth there, is
# likely the chart's least depth over the wreck ("Flak á 14,5 m dýpi" at UKHO's 14.5 m least, 16 m seabed): noted, not moved
txt_rd <- which(depth_rd$outcome == "read" & depth_rd$pattern %in% names(D_PAT))
for (k in txt_rd) { at <- which(rec$place %in% rec$place[depth_rd$rid[k]] & rec$role == "witness" & rec$list %in% c("ukho", "osm"))
  m <- depth_rd$metres[k]; lq <- rec$least_depth_m[at]; sb <- rec$depth_m[at]
  if (any(abs(lq - m) < 0.05, na.rm = TRUE) && !any(abs(sb - m) < 0.05, na.rm = TRUE))
    depth_rd$why[k] <- sprintf("equal to the least depth %s gives here (%g m; seabed %s): likely the chart's least depth, read as seabed",
                               paste(unique(rec$list[at][abs(lq - m) < 0.05 & !is.na(lq)]), collapse = ", "), m,
                               paste(ifelse(is.na(sb), "none", paste(sb, "m")), collapse = ", ")) }
# The review tables: every depth and every date read, and every one not read with why (the text as matched: line breaks
# shown as " | ", no-break spaces as spaces; LHG's as read back from Mac Icelandic, its given text in wreck_description)
ctx <- function(rid) data.frame(list = rec$list[rid], record_id = rec$record_id[rid], role = rec$role[rid], wreck = rec$place[rid],
                                internal = rec$list[rid] %in% INTERNAL)
depth_out <- cl_utf8(cbind(rid = depth_rd$rid, ctx(depth_rd$rid), depth_rd[, c("field", "quantity", "text", "number", "unit", "low", "high", "metres",
                                                                              "pattern", "outcome", "why")]))
depth_out <- depth_out[order(depth_out$outcome != "ambiguous", depth_out$list, depth_out$rid, depth_out$quantity), ]
date_out <- cl_utf8(cbind(rid = date_rd$rid, ctx(date_rd$rid), date_rd[, c("field", "text", "date", "precision", "pattern", "outcome", "why")]))
date_out <- date_out[order(date_out$outcome != "ambiguous", date_out$list, date_out$rid), ]
# The seabed depths of two witnesses of one place side by side, a test of the units: a ratio near 1.83 or 0.55 is a fathom
# apart. HI's Z, where not read, is shown as given.
zv <- setNames(ifelse(hi$Z %in% 0, NA, hi$Z), rh)
dv <- ifelse(rec$list == "hi" & is.na(rec$depth_m), zv[as.character(rec$rid)], rec$depth_m)
du <- ifelse(rec$list == "hi" & is.na(rec$depth_m) & !is.na(dv), "Z (not read)", rec$depth_unit)
dcp <- do.call(rbind, lapply(pl, function(ix) { ix <- ix[!is.na(dv[ix])]; if (length(ix) < 2) return(NULL)
  cb <- t(combn(ix, 2)); data.frame(wreck = rec$place[cb[, 1]], rid_i = cb[, 1], list_i = rec$list[cb[, 1]], value_i = dv[cb[, 1]], unit_i = du[cb[, 1]],
                                    rid_j = cb[, 2], list_j = rec$list[cb[, 2]], value_j = dv[cb[, 2]], unit_j = du[cb[, 2]]) }))
dcp$ratio <- round(dcp$value_i / dcp$value_j, 2)
dcp$a_fathom_apart <- abs(abs(log(dcp$ratio)) - log(FATHOM_M)) < log(1.15)
rec_out <- rec[, c("rid", "list", "record_id", "role", "name_given", "name", "key", "lon", "lat", "in_box", "res_min", "res_m",
                   "depth_m", "depth_unit", "depth_text", "depth_pattern", "least_depth_m", "least_depth_pattern", "depth_outcome",
                   "date_sunk", "date_precision", "date_text", "date_pattern", "year_sunk", "date_outcome",
                   "note", "copy_of", "copy_m", "copy_how", "place", "outcome")]
names(rec_out)[names(rec_out) == "place"] <- "wreck"
pr_out <- cl_utf8(data.frame(list_i = rec$list[pr$i], rid_i = pr$i, name_i = rec$name[pr$i], list_j = rec$list[pr$j], rid_j = pr$j,
                             name_j = rec$name[pr$j], pr[, c("dist_m", "mutual", "joined", "maybe_same", "maybe_lim_m", "names_agree", "years_agree", "dates_agree", "same_position")],
                             year_i = rec$year_sunk[pr$i], year_j = rec$year_sunk[pr$j], date_i = rec$date_sunk[pr$i], date_j = rec$date_sunk[pr$j],
                             wreck_i = rec$place[pr$i], wreck_j = rec$place[pr$j]))
names(wk)[names(wk) == "place"] <- "wreck"
wk_sf <- st_as_sf(wk, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
desc_out <- desc[, c("rid", "list", "record_id", "place", "field", "text", "internal")]; names(desc_out)[names(desc_out) == "place"] <- "wreck"
write_curated(wk_sf, file.path(OUT, "wreck.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(rec_out, file.path(OUT, "wreck_record.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(pr_out, file.path(OUT, "wreck_pair.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(desc_out, file.path(OUT, "wreck_description.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(depth_out, file.path(CHK, "wreck_depth_read.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(date_out, file.path(CHK, "wreck_date_read.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(dcp, file.path(CHK, "wreck_depth_compare.parquet"), inputs = INPUTS, script = SCRIPT)

# What was built, for the log: the bookkeeping, every record in one outcome ----------------------------------------------------
cat(sprintf("The wreck list: mutual nearest within %g m (ISN93), rule %s, maybe one wreck within %g m. %d records, %d wrecks.\n\n",
            D, RULE, MAYBE_M, nrow(rec), nrow(wk)))
cat("Every record in one outcome, by list:\n"); print(addmargins(table(rec$list, rec$outcome)))
cat("\nCopies, distance to their original (m):\n"); print(tapply(rec$copy_m[rec$role == "copy"], rec$list[rec$role == "copy"], summary))
cat(sprintf("\nPlaces: %d; by outcome:\n", nrow(wk))); print(table(wk$outcome))
cat("\nPlaces by number of lists (witnesses):\n"); print(table(wk$n_lists))
cat("\nWitness sets:\n"); print(sort(table(wk$witnesses), decreasing = TRUE))
cat("\nConflict reasons:\n"); print(table(unlist(strsplit(wk$why[nzchar(wk$why)], ","))))
nmv <- function(x) ifelse(is.na(x), "unknown", ifelse(x, "agree", "differ"))
cat(sprintf("\nMaybe one wreck (ask o: mutual nearest witnesses of two lists in two places, within %g m or their coordinates' digits;\nflagged, not joined, outcomes unchanged): %d pairs, on %d places (%d of them in conflict). Pairs by distance (m) and names:\n",
            MAYBE_M, sum(pr$maybe_same), sum(!is.na(wk$maybe_same_as)), sum(!is.na(wk$maybe_same_as) & wk$outcome == "conflict")))
print(table(dist = cut(pr$dist_m[pr$maybe_same], c(0, 500, 750, 1000, 2000, 5000)), names = nmv(pr$names_agree[pr$maybe_same])))
cat("By lists:\n"); print(table(paste(rec$list[pr$i], rec$list[pr$j])[pr$maybe_same]))
cat(sprintf("\nPlaces outside the box (32 W-6 W, 59-70 N), where only LHG and HI were asked: %d\n", sum(!wk$in_box)))
cat(sprintf("Places with an attribute from an internal list (HI, the plotter): %d; known from internal lists alone: %d (HI %d, the plotter %d, both %d)\n",
            sum(wk$internal), sum(wk$only_internal), sum(wk$witnesses == "hi"), sum(wk$witnesses == "plotter"), sum(wk$witnesses == "hi,plotter")))
cat(sprintf("Places with an attribute from HI: %d; from the plotter: %d\n",
            sum(wk$name_basis %in% "hi" | wk$date_basis %in% "hi" | wk$depth_basis %in% "hi" | wk$position_basis %in% "hi"),
            sum(wk$name_basis %in% "plotter" | wk$date_basis %in% "plotter" | wk$depth_basis %in% "plotter" | wk$position_basis %in% "plotter")))
cat("\nThe plotter (internal), its marks by state and by what they are:\n"); print(addmargins(table(pm$state, pm$kind)))
cat("Its wreck marks by icon or name, by state:\n"); print(addmargins(table(pm$state, pm$wreck_basis)))
cat("Its objects that are not marks (1 the ground names; 3, 4, 8 lines and areas), TimeZero type by state:\n")
print(do.call(rbind, lapply(tz, function(o) table(factor(o$ObjectType[!o$ObjectType %in% TZ_MARK], c(1, 3, 4, 8))))))
cat(sprintf("2022 waypoints tied to a TimeZero mark (within 1 m, same creation time): %d of %d\n", sum(!is.na(pm$guid[pm$state == "gpx2022"])), sum(pm$state == "gpx2022")))
pw_rec <- rec[rec$list == "plotter" & rec$role != "not_a_wreck", ]
cat("Its wreck marks by role (a copy by how, and of which list), by state:\n")
print(addmargins(table(sub(":.*", "", pw_rec$record_id), ifelse(pw_rec$role == "copy", paste0(sub(" \\(.*", "", pw_rec$copy_how), " -> ", rec$list[pw_rec$copy_of]), "witness"))))
pwi <- which(rec$list == "plotter" & rec$role == "witness")
cat("Its witnesses by icon and outcome:\n"); print(addmargins(table(icon = pm$icon[match(pwi, pm$rid)], rec$outcome[pwi])))
cat("Places with the plotter among their witnesses, by witness set:\n"); print(sort(table(wk$witnesses[grepl("plotter", wk$witnesses)]), decreasing = TRUE))
cat("Marks moved between states (an earlier state over 1 m from the latest), m:\n")
mv <- rec[rec$list == "plotter" & rec$copy_how %in% "an earlier state of the same mark" & rec$copy_m > 1, ]; print(mv[, c("record_id", "name", "copy_m")])
cat("\nJoined pairs by distance (m):\n"); print(table(cut(pr$dist_m[pr$joined], c(-1, 1, 10, 50, 100, 250, 500))))
cat("\nPairs of two named witnesses, names agreeing, by distance (m) and joined:\n")
nm <- pr[!is.na(pr$names_agree), ]
print(table(dist = cut(nm$dist_m, c(-1, 100, 500, 1000, 2000, 5000)), agree = nm$names_agree, joined = nm$joined))
cat("\nJoined pairs of identical position (< 1 m), by lists:\n"); print(table(paste(rec$list[pr$i], rec$list[pr$j])[pr$joined & pr$same_position]))
cat("\nText: every character column valid UTF-8 (checked); misread characters left in the wreck table's name and description from LHG:\n")
print(moji_left)
cat(sprintf("\nDescriptions: %d fields of %d records (%d internal: HI %d, the plotter %d); by list:\n", nrow(desc), length(unique(desc$rid)),
            sum(desc$internal), sum(desc$list == "hi"), sum(desc$list == "plotter")))
print(table(desc$list))
cat("\nThe coordinates' digits (metres of latitude), by list:\n"); print(table(rec$list, rec$res_m, useNA = "ifany")[c("lhg", "hi", "ukho"), ])
cat("\nDepth, every record in one outcome (read: a unit stated and a depth; ambiguous: listed in wreck_depth_read; not_a_depth: a\n",
    "number with a unit that is not a depth, listed; none: no depth text), by list:\n", sep = "")
print(addmargins(table(rec$list, factor(rec$depth_outcome, c("read", "ambiguous", "not_a_depth", "none", "not_a_wreck")))))
cat("Readings by quantity, pattern and unit as read:\n"); rr <- depth_rd[depth_rd$outcome == "read", ]; print(table(paste(rr$quantity, rr$pattern), rr$unit))
cat("Not read, why:\n"); print(table(depth_rd$why[depth_rd$outcome != "read"], depth_rd$outcome[depth_rd$outcome != "read"]))
cat("Places by the seabed depth's witness and unit, and the least depth's witness:\n"); print(table(wk$depth_basis, wk$depth_unit, useNA = "ifany"))
print(table(wk$least_depth_basis))
lqn <- depth_rd[grepl("^equal to the least depth", dplyr::coalesce(depth_rd$why, "")), ]
cat(sprintf("Text depths read as the seabed but equal to a charted least depth at their place (noted, not moved): %d (%s)\n",
            nrow(lqn), paste(sprintf("%s %s %s", rec$list[lqn$rid], rec$role[lqn$rid], lqn$text), collapse = "; ")))
cat(sprintf("Seabed depths of two witnesses of one place (wreck_depth_compare): %d pairs, %d a fathom apart (ratio within 15%% of 1.83 or 0.55)\n",
            nrow(dcp), sum(dcp$a_fathom_apart, na.rm = TRUE)))
print(dcp[dcp$a_fathom_apart %in% TRUE, c("wreck", "list_i", "value_i", "unit_i", "list_j", "value_j", "unit_j", "ratio")], row.names = FALSE)
hz <- dcp[xor(dcp$list_i == "hi", dcp$list_j == "hi") & (dcp$unit_i %in% "m" | dcp$list_i == "hi") & (dcp$unit_j %in% "m" | dcp$list_j == "hi"), ]
hr <- ifelse(hz$list_i == "hi", hz$ratio, 1 / hz$ratio)
if (!is.na(HI_Z_UNIT)) cat(sprintf("HI's Z read in %s, %s; not read as metres: %s\n", HI_Z_UNIT, HI_Z_BASIS, paste(HI_Z_NOT_METRES, collapse = ", ")))
if (nrow(hz)) cat(sprintf("HI's Z (%s) against another witness's seabed depth in metres (Z / metres), %d pairs: within 25%% of 1 %d, a fathom apart %d; quartiles %s\n",
            if (is.na(HI_Z_UNIT)) "not read" else paste("read in", HI_Z_UNIT), nrow(hz), sum(abs(log(hr)) < log(1.25)), sum(hz$a_fathom_apart),
            paste(round(quantile(hr), 2), collapse = " ")))
cat("\nThe date sunk, every record in one outcome (read; ambiguous: listed in wreck_date_read; no_loss_date: dates, none of a loss;\n",
    "none: no date text), by list:\n", sep = "")
print(addmargins(table(rec$list, factor(rec$date_outcome, c("read", "ambiguous", "no_loss_date", "none", "not_a_wreck")))))
cat("Dates read by list and precision:\n"); print(addmargins(table(rec$list, factor(rec$date_precision, c("day", "month", "year")))))
cat("Dates read by pattern:\n"); print(table(date_rd$pattern[date_rd$outcome == "read"]))
cat("Not read, why:\n"); print(table(date_rd$why[date_rd$outcome != "read"], date_rd$outcome[date_rd$outcome != "read"]))
cat("Places by the date's witness and precision:\n"); print(addmargins(table(wk$date_basis, factor(wk$date_precision, c("day", "month", "year")), useNA = "ifany")))
yd <- vapply(pl, function(ix) { y <- rec$year_sunk[ix][!is.na(rec$year_sunk[ix])]; length(unique(y)) > 1 }, logical(1))
dd2 <- grepl("dates_differ", wk$why)
cat(sprintf("Places whose witnesses' dates differ at their common precision: %d (their years differ in %d, only the month or day in %d)\n",
            sum(dd2), sum(dd2 & yd[as.character(wk$wreck)]), sum(dd2 & !yd[as.character(wk$wreck)])))
cf_d <- rec[rec$place %in% wk$wreck[dd2] & rec$role == "witness" & !is.na(rec$date_sunk), c("place", "list", "name", "date_sunk", "date_text")]
print(cf_d[order(cf_d$place, cf_d$list), ], row.names = FALSE)
