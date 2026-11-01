# name_group.R — one name for the keys that write one place: "Utan við hólf", "Utan við hólfið á Breiðafirði" and
# "Utan við hólf Br." are one ground. A proposal, by rule; the keys, their spellings and their sources stay as they are.
# Side: preprocessing (place names). See plan 045 §3.1 (2026-11-01); plan 044.
#
# Input:  curated/place_name/{place_name, variant}.parquet (curate/place_name.R, curate/place_name_evidence.R)
# Output: curated/place_name/name_group.parquet - one row per key: its `group` (the key that names it), the single name
#         `group_name`, how it joined (`basis`), the words dropped as a locator (`locator`, folded), its distance from the
#         group's head (`km`), the `core` it was matched on, the group's size (`n_keys`) and `status` "proposed"
#
# The maintainer, 2026-11-01: "In the end we really want a single name (although the sources stay as is)". A key is a
# spelling folded (case, accents, spaces, doubled letters); here a name is read further, word by word, to its core:
# - a compass letter is a word (N, S, A, V, NA ... : "Kantur N af Patró" is "Kantur norður af Patró");
# - a first "á" or "í" is dropped ("Í Grjóti" is "Grjót"), and so are "við" (or "v.") after utan, innan, austan ... and
#   "fyrir" before them ("fyrir utan hólf" is "utan hólf");
# - each word loses its article and case ending, with fjörður's stems (firði, fjarðar), as the recaptures' texts are
#   matched in place_name_evidence.R ("hólfið" is "hólf", "Breiðafirði" is "Breiðafjörður");
# - a locator at the end is dropped: one or two last words, marked as a locator (after "á" or "í"; cut short of a
#   longer word of a name within 60 km, "Breiðafj.", or its letters in order where it has no vowel, "Brf",
#   "Br."; or after a comma where the words name a broad name, level 1-2, within 60 km: "Arnarfjörður, Hvesta" is a spot
#   in the fjord, not the fjord), where what is left is a name used within reach (below) or the words name a broad
#   name. Never after a word of relation ("Kantur N af
#   Patró" keeps Patró), never a compass word, a number, a qualifier or a superlative ("Sandvík V", "Eyjafjarðaráll
#   ytri", "Klöppin dýpst", "Táin utar" are parts, not the whole), never in a name that holds two names or a refinement
#   in brackets ("Barðið/Djúpkrókur", "Tungan-Kolkugrunn", "Kópur = Kópanes", "Hálsar (Eyjahorn)"; a hyphen after Litli,
#   Norður or a compass letter is one name), and never where it leaves a bare terrain word ("Útkantur Selvogsbanka" is
#   not "Útkantur", "N kantur Kolluáll" not "Norðurkantur").
# Keys of one core form a group around the one with most positions (its head), each member within reach of the head: the
# larger of 15 km and the two keys' spread (r80). A star, never a chain: "Skálin" and "Skelin", one letter apart, are
# never joined through a third key. The same core far off is another place, with its own group. A key with no position
# joins the one group of its core, if there is one. A key left alone joins a group whose core is the dictionary's reading
# of one of its spellings (the 2022 hand readings) within reach, unless the reading is a bare terrain word ("Kantur"),
# that group's head is its parent, it spreads more than twice as far (a reading often names the broader place, plan
# 043 §3.4), or the key's name holds a compass word or a qualifier ("Trintur V" is a part of Trinturnar).
# The single name: LMÍ's where the group holds an LMÍ name; else the commonest spelling of the member with most positions
# among those matched on the core itself (no locator dropped, no reading); else the head's. It is a proposal (`status`):
# plan 045 asks who reviews, and a reviewed name is to be read from overrides/ as an input, never computed (the cycle
# rule, AGENTS.md).

library(dplyr)

pn <- nanoparquet::read_parquet(fd_curated("place_name", "place_name.parquet"))
pn$geometry <- NULL
variant <- nanoparquet::read_parquet(fd_curated("place_name", "variant.parquet"))

# Words -------------------------------------------------------------------------------------------------------------
# fold(), single(), the endings and base() as in place_name_evidence.R, where a finder's text is matched to a name
fold <- function(x) {
  x <- tolower(x); x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
  gsub("[^a-z0-9?]", "", chartr("áéíóúýöäåøü", "aeiouyoaaou", x))
}
single <- function(x) gsub("([a-z])\\1+", "\\1", x)
ART <- c("arinnar", "urinnar", "innar", "unnar", "isins", "inum", "anum", "unum", "sins", "inni", "unni", "inu", "ina",
         "una", "ins", "ans", "inn", "ann", "nir", "nar", "num", "id", "in", "an")
