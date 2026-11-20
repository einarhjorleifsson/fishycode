# trackwell_candidate.R — Trackwell's names in an open region, each in one outcome; a candidate a name only by the
# maintainer's yes on the page (plan 080 ask n, decision 336: "Candidates, my yes"; public since decision 335).
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/names/marine_name.R, outside the targets flow.
#
# Input:  staging/ornefni/trackwell_haul.parquet (sources/ornefni/trackwell_haul.R: Trackwell's named tows), curated/reference/
#         place_name_region.parquet (the open regions), seabed_feature.parquet (ÍSOR's craters, guyots and seamounts),
#         marine_name.parquet (the names now: a Trackwell name already among them is a witness), overrides/marine_name_edits.csv
#         (his `accept` and `reject` rows, the candidate's key in `link_to`; his `ignore` rows, "trackwell:<spelling joined>"
#         in `link_to`, a name of the skippers' set aside in every region)
# Output: curated/reference/marine_name_candidate.parquet - one row a Trackwell name (spellings joined) with a tow in an open
#         region: `key` ("trackwell:<region>:<spelling joined>"), `region`, `name` (its commonest spelling), `spellings`, its
#         tows and vessels there and in all, `share` (its tows there over all its tows), `lon`, `lat` (its place: ÍSOR's
#         feature, else its tows' centre), `place_basis`, `seabed_id`, `outcome`, `verdict` (his, if any)
#
# The rule (the named-features study's 120 made simple; Claude's choices, his to correct):
# - a tow counts in a region when its middle lies there; "FROM SHIP" and tows dated outside 2003-2022 left out;
# - spellings joined: case and accents aside, every character but letters and digits dropped, a doubled letter single (the
#   maintainer's go-ahead, 2026-11-19: Pínu Littli Banki is LMÍ's Pínulitlibanki);
# - each vessel one vote: the tows' centre is the median of each vessel's own median tow middle;
# - outcomes, in order: already a name (the same spelling among the names whose thing lies in the region); one vessel (fewer
#   than two vessels there); carried in (fewer than 80 % of its tows there); a candidate on a feature (ÍSOR's crater, guyot or
#   seamount top within 3 km of its tows' centre, the shallowest); a candidate, no feature. His verdict, the latest of a key,
#   stands over the rule's outcome; a name he ignores (`ignore`, all its spellings, every region) is "ignored by the
#   maintainer" before any rule, kept in the table and never a candidate (the maintainer, 2026-11-19: "All skippers registry
#   of "Skerjadýpi" should be ignored", "also Skerjadjúp"). The tows never place a name (the maintainer: the trawls tow the flanks); the centre is shown
#   only where no feature is near.
# Run from the repo root: Rscript reference/names/trackwell_candidate.R. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
TW <- fd_staging("ornefni", "trackwell_haul.parquet"); EF <- "overrides/marine_name_edits.csv"
INPUTS <- c(TW, REF("place_name_region.parquet"), REF("seabed_feature.parquet"), REF("marine_name.parquet"), EF)
fold <- function(x) gsub("(.)\\1+", "\\1", gsub("[^a-z0-9]", "", tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))))
# a name in another case (Myrkur and Myrkri): one folded spelling the other's but for its last two letters at most, the two
# within 5 km, is the same name
stem_same <- function(a, b) { n <- pmin(nchar(a), nchar(b)); n >= 4 & substr(a, 1, n - 2) == substr(b, 1, n - 2) & abs(nchar(a) - nchar(b)) <= 2 }

regs <- read_curated_sf(REF("place_name_region.parquet")); regs <- regs[regs$open, ]
tw <- as.data.frame(nanoparquet::read_parquet(TW)) |>
  filter(!name_placeholder, !time_suspect, !is.na(lon1), !is.na(lat1), !is.na(lon2), !is.na(lat2), !is.na(name), nzchar(name)) |>
  mutate(lon = (lon1 + lon2) / 2, lat = (lat1 + lat2) / 2, key0 = fold(name))
all_by_key <- tw |> count(key0, name = "tows_all")
p <- st_as_sf(tw[c("lon", "lat")], coords = c("lon", "lat"), crs = 4326)
hit <- st_intersects(p, regs); tw$region <- vapply(hit, function(z) if (length(z)) regs$region[z[1]] else NA_character_, "")
rt <- tw[!is.na(tw$region), ]

sfx <- read_curated_sf(REF("seabed_feature.parquet"))
feat <- st_drop_geometry(sfx) |> filter(kind %in% c("crater", "guyot", "point", "seamount"))
f3 <- st_transform(st_as_sf(feat, coords = c("lon", "lat"), crs = 4326), 3057)
nm <- as.data.frame(nanoparquet::read_parquet(REF("marine_name.parquet")))
nmp <- st_as_sf(nm[c("lon", "lat")], coords = c("lon", "lat"), crs = 4326)
nm$region <- vapply(st_intersects(nmp, regs), function(z) if (length(z)) regs$region[z[1]] else NA_character_, "")
have <- nm |> filter(!is.na(region)) |> transmute(region, n = name, s = synonyms, lon, lat) |>
  rowwise() |> reframe(region, lon, lat, k = fold(c(n, if (!is.na(s)) strsplit(s, ";\\s*")[[1]]))) |> distinct()

