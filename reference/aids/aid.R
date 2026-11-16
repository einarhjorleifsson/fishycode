# aid.R — the curated list of aids to navigation (lights and leading lights, buoys, sea and leading marks, radar beacons) from
# several witnesses: every record of every list in one outcome, each attribute of an aid from its best witness with its basis
# beside it (plan 074 step 9; the named-features study's 93_aids.R and 96_aids_witnesses.R, the prototype and its measurement).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 074 ask p, the maintainer, 2026-11-16:
# "this whole process should go into the flow: raw -> staged -> out or curated"; "Standalone in layers").
#
# Input:  staging/vitaskra/aid.parquet (sources/vitaskra/aid.R: the List of Lights in force, 546 aids)
#         staging/vegagerdin/{light,wave_buoy}.parquet (sources/vegagerdin/light.R: 101 lights, the List's own; 12 wave buoys)
#         staging/osm/{seamark,seamark_tag}.parquet (sources/osm/seamark.R: 495 objects, NGA's list of 2010 most)
#         staging/is50v/lighthouse.parquet (sources/is50v/lighthouse.R: LMÍ's 108, accuracy 1-10 m stated)
#         staging/wikidata/lighthouse.parquet (sources/wikidata/lighthouse.R: 130 items, an aggregator)
#         staging/sjokort/{light_characteristic,aid_lettering}.parquet (sources/sjokort/aid_label.R) and
#         curated/reference/chart_names.parquet (reference/chart_names.R): the charts' printed characteristics and letterings
# Output: curated/reference/aid.parquet - one row per aid (a place): kind, name, characteristic, position (WKB geometry, lon,
#         lat), height, range, the Admiralty number, each with its basis (the list it came from); the position's precision;
#         the witnesses, their counts, the spread; outcome and the conflict's reasons; the area; the free text gathered
#         curated/reference/aid_record.parquet - every record of every list, one row each: list, role (witness, label, copy,
#         not_an_aid), kind, name, characteristic, position and its precision, height, range, number, a copy's original, a
#         label's attachment, place, outcome
#         curated/reference/aid_pair.parquet - every pair of position witnesses of two lists within 2 km: distance, kinds,
#         characteristics, numbers and names with their agreement, joined, by number, position_differ
#         curated/reference/aid_description.parquet - every descriptive field of every record, one row a field, as delivered
#         curated/check/aid_join_rules.parquet - the join's alternatives measured, the Admiralty number as the test
#
# The join (plan 074 step 9, measured on the prototype): two witness records of two position lists are one aid when they share
# an Admiralty number that each list gives to one record only (within 2 km); the rest when each is the other's nearest record
# of that list of the same kind, their characteristics not disagreeing, numbers not differing, within D = 100 m (ISN93).
# Places are the connected sets. The alternatives (nearest alone, by kind, by kind and characteristic, widened by the
# coordinates' digits; D 50 to 500 m) are measured into aid_join_rules: at 100 m the nearest alone joins 14 pairs whose
# numbers differ and misses 55 of one number; this rule none and 6 (the numbers a list gives twice).
# Copies: a Wikidata item at the very position (under 1 m) of the OpenStreetMap object that names it.
# The charts are labels, not positions (ask m): a printed characteristic attaches to the aid whose characteristic agrees
# within LABEL_MM = 5 mm of its box on its chart, a lettering of a light to the aid whose name agrees within NAME_MM = 10 mm
# (names are lettered farther out); a label attached nowhere is an aid of its own where an aid of some list lies within 20 mm,
# else a reading, not an aid; a text over 40 mm long is a line run across the chart.
# Conflicts are listed, not resolved (the maintainer, 2026-11-16): two witnesses of one list in a place (one_list_twice), the
# characteristics (char_differ) or numbers (number_differ) of joined records disagreeing, joined records farther apart than
# their digits allow (position_differ), a witness of a list the place lacks within D that found no partner of that list
# elsewhere (ambiguous).
# Best witness (ask m, dug into by the study's 96, settled by the maintainer 2026-11-16): position Vegagerðin's geometry (the List's own position before its
# rounding: nearer IS 50V than the List at 58 of 95 lighthouses), the List at 1/100 minute, IS 50V, the List at 1/10, OSM,
# Wikidata, a chart's label; characteristic, height, range and number the List, Vegagerðin, OSM (IS 50V for the number),
# Wikidata, the charts' characteristic last; name the List, Vegagerðin, IS 50V, OSM, Wikidata, the chart.
# The wave buoys are measuring buoys, kept not aids (the maintainer may say otherwise: the List lists all 12 as lit special
# buoys, öldudufl), each noted with the List's buoy near it.
# Internal: the charts' read (Landhelgisgæslan's charts). Nothing in the flow reads these tables yet.
# Run from the repo root: Rscript reference/aids/aid.R   (RULE=, D= give the alternatives' own outputs, under curated/scratch/)
# Written by Claude (AI).
library(sf)
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R", "R/curated_list.R", "R/light_characteristic.R")) source(f)   # standalone: not targets'
RULE <- Sys.getenv("RULE", "number"); D <- as.numeric(Sys.getenv("D", "100"))
LABEL_MM <- 5; NAME_MM <- 10; NEAR_MM <- 20
OUT <- if (RULE == "number" && D == 100) fd_curated("reference") else fd_curated("scratch", paste0("aid_", RULE, "_", D))
CHK <- if (RULE == "number" && D == 100) fd_curated("check") else OUT
num <- function(x) suppressWarnings(as.numeric(sub(",", ".", cl_blank(x))))
range_max <- function(x) vapply(strsplit(ifelse(is.na(cl_blank(x)), "", x), "[-/ |]+"), function(z) {
  z <- suppressWarnings(as.numeric(sub(",", ".", z))); if (all(is.na(z))) NA_real_ else max(z, na.rm = TRUE) }, numeric(1))
