# chart_names.R — the names lettered on the Icelandic sea charts, one table: a row a label on a chart (plan 074 step 1b).
# Side: preprocessing (sea-chart names). See plan 074; plan 014.
#
# Input:  $FISHYDATA/archive/2026-11-11-named-features/out/frozen/<series>/labels.gpkg, layer box, for the nine chart
#         series: each chart's lettering read once (the study's scripts 18-39, macOS's own recognizer), reviewed (the
#         maintainer's answers and cards, Claude's look, the witnesses) and frozen (its 28_freeze_scale.R), the labels kept
# Output: curated/reference/chart_names.parquet - one row per label kept on a chart, keyed on (chart, label_id); WKB
#         `geometry`, the label's box (a rectangle round its own letters, along their direction), WGS 84
#
# Each chart's own print is kept: a name lettered on two charts is two rows, each with its chart (the maintainer, 2026-11-13:
# "Keep each chart's own print"). The reading is the study's, frozen as an input the build reads and never makes (the read
# needs a Mac, and its review is the maintainer's: decision 075's way for a one-time fix); a chart frozen again there
# rebuilds this table. `judged_by` says who settled each label: the maintainer (an answer on the maps or a card), Claude's
# look at the chart (from the crops), the witnesses (read alike its name, the same name within 2-3 km in natt.is's names,
# the place-name map or another frozen chart), the checks (confident, not judged), or no one (a land name kept as read,
# not checked: the maintainer, 2026-11-15, "Keep, marked unchecked"). Internal: the charts are Landhelgisgæslan's (©
# Sjómælingar Íslands), not for navigation; the notes name internal witnesses.

library(dplyr)

SERIES <- c(sjokort_2milljon = 2e6, sjokort_1milljon = 1e6, sjokort_300thusund = 3e5, sjokort_K42 = 1.6e5,
            sjokort_100thusund = 1e5, sjokort_K44 = 7e4, sjokort_35_40_50thusund = 4e4, sjokort_15thusund = 1.5e4,
            sjokort_10thusund = 1e4)
FROZEN <- fd_path("archive", "2026-11-11-named-features", "out", "frozen")
files <- file.path(FROZEN, names(SERIES), "labels.gpkg")
outcomes <- file.path(FROZEN, names(SERIES), "outcome.csv")   # every box's outcome (1:1 000 000's labels.gpkg predates its column)
stopifnot(all(file.exists(c(files, outcomes))))

d <- bind_rows(lapply(seq_along(files), function(i) {
  b <- sf::st_read(files[i], "box", quiet = TRUE)
  stopifnot(sf::st_crs(b)$epsg == 3857, !anyDuplicated(b$label_id))
  o <- utils::read.csv(outcomes[i], encoding = "UTF-8", colClasses = "character")
  b$outcome <- o$outcome[match(as.character(b$label_id), o$label_id)]
  b <- sf::st_transform(b, 4326)
  c0 <- suppressWarnings(sf::st_coordinates(sf::st_centroid(sf::st_geometry(b))))
  x <- sf::st_drop_geometry(b)
  g <- function(n, f = as.character) if (n %in% names(x)) f(x[[n]]) else f(rep(NA, nrow(x)))   # a column an older freeze lacks
  tibble(chart = names(SERIES)[i], scale = unname(SERIES[i]), label_id = g("label_id", as.integer), name = g("name"),
         name_read = g("name_read"), kind = g("kind"), class = g("class"), text = g("text"),
         spaced = g("spaced", as.logical), runs_deg = g("runs_deg", as.numeric), long_km = g("long_km", as.numeric),
         lon = c0[, 1], lat = c0[, 2], verdict = g("verdict"), outcome = g("outcome"), corrected_by = g("corrected_by"),
         hand_box = g("hand_box"), note = g("note"), frozen = g("frozen"), round = g("round", as.integer), geometry = sf::st_geometry(b))
}))
# who settled each label, from its frozen outcome
d <- d |> mutate(judged_by = case_when(
  grepl("not checked", outcome) ~ "no one (a land name kept as read)",
  grepl("not judged", outcome) ~ "the checks (confident, not judged)",
  # a chart he reviewed whole on its map (1:2 000 000, 1:1 000 000, 1:300 000): a box he saw and left unmarked is accepted
  grepl("not marked", outcome) ~ "the maintainer (seen, left unmarked)",
  grepl("\\(the witnesses\\)", outcome) ~ "the witnesses",
  grepl("\\(Claude's look\\)", outcome) ~ "Claude's look",
  grepl("^kept: (right|part|lines joined|seen)", outcome) ~ "the maintainer",
  TRUE ~ NA_character_), .after = outcome)
stopifnot(!anyNA(d$judged_by), !anyNA(d$name), nrow(distinct(d, chart, label_id)) == nrow(d), all(startsWith(d$outcome, "kept")))
d <- sf::st_as_sf(d, sf_column_name = "geometry", crs = 4326) |> arrange(chart, label_id)
write_curated(d, fd_curated("reference", "chart_names.parquet"), inputs = c(files, outcomes))
message("chart_names: ", nrow(d), " labels on ", n_distinct(d$chart), " charts, ", n_distinct(d$name), " names; ",
        paste(names(table(d$judged_by)), table(d$judged_by), collapse = "; "))
