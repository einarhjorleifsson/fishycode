# place_name_proposal.R — Claude's best proposal for each place name, from every witness at once (plan 081, decision 337:
# "the goal of this plan is that you come up with the best proposal to a placename. We would then go through that against
# other records in an interactive review"). Step 1 (plan 081 §7): the deeps over all Iceland, on ÍSOR's troughs.
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/names/marine_name.R, outside the targets flow;
# marine_name.R reads its accepted proposals back (the maintainer's `accept proposal` rows).
#
# Input:  curated/reference/marine_name.parquet (the names), seabed_feature.parquet (ÍSOR's troughs), staging/ornefni/
#         trackwell_haul.parquet (the skippers' named tows), staging/is50v/name.parquet (LMÍ's records and their sources),
#         version 1's frozen letterings.csv and chart_join.csv (where each chart scale letters a name; a chart name's LMÍ
#         records), raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif (the depth model), raw/external/is50v/
#         strandlina_flakar.json (the land), overrides/marine_name_edits.csv (his `ignore` rows; his verdicts on proposals,
#         `accept proposal` and `reject proposal`, the proposal's key in `link_to`; his `limit`/`unlimit` and `rest`/`unrest`
#         rows dividing a shared trough), and Bjarni Sæmundsson's statements on
#         the deeps where read ($FISHYDATA/archive/2026-11-20-proposal-deeps/out/bjarni_deep_readings.csv; plan 081 §8 h)
# Output: curated/reference/place_name_proposal.parquet - one row a proposal: `key` ("deep:<name id>", or
#         "deep:trough:<n>" for a trough no name of ours takes, "deep:trough:<n>:<part>" for a part of a shared trough no name
#         takes), `step`, `class`, `name_id`, `name`, `forms`, `kind`, `element` (the seabed feature, ÍSOR's id), `trough`,
#         `part` (of a shared trough, by its shape), `lon`, `lat` (the thing), `place_basis`, `extent_km`,
#         `extent_basis`, `whole`, `shared_with`, `agree` (the witnesses agreeing: charts, LMÍ, skippers, Bjarni; a copy
#         counted with its source), `against`, `flags`, `verdict`, `version`
#         curated/reference/place_name_proposal_evidence.parquet - one row a proposal, candidate element and witness: its
#         member (a chart scale, an LMÍ record and its source, the skippers' name, a statement of Bjarni's), its `group`,
#         `outcome` (agrees, disagrees, silent, mixed, ignored by the maintainer, copy of <group>), `value`, `detail`
#         curated/reference/place_name_proposal_shape.parquet - the proposals' extents (a trough, or its part) and the
#         deeps' thalwegs toward the fjord or bay they are named for; WKB `geometry`, WGS 84
#
# The rules (Claude's, plan 081 §4, his to correct):
# - a deep is a name of ours ending -djúp, -dýpi, -áll or -renna, a name of his own over a trough, or a name he gives the rest
#   of a trough (his `rest`, which puts it on that trough); every one gets a proposal,
#   the unplaced included; its forms in the skippers' tows are its name's, its synonyms' and the charts' own spellings of it;
# - its candidates are ÍSOR's troughs any witness puts it in; each witness gives each candidate one outcome: the charts
#   agree where a scale letters the name inside the trough; LMÍ where its record lies inside (a record of the Coast
#   Guard's or of the general map a copy of the charts, of Trackwell's or Hafrannsóknastofnun's deliveries of 2020 a copy
#   of the skippers'); the skippers where the trough holds more of the name's own tows (its forms joined, "-dýpi" for
#   "-djúp") than any other, at two vessels or more (concentration, plan 081 §8 c), and not where he ignores the name;
#   Bjarni where a statement places it so (the trough nearest the fjord, bay, headland or bank it is off, runs into or
#   adjoins, nearest the middle of the two it lies between; a depth within the trough's confirms a trough the others name,
#   outside it is silent, a depth places nothing); a name the reader inferred, or the text's fjord, silent;
# - the proposal is the candidate with the most independent witnesses agreeing; a tie, a disagreement or a single witness
#   is flagged for the review, not decided; no candidate: the deep awaits the depth model's outline (step 5);
# - its thing is the deepest 200 m cell within the trough's largest inscribed circle, its extent the trough; a trough several names
#   take is split by its own shape into its arms and the stretches of its main line between them, each part to the name whose
#   witnesses point to it, the strongest claim first (Claude's rule, flagged; decision 338), each name's thing the deepest cell
#   within its part's circle; his `limit` and `rest` rows divide a trough by his word (a limit by a straight line or by one of
#   ÍSOR's lines across the trough, holding against the name's own rest); a name whose proposal he rejected takes no part;
# - its thalweg: the deepest route on 1 km cells from the thing to the fjord or bay its root names (cost 1 / (1 + depth /
#   50 m)), where the root names one; untried, for step 3's banks.
# Run from the repo root: Rscript reference/names/place_name_proposal.R. Written by Claude (AI), 2026-11-20.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
TW <- fd_staging("ornefni", "trackwell_haul.parquet"); IS <- fd_staging("is50v", "name.parquet"); EF <- "overrides/marine_name_edits.csv"
DEMF <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif"); COAST <- fd_raw("external", "is50v", "strandlina_flakar.json")
BJ <- fd_path("archive", "2026-11-20-proposal-deeps", "out", "bjarni_deep_readings.csv")
INPUTS <- c(REF("marine_name.parquet"), REF("seabed_feature.parquet"), TW, IS, file.path(V1, "letterings.csv"), file.path(V1, "chart_join.csv"),
            DEMF, COAST, EF, if (file.exists(BJ)) BJ)
VERSION <- "081.1"
fold <- function(x) gsub("(.)\\1+", "\\1", gsub("[^a-z0-9]", "", tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))))
low <- function(x) gsub("[^a-zþæöðáéíóúý]", "", tolower(x))

# The deeps --------------------------------------------------------------------------------------------------------------
nm <- as.data.frame(nanoparquet::read_parquet(REF("marine_name.parquet")))
nm$f <- low(nm$name)
over_trough <- nm$src == "maintainer" & grepl("^isor:landform:trough:[0-9]+$", coalesce(nm$seabed_members, ""))
# a name he gives the rest of a trough (his latest `rest`, not undone) is a deep of that trough whatever its ending
# (decision 338: Paradísarhola on trough 11)
ed0 <- read.csv(EF, encoding = "UTF-8"); if (!"link_to" %in% names(ed0)) ed0$link_to <- NA_character_
rest0 <- ed0[ed0$action %in% c("rest", "unrest"), ]; rest0 <- rest0[order(rest0$at), ]
rest0 <- rest0[!duplicated(rest0$feature, fromLast = TRUE) & rest0$action == "rest", ]
dp <- nm[(grepl("(djúp|djúpið|dýpi|dýpið|áll|állinn|renna|rennan)$", nm$f) | over_trough | nm$id %in% rest0$feature) & !is.na(nm$lon), ]
dp$root <- sub("(djúpið|djúp|dýpið|dýpi|állinn|áll|rennan|renna)$", "", dp$f)
dp$k <- fold(dp$name)
# the forms a skipper may use: the fold, "-dýpi" for "-djúp" and back, the definite article
forms_of <- function(k) { b <- sub("(djupid|djup|dypid|dypi|alin|al|renan|rena)$", "", k); e <- sub(paste0("^", b), "", k)
  alt <- switch(sub("(id|in|n)$", "", e), djup = c("djup", "dypi"), dypi = c("djup", "dypi"), al = "al", rena = "rena", e)
  unique(c(k, paste0(b, alt), paste0(b, alt, "id"), paste0(b, alt, "in"), paste0(b, alt, "n"))) }