area_of <- function(lon, lat) ifelse(lon >= -8 & lon <= -6 & lat >= 61.3 & lat <= 62.5, "faroes",
  ifelse(lat > 67.5 & lon < -20, "greenland", ifelse(lon >= -25.5 & lon <= -12.5 & lat >= 62.9 & lat <= 67.6, "iceland", "other")))
intl_norm <- function(x) { x <- toupper(gsub("\\s", "", cl_blank(x))); x <- sub(",", ".", x)
  k <- !is.na(x) & grepl("^[0-9]", x); x[k] <- paste0("L", x[k]); x[!is.na(x) & !grepl("^[A-Z][0-9]+(\\.[0-9]+)?$", x)] <- NA; x }
GENERIC <- c("innsiglingarviti", "innsiglingarljos", "aukaviti", "flugviti", "hafnarviti", "leidarljos", "leidarmerki", "ljosdufl",
             "dufl", "bauja", "baujan", "radarsvari", "radarspegill", "radarmerki", "bryggjuljos", "fremra", "aftara", "efra", "nedra",
             "ytra", "innra", "nr", "vitar", "vitinn", "viti", "framkvaemda", "lighthouse", "light", "lights", "range", "rear", "front",
             "upper", "lower", "airfield", "aero", "rock", "pier", "head", "breakwater", "harbour", "harbor", "entrance", "beacon",
             "buoy", "point", "the", "of", "and")
rec_of <- function(list, id, own_id = NA, role = "witness", kind = NA, kind_given = NA, name = NA, char = NA, lon, lat,
                   precision = NA, res_m = NA, height_m = NA, range_given = NA, intl = NA, note = NA, chart = NA, scale = NA)
  data.frame(list = list, record_id = as.character(id), own_id = as.character(own_id), role = role, kind = kind,
             kind_given = cl_blank(kind_given), name = cl_blank(name), char_given = cl_blank(char), lon = as.numeric(lon),
             lat = as.numeric(lat), precision = precision, res_m = as.numeric(res_m), height_m = as.numeric(height_m),
             range_given = cl_blank(range_given), intl = intl_norm(intl), note = cl_blank(note), chart = chart,
             scale = as.numeric(scale), stringsAsFactors = FALSE)
rd <- function(...) as.data.frame(nanoparquet::read_parquet(fd_staging(...)))
INPUTS <- c(fd_staging("vitaskra", "aid.parquet"), fd_staging("vegagerdin", "light.parquet"), fd_staging("vegagerdin", "wave_buoy.parquet"),
            fd_staging("osm", "seamark.parquet"), fd_staging("osm", "seamark_tag.parquet"), fd_staging("is50v", "lighthouse.parquet"),
            fd_staging("wikidata", "lighthouse.parquet"), fd_staging("sjokort", "light_characteristic.parquet"),
            fd_staging("sjokort", "aid_lettering.parquet"), fd_curated("reference", "chart_names.parquet"))

# Records ---------------------------------------------------------------------------------------------------------------------
## The List of Lights ---------------------------------------------------------------------------------------------------------
vs <- rd("vitaskra", "aid.parquet")
r_vs <- rec_of("vitaskra", sprintf("p%03d_l%02d", vs$page, vs$line), own_id = cl_blank(vs$number), kind = vs$part, kind_given = vs$part,
               name = vs$full_name, char = vs$characteristic, lon = vs$lon, lat = vs$lat,
               precision = ifelse(startsWith(vs$precision, "exact"), "1/100 minute", "1/10 minute"),
               res_m = ifelse(startsWith(vs$precision, "exact"), 0.01, 0.1) * 1852, height_m = num(vs$height_m),
               range_given = vs$range_nm, intl = vs$intl)
## Vegagerðin's lights and wave buoys -------------------------------------------------------------------------------------------
vg <- rd("vegagerdin", "light.parquet")
r_vg <- rec_of("vegagerdin", vg$OBJECTID, own_id = vg$NR, kind = "light", kind_given = "viti", name = vg$HEITI, char = vg$LJOSEINKENNI,
               lon = vg$lon, lat = vg$lat, precision = "ISN93 metres", res_m = 1, height_m = num(vg$LJOSHAED),
               range_given = vg$SJONARLENGD, intl = vg$ADMR, note = paste0(vg$NAFN_STAD, "; ", vg$BYGGING))
