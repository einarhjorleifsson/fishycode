# landing_site.R — one table of potential landing sites: every list's feature weighed as evidence, each site anchored
# once, with its basis; the ports a subset by basis (plan 075 §2.2; port_layer.R, a port layer, until step 6).
# Side: preprocessing (ports). See plan 014.
#
# Input:  staging/ports/landing_site_feature.gpkg     every feature of every list (reference/ports/landing_site_feature.R)
#         overrides/port_pid_pinned.csv              einar's pinned acronyms (decision 082)
#         curated/reference/port_ledger/             the numbers and the other acronyms (R/allocate_ports.R), read as an
#                                                    input, as the vid ledger is
# Output: curated/reference/landing_site.parquet     one row per site: pid, pid_acronym, site_key, name, country, the
#                                                    anchor's geometry, its basis and the lists that agree
#         curated/reference/landing_site_feature.parquet  every feature with its outcome, reason and site
#
# The cascade, in rank order (plan 075 §4 measured the ranks against the reviewed polygons; the maintainer: einar first,
# every other list by measure). A feature joins the nearest site ANCHOR if it touches it, lies within R_NEAR with no name
# disagreeing, or within R_NAME with the same name; otherwise it anchors a new site. It joins anchors only, never a
# witness, so nothing chains. A feature joins an anchor of its own list only by the same name (OSM's parts excepted) or by
# touching it, and two einar harbours never merge. Areas come before points within the ranks, so a site's geometry is its
# best area where there is one; anchors' areas never overlap, because a touching feature joins. In Iceland and the Faroes
# only einar anchors a site: a feature there that joins no einar harbour is flagged `home list has no site here`, a small
# landing too (the maintainer, 2026-11-15, reinstating the rule ask n had set aside: without it the two countries gained
# GISCO's Höfn beside einar's Hornafjörður, single GFW dock anchorages and unnamed OSM port areas in the Faroes, and 75
# small landings).
#
# OSM's small landings (`osm_landing`) come last, and are not grouped among themselves (ask m: a landing place's several
# jetties are grouped later in the processing). Each joins the nearest anchor of a port list by the same rules, as
# `joined`, or anchors a site of its own. A small landing is no witness: piers stand on every shore, so one beside a
# single list's feature does not make a port. An object that also carries a port tag is OSM's port feature's duplicate.
#
# Every anchor is a site, and its basis says what stands behind it, strongest first (plan 075 §2.2.3):
#   reviewed   an einar harbour;
#   witnessed  evidence beyond its anchor's list: a feature of a second list, a UN/LOCODE location of its name within
#              R_NAME (or of a member's code), an entry of the EU's location list (the MDR, where the feature table holds
#              it: a study's test, since the maintainer held it out on 2026-11-14), or, for a GFW dock area, GFW's own
#              label beside its AIS stops (ask a, answered 2026-11-14);
#   one list   a single list's feature;
#   structure  a small landing alone: a slipway, pier, quay, small-craft facility or mooring;
#   context    a breakwater or groyne alone: coast protection as often as a landing (ask l, left open: the maintainer,
#              2026-11-15, labelled rather than ruled).
# A port is a site whose basis is reviewed or witnessed (ask a). Copies are not witnesses: EMODnet's points "from GISCO"
# lie within 10 m of GISCO's, a vmstools point, or an MDR position, within 10 m of a UN/LOCODE location counts as
# UN/LOCODE's, and an MDR position within 10 m of another list's point counts as that list's. A disagreeing feature is
# flagged where it lies, never moved: a single list's anchor with a feature of another list of its name over 20 km off in
# its country is `displaced`, and the cascade is run again without it, so the features that had joined it find their own
# place.
#
# Every feature ends in one outcome: chosen (a site's anchor), witness (another list), duplicate (the anchor's own list, or
# a copy), joined (a small landing at a port list's site), flagged (with its reason). A GFW dock anchorage takes its dock
# area's outcome.

library(sf)
library(dplyr)
library(tidyr)

R_NEAR <- 1000   # metres: the same site, whatever the names, unless they disagree (plan 075 §4: 300 m-1 km alike)
R_NAME <- 5000   # metres: the same site when the names agree (names agree in 10 % of nearest pairs at 5-10 km)
COPY_M <- 10     # metres: a copy, not a witness
RANK <- c(einar = 1, jeppe = 2, gfw_dock = 3, osm = 4, gisco = 5, maksims = 6, vmstools = 7, emodnet = 8, marta = 9,
          osm_landing = 10)