dp$forms <- lapply(seq_len(nrow(dp)), function(i) { al <- c(dp$name[i], if (!is.na(dp$synonyms[i])) trimws(strsplit(dp$synonyms[i], "[;,]")[[1]]))
  unique(unlist(lapply(fold(al[nzchar(al)]), forms_of))) })
# a name he made by accepting a proposal for a trough no name took (the page's `new` row over the trough, citing the key)
# keeps that proposal's key, so his verdict stays on it
ed0 <- read.csv(EF, encoding = "UTF-8"); if (!"link_to" %in% names(ed0)) ed0$link_to <- NA_character_
mk <- ed0[ed0$action == "new" & grepl("^isor:landform:trough:", coalesce(ed0$link_to, "")) & grepl("\\(deep:trough:[0-9]+\\)", coalesce(ed0$why, "")), ]
made <- data.frame(name_id = nm$id[match(mk$link_to, ifelse(nm$src == "maintainer", nm$seabed_members, NA))],
                   key = sub(".*\\((deep:trough:[0-9]+)\\).*", "\\1", mk$why))
made <- made[!is.na(made$name_id), ]
key_of <- function(id) ifelse(id %in% made$name_id, made$key[match(id, made$name_id)], paste0("deep:", id))
message(sprintf("deeps: %d names (%s)", nrow(dp), paste(names(table(dp$src)), table(dp$src), collapse = ", ")))

# The troughs ------------------------------------------------------------------------------------------------------------
sfx <- read_curated_sf(REF("seabed_feature.parquet"))
tr <- st_transform(sfx[sfx$kind == "trough", ], 3057); tr$t <- sub("isor:landform:trough:", "", tr$seabed_id)
dem <- terra::rast(DEMF); dem4 <- terra::aggregate(dem, 4)              # 200 m cells
z_of <- function(g) { v <- terra::vect(st_transform(g, terra::crs(dem4))); z <- -terra::values(terra::mask(terra::crop(dem4, v), v), mat = FALSE); z[is.finite(z)] }
# a deep's place: the deepest 200 m cell (its centre inside) within the outline's largest inscribed circle: deep, central, and
# away from a trough's mouth on the slope, where the deepest cell of the whole outline lies for 16 of 40 (Claude's choice of
# three tried, 2026-11-20: the deepest cell anywhere, the circle's centre, this; the circle is the outline's own, no distance chosen)
deepest_in <- function(g) { g3 <- st_union(st_transform(st_geometry(g), 3057)); ic <- st_inscribed_circle(g3, dTolerance = 50)[1]
  a <- st_intersection(ic, g3); v <- terra::vect(st_transform(a, terra::crs(dem4)))
  r <- terra::mask(terra::crop(dem4, v, snap = "out"), v, touches = FALSE); c <- which.min(terra::values(r))
  p <- st_coordinates(st_transform(st_sfc(st_point(terra::xyFromCell(r, c)[1, ]), crs = terra::crs(dem4)), 4326)); c(p[1], p[2], -terra::values(r)[c]) }
tz <- lapply(seq_len(nrow(tr)), function(i) z_of(tr[i, ]))
tr$z05 <- vapply(tz, quantile, 0, 0.05); tr$z95 <- vapply(tz, quantile, 0, 0.95); tr$zmax <- vapply(tz, max, 0)
in_trough <- function(lon, lat) { if (!length(lon)) return(character()); p <- st_transform(st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326), 3057)
  h <- st_intersects(p, tr); vapply(h, function(z) if (length(z)) tr$t[z[1]] else NA_character_, "") }

ev <- list()   # the evidence: one row a deep, candidate trough and witness member
add_ev <- function(d, t, group, member, outcome, value = NA_character_, detail = NA_character_)
  ev[[length(ev) + 1]] <<- data.frame(name_id = d, trough = t, group = group, member = member, outcome = outcome, value = value, detail = detail)

# The charts: where each scale letters the name --------------------------------------------------------------------------
lt <- read.csv(file.path(V1, "letterings.csv"), encoding = "UTF-8")
lt <- lt[lt$feature %in% dp$id, ]; lt$trough <- in_trough(lt$lon, lt$lat)
# the charts' own spellings are forms of the name too (the 1:100 000 and 1:300 000 charts letter "Reykjafjarðaráll", as the skippers write it)
for (i in seq_len(nrow(dp))) { sp <- unique(lt$name[lt$feature == dp$id[i]]); if (length(sp)) dp$forms[[i]] <- unique(c(dp$forms[[i]], unlist(lapply(fold(sp), forms_of)))) }

# LMÍ's records: a chart name's joined records, an LMÍ name's own --------------------------------------------------------
st <- read_curated_sf(IS); stp <- suppressWarnings(st_point_on_surface(st_make_valid(st)))
stxy <- st_coordinates(stp); st0 <- st_drop_geometry(st); st0$lon <- stxy[, 1]; st0$lat <- stxy[, 2]
cj <- read.csv(file.path(V1, "chart_join.csv"), encoding = "UTF-8")
lmi_group <- function(src) case_when(grepl("Landhelgisg|Aðalkort|Sjómælingar", src) ~ "charts", grepl("V20200500[23]|Trackwell|Hafrannsóknastofnun", src) ~ "skippers", TRUE ~ "LMÍ")
lr <- bind_rows(
  do.call(rbind, lapply(which(dp$src == "chart"), function(i) { u <- strsplit(coalesce(cj$uuids[match(dp$id[i], cj$feature)], ""), "\\s+")[[1]]
    s <- st0[st0$uuid %in% u, ]; if (nrow(s)) data.frame(name_id = dp$id[i], rec = s$uuid, source_ref = s$source_ref, lon = s$lon, lat = s$lat) })),
  do.call(rbind, lapply(which(dp$src == "lmi"), function(i) { s <- st0[st0$id == dp$id[i], ]
    if (nrow(s)) data.frame(name_id = dp$id[i], rec = s$uuid, source_ref = s$source_ref, lon = s$lon, lat = s$lat) })))
lr$trough <- in_trough(lr$lon, lr$lat); lr$group <- lmi_group(lr$source_ref)

# The skippers' tows, by concentration -----------------------------------------------------------------------------------
tw <- as.data.frame(nanoparquet::read_parquet(TW)) |>
  filter(!name_placeholder, !time_suspect, !is.na(lon1), !is.na(lon2), !is.na(lat1), !is.na(lat2), !is.na(name), nzchar(name)) |>
  mutate(k = fold(name), lon = (lon1 + lon2) / 2, lat = (lat1 + lat2) / 2)
