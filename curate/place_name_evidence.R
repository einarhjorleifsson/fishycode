# place_name_evidence.R — every occurrence of a place name in the ornefni sources, and every spelling, under one key.
# Side: preprocessing (place names). See plan 044; plan 043; decision 222.
#
# Input:  staging/ornefni/{trackwell_haul, trackwell_area, plotter_mark, plotter_track, chart_name, lmi_name,
#         recapture_place, recapture_reading, name_dictionary, drawn_area, fiskislod, article_record,
#         document_name}.parquet; curated/logbook/{station_window, gear}.parquet (the gear of Trackwell's hauls)
# Output: curated/place_name/evidence.parquet - one row per occurrence, keyed on (`source_table`, `source_key`)
#         curated/place_name/variant.parquet  - one row per spelling (`name`), with its key
#         curated/place_name/outcome.parquet  - every staged row in one outcome: an occurrence, or not and why
#
# An occurrence is a name in a staged row, with the row's position where it has one: a tow's midpoint, a line's middle,
# a polygon's point on surface (`lon`, `lat`, as the row's basis), its time and vessel. `position_flag` marks a
# position kept as given but used for nothing: `impossible` (latitude over 90 or longitude over 180: 22 of Trackwell's
# hauls) or `at zero` (both within a degree of 0). Not occurrences, each counted:
# the plotter's numbers, symbols ("!!") and unnamed marks, placeholders ("FROM SHIP", "Ekkert valið"), LMÍ's land and lake names, the
# recapture texts (descriptions: their hand readings are the occurrences), the fiskislóð hulls (derived from those
# readings) and the plotter's tracks (no names). Trackwell's picklist summary (trackwell_area) is an occurrence per name
# with `summary` TRUE: it repeats the hauls, so no count or position statistic reads it.
#
# The key groups spellings of one place: lower case, accents and Icelandic letters folded (ð d, þ th, æ ae), everything
# but letters and digits dropped, a doubled letter made single: "Litli-Banki", "Littli banki" and "Litlibanki" share
# "litlibanki". A "?" in a plotter name stands for a lost Icelandic letter (plan 043 §3.2): where exactly one name that
# keeps its letters fits it, that name replaces it (`name_repaired`, rule `repaired`). The hand readings (the
# dictionary's `reading`, an article's synonyms) are kept beside a spelling in variant.parquet as relations, never
# merged into its key: a reading often names the broader place (plan 043 §3.4).
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
account("trackwell_haul", "occurrence", nrow(ev_th))
account("trackwell_haul", "placeholder (FROM SHIP)", sum(th$name_placeholder))

ta <- st("trackwell_area")
ev_ta <- ta |> filter(!name_placeholder) |>
  transmute(source = "trackwell", source_table = "trackwell_area", source_key = as.character(row), name, lon, lat,
            position_basis, position_kind, weight = n_haul, summary = TRUE)
account("trackwell_area", "occurrence (summary)", nrow(ev_ta))
account("trackwell_area", "placeholder (Ekkert valið)", sum(ta$name_placeholder))

# The plotter ---------------------------------------------------------------------------------------------------------
pm <- st("plotter_mark")
no_letter <- !is.na(pm$name) & !pm$name_is_number & !grepl("[[:alpha:]]", pm$name)       # "!!", ",", "..."
ev_pm <- pm[!is.na(pm$name) & !pm$name_is_number & !no_letter, ] |>
  transmute(source = "plotter", source_table = "plotter_mark", source_key = paste(file, mark, sep = ":"), name, lon, lat,
            position_basis, position_kind, time = if_else(time_placeholder | time_suspect, as.POSIXct(NA), time),
            weight = 1L, text_lost)
account("plotter_mark", "occurrence", nrow(ev_pm))
account("plotter_mark", "no name", sum(is.na(pm$name)))
account("plotter_mark", "a number, not a name", sum(!is.na(pm$name) & pm$name_is_number))
account("plotter_mark", "a symbol, not a name", sum(no_letter))
account("plotter_track", "a track point, no name", nrow(st("plotter_track")))

# Lines and polygons ------------------------------------------------------------------------------------------------
ch <- st_sf("chart_name"); xy <- point_of(sf::st_geometry(ch))
ev_ch <- tibble(source = "sjokort", source_table = "chart_name", source_key = as.character(ch$row), name = ch$name,
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "line", weight = 1L)
account("chart_name", "occurrence", nrow(ev_ch))

lm <- st_sf("lmi_name"); sea <- grepl("^Sjávar", lm$class)
xy <- point_of(sf::st_geometry(lm)[sea])
ev_lm <- tibble(source = "lmi", source_table = "lmi_name", source_key = as.character(lm$row[sea]), name = lm$name[sea],
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "polygon", weight = 1L,
                lmi_class = lm$class[sea], lmi_feature = lm$feature[sea])
