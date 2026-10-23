# species.R — every species code of the logbooks and the landings, with its names, FAO code and WoRMS id (TODO 10).
# Side: preprocessing (reference). See plan 014.
#
# Input:  raw/oracle/ufs/fisktegundir.parquet            the Directorate's list of landed species (331): names, FAO code
#         raw/oracle/orri/fisktegundir.parquet           orri's list (686): names. kvoti's stadall_fisktegundir_v
#                                                        is 74 of its rows: kvoti's standard list, read from its table
#         raw/oracle/orri/fao_fisktegund_vorpun.parquet  FAO 3-alpha -> orri's code
#         raw/oracle/taxon/species.parquet               MFRI's species register (1,312): names, rank, taxocode,
#                                                        taxon unit
#         raw/oracle/taxon/taxon.parquet                 each taxon unit's source and its id there (WoRMS)
#         raw/oracle/kvoti/lods_fteg.parquet             lods' list (the landings of 1992-2007)
#         raw/oracle/afli/fiskar.parquet                 afli's list
#         raw/oracle/adb/species.parquet                 adb's list: its own id -> the code
#         raw/oracle/fs_ufs/landing_species.parquet      a landings code -> taxon number, WoRMS id, target assemblage
#         raw/oracle/fs_ufs/fisktegundir.parquet         a second copy of ufs's list, differing on 31 codes
#         raw/oracle/asfis/asfis.parquet                 FAO's list: the valid 3-alpha codes, and each taxocode's code
# Output: curated/reference/species.parquet   one row per species code (sid): Icelandic, English and scientific names,
#                                              FAO 3-alpha and WoRMS id, each with its layer, basis and the other
#                                              lists' values where they differ
#
# The codes are one numbering: ufs's, orri's and taxon's lists share 328 and 645 codes, and the logbooks and landings
# code by it. The lists' tables, not taxon's tegund_v, whose joins (taxon.taxon for the WoRMS id, asfis by taxocode
# for the FAO code) are done here (decision 182).
#
# Not every list means the same species by a code: ufs's 278 is Bretahveðnir, orri's and taxon's a sixgill shark.
# A code's identity is its anchor's, the first list in the name order that holds it, and a list's values are taken
# only where its record of the code is the same taxon as the anchor's: an Icelandic name in common, a scientific name
# at the same rank, or one's name the other's scientific name. A list whose record cannot be matched so (another
# taxon, or a catch-all in other words) is listed in `lists_unmatched`; its values are kept in the `_other` columns,
# never taken.

library(tidyverse)
library(nanoparquet)

