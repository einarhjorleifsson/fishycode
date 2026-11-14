# port_layer.R — one global port layer: every list's feature weighed as evidence, each port anchored once (plan 075 §2.2).
# Side: preprocessing (ports). See plan 014.
#
# Input:  staging/ports/port_feature.gpkg            every feature of every list (reference/ports/port_feature.R)
#         overrides/port_pid_pinned.csv              einar's pinned acronyms (decision 082)
#         curated/reference/port_ledger/             the numbers and the other acronyms (R/allocate_ports.R), read as an
#                                                    input, as the vid ledger is; empty until the first allocation
# Output: curated/reference/port_layer.parquet       one row per port: pid, pid_acronym, port_key, name, country, the
#                                                    anchor's geometry, its basis and the lists that agree
#         curated/reference/port_feature.parquet     every feature with its outcome, reason and port
#
# The cascade, in rank order (plan 075 §4 measured the ranks against the reviewed polygons; the maintainer: einar rules
# Iceland and the Faroes, every other list by measure). A feature joins the nearest port ANCHOR if it touches it, lies
# within R_NEAR with no name disagreeing, or within R_NAME with the same name; otherwise it anchors a new port. It joins
# anchors only, never a witness, so nothing chains. A feature joins an anchor of its own list only by the same name (OSM's
# parts excepted) or by touching it, and two einar harbours never merge. In Iceland and the Faroes nothing but einar anchors a port. Areas
# come before points within the ranks, so a port's geometry is its best area where there is one; anchors' areas never
# overlap, because a touching feature joins.
#
# A port needs evidence beyond its anchor's list: a feature of a second list, a UN/LOCODE location of its name within
# R_NAME (or of a member's code), an entry of the EU's location list (the MDR, where the feature table holds it: a study's
# test, since the maintainer held it out of the build on 2026-11-14; of a member's code, within R_NEAR with no name
# disagreeing, or of its name within R_NAME), or, for a GFW dock area, GFW's own label beside its AIS stops (ask a,
# answered 2026-11-14). A reviewed anchor (einar) needs none. A port without it is dissolved and its features flagged.
# Copies are not witnesses: EMODnet's points "from GISCO" lie within 10 m of GISCO's, a vmstools point, or an MDR
# position, within 10 m of a UN/LOCODE location counts as UN/LOCODE's, and an MDR position within 10 m of another list's
# point counts as that list's (2,293 of vmstools' 3,839 harbours, "EU Lot 2 project" in its help, lie within 10 m of an
# MDR position, most at 0 m). A disagreeing feature is flagged where it lies, never moved.
#
# Every feature ends in one outcome: chosen (a port's anchor), witness (another list), duplicate (the anchor's own list, or
# a copy), flagged (with its reason). A GFW dock anchorage takes its dock area's outcome.

library(sf)
library(dplyr)
library(tidyr)

R_NEAR <- 1000   # metres: the same port, whatever the names, unless they disagree (plan 075 §4: 300 m-1 km alike)
R_NAME <- 5000   # metres: the same port when the names agree (names agree in 10 % of nearest pairs at 5-10 km)
COPY_M <- 10     # metres: a copy, not a witness
RANK <- c(einar = 1, jeppe = 2, gfw_dock = 3, osm = 4, gisco = 5, maksims = 6, vmstools = 7, emodnet = 8, marta = 9)
REVIEWED <- "einar"
HOME <- c(einar = "IS|FO")   # in these countries only this list anchors a port
# A test: PORT_LAYER_HOLD_OUT names a list held out as truth (plan 075 §4; the maintainer, 2026-11-14: the Icelandic case "as a
# test against the web mined data"). Its features make no port and it rules no country; the layer goes to the study folder
# (PORT_LAYER_TEST_DIR), never to curated/.
# PORT_LAYER_FEATURES, also a test, reads another feature table (a study's) in place of staging's; PORT_LAYER_TEST_TAG
# names the run's files (by default "without_<list>").
HOLD_OUT <- Sys.getenv("PORT_LAYER_HOLD_OUT", "")
if (nzchar(HOLD_OUT)) {
  RANK <- RANK[names(RANK) != HOLD_OUT]
  HOME <- HOME[names(HOME) != HOLD_OUT]
}
FEATURES <- Sys.getenv("PORT_LAYER_FEATURES", fd_staging("ports", "port_feature.gpkg"))
TEST <- nzchar(HOLD_OUT) || FEATURES != fd_staging("ports", "port_feature.gpkg")
TAG <- Sys.getenv("PORT_LAYER_TEST_TAG", paste0("without_", HOLD_OUT))

