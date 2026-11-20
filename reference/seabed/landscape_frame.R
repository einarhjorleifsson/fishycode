# landscape_frame.R — the coarsest level of the shelf's landscape: the deeps, their lines, the two volcanic ridges and the
# grounds between, with no gap (plan 081 §4.6 and §7 step 3; decision 341; the maintainer, 2026-11-20: "Yes, keep them",
# "Start the frame's build"). A layer beside ÍSOR's own (plan 081 objective 2); no name enters a rule.
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow, after reference/seabed/
# seabed_feature.R (and, for the witnesses a piece stands by, reference/names/marine_name.R).
#
# The rule, as adopted ("Yes, keep them") and tested (decision 341; the study 2026-11-20-proposal-banks, scripts 11-17):
# - the shelf: inside ÍSOR's shelf break, less Iceland (the mainland, the one void; an island where the depth model is above
#   the sea), on 500 m cells of the Olex depth model;
# - the deeps: ÍSOR's troughs. Each trough is split by its own shape (trough_parts(), R/trough_shape.R: plan 081 step 1's
#   rule), and each arm (its parts on one branch) gets a line: from the arm's deepest point (deepest_in()) up the arm to its
#   head, the arm's point nearest the mainland, on by the cheapest route (cost 1 / (1 + depth / 50 m)) to the mainland's
#   coast, and seaward by the cheapest route out of the shelf. One exception, the maintainer's word: trough 16's line is not
#   drawn ("Drop it", of Norðfjarðardjúp's line, 2026-11-20, decision 341);
# - the ridges, elements of their own ("They are an element of their own, even on a global model, this separates the
#   American and the Eurasian tectonic plates"): each crest the longest path of the minimum spanning tree of ÍSOR's craters,
#   guyots and points in its region, carried on to the land and out of the shelf; its area its volcanic systems and a
#   corridor along the crest as wide as the craters' median spacing on the tree. The Reykjanes Ridge's region is
#   place_name_region's; the Kolbeinsey Ridge's the box 21-15.5 W, 65.9-68.2 N and ÍSOR's systems Mánáreyjar, Nafir, Hóllinn,
#   Stóragrunn and Skjálfandadjúp (the Tjörnes zone's chain, decision 341). A ridge's cell is the ridge's, a trough's under it
#   too;
# - the grounds: the rest, cut by the lines into pieces. A piece stands as a ground where a name belongs to it (plan 081
#   §4.6, in place of the floor tried in the study): the charts letter a bank in it (-grunn or -banki at 1:300 000 or
#   coarser), or a skippers' name of two vessels or more has most of its own tows in it, or one of LMÍ's named water areas
#   lies mostly in it and covers most of it. A piece no name belongs to joins the neighbour it borders most, else the nearest
#   ground on its own side of the crests; no ground lies on both sides. Numbered clockwise round Iceland from the south-west.
#
# Input:  curated/reference/seabed_feature.parquet (ÍSOR's shelf break, troughs, volcanic systems, craters, guyots, points);
#         raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif; raw/external/is50v/strandlina_flakar.json (the coast, the
#         mainland its largest polygon); curated/reference/place_name_region.parquet (the Reykjanes Ridge's region); the
#         witnesses a piece stands by: the named-features study's frozen version 1 (its letterings.csv, the charts'),
#         staging/ornefni/trackwell_haul.parquet (the skippers'), curated/reference/marine_name.parquet and
#         marine_name_extent.parquet (LMÍ's named areas)
# Output: curated/reference/landscape_element.parquet - one row an element: `element` ("deep:<trough>", "ridge:<name>",
#           "ground:<nn>"), `kind`, `label`, `side` (the plate's side, west or east; none for a ridge), `km2`, `basis`, `banks`
#           (the charts' banks lettered in it), WKB `geometry` (EPSG:4326)
#         curated/reference/landscape_line.parquet - one row a line: `line` ("arm:<trough>:<arm>", "crest:<ridge>"), `kind`,
#           `trough`, `arm`, the thing (`lon`, `lat`, `depth_m`), the head (`head_lon`, `head_lat`, `head_km` from the
#           mainland), the landing (`coast_lon`, `coast_lat`), `km` (thing to coast), WKB `geometry` (EPSG:4326)
#         curated/reference/landscape_piece.parquet - one row a piece the lines cut: `piece`, `km2`, `lon`, `lat`, `side`,
#           `outcome` (a ground by a chart bank, by the skippers' name, by a named area; joined to its neighbour; joined to
#           the nearest on its side), `witness`, `element` (the ground it is in)
#         curated/reference/landscape_cell.parquet - one row a cell of the shelf: `cell` (the 500 m grid's), `x`, `y` (the
#           depth model's CRS, in fd.crs), `element`, `piece`
# Checked by curate/checks/landscape_frame_accounting.R. Run from the repo root: Rscript reference/seabed/landscape_frame.R
# Written by Claude (AI), 2026-11-20; no person has checked it.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R", "R/trough_shape.R")) source(f)   # standalone: not targets'
SCRIPT <- "reference/seabed/landscape_frame.R"; VERSION <- "081.3a"
REF <- function(f) fd_curated("reference", f)
DEMF <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif"); COASTF <- fd_raw("external", "is50v", "strandlina_flakar.json")
V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1"); LETF <- file.path(V1, "letterings.csv")
TWF <- fd_staging("ornefni", "trackwell_haul.parquet")
INPUTS <- c(REF("seabed_feature.parquet"), DEMF, COASTF, REF("place_name_region.parquet"), LETF, TWF, REF("marine_name.parquet"), REF("marine_name_extent.parquet"))
DROP <- c("16" = "trough 16's line not drawn: the maintainer, 2026-11-20, of Norðfjarðardjúp's line, \"Drop it\" (decision 341)")
RIDGE_SYSTEMS_N <- c("Mánáreyjar", "Nafir", "Hóllinn", "Stóragrunn", "Skjálfandadjúp")
NBOX <- c(xmin = -21, xmax = -15.5, ymin = 65.9, ymax = 68.2)