account("lmi_name", "occurrence (a sea name)", sum(sea))
account("lmi_name", "a land or lake name", sum(!sea))

dr <- st_sf("drawn_area"); xy <- point_of(sf::st_geometry(dr))
ev_dr <- tibble(source = "qgis", source_table = "drawn_area", source_key = as.character(dr$row), name = dr$name,
                lon = xy[, 1], lat = xy[, 2], position_basis = "recorded", position_kind = "drawn", weight = 1L)
account("drawn_area", "occurrence", nrow(ev_dr))
account("fiskislod", "derived from the recapture readings", nrow(st_sf("fiskislod")))

# Recaptures: the hand readings are the names, the recapture gives the position ---------------------------------------
rp <- st("recapture_place"); rr <- st("recapture_reading")
read_name <- rr |> mutate(name = coalesce(reading, fiskislod)) |>
  left_join(rp |> select(recapture_id, lon, lat, position_basis), by = "recapture_id")
ev_rr <- read_name |> filter(!is.na(name)) |>
  transmute(source = "fiskmerki", source_table = "recapture_reading", source_key = paste(file, recapture_id, sep = ":"),
            name, lon, lat, position_basis, position_kind = "point", weight = 1L)
account("recapture_place", "a description, read in recapture_reading", nrow(rp))
account("recapture_reading", "occurrence (a reading)", nrow(ev_rr))
account("recapture_reading", "not read", sum(is.na(read_name$name)))

# Text: articles and documents ----------------------------------------------------------------------------------------
ar <- st("article_record")
ev_ar <- ar |> filter(!is.na(name)) |>
  transmute(source = "article", source_table = "article_record", source_key = file, name, position_basis = "none",
            position_kind = "text", weight = 1L)
account("article_record", "occurrence", nrow(ev_ar))
account("article_record", "no name", sum(is.na(ar$name)))

dn <- st("document_name")
ev_dn <- dn |>
  transmute(source, source_table = "document_name", source_key = paste(document, entry, sep = ":"), name, lon, lat,
            position_basis, position_kind, weight = 1L, isor_group = group, region = class_filled)
account("document_name", "occurrence", nrow(ev_dn))
account("name_dictionary", "a hand reading, a relation in variant.parquet", nrow(st("name_dictionary")))

# Together, the repair and the key ----------------------------------------------------------------------------------
ev <- bind_rows(ev_th, ev_ta, ev_pm, ev_ch, ev_lm, ev_dr, ev_rr, ev_ar, ev_dn) |>
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

# Spellings, with the hand readings as relations ----------------------------------------------------------------------
dict <- st("name_dictionary") |> filter(!is.na(name), !is.na(reading)) |>
  group_by(name) |> summarise(reading = paste(sort(unique(c(reading, na.omit(reading2)))), collapse = "; "), .groups = "drop")
syn <- ar |> filter(!is.na(name), !is.na(synonyms)) |>
  mutate(synonym = strsplit(synonyms, "\\s*[,;\n]\\s*")) |> tidyr::unnest(synonym) |>
  mutate(synonym = squeeze(synonym)) |> filter(!is.na(synonym)) |>
  group_by(name = synonym) |> summarise(synonym_of = paste(sort(unique(.data$name)), collapse = "; "), .groups = "drop")
variant <- ev |> group_by(name) |>
  summarise(key = first(key), rule = if_else(any(!is.na(name_repaired)), "repaired", "key"),
            repaired_to = first(name_repaired), n = n(), n_positioned = sum(position_basis != "none" & !summary),
            n_vessel = n_distinct(vessel, na.rm = TRUE), sources = paste(sort(unique(source)), collapse = ", "),
            .groups = "drop") |>
  left_join(dict, by = "name") |> left_join(syn, by = "name") |> arrange(key, desc(n))

outcome <- bind_rows(outcomes)

# Check and write -----------------------------------------------------------------------------------------------------
staged <- c(trackwell_haul = nrow(th), trackwell_area = nrow(ta), plotter_mark = nrow(pm), chart_name = nrow(ch),
            lmi_name = nrow(lm), drawn_area = nrow(dr), recapture_reading = nrow(rr), article_record = nrow(ar),
            document_name = nrow(dn))
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
  "recapture_place", "recapture_reading", "name_dictionary", "drawn_area", "article_record", "document_name"), ".parquet")),
  fd_curated("logbook", "station_window.parquet"), fd_curated("logbook", "gear.parquet"))
write_curated(ev, fd_curated("place_name", "evidence.parquet"), inputs = inputs)
write_curated(variant, fd_curated("place_name", "variant.parquet"), inputs = inputs)
write_curated(outcome, fd_curated("place_name", "outcome.parquet"), inputs = inputs)
