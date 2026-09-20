# https://www.fao.org/fishery/geonetwork/srv/eng/catalog.search#/metadata/ac02a460-da52-11dc-9d70-0017f293bd28

url <- "https://www.fao.org/fishery/geoserver/fifao/ows?service=WFS"


library(sf)
library(httr2)

# FAO_AREAS_ERASE --------------------------------------------------------------
url <- paste0(
  "https://www.fao.org/fishery/geoserver/fifao/ows",
  "?service=WFS",
  "&version=1.0.0",
  "&request=GetFeature",
  "&typeName=fifao:FAO_AREAS_ERASE",
  "&outputFormat=application/json"
)
request(url) |>
  req_perform(path = fd_raw("aux", "FAO_AREAS_ERASE.geojson"))
# FAO_AREAS_NOCOASTLINE  -------------------------------------------------------
url <- paste0(
  "https://www.fao.org/fishery/geoserver/fifao/ows",
  "?service=WFS",
  "&version=1.0.0",
  "&request=GetFeature",
  "&typeName=fifao:FAO_AREAS_NOCOASTLINE",
  "&outputFormat=application/json"
)
request(url) |>
  req_perform(path = fd_raw("aux", "FAO_AREAS_NOCOASTLINE.geojson"))

# ICES areas -------------------------------------------------------------------
url <- "https://gis.ices.dk/shapefiles/ICES_areas.zip"
library(httr2)
library(sf)

tmp_zip <- tempfile(fileext = ".zip")
tmp_dir  <- tempdir()

request("https://gis.ices.dk/shapefiles/ICES_areas.zip") |>
  req_perform(path = tmp_zip)

unzip(tmp_zip, exdir = tmp_dir)

ices_areas <- read_sf(file.path(tmp_dir, "ICES_Areas_20160601_cut_dense_3857.shp"))
ices_areas |> write_sf(fd_raw("aux", "ICES_Areas_20160601_cut_dense_3857.gpkg"), delete_dsn = TRUE)