# The grid ----------------------------------------------------------------------------------------------------------------
sfx <- read_curated_sf(REF("seabed_feature.parquet"))
shelf <- st_union(st_make_valid(sfx[sfx$kind == "shelf break", ])); BOX3 <- st_as_sfc(st_bbox(st_buffer(st_transform(shelf, 3057), 10000)))
dem <- terra::rast(DEMF); cr <- terra::crs(dem); dem4 <- terra::aggregate(dem, 4); dem20 <- terra::aggregate(dem, 20)
d5 <- terra::aggregate(terra::crop(dem, terra::vect(st_transform(BOX3, cr))), 10); z <- -terra::values(d5, mat = FALSE); nc5 <- terra::ncol(d5); nr5 <- terra::nrow(d5)
xy <- terra::xyFromCell(d5, seq_len(terra::ncell(d5)))
coast <- st_union(st_make_valid(st_read(COASTF, quiet = TRUE)))
rz <- function(g, touches = FALSE) !is.na(terra::values(terra::rasterize(terra::vect(st_transform(g, cr)), d5, touches = touches), mat = FALSE))
# Iceland the one void (the maintainer, 2026-11-20: "You may have to add \"Iceland\" as a void here"): the mainland is the land;
# an island is land only where the depth model says so, for at 500 m the islands' outlines closed inner Breiðafjörður's water
# off into small patches
mp <- st_cast(st_collection_extract(st_make_valid(coast), "POLYGON"), "POLYGON"); mainland <- mp[which.max(as.numeric(st_area(st_transform(mp, 3057))))]
in_shelf <- rz(shelf); land <- rz(mainland, TRUE); sea <- is.finite(z) & z > 0 & !land; dom <- sea & in_shelf
land_main <- land
nb4 <- function(mask, dr, dc) { r <- (seq_along(mask) - 1) %/% nc5 + 1; c <- (seq_along(mask) - 1) %% nc5 + 1; r2 <- r + dr; c2 <- c + dc
  ok <- r2 >= 1 & r2 <= nr5 & c2 >= 1 & c2 <= nc5; out <- rep(FALSE, length(mask)); out[ok] <- mask[(r2[ok] - 1) * nc5 + c2[ok]]; out }