tw <- tw[tw$k %in% unlist(dp$forms), ]; tw$trough <- in_trough(tw$lon, tw$lat)
ed <- read.csv(EF, encoding = "UTF-8"); if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
ignored <- sub("^trackwell:", "", ed$link_to[ed$action == "ignore"])

# Bjarni's statements --------------------------------------------------------------------------------------------------
bj <- if (file.exists(BJ)) read.csv(BJ, encoding = "UTF-8") else data.frame(deep = character())
# a statement the reader marked as of the fjord itself, or of a fjord's own channels (Skagafjörður's Austuráll and Vesturáll,
# 1901), not of an offshore deep: silent on the troughs (the reader's notes, notes/bjarni_deep_readings.md)
FJORD_SENSE <- "^Fjord sense|channel of the fjord|channel \\(.*\\) of Skagafjörður|by (Vesturáll|Austuráll)|into the fjord|leave the fjord"
place_xy <- function(nme) { s <- st0[tolower(st0$name) == tolower(nme) & !is.na(st0$lon), ]; s[c("lon", "lat")] }
tr_c <- st_coordinates(st_point_on_surface(tr))
near_trough <- function(lon, lat) { if (!length(lon)) return(character()); p <- st_transform(st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326), 3057)
  tr$t[st_nearest_feature(p, tr)] }
fathom <- function(v) { u <- if (grepl("fa[ðd]m|fm", v, ignore.case = TRUE)) 1.8288 else 1
  n <- as.numeric(regmatches(v, gregexpr("[0-9]+([.,][0-9]+)?", v))[[1]] |> sub(pattern = ",", replacement = ".")); if (!length(n)) NULL else range(n) * u }
judge_bj <- function(r) {   # the troughs a statement agrees with, or NA when it cannot be judged
  tg <- trimws(strsplit(coalesce(r$target, ""), ";")[[1]]); tg <- tg[nzchar(tg)]
  if (r$relation %in% c("off", "into", "adjoins", "bearing", "distance") && length(tg)) {
    xy <- place_xy(tg[1]); if (!nrow(xy)) return(NA); unique(near_trough(xy$lon, xy$lat)) }
  else if (r$relation == "between" && length(tg) >= 2) { a <- place_xy(tg[1]); b <- place_xy(tg[2]); if (!nrow(a) || !nrow(b)) return(NA)
    unique(as.vector(outer(seq_len(nrow(a)), seq_len(nrow(b)), Vectorize(function(i, j) near_trough((a$lon[i] + b$lon[j]) / 2, (a$lat[i] + b$lat[j]) / 2))))) }
  else if (r$relation == "depth" && nzchar(coalesce(r$value, ""))) { z <- fathom(r$value); if (is.null(z)) return(NA)
    structure(tr$t[tr$z05 <= z[2] & tr$zmax >= z[1]], depth = TRUE) }
  else NA }

# Each deep: its witnesses on every candidate ----------------------------------------------------------------------------
for (i in seq_len(nrow(dp))) { d <- dp$id[i]
  l <- lt[lt$feature == d, ]; lm <- lr[lr$name_id %in% d, ]; t <- tw[tw$k %in% dp$forms[[i]], ]
  b <- bj[fold(bj$deep) %in% dp$forms[[i]] | fold(bj$deep) == dp$k[i], , drop = FALSE]
  bjt <- if (nrow(b)) lapply(seq_len(nrow(b)), function(j) judge_bj(b[j, ])) else list()
  ign <- any(dp$forms[[i]] %in% ignored)
  share <- if (nrow(t)) t |> filter(!is.na(trough)) |> group_by(trough) |> summarise(n = n(), v = n_distinct(vid), .groups = "drop") |> mutate(share = n / nrow(t)) else data.frame(trough = character(), n = integer(), v = integer(), share = numeric())
  top <- share |> filter(v >= 2) |> arrange(desc(share)) |> slice_head(n = 1)
  # a depth only tests the troughs the other witnesses name: it adds none
  placing <- bjt[!vapply(bjt, function(z) all(is.na(z)) || isTRUE(attr(z, "depth")), TRUE)]
  cand <- unique(na.omit(c(l$trough, lm$trough, top$trough, unlist(placing), in_trough(dp$lon[i], dp$lat[i]))))
  for (tt in c(cand, NA_character_)) {
    tlab <- if (is.na(tt)) "none" else tt
    if (nrow(l)) add_ev(d, tlab, "charts", "the charts' letterings", if (!is.na(tt) && any(l$trough %in% tt)) "agrees" else if (is.na(tt) && all(is.na(l$trough))) "agrees" else "disagrees",
                        sprintf("%d of %d scales", if (is.na(tt)) sum(is.na(l$trough)) else sum(l$trough %in% tt), nrow(l)), paste(unique(l$chart), collapse = ", "))
    for (j in seq_len(nrow(lm))) { o <- if ((!is.na(tt) && lm$trough[j] %in% tt) || (is.na(tt) && is.na(lm$trough[j]))) "agrees" else "disagrees"
      add_ev(d, tlab, lm$group[j], paste0("LMÍ: ", lm$source_ref[j]), if (lm$group[j] == "LMÍ") o else paste0(o, " (a copy of the ", lm$group[j], ")"), NA, lm$rec[j]) }
    if (ign) add_ev(d, tlab, "skippers", "the skippers' tows", "ignored by the maintainer", NA, paste(intersect(dp$forms[[i]], ignored), collapse = ", "))
    else if (nrow(t)) { s <- share[share$trough %in% tt, ]
      o <- if (!nrow(top)) "silent (fewer than two vessels in any trough)" else if (!is.na(tt) && top$trough == tt) "agrees" else "disagrees"
      add_ev(d, tlab, "skippers", "the skippers' tows", o, sprintf("%.0f %% of %d tows, %d vessels", 100 * coalesce(s$share[1], 0), nrow(t), coalesce(s$v[1], 0L)),
             paste(sort(unique(t$name)), collapse = "; ")) }
    for (j in seq_len(nrow(b))) { z <- bjt[[j]]
      o <- if (identical(b$basis[j], "inferred")) "silent (the reader inferred the name)"
        else if (grepl(FJORD_SENSE, coalesce(b$says[j], ""))) "silent (the text means the fjord or its channels)" else if (all(is.na(z))) "silent"
        else if (isTRUE(attr(z, "depth"))) { if (!is.na(tt) && tt %in% z) "agrees (its depth)" else "silent (a depth outside: it may be the trough's mouth or slope)" }
        else if (is.na(tt)) "disagrees" else if (tt %in% z) "agrees" else "disagrees"
      add_ev(d, tlab, "Bjarni", sprintf("Bjarni, Andvari %s p. %s: %s", b$year[j], b$page[j], b$relation[j]), o, b$value[j], b$says[j]) } } }
E <- bind_rows(ev)