feat <- read_sf(FEATURES)
feat$id <- seq_len(nrow(feat))
d <- st_drop_geometry(feat)

# Names: common harbour words stripped, then the same name if Jaro-Winkler >= 0.9 or one is the start of the other
GEN <- paste0("^(PORTOF|PORTDE|PORTO|PORT|HAVEN|HAVN|HAMN|HAFEN|HARBOUR|HARBOR|PUERTO|MARINA)|",
              "(HAVN|HAMN|HAFEN|HARBOUR|HARBOR|HAVEN|PORT|HAMNEN|HAVNEN|HOFN|FISKIHOFN|MARINA|ANCHORAGE)$")
k2 <- gsub(GEN, "", d$name_key)
d$k2 <- ifelse(nchar(k2) >= 3, k2, d$name_key)
same_name <- function(a, b) {
  ok <- !is.na(a) & !is.na(b) & nchar(a) >= 3 & nchar(b) >= 3
  s <- stringdist::stringsim(a, b, method = "jw", p = 0.1)
  ok & (s >= 0.9 | (nchar(a) >= 4 & nchar(b) >= 4 & (startsWith(a, b) | startsWith(b, a))))
}
named <- function(a) !is.na(a) & nchar(a) >= 3

# Who may anchor, who only witnesses ------------------------------------------------------------------------------------
d$copy_of <- NA_character_
em <- which(d$source == "emodnet" & d$kind == "from GISCO" & d$has_pos)
gi <- which(d$source == "gisco")
xyz <- function(lon, lat) { p <- lat * pi / 180; l <- lon * pi / 180; 6371008.8 * cbind(cos(p) * cos(l), cos(p) * sin(l), sin(p)) }
nn <- RANN::nn2(xyz(d$lon[gi], d$lat[gi]), xyz(d$lon[em], d$lat[em]), k = 1)
d$copy_of[em] <- ifelse(nn$nn.dists[, 1] <= COPY_M, paste0("gisco:", d$feature_key[gi[nn$nn.idx[, 1]]]), NA)
ul <- which(d$source == "unlocode" & d$has_pos)
vm <- which(d$source == "vmstools")
nn <- RANN::nn2(xyz(d$lon[ul], d$lat[ul]), xyz(d$lon[vm], d$lat[vm]), k = 1)
vm_copy <- vm[nn$nn.dists[, 1] <= COPY_M]
d$family <- ifelse(d$source %in% c("gfw", "gfw_dock"), "gfw", d$source)
d$family[vm_copy] <- "unlocode"          # a copied coordinate is UN/LOCODE's evidence, not a second list's
d$family[!is.na(d$copy_of)] <- "gisco"
# the MDR took most UN/LOCODE positions as they were: an MDR position within COPY_M of its code's UN/LOCODE location
md <- which(d$source == "mdr" & d$has_pos & !is.na(d$locode))
uk <- match(paste0(d$iso_src[md], d$locode[md]), sub("_[0-9]+$", "", d$feature_key[ul]))
md <- md[!is.na(uk)]; uk <- uk[!is.na(uk)]
if (length(md)) {
  md_m <- geosphere::distHaversine(cbind(d$lon[md], d$lat[md]), cbind(d$lon[ul][uk], d$lat[ul][uk]))
  d$family[md[md_m <= COPY_M]] <- "unlocode"
}
# and an MDR position within COPY_M of another list's point is that list's (vmstools' harbours share the MDR's positions)
md <- which(d$source == "mdr" & d$has_pos & d$family == "mdr")
pt <- which(!d$source %in% c("mdr", "gfw") & d$has_pos & d$gtype %in% "point")
if (length(md) && length(pt)) {
  nn <- RANN::nn2(xyz(d$lon[pt], d$lat[pt]), xyz(d$lon[md], d$lat[md]), k = 1)
  cp_ <- nn$nn.dists[, 1] <= COPY_M
  d$family[md[cp_]] <- d$family[pt[nn$nn.idx[cp_, 1]]]
}

