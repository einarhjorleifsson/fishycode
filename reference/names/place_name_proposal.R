# place_name_proposal.R — Claude's best proposal for each place name, from every witness at once (plan 081, decision 337:
# "the goal of this plan is that you come up with the best proposal to a placename. We would then go through that against
# other records in an interactive review"). Step 1 (plan 081 §7): the deeps over all Iceland, on ÍSOR's troughs; step 2: the
# ridge, edge, toe and tip names on ÍSOR's moraines (its rules in its own section below).
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
#         the deeps where read ($FISHYDATA/archive/2026-11-20-proposal-deeps/out/bjarni_deep_readings.csv; plan 081 §8 h); for
#         step 2 the texts read for its names ($FISHYDATA/archive/2026-11-20-proposal-moraines/out/text_moraine_readings.csv)
# Output: curated/reference/place_name_proposal.parquet - one row a proposal: `key` ("deep:<name id>", or
#         "deep:trough:<n>" for a trough no name of ours takes, "deep:trough:<n>:<part>" for a part of a shared trough no name
#         takes; step 2 "moraine:<name id>", "moraine:skippers:<spelling>" for a skippers' name no name of ours takes), `step`,
#         `class` (deep, moraine), `name_id`, `name`, `forms`, `kind`, `element` (the seabed feature, ÍSOR's id), `trough`,
#         `part` (of a shared trough, by its shape), `moraine` (step 2's, or "none"), `lon`, `lat` (the thing), `place_basis`, `extent_km`,
#         `extent_basis`, `whole`, `shared_with`, `agree` (the witnesses agreeing: charts, LMÍ, skippers, Bjarni; a copy
#         counted with its source), `against`, `flags`, `verdict`, `version`
#         curated/reference/place_name_proposal_evidence.parquet - one row a proposal, candidate element and witness: its
#         member (a chart scale, an LMÍ record and its source, the skippers' name, a statement of Bjarni's), its `group`,
#         `outcome` (agrees, disagrees, silent, mixed, ignored by the maintainer, copy of <group>), `value`, `detail`
#         curated/reference/place_name_proposal_shape.parquet - the proposals' extents (a trough, or its part; a moraine), the
#         deeps' thalwegs toward the fjord or bay they are named for, and the other moraines a step 2 name's tows run along
#         (`what` spread); WKB `geometry`, WGS 84
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
            DEMF, COAST, EF, if (file.exists(BJ)) BJ,
            if (file.exists(fd_path("archive", "2026-11-20-proposal-moraines", "out", "text_moraine_readings.csv"))) fd_path("archive", "2026-11-20-proposal-moraines", "out", "text_moraine_readings.csv"))
VERSION <- "081.2"   # step 2 (the moraines) added; 081.1, step 1 alone, frozen with the names' version 2
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

# Step 2: the moraines, and the ridge, edge, toe and tip names (plan 081 §7 step 2) ----------------------------------------
# The rules (Claude's, plan 081 §4, his to correct; study 2026-11-20-proposal-moraines):
# - a name of step 2 is a water name of ours, not a deep, one of whose words ends as the grammar's ridge, edge, toe, tip, horn,
#   heel, tail, slope, snout, neck or foot (plan 081 §4.2), its oblique forms too ("Suður á horni"); its kind that ending's;
# - its candidates are ÍSOR's moraines a witness puts it on, each within a moraine's corridor: the distance at which the share
#   of the skippers' tows running along their nearest moraine (within 20 degrees, 2/9 by chance) has fallen half way from
#   its largest to chance, measured below on every clean tow by distance band (5 km on 2026-11-20). No moraine is chained to
#   the next: the gaps between ÍSOR's pieces run evenly from 50 m to 10 km, no natural break (the study's script 03);
# - the charts agree with the moraine nearest a lettering within the corridor; LMÍ likewise by its records (a copy with its
#   source); the skippers with the moraine holding the largest share of the name's own tows within the corridor, two vessels
#   or more on it (its spellings joined, the definite article off; his ignored names out); namesakes' tows go to the namesake
#   nearest that moraine, and to none it lies beyond the namesakes' gap from (plan 081 §2.2: true families 10-90 km apart,
#   false 217-598 km; 150 km); the maintainer's word (his link, or his own name on a moraine) agrees with his moraine; the
#   texts read for step 2 (Bjarni's Andvari reports, the stored timarit.is pages) with the candidate nearest the place a
#   statement sets the name by, where there are two candidates or more, a depth with a moraine whose middle lies within it;
# - the proposal is the candidate with the most independent witnesses agreeing; ties, witnesses against and a single witness
#   flagged; its thing the moraine's middle (ÍSOR's point midway along it), its extent the moraine; no candidate: a volcanic
#   ridge waits for step 4, the rest for step 3 (a bank's edges and tips) or step 5;
# - a skippers' name of the grammar that no name of ours takes, two vessels or more on its moraine, is a proposal of its own
#   (key moraine:skippers:<its spelling folded, the article off>), one witness, where it names the moraine by either of two
#   comparisons, no threshold: it is the moraine's most concentrated name among all the skippers' names there (two vessels or
#   more), or more of its tows lie on the moraine than off every moraine. A broad name passes neither (Kolbeinseyjarhryggur, 1 %
#   of its tows on its moraine); the plurality alone dropped his own checks (Eldeyjarbankakantur 38 % on 143, 39 % off), the
#   mutual best alone a name a namesake beats on its moraine (Hællinn by Utan fótar); the study's script 05. His Accept writes
#   it as his own name there. A name of ours keeps the skippers' witness as the plan has it, flagged where it is broad or
#   another name is its moraine's most concentrated;
# - a name whose place lies off the shelf (beyond ÍSOR's shelf break; 726 of its 728 moraines lie on it) takes no moraine: a
#   ridge there, or a name in ÍSOR's volcanic ridges or systems, waits for step 4 (Reykjaneshryggur, lettered at 1:300 000 by
#   a moraine at the shelf's foot), the rest for step 3 or 5 (Hvalbakshalli, a bank's slope to the ocean).
lowsp <- function(x) gsub("[^a-zþæöðáéíóúý ]", " ", tolower(x))
G2 <- list(ridge = c("hryggur", "hryggurinn", "hrygg", "hryggnum", "hryggjar", "hryggir", "hryggirnir", "hryggjum", "kambur", "kamburinn", "kamb", "kambi", "kambinum"),
  edge = c("kantur", "kanturinn", "kant", "kanti", "kantinum", "kantinn", "kantar", "kantarnir", "köntum", "brún", "brúnin", "brúnina", "brúninni", "brúnir"),
  toe = c("tá", "táin", "tána", "tánni", "tær"), tip = c("tota", "totan", "totu", "totunni"), horn = c("horn", "hornið", "horni", "horninu", "hornin"),
  heel = c("hæll", "hællinn", "hæl", "hælnum"), tail = c("hali", "halinn", "hala", "halanum"), slope = c("halli", "hallinn", "halla", "hallanum"),
  snout = c("rani", "raninn", "rana"), neck = c("haft", "haftið", "hafti"), foot = c("fótur", "fóturinn", "fót", "fæti", "fætinum"))