# The proposal: the candidate with the most independent witnesses agreeing ---------------------------------------------
grp_out <- E |> mutate(ag = grepl("^agrees", outcome), dis = grepl("^disagrees", outcome)) |>
  group_by(name_id, trough, group) |> summarise(ag = any(ag), dis = any(dis), .groups = "drop") |>
  group_by(name_id, trough) |> summarise(agree = paste(sort(group[ag]), collapse = ", "), n_agree = sum(ag), against = paste(sort(group[dis & !ag]), collapse = ", "), n_against = sum(dis & !ag), .groups = "drop")
pick <- grp_out |> group_by(name_id) |> arrange(desc(n_agree), n_against, trough == "none", .by_group = TRUE) |>
  mutate(tie = n() > 1 & n_agree[1] > 0 & n_agree[1] == dplyr::nth(n_agree, 2, default = -1L) & n_against[1] == dplyr::nth(n_against, 2, default = -1L)) |>
  slice_head(n = 1) |> ungroup()
P <- dp |> transmute(name_id = id, name, src, root, k, lon0 = lon, lat0 = lat, forms = vapply(forms, paste, "", collapse = "; ")) |>
  left_join(pick, by = "name_id") |> mutate(trough = ifelse(is.na(trough) | n_agree == 0, "none", trough))
P$n_agree[is.na(P$n_agree)] <- 0L
hr <- match(P$name_id, rest0$feature); P$trough[!is.na(hr)] <- sub("^isor:landform:trough:", "", rest0$link_to[hr[!is.na(hr)]])   # his rest: the name on that trough

# The thing and the extent ---------------------------------------------------------------------------------------------
# A trough one name takes: its thing the deepest 200 m cell within the trough's largest inscribed circle, its extent the
# trough. A trough several names take is split by its own shape (Claude's rule, tried on trough 10, decision 338): on 1 km
# cells, each cell's distance from the trough's deepest cell along the trough; flooded from the farthest in, a branch ends
# where it meets a longer one, its length the tip's distance less the meeting's; a branch longer than the trough is half
# wide near where it joins is an arm, and the longest line (from the deepest cell to the farthest tip) is cut where the arms
# meet it. Each witness points a name to a part (the charts: the part of its largest-scale lettering, the larger the
# scale the closer a lettering sits to its thing; LMÍ: its records' parts, a copy with its source; the skippers: the part
# holding most of its tows, two vessels or more there; Bjarni: the part nearest the place a statement sets it by); each part
# to one name, the strongest claim first; a name whose parts are all taken leaves the trough, a part no name takes is a
# proposal of its own. His `limit` rows keep a name to the left of a line (walked from lon/lat to comp_lon/comp_lat), or, where
# link_to names one of ÍSOR's lines (a moraine), on the side of that line holding lon/lat, the line carried on along its end
# segments to the trough's outline; his `rest` rows give a name every cell of the trough (link_to) no other name holds,
# within the name's own limits; `unlimit` and `unrest` undo. A name whose proposal he rejected leaves its trough (decision 338).
dem20 <- terra::aggregate(dem, 20)                                          # 1 km cells
NB <- cbind(c(-1, -1, -1, 0, 0, 1, 1, 1), c(-1, 0, 1, -1, 1, -1, 0, 1))
flood <- function(ord, key, rc, idx, nr, nc) {   # cells reached in `ord`; a set is led by its cell of largest `key`; a lesser set ends where it meets
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
  list(lab = lab, ends = ends) }
trough_parts <- function(g) {
  g5 <- terra::vect(st_transform(st_geometry(g), terra::crs(dem20)))
  v <- terra::mask(terra::crop(dem20, terra::ext(g5) + 3000, snap = "out"), g5, touches = FALSE)
  cells <- which(!is.na(terra::values(v, mat = FALSE))); z <- -terra::values(v, mat = FALSE)[cells]
  nr <- terra::nrow(v); nc <- terra::ncol(v); rc <- terra::rowColFromCell(v, cells)
  idx <- rep(NA_integer_, terra::ncell(v)); idx[cells] <- seq_along(cells)
  root <- which.max(z); mk <- v; mk[!is.na(mk)] <- 1; mk[cells[root]] <- 0
  dist <- terra::values(terra::gridDist(mk, target = 0), mat = FALSE)[cells] / 1000; dist[!is.finite(dist)] <- NA
  reach <- which(!is.na(dist)); main <- reach[which.max(dist[reach])]
  fl <- flood(reach[order(-dist[reach])], ifelse(is.na(dist), -Inf, dist), rc, idx, nr, nc)
  br <- fl$ends; br$length <- dist[br$tip] - dist[br$meet]; br <- br[order(-br$length), ]
  # an arm: a branch longer than the trough is half wide near where it joins (the largest distance to the outline's edge
  # among the cells within one branch length of the junction, not its own): a shorter one is a bump on the body it joins.
  # Tried against the largest drop in the sorted lengths, which a 500 m shift of the grid flipped for trough 10 (decision 338)
  xy0 <- terra::xyFromCell(v, cells); out0 <- v; out0[] <- 1; out0[cells] <- NA
  dt <- terra::values(terra::distance(out0), mat = FALSE)[cells] / 1000
  br$half <- NA_real_
  for (i in which(br$length > 1)) { d <- sqrt((xy0[, 1] - xy0[br$meet[i], 1])^2 + (xy0[, 2] - xy0[br$meet[i], 2])^2) / 1000
    br$half[i] <- max(dt[d <= br$length[i] & fl$lab != br$tip[i]]) }
  arms <- br$tip[!is.na(br$half) & br$length > br$half]; n_arm <- length(arms)
  keep <- c(main, arms); up <- setNames(br$into, br$tip)
  top <- function(b) { while (!(b %in% keep)) b <- up[[as.character(b)]]; b }
  arm <- rep(NA_integer_, length(cells)); arm[reach] <- vapply(fl$lab[reach], top, 1L)
  xy <- terra::xyFromCell(v, cells)
  if (length(miss <- which(is.na(arm)))) { r0 <- reach[vapply(miss, function(m) which.min((xy[reach, 1] - xy[m, 1])^2 + (xy[reach, 2] - xy[m, 2])^2), 1L)]; arm[miss] <- arm[r0]; dist[miss] <- dist[r0] }
  ll <- st_coordinates(st_transform(st_as_sf(data.frame(x = xy[, 1], y = xy[, 2]), coords = 1:2, crs = terra::crs(dem20)), 4326))
  lab <- setNames(paste0("b", rank(ll[keep, 1], ties.method = "first")), keep)            # the arms by their tips, west to east
  part <- unname(lab[as.character(arm)])
  onm <- arms[vapply(br$into[match(arms, br$tip)], top, 1L) == main]   # the arms meeting the main line
  cuts <- c(-Inf, sort(dist[br$meet[match(onm, br$tip)]]), Inf); m <- arm == main
  if (length(cuts) > 2) part[m] <- paste0(lab[as.character(main)], ".", findInterval(dist[m], cuts))
  cl <- data.frame(cell = cells, lon = ll[, 1], lat = ll[, 2], x = xy[, 1], y = xy[, 2], z = z, part = part)
  list(v = v, idx = idx, cells = cl, arms = data.frame(tip = keep, part = unname(lab), length = c(dist[main], br$length[match(keep[-1], br$tip)])), n_arm = n_arm) }