wb <- rd("vegagerdin", "wave_buoy.parquet")
r_wb <- rec_of("wave_buoy", wb$IDDUFL, own_id = wb$IDDUFL, role = "not_an_aid", kind = "wave_buoy", kind_given = "öldudufl",
               name = wb$NAFN, lon = wb$lon, lat = wb$lat, precision = "ISN93 metres", res_m = 1,
               note = "a wave-measuring buoy, not an aid to navigation")
## OpenStreetMap ----------------------------------------------------------------------------------------------------------------
os <- rd("osm", "seamark.parquet"); ot <- rd("osm", "seamark_tag.parquet")
tags <- lapply(split(ot, factor(ot$osm_id, levels = os$osm_id)), function(d) setNames(d$value, d$key))
tg <- function(k) vapply(tags, function(t) if (k %in% names(t)) t[[k]] else NA_character_, character(1), USE.NAMES = FALSE)
tg_any <- function(pat, f = function(v) paste(unique(v), collapse = ";")) vapply(tags, function(t) { v <- t[grepl(pat, names(t))]
  if (length(v)) f(v) else NA_character_ }, character(1), USE.NAMES = FALSE)
otype <- ifelse(is.na(tg("seamark:type")), paste0("man_made=", tg("man_made")), tg("seamark:type"))
lit <- !is.na(tg_any("^seamark:light(:[0-9]+)?:character$"))
okind <- ifelse(otype %in% c("light_major", "light_minor", "light_vessel", "light_float", "man_made=lighthouse"), "light",
         ifelse(grepl("^buoy_", otype), "buoy",
         ifelse(grepl("^beacon_|^daymark$|^landmark$|^man_made=beacon$", otype), ifelse(lit, "light", "mark"),
         ifelse(otype == "radar_transponder", "racon", NA))))
# a light's characteristics from OpenSeaMap's tags: each light of the object (seamark:light:* and every seamark:light:<n>:*)
# its rhythm, group and period; the sectors of one rhythm, group and period one characteristic with all their colours
o_char <- vapply(tags, function(t) {
  ids <- unique(sub("^seamark:light:(([0-9]+):)?(character|colour|group|period)$", "\\2", grep("^seamark:light:([0-9]+:)?(character|colour|group|period)$", names(t), value = TRUE)))
  if (!length(ids)) return(NA_character_)
  g <- function(n, k) { nm <- if (nzchar(n)) paste0("seamark:light:", n, ":", k) else paste0("seamark:light:", k)
    v <- if (nm %in% names(t)) t[[nm]] else if (nzchar(n) && paste0("seamark:light:", k) %in% names(t)) t[[paste0("seamark:light:", k)]] else NA
    if (is.na(v) || !nzchar(v)) NA else v }
  li <- do.call(rbind, lapply(ids, function(n) data.frame(ch = g(n, "character"), gr = g(n, "group"), pe = g(n, "period"), col = g(n, "colour"))))
  li <- li[!is.na(li$ch), , drop = FALSE]; if (!nrow(li)) return(NA_character_)
  key <- paste(li$ch, ifelse(is.na(li$gr), "", li$gr), ifelse(is.na(li$pe), "", li$pe))
  out <- vapply(unique(key), function(k) { d <- li[key == k, , drop = FALSE]
    col <- unique(unlist(strsplit(d$col[!is.na(d$col)], ";")))
    col <- c(white = "W", red = "R", green = "G", yellow = "Y", blue = "Bu")[col]
    col <- paste(intersect(c("W", "R", "G", "Y", "Bu"), col[!is.na(col)]), collapse = "")
    paste0(d$ch[1], if (!is.na(d$gr[1])) paste0("(", d$gr[1], ")") else "", " ", col, if (!is.na(d$pe[1])) paste0(" ", d$pe[1], "s") else "") }, character(1))
  paste(gsub("\\s+", " ", trimws(out)), collapse = " | ") }, character(1), USE.NAMES = FALSE)
o_res <- cl_digits_min(os$lat, os$lon)
r_osm <- rec_of("osm", os$osm_id, own_id = os$osm_id, role = ifelse(is.na(okind), "not_an_aid", "witness"),
                kind = ifelse(is.na(okind), otype, okind), kind_given = otype,
                name = ifelse(is.na(tg("seamark:name")), tg("name"), tg("seamark:name")), char = o_char, lon = os$lon, lat = os$lat,
                precision = ifelse(is.na(o_res), "finer than 1/1000 minute", paste(o_res, "minute (the digits)")),
                res_m = ifelse(is.na(o_res), 1, o_res * 1852),
                height_m = num(ifelse(is.na(tg("seamark:light:height")), tg_any("^seamark:light:[0-9]+:height$", function(v) v[[1]]), tg("seamark:light:height"))),
                range_given = tg_any("^seamark:light(:[0-9]+)?:range$"),
                intl = ifelse(is.na(tg("seamark:light:reference")), tg("ref:admiralty"), tg("seamark:light:reference")), note = tg("source"))
