# landing_site_accounting.R — every list's every feature in one outcome, counted (plan 075 §2.4; port_accounting.R until
# step 6).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/ports/* (each list's raw rows, counted as landing_site_feature.R reads them; OSM's two port fetches as
#         their union),
#         curated/reference/landing_site_feature.parquet and landing_site.parquet (reference/ports/landing_site.R),
#         overrides/port_pid_pinned.csv
# Output: curated/check/landing_site_accounting.parquet - one row per list, outcome and reason group: the features counted, with
#         `verdict` "ok" or what failed
#
# Bookkeeping, not an agreement rate (decision 155): the raw rows of each list are counted from the raw files again, and
# every one must appear once in the outcome table, in exactly one outcome. The script stops, after writing, unless:
#   - each list's raw rows = its rows with an outcome, and no key appears twice;
#   - every site has exactly one chosen feature, and every chosen feature is a site's anchor;
#   - no feature but a chosen one, a witness, a duplicate or a joined one has a site, and every flagged feature has a
#     reason;
#   - each site's basis agrees with its members: a witnessed site has two families of evidence (GFW's label counts for a
#     dock area), a one-list site one, a structure or context site is a small landing, with no witness;
#   - no small landing witnesses: one at a port list's site is `joined`;
#   - no two sites' areas overlap, but small landings' among themselves;
#   - every einar harbour (and its pinned acronym) is a site of its own, and in Iceland and the Faroes no other list
#     anchors one.

library(sf)
library(dplyr)

sf_use_s2(FALSE)
osm_keys <- function(f) { o <- read_sf(f); paste0(as.character(st_geometry_type(o)), "/", o$osm_id) }
raw_n <- c(
  einar    = nrow(read_sf(fd_staging("ports", "ports_iceland_faroe.gpkg"))),
  jeppe    = nrow(read_sf(fd_raw("ports", "havnepolygoner3.gpkg"))),
  maksims  = nrow(read_sf(fd_raw("ports", "maksims", "harbours.shp"))),
  emodnet  = nrow(read_sf(fd_raw("ports", "ports_emodnet.gpkg"))),
  # OSM's two fetches overlap: one row per object, keyed by geometry type and id (port_feature.R)
  osm      = length(union(osm_keys(fd_raw("ports", "ports_osm.gpkg")), osm_keys(fd_raw("ports", "ports_osm_20261114.gpkg")))),
  osm_landing = length(osm_keys(fd_raw("ports", "landings_osm_20261114.gpkg"))),
  vmstools = nrow(read_sf(fd_raw("ports", "ports_vmstools.gpkg"))),
  gfw      = nrow(read_sf(fd_raw("ports", "ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg"))),
  gisco    = nrow(read_sf(fd_raw("ports", "ports_giscoR.gpkg"))),
  marta    = nrow(readxl::read_excel(fd_raw("ports", "marta", "landings_portos_Einer.xlsx"))),
  unlocode = nrow(nanoparquet::read_parquet(fd_raw("ports", "unlocode.parquet"))))

f <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "landing_site_feature.parquet")))
f$geom <- NULL
ly <- read_curated_sf(fd_curated("reference", "landing_site.parquet"))
pins <- read.csv("overrides/port_pid_pinned.csv", colClasses = "character")
raw <- f[!f$derived, ]

fails <- character()
fail <- function(ok, what) if (!isTRUE(ok)) fails <<- c(fails, what)
n_out <- table(factor(raw$source, levels = names(raw_n)))
fail(all(n_out == raw_n), paste("raw rows differ:", paste(names(raw_n)[n_out != raw_n], collapse = ", ")))
fail(!anyDuplicated(paste(f$source, f$feature_key)), "a key twice")
fail(all(f$outcome %in% c("chosen", "witness", "duplicate", "joined", "flagged")), "an unknown outcome")
fail(!anyNA(f$reason), "an outcome without a reason")
mk <- f[f$source != "gfw", ]                       # a GFW anchorage takes its dock area's outcome
ch <- mk[mk$outcome == "chosen", ]
fail(!anyDuplicated(ch$site_key) && setequal(ch$site_key, ly$site_key) &&
       all(paste0(ch$source, ":", ch$feature_key) == ch$site_key), "a site without exactly one chosen feature")
fail(all(is.na(f$site_key[f$outcome == "flagged"])), "a flagged feature with a site")
fail(all(!is.na(f$site_key[f$outcome != "flagged"])), "a chosen, witness, duplicate or joined feature without a site")
fail(all(f$pid[!is.na(f$site_key)] %in% c(ly$pid, NA)), "a feature's pid is not its site's")
# the basis from the members, counted again
ev <- f[!is.na(f$site_key) & f$source != "osm_landing", ]
n_fam <- tapply(ev$family, ev$site_key, \(x) length(unique(x)))
nf <- unname(n_fam[ly$site_key]); nf[is.na(nf)] <- 0L
nf <- nf + (ly$anchor_source == "gfw_dock")
fail(all(ly$basis[ly$anchor_source == "einar"] == "reviewed"), "an einar harbour not reviewed")
fail(all((nf >= 2) == (ly$basis == "witnessed") | ly$basis == "reviewed"), "a site's basis disagrees with its families of evidence")
fail(all((ly$anchor_source == "osm_landing") == (ly$basis %in% c("structure", "context"))), "a structure or context site not a small landing")
st_sites <- ly$site_key[ly$basis %in% c("structure", "context")]
fail(all(f$outcome[f$site_key %in% st_sites] %in% c("chosen", "duplicate")), "a structure or context site with a witness")
fail(all(f$outcome[f$source == "osm_landing" & !is.na(f$site_key)] %in% c("chosen", "joined", "duplicate")), "a small landing as a witness")
ar <- st_transform(ly[ly$geom_type == "area", ], 3035)
ov <- st_overlaps(ar)
ovp <- data.frame(a = rep(seq_along(ov), lengths(ov)), b = unlist(ov))
ovp <- ovp[!(ar$anchor_source[ovp$a] == "osm_landing" & ar$anchor_source[ovp$b] == "osm_landing"), ]
fail(nrow(ovp) == 0, "two sites' areas overlap")
eh <- ly[ly$anchor_source == "einar", ]
fail(nrow(eh) == raw_n[["einar"]] && setequal(eh$pid_acronym, pins$pid), "an einar harbour is not a site of its own")
fail(all(ly$anchor_source[ly$iso %in% c("IS", "FO")] == "einar"), "a site in Iceland or the Faroes not anchored by einar")

acc <- f |>
  mutate(list = ifelse(derived, paste0(source, " (derived)"), source),
         reason_group = sub(":.*| [0-9,]+ km off$", "", sub("^in GFW dock area [^:]+: ", "dock area: ", reason))) |>
  count(list, outcome, reason_group, name = "features") |>
  arrange(list, outcome, desc(features)) |>
  mutate(verdict = if (length(fails)) paste(fails, collapse = "; ") else "ok")
cat("sites", nrow(ly), "by basis:", paste(names(table(ly$basis)), table(ly$basis), collapse = ", "), "\n")
print(as.data.frame(tidyr::pivot_wider(acc |> count(list, outcome, wt = features), names_from = outcome, values_from = n,
                                       values_fill = 0)))
write_curated(acc, fd_curated("check", "landing_site_accounting.parquet"),
              inputs = c(fd_curated("reference", "landing_site_feature.parquet"), fd_curated("reference", "landing_site.parquet")))
if (length(fails)) stop("landing_site_accounting: ", paste(fails, collapse = "; "))