REVIEWED <- "einar"
HOME <- c(einar = "IS|FO")   # in these countries only this list anchors a site
LANDING <- "osm_landing"
CONTEXT <- c("breakwater", "groyne")
# A test: LANDING_SITE_HOLD_OUT names a list held out as truth (plan 075 §4; the maintainer, 2026-11-14: the Icelandic case
# "as a test against the web mined data"). Its features make no site; the table goes to the study folder
# (LANDING_SITE_TEST_DIR), never to curated/. LANDING_SITE_FEATURES, also a test, reads another feature table (a study's)
# in place of staging's; LANDING_SITE_TEST_TAG names the run's files (by default "without_<list>"). The study of
# 2026-11-14 ran these as PORT_LAYER_*, before step 6.
HOLD_OUT <- Sys.getenv("LANDING_SITE_HOLD_OUT", "")
if (nzchar(HOLD_OUT)) {
  RANK <- RANK[names(RANK) != HOLD_OUT]
  HOME <- HOME[names(HOME) != HOLD_OUT]
}
FEATURES <- Sys.getenv("LANDING_SITE_FEATURES", fd_staging("ports", "landing_site_feature.gpkg"))
TEST <- nzchar(HOLD_OUT) || FEATURES != fd_staging("ports", "landing_site_feature.gpkg")
TAG <- Sys.getenv("LANDING_SITE_TEST_TAG", paste0("without_", HOLD_OUT))

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
# an OSM object with a port tag and a small-landing tag: the port feature's
ol <- which(d$source == LANDING)
d$copy_of[ol] <- ifelse(d$feature_key[ol] %in% d$feature_key[d$source == "osm"], paste0("osm:", d$feature_key[ol]), NA)
ul <- which(d$source == "unlocode" & d$has_pos)
vm <- which(d$source == "vmstools")
nn <- RANN::nn2(xyz(d$lon[ul], d$lat[ul]), xyz(d$lon[vm], d$lat[vm]), k = 1)
vm_copy <- vm[nn$nn.dists[, 1] <= COPY_M]
d$family <- ifelse(d$source %in% c("gfw", "gfw_dock"), "gfw", d$source)
d$family[vm_copy] <- "unlocode"          # a copied coordinate is UN/LOCODE's evidence, not a second list's
d$family[d$source == "emodnet" & !is.na(d$copy_of)] <- "gisco"
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
pt <- which(!d$source %in% c("mdr", "gfw", LANDING) & d$has_pos & d$gtype %in% "point")
if (length(md) && length(pt)) {
  nn <- RANN::nn2(xyz(d$lon[pt], d$lat[pt]), xyz(d$lon[md], d$lat[md]), k = 1)
  cp_ <- nn$nn.dists[, 1] <= COPY_M
  d$family[md[cp_]] <- d$family[pt[nn$nn.idx[cp_, 1]]]
}

# the port lists' features that may anchor, and the small landings
maker <- d$source %in% setdiff(names(RANK), LANDING) & d$has_pos & is.na(d$copy_of)
mk <- which(maker)
la <- which(d$source == LANDING & d$source %in% names(RANK) & d$has_pos & is.na(d$copy_of))

