# place_name_evidence.R — every occurrence of a place name in the ornefni sources, and every spelling, under one key.
# Side: preprocessing (place names). See plan 044; plan 043; decision 222.
#
# Input:  staging/ornefni/{trackwell_haul, trackwell_area, plotter_mark, plotter_track, chart_name, lmi_name,
#         recapture_place, recapture_reading, tag_recapture, tag_release, name_dictionary, drawn_area, fiskislod,
#         article_record, document_name, oracle_name, channel_name, uv_area}.parquet; curated/logbook/{station_window,
#         gear}.parquet (the gear of Trackwell's hauls)
# Output: curated/place_name/evidence.parquet - one row per occurrence, keyed on (`source_table`, `source_key`)
#         curated/place_name/variant.parquet  - one row per spelling (`name`), with its key
#         curated/place_name/outcome.parquet  - every staged row in one outcome: an occurrence, or not and why
#
# An occurrence is a name in a staged row, with the row's position where it has one: a tow's midpoint, a line's middle,
# a polygon's point on surface (`lon`, `lat`, as the row's basis), its time and vessel. `position_flag` marks a
# position kept as given but used for nothing: `impossible` (latitude over 90 or longitude over 180: 22 of Trackwell's
# hauls) or `at zero` (both within a degree of 0). Not occurrences, each counted:
# the plotter's numbers, symbols ("!!") and unnamed marks, placeholders ("FROM SHIP", "Ekkert valið"), LMÍ's land and
# lake names, the 2022 extract of the recaptures (recapture_place: the dump's tag_recapture holds them), a second hand
# reading of a recapture, a finder's text with no name matched, or relative to one, or naming two, the fiskislóð hulls
# (derived from the readings), the plotter's tracks (no names), and a record entered twice (an inspector's sample of a
# Trackwell haul, a tagging group at its own channel station, a name picked from orri at orri's position). A recapture
# is one occurrence at most. Trackwell's picklist summary (trackwell_area) is an occurrence per name
# with `summary` TRUE: it repeats the hauls, so no count or position statistic reads it.
#
# The key groups spellings of one place: lower case, accents and Icelandic letters folded (ð d, þ th, æ ae), everything
# but letters and digits dropped, a doubled letter made single: "Litli-Banki", "Littli banki" and "Litlibanki" share
# "litlibanki". A "?" in a plotter name stands for a lost Icelandic letter (plan 043 §3.2): where exactly one name that
# keeps its letters fits it, that name replaces it (`name_repaired`, rule `repaired`). The hand readings (the
# dictionary's `reading`, an article's synonyms) are kept beside a spelling in variant.parquet as relations, never
# merged into its key: a reading often names the broader place (plan 043 §3.4).
#
# `class` (plan 044 §4.2): each spelling is a `name`, a `composite` (two names, or a name and a qualifier such as
# "vestan v."; a hyphen after Litli-, Austur- and the like is part of one name), a `description` (a distance or a bearing: "14 sjm blettur V klöpp"), or not a place name: a `depth`
# (a number or a range, with or without a unit), a plotter's `default` label ("Event 0261") or a `placeholder`
# ("FROM SHIP", "Ekkert valið", a survey's "hringferð"). The last
# three are counted in outcome.parquet and left out. Oracle's square-placed rows carry the square's size (`square_w`,
# `square_h`, degrees), so the gazetteer can draw a coarse ground from its squares.
#
# Trackwell's gear: its haul matched to a curated logbook station on vid and start minute (Trackwell t1 = the
# station's t2, else t1, else t3; the measure of plan 043 §3.1), and the station's `gid_used`. The names go on no
# logbook haul (the maintainer, 2026-10-24).

library(dplyr)