ora <- function(schema, table) as_tibble(read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet"))))

asfis <- ora("asfis", "asfis")

# The order of the lists, best first, per field (docs/grammar.qmd, the layer). ufs first: it is the list of the
# systems that code most of the sweep (agf, fs_afladagbok, adb), and where it and orri name a code differently the
# sweep's rows are the Directorate's. orri holds twice ufs's codes, taxon is MFRI's register. For the scientific name
# taxon first, whose names are checked against WoRMS; the others carry authors and misspellings.
layer_order <- tribble(
  ~field,       ~layer,
  "name",       "ufs.fisktegundir",
  "name",       "orri.fisktegundir",
  "name",       "taxon.species",
  "name",       "kvoti.lods_fteg",
  "name",       "afli.fiskar",
  "name",       "adb.species",
  "name",       "fs_ufs.fisktegundir",
  "name_en",    "ufs.fisktegundir",
  "name_en",    "orri.fisktegundir",
  "name_en",    "taxon.species",
  "name_en",    "fs_ufs.landing_species",
  "name_en",    "fs_ufs.fisktegundir",
  "name_sci",   "taxon.species",
  "name_sci",   "orri.fisktegundir",
  "name_sci",   "ufs.fisktegundir",
  "name_sci",   "fs_ufs.landing_species",
  "name_sci",   "fs_ufs.fisktegundir",
  "fao_3a",     "ufs.fisktegundir",
  "fao_3a",     "orri.fao_fisktegund_vorpun",
  "fao_3a",     "asfis.asfis",
  "fao_3a",     "fs_ufs.fisktegundir",
  "worms_id",   "fs_ufs.landing_species",
  "worms_id",   "taxon.taxon",
  "taxon_rank", "taxon.species",
  "target_assemblage", "fs_ufs.landing_species") |>
  mutate(rank = row_number(), .by = field)

# Codes no list names, or whose meaning in a source is not the list's (decision 182 has the counts) -------------------
declared <- tribble(
  ~sid, ~note,
  0,    "No list names it: a species not entered (afli, lods).",
  999,  paste("Not in afli's own list; taxon names it unidentifiable. In afli (1973-1990, bottom trawl, often the",
              "station's only species) most likely catch not split by species: not established."),
  -30,  "afli's own code: herring let go (sleppt), not landed.",
  -31,  "afli's own code: capelin let go (sleppt), not landed.",
  -34,  "afli's own code: blue whiting let go (sleppt), not landed.",
  278,  paste("ufs and adb: Bretahveðnir - 1 (adb maps it to 512); orri and taxon: Brandháfur, a sixgill shark;",
              "landing_species gives it no taxon number. The landings (agf) code by ufs."),
  953,  "ufs: Langhali (adb maps it to 122); orri and lods: Skötuselur 2.",
  165,  "orri: 'do not use this number, use 125'; ufs: Litli loðháfur.",
  445,  paste("afli: Slitinn humar (Norway lobster, broken), 2019-2021 on Nephrops trawl, never on a station that",
              "also logs 40; the other lists: Sækönguló (sea spider)."),
  901,  paste("A placeholder (platfiskur1), no species; adb maps it to 55 (Annað). landing_species gives it cod with",
              "no taxon number, not taken."),
  665,  "Ansjósa (anchovy): named by ufs, orri and taxon, by none of the four lists TODO 10 measured.",
  533,  "Geirnefur (Atlantic saury): named by ufs, orri and taxon, by none of the four lists TODO 10 measured.",
  269,  "Ljósátur, Thysanoessa (krill): named by ufs, orri and taxon, by none of the four lists TODO 10 measured.",
  1128, "Beltisþari (sea belt): named by ufs only.",
  954,  "Bleikja (Arctic char): named by ufs only.") |>
  mutate(sid = as.integer(sid))

# Each list's record of a code -----------------------------------------------------------------------------------------
# One row per (code, list): the Icelandic and scientific names that say which taxon the list means, and the fields it
# gives, each with the table it came from and its basis.
ufs <- ora("ufs", "fisktegundir")
orri <- ora("orri", "fisktegundir")
taxon <- ora("taxon", "species") |>
  left_join(ora("taxon", "taxon") |> select(taxon_unit_id, taxon_source, taxon_source_id), by = "taxon_unit_id")
lods <- ora("kvoti", "lods_fteg")
afli <- ora("afli", "fiskar")
fs_ufs <- ora("fs_ufs", "fisktegundir")
# Two halves: landings rows keyed by orri's code (fteg), logbook rows by ufs's (fisktegund). Four codes are in both,
# alike in every value read here.
landing_species <- ora("fs_ufs", "landing_species") |>
  mutate(sid = coalesce(fteg, fisktegund), target_assemblage = trimws(target_assemblage)) |>
  distinct(sid, name, eng_name, sci_name, worms_id, target_assemblage)

# Several FAO codes folded into one of orri's codes (20 'Ósundurliðað', 55 'Annað', 305) are not that code's FAO code.
vorpun <- ora("orri", "fao_fisktegund_vorpun") |> filter(n() == 1, .by = fisktegund)

# adb's id is its own, and several ids map to one code (950 Rauðmagi and 951 Grásleppa to 48): a code's name in adb is
# the id that is the code, else the code's only id.
adb <- ora("adb", "species") |>
  filter(!is.na(species_no)) |>
  filter(if (any(id == species_no)) id == species_no else n() == 1, .by = species_no)

blank <- function(x) if_else(trimws(x) == "", NA_character_, trimws(x))
rec <- function(sid, record, id_name, id_sci = NA_character_, ...)
  tibble(sid = as.integer(sid), record = record, id_name = blank(id_name), id_sci = blank(id_sci), ...)

records <- bind_rows(
  rec(ufs$fisktegund, "ufs", ufs$heiti, ufs$latneskt_heiti,
      name = ufs$heiti, name_en = ufs$enskt_heiti, name_sci = ufs$latneskt_heiti, fao_3a = ufs$fao_kodi),
  rec(orri$tegund, "orri", orri$heiti, orri$visindaheiti,
      name = orri$heiti, name_en = orri$enskt_heiti, name_sci = orri$visindaheiti,
      fao_3a = vorpun$fao_species_code[match(orri$tegund, vorpun$fisktegund)]),
  rec(taxon$species_no, "taxon", taxon$name, taxon$sci_name,
      name = taxon$name, name_en = taxon$eng_name, name_sci = taxon$sci_name, taxon_rank = taxon$taxon_rank,
      fao_3a = asfis$code_3a[match(taxon$taxocode, asfis$taxocode)],
      worms_id = if_else(taxon$taxon_source == "WORMS", taxon$taxon_source_id, NA)),
  rec(lods$fisktegund, "lods", lods$heiti, name = lods$heiti),
  rec(afli$f_numer, "afli", afli$f_nafn, name = afli$f_nafn),
  rec(adb$species_no, "adb", adb$name, name = adb$name),
  # The landings code's taxon side: its taxon name, not the copies of ufs's and orri's names beside it.
  rec(landing_species$sid, "landing_species", landing_species$name, landing_species$sci_name,
      name_en = landing_species$eng_name, name_sci = landing_species$sci_name, worms_id = landing_species$worms_id,
      target_assemblage = landing_species$target_assemblage),
  rec(fs_ufs$fisktegund, "fs_ufs", fs_ufs$heiti, fs_ufs$latneskt_heiti,
      name = fs_ufs$heiti, name_en = fs_ufs$enskt_heiti, name_sci = fs_ufs$latneskt_heiti, fao_3a = fs_ufs$fao_kodi)) |>
  mutate(across(c(name, name_en, name_sci, fao_3a, taxon_rank, target_assemblage), blank),
         worms_id = as.integer(worms_id))
stopifnot(!anyNA(records$sid), !anyDuplicated(records[c("sid", "record")]))

# Which table gave each field of each record, and how
source_of <- tribble(
  ~record,           ~field,              ~layer,                         ~basis,
  "ufs",             "name",              "ufs.fisktegundir",             "recorded",
  "ufs",             "name_en",           "ufs.fisktegundir",             "recorded",
  "ufs",             "name_sci",          "ufs.fisktegundir",             "recorded",
  "ufs",             "fao_3a",            "ufs.fisktegundir",             "recorded",
  "orri",            "name",              "orri.fisktegundir",            "recorded",
  "orri",            "name_en",           "orri.fisktegundir",            "recorded",
  "orri",            "name_sci",          "orri.fisktegundir",            "recorded",
  "orri",            "fao_3a",            "orri.fao_fisktegund_vorpun",   "recorded",
  "taxon",           "name",              "taxon.species",                "recorded",
  "taxon",           "name_en",           "taxon.species",                "recorded",
  "taxon",           "name_sci",          "taxon.species",                "recorded",
  "taxon",           "taxon_rank",        "taxon.species",                "recorded",
  "taxon",           "fao_3a",            "asfis.asfis",                  "derived",   # by the record's taxocode
  "taxon",           "worms_id",          "taxon.taxon",                  "derived",   # by the record's taxon unit
  "lods",            "name",              "kvoti.lods_fteg",              "recorded",
  "afli",            "name",              "afli.fiskar",                  "recorded",
  "adb",             "name",              "adb.species",                  "recorded",
  "landing_species", "name_en",           "fs_ufs.landing_species",       "recorded",
  "landing_species", "name_sci",          "fs_ufs.landing_species",       "recorded",
  "landing_species", "worms_id",          "fs_ufs.landing_species",       "recorded",
  "landing_species", "target_assemblage", "fs_ufs.landing_species",       "recorded",
  "fs_ufs",          "name",              "fs_ufs.fisktegundir",          "recorded",
  "fs_ufs",          "name_en",           "fs_ufs.fisktegundir",          "recorded",
  "fs_ufs",          "name_sci",          "fs_ufs.fisktegundir",          "recorded",
  "fs_ufs",          "fao_3a",            "fs_ufs.fisktegundir",          "recorded")
stopifnot(setequal(paste(source_of$field, source_of$layer), paste(layer_order$field, layer_order$layer)))

# When two values agree ------------------------------------------------------------------------------------------------
# Names as a person reads them: case, quotes, accents and rank words (ætt, ættkvísl, ógreindur) ignored, "A / B" and
# "A, B" agreeing with A and with B, an abbreviation (lods' "Annar flatf.") with what it shortens, and two spellings
# two letters apart the same name (Kambhrislingur, Kambhríslungur).
plain <- function(x)
  chartr("áéíóúý", "aeiouy", gsub("þ", "th", gsub("æ", "ae", gsub("ð", "d", gsub("ö", "o", tolower(x))))))
rank_words <- c("aett", "aettkvisl", "aettkvislir", "aettbalkur", "tegund", "tegundir", "genus", "species", "family",
                "order", "nei", "sp", "spp")
name_parts <- function(x)
  lapply(strsplit(plain(x), "[/,]"), function(p) {
    p <- c(p, gsub("\\([^)]*\\)", "", p))                      # "(Nef)broddabakur" is also Broddabakur
    p <- gsub("\\b(ogr[.]?|ogreind[a-z]*|ogreint|oskilgreind[a-z]*)( |$)", " ", p)
    p <- gsub("[^a-z0-9]", "", sub("aett *$", "", p))
    unique(p[!is.na(p) & nchar(p) >= 3 & !p %in% rank_words])
  })
parts_agree <- function(x, y, prefix = TRUE) {
  if (!length(x) || !length(y)) return(FALSE)
  pre <- prefix & outer(x, y, function(a, b) startsWith(a, b) | startsWith(b, a))
  any(adist(x, y) == 0 | ((adist(x, y) <= 2 | pre) & outer(nchar(x), nchar(y), pmin) >= 5))
}
names_agree <- function(a, b, prefix = TRUE) unname(mapply(parts_agree, name_parts(a), name_parts(b), prefix))
# A scientific name as genus and epithet: no author, no subgenus in brackets, no "sp."
sci_key <- function(x)
  vapply(strsplit(gsub("\\([^)]*\\)", " ", replace_na(x, "")), "[[:space:],]+"), function(w) {
    w <- w[nzchar(w)]
    if (!length(w)) return(NA_character_)
    ep <- if (length(w) > 1 && grepl("^[a-z]+$", w[2]) && !w[2] %in% c("sp", "spp", "unid")) w[2]
    tolower(paste(c(w[1], ep), collapse = " "))
  }, "")
# Two lists mean one taxon when they share an Icelandic name, or a scientific name at the same rank (taxon's Gullkarfi,
# Sebastes norvegicus, is not orri's 'Karfi ógreindur', Sebastes sp.), or one's name is the other's scientific name.
same_taxon <- function(name1, sci1, name2, sci2)
  names_agree(name1, name2) | names_agree(sci_key(sci1), sci_key(sci2), prefix = FALSE) |
  names_agree(name1, sci_key(sci2), prefix = FALSE) | names_agree(name2, sci_key(sci1), prefix = FALSE)
agree <- function(field, a, b)
  switch(field, name = , name_en = names_agree(a, b), name_sci = coalesce(sci_key(a) == sci_key(b), FALSE), a == b)

# The anchor, and which lists mean its taxon --------------------------------------------------------------------------
# The lists that agree with the anchor, then those that agree with any of them, until none is added: taxon's
# "Kambhríslungur" (Chirolophis ascanii) reaches ufs's Kambhrislingur through orri's scientific name. A list that
# names no taxon (landing_species without a taxon number) contradicts none.
same_as <- function(name, sci, anchor) {
  set <- anchor
  repeat {
    add <- !set & vapply(seq_along(name), function(i) any(same_taxon(name[i], sci[i], name[set], sci[set])), NA)
    if (!any(add)) return(set)
    set <- set | add
  }
}
anchor_rank <- layer_order |> filter(field == "name") |>
  inner_join(source_of |> filter(field == "name") |> select(record, layer), by = "layer") |> select(record, rank)
records <- records |>
  left_join(anchor_rank, by = "record") |>
  mutate(anchor = coalesce(rank == min(rank[!is.na(id_name)], Inf, na.rm = TRUE) & !is.na(id_name), FALSE),
         anchor = if (any(anchor)) anchor else row_number() == 1,
         same = same_as(id_name, id_sci, anchor) | (is.na(id_name) & is.na(id_sci)), .by = sid) |>
  select(-rank)

# One value per field: the first list in the field's order that means the anchor's taxon, with a valid value ---------
long <- records |>
  pivot_longer(c(name, name_en, name_sci, fao_3a, worms_id, taxon_rank, target_assemblage),
               names_to = "field", values_to = "value", values_transform = as.character, values_drop_na = TRUE) |>
  inner_join(source_of, by = c("record", "field")) |>
  inner_join(layer_order, by = c("field", "layer")) |>
  mutate(valid = field != "fao_3a" | value %in% asfis$code_3a)

chosen <- long |>
  filter(same, valid) |>
  slice_min(rank, n = 1, by = c(sid, field)) |>
  select(sid, field, value, layer, basis)

# Every other value that differs from the chosen one, with its table: what the lists disagree on, kept
other <- long |>
  left_join(chosen |> select(sid, field, chosen = value, chosen_layer = layer), by = c("sid", "field")) |>
  filter(layer != coalesce(chosen_layer, "")) |>
  mutate(differs = is.na(chosen) | !mapply(agree, field, value, chosen)) |>
  filter(differs) |>
  arrange(sid, field, rank) |>
  summarise(other = paste0(layer, ": ", value, if_else(valid, "", " (not in ASFIS)"), collapse = "; "),
            .by = c(sid, field))

wide <- function(f)
  tibble(sid = sort(unique(c(records$sid, declared$sid)))) |>
  left_join(chosen |> filter(field == f) |> select(sid, value, layer, basis), by = "sid") |>
  left_join(other |> filter(field == f) |> select(sid, other), by = "sid") |>
  transmute(sid, value, layer, basis = coalesce(basis, "none"), other, differs = !is.na(other)) |>
  rename_with(~ if_else(.x == "value", f, paste(f, .x, sep = "_")), -sid)

species <- reduce(lapply(c("name", "name_en", "name_sci", "fao_3a", "worms_id"), wide), left_join, by = "sid") |>
  mutate(worms_id = as.integer(worms_id)) |>
  left_join(chosen |> filter(field == "taxon_rank") |> select(sid, taxon_rank = value), by = "sid") |>
  left_join(chosen |> filter(field == "target_assemblage") |> select(sid, target_assemblage = value), by = "sid") |>
  left_join(records |>
              summarise(lists = paste(record, collapse = " "),
                        lists_unmatched = if (all(same)) NA_character_ else paste(record[!same], collapse = " "),
                        .by = sid),
            by = "sid") |>
  left_join(declared, by = "sid") |>
  arrange(sid)
stopifnot(!anyDuplicated(species$sid))

# Check: every species code of the curated catch tables resolves - a name, or a note saying why not --------------------
# Read for the check only, not inputs: a reference is not rebuilt when the catch tables are.
catch <- c(logbook = fd_curated("logbook", "catch.parquet"), landing = fd_curated("landing", "catch.parquet"))
catch <- catch[file.exists(catch)]
codes <- bind_rows(lapply(catch, function(f)
  duckdbfs::open_dataset(f) |> count(schema, sid) |> collect()), .id = "table")
unresolved <- codes |> anti_join(species |> filter(!is.na(name) | !is.na(note)), by = "sid")
message(sprintf("species: %d codes; the catch tables' %d (table, schema, code) all resolve but %d",
                nrow(species), nrow(codes), nrow(unresolved)))
if (nrow(unresolved)) {
  print(unresolved)
  stop("species codes in the catch tables that neither a list nor `declared` names", call. = FALSE)
}

species |>
  write_curated(fd_curated("reference", "species.parquet"),
                inputs = c(fd_raw("oracle", "ufs", "fisktegundir.parquet"),
                           fd_raw("oracle", "orri", "fisktegundir.parquet"),
                           fd_raw("oracle", "orri", "fao_fisktegund_vorpun.parquet"),
                           fd_raw("oracle", "taxon", "species.parquet"),
                           fd_raw("oracle", "taxon", "taxon.parquet"),
                           fd_raw("oracle", "kvoti", "lods_fteg.parquet"),
                           fd_raw("oracle", "afli", "fiskar.parquet"),
                           fd_raw("oracle", "adb", "species.parquet"),
                           fd_raw("oracle", "fs_ufs", "landing_species.parquet"),
                           fd_raw("oracle", "fs_ufs", "fisktegundir.parquet"),
                           fd_raw("oracle", "asfis", "asfis.parquet")))