re2 <- lapply(G2, function(f) paste0("(", paste(f, collapse = "|"), ")$"))
ending2 <- function(x) vapply(strsplit(lowsp(x), " +"), function(w) { w <- rev(w[nzchar(w)])
  for (a in w) for (e in names(re2)) if (grepl(re2[[e]], a)) return(e); NA_character_ }, "")
IND <- c("hrygur", "hrygir", "kambur", "kantur", "kantar", "brun", "brunir", "ta", "tota", "horn", "hael", "hali", "fotur", "rani", "haft")
canon <- function(k) vapply(k, function(x) { for (s in c("nir", "id", "in", "n")) if (endsWith(x, s)) { b <- substr(x, 1, nchar(x) - nchar(s))
  if (any(endsWith(b, IND))) return(b) }; x }, "", USE.NAMES = FALSE)                  # the definite article off
GAP_KM <- 150                                                                            # in the namesakes' gap, 90-217 km (plan 081 §2.2)
mo <- st_transform(sfx[sfx$kind == "moraine", ], 3057); mo$m <- sub("isor:landform:moraine:", "", mo$seabed_id)
mo$len_km <- as.numeric(st_length(mo)) / 1000
mv <- do.call(rbind, lapply(seq_len(nrow(mo)), function(i) { g <- st_line_sample(st_geometry(mo)[i], density = 1 / 100)
  xy <- if (st_is_empty(g[[1]])) st_coordinates(st_geometry(mo)[i])[, 1:2, drop = FALSE] else st_coordinates(g)[, 1:2, drop = FALSE]
  data.frame(m = mo$m[i], x = xy[, 1], y = xy[, 2]) }))
same <- c(mv$m[-1] == mv$m[-nrow(mv)], FALSE); prev <- c(FALSE, same[-length(same)])   # a vertex's bearing from its neighbours on the same moraine
dxm <- ifelse(same, c(mv$x[-1], NA), mv$x) - ifelse(prev, c(NA, mv$x[-nrow(mv)]), mv$x); dym <- ifelse(same, c(mv$y[-1], NA), mv$y) - ifelse(prev, c(NA, mv$y[-nrow(mv)]), mv$y)
mv$bear <- atan2(dxm, dym) * 180 / pi
near_mo <- function(lon, lat) { if (!length(lon)) return(data.frame(m = character(), d_km = numeric()))
  p <- st_coordinates(st_transform(st_as_sf(data.frame(lon, lat), coords = c("lon", "lat"), crs = 4326), 3057))
  nn <- RANN::nn2(as.matrix(mv[c("x", "y")]), p, k = 1); data.frame(m = mv$m[nn$nn.idx[, 1]], d_km = nn$nn.dists[, 1] / 1000) }