CASE <- c("ar", "ur", "ir", "um", "s", "i", "a", "u")
strip <- function(k, suf, keep) { for (x in suf) if (endsWith(k, x) && nchar(k) - nchar(x) >= keep) return(substr(k, 1, nchar(k) - nchar(x))); k }
base <- function(k) {
  k <- sub("(fjord|fird|fjard)", "fjord", k); k <- sub("hafn", "hofn", k); k <- sub("strand", "strond", k)
  k <- sub("sjav(ar)?$", "sjo", k); k <- sub("sjor$", "sjo", k); sub("eyj", "ey", k)
}
word_stem <- function(k) single(strip(strip(base(k), ART, 4), CASE, 3))
stem_of <- function(w) paste(vapply(w, word_stem, ""), collapse = "")
km <- function(lon1, lat1, lon2, lat2) 6371 * acos(pmin(1, sin(lat1 * pi / 180) * sin(lat2 * pi / 180) +
                                                          cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos((lon2 - lon1) * pi / 180)))

COMPASS <- c("N" = "nordur", "S" = "sudur", "A" = "austur", "V" = "vestur", "NA" = "nordaustur", "NV" = "nordvestur",
             "SA" = "sudaustur", "SV" = "sudvestur")
ADVERB <- c("utan", "innan", "austan", "vestan", "nordan", "sunnan", "framan", "ofan", "nedan")
RELATION <- c("af", "vid", "v", "undan", "fra", "fyrir", "milli", "hja", "naelaegt", "nalaegt", "og", ADVERB, unname(COMPASS))
QUALIFIER <- c("ytri", "innri", "sydri", "nydri", "nyrdri", "eystri", "vestari", "efri", "nedri", "fremri", "litli",
               "litla", "stori", "stora", "mid", "midja", "midjan", "midju", "gamli", "nyi", "grunni", "djupi", "nordari",
               "sunnari", "austari", "dypst", "dypsta", "grynst", "grynsta", "grunst", "nyrst", "nyrsta", "sydst",
               "sydsta", "austast", "vestast", "innst", "innsta", "ytst", "ysta", "fost", "laus", "utar", "innar", "nordar",
               "sunnar", "austar", "vestar", "ofar", "nedar", "dypra", "grynra", "nær", "naer", "fjaer", "nyrdra", "sydra",
               "eystra", "vestara", "ytra", "innra", "efra", "nedra", "fremra")
BARE <- c("kantur", "horn", "grunn", "hryggur", "dypi", "djup", "all", "banki", "flak", "hraun", "brun", "vik", "holl",
          "sker", "rif", "bletur", "svaedi", "holf", "slod", "mid", "botn", "floi", "fjordur", "tunga", "dalur", "bugur",
          "hola", "renna", "eyri", "kambur", "bakki", "festa")
# a bare terrain word, alone or after a compass word or ut-, inn- ... ("Útkantur", "Norðurkantur", "N kantur"), as stems
PREFIX <- c("nordur", "sudur", "austur", "vestur", "ut", "inn", "ytri", "innri", "litli", "litla", "stori", "stora")
BARE_RE <- paste0("^(", paste(unique(vapply(PREFIX, word_stem, "", USE.NAMES = FALSE)), collapse = "|"), ")?(",
                  paste(unique(vapply(BARE, word_stem, "", USE.NAMES = FALSE)), collapse = "|"), ")$")
is_bare <- function(s) grepl(BARE_RE, s)

# A name's words, folded, with compass letters and the relation words read
words_of <- function(x) {
  w <- regmatches(x, gregexpr("[[:alnum:]?]+", x))[[1]]
  f <- fold(w)
  # a compass letter: N, S, V in either case, A (and NA, SA) in capitals only, since "a" is often "á"
  cmp <- toupper(w) %in% names(COMPASS) & (w == toupper(w) | !toupper(w) %in% c("A", "NA", "SA"))
  f[cmp] <- COMPASS[toupper(w[cmp])]
  f <- f[!is.na(f) & f != ""]
  drop <- rep(FALSE, length(f))
  for (i in seq_along(f)) {
    if (i == 1 && length(f) > 1 && f[i] %in% c("a", "i")) drop[i] <- TRUE
    if (i > 1 && f[i] %in% c("vid", "v") && f[i - 1] %in% ADVERB) drop[i] <- TRUE
    if (i < length(f) && f[i] == "fyrir" && f[i + 1] %in% ADVERB) drop[i] <- TRUE
  }
  f[!drop]
}