coastal <- sea & (nb4(land_main, -1, 0) | nb4(land_main, 1, 0) | nb4(land_main, 0, -1) | nb4(land_main, 0, 1))   # the sea beside the mainland
message(sprintf("the shelf: %.0f km2 of sea on %d cells of 500 m", sum(dom) * .25, sum(dom)))

# The cheapest route on the grid, to a point or to a set of cells ------------------------------------------------------
cost <- 1 / (1 + pmax(z, 0) / 50)
route <- function(from, to = NULL, stop_set = NULL) {
  w <- if (is.null(stop_set)) { pts <- rbind(from, to); c(min(pts[, 1]) - 40000, max(pts[, 1]) + 40000, min(pts[, 2]) - 40000, max(pts[, 2]) + 40000) } else
    c(from[1] - 150000, from[1] + 150000, from[2] - 150000, from[2] + 150000)
  cc <- which(xy[, 1] >= w[1] & xy[, 1] <= w[2] & xy[, 2] >= w[3] & xy[, 2] <= w[4] & sea)
  idx <- rep(NA_integer_, length(z)); idx[cc] <- seq_along(cc); rr <- (cc - 1) %/% nc5 + 1; co <- (cc - 1) %% nc5 + 1
  ed <- do.call(rbind, lapply(list(c(0, 1), c(1, 0), c(1, 1), c(1, -1)), function(o) { r2 <- rr + o[1]; c2 <- co + o[2]; ok <- r2 >= 1 & r2 <= nr5 & c2 >= 1 & c2 <= nc5
    b <- (r2[ok] - 1) * nc5 + c2[ok]; a <- cc[ok]; k <- !is.na(idx[b]); cbind(idx[a[k]], idx[b[k]], sqrt(sum(o^2)) * (cost[a[k]] + cost[b[k]]) / 2) }))
  n <- length(cc); sink <- n + 1
  if (!is.null(stop_set)) ed <- rbind(ed, cbind(which(stop_set[cc]), sink, 0))
  gr <- igraph::add_edges(igraph::make_empty_graph(n = n + 1, directed = FALSE), t(ed[, 1:2]), weight = ed[, 3])
  near <- function(q) which.min((xy[cc, 1] - q[1])^2 + (xy[cc, 2] - q[2])^2)
  a <- near(from); b <- if (is.null(stop_set)) near(to) else sink
  p <- as.integer(igraph::shortest_paths(gr, a, b, output = "vpath")$vpath[[1]]); p <- p[p <= n]
  if (!length(p)) stop("no route from ", paste(round(from), collapse = " "))
  xy[cc[p], , drop = FALSE] }
proj <- function(lon, lat) st_coordinates(st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), cr))[1, 1:2]
unproj <- function(p) st_coordinates(st_transform(st_sfc(st_point(p), crs = cr), 4326))[1, 1:2]
cell_at <- function(q) terra::cellFromXY(d5, matrix(q, 1))
walk <- function(p0, dir, stop_fn, max_km = 100) { dir <- dir / sqrt(sum(dir^2)); pts <- p0
  for (k in seq_len(max_km * 2)) { q <- p0 + dir * 500 * k; pts <- rbind(pts, q); if (stop_fn(q)) return(pts) }; pts }
off_shelf <- sea & !in_shelf