r_osm$note[r_osm$role == "not_an_aid"] <- paste0("not an aid: ", otype[r_osm$role == "not_an_aid"])
## LMÍ's lighthouses (IS 50V) ---------------------------------------------------------------------------------------------------
is5 <- rd("is50v", "lighthouse.parquet")
ath <- ifelse(is.na(is5$ath), "", is5$ath); has_no <- grepl("L ?[0-9]", ath); is_no <- rep(NA_character_, nrow(is5))
is_no[has_no] <- regmatches(ath, regexpr("L ?[0-9]+(\\.[0-9]+)?", ath))
r_is5 <- rec_of("is50v", is5$uuid, own_id = is5$objectid, kind = "light", kind_given = "mannvirki 6510 (viti)", name = is5$nafnfitju,
                lon = is5$lon, lat = is5$lat, precision = paste(is5$nakvaemnixy, "m (stated)"), res_m = is5$nakvaemnixy,
                intl = is_no, note = paste0(cl_blank(is5$ath), "; ", is5$heimild))
## Wikidata: one row a combination of values, folded to one an item ---------------------------------------------------------------
wd <- rd("wikidata", "lighthouse.parquet")
fold <- function(v) { v <- unique(cl_blank(v)); v <- v[!is.na(v)]; if (length(v)) paste(v, collapse = " | ") else NA_character_ }
wcols <- setdiff(names(wd), c("lon", "lat", "file"))
wdi <- do.call(rbind, lapply(split(wd, factor(wd$item, levels = unique(wd$item))), function(d)
  as.data.frame(lapply(d[, wcols], fold), stringsAsFactors = FALSE)))
w1 <- wd[!duplicated(wd$item), ]
w_dec <- vapply(strsplit(sub("^Point\\(([^)]*)\\)$", "\\1", w1$coord), " "), function(z) min(nchar(sub("^[^.]*\\.?", "", z))), numeric(1))
w_res <- cl_digits_min(w1$lat, w1$lon)
r_wd <- rec_of("wikidata", wdi$item, own_id = wdi$item, kind = "light", kind_given = "lighthouse",
               name = ifelse(is.na(wdi$label_is), wdi$label_en, wdi$label_is), char = wdi$characteristic, lon = w1$lon, lat = w1$lat,
               precision = ifelse(!is.na(w_res), paste(w_res, "minute (the digits)"), paste0(w_dec, " decimals of a degree")),
               res_m = ifelse(!is.na(w_res), w_res * 1852, 10^-w_dec * 111320), height_m = num(sub(" \\|.*", "", wdi$focal_height)),
               range_given = wdi$range, intl = sub(" \\|.*", "", wdi$admiralty),
               note = paste0(ifelse(is.na(wdi$description_en), "", wdi$description_en), "; NGA ", ifelse(is.na(wdi$nga), "-", wdi$nga)))
## The charts: letterings of lights (chart_names) and the characteristics printed --------------------------------------------------
cn <- read_curated_sf(fd_curated("reference", "chart_names.parquet"))
al <- rd("sjokort", "aid_lettering.parquet")
lt <- cn$kind %in% "light" | cn$class %in% "light" | paste(cn$chart, cn$label_id) %in% paste(al$chart, al$label_id)
cnl <- st_drop_geometry(cn)[lt, ]; cnl_g <- st_transform(st_geometry(cn)[lt], 3057)
r_cl <- rec_of("chart", paste0(cnl$chart, ":label_", cnl$label_id), own_id = cnl$label_id, role = "label", kind = "light",
               kind_given = ifelse(paste(cnl$chart, cnl$label_id) %in% paste(al$chart, al$label_id), "an aid's lettering (84)", "lettering of a light (the read)"),
               name = cnl$name, lon = cnl$lon, lat = cnl$lat, precision = "a label", res_m = NAME_MM / 1000 * cnl$scale,
               chart = cnl$chart, scale = cnl$scale)
ct <- rd("sjokort", "light_characteristic.parquet")
ct_g <- st_transform(st_as_sfc(ct$box_wkt, crs = 4326), 3057)
r_ct <- rec_of("chart", paste0(ct$chart, ":text_", ct$text_id), own_id = ct$text_id, role = ifelse(ct$len_mm > 40, "not_an_aid", "label"),
               kind = ifelse(ct$len_mm > 40, "a line run across the chart", "lit"), kind_given = "a light's characteristic printed",
               char = ct$text, lon = ct$lon, lat = ct$lat, precision = "a label", res_m = LABEL_MM / 1000 * ct$scale,
               note = ifelse(ct$len_mm > 40, sprintf("not an aid: the read's text is %.0f mm long, a line across the chart", ct$len_mm), NA),
               chart = ct$chart, scale = ct$scale)