# The broad names a locator may name, and the cores of every positioned name, with where they lie
k <- pn |> select(key, name, class, lon, lat, r80_km, n_positioned, in_lmi, parent_key, level) |>
  mutate(n_positioned = coalesce(n_positioned, 0L), r80 = coalesce(r80_km, 0), in_lmi = coalesce(in_lmi, FALSE),
         plain = vapply(name, function(x) stem_of(words_of(x)), "", USE.NAMES = FALSE))
placed <- k |> filter(!is.na(lon))
placed_words <- lapply(placed$name, function(x) vapply(words_of(x), word_stem, "", USE.NAMES = FALSE))
broad <- placed |> filter(level <= 2, !is_bare(plain)) |> select(key, stem = plain, lon, lat)
is_sub <- function(p, s) {                           # p's letters in s, in order: "brf" in "breidafjord"
  j <- 1; for (ch in strsplit(p, "")[[1]]) { k <- regexpr(ch, substring(s, j), fixed = TRUE); if (k < 0) return(FALSE); j <- j + k }
  TRUE
}
names_broad <- function(p, s) startsWith(s, p) ||
  (nchar(p) >= 6 && substr(p, 1, 6) == substr(s, 1, 6)) ||
  (nchar(p) <= 6 && substr(p, 1, 2) == substr(s, 1, 2) && is_sub(p, s))

# A name's core, with a locator at its end dropped
core_of <- function(name, key, lon, lat, r80) {
  w <- words_of(name)
  out <- list(core = stem_of(w), locator = NA_character_)
  # two names in one ("Barðið/Djúpkrókur", "Tungan-Kolkugrunn", "halinn-barðið", but not "Litli-Banki" or "A-Horn"), a
  # refinement in brackets, or no position to judge by
  hy <- regmatches(name, regexpr("[[:alnum:]]+(?=\\s*-)", name, perl = TRUE))
  two <- grepl("/|=|\\+|&", name) || (length(hy) && !fold(hy) %in% c(PREFIX, names(COMPASS), tolower(names(COMPASS)), QUALIFIER))
  if (is.na(lon) || two || grepl("\\(", name)) return(out)
  after_comma <- if (grepl(",", name)) words_of(sub(".*,", "", name)) else character()
  d_near <- km(lon, lat, placed$lon, placed$lat)
  b <- broad[broad$key != key & km(lon, lat, broad$lon, broad$lat) <= 60, ]
  words_near <- unique(unlist(placed_words[d_near <= 60]))
  for (n in 1:2) {
    if (length(w) <= n) next
    drop <- tail(w, n); rest <- head(w, -n)
    if (tail(rest, 1) %in% RELATION) next              # "N af Patró": relative to Patró, not in it
    prep <- tail(rest, 1) %in% c("a", "i")
    if (prep) rest <- head(rest, -1)
    if (!length(rest) || tail(rest, 1) %in% RELATION) next
    if (any(drop %in% c(unname(COMPASS), QUALIFIER, RELATION)) || any(grepl("[0-9]", drop))) next
    rc <- stem_of(rest); p <- stem_of(drop)
    if (nchar(p) < 2 || is_bare(rc) || is_bare(p)) next
    # marked as a locator: after "á" or "í"; cut short of a longer word near; after a comma, naming a broad name
    longer <- words_near[nchar(words_near) >= nchar(p) + 2]
    cut <- (nchar(p) >= 4 && any(startsWith(longer, p))) ||
      (!grepl("[aeiouy]", p) &&
         any(substr(longer, 1, 2) == substr(p, 1, 2) & vapply(longer, is_sub, NA, p = p)))
    broad_hit <- nrow(b) > 0 && any(vapply(b$stem, names_broad, NA, p = p))
    if (!(prep || cut || (identical(drop, after_comma) && broad_hit))) next
    # what is left is a name used within reach, or the words name a broad name near
    used <- any(placed$plain == rc & placed$key != key & d_near <= pmax(15, r80, placed$r80))
    if (used || broad_hit) return(list(core = rc, locator = paste(drop, collapse = " ")))
  }
  out
}

# Cores -------------------------------------------------------------------------------------------------------------
cl <- purrr::pmap(k[c("name", "key", "lon", "lat", "r80")], core_of)
k$core <- vapply(cl, `[[`, "", "core")
k$locator <- vapply(cl, `[[`, "", "locator")