# The deeps and their arms' lines ------------------------------------------------------------------------------------------
tr <- st_transform(sfx[sfx$kind == "trough", ], 3057); tr$t <- sub("isor:landform:trough:", "", tr$seabed_id); tr <- tr[order(as.integer(tr$t)), ]
deep <- dom & rz(tr); deep_of <- rep(NA_character_, length(z))
for (i in seq_len(nrow(tr))) deep_of[dom & rz(tr[i, ])] <- tr$t[i]
L <- list(); LT <- list()
for (i in seq_len(nrow(tr))) { tt <- tr$t[i]; tp <- trough_parts(tr[i, ], dem20); arm <- sub("\\..*$", "", tp$cells$part)
  for (a in sort(unique(arm))) {
    pg <- trough_cells_poly(tp, which(arm == a)); q <- deepest_in(st_sf(geometry = pg), dem4); from <- proj(q[1], q[2])
    np <- st_nearest_points(st_transform(pg, cr), st_transform(mainland, cr)); head <- st_coordinates(np)[1, 1:2]; head_km <- as.numeric(st_length(np)) / 1000
    if (tt %in% names(DROP)) { message("trough ", tt, " arm ", a, ": ", DROP[[tt]]); next }
    land_route <- rbind(route(from, head), route(head, stop_set = coastal)[-1, , drop = FALSE]); sea_route <- route(from, stop_set = off_shelf)
    full <- rbind(sea_route[nrow(sea_route):1, , drop = FALSE], land_route[-1, , drop = FALSE]); e <- unproj(land_route[nrow(land_route), ]); hll <- unproj(head)
    L[[length(L) + 1]] <- st_sf(line = sprintf("arm:%s:%s", tt, a), geometry = st_sfc(st_linestring(full), crs = cr))
    LT[[length(LT) + 1]] <- data.frame(line = sprintf("arm:%s:%s", tt, a), kind = "a deep's arm", trough = tt, arm = a, lon = q[1], lat = q[2], depth_m = round(q[3]),
      head_lon = hll[1], head_lat = hll[2], head_km = round(head_km, 2), coast_lon = e[1], coast_lat = e[2], km = round(sum(sqrt(rowSums(diff(land_route)^2))) / 1000, 1)) } }
message(sprintf("the deeps: %d troughs, %d arms' lines", nrow(tr), length(L)))

# The ridges ---------------------------------------------------------------------------------------------------------------
rgn <- st_transform(read_curated_sf(REF("place_name_region.parquet")), 4326)
vsa <- sfx[sfx$kind == "volcanic system", ]; cra <- sfx[sfx$kind %in% c("crater", "guyot", "point"), ]
REG <- list(Reykjaneshryggur = st_union(rgn[rgn$region == "reykjaneshryggur", ]), Kolbeinseyjarhryggur = st_as_sfc(st_bbox(NBOX, crs = 4326)))
SYS <- list(Reykjaneshryggur = vsa[lengths(st_intersects(st_make_valid(vsa), REG$Reykjaneshryggur)) > 0, ], Kolbeinseyjarhryggur = vsa[vsa$label %in% RIDGE_SYSTEMS_N, ])
stopifnot(nrow(SYS$Kolbeinseyjarhryggur) == length(RIDGE_SYSTEMS_N), nrow(SYS$Reykjaneshryggur) > 0)
on_land <- function(q) { k <- cell_at(q); !is.na(k) && land[k] }; out_shelf <- function(q) { k <- cell_at(q); is.na(k) || !in_shelf[k] }
RP <- list(); RT <- list()
for (rn in names(REG)) { cc <- cra[lengths(st_intersects(cra, REG[[rn]])) > 0, ]
  p3 <- st_coordinates(st_transform(cc, cr))[, 1:2]; gt <- igraph::mst(igraph::graph_from_adjacency_matrix(as.matrix(dist(p3)), mode = "undirected", weighted = TRUE))
  dd <- igraph::distances(gt); ij <- which(dd == max(dd), arr.ind = TRUE)[1, ]; path <- as.integer(igraph::shortest_paths(gt, ij[1], ij[2])$vpath[[1]])
  vp <- p3[path, , drop = FALSE]; w <- median(igraph::E(gt)$weight)
  dl <- function(q) as.numeric(st_distance(st_sfc(st_point(q), crs = cr), st_transform(coast, cr)))   # from the end nearer the land
  if (dl(vp[1, ]) > dl(vp[nrow(vp), ])) vp <- vp[nrow(vp):1, ]
  c_end <- if (on_land(vp[1, ])) vp[1, , drop = FALSE] else walk(vp[1, ], vp[1, ] - vp[min(3, nrow(vp)), ], on_land)
  o_end <- if (out_shelf(vp[nrow(vp), ])) vp[nrow(vp), , drop = FALSE] else walk(vp[nrow(vp), ], vp[nrow(vp), ] - vp[max(1, nrow(vp) - 2), ], out_shelf, max_km = 200)
  crest <- rbind(c_end[nrow(c_end):1, , drop = FALSE], vp[-c(1, nrow(vp)), , drop = FALSE], o_end)
  id <- paste0("crest:", tolower(rn))
  L[[length(L) + 1]] <- st_sf(line = id, geometry = st_sfc(st_linestring(crest), crs = cr))
  e <- unproj(crest[1, ])
  RT[[length(RT) + 1]] <- data.frame(line = id, kind = "a ridge's crest", trough = NA_character_, arm = NA_character_, lon = NA_real_, lat = NA_real_, depth_m = NA_real_,
    head_lon = NA_real_, head_lat = NA_real_, head_km = NA_real_, coast_lon = e[1], coast_lat = e[2], km = round(as.numeric(st_length(st_sfc(st_linestring(crest), crs = cr))) / 1000, 1))
  RP[[rn]] <- st_sf(element = paste0("ridge:", tolower(rn)), label = rn, n_craters = length(path), spacing_km = round(w / 1000, 2),
    systems = paste(SYS[[rn]]$label, collapse = ", "), geometry = st_union(c(st_union(st_make_valid(st_transform(SYS[[rn]], cr))), st_buffer(st_sfc(st_linestring(vp), crs = cr), w))))
  message(sprintf("%s: its crest through %d of %d craters (%.0f km), spacing %.1f km, %d systems", rn, length(path), nrow(cc), as.numeric(st_length(st_sfc(st_linestring(crest), crs = cr))) / 1000, w / 1000, nrow(SYS[[rn]]))) }