part_at <- function(tp, lon, lat) { out <- rep(NA_character_, length(lon)); ok <- !is.na(lon) & !is.na(lat); if (!any(ok)) return(out)
  p <- st_coordinates(st_transform(st_as_sf(data.frame(lon = lon[ok], lat = lat[ok]), coords = 1:2, crs = 4326), terra::crs(dem20)))
  a <- tp$idx[terra::cellFromXY(tp$v, p)]; out[ok] <- ifelse(is.na(a), NA_character_, tp$cells$part[a]); out }
part_near <- function(tp, lon, lat) vapply(seq_along(lon), function(i)
  tp$cells$part[which.min((tp$cells$lon - lon[i])^2 * cos(lat[i] * pi / 180)^2 + (tp$cells$lat - lat[i])^2)], "")
cells_poly <- function(tp, keep) { r <- tp$v; r[] <- NA; r[tp$cells$cell[keep]] <- 1
  st_union(st_make_valid(st_as_sf(terra::as.polygons(r, dissolve = TRUE)))) |> st_transform(4326) }
scale_of <- function(ch) { n <- suppressWarnings(as.numeric(sub("^sjokort_([0-9]+).*", "\\1", ch))); ifelse(grepl("milljon", ch), n * 1e6, ifelse(grepl("thusund", ch), n * 1e3, NA)) }
cut_side <- function(tp, g, r, tt) {   # the cells on the side of his ÍSOR line holding his point
  ln <- sfx[sfx$seabed_id %in% r$link_to, ]; if (nrow(ln) != 1) stop("his limit of ", r$name, " by ", r$link_to, ": no such ÍSOR feature")
  cr <- terra::crs(dem20); ln <- st_cast(st_geometry(st_transform(ln, cr)), "LINESTRING")
  if (length(ln) != 1) stop("his limit of ", r$name, " by ", r$link_to, ": not one line")
  xy <- st_coordinates(ln)[, 1:2]; n <- nrow(xy)
  far <- function(p, q) p + (p - q) / sqrt(sum((p - q)^2)) * 20000                 # carried on 20 km past an end, along its last segment
  cut <- st_sfc(st_linestring(rbind(far(xy[1, ], xy[2, ]), xy, far(xy[n, ], xy[n - 1, ]))), crs = cr)
  pcs <- st_cast(st_difference(st_union(st_transform(st_geometry(g), cr)), st_buffer(cut, 5)), "POLYGON")
  k <- which(lengths(st_intersects(pcs, st_transform(st_sfc(st_point(c(r$lon, r$lat)), crs = 4326), cr))) > 0)
  if (length(pcs) != 2 || length(k) != 1) stop(sprintf("his limit of %s by %s: it does not cut ÍSOR's trough %s in two, or his point is on neither side", r$name, r$link_to, tt))
  pts <- st_as_sf(data.frame(x = tp$cells$x, y = tp$cells$y), coords = 1:2, crs = cr); w <- st_intersects(pts, pcs)
  side <- vapply(w, function(z) if (length(z)) z[1] else NA_integer_, 1L)
  if (any(on <- is.na(side))) side[on] <- st_nearest_feature(pts[on, ], pcs)             # a cell on the line itself: its nearer side
  side == k }
left_of <- function(x, y, r) { a <- st_coordinates(st_transform(st_as_sf(data.frame(lon = c(r$lon, r$comp_lon), lat = c(r$lat, r$comp_lat)), coords = 1:2, crs = 4326), terra::crs(dem20)))
  (a[2, 1] - a[1, 1]) * (y - a[1, 2]) - (a[2, 2] - a[1, 2]) * (x - a[1, 1]) > 0 }
# his limits and rests, each undone by a later `unlimit` or `unrest` of the name
latest_of <- function(on, off) { e <- ed[ed$action %in% c(on, off), ]; e <- e[order(e$at), ]
  if (!nrow(e)) return(e); last_off <- tapply(ifelse(e$action == off, seq_len(nrow(e)), 0L), e$feature, max)
  e[e$action == on & seq_len(nrow(e)) > last_off[as.character(e$feature)], ] }
his_limit <- latest_of("limit", "unlimit"); his_rest <- latest_of("rest", "unrest")
his_rest <- his_rest[!duplicated(his_rest$feature, fromLast = TRUE), ]

shapes <- list(); P$lon <- P$lon0; P$lat <- P$lat0; P$place_basis <- "its place as the names have it (no trough proposed)"; P$extent_km <- NA_real_
P$extent_basis <- NA_character_; P$shared_with <- NA_character_; P$split <- FALSE; P$part <- NA_character_; P$part_note <- NA_character_
UP <- list()   # the parts of a shared trough no name takes
# his rejects: a name whose proposal he rejected takes no part of its trough (decision 338), its place its own
vd0 <- ed |> filter(action %in% c("accept proposal", "reject proposal")) |> arrange(at) |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
rj <- which(key_of(P$name_id) %in% vd0$link_to[vd0$action == "reject proposal"] & P$trough != "none")
P$part_note[rj] <- paste0("off ÍSOR's trough ", P$trough[rj], ": the maintainer rejected its proposal"); P$trough[rj] <- "none"
P$agree[rj] <- ""; P$n_agree[rj] <- 0L; P$against[rj] <- ""; P$n_against[rj] <- 0L; P$tie[rj] <- FALSE
place_in <- function(jj, pg, tt, what) { q <- deepest_in(st_sf(geometry = pg)); P$lon[jj] <<- q[1]; P$lat[jj] <<- q[2]
  P$place_basis[jj] <<- sprintf("the deepest 200 m cell within the largest circle inside ÍSOR's trough %s%s, %.0f m (Claude's proposal, plan 081 step 1)", tt, what, q[3])
  bb <- st_bbox(st_transform(pg, 3057)); P$extent_km[jj] <<- round(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1000, 3); q }
