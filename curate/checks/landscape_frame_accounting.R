# landscape_frame_accounting.R — the landscape frame's bookkeeping (plan 081 §7 step 3, decision 342): the shelf counted
# again from its sources, every cell of it in one element; every element's area its cells'; every deep inside its ÍSOR
# trough and every trough a deep; every arm of every trough with its line (trough 16's left out at the maintainer's word),
# each landing on the mainland's coast and running out of the shelf, each crest from the land out of the shelf; every piece
# the lines cut in one outcome, every ground standing on the one piece a name belongs to; no ground on both plates; every
# chart bank in one outcome.
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/seabed/landscape_frame.R.
#
# Input:  curated/reference/landscape_{element,line,piece,cell}.parquet; curated/reference/seabed_feature.parquet;
#         raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif; raw/external/is50v/strandlina_flakar.json; the named-features
#         study's frozen letterings (version 1)
# Output: curated/check/landscape_frame_accounting.parquet - one row per check: the check, its verdict, n
#
# Bookkeeping (decision 155): the script stops, after writing, unless every check holds.
# Run from the repo root: Rscript curate/checks/landscape_frame_accounting.R. Written by Claude (AI), 2026-11-20.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R", "R/trough_shape.R")) source(f)   # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
DEMF <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif"); COASTF <- fd_raw("external", "is50v", "strandlina_flakar.json")
LETF <- file.path(fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1"), "letterings.csv")
DROP <- "16"                                                                   # trough 16's line, not drawn at his word (decision 341)
E <- read_curated_sf(REF("landscape_element.parquet")); e <- st_drop_geometry(E)
LN <- read_curated_sf(REF("landscape_line.parquet")); l <- st_drop_geometry(LN)
P <- as.data.frame(nanoparquet::read_parquet(REF("landscape_piece.parquet")))
C <- as.data.frame(nanoparquet::read_parquet(REF("landscape_cell.parquet")))
acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }

# The shelf, counted again on the frame's grid
sfx <- read_curated_sf(REF("seabed_feature.parquet")); shelf <- st_union(st_make_valid(sfx[sfx$kind == "shelf break", ]))
BOX3 <- st_as_sfc(st_bbox(st_buffer(st_transform(shelf, 3057), 10000)))
dem <- terra::rast(DEMF); cr <- terra::crs(dem); dem20 <- terra::aggregate(dem, 20)
d5 <- terra::aggregate(terra::crop(dem, terra::vect(st_transform(BOX3, cr))), 10); z <- -terra::values(d5, mat = FALSE); nc5 <- terra::ncol(d5); nr5 <- terra::nrow(d5)
coast <- st_union(st_make_valid(st_read(COASTF, quiet = TRUE)))
rz <- function(g, touches = FALSE) !is.na(terra::values(terra::rasterize(terra::vect(st_transform(g, cr)), d5, touches = touches), mat = FALSE))
mp0 <- st_cast(st_collection_extract(st_make_valid(coast), "POLYGON"), "POLYGON"); main0 <- mp0[which.max(as.numeric(st_area(st_transform(mp0, 3057))))]
in_shelf <- rz(shelf); land <- rz(main0, TRUE); sea <- is.finite(z) & z > 0 & !land; dom <- sea & in_shelf   # Iceland the one void, as the frame
ok("the shelf's cells, counted again from ÍSOR's shelf break, Iceland's coast and the depth model, are the frame's, each once",
   !anyDuplicated(C$cell) && setequal(C$cell, which(dom)), sum(dom))
ok("every cell in one element of the list", !anyNA(C$element) & C$element %in% e$element, nrow(C))
ok("the elements: deeps, ridges and grounds, each once", !anyDuplicated(e$element) & e$kind %in% c("deep", "ridge", "ground") & e$element %in% C$element, nrow(e))
cnt <- table(C$element) * 0.25
ok("each element's area its cells' (within 1 %)", abs(e$km2 - as.numeric(cnt[e$element])) <= 0.01 * as.numeric(cnt[e$element]) + 0.5, nrow(e))

# The deeps and their lines
tr <- sfx[sfx$kind == "trough", ]; tr$t <- sub("isor:landform:trough:", "", tr$seabed_id)
in_tr <- lapply(seq_len(nrow(tr)), function(i) dom & rz(tr[i, ])); names(in_tr) <- tr$t
dc <- C[startsWith(C$element, "deep:"), ]; dt <- sub("deep:", "", dc$element)
ok("a deep's cells lie in its ÍSOR trough", vapply(seq_len(nrow(dc)), function(i) in_tr[[dt[i]]][dc$cell[i]], TRUE), nrow(dc))
ridge_cells <- C$cell[startsWith(C$element, "ridge:")]
has_free <- vapply(tr$t, function(t) any(setdiff(which(in_tr[[t]]), ridge_cells) %in% C$cell), TRUE)
ok("every ÍSOR trough with a cell outside the ridges is a deep", paste0("deep:", tr$t[has_free]) %in% e$element, sum(has_free))
arms <- bind_rows(lapply(seq_len(nrow(tr)), function(i) { tp <- trough_parts(st_transform(tr[i, ], 3057), dem20)
  data.frame(trough = tr$t[i], arm = sort(unique(sub("\\..*$", "", tp$cells$part)))) }))
al <- l[l$kind == "a deep's arm", ]
ok("every arm of every trough has its line, but trough 16's (the maintainer's word)",
   setequal(paste(arms$trough, arms$arm)[!arms$trough %in% DROP], paste(al$trough, al$arm)) && !any(al$trough %in% DROP), nrow(arms))
