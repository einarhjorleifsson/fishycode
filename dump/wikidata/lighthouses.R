# Wikidata's lighthouses round Iceland (32 W to 6 W, 59 N to 70 N): every item that is a lighthouse (P31/P279* Q39715) of
# Iceland, the Faroes, Denmark, Norway or the United Kingdom with a coordinate in the box, with its labels and descriptions
# (Icelandic, English), its Admiralty (P3562), NGA (P3563) and ARLHS (P2980) numbers, focal height (P2923), light
# characteristic (P1030), range (P2929) and inception (P571). One SPARQL query, as delivered: one row per combination of
# values (an item with two characteristics is two rows); the staging folds them. A witness for plan 074 step 9's curated list
# of aids to navigation, and the only open list met that carries the Admiralty and NGA numbers beside a position (NGA's own
# list, Pub. 115, was under maintenance on 2026-11-16). Wikidata gathers from other lists, so it is a weak witness of position.
# Output: $FISHYDATA/raw/external/wikidata_lighthouses/lighthouses_<YYYYMMDD>.csv and README-provenance.txt.
# Run once, from the repo root: Rscript dump/wikidata/lighthouses.R
# Wikidata's data are CC0. Written by Claude (AI).
source("R/paths.R")
DATE <- format(Sys.time(), "%Y%m%d", tz = "UTC")
q <- 'SELECT DISTINCT ?item ?coord ?cls ?label_is ?label_en ?description_en ?description_is ?admiralty ?nga ?arlhs ?focal_height ?characteristic ?range ?inception ?country WHERE {
  ?item wdt:P31/wdt:P279* wd:Q39715 .
  ?item wdt:P625 ?coord .
  ?item wdt:P17 ?country . VALUES ?country { wd:Q189 wd:Q4628 wd:Q35 wd:Q223 wd:Q145 }
  FILTER(geof:longitude(?coord) >= -32 && geof:longitude(?coord) <= -6 && geof:latitude(?coord) >= 59 && geof:latitude(?coord) <= 70)
  OPTIONAL { ?item wdt:P31 ?cls }
  OPTIONAL { ?item rdfs:label ?label_is FILTER(lang(?label_is) = "is") } OPTIONAL { ?item rdfs:label ?label_en FILTER(lang(?label_en) = "en") }
  OPTIONAL { ?item schema:description ?description_en FILTER(lang(?description_en) = "en") }
  OPTIONAL { ?item schema:description ?description_is FILTER(lang(?description_is) = "is") }
  OPTIONAL { ?item wdt:P3562 ?admiralty } OPTIONAL { ?item wdt:P3563 ?nga } OPTIONAL { ?item wdt:P2980 ?arlhs }
  OPTIONAL { ?item wdt:P2923 ?focal_height } OPTIONAL { ?item wdt:P1030 ?characteristic } OPTIONAL { ?item wdt:P2929 ?range }
  OPTIONAL { ?item wdt:P571 ?inception }
}'
dir <- fd_raw("external", "wikidata_lighthouses"); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
f <- file.path(dir, paste0("lighthouses_", DATE, ".csv"))
httr2::request("https://query.wikidata.org/sparql") |> httr2::req_url_query(query = q) |>
  httr2::req_headers(Accept = "text/csv") |> httr2::req_user_agent("fishycode data fetch (R httr2)") |>
  httr2::req_timeout(300) |> httr2::req_perform(path = f)
x <- utils::read.csv(f, encoding = "UTF-8", check.names = FALSE)
stopifnot(identical(names(x)[1:2], c("item", "coord")))            # an answer, not the endpoint's error text
note <- c("# Wikidata's lighthouses round Iceland, fetched by dump/wikidata/lighthouses.R (plan 074 step 9, the aids).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Box: 32 W to 6 W, 59 N to 70 N. Wikidata, CC0."),
          "", paste0("## ", basename(f)), "server: https://query.wikidata.org/sparql (Accept: text/csv)", "query:", q,
          paste0("rows: ", nrow(x), "; items: ", length(unique(x$item))), paste0("bytes: ", file.size(f)),
          paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
          paste0("items by country: ", paste(names(table(unique(x[, c("item", "country")])$country)),
                                              table(unique(x[, c("item", "country")])$country), collapse = ", ")))
writeLines(note, file.path(dir, "README-provenance.txt")); cat(note, sep = "\n")