st <- function(t) nanoparquet::read_parquet(fd_path("staging", "ornefni", paste0(t, ".parquet")))
st_sf <- function(t) read_curated_sf(fd_path("staging", "ornefni", paste0(t, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }
name_key <- function(x) {
  x <- tolower(x)
  x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
  x <- chartr("áéíóúýöäåøü", "aeiouyoaaou", x)
  x <- gsub("[^a-z0-9?]", "", x)
  gsub("([a-z])\\1+", "\\1", x)
}
point_of <- function(g) {                                   # a line's middle, a polygon's point on surface, in ISN93
  g <- sf::st_transform(g, 3057)
  line <- sf::st_geometry_type(g) %in% c("LINESTRING", "MULTILINESTRING")
  out <- sf::st_point_on_surface(g)
  if (any(line)) out[line] <- sf::st_cast(sf::st_line_sample(sf::st_cast(g[line], "LINESTRING"), sample = 0.5), "POINT")
  sf::st_coordinates(sf::st_transform(out, 4326))
}
outcomes <- list()
account <- function(table, outcome, n) outcomes[[length(outcomes) + 1]] <<- tibble(source_table = table, outcome = outcome, rows = n)

# Trackwell ---------------------------------------------------------------------------------------------------------
th <- st("trackwell_haul")
con <- DBI::dbConnect(duckdb::duckdb())
duckdb::duckdb_register(con, "th", th |> filter(!is.na(vid)) |> select(row, vid, t1) |> mutate(vid = as.character(vid)))
cur <- fd_path("curated", "logbook")
gear <- DBI::dbGetQuery(con, sprintf("
  WITH sw AS (SELECT DISTINCT w.\".sid\" sid, w.schema, CAST(w.vid AS VARCHAR) vid, w.t1, w.t2, w.t3
              FROM '%1$s/station_window.parquet' w),
  k AS (SELECT th.row, sw.sid, sw.schema,
          CASE WHEN date_trunc('minute', th.t1) = date_trunc('minute', sw.t2) THEN 1
               WHEN date_trunc('minute', th.t1) = date_trunc('minute', sw.t1) THEN 2 ELSE 3 END pri
        FROM th JOIN sw ON th.vid = sw.vid
         AND date_trunc('minute', th.t1) IN (date_trunc('minute', sw.t1), date_trunc('minute', sw.t2), date_trunc('minute', sw.t3))),
  k1 AS (SELECT * FROM k QUALIFY row_number() OVER (PARTITION BY row ORDER BY pri, sid, schema) = 1)
  SELECT k1.row, k1.sid, k1.schema, g.gid_used, g.gear FROM k1 LEFT JOIN '%1$s/gear.parquet' g
    ON g.\".sid\" = k1.sid AND g.schema = k1.schema", cur))
DBI::dbDisconnect(con, shutdown = TRUE)
ev_th <- th |> filter(!name_placeholder) |> left_join(gear, by = "row") |>
  transmute(source = "trackwell", source_table = "trackwell_haul", source_key = as.character(row), name,
            lon = ifelse(is.na(lon2), lon1, (lon1 + lon2) / 2), lat = ifelse(is.na(lat2), lat1, (lat1 + lat2) / 2),
            position_basis = ifelse(is.na(lon2), position_basis, "derived"), position_kind = "point", time = t1,
            vessel = vessel_raw, vid, gid = as.integer(gid_used), gear, weight = 1L)
account("trackwell_haul", "placeholder (FROM SHIP)", sum(th$name_placeholder))

ta <- st("trackwell_area")
ev_ta <- ta |> filter(!name_placeholder) |>
  transmute(source = "trackwell", source_table = "trackwell_area", source_key = as.character(row), name, lon, lat,
            position_basis, position_kind, weight = n_haul, summary = TRUE)
account("trackwell_area", "placeholder (Ekkert valið)", sum(ta$name_placeholder))

# The plotter ---------------------------------------------------------------------------------------------------------
pm <- st("plotter_mark")
no_letter <- !is.na(pm$name) & !pm$name_is_number & !grepl("[[:alpha:]]", pm$name)       # "!!", ",", "..."
ev_pm <- pm[!is.na(pm$name) & !pm$name_is_number & !no_letter, ] |>
  transmute(source = "plotter", source_table = "plotter_mark", source_key = paste(file, mark, sep = ":"), name, lon, lat,
            position_basis, position_kind, time = if_else(time_placeholder | time_suspect, as.POSIXct(NA), time),
            weight = 1L, text_lost)
account("plotter_mark", "no name", sum(is.na(pm$name)))
account("plotter_mark", "a number, not a name", sum(!is.na(pm$name) & pm$name_is_number))
account("plotter_mark", "a symbol, not a name", sum(no_letter))
account("plotter_track", "a track point, no name", nrow(st("plotter_track")))

# Lines and polygons ------------------------------------------------------------------------------------------------
ch <- st_sf("chart_name"); xy <- point_of(sf::st_geometry(ch))
ev_ch <- tibble(source = "sjokort", source_table = "chart_name", source_key = as.character(ch$row), name = ch$name,
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "line", weight = 1L)

lm <- st_sf("lmi_name"); sea <- grepl("^Sjávar", lm$class)
xy <- point_of(sf::st_geometry(lm)[sea])
ev_lm <- tibble(source = "lmi", source_table = "lmi_name", source_key = as.character(lm$row[sea]), name = lm$name[sea],
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "polygon", weight = 1L,
                lmi_class = lm$class[sea], lmi_feature = lm$feature[sea])
account("lmi_name", "a land or lake name", sum(!sea))

dr <- st_sf("drawn_area"); xy <- point_of(sf::st_geometry(dr))
ev_dr <- tibble(source = "qgis", source_table = "drawn_area", source_key = as.character(dr$row), name = dr$name,
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "drawn", weight = 1L)
account("fiskislod", "derived from the recapture readings", nrow(st_sf("fiskislod")))

# Tags: the hand readings name a recapture, the dump places it; the tagging groups' names ------------------------------
# One occurrence per recapture: its reading in ornefni_endurheimtur.xlsx, else trial2's fiskislóð, else its text matched
# to a name below. Both workbooks read the ornefni repo's extracts of 2022 (recapture_place), whose recaptures are all
# in the dump (tag_recapture): the dump gives the position, as it stands now.
rp <- st("recapture_place"); rr <- st("recapture_reading"); tr <- st("tag_recapture"); tl <- st("tag_release")
stopifnot("the 2022 extract's recaptures are in the dump" = all(rp$recapture_id %in% tr$recapture_id[tr$recapture_table == "endurheimtur"]))
pos_tr <- tr |> filter(recapture_table == "endurheimtur") |>
  select(recapture_id, lon, lat, position_basis, position_kind, square_w, square_h, time)
read_name <- rr |> mutate(name = if_else(file == "ornefni_endurheimtur.xlsx", reading, fiskislod),
                          first = file == "ornefni_endurheimtur.xlsx")
read_first <- read_name$recapture_id[read_name$first & !is.na(read_name$name)]
second <- !read_name$first & !is.na(read_name$name) & read_name$recapture_id %in% read_first
ev_rr <- read_name[!is.na(read_name$name) & !second, ] |> left_join(pos_tr, by = "recapture_id") |>
  transmute(source = "fiskmerki", source_table = "recapture_reading", source_key = paste(file, recapture_id, sep = ":"),
            name, lon, lat, position_basis, position_kind, square_w, square_h, time, weight = 1L)
account("recapture_place", "the 2022 extract of tag_recapture, read in recapture_reading", nrow(rp))
account("recapture_reading", "not read", sum(is.na(read_name$name)))
account("recapture_reading", "a second reading of a recapture read in ornefni_endurheimtur.xlsx", sum(second))
read_ids <- unique(read_name$recapture_id[!is.na(read_name$name)])

ev_tl <- tl |>
  transmute(source = "fiskmerki", source_table = "tag_release", source_key = as.character(link_id), name, lon, lat,
            position_basis, position_kind, time, weight = 1L, square_w, square_h)

# Text: articles and documents ----------------------------------------------------------------------------------------
ar <- st("article_record")
ev_ar <- ar |> filter(!is.na(name)) |>
  transmute(source = "article", source_table = "article_record", source_key = file, name, position_basis = "none",
            position_kind = "text", weight = 1L)
account("article_record", "no name", sum(is.na(ar$name)))

dn <- st("document_name")
ev_dn <- dn |>
  transmute(source, source_table = "document_name", source_key = paste(document, entry, sep = ":"), name, lon, lat,
            position_basis, position_kind, weight = 1L, isor_group = group, region = class_filled)
account("name_dictionary", "a hand reading, a relation in variant.parquet", nrow(st("name_dictionary")))

# Oracle's place tables: the gazetteer, the coarse grounds, Breiðafjörður (plan 044 §4.1) ---------------------------
on <- st("oracle_name")
ev_on <- on |> filter(!is.na(name)) |> mutate(okey = paste(source_table, row, sep = ":"), otab = source_table) |>
  transmute(source = "oracle", source_table = "oracle_name", source_key = okey, name,
            lon, lat, position_basis, position_kind, weight = 1L, description, oracle_table = otab,
            oracle_region = region, sea_area, skiki,
            square_w = case_when(position_kind != "square" ~ NA_real_, !is.na(mini_part) ~ 0.25, !is.na(square_part) ~ 0.5, TRUE ~ 1),
            square_h = square_w / 2)
account("oracle_name", "no name", sum(is.na(on$name)))

# channel: the fishing-area names on MFRI's sampling stations (plan 044 §4.1) -----------------------------------------
cn <- st("channel_name")
ev_cn <- cn |>
  transmute(source = "channel", source_table = "channel_name", source_key = as.character(station_id), name, lon, lat,
            position_basis, position_kind, time = station_date, weight = 1L, square_w, square_h, channel_categories = categories)

# Together, the repair and the key ----------------------------------------------------------------------------------
ev <- bind_rows(ev_th, ev_ta, ev_pm, ev_ch, ev_lm, ev_dr, ev_rr, ev_tl, ev_ar, ev_dn, ev_on, ev_cn) |>
  mutate(summary = coalesce(summary, FALSE), text_lost = coalesce(text_lost, FALSE),
         lon = ifelse(position_basis == "none", NA, lon), lat = ifelse(position_basis == "none", NA, lat),
         position_flag = case_when(is.na(lon) | is.na(lat) ~ NA_character_,
                                   abs(lat) > 90 | abs(lon) > 180 ~ "impossible",
                                   abs(lat) < 1 & abs(lon) < 1 ~ "at zero", TRUE ~ NA_character_))
whole <- unique(ev$name[!ev$text_lost & grepl("[ðþáéíóúýæöÐÞÁÉÍÓÚÝÆÖ]", ev$name)])
lost <- unique(ev$name[ev$text_lost])
fit <- vapply(lost, function(n) {
  rx <- paste0("^", gsub("\\\\\\?", "[ðþáéíóúýæöÐÞÁÉÍÓÚÝÆÖ]", gsub("([][{}()+*^$|.\\\\?])", "\\\\\\1", n)), "$")
  m <- whole[grepl(rx, whole)]
  if (length(m) == 1) m else NA_character_
}, "")
ev <- ev |>
  mutate(name_repaired = if_else(text_lost, unname(fit[name]), NA_character_),
         key = name_key(coalesce(name_repaired, name))) |>
  relocate(name_repaired, key, .after = name)

# A class per spelling (plan 044 §4.2): depths, plotter defaults and placeholders are not place names ------------------
# A hyphen after one of these is part of a single name (Litli-Banki, Austur-Grænland), not a join of two
PREFIX <- "(^|\\s)(Litli|Litla|Litlu|Stóri|Stóra|Stóru|Vestur|Austur|Norður|Suður|Ytri|Innri|Nyrðri|Syðri|Mið|Gamli|Gamla|Nýi|Nýja|Efri|Neðri|Fremri)-"
name_class <- function(x) {
  x <- trimws(x)
  case_when(
    x %in% c("FROM SHIP", "Ekkert valið") | tolower(x) %in% c("hringferð") ~ "placeholder",   # a survey's round trip
    grepl("^[+-]?[0-9]+([.,][0-9]+)?(\\s*[-–/]\\s*[0-9]+([.,][0-9]+)?)?\\s*[.]?\\s*(fa|f|fm|faðm[a-zð]*|m)?[.]?$", x, ignore.case = TRUE) ~ "depth",
    grepl("^(event|mark|wpt|waypoint|punktur|mob|pt)\\s*[0-9]+$", x, ignore.case = TRUE) ~ "default",
    grepl("[0-9]+([.,][0-9]+)?\\s*(sjm|sml|sm|sjómíl\\w*|mílu\\w*|mílna|míl|mil|nm|km|m)\\b", x, ignore.case = TRUE) |
      grepl("\\b(N|S|A|V|NV|NA|SV|SA|NNV|NNA|SSV|SSA|VNV|VSV|ANA|ASA)\\.?\\s+(af|úr|frá|við|undan)\\b", x) ~ "description",
    grepl("[,/]|\\s-\\s|\\b(vestan|austan|norðan|sunnan)\\s+(v\\.|við)", x) |
      (grepl("[[:lower:]]-[[:upper:]]", x) & !grepl(PREFIX, x)) ~ "composite",
    TRUE ~ "name")
}
ev <- ev |> mutate(class = name_class(name), .after = key)
not_name <- ev$class %in% c("depth", "default", "placeholder")
excluded <- ev[not_name, ] |> count(source_table, class)
for (i in seq_len(nrow(excluded))) account(excluded$source_table[i], paste0("not a place name (", excluded$class[i], ")"), excluded$n[i])
ev <- ev[!not_name, ]

# Repeats: one record entered twice is one occurrence ----------------------------------------------------------------
# An inspector's or a fisherman's channel sample of a haul Trackwell logged carries the skipper's name: a channel station
# with a Trackwell haul of the same key on the same day within 0.02 x 0.01 degrees (about 1 km) is that haul again.
# A tagging group named at a channel station that names it the same is that station again.
th_day <- ev |> filter(source_table == "trackwell_haul", position_basis != "none", is.na(position_flag)) |>
  transmute(key, day = as.Date(time), tlon = lon, tlat = lat)
ch_rep <- ev |> filter(source_table == "channel_name", position_basis != "none") |>
  transmute(source_key, key, day = as.Date(time), lon, lat) |>
  inner_join(th_day, by = c("key", "day"), relationship = "many-to-many") |>
  filter(abs(lon - tlon) <= 0.02, abs(lat - tlat) <= 0.01) |> distinct(source_key)
tl_rep <- tl |> inner_join(cn |> select(station_id, cname = name), by = "station_id") |>
  filter(name_key(name) == name_key(cname)) |> distinct(source_key = as.character(link_id))
account("channel_name", "the same haul as a Trackwell haul (same name, day and spot)", nrow(ch_rep))
account("tag_release", "the same station's fishing area (channel_name)", nrow(tl_rep))
ev <- ev |> filter(!(source_table == "channel_name" & source_key %in% ch_rep$source_key),
                   !(source_table == "tag_release" & source_key %in% tl_rep$source_key))

# The recaptures no one read: the finder's text matched to a name, through its inflection -----------------------------
# A name in a finder's text is often inflected after a preposition: "út af Hellissandi" (Hellissandur), "í Faxaflóa",
# "á Halanum" (Halinn). A name's word, folded, loses an article ending (-inn, -inum, -unni, -isins ...) and then a case
# ending (-ur, -i, -s, -a, -u, -ar, -um), keeping three letters, with the stem changes of fjörður (firði, fjarðar),
# höfn, strönd, sjór and ey, before a doubled letter is made single. A text's word is read every way an ending allows
# ("grunni" is grunn + i, not gr + unni), and a reading that meets a name's stem matches. A text's words are matched to the stems of the names the other sources attest (class
# `name`, keys of four letters or more and no digit, not a bare terrain word, alone or after a compass word: kantur, horn,
# blettur, Norðurkantur ...; not a phrase that opens with "á" or "í" or holds a word of relation: "Út af Ólafsvík"),
# the longest run first. Halinn is no bare word: alone it is the ground off the Westfjords.
# The text is an occurrence of the name when it holds exactly one, standing alone or after "á" or "í"; after a word of
# relation (af, við, undan, fyrir sunnan ...) it places the catch relative to that name, not in it, and is counted
# apart, as is a text naming two places, and a name picked from orri at orri's position (a repeat of oracle_name). `name` is the name matched, `text` the finder's words, `name_match` "key"
# when the text's key is the name's, else "inflected". Tested on the hand readings below.
ART <- c("arinnar", "urinnar", "innar", "unnar", "isins", "inum", "anum", "unum", "sins", "inni", "unni", "inu", "ina",
         "una", "ins", "ans", "inn", "ann", "nir", "nar", "num", "id", "in", "an")             # the article, after the case
CASE <- c("ar", "ur", "ir", "um", "s", "i", "a", "u")
BARE <- c("kantur", "horn", "grunn", "hryggur", "dýpi", "djúp", "áll", "banki", "flak", "hraun", "flös", "bolli", "brún", "vík", "renna", "hóll", "eyri", "sker", "rif", "bót", "bugt", "blettur", "svæði", "hola", "gat", "leir",
          "bakki", "tunga", "dalur", "kambur", "slóð", "mið", "botn", "flói", "fjörður", "sund", "rás", "háls", "hæð", "nef",
          "klettur", "steinn", "boði", "grjót", "barð", "barmur", "brekka", "ból", "hryggir")
RELATION <- c("af", "vid", "undan", "fra", "fyrir", "utan", "innan", "framan", "ofan", "nedan", "naelaegt", "nalaegt", "milli",
              "hja", "austan", "vestan", "nordan", "sunnan", "austar", "vestar", "nordar", "sunnar")
fold <- function(x) {                                # name_key() without making a doubled letter single
  x <- tolower(x); x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
  gsub("[^a-z0-9?]", "", chartr("áéíóúýöäåøü", "aeiouyoaaou", x))
}
single <- function(x) gsub("([a-z])\\1+", "\\1", x)
strip <- function(k, suf, keep) { for (x in suf) if (endsWith(k, x) && nchar(k) - nchar(x) >= keep) return(substr(k, 1, nchar(k) - nchar(x))); k }
base <- function(k) {
  k <- sub("(fjord|fird|fjard)", "fjord", k); k <- sub("hafn", "hofn", k); k <- sub("strand", "strond", k)
  k <- sub("sjav(ar)?$", "sjo", k); k <- sub("sjor$", "sjo", k); sub("eyj", "ey", k)
}
word_stem <- function(k) single(strip(strip(base(k), ART, 4), CASE, 3))  # a name's stem: article, then case, off
word_stems <- function(k) {                          # a text word's readings: "grunni" is grunn + i, not gr + unni
  k <- base(k); unique(single(c(strip(strip(k, ART, 4), CASE, 3), strip(k, CASE, 3), strip(k, ART, 4), k)))
}
words_of <- function(x) lapply(strsplit(x, "[^[:alnum:]]+"), function(w) { w <- fold(w); w[!is.na(w) & w != ""] })
bare <- paste0("^(nordur|sudur|austur|vestur|inri|ytri|nydri|sydri|litli|litla|stori|stora|mid)?(",
               paste(unique(vapply(fold(BARE), word_stem, "")), collapse = "|"), ")$")
voc <- ev |> filter(class == "name", nchar(key) >= 4, !grepl("[0-9]", key)) |> count(name, key) |>
  mutate(stem = vapply(words_of(name), function(w) paste(vapply(w, word_stem, ""), collapse = " "), ""),
         phrase = vapply(words_of(name), function(w) w[1] %in% c("a", "i", "ut", "inni", "uti") || any(w %in% RELATION), NA)) |>
  filter(nchar(gsub(" ", "", stem)) >= 4, !grepl(bare, gsub(" ", "", stem)), !phrase) |>
  group_by(stem) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup()
name_hits <- function(text) {                        # per text: each name found, its first word's place, the word before
  lapply(words_of(text), function(w) {
    cand <- lapply(w, word_stems); hit <- character(0); at <- integer(0); used <- integer(0)
    if (length(w)) for (n in min(4, length(w)):1) for (i in seq_len(length(w) - n + 1)) {
      span <- i:(i + n - 1)
      if (any(span %in% used)) next
      combos <- do.call(paste, c(expand.grid(cand[span], stringsAsFactors = FALSE), sep = " "))
      j <- match(combos, voc$stem); j <- j[!is.na(j)]
      if (length(j)) { hit <- c(hit, voc$name[j[1]]); at <- c(at, i); used <- c(used, span) }
    }
    tibble(name = hit, start = at, prev = ifelse(at > 1, w[pmax(at - 1, 1)], ""))
  })
}
match_name <- function(text) {                       # the name matched, or why not: "relative", "several", NA
  vapply(name_hits(text), function(d) {
    u <- unique(d$name)
    if (length(u) > 1) "several" else if (length(u) == 1 && any(d$prev %in% RELATION)) "relative" else if (length(u) == 1) u else NA_character_
  }, "")
}
trm <- tr |> filter(!(recapture_table == "endurheimtur" & recapture_id %in% read_ids)) |>
  mutate(m = match_name(text), number = grepl("^[0-9 .,-]+$", text))
ev_tr <- trm |> filter(!m %in% c("several", "relative"), !is.na(m), !number) |>
  transmute(source = "fiskmerki", source_table = "tag_recapture", source_key = paste(recapture_table, recapture_id, sep = ":"),
            name = m, text, name_match = if_else(name_key(text) == name_key(m), "key", "inflected"), lon, lat,
            position_basis, position_kind, time, weight = 1L, square_w, square_h,
            summary = FALSE, text_lost = FALSE, key = name_key(m), class = "name")
# A name picked in the app from orri.ornefni brings orri's position with it: that recapture repeats the Oracle row
orri_pos <- ev |> filter(source_table == "oracle_name", position_basis != "none") |> distinct(key, olon = lon, olat = lat)
picked <- ev_tr |> filter(position_basis != "none") |> inner_join(orri_pos, by = "key", relationship = "many-to-many") |>
  filter(abs(lon - olon) < 1e-4, abs(lat - olat) < 1e-4) |> distinct(source_key)
ev_tr <- ev_tr |> filter(!source_key %in% picked$source_key)
account("tag_recapture", "a name picked from orri, at orri's position (oracle_name holds it)", nrow(picked))
account("tag_recapture", "read in recapture_reading", sum(tr$recapture_table == "endurheimtur" & tr$recapture_id %in% read_ids))
account("tag_recapture", "a number (an orri row)", sum(trm$number))
account("tag_recapture", "relative to a named place", sum(trm$m %in% "relative" & !trm$number))
account("tag_recapture", "two names or more", sum(trm$m %in% "several" & !trm$number))
account("tag_recapture", "no name matched", sum(is.na(trm$m) & !trm$number))

# uv: the closures' and regulated areas' grounds -----------------------------------------------------------------------
# An area's text is its explanation, else its form's (a real-time closure), else the second explanation, else the form's
# place, cut at its first sentence (the rest draws the boundary from landmarks). Unlike a finder's text, each name after
# "á" or "í", or opening the text, is an occurrence: "á Eyjagrunni í Húnaflóa" lies on Eyjagrunn and in Húnaflói. A name
# after a word of relation only ("norður af Skaga") places the area relative to it. Rivers' works, salmon nets at the
# shore (named by their farm), fish farms' licences and discarded entries are not sea grounds. The position is the outline's point on surface; a polygon over 2,500 km2, larger than a
# statistical square, is kind `area`. An area naming the same keys at the same point as an earlier one (a closure
# renewed, a repealed regulation's copy) repeats it.
uva <- st_sf("uv_area")
NOT_SEA <- c("Rusl", "LaxSil_AðrarFramkvæmdir", "LaxSil_Efnistaka", "Netalögn", "Fiskeldisstöðvar")
first_clause <- function(x) {
  x <- sub("^\\s*[0-9]+\\s*\\.?\\s*gr\\.?\\s*", "", x)
  vapply(strsplit(x, "\\.\\s+(?=\\p{Lu})", perl = TRUE), function(z) if (length(z)) z[1] else NA_character_, "")
}
has <- uva$outline != "none"
xy <- matrix(NA_real_, nrow(uva), 2); xy[has, ] <- point_of(sf::st_geometry(uva)[has])
ua <- sf::st_drop_geometry(uva) |>
  mutate(lon = xy[, 1], lat = xy[, 2], text = first_clause(coalesce(skyring, form_text, fs_skyring, form_place)),
         position_kind = case_when(outline == "polygon" & area_km2 > 2500 ~ "area", outline == "none" ~ NA_character_,
                                   TRUE ~ outline),
         position_basis = case_when(outline == "none" ~ "none", outline == "point" ~ "recorded", TRUE ~ "derived"),
         sea = !type %in% NOT_SEA)
uh <- name_hits(ifelse(ua$sea, ua$text, NA_character_))
ua$names <- lapply(uh, function(d) unique(d$name[d$prev %in% c("i", "a") | d$start == 1]))
ua$relative <- vapply(uh, function(d) any(d$prev %in% RELATION), NA)
ua <- ua |> arrange(date_from, area_id) |>
  mutate(n_names = lengths(names),
         sig = ifelse(n_names > 0, paste(vapply(names, function(n) paste(sort(name_key(n)), collapse = "+"), ""),
                                         round(lon, 3), round(lat, 3)), NA_character_),
         repeat_ = !is.na(sig) & duplicated(sig))
ev_uv <- ua |> filter(n_names > 0, !repeat_) |> tidyr::unnest_longer(names, values_to = "name", indices_to = "k") |>
  transmute(source = "uv", source_table = "uv_area", source_key = paste(area_id, k, sep = ":"), name, text,
            name_match = if_else(vapply(seq_along(name), function(i) grepl(name_key(name[i]), name_key(text[i]), fixed = TRUE), NA),
                                 "key", "inflected"),
            lon, lat, position_basis, position_kind, time = date_from, weight = 1L, summary = FALSE, text_lost = FALSE,
            key = name_key(name), class = "name", uv_type = type)
account("uv_area", "a river's works, a salmon net, a fish farm or a discarded entry: not a sea ground", sum(!ua$sea))
account("uv_area", "no text", sum(ua$sea & is.na(ua$text)))
account("uv_area", "no name matched", sum(ua$sea & !is.na(ua$text) & ua$n_names == 0 & !ua$relative))
account("uv_area", "relative to a named place", sum(ua$sea & !is.na(ua$text) & ua$n_names == 0 & ua$relative))
account("uv_area", "a repeat of an earlier area (the same names at the same point)", sum(ua$repeat_))
account("uv_area", "occurrence", sum(ua$n_names == 1 & !ua$repeat_))
account("uv_area", "occurrences, one per name (two names or more)", sum(ua$n_names > 1 & !ua$repeat_))

# The test: the rule against the readings of 2022, where a person read the text
edits <- function(a, b) mapply(function(x, y) if (is.na(x) || is.na(y)) NA_real_ else drop(adist(x, y)), a, b, USE.NAMES = FALSE)
test <- read_name |> filter(first, !is.na(name)) |> mutate(m = match_name(text)) |>
  mutate(ms = voc$stem[match(m, voc$name)], rs = vapply(words_of(name), function(w) paste(vapply(w, word_stem, ""), collapse = " "), ""),
         ed = edits(gsub(" ", "", ms), gsub(" ", "", rs)),
         outcome = case_when(grepl(bare, gsub(" ", "", rs)) ~ "the reading is a bare terrain word",
                             is.na(m) ~ "no name matched", m == "several" ~ "two names or more",
                             m == "relative" ~ "relative to a named place", ms == rs ~ "the reading",
                             ed <= 3 ~ "the reading, spelt otherwise", TRUE ~ "another name"))
print(knitr::kable(count(test, outcome), caption = "the inflection match against the hand readings (ornefni_endurheimtur.xlsx)"))
ev <- bind_rows(ev, ev_tr, ev_uv)

final <- ev |> filter(source_table != "uv_area") |> count(source_table, name_match)       # uv's are counted by area above
for (i in seq_len(nrow(final)))
  account(final$source_table[i], case_when(final$source_table[i] == "trackwell_area" ~ "occurrence (summary)",
                                           final$name_match[i] %in% "inflected" ~ "occurrence (inflected)",
                                           TRUE ~ "occurrence"), final$n[i])

# Spellings, with the hand readings as relations ----------------------------------------------------------------------
dict <- st("name_dictionary") |> filter(!is.na(name), !is.na(reading)) |>
  group_by(name) |> summarise(reading = paste(sort(unique(c(reading, na.omit(reading2)))), collapse = "; "), .groups = "drop")
syn <- ar |> filter(!is.na(name), !is.na(synonyms)) |>
  mutate(synonym = strsplit(synonyms, "\\s*[,;\n]\\s*")) |> tidyr::unnest(synonym) |>
  mutate(synonym = squeeze(synonym)) |> filter(!is.na(synonym)) |>
  group_by(name = synonym) |> summarise(synonym_of = paste(sort(unique(.data$name)), collapse = "; "), .groups = "drop")
variant <- ev |> group_by(name) |>
  summarise(key = first(key), class = first(class), rule = if_else(any(!is.na(name_repaired)), "repaired", "key"),
            repaired_to = first(name_repaired), n = n(), n_positioned = sum(position_basis != "none" & !summary),
            n_vessel = n_distinct(vessel, na.rm = TRUE), sources = paste(sort(unique(source)), collapse = ", "),
            .groups = "drop") |>
  left_join(dict, by = "name") |> left_join(syn, by = "name") |> arrange(key, desc(n))

outcome <- bind_rows(outcomes)

# Check and write -----------------------------------------------------------------------------------------------------
staged <- c(trackwell_haul = nrow(th), trackwell_area = nrow(ta), plotter_mark = nrow(pm), chart_name = nrow(ch),
            lmi_name = nrow(lm), drawn_area = nrow(dr), recapture_place = nrow(rp), recapture_reading = nrow(rr),
            tag_recapture = nrow(tr), tag_release = nrow(tl), article_record = nrow(ar), document_name = nrow(dn),
            oracle_name = nrow(on), channel_name = nrow(cn), uv_area = nrow(uva))
got <- outcome |> filter(source_table %in% names(staged)) |> group_by(source_table) |> summarise(rows = sum(rows))
stopifnot("every staged row in one outcome" = all(got$rows == staged[got$source_table]), length(got$rows) == length(staged),
          !anyNA(ev$key), !any(ev$key == ""), !anyDuplicated(ev[c("source_table", "source_key")]))

print(knitr::kable(outcome, caption = "curated/place_name/outcome"))
print(knitr::kable(ev |> group_by(source) |> summarise(occurrences = n(), names = n_distinct(name), keys = n_distinct(key),
  positioned = sum(position_basis != "none" & !summary), flagged = sum(!is.na(position_flag)), with_gear = sum(!is.na(gear))),
  caption = "curated/place_name/evidence"))
cat("spellings", nrow(variant), " keys", n_distinct(variant$key), " lost-letter names repaired", sum(!is.na(fit)), "of", length(fit),
    " with a hand reading", sum(!is.na(variant$reading)), " synonyms", sum(!is.na(variant$synonym_of)), "\n")

inputs <- c(fd_path("staging", "ornefni", paste0(c("trackwell_haul", "trackwell_area", "plotter_mark", "chart_name", "lmi_name",
  "recapture_place", "recapture_reading", "name_dictionary", "drawn_area", "article_record", "document_name",
  "oracle_name", "channel_name", "tag_recapture", "tag_release", "uv_area"), ".parquet")),
  fd_curated("logbook", "station_window.parquet"), fd_curated("logbook", "gear.parquet"))
write_curated(ev, fd_curated("place_name", "evidence.parquet"), inputs = inputs)
write_curated(variant, fd_curated("place_name", "variant.parquet"), inputs = inputs)
write_curated(outcome, fd_curated("place_name", "outcome.parquet"), inputs = inputs)