rec <- rbind(r_vs, r_vg, r_wb, r_osm, r_is5, r_wd, r_cl, r_ct)
rec$rid <- seq_len(nrow(rec)); rec$area <- area_of(rec$lon, rec$lat); rec$res_m <- round(rec$res_m, 1)
rec$char <- light_char_text(light_char_parse(sub(" \\|.*", "", rec$char_given)))
stopifnot(!anyDuplicated(paste(rec$list, rec$record_id)), !anyNA(rec$lon), !anyNA(rec$lat))
LG <- c(cnl_g, ct_g); LG_rid <- rec$rid[rec$list == "chart"]; stopifnot(length(LG) == length(LG_rid))
KEYS <- cl_name_keys(rec$name, GENERIC)

## Descriptions: every descriptive field of every record, one row a field, as delivered -----------------------------------------
osm_rid <- rec$rid[rec$list == "osm"]
desc <- rbind(
  cl_long(rec$rid[rec$list == "vitaskra"], vs[, setdiff(names(vs), c("lat", "lon"))]),
  cl_long(rec$rid[rec$list == "vegagerdin"], vg[, setdiff(names(vg), c("lon", "lat"))]),
  cl_long(rec$rid[rec$list == "wave_buoy"], wb[, setdiff(names(wb), c("lon", "lat"))]),
  data.frame(rid = osm_rid[match(ot$osm_id, os$osm_id)], field = ot$key, text = ot$value),
  cl_long(rec$rid[rec$list == "is50v"], is5[, setdiff(names(is5), c("lon", "lat"))]),
  cl_long(rec$rid[rec$list == "wikidata"], wdi),
  cl_long(rec$rid[rec$list == "chart"],
          rbind(data.frame(chart = cnl$chart, label_id = cnl$label_id, name = cnl$name, kind = cnl$kind, class = cnl$class, scale = cnl$scale,
                           text = NA, clean = NA, outcome_read = NA, reads = NA, len_mm = NA),
                data.frame(chart = ct$chart, label_id = NA, name = NA, kind = NA, class = NA, scale = ct$scale, text = ct$text, clean = ct$clean,
                           outcome_read = ct$outcome_read, reads = ct$reads, len_mm = ct$len_mm))))
desc <- desc[order(desc$rid), ]

# Positions in ISN93; the wave buoys against the List's ------------------------------------------------------------------------
P <- st_transform(st_as_sf(rec, coords = c("lon", "lat"), crs = 4326, remove = FALSE), 3057); XY <- st_coordinates(P)
dist_m <- function(i, j) sqrt((XY[i, 1] - XY[j, 1])^2 + (XY[i, 2] - XY[j, 2])^2)
ol <- which(rec$list == "vitaskra" & rec$kind == "buoy" & grepl("öldudufl", rec$name, ignore.case = TRUE))
nd <- which(rec$list == "wave_buoy")
wave_vs <- do.call(rbind, lapply(nd, function(i) { d <- dist_m(i, ol); k <- ol[which.min(d)]
  data.frame(wave_buoy = rec$name[i], listed_as = rec$name[k], characteristic = rec$char_given[k], dist_m = round(min(d))) }))
rec$note[nd] <- ifelse(wave_vs$dist_m <= 1000, sprintf("%s; the List of Lights lists a wave buoy %d m away: %s, %s", rec$note[nd],
                                                       wave_vs$dist_m, wave_vs$listed_as, wave_vs$characteristic), rec$note[nd])

# Pairs of position witnesses ---------------------------------------------------------------------------------------------------
W <- which(rec$role == "witness")
pr <- cl_pairs(XY, rec$list, rec$role == "witness", 2000)
pr$same_kind <- rec$kind[pr$i] == rec$kind[pr$j]
pr$chars_agree <- light_char_agree(rec$char_given[pr$i], rec$char_given[pr$j])
pr$chars_equal <- ifelse(is.na(rec$char[pr$i]) | is.na(rec$char[pr$j]), NA, rec$char[pr$i] == rec$char[pr$j])
pr$numbers_agree <- ifelse(is.na(rec$intl[pr$i]) | is.na(rec$intl[pr$j]), NA, rec$intl[pr$i] == rec$intl[pr$j])
pr$names_agree <- cl_names_agree(KEYS[pr$i], KEYS[pr$j])
pr$reach_m <- pmax(D, rec$res_m[pr$i] + rec$res_m[pr$j])
pr$same_position <- pr$dist_m < 1
nk <- paste(rec$list, rec$intl)[W][!is.na(rec$intl[W])]; dup_no <- unique(nk[duplicated(nk)])
pr$number_unique <- !paste(rec$list[pr$i], rec$intl[pr$i]) %in% dup_no & !paste(rec$list[pr$j], rec$intl[pr$j]) %in% dup_no