maker <- d$source %in% names(RANK) & d$has_pos & is.na(d$copy_of)
mk <- which(maker)

# Candidate pairs among the port-making features: exact distance in metres (s2) within R_NAME
sf_use_s2(TRUE)
G <- st_geometry(feat)[mk]
nb <- st_is_within_distance(G, G, dist = R_NAME)
pr <- do.call(rbind, lapply(seq_along(nb), \(i) { j <- nb[[i]]; j <- j[j != i]; if (length(j)) cbind(i, j) }))
up <- pr[pr[, 1] < pr[, 2], , drop = FALSE]
dd <- as.numeric(st_distance(G[up[, 1]], G[up[, 2]], by_element = TRUE))
pairs <- tibble(i = mk[up[, 1]], j = mk[up[, 2]], dist = dd)
pairs <- bind_rows(pairs, pairs |> rename(i = j, j = i))
pairs$agree <- same_name(d$k2[pairs$i], d$k2[pairs$j])
pairs$both_named <- named(d$k2[pairs$i]) & named(d$k2[pairs$j])
nbl <- split(pairs, pairs$i)
sf_use_s2(FALSE)

# The cascade ---------------------------------------------------------------------------------------------------------
home_of <- rep(NA_character_, nrow(d))
for (h in names(HOME)) home_of[grepl(paste0("^(", HOME[[h]], ")$"), d$iso_geo)] <- h
ord <- mk[order(RANK[d$source[mk]], d$gtype[mk] != "area", -coalesce(d$area_m2[mk], 0), d$source[mk], d$feature_key[mk])]
port <- rep(NA_integer_, nrow(d))
anchor <- rep(FALSE, nrow(d))
how <- rep(NA_character_, nrow(d))
dist_to <- rep(NA_real_, nrow(d))
for (f in ord) {
  nbf <- nbl[[as.character(f)]]
  if (!is.null(nbf)) {
    nbf <- nbf[anchor[nbf$j], , drop = FALSE]
    same <- d$source[nbf$j] == d$source[f]
    ok <- nbf$dist == 0 | (nbf$dist <= R_NEAR & (!nbf$both_named | nbf$agree)) | (nbf$agree & nbf$dist <= R_NAME)
    # its own list: only by the same name, or touching (two areas that touch are one port), and never two reviewed harbours
    ok <- ok & (!same | nbf$agree | nbf$dist == 0 | d$source[f] == "osm") & !(same & d$source[f] %in% REVIEWED)
    nbf <- nbf[ok, , drop = FALSE]
    if (nrow(nbf)) {
      b <- nbf[order(nbf$dist > 0, !nbf$agree, nbf$dist, nbf$j), ][1, ]
      port[f] <- b$j
      dist_to[f] <- b$dist
      how[f] <- if (b$dist == 0) "touches the anchor" else if (b$dist <= R_NEAR) "within 1 km" else "same name within 5 km"
      next
    }
  }
  if (!is.na(home_of[f]) && d$source[f] != home_of[f]) { how[f] <- "home list has no port here"; next }
  port[f] <- f
  anchor[f] <- TRUE
  dist_to[f] <- 0
  how[f] <- "anchor"
}