# Candidate pairs among the port lists' features: exact distance in metres (s2) within R_NAME. s2 rejects what GEOS lets
# pass (a ring with a repeated vertex, among the small landings): such a geometry is rebuilt by s2 for the distances
# alone; the table keeps it as drawn.
s2_safe <- function(g) {
  bad <- which(!s2::s2_is_valid(g))
  if (length(bad)) g[bad] <- st_as_sfc(s2::s2_rebuild(s2::as_s2_geography(st_as_binary(g[bad]), check = FALSE)))
  g
}
sf_use_s2(TRUE)
G <- s2_safe(st_geometry(feat)[mk])
nb <- st_is_within_distance(G, G, dist = R_NAME)
pr <- do.call(rbind, lapply(seq_along(nb), \(i) { j <- nb[[i]]; j <- j[j != i]; if (length(j)) cbind(i, j) }))
up <- pr[pr[, 1] < pr[, 2], , drop = FALSE]
dd <- as.numeric(st_distance(G[up[, 1]], G[up[, 2]], by_element = TRUE))
pairs <- tibble(i = mk[up[, 1]], j = mk[up[, 2]], dist = dd)
pairs <- bind_rows(pairs, pairs |> rename(i = j, j = i))
pairs$agree <- same_name(d$k2[pairs$i], d$k2[pairs$j])
pairs$both_named <- named(d$k2[pairs$i]) & named(d$k2[pairs$j])
nbl <- split(pairs, pairs$i)
# and from each small landing to the port lists' features: any within R_NEAR, a named one's within R_NAME
GL <- s2_safe(st_geometry(feat)[la])
nb1 <- st_is_within_distance(GL, G, dist = R_NEAR)
nm_la <- which(named(d$k2[la]))
nb5 <- st_is_within_distance(GL[nm_la], G, dist = R_NAME)
lp <- unique(rbind(cbind(rep(seq_along(nb1), lengths(nb1)), as.integer(unlist(nb1))),
                   cbind(rep(nm_la, lengths(nb5)), as.integer(unlist(nb5)))))
lpairs <- tibble(i = la[lp[, 1]], j = mk[lp[, 2]], dist = as.numeric(st_distance(GL[lp[, 1]], G[lp[, 2]], by_element = TRUE)))
lpairs$agree <- same_name(d$k2[lpairs$i], d$k2[lpairs$j])
lpairs$both_named <- named(d$k2[lpairs$i]) & named(d$k2[lpairs$j])
lpairs <- lpairs[lpairs$dist <= R_NEAR | lpairs$agree, ]
sf_use_s2(FALSE)
home_of <- rep(NA_character_, nrow(d))
for (h in names(HOME)) home_of[grepl(paste0("^(", HOME[[h]], ")$"), d$iso_geo)] <- h
ord_all <- mk[order(RANK[d$source[mk]], d$gtype[mk] != "area", -coalesce(d$area_m2[mk], 0), d$source[mk], d$feature_key[mk])]

# The cascade, run again without each displaced anchor ------------------------------------------------------------------
# `out`: rows held out as displaced. Returns each row's site (the anchor's row), whether it anchors, how it was placed,
# and its distance to the anchor.
place <- function(out) {
  port <- rep(NA_integer_, nrow(d)); anchor <- rep(FALSE, nrow(d)); how <- rep(NA_character_, nrow(d))
  dist_to <- rep(NA_real_, nrow(d))
  for (f in setdiff(ord_all, out)) {
    nbf <- nbl[[as.character(f)]]
    if (!is.null(nbf)) {
      nbf <- nbf[anchor[nbf$j], , drop = FALSE]
      same <- d$source[nbf$j] == d$source[f]
      ok <- nbf$dist == 0 | (nbf$dist <= R_NEAR & (!nbf$both_named | nbf$agree)) | (nbf$agree & nbf$dist <= R_NAME)
      # its own list: only by the same name, or touching (two areas that touch are one site), and never two reviewed harbours
      ok <- ok & (!same | nbf$agree | nbf$dist == 0 | d$source[f] == "osm") & !(same & d$source[f] %in% REVIEWED)
      nbf <- nbf[ok, , drop = FALSE]
      if (nrow(nbf)) {
        b <- nbf[order(nbf$dist > 0, !nbf$agree, nbf$dist, nbf$j), ][1, ]
        port[f] <- b$j; dist_to[f] <- b$dist
        how[f] <- if (b$dist == 0) "touches the anchor" else if (b$dist <= R_NEAR) "within 1 km" else "same name within 5 km"
        next
      }
    }
    if (!is.na(home_of[f]) && d$source[f] != home_of[f]) { how[f] <- "home list has no site here"; next }
    port[f] <- f; anchor[f] <- TRUE; dist_to[f] <- 0; how[f] <- "anchor"
  }
  # the small landings: the best anchor of a port list by the same rules, else a site of their own
  lp_ <- lpairs[anchor[lpairs$j] & !lpairs$i %in% out, ]
  lp_ <- lp_[lp_$dist == 0 | (lp_$dist <= R_NEAR & (!lp_$both_named | lp_$agree)) | (lp_$agree & lp_$dist <= R_NAME), ]
  lp_ <- lp_[order(lp_$i, lp_$dist > 0, !lp_$agree, lp_$dist, lp_$j), ]
  lp_ <- lp_[!duplicated(lp_$i), ]
  port[lp_$i] <- lp_$j; dist_to[lp_$i] <- lp_$dist
  how[lp_$i] <- ifelse(lp_$dist == 0, "touches the anchor", ifelse(lp_$dist <= R_NEAR, "within 1 km", "same name within 5 km"))
  own <- setdiff(la[is.na(port[la])], out)
  hm <- own[!is.na(home_of[own])]
  how[hm] <- "home list has no site here"
  own <- setdiff(own, hm)
  port[own] <- own; anchor[own] <- TRUE; dist_to[own] <- 0; how[own] <- "anchor"
  list(port = port, anchor = anchor, how = how, dist_to = dist_to)
}