# The join and its alternatives ---------------------------------------------------------------------------------------------------
join_rule <- function(rule, d) {
  base <- pr$dist_m <= d; pref <- pr$chars_agree %in% TRUE
  kc <- pr$same_kind & !(pr$chars_agree %in% FALSE)
  switch(rule,
    near = cl_mutual(pr, rec$list, base, pref),
    kind = cl_mutual(pr, rec$list, base & pr$same_kind, pref),
    kind_char = cl_mutual(pr, rec$list, base & kc, pref),
    digits = cl_mutual(pr, rec$list, pr$dist_m <= pmax(d, rec$res_m[pr$i] + rec$res_m[pr$j]) & kc, pref),
    number = , number_digits = {
      byno <- pr$numbers_agree %in% TRUE & pr$dist_m <= 2000 & pr$number_unique
      done <- unique(c(paste(pr$i[byno], rec$list[pr$j[byno]]), paste(pr$j[byno], rec$list[pr$i[byno]])))
      free <- !paste(pr$i, rec$list[pr$j]) %in% done & !paste(pr$j, rec$list[pr$i]) %in% done
      reach <- if (rule == "number_digits") pr$dist_m <= pmax(d, rec$res_m[pr$i] + rec$res_m[pr$j]) else base
      byno | cl_mutual(pr, rec$list, reach & free & kc & !(pr$numbers_agree %in% FALSE), pref) })
}
measure <- function(rule, d) {
  j <- join_rule(rule, d); pl <- cl_places(nrow(rec), pr, j, W)
  twice <- tapply(rec$list[W], pl[W], function(l) anyDuplicated(l) > 0)
  near_no <- pr$numbers_agree %in% TRUE & pr$dist_m <= 2000
  data.frame(rule = rule, D = d, joins = sum(j), places = length(unique(pl[W])),
             joins_number_same = sum(j & pr$numbers_agree %in% TRUE), joins_number_differ = sum(j & pr$numbers_agree %in% FALSE),
             same_number_not_joined = sum(near_no & !j & pl[pr$i] != pl[pr$j]),
             joins_chars_agree = sum(j & pr$chars_agree %in% TRUE), joins_chars_differ = sum(j & pr$chars_agree %in% FALSE),
             joins_names_agree = sum(j & pr$names_agree %in% TRUE), joins_names_differ = sum(j & pr$names_agree %in% FALSE),
             joins_kind_differ = sum(j & !pr$same_kind), places_one_list_twice = sum(twice)) }
rules <- do.call(rbind, lapply(c("near", "kind", "kind_char", "digits", "number", "number_digits"), function(r)
  do.call(rbind, lapply(c(50, 100, 250, 500), function(d) measure(r, d)))))
pr$joined <- join_rule(RULE, D)
pr$by_number <- RULE %in% c("number", "number_digits") & pr$joined & pr$numbers_agree %in% TRUE & pr$dist_m <= 2000 & pr$number_unique
pr$position_differ <- pr$joined & pr$dist_m > pr$reach_m

# Copies: a Wikidata item at the position of the OpenStreetMap object that names it (under 1 m) ---------------------------------
osm_qid <- tg("wikidata"); rec$copy_of <- NA_integer_; rec$copy_m <- NA_real_
for (i in which(rec$list == "wikidata")) { o <- osm_rid[osm_qid %in% rec$record_id[i]]; if (!length(o)) next
  d <- dist_m(i, o); if (min(d) < 1) { rec$copy_of[i] <- o[which.min(d)]; rec$copy_m[i] <- round(min(d), 2) } }
cp <- which(!is.na(rec$copy_of)); rec$role[cp] <- "copy"
drop <- pr$i %in% cp | pr$j %in% cp; pr$joined[drop] <- FALSE; pr$by_number[drop] <- FALSE; pr$position_differ[drop] <- FALSE
W <- which(rec$role == "witness"); rec$place <- cl_places(nrow(rec), pr, pr$joined, W); rec$place[cp] <- rec$place[rec$copy_of[cp]]

# The charts' labels attach to the aid they name or whose characteristic they print ----------------------------------------------
L <- which(rec$role == "label")
rec$attach_rid <- NA_integer_; rec$attach_m <- NA_real_; rec$attach_mm <- NA_real_; rec$attach_by <- NA_character_; rec$near_mm <- NA_real_
Wp <- W[rec$area[W] != "faroes"]; LGl <- LG[match(rec$rid[L], LG_rid)]
reach <- ifelse(rec$kind[L] == "lit", LABEL_MM, NAME_MM) / 1000 * rec$scale[L]
nbl <- st_is_within_distance(LGl, P[Wp, ], NEAR_MM / 1000 * max(rec$scale[L]))
for (a in seq_along(L)) {
  i <- L[a]; c <- Wp[nbl[[a]]]; if (!length(c)) next
  d <- as.numeric(st_distance(LGl[a], P[c, ])); rec$near_mm[i] <- round(min(d) / rec$scale[i] * 1000, 1)
  c <- c[d <= reach[a]]; d <- d[d <= reach[a]]; if (!length(c)) next
  if (rec$kind[i] == "lit") { ok <- rec$kind[c] %in% c("light", "buoy") & light_char_agree(rep(rec$char_given[i], length(c)), rec$char_given[c]) %in% TRUE; by <- "characteristic"
  } else { ok <- rec$kind[c] %in% c("light", "buoy", "mark") & cl_names_agree(KEYS[rep(i, length(c))], KEYS[c]) %in% TRUE; by <- "name" }
  if (!any(ok)) next
  k <- which(ok)[which.min(d[ok])]
  rec$attach_rid[i] <- c[k]; rec$attach_m[i] <- round(d[k]); rec$attach_mm[i] <- round(d[k] / rec$scale[i] * 1000, 2); rec$attach_by[i] <- by
}
rec$place[L] <- rec$place[rec$attach_rid[L]]
far <- L[is.na(rec$place[L]) & (is.na(rec$near_mm[L]) | rec$near_mm[L] > NEAR_MM)]
rec$role[far] <- "not_an_aid"; rec$note[far] <- sprintf("not an aid: no aid of any list within %g mm on its chart (the nearest %s)", NEAR_MM,
                                                        ifelse(is.na(rec$near_mm[far]), "farther", paste(rec$near_mm[far], "mm")))