# every clean named tow of 200 m or more: its nearest moraine, the distance and the angle to it there
pj <- function(lo, la) st_coordinates(st_transform(st_as_sf(data.frame(lo, la), coords = c("lo", "la"), crs = 4326), 3057))
ta <- pj(twa$lon1, twa$lat1); tb <- pj(twa$lon2, twa$lat2); tl <- sqrt((tb[, 1] - ta[, 1])^2 + (tb[, 2] - ta[, 2])^2)
keep <- is.finite(tl) & tl > 200; t2 <- twa[keep, ]; ta <- ta[keep, , drop = FALSE]; tb <- tb[keep, , drop = FALSE]
nn <- RANN::nn2(as.matrix(mv[c("x", "y")]), cbind((ta[, 1] + tb[, 1]) / 2, (ta[, 2] + tb[, 2]) / 2), k = 1)
t2$m <- mv$m[nn$nn.idx[, 1]]; t2$d_km <- nn$nn.dists[, 1] / 1000
t2$angle <- abs(((atan2(tb[, 1] - ta[, 1], tb[, 2] - ta[, 2]) * 180 / pi - mv$bear[nn$nn.idx[, 1]]) + 90) %% 180 - 90)
BANDS <- c(0, 0.25, 0.5, 1, 2, 3, 5, 8, 12, 20, 50, Inf); CHANCE <- 20 / 90
al <- tapply(t2$angle <= 20, cut(t2$d_km, BANDS, right = FALSE), mean)
CORRIDOR <- BANDS[which(al < CHANCE + (max(al) - CHANCE) / 2)[1]]
message(sprintf("step 2: a moraine's corridor %g km (tows along their nearest moraine within 20 degrees: %s by distance band; chance %.2f)",
  CORRIDOR, paste(sprintf("%.2f", al), collapse = " "), CHANCE))
# the names of step 2: ours, and the skippers' of the grammar
n2 <- nm[nm$kind == "water" & !is.na(nm$lon) & !nm$id %in% dp$id, ]; n2$ending <- ending2(n2$name); n2 <- n2[!is.na(n2$ending), ]
n2$forms <- lapply(seq_len(nrow(n2)), function(i) { a <- c(n2$name[i], if (!is.na(n2$synonyms[i])) trimws(strsplit(n2$synonyms[i], "[;,]")[[1]]))
  k <- fold(a[nzchar(a)]); unique(c(k, canon(k))) })
dn <- unique(t2$name); de <- ending2(dn); t2$ending <- de[match(t2$name, dn)]
tg <- t2[!is.na(t2$ending) & !t2$k %in% ignored, ]; tg$c <- canon(tg$k)
conc <- function(t) { if (!nrow(t)) return(NULL)                                         # a name's tows on each moraine in the corridor
  s <- t[t$d_km <= CORRIDOR, ] |> group_by(m) |> summarise(n = n(), v = n_distinct(vid), .groups = "drop") |> mutate(share = n / nrow(t)) |> arrange(desc(share))
  list(all = nrow(t), v_all = n_distinct(t$vid), on = s, top = s$m[s$v >= 2][1], spell = paste(names(sort(table(t$name), decreasing = TRUE)), collapse = "; ")) }
cg <- lapply(split(tg, tg$c), conc)
uk <- unique(t2$k); t2$c <- canon(uk)[match(t2$k, uk)]                                 # every skippers' name, the article off where the grammar's
mtop <- t2[t2$d_km <= CORRIDOR & !t2$k %in% ignored, ] |> group_by(c, m) |> summarise(n = n(), v = n_distinct(vid), .groups = "drop") |>
  left_join(t2 |> count(c, name = "n_all"), by = "c") |> mutate(share = n / n_all) |> filter(v >= 2) |> group_by(m) |> arrange(desc(share), .by_group = TRUE) |>
  summarise(top_c = c[1], top_share = share[1], top_name = c[1], .groups = "drop")
spell_of <- function(cc) { x <- t2$name[t2$c == cc]; if (!length(x)) cc else names(sort(table(x), decreasing = TRUE))[1] }
mtop$top_name <- vapply(mtop$top_c, spell_of, "")
off_of <- function(t) mean(t$d_km > CORRIDOR)
mxy <- function(m) { j <- match(paste0("isor:landform:moraine:", m), sfx$seabed_id); c(sfx$lon[j], sfx$lat[j]) }
km_to <- function(lon, lat, m) { q <- mxy(m); sqrt(((q[1] - lon) * 111.32 * cos(lat * pi / 180))^2 + ((q[2] - lat) * 110.57)^2) }
# each skippers' group to a name of ours: its forms hold the group's spelling; of namesakes the nearest to the group's moraine
owner <- setNames(rep(NA_real_, length(cg)), names(cg)); why_none <- setNames(rep(NA_character_, length(cg)), names(cg))
for (cc in names(cg)) { hit <- which(vapply(n2$forms, function(f) cc %in% f, TRUE)); if (!length(hit)) next
  top <- cg[[cc]]$top; if (is.na(top)) { owner[cc] <- n2$id[hit[1]]; next }
  dk <- vapply(hit, function(i) km_to(n2$lon[i], n2$lat[i], top), 0); w <- hit[which.min(dk)]
  if (min(dk) > GAP_KM) why_none[cc] <- sprintf("its tows lie on moraine %s, %.0f km from it: another place of the name", top, min(dk)) else owner[cc] <- n2$id[w]
  for (i in setdiff(hit, w)) why_none[paste0(cc, "@", n2$id[i])] <- sprintf("its tows lie on moraine %s, by a namesake (%s, %.0f km nearer)", top, n2$name[w], km_to(n2$lon[i], n2$lat[i], top) - min(dk)) }
