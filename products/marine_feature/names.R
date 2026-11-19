# names.R — marine_feature as one file for ogis's og_names(): the names of the sea charts, LMÍ and ÍSOR, the aids to
# navigation and the wrecks, a row each, in og_names()'s columns, with a data dictionary for the page's labels and
# fishycode's fd.* stamps. Carried by ogisdata, MFRI's internal package, and named on one computer by OGIS_NAMES (plan
# 078 §3.9, steps 6-7; its asks i-k, the maintainer, 2026-11-19: an angle, "Hold on - all wrecks go in", all three types).
# Internal: the charts' names (Landhelgisgæslan's), the wrecks known from internal lists (flagged `internal`).
#
# Input:  $FISHYDATA/curated/reference/marine_feature.parquet (reference/marine_feature.R, decision 332)
#         $FISHYDATA/curated/reference/marine_name_extent.parquet (reference/names/marine_name.R: LMÍ's and ÍSOR's areas)
# Output: $FISHYDATA/products/marine_feature/names.parquet (GeoParquet), one row per row of marine_feature (27,305):
#         name (empty for a nameless aid or wreck, which og_names() then leaves undrawn and unfound); label_lon, label_lat
#         (its place); geometry (a name's area or line, LMÍ's or ÍSOR's, where one is known); min_zoom (the zoom it
#         deserves); level 1-4 and n (its rank and, within it, its extent); angle (degrees counter-clockwise from level,
#         og_text()'s); type, kind and the rest a click shows; KV metadata `data_dict` and the fd.* stamps
#
# - `level`: a name by its extent, 1 from 50 km, 2 from 10 km, 3 from 1 km, else 4 (Claude's proposal, plan 078 §3.9);
#   an aid or a wreck 4. `n`: a name's extent in km (version 1's priority turned round), so the larger is placed first
#   within a level; an aid or a wreck 0.
# - `angle` is marine_feature's `rotate_deg` turned round: MapLibre's rotation is clockwise, og_text()'s counter-clockwise.
# Run from the fishycode root, after reference/marine_feature.R and its check (a few seconds):
#   Rscript products/marine_feature/names.R
# then ogisdata's data-raw/files.R copies it into the package. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
source("R/paths.R")
source("R/write_curated.R")   # read_curated_sf(), and the fd.* stamps (.curated_kv); the file is not curated

mf_path <- fd_path("curated", "reference", "marine_feature.parquet")
ex_path <- fd_path("curated", "reference", "marine_name_extent.parquet")
out <- fd_path("products", "marine_feature", "names.parquet")
stopifnot(file.exists(mf_path), file.exists(ex_path))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)

mf <- st_drop_geometry(read_curated_sf(mf_path))
ex <- read_curated_sf(ex_path)

# A name's area: its LMÍ or ÍSOR extents (areas and lines), one geometry a name ------------------------------------------
ar <- ex[ex$what == "extent", ] |> mutate(id = paste0("name:", feature)) |> group_by(id) |>
  summarise(geometry = st_union(geometry), .groups = "drop")
geom <- st_geometry(ar)[match(mf$id, ar$id)]

d <- mf |> transmute(
  name = na_if(name, ""), label_lon = round(lon, 6), label_lat = round(lat, 6),
  min_zoom = z_rule,
  level = case_when(type != "name" ~ 4L, is.na(extent_km) ~ 4L, extent_km >= 50 ~ 1L, extent_km >= 10 ~ 2L,
                    extent_km >= 1 ~ 3L, TRUE ~ 4L),
  n = if_else(type == "name", round(-priority, 3), 0),
  angle = round(-rotate_deg, 2),
  type, kind, source = src, class, synonyms,
  extent_km = round(extent_km, 3), lies_in = mf$name[match(holder, mf$id)], on_feature = mf$name[match(on_feature, mf$id)],
  place_basis, zoom_basis = z_rule_basis, internal, flags, id)

# The dictionary: the page's labels for what a click shows --------------------------------------------------------------
dict <- paste(
  "columns:",
  "  - {name: name, label: Name}",
  "  - {name: type, label: Type, values: {name: place name, aid: aid to navigation, wreck: wreck}}",
  "  - {name: kind, label: Kind}",
  "  - {name: source, label: Source, values: {chart: the sea charts, lmi: LMÍ (IS 50V), isor: ÍSOR's seabed map, aid: the aid list, wreck: the wreck list}}",
  "  - {name: class, label: Class}",
  "  - {name: synonyms, label: Also called}",
  "  - {name: extent_km, label: Extent, units: km}",
  "  - {name: lies_in, label: Lies in}",
  "  - {name: on_feature, label: On}",
  "  - {name: place_basis, label: Placed by}",
  "  - {name: zoom_basis, label: Shown from}",
  "  - {name: internal, label: Known from internal lists only}",
  "  - {name: flags, label: Flags}",
  "  - {name: id, label: Id in marine_feature}",
  sep = "\n")

# Write: GeoParquet by DuckDB's spatial extension, the stamps and the dictionary in its metadata ------------------------
con <- DBI::dbConnect(duckdb::duckdb())
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
invisible(DBI::dbExecute(con, "INSTALL spatial; LOAD spatial"))
q <- function(x) DBI::dbQuoteString(con, x)
w <- d
w$wkb <- blob::as_blob(lapply(seq_along(geom), function(i) {
  g <- geom[i]; if (is.null(g[[1]]) || st_is_empty(g)) NULL else unclass(st_as_binary(g, EWKB = FALSE))[[1]] }))
duckdb::duckdb_register(con, "nm", w)
sql <- "SELECT * EXCLUDE (wkb), CASE WHEN wkb IS NULL THEN NULL ELSE ST_GeomFromWKB(wkb) END AS geometry FROM nm"
ds <- DBI::dbGetQuery(con, sprintf("DESCRIBE %s", sql))
kv <- c(.curated_kv("products/marine_feature/names.R", nrow(d),
                    substr(digest_string(paste(ds$column_name, ds$column_type, collapse = "|")), 1, 16),
                    inputs = c(mf_path, ex_path)),
        data_dict = dict)
meta <- paste(sprintf("%s: %s", q(names(kv)), q(unname(kv))), collapse = ", ")
tmp <- paste0(out, ".partial")
unlink(tmp)
invisible(DBI::dbExecute(con, sprintf("COPY (%s ORDER BY level, n DESC, name) TO %s (FORMAT parquet, COMPRESSION zstd, KV_METADATA {%s})",
                                      sql, q(tmp), meta)))

# The rows are marine_feature's, or nothing is replaced
chk <- DBI::dbGetQuery(con, sprintf(
  "SELECT count(*) AS rows, count(DISTINCT id) AS ids, count(geometry) AS areas, count(name) AS named,
          sum((type = 'wreck')::INT) AS wrecks, sum((type = 'wreck' AND internal)::INT) AS internal FROM read_parquet(%s)", q(tmp)))
if (chk$rows != nrow(mf) || chk$ids != nrow(mf) || chk$wrecks != sum(mf$type == "wreck") ||
    chk$internal != sum(mf$internal)) {
  unlink(tmp)
  stop("names.R: the file written is not marine_feature's rows", call. = FALSE)
}
invisible(file.rename(tmp, out))
cat(sprintf("%s: %s rows (%s named, %s with an area; wrecks %d, %d internal), %.1f MB\n", out, format(chk$rows, big.mark = ","),
            format(chk$named, big.mark = ","), format(chk$areas, big.mark = ","), chk$wrecks, chk$internal, file.size(out) / 1e6))
print(table(type = d$type, level = d$level))