lines <- do.call(rbind, L); LT <- bind_rows(c(LT, RT)); RP <- do.call(rbind, RP)
ridge_of <- rep(NA_character_, length(z)); for (i in seq_len(nrow(RP))) ridge_of[dom & rz(RP[i, ])] <- RP$element[i]

# The cover: a ridge's cell first, then a deep's, the rest the grounds' ---------------------------------------------------
cut <- rz(lines, TRUE); crest_cut <- rz(lines[startsWith(lines$line, "crest:"), ], TRUE)
el <- ifelse(!dom, NA_character_, ifelse(!is.na(ridge_of), ridge_of, ifelse(!is.na(deep_of), paste0("deep:", deep_of), "ground")))
r <- d5; terra::values(r) <- ifelse(el %in% "ground" & !cut, 1, NA); g <- terra::values(terra::patches(r, directions = 4), mat = FALSE)
fill <- which(el %in% "ground" & is.na(g)); have <- which(!is.na(g))                         # a line's cells to the nearest piece
if (length(fill)) g[fill] <- g[have][RANN::nn2(xy[have, ], xy[fill, , drop = FALSE], k = 1)$nn.idx[, 1]]
piece0 <- g
rs <- d5; terra::values(rs) <- ifelse(dom & is.na(ridge_of) & !crest_cut, 1, NA); side <- terra::values(terra::patches(rs, directions = 4), mat = FALSE)
two <- as.integer(names(sort(table(side), decreasing = TRUE))[1:2])                          # the two sides: the plates
wpt <- terra::cellFromXY(d5, matrix(proj(-24.5, 66.3), 1)); sc <- which(side %in% two)       # the west's, off the Westfjords
if (side[sc][RANN::nn2(xy[sc, ], xy[wpt, , drop = FALSE], k = 1)$nn.idx[1, 1]] != two[1]) two <- rev(two)
# a cell in a small patch (inner fjords the islands close off at 500 m, a line's or a crest's cell) takes the side of the
# nearest cell of the two sides, so that no piece joins across a ridge
main <- which(side %in% two); side2 <- ifelse(side %in% two, side, NA); fillc <- which(dom & is.na(ridge_of) & is.na(side2))
if (length(fillc)) side2[fillc] <- side[main][RANN::nn2(xy[main, ], xy[fillc, , drop = FALSE], k = 1)$nn.idx[, 1]]
side_name <- ifelse(side2 %in% two[1], "west", ifelse(side2 %in% two[2], "east", NA))