# Witness-only lists --------------------------------------------------------------------------------------------------
A <- which(anchor)
xa <- xyz(d$lon[A], d$lat[A])
# the nearest anchor within R_NEAR of each row (distance to the anchor's geometry); with `names`, never one whose name
# disagrees
near_anchor <- function(rows, names = FALSE) {
  if (!length(rows)) return(list(port = integer(), dist = numeric()))
  cand <-RANN::nn2(xa, xyz(d$lon[rows], d$lat[rows]), k = min(10, length(A)))
  pts <- st_as_sf(d[rows, c("lon", "lat")], coords = c("lon", "lat"), crs = 4326)
  best <- rep(NA_integer_, length(rows)); bdist <- rep(NA_real_, length(rows))
  near_any <- which(cand$nn.dists[, 1] <= R_NEAR + 50000)   # an area anchor's point may lie far from its edge
  sf_use_s2(TRUE)
  for (k in seq_len(ncol(cand$nn.idx))) {
    a <- A[cand$nn.idx[near_any, k]]
    dk <- as.numeric(st_distance(st_geometry(pts)[near_any], st_geometry(feat)[a], by_element = TRUE))
    ok <- if (names) !(named(d$k2[rows[near_any]]) & named(d$k2[a])) | same_name(d$k2[rows[near_any]], d$k2[a]) else TRUE
    better <- dk <= R_NEAR & ok & (is.na(bdist[near_any]) | dk < bdist[near_any])
    best[near_any[better]] <- a[better]; bdist[near_any[better]] <- dk[better]
  }
  sf_use_s2(FALSE)
  list(port = best, dist = bdist)
}
# GFW anchorages away from a dock: the nearest anchor within R_NEAR
nd <- which(d$source == "gfw" & is.na(d$part_of) & d$has_pos)
na_ <- near_anchor(nd)
best <- na_$port; bdist <- na_$dist
port[nd] <- best; dist_to[nd] <- bdist
how[nd] <- ifelse(is.na(best), "not a dock, no port within 1 km", "GFW anchorage within 1 km")
# UN/LOCODE: by a member's code, else by its name within R_NAME
mem <- which(!is.na(port) & !is.na(d$locode) & d$source != "unlocode")
code_port <- tapply(port[mem], paste0(d$iso_src[mem], d$locode[mem]), \(p) p[1])
uc <- which(d$source == "unlocode")
ucode <- sub("_[0-9]+$", "", d$feature_key[uc])
port[uc] <- unname(code_port[ucode])
how[uc] <- ifelse(is.na(port[uc]), NA, "same UN/LOCODE")
un <- uc[is.na(port[uc]) & d$has_pos[uc]]
cand <- RANN::nn2(xa, xyz(d$lon[un], d$lat[un]), k = min(10, length(A)))
for (k in seq_len(ncol(cand$nn.idx))) {
  a <- A[cand$nn.idx[, k]]
  dk <- geosphere::distHaversine(cbind(d$lon[un], d$lat[un]), cbind(d$lon[a], d$lat[a]))
  ok <- is.na(port[un]) & dk <= R_NAME & same_name(d$k2[un], d$k2[a])
  port[un[ok]] <- a[ok]; dist_to[un[ok]] <- dk[ok]; how[un[ok]] <- "same name within 5 km"
}
how[uc][is.na(port[uc]) & !d$has_pos[uc]] <- "no position"
how[uc][is.na(port[uc]) & d$has_pos[uc]] <- "no port of its name or code within 5 km"
# The EU's location list (MDR): by a member's code (never a witness's, so nothing chains), else the nearest anchor within
# R_NEAR whose name does not disagree, else an anchor of its name within R_NAME
mc <- which(d$source == "mdr")
mem <- which(!is.na(port) & !is.na(d$locode) & !d$source %in% c("unlocode", "mdr"))
code_port <- tapply(port[mem], paste0(d$iso_src[mem], d$locode[mem]), \(p) p[1])
port[mc] <- unname(code_port[sub("_[0-9]+$", "", d$feature_key[mc])])
how[mc] <- ifelse(is.na(port[mc]), NA, "same code")
mn <- mc[is.na(port[mc]) & d$has_pos[mc]]
na_ <- near_anchor(mn, names = TRUE)
port[mn] <- na_$port; dist_to[mn] <- na_$dist
how[mn] <- ifelse(is.na(na_$port), NA, "within 1 km")
mn <- mn[is.na(port[mn])]
if (length(mn)) cand <- RANN::nn2(xa, xyz(d$lon[mn], d$lat[mn]), k = min(10, length(A)))
for (k in seq_len(if (length(mn)) ncol(cand$nn.idx) else 0)) {
  a <- A[cand$nn.idx[, k]]
  dk <- geosphere::distHaversine(cbind(d$lon[mn], d$lat[mn]), cbind(d$lon[a], d$lat[a]))
  ok <- is.na(port[mn]) & dk <= R_NAME & same_name(d$k2[mn], d$k2[a])
  port[mn[ok]] <- a[ok]; dist_to[mn[ok]] <- dk[ok]; how[mn[ok]] <- "same name within 5 km"
}
how[mc][is.na(port[mc]) & d$has_pos[mc]] <- "no port of its code, none within 1 km, none of its name within 5 km"
cpm <- mc[d$family[mc] != "mdr"]
how[cpm] <- paste0(how[cpm], " (its position is ", d$family[cpm], "'s)")
how[!d$has_pos & is.na(how)] <- ifelse(d$pos_out_of_range[!d$has_pos & is.na(how)], "position out of range", "no position")
if (nzchar(HOLD_OUT)) how[d$source == HOLD_OUT] <- "held out as truth (a test)"