# Groups: a star around the key with most positions, of the keys of its core within reach ----------------------------
k <- k |> arrange(desc(n_positioned), key)
k$group <- NA_character_; k$basis <- NA_character_; k$km <- NA_real_
for (h in which(!is.na(k$lon))) {
  if (!is.na(k$group[h])) next
  k$group[h] <- k$key[h]; k$basis[h] <- "head"; k$km[h] <- 0
  m <- which(is.na(k$group) & k$core == k$core[h] & !is.na(k$lon))
  d <- km(k$lon[h], k$lat[h], k$lon[m], k$lat[m])
  keep <- d <= pmax(15, k$r80[h], k$r80[m])
  m <- m[keep]; d <- d[keep]
  k$group[m] <- k$key[h]; k$km[m] <- d
  k$basis[m] <- ifelse(is.na(k$locator[m]), "core", "locator")
}
# a key with no position: the one group of its core
heads <- k |> filter(basis == "head")
for (i in which(is.na(k$group))) {
  g <- heads$key[heads$core == k$core[i]]
  if (length(g) == 1) { k$group[i] <- g; k$basis[i] <- "core" } else { k$group[i] <- k$key[i]; k$basis[i] <- "head" }
}
# a key left alone: the group its dictionary reading names
alone <- k |> count(group) |> filter(n == 1) |> pull(group)
reading <- variant |> filter(!is.na(reading)) |> distinct(key, reading)
heads <- k |> filter(basis == "head", !is.na(lon))
part <- vapply(k$name, function(x) any(words_of(x) %in% c(unname(COMPASS), QUALIFIER)), NA, USE.NAMES = FALSE)
for (i in which(k$key %in% alone & !is.na(k$lon) & k$key %in% reading$key & !part)) {
  if (any(k$group == k$key[i] & k$key != k$key[i])) next          # no chain: a key another joined stays put
  rc <- unique(vapply(reading$reading[reading$key == k$key[i]], function(x) stem_of(words_of(x)), ""))
  rc <- rc[!is_bare(rc)]
  g <- heads |> filter(core %in% rc, key != k$key[i], k$group[match(key, k$key)] == key)   # still its own head
  if (!nrow(g)) next
  g$d <- km(k$lon[i], k$lat[i], g$lon, g$lat)
  g <- g |> filter(d <= pmax(15, r80, k$r80[i]), is.na(k$parent_key[i]) | key != k$parent_key[i],
                   r80 <= 2 * k$r80[i] + 10) |> arrange(d)
  if (!nrow(g)) next
  k$group[i] <- g$key[1]; k$basis[i] <- "reading"; k$km[i] <- g$d[1]
}

# The single name ---------------------------------------------------------------------------------------------------
own <- function(basis, locator, class) basis %in% c("head", "core") & is.na(locator) & class == "name"
named <- k |> group_by(group) |>
  summarise(n_keys = n(),
            namer = c(key[in_lmi][which.max(n_positioned[in_lmi])],
                      key[own(basis, locator, class)][which.max(n_positioned[own(basis, locator, class)])],
                      group[1])[1],
            .groups = "drop") |>
  left_join(k |> select(namer = key, group_name = name), by = "namer")
out <- k |> left_join(named, by = "group") |>
  transmute(key, name, group = namer, group_name, basis, locator, km = round(km, 1), core, n_keys, status = "proposed")

# Check and write -----------------------------------------------------------------------------------------------------
stopifnot("one row per key" = !anyDuplicated(out$key), setequal(out$key, pn$key), !anyNA(out$group),
          !anyNA(out$group_name), "a group is named by its own member" = all(out$group[match(out$group, out$key)] == out$group))
g <- out |> filter(n_keys > 1)
print(knitr::kable(tibble(keys = nrow(out), groups = n_distinct(out$group), in_groups_of_2_or_more = nrow(g),
                          groups_of_2_or_more = n_distinct(g$group),
                          basis = paste(names(table(out$basis)), table(out$basis), collapse = ", "),
                          with_locator = sum(!is.na(out$locator))), caption = "curated/place_name/name_group"))
print(knitr::kable(g |> count(group_name, n_keys, sort = TRUE) |> select(-n) |> head(15), caption = "the largest groups"))

write_curated(out, fd_curated("place_name", "name_group.parquet"),
              inputs = c(fd_curated("place_name", "place_name.parquet"), fd_curated("place_name", "variant.parquet")))