L <- which(rec$role == "label"); lone <- L[is.na(rec$place[L])]
rec$place[lone] <- max(rec$place, na.rm = TRUE) + seq_along(lone)
rec$place <- match(rec$place, sort(unique(rec$place)))

# Outcomes ------------------------------------------------------------------------------------------------------------------------
IN <- which(!is.na(rec$place)); pl <- split(IN, rec$place[IN])
why <- vapply(pl, function(ix) {
  w <- ix[rec$role[ix] == "witness"]; r <- character()
  if (anyDuplicated(rec$list[w])) r <- c(r, "one_list_twice")
  jp <- pr[pr$joined & pr$i %in% w, ]
  if (any(jp$chars_agree %in% FALSE)) r <- c(r, "char_differ")
  if (any(jp$numbers_agree %in% FALSE)) r <- c(r, "number_differ")
  if (any(jp$position_differ)) r <- c(r, "position_differ")
  if (length(w)) {
    lim <- if (RULE %in% c("digits", "number_digits")) pr$reach_m else D
    near <- pr[!pr$joined & (pr$i %in% w | pr$j %in% w) & pr$same_kind & !(pr$chars_agree %in% FALSE) & !(pr$numbers_agree %in% FALSE) & pr$dist_m <= lim, ]
    mine <- ifelse(near$i %in% w, near$i, near$j); other <- ifelse(near$i %in% w, near$j, near$i)
    amb <- rec$role[other] == "witness" & !rec$list[other] %in% rec$list[w] & !other %in% w &
      !mapply(function(o, m) rec$list[m] %in% rec$list[rec$role == "witness" & rec$place %in% rec$place[o]], other, mine)
    if (any(amb)) r <- c(r, "ambiguous") }
  paste(r, collapse = ",") }, character(1))
n_lists <- vapply(pl, function(ix) length(unique(rec$list[ix[rec$role[ix] %in% c("witness", "label")]])), integer(1))
place_outcome <- ifelse(nzchar(why), "conflict", ifelse(n_lists >= 2, "several_witnesses", "one_witness"))
names(place_outcome) <- names(why) <- names(n_lists) <- names(pl)
rec$outcome <- ifelse(rec$role == "not_an_aid", "not_an_aid", ifelse(rec$role == "copy", "copy", place_outcome[as.character(rec$place)]))
stopifnot(!anyNA(rec$outcome))

# The curated list: one row an aid, each attribute from its best witness -------------------------------------------------------------
pos_rank <- function(l, p) ifelse(l == "vegagerdin", 1, ifelse(l == "vitaskra" & p == "1/100 minute", 2, ifelse(l == "is50v", 3,
  ifelse(l == "vitaskra", 4, ifelse(l == "osm", 5, ifelse(l == "wikidata", 6, 7))))))
ORDER <- list(char = c("vitaskra", "vegagerdin", "osm", "wikidata", "chart"), num = c("vitaskra", "vegagerdin", "osm", "is50v", "wikidata"),
              name = c("vitaskra", "vegagerdin", "is50v", "osm", "wikidata", "chart"), kind = c("vitaskra", "vegagerdin", "osm", "is50v", "wikidata", "chart"))
FREE <- c(vitaskra = "^(description|topmark)$", vegagerdin = "^(BYGGING|STADARLYSING)$", osm = "^(seamark:information|description|note)$",
          is50v = "^ath$", wikidata = "^description_(en|is)$")
