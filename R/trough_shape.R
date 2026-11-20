# trough_shape.R — a trough's shape, and the deepest point of an outline: plan 081 step 1's rules (decision 338), moved here
# from reference/names/place_name_proposal.R on 2026-11-20 so that the landscape frame (reference/seabed/landscape_frame.R,
# plan 081 §7 step 3) uses them without a copy; marine_name.R's own copy of deepest_in() replaced by this one.
# Functions only. Each takes its depth raster as an argument (the Olex model aggregated: 200 m cells for deepest_in(), 1 km
# for trough_parts()), so nothing global is read.

# The deepest 200 m cell (its centre inside) within the outline's largest inscribed circle: deep, central, and away from a
# trough's mouth on the slope, where the deepest cell of the whole outline lies for 16 of 40 (Claude's choice of three tried,
# 2026-11-20: the deepest cell anywhere, the circle's centre, this; the circle is the outline's own, no distance chosen).
# Returns c(lon, lat, depth in m).
deepest_in <- function(g, dem4) {
  g3 <- sf::st_union(sf::st_transform(sf::st_geometry(g), 3057)); ic <- sf::st_inscribed_circle(g3, dTolerance = 50)[1]
  a <- sf::st_intersection(ic, g3); v <- terra::vect(sf::st_transform(a, terra::crs(dem4)))
  r <- terra::mask(terra::crop(dem4, v, snap = "out"), v, touches = FALSE); c <- which.min(terra::values(r))
  p <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_point(terra::xyFromCell(r, c)[1, ]), crs = terra::crs(dem4)), 4326))
  c(p[1], p[2], -terra::values(r)[c])
}

# Cells reached in `ord`; a set is led by its cell of largest `key`; a lesser set ends where it meets.
trough_flood <- function(ord, key, rc, idx, nr, nc) {
  NB <- cbind(c(-1, -1, -1, 0, 0, 1, 1, 1), c(-1, 0, 1, -1, 1, -1, 0, 1))
  par <- seq_along(key); lead <- seq_along(key); seen <- logical(length(key)); lab <- rep(NA_integer_, length(key))
  ends <- data.frame(tip = integer(), meet = integer(), into = integer())
  find <- function(i) { while (par[i] != i) { par[i] <<- par[par[i]]; i <- par[i] }; i }
  for (i in ord) { seen[i] <- TRUE
    rr <- rc[i, 1] + NB[, 1]; cc <- rc[i, 2] + NB[, 2]; ok <- rr >= 1 & rr <= nr & cc >= 1 & cc <= nc
    nb <- idx[(rr[ok] - 1) * nc + cc[ok]]; nb <- nb[!is.na(nb)]; nb <- nb[seen[nb]]
    for (j in nb) { a <- find(i); b <- find(j); if (a == b) next
      la <- lead[a]; lb <- lead[b]
      if (key[la] < key[lb] || (key[la] == key[lb] && la == i)) { t0 <- a; a <- b; b <- t0; t0 <- la; la <- lb; lb <- t0 }   # a tie: the cell just reached joins
      if (lb != i) ends[nrow(ends) + 1, ] <- list(lb, i, la)
      par[b] <- a; lead[a] <- la }
    lab[i] <- lead[find(i)] }
  list(lab = lab, ends = ends)
}