# The witnesses a piece stands by ------------------------------------------------------------------------------------------
nm <- as.data.frame(nanoparquet::read_parquet(REF("marine_name.parquet")))
lt <- read.csv(LETF, encoding = "UTF-8"); lt <- lt[lt$feature %in% nm$id[nm$kind == "water"] & grepl("(grunn|banki)$", tolower(lt$name)) &
  lt$chart %in% c("sjokort_2milljon", "sjokort_1milljon", "sjokort_300thusund") & !grepl("^[A-ZÁÉÍÓÚÝÞÆÖÐ ]+$", lt$name), ]
lt$cell <- terra::cellFromXY(d5, st_coordinates(st_transform(st_as_sf(lt, coords = c("lon", "lat"), crs = 4326), cr)))
fold <- function(x) gsub("(.)\\1+", "\\1", gsub("[^a-z0-9]", "", tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))))
tw <- as.data.frame(nanoparquet::read_parquet(TWF)) |> filter(!name_placeholder, !time_suspect, !is.na(lon1), !is.na(lon2), !is.na(name)) |>
  mutate(k = fold(name), lon = (lon1 + lon2) / 2, lat = (lat1 + lat2) / 2)
tw$cell <- terra::cellFromXY(d5, st_coordinates(st_transform(st_as_sf(tw, coords = c("lon", "lat"), crs = 4326), cr))); tw$piece <- g[tw$cell]
n_all <- tw |> count(k, name = "n_all")
sk <- tw |> filter(!is.na(piece)) |> group_by(piece, k) |> summarise(n = n(), v = n_distinct(vid), name = names(sort(table(name), decreasing = TRUE))[1], .groups = "drop") |>
  left_join(n_all, by = "k") |> filter(v >= 2, n / n_all > 0.5) |> arrange(piece, desc(n))
pc <- terra::as.polygons({ rp <- d5; terra::values(rp) <- g; rp }, dissolve = TRUE); PC <- st_as_sf(pc); names(PC)[1] <- "piece"; PC <- st_make_valid(st_transform(PC, 3057))
PC$km2 <- as.numeric(st_area(PC)) / 1e6
ex <- read_curated_sf(REF("marine_name_extent.parquet")); ex <- ex[startsWith(ex$basis, "LMÍ's") & ex$feature %in% nm$id[nm$kind == "water"] &
  as.character(st_geometry_type(ex)) %in% c("POLYGON", "MULTIPOLYGON"), ]
ex <- st_make_valid(st_transform(ex, 3057)); ex$a <- as.numeric(st_area(ex)); ex <- ex[ex$a > 0, ]; ex$name <- nm$name[match(ex$feature, nm$id)]
hit <- st_intersects(PC, ex); na_txt <- character(nrow(PC))
for (i in which(lengths(hit) > 0)) { e <- ex[hit[[i]], ]; pg <- st_geometry(PC[i, ])
  ai <- vapply(seq_len(nrow(e)), function(j) { a <- suppressWarnings(st_area(st_intersection(st_geometry(e)[j], pg))); if (length(a)) sum(as.numeric(a)) else 0 }, 0)
  ok <- ai / e$a > 0.5 & ai / (PC$km2[i] * 1e6) > 0.5; if (any(ok)) na_txt[i] <- paste(unique(e$name[ok]), collapse = ", ") }
P <- st_drop_geometry(PC) |> mutate(
  bank = vapply(piece, function(k) paste(unique(lt$name[!is.na(lt$cell) & g[lt$cell] %in% k]), collapse = ", "), ""),
  skippers = vapply(piece, function(k) { s <- sk[sk$piece == k, ]; paste(sprintf("%s (%d tows, %.0f %% of its own, %d vessels)", s$name, s$n, 100 * s$n / s$n_all, s$v), collapse = "; ") }, ""),
  area = na_txt[match(piece, PC$piece)],
  outcome = case_when(nzchar(bank) ~ "a ground: the charts letter a bank in it", nzchar(skippers) ~ "a ground: a skippers' name has most of its tows in it",
                      nzchar(area) ~ "a ground: an LMÍ named area lies mostly in it and covers most of it", TRUE ~ NA_character_),
  witness = case_when(nzchar(bank) ~ bank, nzchar(skippers) ~ skippers, nzchar(area) ~ area, TRUE ~ NA_character_))