desc$list <- rec$list[desc$rid]; desc$record_id <- rec$record_id[desc$rid]; desc$place <- rec$place[desc$rid]
free <- desc[mapply(function(l, f) l %in% names(FREE) && grepl(FREE[[l]], f), desc$list, desc$field) & rec$role[desc$rid] == "witness", ]
aid <- do.call(rbind, lapply(names(pl), function(p) { ix <- pl[[p]]; ev <- ix[rec$role[ix] %in% c("witness", "label")]
  pos <- ev[order(pos_rank(rec$list[ev], rec$precision[ev]), ev)][1]
  bb <- function(col, o) cl_best(ev, rec[[col]], rec$list, o)
  nm <- bb("name", ORDER$name); ch <- bb("char_given", ORDER$char); h <- bb("height_m", ORDER$num); rg <- bb("range_given", ORDER$num)
  no <- bb("intl", ORDER$num); kd <- bb("kind", ORDER$kind); w <- ev[rec$role[ev] == "witness"]
  f <- free[free$place %in% as.integer(p), ]
  data.frame(aid = as.integer(p), kind = kd[1], kind_basis = kd[2], name = nm[1], name_basis = nm[2],
             characteristic = ch[1], characteristic_basis = ch[2], lon = rec$lon[pos], lat = rec$lat[pos], position_basis = rec$list[pos],
             position_precision = rec$precision[pos], position_res_m = rec$res_m[pos], height_m = as.numeric(h[1]), height_basis = h[2],
             range_nm = rg[1], range_basis = rg[2], intl = no[1], intl_basis = no[2],
             witnesses = paste(sort(unique(rec$list[ev])), collapse = ","), n_lists = n_lists[[p]], n_position_lists = length(unique(rec$list[w])),
             n_records = length(ev), n_chart_labels = sum(rec$list[ev] == "chart"),
             spread_m = round(if (length(w) > 1) max(dist(XY[w, , drop = FALSE])) else 0),
             outcome = place_outcome[[p]], why = why[[p]], area = rec$area[pos],
             description = if (nrow(f)) paste(sprintf("[%s] %s", f$list, f$text), collapse = " || ") else NA_character_,
             n_descriptions = sum(desc$place %in% as.integer(p)), stringsAsFactors = FALSE) }))
aid$range_nm_max <- range_max(aid$range_nm)

# Write --------------------------------------------------------------------------------------------------------------------------
SCRIPT <- "reference/aids/aid.R"
rec_out <- cl_utf8(rec[, c("rid", "list", "record_id", "own_id", "role", "kind", "kind_given", "name", "char_given", "char", "lon", "lat",
                           "area", "precision", "res_m", "height_m", "range_given", "intl", "note", "chart", "scale", "copy_of", "copy_m",
                           "attach_rid", "attach_m", "attach_mm", "attach_by", "near_mm", "place", "outcome")])
names(rec_out)[names(rec_out) == "place"] <- "aid"
pr_out <- cl_utf8(data.frame(list_i = rec$list[pr$i], rid_i = pr$i, name_i = rec$name[pr$i], kind_i = rec$kind[pr$i], char_i = rec$char_given[pr$i],
                             intl_i = rec$intl[pr$i], list_j = rec$list[pr$j], rid_j = pr$j, name_j = rec$name[pr$j], kind_j = rec$kind[pr$j],
                             char_j = rec$char_given[pr$j], intl_j = rec$intl[pr$j],
                             pr[, c("dist_m", "reach_m", "same_kind", "chars_agree", "chars_equal", "numbers_agree", "number_unique", "names_agree",
                                    "same_position", "joined", "by_number", "position_differ")], aid_i = rec$place[pr$i], aid_j = rec$place[pr$j]))
aid_sf <- st_as_sf(cl_utf8(aid), coords = c("lon", "lat"), crs = 4326, remove = FALSE)
desc_out <- cl_utf8(desc[, c("rid", "list", "record_id", "place", "field", "text")]); names(desc_out)[names(desc_out) == "place"] <- "aid"
write_curated(aid_sf, file.path(OUT, "aid.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(rec_out, file.path(OUT, "aid_record.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(pr_out, file.path(OUT, "aid_pair.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(desc_out, file.path(OUT, "aid_description.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(rules, file.path(CHK, "aid_join_rules.parquet"), inputs = INPUTS, script = SCRIPT)

# What was built, for the log -----------------------------------------------------------------------------------------------------
cat(sprintf("The aid list: rule %s, D %g m. %d records, %d aids.\n\nEvery record in one outcome, by list:\n", RULE, D, nrow(rec), nrow(aid)))
print(addmargins(table(rec$list, factor(rec$outcome, c("several_witnesses", "one_witness", "conflict", "copy", "not_an_aid")))))
cat("\nAids by outcome and area:\n"); print(table(aid$outcome, aid$area))
cat("\nConflict reasons:\n"); print(table(unlist(strsplit(aid$why[nzchar(aid$why)], ","))))
cat(sprintf("\nJoined by the Admiralty number: %d of %d joins; copies %d\n", sum(pr$by_number), sum(pr$joined), length(cp)))
cat("\nThe charts' labels: attached by name or characteristic, alone, or not aids:\n")
print(table(rec$chart[rec$list == "chart"], ifelse(!is.na(rec$attach_by), rec$attach_by, ifelse(rec$role == "not_an_aid", "not an aid", "alone"))[rec$list == "chart"]))
cat("\nThe wave buoys against the List of Lights' wave buoys:\n"); print(wave_vs, row.names = FALSE)
cat("\nThe best witness of position:\n"); print(table(aid$position_basis))
