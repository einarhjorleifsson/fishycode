# ÍSOR's seabed map: the five layers that name features (volcanic areas, points and lines; submarine landslides; offshore
# geothermal sites), one row per record as delivered (plan 074 step 12, the names).
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow (plan 074 ask p);
# reference/names/marine_name.R reads it.
#
# Input:  raw/external/isor/hafsbotn_{Eldvirkni_og_jardv_a__2_..., __0_..., __1_..., __5_..., Jardhiti_i_sjo__0_...}.geojson
#         (dump/isor/hafsbotn.R: kort.isor.is's hafsbotn layers, as delivered)
# Output: staging/isor/seabed_name.parquet - one row per record with a geometry (2,825): `kind` (area, point, line,
#         landslide, geothermal), `layer` (the file), `rid` (the record's number in that kind order, the named-features
#         study's 131 key), `name`, `references` (References_ or Reference), and every attribute of its layer as delivered
#         (one whose name clashes with these, case aside, prefixed `isor_`: ÍSOR's `Name` is `isor_Name`);
#         WKB `geometry`, WGS 84
#
# Source-shaped. Records with an empty geometry are left out and counted, as the study's 131 left them out.
# ÍSOR's names and references cite Hjartarson and Erlendsson (2018), Rep. ISOR-2018/027, and Erlendsson et al. (EGU 2023).
# Run from the repo root: Rscript sources/isor/seabed_name.R. Written by Claude (AI), 2026-11-19.

library(dplyr)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'

LAYERS <- c(area = "hafsbotn_Eldvirkni_og_jardv_a__2_Eldst_odvar_fl_akar_.geojson",
            point = "hafsbotn_Eldvirkni_og_jardv_a__0_Eldst_odvar_punktar_punktar_.geojson",
            line = "hafsbotn_Eldvirkni_og_jardv_a__1_Eldst_odvar_l_inur_.geojson",
            landslide = "hafsbotn_Eldvirkni_og_jardv_a__5_Nedansj_avarskridur_Submarine_landslides.geojson",
            geothermal = "hafsbotn_Jardhiti_i_sjo__0_Jardhiti_i_sj_o_Offshore_geothermal_sites.geojson")

empty <- integer()
parts <- lapply(names(LAYERS), function(k) {
  g <- sf::st_read(fd_raw("external", "isor", LAYERS[[k]]), quiet = TRUE)
  stopifnot(sf::st_crs(g)$epsg %in% c(4326L, NA) || !is.na(sf::st_crs(g)))
  g <- sf::st_transform(g, 4326)
  e <- sf::st_is_empty(g); empty[[k]] <<- sum(e); g <- g[!e, ]
  a <- as.data.frame(sf::st_drop_geometry(g))
  ref <- if ("References_" %in% names(a)) a$References_ else if ("Reference" %in% names(a)) a$Reference else NA_character_
  a[] <- lapply(a, as.character)
  nm_isor <- a$Name
  clash <- tolower(names(a)) %in% c("kind", "layer", "rid", "name", "references", "geometry")   # DuckDB's names ignore case
  names(a)[clash] <- paste0("isor_", names(a)[clash])
  # bind_cols: sf::st_sf(tibble, a, geometry =) kept the first data frame alone, so until 2026-11-19 the layers' attributes
  # never reached staging though this header promised them (found when plan 080 §5.2a wanted Morpho_T)
  sf::st_sf(dplyr::bind_cols(tibble(kind = k, layer = LAYERS[[k]], name = trimws(coalesce(nm_isor, "")), references = coalesce(as.character(ref), "")),
                             a), geometry = sf::st_geometry(g))
})
d <- do.call(dplyr::bind_rows, parts)
d <- sf::st_sf(d, sf_column_name = "geometry") |> mutate(rid = row_number(), .after = layer) |> relocate(geometry, .after = last_col())

stopifnot(nrow(d) == 2825L, sf::st_crs(d)$epsg == 4326)
print(knitr::kable(sf::st_drop_geometry(d) |> count(kind, name = "records") |>
  mutate(empty_left_out = unname(empty[kind]), named = as.vector(tapply(nzchar(d$name), d$kind, sum)[kind])),
  caption = "staging/isor/seabed_name"))
write_parquet_sf(d, fd_staging("isor", "seabed_name.parquet"))