stands <- P$piece[!is.na(P$outcome)]
message(sprintf("pieces: %d; standing: %d (by a chart bank %d, by the skippers %d, by an LMÍ area %d)", nrow(P), length(stands), sum(nzchar(P$bank)),
  sum(!nzchar(P$bank) & nzchar(P$skippers)), sum(!nzchar(P$bank) & !nzchar(P$skippers) & nzchar(P$area))))

# The rest join: the neighbour each borders most, again until none borders a ground; then the nearest on its own side -----
joined <- setNames(rep(NA_character_, nrow(P)), P$piece)
repeat { ids <- sort(unique(na.omit(g))); sl <- setdiff(ids, stands); if (!length(sl)) break; done <- FALSE
  for (k in sl) { cells <- which(g == k); rr <- (cells - 1) %/% nc5 + 1; co <- (cells - 1) %% nc5 + 1
    nb <- c(ifelse(rr > 1, cells - nc5, NA), ifelse(rr < nr5, cells + nc5, NA), ifelse(co > 1, cells - 1, NA), ifelse(co < nc5, cells + 1, NA))
    o <- g[nb[!is.na(nb)]]; o <- o[!is.na(o) & o != k]; if (!length(o)) next
    into <- as.integer(names(which.max(table(o)))); g[cells] <- into; done <- TRUE
    for (p0 in unique(piece0[cells])) if (is.na(joined[as.character(p0)])) joined[as.character(p0)] <- "joined: the neighbour it borders most" }
  if (!done) break }
for (k in setdiff(sort(unique(na.omit(g))), stands)) { cells <- which(g == k); hv <- which(g %in% stands & side2 %in% unique(side2[cells])); if (!length(hv)) hv <- which(g %in% stands)
  into <- as.integer(names(which.max(table(g[hv][RANN::nn2(xy[hv, ], xy[cells, , drop = FALSE], k = 1)$nn.idx[, 1]])))); g[cells] <- into
  for (p0 in unique(piece0[cells])) if (is.na(joined[as.character(p0)])) joined[as.character(p0)] <- "joined: the nearest ground on its side" }

# The grounds, numbered clockwise from the south-west -----------------------------------------------------------------------
gr <- d5; terra::values(gr) <- g; G <- st_as_sf(terra::as.polygons(gr, dissolve = TRUE)); names(G)[1] <- "core"
cc <- st_coordinates(st_transform(suppressWarnings(st_point_on_surface(G)), 4326))
ang <- (180 + 45 - atan2(cc[, 2] - 64.95, (cc[, 1] + 18.6) * cos(64.95 * pi / 180)) * 180 / pi) %% 360
G$no <- rank(ang, ties.method = "first"); G$element <- sprintf("ground:%02d", G$no)
el[el %in% "ground"] <- G$element[match(g[el %in% "ground"], G$core)]
stopifnot(!anyNA(el[dom]))
G$side <- vapply(G$core, function(k) { s <- side_name[g %in% k]; s <- s[!is.na(s)]; if (!length(s)) NA_character_ else names(which.max(table(s))) }, "")
G$banks <- vapply(G$element, function(e) paste(sort(unique(lt$name[!is.na(lt$cell) & el[lt$cell] %in% e])), collapse = ", "), "")
G$basis <- vapply(G$core, function(k) { p <- P[P$piece == k, ]; sprintf("%s (%s)", sub("^a ground: ", "", p$outcome), p$witness) }, "")
P$element <- vapply(P$piece, function(k) { e <- unique(el[piece0 %in% k]); e <- e[!is.na(e)]; if (length(e)) names(sort(table(el[piece0 %in% k]), decreasing = TRUE))[1] else NA_character_ }, "")
P$outcome[is.na(P$outcome)] <- joined[as.character(P$piece[is.na(P$outcome)])]
pq <- st_coordinates(st_transform(suppressWarnings(st_point_on_surface(PC)), 4326)); P$lon <- round(pq[match(P$piece, PC$piece), 1], 4); P$lat <- round(pq[match(P$piece, PC$piece), 2], 4)
P$side <- vapply(P$piece, function(k) { s <- side_name[piece0 %in% k]; s <- s[!is.na(s)]; if (!length(s)) NA_character_ else names(which.max(table(s))) }, "")

