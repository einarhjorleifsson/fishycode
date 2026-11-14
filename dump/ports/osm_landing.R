# OpenStreetMap's small landings: anything that may serve a small-scale fishing vessel as a landing place (plan 075 §2.1,
# step 5; the maintainer, 2026-11-14: "include record from osm on anything that may look like a potential landing site").
# Output: raw/ports/landings_osm/<cell>__<group>__<YYYYMMDD>.osm.gz   each Overpass answer as delivered (XML, gzipped),
#                                                                      never overwritten
#         raw/ports/landings_osm/_manifest.csv                        one row per answer: what was asked, where, when
# Read by read_landings_osm() (R/osm_fetch.R): the newest answer of every cell and group, one row per OSM object.
#
# A store that grows (the maintainer, 2026-11-14: "such that it can easily be restarted to pick up more data at a later
# stage"). A cell is a 5-degree grid cell, named by its south-west corner; a group is one Overpass filter of
# osm_landing_groups(). A run fetches what the store lacks:
#   - more places: add a box to REGION (or name boxes in LANDING_REGIONS); only the new cells are fetched;
#   - more tags: add a group to osm_landing_groups(); only that group is fetched, in every cell;
#   - newer data: LANDING_REFRESH_BEFORE=YYYYMMDD fetches again every answer older than that day; the old ones stay, the
#     newest is read;
#   - a smaller step: LANDING_MAX_FETCHES=n stops after n answers (the maintainer: "take your time rather than mining too
#     big stuff at any one time"); a rerun goes on where it stopped.
# One query at a time, with retries, a whole answer only, and a random pause between queries (median 15 s, never under
# 10 s). Data © OpenStreetMap contributors, ODbL.
#
# The groups: slipways (leisure=slipway, the boat-ramp symbol); piers, quays, breakwaters and groynes (man_made, the last
# two as context); seamark small-craft facilities and moorings. Measured on a pilot (study archive/2026-11-14-port-layer,
# plan 075 §4.2): 4,805 features over Portugal, the Azores and Madeira, 28,204 over Denmark. The first places: those of the
# EM4SSF hackathon's case studies and partners (Italy, CS1 and the host; Greece; Spain; Portugal with the Azores and Madeira;
# Denmark), France, which the project's text names, and Iceland (the maintainer, 2026-11-14; Italy added on a check of the
# case studies).

source("R/osm_fetch.R")   # run from the repository's root; targets would source R/ itself

# xmin, ymin, xmax, ymax
REGION <- list(denmark = c(7.9, 54.5, 15.3, 57.8), france = c(-5.3, 41.3, 9.6, 51.2), portugal = c(-9.6, 36.9, -6.1, 42.2),
               azores = c(-31.5, 36.8, -24.8, 39.8), madeira = c(-17.4, 32.3, -16.2, 33.2), spain = c(-9.4, 35.9, 4.4, 43.8),
               canaries = c(-18.2, 27.6, -13.4, 29.5), greece = c(19.3, 34.7, 29.7, 41.8), italy = c(6.6, 35.4, 18.6, 47.1),
               iceland = c(-24.6, 63.2, -13.4, 66.6))
GROUPS <- osm_landing_groups()

pick <- strsplit(Sys.getenv("LANDING_REGIONS", ""), ",")[[1]]
if (length(pick)) { stopifnot("LANDING_REGIONS names boxes of REGION" = all(pick %in% names(REGION))); REGION <- REGION[pick] }
refresh <- Sys.getenv("LANDING_REFRESH_BEFORE", "")
max_fetch <- as.numeric(Sys.getenv("LANDING_MAX_FETCHES", "Inf"))
today <- format(Sys.time(), "%Y%m%d", tz = "UTC")

dir <- fd_raw("ports", "landings_osm")
dir.create(dir, showWarnings = FALSE, recursive = TRUE)
manifest <- file.path(dir, "_manifest.csv")

cells <- osm_cells(REGION)
want <- expand.grid(cell = names(cells), group = names(GROUPS), stringsAsFactors = FALSE)
h <- osm_store_held(dir)
want$have <- h$date[match(paste(want$cell, want$group), paste(h$cell, h$group))]
todo <- want[is.na(want$have) | (nzchar(refresh) & !is.na(want$have) & want$have < refresh), ]
message(sprintf("%d cells x %d groups; %d answers held, %d to fetch%s", length(cells), length(GROUPS), sum(!is.na(want$have)),
                nrow(todo), if (is.finite(max_fetch)) sprintf(" (at most %d this run)", max_fetch) else ""))
n <- 0
for (k in seq_len(nrow(todo))) {
  if (n >= max_fetch) break
  t <- todo$cell[k]; g <- todo$group[k]; b <- cells[[t]]
  q <- paste0("[out:xml][timeout:600];(nwr", GROUPS[[g]]$filter, "(", b[2], ",", b[1], ",", b[4], ",", b[3], "););(._;>;);out body;")
  base <- paste0(t, "__", g, "__", today)
  message(sprintf("fetching %s %s (%d of %d)", t, g, k, nrow(todo)))
  xml <- file.path(dir, paste0(base, ".osm"))
  osm_fetch(q, xml)
  osm_base <- sub('.*osm_base="([^"]*)".*', "\\1", grep("osm_base=", readLines(xml, n = 10, warn = FALSE), value = TRUE)[1])
  gz <- file.path(dir, paste0(base, ".osm.gz"))
  R.utils::gzip(xml, destname = gz)
  row <- data.frame(file = basename(gz), cell = t, group = g, xmin = b[1], ymin = b[2], xmax = b[3], ymax = b[4],
                    fetched_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"), osm_base = osm_base,
                    bytes = file.size(gz), md5 = unname(tools::md5sum(gz)), query = q)
  utils::write.table(row, manifest, sep = ",", row.names = FALSE, col.names = !file.exists(manifest),
                     append = file.exists(manifest), qmethod = "double")
  n <- n + 1
  osm_pause()
}
message(sprintf("fetched %d answers this run; the store holds %d", n, nrow(osm_store_held(dir))))