# Witness-only lists: GFW's anchorages away from a dock, UN/LOCODE, the MDR, placed at the port lists' anchors ----------
witnesses <- function(p) {
  port <- p$port; how <- p$how; dist_to <- p$dist_to
  A <- which(p$anchor & d$source != LANDING)
  xa <- xyz(d$lon[A], d$lat[A])
  # the nearest anchor within R_NEAR of each row (distance to the anchor's geometry); with `names`, never one whose name
  # disagrees
  near_anchor <- function(rows, names = FALSE) {
    if (!length(rows)) return(list(port = integer(), dist = numeric()))
    cand <- RANN::nn2(xa, xyz(d$lon[rows], d$lat[rows]), k = min(10, length(A)))
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
  port[nd] <- na_$port; dist_to[nd] <- na_$dist
  how[nd] <- ifelse(is.na(na_$port), "not a dock, no port list's site within 1 km", "GFW anchorage within 1 km")
  # UN/LOCODE: by a member's code, else by its name within R_NAME
  mem <- which(!is.na(port) & !is.na(d$locode) & d$source != "unlocode")
  code_port <- tapply(port[mem], paste0(d$iso_src[mem], d$locode[mem]), \(p) p[1])
  uc <- which(d$source == "unlocode")
  port[uc] <- unname(code_port[sub("_[0-9]+$", "", d$feature_key[uc])])
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
  how[uc][is.na(port[uc]) & d$has_pos[uc]] <- "no site of its name or code within 5 km"
  # The EU's location list (MDR): by a member's code (never a witness's, so nothing chains), else the nearest anchor
  # within R_NEAR whose name does not disagree, else an anchor of its name within R_NAME
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
  how[mc][is.na(port[mc]) & d$has_pos[mc]] <- "no site of its code, none within 1 km, none of its name within 5 km"
  cpm <- mc[d$family[mc] != "mdr"]
  how[cpm] <- paste0(how[cpm], " (its position is ", d$family[cpm], "'s)")
  p$port <- port; p$how <- how; p$dist_to <- dist_to
  p
}

# The basis of each anchor: the families of evidence among its members, a small landing not counted
basis_of <- function(p) {
  A <- which(p$anchor)
  on <- which(!is.na(p$port) & d$source != LANDING)
  fams <- tapply(d$family[on], p$port[on], \(s) sort(unique(s)))
  n_fam <- vapply(as.character(A), \(a) if (a %in% names(fams)) length(fams[[a]]) else 0L, 1L) +
    (d$source[A] == "gfw_dock")   # GFW's label (ask a)
  b <- ifelse(d$source[A] %in% REVIEWED, "reviewed", ifelse(n_fam >= 2, "witnessed", "one list"))
  ctx <- grepl(paste0("man_made=(", paste(CONTEXT, collapse = "|"), ")"), d$kind[A]) &
    !grepl("leisure=slipway|seamark:type=", d$kind[A])
  b[d$source[A] == LANDING] <- ifelse(ctx[d$source[A] == LANDING], "context", "structure")
  setNames(b, A)
}

# A displaced feature: a single list's anchor, and a feature of another list with its name lies over 20 km off in its
# country
nm_w <- d |> filter(has_pos, named(k2), !source %in% c("gfw", LANDING)) |> select(id, source, k2, iso_geo, lon, lat)
displaced <- function(rows) {
  if (!length(rows)) return(tibble(id = integer(), km = numeric()))
  d[rows, ] |> filter(named(k2)) |> select(id, source, k2, iso_geo, lon, lat) |>
    mutate(b = substr(k2, 1, 3)) |>
    inner_join(nm_w |> mutate(b = substr(k2, 1, 3)), by = c("iso_geo", "b"), suffix = c("", ".w"), relationship = "many-to-many") |>
    filter(source != source.w) |>
    filter(same_name(k2, k2.w)) |>
    mutate(km = geosphere::distHaversine(cbind(lon, lat), cbind(lon.w, lat.w)) / 1000) |>
    group_by(id) |> summarise(km = min(km), .groups = "drop") |> filter(km > 20)
}
out <- integer(); out_km <- numeric()
for (pass in 1:5) {
  p <- witnesses(place(out))
  bs <- basis_of(p)
  dp <- displaced(as.integer(names(bs)[bs == "one list"]))
  cat(sprintf("pass %d: %d sites, %d displaced\n", pass, length(bs), nrow(dp)))
  if (!nrow(dp)) break
  out <- c(out, dp$id); out_km <- c(out_km, dp$km)
}
stopifnot("the displaced anchors settle within five passes" = !nrow(dp))
port <- p$port; anchor <- p$anchor; how <- p$how; dist_to <- p$dist_to
how[out] <- sprintf("displaced: a feature of another list with its name lies %.0f km off", out_km)
how[!d$has_pos & is.na(how)] <- ifelse(d$pos_out_of_range[!d$has_pos & is.na(how)], "position out of range", "no position")
if (nzchar(HOLD_OUT)) how[d$source == HOLD_OUT] <- "held out as truth (a test)"

# Outcomes ------------------------------------------------------------------------------------------------------------
outcome <- case_when(
  anchor ~ "chosen",
  !is.na(d$copy_of) ~ "duplicate",
  !is.na(port) & d$source == LANDING ~ "joined",
  !is.na(port) & d$family == d$family[pmax(port, 1L)] ~ "duplicate",
  !is.na(port) ~ "witness",
  TRUE ~ "flagged")
# a copy follows its original: the original's site, or flagged with it
cp <- which(!is.na(d$copy_of))
orig <- match(d$copy_of[cp], paste0(d$source, ":", d$feature_key))
port[cp] <- port[orig]
outcome[cp] <- ifelse(is.na(port[orig]), "flagged", "duplicate")
how[cp] <- paste0("copy of ", d$copy_of[cp], ifelse(is.na(port[orig]), ", which is flagged", ""))
# a GFW dock anchorage takes its dock area's outcome and site
pk <- match(d$part_of, d$feature_key[d$source == "gfw_dock"])
da <- which(!is.na(d$part_of))
dk <- which(d$source == "gfw_dock")[pk[da]]
port[da] <- port[dk]
outcome[da] <- outcome[dk]
how[da] <- paste0("in GFW dock area ", d$feature_key[dk], ": ", how[dk])
stopifnot("every feature has an outcome" = !anyNA(outcome), "every outcome has a reason" = !anyNA(how))

# The sites -----------------------------------------------------------------------------------------------------------
A <- which(anchor)
pins <- read.csv("overrides/port_pid_pinned.csv", colClasses = "character")
sites <- d[A, ] |>
  transmute(anchor_id = id, site_key = paste0(source, ":", feature_key), anchor_source = source, anchor_key = feature_key,
            anchor_kind = kind, iso = coalesce(if_else(source == "einar", substr(feature_key, 1, 2), NA_character_), iso_geo, iso_src),
            geom_type = gtype, hid, area_m2, on_land, d_coast_km)
sites$basis <- unname(bs[as.character(sites$anchor_id)])
sites$pid_acronym <- pins$pid[match(sites$anchor_key, pins$pid_bootstrap)]
sites$pid_acronym[sites$anchor_source != "einar"] <- NA
# the name by the same cascade: the anchor's, else the first named member by rank
mem <- tibble(id = d$id, port = port, source = d$source, name = d$name, rank = RANK[d$source]) |>
  filter(!is.na(port), !is.na(name), nchar(name) > 0, source %in% names(RANK)) |>
  arrange(port, id != port, rank, id)
nm1 <- mem |> distinct(port, .keep_all = TRUE)
sites$name <- nm1$name[match(sites$anchor_id, nm1$port)]
sites$name_from <- nm1$source[match(sites$anchor_id, nm1$port)]
# the lists that agree (the families of evidence; a joined small landing is counted apart)
agree <- tibble(port = port, family = d$family, outcome = outcome) |> filter(!is.na(port)) |>
  group_by(port) |>
  summarise(lists = paste(sort(unique(family[outcome != "joined"])), collapse = ","), n_features = n(),
            n_joined = sum(outcome == "joined"), .groups = "drop")
sites <- sites |> left_join(agree, by = c("anchor_id" = "port"))
sites$lists[sites$anchor_source == "gfw_dock"] <- paste0(sites$lists[sites$anchor_source == "gfw_dock"], ",gfw_label")
sites$n_lists <- lengths(strsplit(sites$lists, ","))

# The number, from the ledger (R/allocate_ports.R; its key column, named before step 6, is `port_key`); NA until allocated
led <- read_port_ledger()
sites$pid <- led$pid[match(sites$site_key, led$port_key)]
sites$pid_acronym <- coalesce(sites$pid_acronym, led$pid_acronym[match(sites$site_key, led$port_key)])
cat("sites", nrow(sites), " numbered", sum(!is.na(sites$pid)), "\n"); print(table(sites$basis))
sites <- sites |> select(pid, pid_acronym, site_key, name, name_from, iso, basis, geom_type, lists, n_lists, n_features,
                         n_joined, anchor_source, anchor_key, anchor_kind, hid, area_m2, on_land, d_coast_km, anchor_id)
layer <- st_sf(sites, geom = st_geometry(feat)[sites$anchor_id])

# Every feature, one outcome; einar whole; no two areas overlap, but small landings' among themselves (ask m)
stopifnot(
  "one anchor per site" = setequal(which(anchor), sites$anchor_id),
  "every einar harbour is a site of its own" = HOLD_OUT == "einar" ||
    setequal(sites$anchor_key[sites$anchor_source == "einar"], d$feature_key[d$source == "einar"]),
  "site keys unique" = !anyDuplicated(sites$site_key))
areas <- layer[layer$geom_type == "area", ]
ov <- st_overlaps(st_transform(areas, 3035))
ovp <- data.frame(a = rep(seq_along(ov), lengths(ov)), b = unlist(ov))
ovp <- ovp[!(areas$anchor_source[ovp$a] == LANDING & areas$anchor_source[ovp$b] == LANDING), ]
if (nrow(ovp)) print(head(data.frame(a = areas$site_key[ovp$a], b = areas$site_key[ovp$b]), 20))
stopifnot("no two sites' areas overlap, but small landings' among themselves" = nrow(ovp) == 0)

d$outcome <- outcome
d$reason <- how
d$site_key <- sites$site_key[match(port, sites$anchor_id)]
d$pid <- sites$pid[match(port, sites$anchor_id)]
d$dist_m <- round(dist_to)
cat("outcomes\n"); print(table(d$source, d$outcome))

feat_out <- st_sf(d |> select(source, feature_key, derived, part_of, name, iso_src, iso_geo, locode, kind, gtype, repaired,
                              family, outcome, reason, site_key, pid, dist_m, lon, lat, d_coast_km),
                  geom = st_geometry(feat))
if (TEST) {
  dir <- Sys.getenv("LANDING_SITE_TEST_DIR")
  stopifnot("a test writes to a folder of its own, never curated/" = nzchar(dir), !grepl("/curated/", dir), nzchar(TAG),
            TAG != "without_")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(layer, file.path(dir, paste0("landing_site_", TAG, ".rds")))
  saveRDS(feat_out, file.path(dir, paste0("landing_site_feature_", TAG, ".rds")))
} else {
  inputs <- c(FEATURES, "overrides/port_pid_pinned.csv", port_ledger_files())
  write_curated(layer |> select(-anchor_id), fd_curated("reference", "landing_site.parquet"), inputs = inputs)
  write_curated(feat_out, fd_curated("reference", "landing_site_feature.parquet"), inputs = inputs)
}