mp <- st_cast(st_collection_extract(st_make_valid(coast), "POLYGON"), "POLYGON"); mainland <- mp[which.max(as.numeric(st_area(st_transform(mp, 3057))))]
land_main <- rz(mainland, TRUE)
near_main <- function(lon, lat) { k <- terra::cellFromXY(d5, st_coordinates(st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), cr)))
  r <- (k - 1) %/% nc5 + 1; c <- (k - 1) %% nc5 + 1
  any(vapply(list(c(-1, 0), c(1, 0), c(0, -1), c(0, 1), c(0, 0)), function(o) { r2 <- r + o[1]; c2 <- c + o[2]
    r2 >= 1 && r2 <= nr5 && c2 >= 1 && c2 <= nc5 && land_main[(r2 - 1) * nc5 + c2] }, TRUE)) }
ok("every arm's line lands on the mainland's coast", mapply(near_main, al$coast_lon, al$coast_lat), nrow(al))
off <- function(p) { k <- terra::cellFromXY(d5, matrix(p, 1)); is.na(k) || (!in_shelf[k]) }
on_land <- function(p) { k <- terra::cellFromXY(d5, matrix(p, 1)); !is.na(k) && land[k] }
ends <- lapply(st_geometry(st_transform(LN, cr)), function(g) { x <- st_coordinates(g)[, 1:2]; list(a = x[1, ], b = x[nrow(x), ]) })
ok("every arm's line runs out of the shelf", vapply(which(l$kind == "a deep's arm"), function(i) off(ends[[i]]$a), TRUE), nrow(al))
ok("every crest runs from the land out of the shelf", vapply(which(l$kind == "a ridge's crest"), function(i) (on_land(ends[[i]]$a) && off(ends[[i]]$b)) || (on_land(ends[[i]]$b) && off(ends[[i]]$a)), TRUE),
   sum(l$kind == "a ridge's crest"))

# The pieces and the grounds
OUTC <- c("a ground: the charts letter a bank in it", "a ground: a skippers' name has most of its tows in it",
          "a ground: an LMÍ named area lies mostly in it and covers most of it", "joined: the neighbour it borders most", "joined: the nearest ground on its side")
ok("every piece in one outcome, in an element of the list", P$outcome %in% OUTC & P$element %in% e$element & !anyDuplicated(P$piece), nrow(P))
gs <- e$element[e$kind == "ground"]; core <- P[startsWith(P$outcome, "a ground"), ]
ok("every ground stands on the one piece a name belongs to", setequal(core$element, gs) && !anyDuplicated(core$element), length(gs))
ok("every standing piece's witness given", !is.na(core$witness) & nzchar(core$witness), nrow(core))
ok("the pieces' area the grounds' (within 1 %)", abs(sum(P$km2) - sum(e$km2[e$kind == "ground"])) <= 0.01 * sum(e$km2[e$kind == "ground"]), nrow(P))
ok("the grounds numbered 1 to n, once each", setequal(as.integer(sub("ground:", "", gs)), seq_along(gs)), length(gs))
crest_cut <- rz(LN[LN$kind == "a ridge's crest", ], TRUE); ridge <- rep(FALSE, length(z)); ridge[ridge_cells] <- TRUE
rs <- d5; terra::values(rs) <- ifelse(dom & !ridge & !crest_cut, 1, NA); side <- terra::values(terra::patches(rs, directions = 4), mat = FALSE)
two <- as.integer(names(sort(table(side), decreasing = TRUE))[1:2])
both <- vapply(gs, function(g) { s <- side[C$cell[C$element == g]]; sum(s %in% two[1]) >= 4 && sum(s %in% two[2]) >= 4 }, TRUE)
ok("no ground on both plates (1 km2 or more on each side)", !both, length(gs))
ok("every ground on a plate's side, as its row says", e$side[e$kind == "ground"] %in% c("west", "east"), length(gs))

# The chart banks
lt <- read.csv(LETF, encoding = "UTF-8"); lt <- lt[grepl("(grunn|banki)$", tolower(lt$name)) & lt$chart %in% c("sjokort_2milljon", "sjokort_1milljon", "sjokort_300thusund") &
  !grepl("^[A-ZÁÉÍÓÚÝÞÆÖÐ ]+$", lt$name), ]
lt$cell <- terra::cellFromXY(d5, st_coordinates(st_transform(st_as_sf(lt, coords = c("lon", "lat"), crs = 4326), cr)))
lt$element <- C$element[match(lt$cell, C$cell)]
lt$outcome <- ifelse(is.na(lt$element), "off the shelf or on land", sub(":.*", "", lt$element))
ok("every chart bank's lettering in one outcome: a ground, a ridge, a deep, off the shelf", lt$outcome %in% c("ground", "ridge", "deep", "off the shelf or on land"), nrow(lt))
bo <- table(lt$outcome); message("the chart banks' letterings: ", paste(names(bo), bo, collapse = ", "))
in_deep <- unique(lt$name[lt$outcome == "deep"]); if (length(in_deep)) message("lettered in a deep: ", paste(sort(in_deep), collapse = ", "))
gb <- lt |> filter(outcome == "ground") |> distinct(name, element) |> count(name)
ok("no chart bank lettered in two grounds", gb$n == 1, nrow(gb))

write_curated(acc, fd_curated("check", "landscape_frame_accounting.parquet"), script = "curate/checks/landscape_frame_accounting.R",
              inputs = c(REF("landscape_element.parquet"), REF("landscape_line.parquet"), REF("landscape_piece.parquet"), REF("landscape_cell.parquet"),
                         REF("seabed_feature.parquet"), DEMF, COASTF, LETF))
print(knitr::kable(acc))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("landscape_frame_accounting: %d checks, %d failed", nrow(acc), length(fails)))
if (length(fails)) stop("landscape_frame_accounting: ", paste(fails, collapse = "; "))