# A trough split by its own shape, on 1 km cells: its arms (branches of the distance-from-deepest flood longer than the
# trough is half wide near where they join) and its main line cut at the junctions. Returns the cells with their part
# (`b<n>` an arm by its tip, west to east; `b<n>.<k>` a piece of the main line), the raster and the arms.
trough_parts <- function(g, dem20) {
  g5 <- terra::vect(sf::st_transform(sf::st_geometry(g), terra::crs(dem20)))
  v <- terra::mask(terra::crop(dem20, terra::ext(g5) + 3000, snap = "out"), g5, touches = FALSE)
  cells <- which(!is.na(terra::values(v, mat = FALSE))); z <- -terra::values(v, mat = FALSE)[cells]
  nr <- terra::nrow(v); nc <- terra::ncol(v); rc <- terra::rowColFromCell(v, cells)
  idx <- rep(NA_integer_, terra::ncell(v)); idx[cells] <- seq_along(cells)
  root <- which.max(z); mk <- v; mk[!is.na(mk)] <- 1; mk[cells[root]] <- 0
  dist <- terra::values(terra::gridDist(mk, target = 0), mat = FALSE)[cells] / 1000; dist[!is.finite(dist)] <- NA
  reach <- which(!is.na(dist)); main <- reach[which.max(dist[reach])]
  fl <- trough_flood(reach[order(-dist[reach])], ifelse(is.na(dist), -Inf, dist), rc, idx, nr, nc)
  br <- fl$ends; br$length <- dist[br$tip] - dist[br$meet]; br <- br[order(-br$length), ]
  # an arm: a branch longer than the trough is half wide near where it joins (the largest distance to the outline's edge
  # among the cells within one branch length of the junction, not its own): a shorter one is a bump on the body it joins.
  # Tried against the largest drop in the sorted lengths, which a 500 m shift of the grid flipped for trough 10 (decision 338)
  xy0 <- terra::xyFromCell(v, cells); out0 <- v; out0[] <- 1; out0[cells] <- NA
  dt <- terra::values(terra::distance(out0), mat = FALSE)[cells] / 1000
  br$half <- rep(NA_real_, nrow(br))                                               # (a trough with no branch has none)
  for (i in which(br$length > 1)) { d <- sqrt((xy0[, 1] - xy0[br$meet[i], 1])^2 + (xy0[, 2] - xy0[br$meet[i], 2])^2) / 1000
    br$half[i] <- max(dt[d <= br$length[i] & fl$lab != br$tip[i]]) }
  arms <- br$tip[!is.na(br$half) & br$length > br$half]; n_arm <- length(arms)
  keep <- c(main, arms); up <- setNames(br$into, br$tip)
  top <- function(b) { while (!(b %in% keep)) b <- up[[as.character(b)]]; b }
  arm <- rep(NA_integer_, length(cells)); arm[reach] <- vapply(fl$lab[reach], top, 1L)
  xy <- terra::xyFromCell(v, cells)
  if (length(miss <- which(is.na(arm)))) { r0 <- reach[vapply(miss, function(m) which.min((xy[reach, 1] - xy[m, 1])^2 + (xy[reach, 2] - xy[m, 2])^2), 1L)]; arm[miss] <- arm[r0]; dist[miss] <- dist[r0] }
  ll <- sf::st_coordinates(sf::st_transform(sf::st_as_sf(data.frame(x = xy[, 1], y = xy[, 2]), coords = 1:2, crs = terra::crs(dem20)), 4326))
  lab <- setNames(paste0("b", rank(ll[keep, 1], ties.method = "first")), keep)            # the arms by their tips, west to east
  part <- unname(lab[as.character(arm)])
  onm <- arms[vapply(br$into[match(arms, br$tip)], top, 1L) == main]   # the arms meeting the main line
  cuts <- c(-Inf, sort(dist[br$meet[match(onm, br$tip)]]), Inf); m <- arm == main
  if (length(cuts) > 2) part[m] <- paste0(lab[as.character(main)], ".", findInterval(dist[m], cuts))
  cl <- data.frame(cell = cells, lon = ll[, 1], lat = ll[, 2], x = xy[, 1], y = xy[, 2], z = z, part = part)
  list(v = v, idx = idx, cells = cl, arms = data.frame(tip = keep, part = unname(lab), length = c(dist[main], br$length[match(keep[-1], br$tip)])), n_arm = n_arm)
}

# The outline (EPSG:4326) of a trough's cells `keep` (indices into tp$cells).
trough_cells_poly <- function(tp, keep) {
  r <- tp$v; r[] <- NA; r[tp$cells$cell[keep]] <- 1
  sf::st_union(sf::st_make_valid(sf::st_as_sf(terra::as.polygons(r, dissolve = TRUE)))) |> sf::st_transform(4326)
}