for (tt in setdiff(unique(P$trough), "none")) { g <- tr[tr$t == tt, ]; ii <- which(P$trough == tt); nk <- unique(P$k[ii])
  if (length(nk) == 1) { jj <- ii; place_in(jj, st_transform(st_geometry(g), 4326), tt, "")
    P$extent_basis[jj] <- sprintf("ÍSOR's trough %s", tt)
    shapes[[length(shapes) + 1]] <- st_sf(key = key_of(P$name_id[jj]), what = "extent", basis = paste0("ÍSOR's trough (isor:landform:trough:", tt, ") (Claude's proposal)"),
                                          geometry = rep(st_transform(st_geometry(g), 4326), length(jj)))
    next }
  tp <- trough_parts(g); cl <- tp$cells
  # each name's witnesses on the parts
  cm <- list()
  for (kk in nk) { rows <- ii[P$k[ii] == kk]; ids <- P$name_id[rows]; fm <- strsplit(P$forms[rows[1]], "; ")[[1]]
    l <- lt[lt$feature %in% ids & lt$trough %in% tt, ]
    if (nrow(l)) { l <- l[scale_of(l$chart) == min(scale_of(l$chart), na.rm = TRUE), ]; pt <- part_at(tp, l$lon, l$lat)
      for (pp in unique(na.omit(pt))) cm[[length(cm) + 1]] <- data.frame(k = kk, part = pp, group = "charts", member = "the charts' letterings",
        value = sprintf("its largest-scale lettering (1:%s) in this part", format(min(scale_of(l$chart)), big.mark = " ")), detail = paste(unique(l$chart), collapse = ", ")) }
    m <- lr[lr$name_id %in% ids & lr$trough %in% tt, ]
    if (nrow(m)) { m$part <- part_at(tp, m$lon, m$lat); for (j in which(!is.na(m$part))) cm[[length(cm) + 1]] <- data.frame(k = kk, part = m$part[j], group = m$group[j],
      member = paste0("LMÍ: ", m$source_ref[j]), value = if (m$group[j] == "LMÍ") NA_character_ else paste0("a copy of the ", m$group[j]), detail = m$rec[j]) }
    t <- tw[tw$k %in% fm & tw$trough %in% tt, ]
    if (nrow(t) && !any(fm %in% ignored)) { t$part <- part_at(tp, t$lon, t$lat)
      s <- t |> filter(!is.na(part)) |> group_by(part) |> summarise(n = n(), v = n_distinct(vid), .groups = "drop") |> filter(v >= 2) |> arrange(desc(n)) |> slice_head(n = 1)
      if (nrow(s)) cm[[length(cm) + 1]] <- data.frame(k = kk, part = s$part, group = "skippers", member = "the skippers' tows",
        value = sprintf("%d of their %d tows in the trough, %d vessels", s$n, nrow(t), s$v), detail = paste(sort(unique(t$name)), collapse = "; ")) }
    b <- bj[fold(bj$deep) %in% fm | fold(bj$deep) == kk, , drop = FALSE]
    b <- b[coalesce(b$basis, "") != "inferred" & !grepl(FJORD_SENSE, coalesce(b$says, "")) & b$relation %in% c("off", "into", "adjoins", "bearing", "distance", "between"), , drop = FALSE]
    for (j in seq_len(nrow(b))) { tg <- trimws(strsplit(coalesce(b$target[j], ""), ";")[[1]]); tg <- tg[nzchar(tg)]; if (!length(tg)) next
      pp <- if (b$relation[j] == "between") { if (length(tg) < 2) next; a1 <- place_xy(tg[1]); a2 <- place_xy(tg[2]); if (!nrow(a1) || !nrow(a2)) next
        part_near(tp, (a1$lon[1] + a2$lon[1]) / 2, (a1$lat[1] + a2$lat[1]) / 2) } else { xy <- place_xy(tg[1]); if (!nrow(xy)) next; unique(part_near(tp, xy$lon, xy$lat)) }
      for (x in pp) cm[[length(cm) + 1]] <- data.frame(k = kk, part = x, group = "Bjarni", member = sprintf("Bjarni, Andvari %s p. %s: %s", b$year[j], b$page[j], b$relation[j]),
        value = b$value[j], detail = b$says[j]) } }
  cm <- bind_rows(cm)
  cn <- if (nrow(cm)) cm |> distinct(k, part, group) |> count(k, part, name = "n") |> arrange(desc(n), k, part) else data.frame(k = character(), part = character(), n = integer())
  asg <- cn[0, ]; for (r in seq_len(nrow(cn))) if (!cn$k[r] %in% asg$k && !cn$part[r] %in% asg$part) asg <- rbind(asg, cn[r, ])
  tie <- cn |> group_by(part) |> filter(n == max(n)) |> filter(n_distinct(k) > 1) |> pull(part) |> unique()
  own <- asg$k[match(cl$part, asg$part)]
  # his limits and rests: a name's limits hold over what its witnesses gave it and over what its rest gives it
  kept <- function(kk) { ok <- rep(TRUE, nrow(cl)); rows <- ii[P$k[ii] == kk]
    for (r in which(his_limit$feature %in% P$name_id[rows])) ok <- ok & (if (grepl("^isor:", coalesce(his_limit$link_to[r], ""))) cut_side(tp, g, his_limit[r, ], tt)
                                                                         else left_of(cl$x, cl$y, his_limit[r, ]))
    ok }
  for (kk in nk) own[own %in% kk & !kept(kk)] <- NA
  for (kk in nk) { rows <- ii[P$k[ii] == kk]; r <- which(his_rest$feature %in% P$name_id[rows] & his_rest$link_to %in% paste0("isor:landform:trough:", tt))
    if (length(r)) own[is.na(own) & kept(kk)] <- kk }
  arms <- paste(sprintf("%s %.0f km", tp$arms$part, tp$arms$length), collapse = ", ")
  for (kk in nk) { jj <- ii[P$k[ii] == kk]; P$split[jj] <- TRUE; P$shared_with[jj] <- paste(unique(P$name[ii][P$k[ii] != kk]), collapse = "; ")
    ev_k <- cm[cm$k == kk, , drop = FALSE]
    for (d in P$name_id[jj]) for (pp in unique(c(ev_k$part, asg$part[asg$k == kk]))) for (gg in unique(ev_k$group)) {
      e <- ev_k[ev_k$group == gg, ]; o <- if (pp %in% e$part) "agrees" else "disagrees"; e1 <- if (pp %in% e$part) e[e$part == pp, ][1, ] else e[1, ]
      add_ev(d, tt, gg, e1$member, o, e1$value, e1$detail); ev[[length(ev)]]$part <- pp }
    mine <- which(own %in% kk)
    if (!length(mine)) { P$trough[jj] <- "none"; P$split[jj] <- FALSE
      inside <- unique(na.omit(part_at(tp, lt$lon[lt$feature %in% P$name_id[jj]], lt$lat[lt$feature %in% P$name_id[jj]])))
      hold <- unique(na.omit(asg$k[match(inside, asg$part)]))
      P$part_note[jj] <- paste0("off ÍSOR's trough ", tt, ": its witnesses hold no part of it that a name with more witnesses does not",
        if (length(hold)) paste0("; its lettering lies in ", paste(unique(P$name[P$k %in% hold]), collapse = ", "), "'s part (a part of it?)") else "")
      next }
    pg <- cells_poly(tp, mine); a0 <- asg[asg$k == kk, ]
    P$part[jj] <- if (nrow(a0)) a0$part else "his division"
    his <- any(his_limit$feature %in% P$name_id[jj]) || any(his_rest$feature %in% P$name_id[jj]) || (nrow(a0) && any(cl$part[mine] != a0$part))
    q <- place_in(jj, pg, tt, if (length(mine) == nrow(cl)) "" else ", in its part")
    P$extent_basis[jj] <- sprintf("ÍSOR's trough %s, %s by the trough's own shape (its arms %s; Claude's rule)%s", tt,
      if (nrow(a0)) paste0("its part ", a0$part) else "its part", arms,
      if (his && length(mine) == nrow(cl)) ", and the rest of it by the maintainer's rest row: the trough whole" else if (his) paste0(", as the maintainer divided it (his limit and rest rows",
        if (length(cutby <- unique(his_limit$link_to[his_limit$feature %in% P$name_id[jj] & grepl("^isor:", coalesce(his_limit$link_to, ""))])))
          paste0("; cut at ÍSOR's ", paste(sub("^isor:landform:([a-z_]+):", "\\1 ", cutby), collapse = ", ")), ")") else "")
    if (nrow(a0)) { P$n_agree[jj] <- a0$n; gq <- sort(unique(cm$group[cm$k == kk & cm$part == a0$part])); P$agree[jj] <- paste(gq, collapse = ", ")
      ag <- sort(setdiff(unique(cm$group[cm$k == kk & cm$part != a0$part]), gq)); P$against[jj] <- paste(ag, collapse = ", "); P$n_against[jj] <- length(ag)
    } else { P$n_agree[jj] <- 0L; P$agree[jj] <- ""; P$against[jj] <- ""; P$n_against[jj] <- 0L }   # cells by his word alone
    if (nrow(a0) && a0$part %in% tie) P$part_note[jj] <- paste0("another name claims its part ", a0$part, " as strongly")
    shapes[[length(shapes) + 1]] <- st_sf(key = key_of(P$name_id[jj]), what = "extent",
      basis = paste0("ÍSOR's trough (isor:landform:trough:", tt, "), its part by the trough's own shape", if (his) ", as the maintainer divided it" else "", " (Claude's proposal)"),
      geometry = rep(pg, length(jj))) }
  for (pp in sort(unique(cl$part[is.na(own)]))) { mine <- which(is.na(own) & cl$part == pp); pg <- cells_poly(tp, mine); q <- deepest_in(st_sf(geometry = pg))
    bb <- st_bbox(st_transform(pg, 3057))
    UP[[length(UP) + 1]] <- data.frame(key = paste0("deep:trough:", tt, ":", pp), name_id = NA_real_, name = NA_character_, src = "none", trough = tt, part = pp,
      lon = q[1], lat = q[2], place_basis = sprintf("the deepest 200 m cell within the largest circle inside its part, %.0f m (Claude's proposal, plan 081 step 1)", q[3]),
      extent_km = round(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1000, 3), extent_basis = sprintf("ÍSOR's trough %s, its part %s by the trough's own shape (its arms %s; Claude's rule)", tt, pp, arms),
      agree = "", n_agree = 0L, against = "", n_against = 0L, flags = sprintf("a part of ÍSOR's trough %s no name of ours takes", tt))
    shapes[[length(shapes) + 1]] <- st_sf(key = paste0("deep:trough:", tt, ":", pp), what = "extent", basis = paste0("ÍSOR's trough (isor:landform:trough:", tt, "), its part ", pp, " by its own shape (Claude's proposal)"), geometry = pg) } }