# The elements -------------------------------------------------------------------------------------------------------------
er <- d5; codes <- sort(unique(na.omit(el))); terra::values(er) <- match(el, codes)
E <- st_as_sf(terra::as.polygons(er, dissolve = TRUE)); names(E)[1] <- "code"; E$element <- codes[E$code]; E <- st_make_valid(E)
E$kind <- sub(":.*", "", E$element); E$km2 <- round(as.numeric(st_area(st_transform(E, 3057))) / 1e6, 2)
E$label <- case_when(E$kind == "deep" ~ paste0("ÍSOR trough ", sub("deep:", "", E$element)), E$kind == "ridge" ~ RP$label[match(E$element, RP$element)],
                     TRUE ~ paste0("ground ", as.integer(sub("ground:", "", E$element))))
E$side <- case_when(E$kind == "ground" ~ G$side[match(E$element, G$element)], E$kind == "deep" ~ vapply(E$element, function(e) {
  s <- side_name[el %in% e]; s <- s[!is.na(s)]; if (!length(s)) NA_character_ else names(which.max(table(s))) }, ""), TRUE ~ NA_character_)
E$basis <- case_when(E$kind == "deep" ~ "ÍSOR's trough, less any ridge over it",
                     E$kind == "ridge" ~ paste0("ÍSOR's volcanic systems (", RP$systems[match(E$element, RP$element)], ") and a corridor of ", RP$spacing_km[match(E$element, RP$element)],
                                                " km along its crest through ", RP$n_craters[match(E$element, RP$element)], " of ÍSOR's craters"),
                     TRUE ~ paste0("between the deeps' lines; a ground by ", G$basis[match(E$element, G$element)]))
E$banks <- vapply(E$element, function(e) paste(sort(unique(lt$name[!is.na(lt$cell) & el[lt$cell] %in% e])), collapse = ", "), "")
E <- st_transform(E[order(E$kind, E$element), c("element", "kind", "label", "side", "km2", "basis", "banks")], 4326)
lines <- st_transform(lines, 4326); LN <- st_sf(left_join(LT, st_drop_geometry(lines) |> mutate(i = row_number()), by = "line") |> select(-i), geometry = st_geometry(lines)[match(LT$line, lines$line)])

message(sprintf("grounds: %d (west %d, east %d); deeps %d; ridges %d; the cover: %s km2", nrow(G), sum(G$side %in% "west"), sum(G$side %in% "east"), sum(E$kind == "deep"), sum(E$kind == "ridge"),
  paste(sprintf("%s %.0f", names(tapply(E$km2, E$kind, sum)), tapply(E$km2, E$kind, sum)), collapse = ", ")))

# Written ------------------------------------------------------------------------------------------------------------------
CELL <- data.frame(cell = which(dom), x = xy[dom, 1], y = xy[dom, 2], element = el[dom], piece = piece0[dom])
st <- c("fd.version" = VERSION, "fd.crs_cells" = paste0("EPSG:", terra::crs(dem, describe = TRUE)$code))
write_curated(E, REF("landscape_element.parquet"), inputs = INPUTS, script = SCRIPT, stamps = c("fd.version" = VERSION))
write_curated(LN, REF("landscape_line.parquet"), inputs = INPUTS, script = SCRIPT, stamps = c("fd.version" = VERSION))
write_curated(as.data.frame(P[, c("piece", "km2", "lon", "lat", "side", "outcome", "witness", "element", "bank", "skippers", "area")]), REF("landscape_piece.parquet"), inputs = INPUTS, script = SCRIPT, stamps = c("fd.version" = VERSION))
write_curated(CELL, REF("landscape_cell.parquet"), inputs = INPUTS, script = SCRIPT, stamps = st)
message("written: landscape_element, landscape_line, landscape_piece, landscape_cell")
