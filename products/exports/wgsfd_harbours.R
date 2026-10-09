# wgsfd_harbours.R — the Iceland and Faroe harbour polygons in the WGSFD exchange format.
#
# Input:  staging/aux/ports.fgb                    the harbour set of the AIS flow; source == "einar"
#         overrides/port_class.csv             the reviewed port labels (decisions 074, 075)
# Output: exports/wgsfd/IS_harbours_<YYYYMMDD>.gpkg
#
# The format is docs/ports.md: one file per supplying country, layer "harbours", EPSG:4326, one polygon
# feature per harbour. The Faroe harbours are foreign harbours the Icelandic fleet uses. The file is
# read back and checked against the spec; any failure stops.
#
# - harbour_code is the MFRI harbour id (pid) for every harbour (maintainer, 2026-10-06): treated as
#   the Icelandic standard although it is not one. Fiskistofa's landing code (hid) covers only 91 of
#   the Icelandic harbours and none of the Faroese.
# - class is filled only where a person reviewed it (overrides/port_class.csv). The data-derived classes of the removed harbour_class.R
#   describe how long vessels stay, which is not the spec's question (are fish landed here?).

library(sf)
library(dplyr)

TODAY    <- Sys.Date()
PROVIDER <- "MFRI"
SUPPLIER <- "IS"   # the supplying country, which names the file
COLS     <- c("country", "harbour_code", "harbour_name", "class", "data_provider", "updated",
              "comment")
CLASSES  <- c("fishing", "mixed", "commercial", "marina", "anchorage", "unknown")
# the reviewed labels' vocabulary -> spec vocabulary
CLASS_MAP <- c(cargo = "commercial", no_pier = "anchorage", marina = "marina", mixed = "mixed")
# The rough extent of each country, to catch a harbour filed under the wrong one
BBOX <- list(IS = c(-25, 63, -13, 67), FO = c(-8, 61.3, -6, 62.5))

out_dir <- fd_path("exports", "wgsfd")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Harbours ---------------------------------------------------------------------
P <- read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |>
  mutate(country = substr(pid, 1, 2))
stopifnot(all(P$country %in% names(BBOX)))

cls <- utils::read.csv("overrides/port_class.csv", encoding = "UTF-8") |>
  transmute(pid, class = unname(CLASS_MAP[class]))
# the labels are keyed on pid; a reviewed label whose pid has since changed would otherwise be
# dropped without a word
stopifnot(!anyNA(cls$class), all(cls$pid %in% P$pid))

# The four hand-placed harbours of the bootstrap (ports_add) are 500 m circles, not outlines
r_eq <- sqrt(as.numeric(st_area(st_transform(P, 3057))) / pi)
hand <- abs(r_eq - 500) < 5
stopifnot(sum(hand) == 4)

geom_updated <- as.Date(file.mtime(fd_raw("ports", "ports_iceland_faroe.gpkg")))

H <- P |>
  left_join(cls, by = "pid") |>
  mutate(
    harbour_code  = pid,
    harbour_name  = port,
    data_provider = PROVIDER,
    updated       = geom_updated,
    comment       = paste0(
      if_else(country == "FO",
              "Derived by MFRI from Icelandic AIS data; not reviewed by a Faroese provider. ", ""),
      if_else(hand, "500 m circle around a hand-placed point.", "")) |>
      trimws() |>
      na_if("")
  ) |>
  st_cast("MULTIPOLYGON") |>
  select(all_of(COLS))

# Write, read back, check ------------------------------------------------------
f <- file.path(out_dir, sprintf("%s_harbours_%s.gpkg", SUPPLIER, format(TODAY, "%Y%m%d")))
write_sf(H, f, layer = "harbours", delete_dsn = TRUE)

check <- function(ok, what) {
  if (!isTRUE(all(ok))) stop(basename(f), ": spec check failed: ", what, call. = FALSE)
}

sf_use_s2(FALSE)   # validity and overlap in the planar GEOS sense, as the spec's consumers test it
y <- read_sf(f, layer = "harbours")
check(identical(st_layers(f)$name, "harbours"), "one layer named harbours")
check(st_crs(y)$epsg == 4326, "CRS EPSG:4326")
check(identical(setdiff(names(y), attr(y, "sf_column")), COLS), "attribute columns")
check(st_geometry_type(y) == "MULTIPOLYGON", "polygon geometry only")
check(st_is_valid(y), "valid geometry")
check(lengths(st_intersects(y)) == 1, "no two harbours overlap")
check(y$country %in% names(BBOX), "country")
check(!is.na(y$harbour_code) & nzchar(y$harbour_code), "harbour_code present")
check(!anyDuplicated(y$harbour_code), "harbour_code unique within the file")
check(startsWith(y$harbour_code, paste0(y$country, "-")), "harbour_code is a pid of its country")
check(!is.na(y$harbour_name) & nzchar(y$harbour_name) & validUTF8(y$harbour_name),
      "harbour_name present and UTF-8")
check(is.na(y$class) | y$class %in% CLASSES, "class vocabulary")
check(y$data_provider == PROVIDER, "data_provider")
check(inherits(y$updated, "Date"), "updated is a date")
for (cc in names(BBOX)) {
  bb <- st_bbox(filter(y, country == cc))
  check(bb[["xmin"]] >= BBOX[[cc]][1] & bb[["ymin"]] >= BBOX[[cc]][2] &
          bb[["xmax"]] <= BBOX[[cc]][3] & bb[["ymax"]] <= BBOX[[cc]][4],
        paste(cc, "harbours inside the country's extent (west longitudes negative)"))
}

message(sprintf("%d harbours (%s), %d with a class -> %s", nrow(y),
                paste(names(table(y$country)), table(y$country), collapse = ", "),
                sum(!is.na(y$class)), f))
