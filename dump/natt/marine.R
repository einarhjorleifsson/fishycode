# The layers at sea and on the coast on Náttúrufræðistofnun's GeoServer (gis.natt.is, the national map service), from their
# owners: Landhelgisgæslan (the baseline and its points, the territorial sea, the contiguous zone, the exclusive economic zone,
# the depth polygons of LMÍ's base map), Fiskistofa (the active closures and fishing areas: spawning, lumpfish, Danish seine,
# Nephrops, quick closures, regulations), Hagstofan (the areas closed to bottom trawling and by regulation), Óbyggðanefnd (the
# belt 2 km from the mainland and inhabited islands, the spring low-water line, Breiðafjörður's protection), the shore's
# boundaries (fjörumörk), LMÍ's spring low-water trial areas, EuroRegionalMap's coast and sea, Náttúrufræðistofnun's seal
# haul-outs, important bird areas, salt marshes and coastal winter bird counts, and Fjarskiptastofa's sea areas (50 miles, A1).
# The maintainer, 2026-11-16: "anything that has coordinates out at sea or in coastal areas if of interest here"; "no
# permission needed for downloading and mining". Left out: LHG:dypislinur (already in raw/external/lhg, dump/lhg/), and
# Fiskistofa's development and extraction permits (works by rivers and lakes).
# Input: https://gis.natt.is/geoserver/ows (WFS 2.0.0 GetFeature, GeoJSON, each layer's own coordinate system).
# Output: $FISHYDATA/raw/external/natt_marine/<workspace>__<layer>.geojson (.csv where the server fails GeoJSON), as delivered, and README-provenance.txt beside
# them (each request, the date, bytes, sha256, the features against the server's own count, the coordinate system, the
# attributes). Run once, from the repo root: Rscript dump/natt/marine.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "natt_marine"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
UA <- "fishycode data fetch"; OWS <- "https://gis.natt.is/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames="
LAYERS <- c("LHG:grunnlina", "LHG:grunnlina_punktar", "LHG:landhelgi_12_milur_lina", "LHG:adlaekt_belti_24_milur_lina", "LHG:efnahagslogsaga_lina",
            "LHG:dyptarflakar",
            "fiskistofa:virk_hrygningarsvaedi", "fiskistofa:virk_grasleppulokanir", "fiskistofa:virk_dragnotaveidisvaedi", "fiskistofa:virk_humarveidisvaedi",
            "fiskistofa:virkar_skyndilokanir", "fiskistofa:virkar_reglugerdir", "fiskistofa:adrar_reglugerdir",
            "Hagstofan:verndud_hafsvaedi", "Hagstofan:onnur_verndud_hafsvaedi",
            "obyggdanefnd:A018", "obyggdanefnd:A019", "obyggdanefnd:A100_storstraumsfjara", "obyggdanefnd:vernd_Breiðafjarðar",
            "jardfraedi:fjorumork_fjorumork", "jardfraedi:fjorumork_landform_rask", "jardfraedi:fjorumork_maeld_haed", "jardfraedi:fjorumork_svaedi_nedansjavar",
            "LMI_vektor:storstraumsfjara",
            "ERM:CoastArea", "ERM:CoastalLine", "ERM:SeaArea", "ERM:ShorelineConstruction",
            "ni:ni_d25v_selalatur_2_landselir_1980_2018_selalatur_fl", "ni:ni_d25v_selalatur_2_landselir_1980_2018_talningarsvaedi_fl",
            "ni:ni_d25v_selalatur_2_utselir_1982_2017_selalatur_fl", "ni:ni_d25v_selalatur_2_utselir_1982_2017_talningarsvaedi_fl",
            "ni:ni_f25v_mikilvaeg_fuglasvaedi_fl", "ni:ni_n50v_serstok_vernd_1_n25v_sjavarfitjar_fl",
            "ni:vetrarfuglatalning_svaedi_linur", "ni:vetrarfuglatalning_upphafs_endapunktar", "ni:vetrartalningar_aedarfugl",
            "fjarskiptastofa:milur_50", "fjarskiptastofa:a1")
note <- c("# The layers at sea and on the coast on gis.natt.is, fetched by dump/natt/marine.R (plan 074).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Each layer's terms are its owner's (natt.is's catalogue,",
                 " gatt.natt.is); not for navigation."), "")
for (layer in LAYERS) {
  q <- utils::URLencode(layer, reserved = TRUE)
  hits <- httr2::request(paste0(OWS, q, "&resultType=hits")) |> httr2::req_user_agent(UA) |> httr2::req_perform() |> httr2::resp_body_string()
  matched <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", hits))
  url <- paste0(OWS, q, "&outputFormat=application/json"); f <- file.path(out_dir, paste0(sub(":", "__", layer), ".geojson"))
  ok <- tryCatch({ httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |> httr2::req_perform(path = f); TRUE },
                 error = function(e) FALSE)
  if (ok) x <- sf::read_sf(f) else {
    # the server fails some layers as GeoJSON (ni:vetrartalningar_aedarfugl: an ArrayIndexOutOfBoundsException in any
    # version), and answers them as CSV (WFS 1.0.0), the geometry as WKT
    unlink(f); url <- paste0(sub("version=2.0.0", "version=1.0.0", sub("typeNames=", "typeName=", OWS)), q, "&outputFormat=csv")
    f <- sub("\\.geojson$", ".csv", f)
    httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |> httr2::req_perform(path = f)
    x <- utils::read.csv(f, encoding = "UTF-8", check.names = FALSE) }
  stopifnot(nrow(x) == matched)                                   # the answer whole, not capped by the server
  note <- c(note, paste0("## ", basename(f)), paste0("request: ", url), paste0("bytes: ", file.size(f)),
            paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
            paste0("features: ", nrow(x), " (the server's own count ", matched, ")"),
            paste0("coordinate system: ", if (inherits(x, "sf")) sf::st_crs(x)$input else "as the CSV's geometry (WKT) gives it"),
            paste0("attributes: ", paste(names(if (inherits(x, "sf")) sf::st_drop_geometry(x) else x), collapse = ", ")),
            if (grepl("aedarfugl", layer)) "persons: the counts name their counters; read by counts and columns only" else NULL, "")
  message(layer, ": ", nrow(x))
}
writeLines(note, file.path(out_dir, "README-provenance.txt"))