E <- bind_rows(ev)   # with the parts' evidence
UP <- bind_rows(UP)

# The troughs no name of ours takes: the skippers' most concentrated name, two vessels or more -----------------------------
twa <- as.data.frame(nanoparquet::read_parquet(TW)) |>
  filter(!name_placeholder, !time_suspect, !is.na(lon1), !is.na(lon2), !is.na(lat1), !is.na(lat2), !is.na(name), nzchar(name)) |>
  mutate(k = fold(name), lon = (lon1 + lon2) / 2, lat = (lat1 + lat2) / 2)
twa$trough <- in_trough(twa$lon, twa$lat); all_k <- twa |> count(k, name = "n_all")
U <- list()
for (tt in setdiff(tr$t, c(P$trough, UP$trough))) { g <- tr[tr$t == tt, ]; q <- deepest_in(g)
  s <- twa |> filter(trough == tt, !k %in% ignored) |> group_by(k) |> summarise(name = names(sort(table(name), decreasing = TRUE))[1], n = n(), v = n_distinct(vid), .groups = "drop") |>
    left_join(all_k, by = "k") |> mutate(share = n / n_all) |> filter(v >= 2) |> arrange(desc(share)) |> slice_head(n = 1)
  bb <- st_bbox(g)
  U[[length(U) + 1]] <- data.frame(key = paste0("deep:trough:", tt), name_id = NA_real_, name = if (nrow(s)) s$name else NA_character_, src = "skippers", trough = tt,
    lon = q[1], lat = q[2], place_basis = sprintf("the deepest 200 m cell within the largest circle inside ÍSOR's trough %s, %.0f m (Claude's proposal, plan 081 step 1)", tt, q[3]),
    extent_km = round(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1000, 3), extent_basis = sprintf("ÍSOR's trough %s", tt),
    agree = if (nrow(s)) "skippers" else "", n_agree = as.integer(nrow(s) > 0), against = "", n_against = 0L,
    flags = if (nrow(s)) sprintf("a trough no name of ours takes; the skippers' most concentrated name, %.0f %% of its %d tows, %d vessels: one witness", 100 * s$share, s$n_all, s$v) else "a trough no name of ours takes and no skippers' name")
  shapes[[length(shapes) + 1]] <- st_sf(key = paste0("deep:trough:", tt), what = "extent", basis = paste0("ÍSOR's trough (isor:landform:trough:", tt, ") (Claude's proposal)"),
                                        geometry = st_transform(st_geometry(g), 4326))
  if (nrow(s)) E <- bind_rows(E, data.frame(name_id = NA_real_, trough = tt, group = "skippers", member = "the skippers' tows", outcome = "agrees",
                                             value = sprintf("%.0f %% of %d tows, %d vessels", 100 * s$share, s$n_all, s$v), detail = s$name, key = paste0("deep:trough:", tt))) }

