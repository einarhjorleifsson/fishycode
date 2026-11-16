# Veðurstofa Íslands' weather stations, every one its open API lists (api.vedur.is/weather/stations: its own, Vegagerðin's,
# Landsvirkjun's and others', in use and closed): name, type, position, elevation, owner, the years it ran. Kept for the
# stations on the coast and on islands, lighthouses' among them (plan 074).
# The maintainer, 2026-11-16: "I am wandering if Veðurstofan has anything mineable when it comes to sea features with
# coordinates"; "no permission needed for downloading and mining". Its API has no sea layer (weather stations and their
# observations only); the sea's from it is the stations by the shore.
# Input: https://api.vedur.is/weather/stations (JSON). Output: $FISHYDATA/raw/external/vedur/stations.json, as delivered, and
# README-provenance.txt beside it. Run once, from the repo root: Rscript dump/vedur/stations.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "vedur"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
url <- "https://api.vedur.is/weather/stations"; f <- file.path(out_dir, "stations.json")
httr2::request(url) |> httr2::req_user_agent("fishycode data fetch") |> httr2::req_headers(Accept = "application/json") |>
  httr2::req_timeout(300) |> httr2::req_perform(path = f)
x <- jsonlite::fromJSON(f)
note <- c("# Veðurstofa Íslands' weather stations from its open API, fetched by dump/vedur/stations.R (plan 074).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "."), "", "## stations.json", paste0("request: ", url),
          paste0("bytes: ", file.size(f)), paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
          paste0("stations: ", nrow(x), " (in use ", sum(is.na(x$ending)), "); by owner: ",
                 paste(names(sort(table(x$owner), decreasing = TRUE)), sort(table(x$owner), decreasing = TRUE), collapse = ", ")),
          paste0("attributes: ", paste(names(x), collapse = ", ")), "positions: WGS 84 degrees (lat, lon)")
writeLines(note, file.path(out_dir, "README-provenance.txt")); cat(note, sep = "\n")