# the charts' letterings and LMÍ's records of the names of step 2
lt2 <- read.csv(file.path(V1, "letterings.csv"), encoding = "UTF-8"); lt2 <- lt2[lt2$feature %in% n2$id, ]; lt2 <- cbind(lt2, near_mo(lt2$lon, lt2$lat))
lr2 <- bind_rows(
  do.call(rbind, lapply(which(n2$src == "chart"), function(i) { u <- strsplit(coalesce(cj$uuids[match(n2$id[i], cj$feature)], ""), "\\s+")[[1]]
    s <- st0[st0$uuid %in% u, ]; if (nrow(s)) data.frame(name_id = n2$id[i], rec = s$uuid, source_ref = s$source_ref, lon = s$lon, lat = s$lat) })),
  do.call(rbind, lapply(which(n2$src == "lmi"), function(i) { s <- st0[st0$id == n2$id[i], ]
    if (nrow(s)) data.frame(name_id = n2$id[i], rec = s$uuid, source_ref = s$source_ref, lon = s$lon, lat = s$lat) })))
lr2 <- lr2[!is.na(lr2$lon), ]; lr2 <- cbind(lr2, near_mo(lr2$lon, lr2$lat)); lr2$group <- lmi_group(lr2$source_ref)
# his word: his latest link of a name to a moraine, and his own names on one
hl2 <- ed |> filter(action %in% c("link", "unlink")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup() |>
  filter(action == "link", grepl("^isor:landform:moraine:", link_to)) |> transmute(feature, m = sub("isor:landform:moraine:", "", link_to), at)
ow <- nm |> filter(src == "maintainer", grepl("^isor:landform:moraine:[0-9]+(;isor:landform:moraine:[0-9]+)*$", coalesce(seabed_members, "")))   # one or several
hw <- bind_rows(hl2, if (nrow(ow)) bind_rows(lapply(seq_len(nrow(ow)), function(i) data.frame(feature = ow$id[i],
  m = sub("isor:landform:moraine:", "", strsplit(ow$seabed_members[i], ";")[[1]]), at = "his own name"))))
# the texts read for step 2
TX <- fd_path("archive", "2026-11-20-proposal-moraines", "out", "text_moraine_readings.csv")
tx <- if (file.exists(TX)) read.csv(TX, encoding = "UTF-8") else data.frame(name = character(), sense = character())
tx <- tx[tx$sense %in% "name", , drop = FALSE]; tx$c <- if (nrow(tx)) canon(fold(tx$name)) else character()
judge_tx <- function(r, cands) {                                                         # the candidates a statement agrees with, or NA
  tgt <- trimws(strsplit(coalesce(r$target, ""), ";")[[1]]); tgt <- tgt[nzchar(tgt)]
  if (r$relation == "depth") { z <- fathom(coalesce(r$value, "")); if (is.null(z)) return(NA)
    zt <- sfx$top_depth_m[match(paste0("isor:landform:moraine:", cands), sfx$seabed_id)]; a <- cands[!is.na(zt) & zt >= z[1] & zt <= z[2]]
    return(structure(a, depth = TRUE)) }
  if (!r$relation %in% c("part_of", "on", "off", "adjoins", "between", "bearing", "distance") || !length(tgt) || length(cands) < 2) return(NA)
  xy <- if (r$relation == "between" && length(tgt) >= 2) { a <- place_xy(tgt[1]); b <- place_xy(tgt[2]); if (!nrow(a) || !nrow(b)) return(NA)
    data.frame(lon = (a$lon[1] + b$lon[1]) / 2, lat = (a$lat[1] + b$lat[1]) / 2) } else place_xy(tgt[1])
  if (!nrow(xy)) return(NA); cands[which.min(vapply(cands, function(m) min(km_to(xy$lon, xy$lat, m)), 0))] }
ev2 <- list(); add2 <- function(key, d, m, group, member, outcome, value = NA_character_, detail = NA_character_)
  ev2[[length(ev2) + 1]] <<- data.frame(key = key, name_id = d, moraine = m, group = group, member = member, outcome = outcome, value = value, detail = detail)
# a name he made by accepting a skippers' proposal (the page's `new` row on the moraine, citing the key) keeps that key
mk2 <- ed0[ed0$action == "new" & grepl("^isor:landform:moraine:", coalesce(ed0$link_to, "")) & grepl("\\(moraine:skippers:[a-z0-9]+\\)", coalesce(ed0$why, "")), ]
made2 <- data.frame(name_id = vapply(seq_len(nrow(mk2)), function(r) { j <- which(nm$src == "maintainer" & nm$seabed_members %in% mk2$link_to[r] & nm$name == mk2$name[r])
  if (length(j)) nm$id[j[1]] else NA_real_ }, 0), key = sub(".*\\((moraine:skippers:[a-z0-9]+)\\).*", "\\1", mk2$why))
made2 <- made2[!is.na(made2$name_id), ]
key2_of <- function(id) ifelse(id %in% made2$name_id, made2$key[match(id, made2$name_id)], paste0("moraine:", id))
for (i in seq_len(nrow(n2))) { d <- n2$id[i]; key <- key2_of(d)
  l <- lt2[lt2$feature == d, ]; lm <- lr2[lr2$name_id %in% d, ]; my <- names(owner)[owner %in% d]; sk <- if (length(my)) conc(tg[tg$c %in% my, ]) else NULL
  silent <- unname(c(why_none[intersect(names(why_none), c(my, n2$forms[[i]]))], why_none[paste0(n2$forms[[i]], "@", d)])); silent <- silent[!is.na(silent)]
  hwi <- hw[hw$feature == d, ]; txi <- tx[tx$c %in% canon(n2$forms[[i]]), , drop = FALSE]; own <- near_mo(n2$lon[i], n2$lat[i])
  cand <- unique(na.omit(c(l$m[l$d_km <= CORRIDOR], lm$m[lm$d_km <= CORRIDOR], if (!is.null(sk)) sk$top, hwi$m, if (own$d_km <= CORRIDOR) own$m)))
  jt <- if (nrow(txi)) lapply(seq_len(nrow(txi)), function(j) judge_tx(txi[j, ], cand)) else list()
  for (mm in c(cand, NA_character_)) { lab <- if (is.na(mm)) "none" else mm
    if (nrow(l)) { inn <- l$d_km <= CORRIDOR; a <- if (is.na(mm)) !any(inn) else any(inn & l$m == mm)
      add2(key, d, lab, "charts", "the charts' letterings", if (a) "agrees" else "disagrees",
           sprintf("%d of %d scales within %g km of it", if (is.na(mm)) sum(!inn) else sum(inn & l$m == mm), nrow(l), CORRIDOR),
           paste(sprintf("%s: moraine %s, %.1f km", sub("sjokort_", "", l$chart), l$m, l$d_km), collapse = "; ")) }
    for (j in seq_len(nrow(lm))) { inn <- lm$d_km[j] <= CORRIDOR; o <- if ((is.na(mm) && !inn) || (!is.na(mm) && inn && lm$m[j] == mm)) "agrees" else "disagrees"
      add2(key, d, lab, lm$group[j], paste0("LMÍ: ", lm$source_ref[j]), if (lm$group[j] == "LMÍ") o else paste0(o, " (a copy of the ", lm$group[j], ")"),
           sprintf("moraine %s, %.1f km", lm$m[j], lm$d_km[j]), lm$rec[j]) }
    if (length(silent) && is.null(sk)) add2(key, d, lab, "skippers", "the skippers' tows", paste0("silent (", silent[1], ")"))
    else if (!is.null(sk)) { s <- sk$on[sk$on$m %in% mm, ]
      o <- if (is.na(sk$top)) "silent (fewer than two vessels on any moraine)" else if (!is.na(mm) && sk$top == mm) "agrees" else "disagrees"
      add2(key, d, lab, "skippers", "the skippers' tows", o, sprintf("%.0f %% of its %d tows within %g km of it, %d vessels", 100 * coalesce(s$share[1], 0), sk$all, CORRIDOR, coalesce(s$v[1], 0L)), sk$spell) }
    for (j in seq_len(nrow(hwi))) add2(key, d, lab, "the maintainer", if (hwi$at[j] == "his own name") "his own name on the moraine" else paste0("his link, ", hwi$at[j]),
                                       if (!is.na(mm) && hwi$m[j] == mm) "agrees (his word)" else "disagrees", paste0("moraine ", hwi$m[j]))
    for (j in seq_len(nrow(txi))) { z <- jt[[j]]; grp <- if (grepl("^Bjarni", txi$source[j])) "Bjarni" else "the papers"
      placing <- txi$relation[j] %in% c("part_of", "on", "off", "adjoins", "between", "bearing", "distance")
      o <- if (identical(txi$basis[j], "inferred")) "silent (the reader inferred it)"
        else if (all(is.na(z))) { if (placing && length(cand) < 2) "silent (one candidate: a text's place cannot choose)" else if (placing) "silent (its place is not in LMÍ's names)"
          else if (txi$relation[j] == "depth") "silent (no depth to read)" else "silent (it places nothing)" }
        else if (isTRUE(attr(z, "depth"))) { if (!is.na(mm) && mm %in% z) "agrees (its depth)" else "silent (a depth outside)" } else if (!is.na(mm) && mm %in% z) "agrees" else "disagrees"
      add2(key, d, lab, grp, sprintf("%s %s, p. %s: %s", if (grp == "Bjarni") "Bjarni, Andvari" else coalesce(txi$title[j], "a stored timarit.is page"), txi$year[j], txi$page[j], txi$relation[j]),
           o, txi$value[j], txi$says[j]) } } }
# the skippers' names no name of ours takes: a proposal each, its moraine their own
# (a spelling of ours whose tows lie beyond the namesakes' gap is another place of the name: a proposal of its own)
orph <- names(cg)[is.na(owner[names(cg)]) & !paste0("moraine:skippers:", names(cg)) %in% made2$key]
orph <- orph[vapply(orph, function(cc) { s <- cg[[cc]]; if (is.na(s$top) || s$v_all < 2) return(FALSE)
  mutual <- identical(mtop$top_c[match(s$top, mtop$m)], cc); plural <- s$on$share[s$on$m == s$top] > off_of(tg[tg$c == cc, ]); mutual || plural }, TRUE)]
O2 <- bind_rows(lapply(orph, function(cc) { s <- cg[[cc]]; top <- s$top; o <- s$on[s$on$m == top, ]; key <- paste0("moraine:skippers:", cc)
  add2(key, NA_real_, top, "skippers", "the skippers' tows", "agrees", sprintf("%.0f %% of its %d tows within %g km of it, %d vessels", 100 * o$share, s$all, CORRIDOR, o$v), s$spell)
  txo <- tx[tx$c %in% cc, , drop = FALSE]                                                  # what the texts say of it (one candidate: a depth can agree)
  for (j in seq_len(nrow(txo))) { grp <- if (grepl("^Bjarni", txo$source[j])) "Bjarni" else "the papers"; z <- judge_tx(txo[j, ], top)
    oo <- if (identical(txo$basis[j], "inferred")) "silent (the reader inferred it)" else if (isTRUE(attr(z, "depth"))) { if (top %in% z) "agrees (its depth)" else "silent (a depth outside)" }
      else if (txo$relation[j] %in% c("part_of", "on", "off", "adjoins", "between", "bearing", "distance")) "silent (one candidate: a text's place cannot choose)" else "silent (it places nothing)"
    add2(key, NA_real_, top, grp, sprintf("%s %s, p. %s: %s", if (grp == "Bjarni") "Bjarni, Andvari" else coalesce(txo$title[j], "a stored timarit.is page"), txo$year[j], txo$page[j], txo$relation[j]),
         oo, txo$value[j], txo$says[j]) }
  data.frame(key = key, name_id = NA_real_, name = strsplit(s$spell, "; ")[[1]][1], src = "skippers", forms = cc, kind = ending2(strsplit(s$spell, "; ")[[1]][1]), moraine = top,
             agree = "skippers", n_agree = 1L, against = "", n_against = 0L, tie = FALSE,
             flags0 = sprintf("a skippers' name no name of ours takes, %.0f %% of its %d tows on it, %d vessels: one witness", 100 * o$share, s$all, o$v)) }))
E2 <- bind_rows(ev2)
g2 <- E2 |> mutate(ag = grepl("^agrees", outcome), dis = grepl("^disagrees", outcome)) |> group_by(key, name_id, moraine, group) |>
  summarise(ag = any(ag), dis = any(dis), .groups = "drop") |> group_by(key, name_id, moraine) |>
  summarise(agree = paste(sort(group[ag]), collapse = ", "), n_agree = sum(ag), against = paste(sort(group[dis & !ag]), collapse = ", "), n_against = sum(dis & !ag), .groups = "drop")
pk2 <- g2 |> group_by(key) |> arrange(desc(n_agree), n_against, moraine == "none", .by_group = TRUE) |>
  mutate(tie = n() > 1 & n_agree[1] > 0 & n_agree[1] == dplyr::nth(n_agree, 2, default = -1L) & n_against[1] == dplyr::nth(n_against, 2, default = -1L)) |> slice_head(n = 1) |> ungroup()
P2 <- n2 |> transmute(key = key2_of(id), name_id = id, name, src, forms = vapply(forms, paste, "", collapse = "; "), kind = ending, lon0 = lon, lat0 = lat) |>
  left_join(pk2 |> select(-name_id), by = "key") |> mutate(moraine = ifelse(is.na(moraine) | coalesce(n_agree, 0L) == 0, "none", moraine), n_agree = coalesce(n_agree, 0L),
  agree = ifelse(moraine == "none", "", coalesce(agree, "")), against = ifelse(moraine == "none", "", coalesce(against, "")), n_against = ifelse(moraine == "none", 0L, coalesce(n_against, 0L)), tie = coalesce(tie, FALSE))
O2 <- O2 |> select(-agree, -n_agree, -against, -n_against, -tie) |> left_join(pk2 |> select(key, agree, n_agree, against, n_against, tie), by = "key")
O2$flags0 <- sub("one witness$", ifelse(O2$n_agree > 1, paste0("its witnesses ", O2$agree), "one witness"), O2$flags0)
P2 <- bind_rows(P2, O2 |> mutate(lon0 = NA_real_, lat0 = NA_real_))
# the thing and the extent: the moraine's middle and the moraine; the spread: the other moraines its skippers' tows run along
volc <- st_union(st_make_valid(st_transform(sfx[sfx$kind %in% c("ridge", "volcanic system"), ], 3057)))
shelf <- st_make_valid(st_transform(sfx[sfx$kind == "shelf break", ], 3057))
P2$off_shelf <- if (nrow(P2)) lengths(st_intersects(st_transform(st_as_sf(data.frame(lon = coalesce(P2$lon0, 0), lat = coalesce(P2$lat0, 0)), coords = c("lon", "lat"), crs = 4326), 3057), shelf)) == 0 & !is.na(P2$lon0) else logical()
P2$in_volc <- if (nrow(P2)) lengths(st_intersects(st_transform(st_as_sf(data.frame(lon = coalesce(P2$lon0, 0), lat = coalesce(P2$lat0, 0)), coords = c("lon", "lat"), crs = 4326), 3057), volc)) > 0 & !is.na(P2$lon0) else logical()
P2$step4 <- P2$in_volc | (P2$off_shelf & P2$kind == "ridge")
vg <- which((P2$in_volc | P2$off_shelf) & P2$moraine != "none")                         # off the shelf or volcanic: no moraine, whatever its witnesses
P2$moraine[vg] <- "none"; P2$n_agree[vg] <- 0L; P2$agree[vg] <- ""; P2$against[vg] <- ""; P2$n_against[vg] <- 0L; P2$tie[vg] <- FALSE
S2 <- list(); P2$lon <- P2$lon0; P2$lat <- P2$lat0; P2$place_basis <- "its place as the names have it (no moraine proposed)"; P2$extent_km <- NA_real_; P2$extent_basis <- NA_character_
for (i in which(P2$moraine != "none")) { mm <- P2$moraine[i]; j <- match(paste0("isor:landform:moraine:", mm), sfx$seabed_id); k <- match(mm, mo$m)
  P2$lon[i] <- sfx$lon[j]; P2$lat[i] <- sfx$lat[j]; P2$extent_km[i] <- round(mo$len_km[k], 3)
  P2$place_basis[i] <- sprintf("the middle of ÍSOR's moraine %s (a point midway along it), %s m (Claude's proposal, plan 081 step 2)", mm, format(sfx$top_depth_m[j]))
  P2$extent_basis[i] <- sprintf("ÍSOR's moraine %s, %.1f km long", mm, mo$len_km[k])
  his <- hw$m[hw$feature %in% P2$name_id[i]]
  if (length(his) > 1 && mm %in% his) {                                                    # his word names several: they are its extent
    kk <- match(his, mo$m); u <- st_union(st_geometry(mo[kk, ])); b <- st_bbox(u); P2$extent_km[i] <- round(max(b$xmax - b$xmin, b$ymax - b$ymin) / 1000, 3)
    P2$extent_basis[i] <- sprintf("ÍSOR's moraines %s, %.1f km along the longer side of their box (his word)", paste(his, collapse = " and "), P2$extent_km[i])
    S2[[length(S2) + 1]] <- st_sf(key = P2$key[i], what = "extent", basis = sprintf("ÍSOR's moraines (%s), his word (Claude's proposal)", paste(paste0("isor:landform:moraine:", his), collapse = "; ")),
                                  geometry = st_transform(u, 4326))
  } else S2[[length(S2) + 1]] <- st_sf(key = P2$key[i], what = "extent", basis = sprintf("ÍSOR's moraine (isor:landform:moraine:%s) (Claude's proposal)", mm), geometry = st_transform(st_geometry(mo[k, ]), 4326)) }
for (i in seq_len(nrow(P2))) { my <- if (is.na(P2$name_id[i])) P2$forms[i] else names(owner)[owner %in% P2$name_id[i]]; if (!length(my)) next
  s <- conc(tg[tg$c %in% my, ]); if (is.null(s)) next; sp <- s$on$m[s$on$v >= 2 & s$on$m != P2$moraine[i]]; if (!length(sp)) next
  S2[[length(S2) + 1]] <- st_sf(key = P2$key[i], what = "spread", basis = sprintf("ÍSOR's moraine %s: %.0f %% of the name's tows within %g km, %d vessels (the skippers' spread)",
    sp, 100 * s$on$share[match(sp, s$on$m)], CORRIDOR, s$on$v[match(sp, s$on$m)]), geometry = st_transform(st_geometry(mo[match(sp, mo$m), ]), 4326)) }
dup2 <- P2 |> filter(moraine != "none") |> group_by(moraine) |> filter(n_distinct(coalesce(as.character(name_id), key)) > 1) |>
  summarise(names = paste(unique(name), collapse = "; "), .groups = "drop")
P2$shared_with <- vapply(seq_len(nrow(P2)), function(i) { s <- dup2$names[dup2$moraine == P2$moraine[i]]; if (!length(s)) NA_character_ else paste(setdiff(strsplit(s, "; ")[[1]], P2$name[i]), collapse = "; ") }, "")
sk_note <- vapply(seq_len(nrow(P2)), function(i) { if (is.na(P2$name_id[i])) return(NA_character_); my <- names(owner)[owner %in% P2$name_id[i]]; if (!length(my)) return(NA_character_)
  s <- conc(tg[tg$c %in% my, ]); if (is.null(s) || is.na(s$top)) return(NA_character_); sh <- s$on$share[s$on$m == s$top]; off <- off_of(tg[tg$c %in% my, ]); j <- match(s$top, mtop$m)
  paste(c(if (off > sh) sprintf("the skippers' tows mostly off every moraine (%.0f %% off, %.0f %% on %s)", 100 * off, 100 * sh, s$top),
          if (!is.na(j) && !mtop$top_c[j] %in% my) sprintf("moraine %s's most concentrated skippers' name is %s (%.0f %%)", s$top, mtop$top_name[j], 100 * mtop$top_share[j])), collapse = "; ") }, "")
sk_note[!is.na(sk_note) & !nzchar(sk_note)] <- NA_character_
his2 <- vapply(seq_len(nrow(P2)), function(i) { h <- hw[hw$feature %in% P2$name_id[i], ]; if (!nrow(h)) NA_character_
  else if (P2$moraine[i] %in% h$m) sprintf("his word puts it on moraine %s", paste(unique(h$m), collapse = " and ")) else sprintf("his word puts it on moraine %s, not %s", paste(unique(h$m), collapse = " and "), P2$moraine[i]) }, "")
P2$flags <- trimws(paste0(
  ifelse(!is.na(P2$flags0), paste0(P2$flags0, "; "), ""),
  ifelse(P2$moraine == "none" & P2$step4, "no moraine proposed: an ocean or volcanic ridge, awaits step 4; ",
    ifelse(P2$moraine == "none" & P2$off_shelf, "no moraine proposed: off the shelf, awaits step 3 or 5; ", ifelse(P2$moraine == "none", "no moraine proposed: awaits step 3 (a bank's edges and tips) or step 5; ", ""))),
  ifelse(P2$moraine != "none" & P2$n_agree == 1 & is.na(P2$flags0), "one witness only; ", ""), ifelse(P2$n_against > 0 & P2$n_agree > 0, paste0("against it: ", P2$against, "; "), ""),
  ifelse(P2$tie, "a tie between moraines; ", ""), ifelse(!is.na(P2$shared_with) & nzchar(P2$shared_with), paste0("on the same moraine: ", P2$shared_with, "; "), ""),
  ifelse(!is.na(his2), paste0(his2, "; "), ""), ifelse(!is.na(sk_note), paste0(sk_note, "; "), "")))
P2$flags[P2$flags == ""] <- NA_character_
out2 <- P2 |> transmute(key, step = 2L, class = "moraine", name_id, name, src, forms, kind, element = ifelse(moraine == "none", NA_character_, paste0("isor:landform:moraine:", moraine)),
  trough = NA_character_, part = NA_character_, moraine, lon, lat, place_basis, extent_km, extent_basis, agree, n_agree, against, n_against, shared_with, flags, version = VERSION)
stopifnot(!anyDuplicated(out2$key), all(E2$key %in% out2$key), nrow(out2) == nrow(n2) + nrow(O2))
message(sprintf("step 2: %d proposals (names of ours %d, the skippers' %d); on a moraine %d, none %d (step 4 %d); witnesses agreeing 0/1/2/3+: %s",
  nrow(out2), nrow(n2), nrow(O2), sum(out2$moraine != "none"), sum(out2$moraine == "none"), sum(P2$moraine == "none" & P2$step4),
  paste(table(factor(pmin(out2$n_agree, 3), 0:3)), collapse = "/")))
out <- bind_rows(out |> mutate(moraine = NA_character_), out2)
vd <- ed |> filter(action %in% c("accept proposal", "reject proposal")) |> arrange(at) |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
if (!all(vd$link_to %in% out$key)) stop("verdicts on proposals that are not proposals now: ", paste(setdiff(vd$link_to, out$key), collapse = ", "))
out$verdict <- ifelse(out$key %in% vd$link_to, paste0(sub(" proposal", "ed", vd$action[match(out$key, vd$link_to)]), " by the maintainer, ", vd$at[match(out$key, vd$link_to)]), NA_character_)
out <- out |> select(key, step, class, name_id, name, src, forms, kind, element, trough, part, moraine, lon, lat, place_basis, extent_km, extent_basis, agree, n_agree, against, n_against, shared_with, flags, verdict, version)
if (!"key" %in% names(E)) E$key <- NA_character_
if (!"part" %in% names(E)) E$part <- NA_character_
E$key <- ifelse(is.na(E$key), key_of(E$name_id), E$key)
E <- E |> mutate(element = ifelse(trough == "none", NA_character_, paste0("isor:landform:trough:", trough)), version = VERSION) |>
  select(key, name_id, element, trough, part, group, member, outcome, value, detail, version)
E <- bind_rows(E |> mutate(moraine = NA_character_), E2 |> mutate(element = ifelse(moraine == "none", NA_character_, paste0("isor:landform:moraine:", moraine)),
  trough = NA_character_, part = NA_character_, version = VERSION)) |> select(key, name_id, element, trough, part, moraine, group, member, outcome, value, detail, version)
S <- rbind(do.call(rbind, shapes), do.call(rbind, S2)); S$version <- VERSION
stopifnot(!anyDuplicated(out$key), all(E$key %in% out$key), all(S$key %in% out$key), nrow(out) == nrow(dp) + nrow(U) + nrow(UP) + nrow(out2),
          setequal(Reduce(union, list(P$trough[P$trough != "none"], U$trough, UP$trough)), tr$t))
pt <- st_as_sf(out, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
write_curated(pt, REF("place_name_proposal.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
write_curated(E, REF("place_name_proposal_evidence.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
write_curated(S, REF("place_name_proposal_shape.parquet"), inputs = INPUTS, script = "reference/names/place_name_proposal.R", stamps = c("fd.version" = VERSION))
message(sprintf("step 1 proposals: %d (deeps %d, troughs no name takes %d, parts no name takes %d); on a trough %d, awaiting step 5 %d; witnesses agreeing 0/1/2/3+: %s; shared troughs %d; thalwegs %d; verdicts %d",
  sum(out$step == 1), nrow(P), nrow(U), nrow(UP), sum(out$trough != "none", na.rm = TRUE), sum(out$trough == "none", na.rm = TRUE), paste(table(factor(pmin(out$n_agree[out$step == 1], 3), 0:3)), collapse = "/"),
  length(unique(P$trough[P$split])), sum(S$what == "thalweg"), sum(!is.na(out$verdict))))