# A port needs evidence beyond its anchor's list -----------------------------------------------------------------------
on <- which(!is.na(port))
fams <- tapply(d$family[on], port[on], \(s) sort(unique(s)))
gfw_label <- d$source[A] == "gfw_dock"     # GFW's named label beside its AIS stops counts (ask a)
n_fam <- vapply(fams[as.character(A)], length, 1L) + gfw_label
keep <- A[n_fam >= 2 | d$source[A] %in% REVIEWED]
lone <- setdiff(A, keep)
drop <- which(port %in% lone)
how[drop] <- ifelse(d$id[drop] %in% lone, "unwitnessed", paste0("joined a port that is unwitnessed (", how[drop], ")"))
anchor[lone] <- FALSE
port[drop] <- NA

# A displaced feature: unwitnessed, and a feature of another list with its name lies over 20 km off in its country
un_f <- which(how %in% "unwitnessed")
nm <- d |> filter(has_pos, named(k2), source != "gfw") |> select(id, source, k2, iso_geo, lon, lat)
x <- d[un_f, ] |> filter(named(k2)) |> select(id, source, k2, iso_geo, lon, lat) |>
  mutate(b = substr(k2, 1, 3)) |>
  inner_join(nm |> mutate(b = substr(k2, 1, 3)), by = c("iso_geo", "b"), suffix = c("", ".w"), relationship = "many-to-many") |>
  filter(source != source.w) |>
  filter(same_name(k2, k2.w)) |>
  mutate(km = geosphere::distHaversine(cbind(lon, lat), cbind(lon.w, lat.w)) / 1000) |>
  group_by(id) |> summarise(km = min(km), .groups = "drop") |> filter(km > 20)
how[x$id] <- sprintf("displaced: a feature of another list with its name lies %.0f km off", x$km)

# Outcomes ------------------------------------------------------------------------------------------------------------
outcome <- case_when(
  anchor ~ "chosen",
  !is.na(d$copy_of) ~ "duplicate",
  !is.na(port) & d$family == d$family[pmax(port, 1L)] ~ "duplicate",
  !is.na(port) ~ "witness",
  TRUE ~ "flagged")
# a copy follows its original: the original's port, or flagged with it
cp <- which(!is.na(d$copy_of))
orig <- match(d$copy_of[cp], paste0(d$source, ":", d$feature_key))
port[cp] <- port[orig]
outcome[cp] <- ifelse(is.na(port[orig]), "flagged", "duplicate")
how[cp] <- paste0("copy of ", d$copy_of[cp], ifelse(is.na(port[orig]), ", which is flagged", ""))
# a GFW dock anchorage takes its dock area's outcome and port
pk <- match(d$part_of, d$feature_key[d$source == "gfw_dock"])
da <- which(!is.na(d$part_of))
dk <- which(d$source == "gfw_dock")[pk[da]]
port[da] <- port[dk]
outcome[da] <- outcome[dk]
how[da] <- paste0("in GFW dock area ", d$feature_key[dk], ": ", how[dk])
stopifnot("every feature has an outcome" = !anyNA(outcome), "every outcome has a reason" = !anyNA(how))

# The ports -----------------------------------------------------------------------------------------------------------
pins <- read.csv("overrides/port_pid_pinned.csv", colClasses = "character")
ports <- d[keep, ] |>
  transmute(anchor_id = id, port_key = paste0(source, ":", feature_key), anchor_source = source, anchor_key = feature_key,
            iso = coalesce(if_else(source == "einar", substr(feature_key, 1, 2), NA_character_), iso_geo, iso_src),
            geom_type = gtype, hid, area_m2, on_land, d_coast_km,
            basis = if_else(source %in% REVIEWED, "reviewed", "witnessed"))