# The thalwegs: the deepest route from the thing to the fjord or bay the root names --------------------------------------
land <- terra::rasterize(terra::vect(st_transform(st_union(st_make_valid(st_read(COAST, quiet = TRUE))), terra::crs(dem20))), dem20, touches = TRUE)
nomin <- function(r) unique(c(sub("fjarðar$", "fjörður", r), sub("flóa$", "flói", r), sub("víkur$", "vík", r), sub("vogs$", "vogur", r), sub("bugs$", "bugur", r)))
bays <- st0[st0$feature %in% c("fjörður", "flói", "vík", "vogur", "bugur", "bugt", "sund") & !is.na(st0$lon), ]
thalweg <- function(lon, lat, root) { nn <- setdiff(nomin(root), root); w <- bays[low(bays$name) %in% nn, ]; if (!nrow(w)) return(NULL)
  dk <- sqrt(((w$lon - lon) * 111.32 * cos(lat * pi / 180))^2 + ((w$lat - lat) * 110.57)^2); w <- w[which.min(dk), ]; if (min(dk) > 250) return(NULL)
  p <- st_coordinates(st_transform(st_as_sf(data.frame(x = c(lon, w$lon), y = c(lat, w$lat)), coords = c("x", "y"), crs = 4326), terra::crs(dem20)))
  e <- terra::ext(min(p[, 1]) - 30000, max(p[, 1]) + 30000, min(p[, 2]) - 30000, max(p[, 2]) + 30000)
  z <- -terra::crop(dem20, e); ld <- terra::crop(land, e); zz <- terra::values(z, mat = FALSE); sea <- is.finite(zz) & zz > 0 & is.na(terra::values(ld, mat = FALSE))
  nc <- terra::ncol(z); nr <- terra::nrow(z); cost <- 1 / (1 + pmax(zz, 0) / 50)
  ed <- do.call(rbind, lapply(list(c(0, 1), c(1, 0), c(1, 1), c(1, -1)), function(o) { a <- which(sea); r <- (a - 1) %/% nc + 1; cc <- (a - 1) %% nc + 1
    r2 <- r + o[1]; c2 <- cc + o[2]; ok <- r2 >= 1 & r2 <= nr & c2 >= 1 & c2 <= nc; b <- (r2[ok] - 1) * nc + c2[ok]; a <- a[ok]; k <- sea[b]
    cbind(a[k], b[k], sqrt(sum(o^2)) * (cost[a[k]] + cost[b[k]]) / 2) }))
  gr <- igraph::graph_from_edgelist(cbind(as.character(ed[, 1]), as.character(ed[, 2])), directed = FALSE); igraph::E(gr)$weight <- ed[, 3]
  snap <- function(xy) { cl <- terra::cellFromXY(z, xy); if (is.na(cl) || !sea[cl]) { s <- which(sea); xyc <- terra::xyFromCell(z, s); cl <- s[which.min((xyc[, 1] - xy[1])^2 + (xyc[, 2] - xy[2])^2)] }; as.character(cl) }
  a <- snap(p[1, , drop = FALSE]); b <- snap(p[2, , drop = FALSE]); if (!a %in% igraph::V(gr)$name || !b %in% igraph::V(gr)$name) return(NULL)
  path <- igraph::shortest_paths(gr, a, b, output = "vpath")$vpath[[1]]; if (length(path) < 2) return(NULL)
  xy <- terra::xyFromCell(z, as.integer(igraph::as_ids(path)))
  list(geom = st_transform(st_sfc(st_linestring(xy), crs = terra::crs(dem20)), 4326), to = w$name) }
for (i in which(P$trough != "none" & !duplicated(paste(P$k, P$trough)))) { th <- thalweg(P$lon[i], P$lat[i], P$root[i]); if (is.null(th)) next
  for (j in which(P$k == P$k[i] & P$trough == P$trough[i]))
    shapes[[length(shapes) + 1]] <- st_sf(key = key_of(P$name_id[j]), what = "thalweg",
      basis = sprintf("the deepest route on 1 km cells from the thing to %s (cost 1 / (1 + depth / 50 m); Claude's rule, untried, for step 3)", th$to), geometry = th$geom) }

# Flags, verdicts, the tables ----------------------------------------------------------------------------------------------
dup <- P |> group_by(k) |> filter(n() > 1) |> summarise(ids = paste(name_id, collapse = ", "), .groups = "drop")
P <- P |> mutate(key = key_of(name_id),
  flags = trimws(paste0(
    ifelse(trough == "none", "no ÍSOR trough proposed: awaits the depth model's outline (step 5); ", ""),
    ifelse(trough != "none" & n_agree == 1, "one witness only; ", ""), ifelse(n_against > 0 & n_agree > 0, paste0("against it: ", against, "; "), ""),
    ifelse(coalesce(tie, FALSE), "a tie between troughs; ", ""), ifelse(split, paste0("shares its trough with ", shared_with, ", split by the trough's own shape; "), ""), ifelse(is.na(part_note), "", paste0(part_note, "; ")),
    ifelse(k %in% dup$k, "another row of the same name; ", ""))))
P$flags[P$flags == ""] <- NA_character_
U <- bind_rows(U)
out <- bind_rows(P |> transmute(key, name_id, name, src, forms, trough, part, lon, lat, place_basis, extent_km, extent_basis, agree = coalesce(agree, ""), n_agree,
                                 against = coalesce(against, ""), n_against = coalesce(n_against, 0L), shared_with, flags),
                 if (nrow(U)) U |> mutate(forms = fold(name), part = NA_character_) |> select(key, name_id, name, src, forms, trough, part, lon, lat, place_basis, extent_km, extent_basis, agree, n_agree, against, n_against, flags),
                 if (nrow(UP)) UP |> mutate(forms = NA_character_) |> select(key, name_id, name, src, forms, trough, part, lon, lat, place_basis, extent_km, extent_basis, agree, n_agree, against, n_against, flags)) |>
  mutate(step = 1L, class = "deep", kind = "deep", element = ifelse(trough == "none", NA_character_, paste0("isor:landform:trough:", trough)), version = VERSION)
vd <- ed |> filter(action %in% c("accept proposal", "reject proposal")) |> arrange(at) |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
if (!all(vd$link_to %in% out$key)) stop("verdicts on proposals that are not proposals now: ", paste(setdiff(vd$link_to, out$key), collapse = ", "))
out$verdict <- ifelse(out$key %in% vd$link_to, paste0(sub(" proposal", "ed", vd$action[match(out$key, vd$link_to)]), " by the maintainer, ", vd$at[match(out$key, vd$link_to)]), NA_character_)
out <- out |> select(key, step, class, name_id, name, src, forms, kind, element, trough, part, lon, lat, place_basis, extent_km, extent_basis, agree, n_agree, against, n_against, shared_with, flags, verdict, version)
if (!"key" %in% names(E)) E$key <- NA_character_
if (!"part" %in% names(E)) E$part <- NA_character_
E$key <- ifelse(is.na(E$key), key_of(E$name_id), E$key)
E <- E |> mutate(element = ifelse(trough == "none", NA_character_, paste0("isor:landform:trough:", trough)), version = VERSION) |>
  select(key, name_id, element, trough, part, group, member, outcome, value, detail, version)
S <- do.call(rbind, shapes); S$version <- VERSION
stopifnot(!anyDuplicated(out$key), all(E$key %in% out$key), all(S$key %in% out$key), nrow(out) == nrow(dp) + nrow(U) + nrow(UP),
          setequal(Reduce(union, list(P$trough[P$trough != "none"], U$trough, UP$trough)), tr$t))
pt <- st_as_sf(out, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
write_curated(pt, REF("place_name_proposal.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
write_curated(E, REF("place_name_proposal_evidence.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
write_curated(S, REF("place_name_proposal_shape.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
message(sprintf("proposals: %d (deeps %d, troughs no name takes %d, parts no name takes %d); on a trough %d, awaiting step 5 %d; witnesses agreeing 0/1/2/3+: %s; shared troughs %d; thalwegs %d; verdicts %d",
  nrow(out), nrow(P), nrow(U), nrow(UP), sum(out$trough != "none"), sum(out$trough == "none"), paste(table(factor(pmin(out$n_agree, 3), 0:3)), collapse = "/"),
  length(unique(P$trough[P$split])), sum(S$what == "thalweg"), sum(!is.na(out$verdict))))