cand <- rt |> group_by(region, key0) |>
  summarise(name = names(sort(table(name), decreasing = TRUE))[1], spellings = paste(sort(unique(name)), collapse = "; "),
            tows = n(), vessels = n_distinct(vid), .groups = "drop") |>
  left_join(all_by_key, by = "key0") |> mutate(share = round(tows / tows_all, 3))
ctr <- rt |> group_by(region, key0, vid) |> summarise(lon = median(lon), lat = median(lat), .groups = "drop") |>
  group_by(region, key0) |> summarise(clon = median(lon), clat = median(lat), .groups = "drop")
cand <- cand |> left_join(ctr, by = c("region", "key0"))
c3 <- st_transform(st_as_sf(cand[c("clon", "clat")], coords = c("clon", "clat"), crs = 4326), 3057)
ed <- read.csv(EF, encoding = "UTF-8")
if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
ig <- ed |> filter(action == "ignore") |> arrange(at) |> group_by(link_to) |> slice_head(n = 1) |> ungroup() |>
  mutate(key0 = sub("^trackwell:", "", link_to))
if (!all(grepl("^trackwell:[a-z0-9]+$", ig$link_to)) || !all(ig$key0 %in% tw$key0))
  stop("ignored names that are not Trackwell's: ", paste(setdiff(ig$link_to, paste0("trackwell:", tw$key0)), collapse = ", "))
near <- st_is_within_distance(c3, f3, 3000)
pick <- vapply(near, function(z) if (length(z)) z[order(feat$top_depth_m[z], na.last = TRUE)[1]] else NA_integer_, 0L)
cand <- cand |> mutate(
  key = paste0("trackwell:", region, ":", key0),
  seabed_id = feat$seabed_id[pick], lon = ifelse(is.na(pick), clon, feat$lon[pick]), lat = ifelse(is.na(pick), clat, feat$lat[pick]),
  place_basis = ifelse(is.na(pick), "its tows' centre, each vessel one vote (no feature within 3 km; a place to pin, not a witness)",
                       sprintf("ÍSOR's %s %s, the shallowest within 3 km of its tows' centre", feat$kind[pick], feat$label[pick])),
  near_stem = vapply(seq_len(n()), function(i) { h <- have[have$region == region[i], ]
    if (!nrow(h)) return(FALSE)
    d <- sqrt(((h$lon - clon[i]) * 111.32 * cos(clat[i] * pi / 180))^2 + ((h$lat - clat[i]) * 110.57)^2)
    any(stem_same(h$k, key0[i]) & d <= 5) }, logical(1)),
  outcome = case_when(key0 %in% ig$key0 ~ "ignored by the maintainer",
                      paste(region, key0) %in% paste(have$region, have$k) | near_stem ~ "already a name",
                      vessels < 2 ~ "one vessel",
                      share < 0.8 ~ "carried in",
                      !is.na(pick) ~ "a candidate on a feature",
                      TRUE ~ "a candidate, no feature"))
vd <- ed |> filter(action %in% c("accept", "reject")) |> arrange(at) |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
if (!all(vd$link_to %in% cand$key)) stop("verdicts on candidates that are not candidates now: ", paste(setdiff(vd$link_to, cand$key), collapse = ", "))
both <- vd$link_to[vd$action == "accept" & vd$link_to %in% cand$key[cand$key0 %in% ig$key0]]
if (length(both)) stop("accepted and ignored: ", paste(both, collapse = ", "))
cand$verdict <- ifelse(cand$key %in% vd$link_to, paste0(vd$action[match(cand$key, vd$link_to)], "ed by the maintainer, ", vd$at[match(cand$key, vd$link_to)]), NA_character_)
cand$verdict <- ifelse(cand$key0 %in% ig$key0, paste0("ignored by the maintainer, ", ig$at[match(cand$key0, ig$key0)]), cand$verdict)
out <- cand |> select(key, region, name, spellings, tows, vessels, tows_all, share, lon, lat, place_basis, seabed_id, outcome, verdict)
stopifnot(!anyDuplicated(out$key), !anyNA(out$outcome), sum(out$tows) == nrow(rt))
write_curated(st_as_sf(out, coords = c("lon", "lat"), crs = 4326, remove = FALSE), REF("marine_name_candidate.parquet"),
              inputs = INPUTS, script = "reference/names/trackwell_candidate.R", stamps = c("fd.version" = "2"))
print(knitr::kable(count(out, region, outcome), caption = "Trackwell's names in the open regions"))
message(sprintf("tows in open regions: %d of %d; names: %d; verdicts: %d", nrow(rt), nrow(tw), nrow(out), sum(!is.na(out$verdict))))