ports$pid_acronym <- pins$pid[match(ports$anchor_key, pins$pid_bootstrap)]
ports$pid_acronym[ports$anchor_source != "einar"] <- NA
# the name by the same cascade: the anchor's, else the first named member by rank
mem <- tibble(id = d$id, port = port, source = d$source, name = d$name, rank = RANK[d$source]) |>
  filter(!is.na(port), !is.na(name), nchar(name) > 0, source %in% names(RANK)) |>
  arrange(port, id != port, rank, id)
nm1 <- mem |> distinct(port, .keep_all = TRUE)
ports$name <- nm1$name[match(ports$anchor_id, nm1$port)]
ports$name_from <- nm1$source[match(ports$anchor_id, nm1$port)]
agree <- tibble(port = port, family = d$family, source = d$source) |> filter(!is.na(port)) |>
  group_by(port) |> summarise(lists = paste(sort(unique(family)), collapse = ","), n_features = n(), .groups = "drop")
ports <- ports |> left_join(agree, by = c("anchor_id" = "port"))
ports$lists[ports$anchor_source == "gfw_dock"] <- paste0(ports$lists[ports$anchor_source == "gfw_dock"], ",gfw_label")
ports$n_lists <- lengths(strsplit(ports$lists, ","))

# The number, from the ledger (R/allocate_ports.R); NA until allocated
led <- read_port_ledger()
ports$pid <- led$pid[match(ports$port_key, led$port_key)]
ports$pid_acronym <- coalesce(ports$pid_acronym, led$pid_acronym[match(ports$port_key, led$port_key)])
cat("ports", nrow(ports), " numbered", sum(!is.na(ports$pid)), "\n")
ports <- ports |> select(pid, pid_acronym, port_key, name, name_from, iso, basis, geom_type, lists, n_lists, n_features,
                         anchor_source, anchor_key, hid, area_m2, on_land, d_coast_km, anchor_id)
layer <- st_sf(ports, geom = st_geometry(feat)[ports$anchor_id])

# Every feature, one outcome; einar whole; no two areas overlap
stopifnot(
  "one anchor per port" = setequal(which(anchor), ports$anchor_id),
  "every einar harbour is a port of its own" = HOLD_OUT == "einar" ||
    setequal(ports$anchor_key[ports$anchor_source == "einar"], d$feature_key[d$source == "einar"]),
  "port keys unique" = !anyDuplicated(ports$port_key))
areas <- layer[layer$geom_type == "area", ]
ov <- st_overlaps(st_transform(areas, 3035))
if (sum(lengths(ov))) {
  i <- which(lengths(ov) > 0)
  print(head(data.frame(a = areas$port_key[i], b = vapply(ov[i], \(j) areas$port_key[j[1]], "")), 20))
}
stopifnot("no two ports' areas overlap" = sum(lengths(ov)) == 0)

d$outcome <- outcome
d$reason <- how
d$port_key <- ports$port_key[match(port, ports$anchor_id)]
d$pid <- ports$pid[match(port, ports$anchor_id)]
d$dist_m <- round(dist_to)
cat("outcomes\n"); print(table(d$source, d$outcome))

feat_out <- st_sf(d |> select(source, feature_key, derived, part_of, name, iso_src, iso_geo, locode, kind, gtype, repaired,
                              family, outcome, reason, port_key, pid, dist_m, lon, lat, d_coast_km),
                  geom = st_geometry(feat))
if (TEST) {
  dir <- Sys.getenv("PORT_LAYER_TEST_DIR")
  stopifnot("a test writes to a folder of its own, never curated/" = nzchar(dir), !grepl("/curated/", dir), nzchar(TAG),
            TAG != "without_")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(layer, file.path(dir, paste0("port_layer_", TAG, ".rds")))
  saveRDS(feat_out, file.path(dir, paste0("port_feature_", TAG, ".rds")))
} else {
  inputs <- c(FEATURES, "overrides/port_pid_pinned.csv", port_ledger_files())
  write_curated(layer |> select(-anchor_id), fd_curated("reference", "port_layer.parquet"), inputs = inputs)
  write_curated(feat_out, fd_curated("reference", "port_feature.parquet"), inputs = inputs)
}
