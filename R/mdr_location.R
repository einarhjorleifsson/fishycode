# The EU's fisheries location list (DG MARE's MDR, code list LOCATION; dump/ports/mdr_location.R) as port-list rows.
#
# read_mdr_location(path) returns one row per row of the sheet ALL_LOCATION, expired codes too, in the columns of
# reference/ports/port_feature.R's std(): source "mdr", feature_key (the code, numbered where a code repeats), name,
# iso_src (the code's country), locode (set only where the code is a UN/LOCODE; the Commission's own codes, for smaller
# landing places, carry none), kind (the flags fishing port, landing place, commercial port, "an MDR code, not a
# UN/LOCODE", and "valid to <date>" for a code that ends) and geom (the position as given; empty where there is none).
#
# The build does not read it: the maintainer held the MDR out of the port layer on 2026-11-14, after its test as a witness
# (plan 075; the study archive/2026-11-14-port-layer, scripts/mdr_*.R), until its copies (vmstools' harbours share its
# positions) and the name rule are reviewed. reference/ports/port_layer.R weighs it when a feature table holds it.
read_mdr_location <- function(path) {
  md <- readxl::read_excel(path, sheet = "ALL_LOCATION", col_types = "text")
  lon <- suppressWarnings(as.numeric(md$Longitude)); lat <- suppressWarnings(as.numeric(md$Latitude))
  geom <- sf::st_sfc(lapply(seq_len(nrow(md)), \(i) if (is.na(lon[i]) || is.na(lat[i])) sf::st_point() else
    sf::st_point(c(lon[i], lat[i]))), crs = 4326)
  flag <- function(v, label) ifelse(toupper(dplyr::coalesce(v, "")) == "Y", label, NA)
  own <- dplyr::coalesce(md$UNLoCode, "") != md$Code
  kind <- apply(cbind(flag(md$FishingPort, "fishing port"), flag(md$LandingPlace, "landing place"),
                      flag(md$CommercialPort, "commercial port"), ifelse(own, "an MDR code, not a UN/LOCODE", NA),
                      ifelse(substr(dplyr::coalesce(md$EndDate, "2100"), 1, 4) == "2100", NA, paste("valid to", substr(md$EndDate, 1, 10)))),
                1, \(r) paste(r[!is.na(r)], collapse = "; "))
  k <- md$Code
  key <- ifelse(duplicated(k) | duplicated(k, fromLast = TRUE), paste0(k, "_", stats::ave(seq_along(k), k, FUN = seq_along)), k)
  sf::st_sf(source = "mdr", feature_key = key, name = md$Name, iso_src = substr(md$Code, 1, 2),
            locode = ifelse(own, NA_character_, substr(md$Code, 3, 5)), kind = kind, geom = geom)
}
