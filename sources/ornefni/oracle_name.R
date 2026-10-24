# The place names in Oracle's own tables: MFRI's gazetteer, its coarse fishing grounds, and Breiðafjörður's names.
# Side: preprocessing (ornefni). See plan 044 §4.1.
#
# Input:  raw/oracle/ops_sigfus/ornefni.parquet (2,881: orri.ornefni's names and 307 more), raw/oracle/orri/ornefni.parquet
#         (checked); raw/oracle/afli/afli_skikar.parquet (1,470 squares of MFRI's coarse grounds);
#         raw/oracle/afli/brei_nofn.parquet (428 Breiðafjörður names) with raw/oracle/ops_sigfus/fj_reitir.parquet
# Output: staging/ornefni/oracle_name.parquet - one row per source row, keyed on (`source_table`, `row`)
#
# Read where the dump put them, as Oracle holds them, under English names:
# - ornefni (the gazetteer the tag app picks from, kb-hafro-kerfi): `name` (nafn), `description` (heiti), `region`
#   (landsvaedi, a coast region: AF AL NL SA SV VF VL), `sea_area` (hafsvaedi, 1-9), `square` (reitur), `square_part`
#   (smareitur's part, 1-4), `skiki`, `fj_square` (fj_reitur), `nr`. The position: `breidd`/`lengd` read as degrees,
#   minutes and seconds (625000 = 62°50'00", west), or as degrees and minutes where they have four digits (Grænahlíð:
#   6616, 2313), basis `recorded`; a position in neither form (Kóparif's longitude 22410) is noted in `position_note`.
#   Else the sub-square's or square's centre, basis `derived`, kind `square`.
# - afli_skikar: one row per mini-square of a coarse ground (`name` = heiti), placed at the mini-square's centre. A
#   square is 1° x 0.5°; its four sub-squares (smáreitur) and their four mini-squares (örreitur) are numbered 1
#   north-west, 2 north-east, 3 south-west, 4 south-east, as geo::sr2d() numbers the sub-squares. `fj_name` (fj_heiti) is a
#   fjord area's name where the row has one.
# - One row of ornefni and one of brei_nofn have no name: kept, with `name` NA.
# - brei_nofn: placed through the fjord squares by three routes, best first (below): `position_route`.

library(dplyr)

R <- function(schema, table) nanoparquet::read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }
dms <- function(x) { x <- as.numeric(x)                    # ddmmss (6 digits), or ddmm (4), else NA
  ifelse(x >= 100000 & x < 1000000, floor(x / 10000) + (floor(x / 100) %% 100) / 60 + (x %% 100) / 3600,
         ifelse(x >= 1000 & x < 10000, floor(x / 100) + (x %% 100) / 60, NA_real_)) }
square_centre <- function(sq) { if (!length(sq)) return(cbind(lat = numeric(), lon = numeric()))
                                d <- geo::r2d(sq); cbind(lat = d$lat, lon = d$lon) }
part_offset <- function(part, dlat, dlon) cbind(lat = ifelse(part %in% c(1, 2), dlat, -dlat), lon = ifelse(part %in% c(1, 3), -dlon, dlon))

# The gazetteer ------------------------------------------------------------------------------------------------------
o <- R("ops_sigfus", "ornefni")
stopifnot(setequal(names(o), c("nafn", "heiti", "landsvaedi", "breidd", "lengd", "hafsvaedi", "reitur", "smareitur",
                               "skiki", "fj_reitur", "nr")))
orri <- R("orri", "ornefni")
stopifnot("every orri place is in ops$sigfus's, by nr and name" = sum(paste(orri$nr, orri$nafn) %in% paste(o$nr, o$nafn)) >= 2497)
c0 <- square_centre(o$reitur[!is.na(o$reitur)]); sq <- matrix(NA_real_, nrow(o), 2); sq[!is.na(o$reitur), ] <- c0
part <- ifelse(is.na(o$smareitur), NA, o$smareitur %% 10)
off <- part_offset(part, 0.125, 0.25)
has_pos <- !is.na(dms(o$breidd)) & !is.na(dms(o$lengd))
unread <- !is.na(o$breidd) & !has_pos
gaz <- tibble(source_table = "ornefni", row = seq_len(nrow(o)), nr = o$nr, name_raw = o$nafn, name = squeeze(o$nafn),
              description = squeeze(o$heiti), region = o$landsvaedi, sea_area = o$hafsvaedi, square = o$reitur,
              square_part = as.integer(part), skiki = o$skiki, fj_square = o$fj_reitur,
              lat = ifelse(has_pos, dms(o$breidd), ifelse(is.na(part), sq[, 1], sq[, 1] + off[, 1])),
              lon = ifelse(has_pos, -dms(o$lengd), ifelse(is.na(part), sq[, 2], sq[, 2] + off[, 2])),
              position_basis = case_when(has_pos ~ "recorded", !is.na(o$reitur) ~ "derived", TRUE ~ "none"),
              position_kind = case_when(has_pos ~ "point", !is.na(o$reitur) ~ "square", TRUE ~ NA_character_),
              position_note = ifelse(unread, paste("recorded position unread:", o$breidd, o$lengd), NA_character_))

# The coarse grounds, mini-square by mini-square ---------------------------------------------------------------------
k <- R("afli", "afli_skikar")
stopifnot(setequal(names(k), c("skiki", "reitur", "smareitur", "orreitur", "heiti", "fj_reitur", "fj_heiti")))
ck <- square_centre(k$reitur); ok1 <- part_offset(k$smareitur, 0.125, 0.25); ok2 <- part_offset(k$orreitur, 0.0625, 0.125)
grounds <- tibble(source_table = "afli_skikar", row = seq_len(nrow(k)), name_raw = k$heiti, name = squeeze(k$heiti),
                  skiki = k$skiki, square = k$reitur, square_part = as.integer(k$smareitur), mini_part = as.integer(k$orreitur),
                  fj_square = k$fj_reitur, fj_name = squeeze(k$fj_heiti),
                  lat = ck[, "lat"] + ok1[, "lat"] + ifelse(is.na(k$orreitur), 0, ok2[, "lat"]),
                  lon = ck[, "lon"] + ok1[, "lon"] + ifelse(is.na(k$orreitur), 0, ok2[, "lon"]),
                  position_basis = "derived", position_kind = "square")

# Breiðafjörður's names, through the fjord squares -------------------------------------------------------------------
# Three routes, best first: fj_reitir (fj_reitur and skiki to a square and sub-square); else afli_skikar's rows that
# carry the same fj_reitur and skiki (the mean of their mini-squares' centres); else the centre of the skiki's own
# squares in afli_skikar, kind `area`, a coarse position. `position_route` says which answered.
b <- R("afli", "brei_nofn"); fj <- R("ops_sigfus", "fj_reitir")
stopifnot(setequal(names(b), c("nafn", "fj_reitur", "skiki")), setequal(names(fj), c("fj_reitur", "skiki", "reitur", "smareitur")),
          !anyDuplicated(fj[c("fj_reitur", "skiki")]))
c1 <- matrix(NA_real_, nrow(fj), 2); c1[] <- square_centre(fj$reitur); o1 <- part_offset(fj$smareitur, 0.125, 0.25)
r1 <- tibble(fj_reitur = fj$fj_reitur, skiki = fj$skiki, lat1 = c1[, 1] + o1[, 1], lon1 = c1[, 2] + o1[, 2])
r2 <- grounds |> filter(!is.na(fj_square)) |> group_by(fj_reitur = fj_square, skiki) |>
  summarise(lat2 = mean(lat), lon2 = mean(lon), .groups = "drop")
r3 <- grounds |> group_by(skiki) |> summarise(lat3 = mean(lat), lon3 = mean(lon), .groups = "drop")
bj <- b |> left_join(r1, by = c("fj_reitur", "skiki")) |> left_join(r2, by = c("fj_reitur", "skiki")) |>
  left_join(r3, by = "skiki") |>
  mutate(position_route = case_when(!is.na(lat1) ~ "fj_reitir", !is.na(lat2) ~ "afli_skikar fj_reitur",
                                    !is.na(lat3) ~ "afli_skikar skiki", TRUE ~ NA_character_))
brei <- tibble(source_table = "brei_nofn", row = seq_len(nrow(bj)), name_raw = bj$nafn, name = squeeze(bj$nafn),
               skiki = bj$skiki, fj_square = bj$fj_reitur,
               lat = coalesce(bj$lat1, bj$lat2, bj$lat3), lon = coalesce(bj$lon1, bj$lon2, bj$lon3),
               position_basis = ifelse(is.na(bj$position_route), "none", "derived"),
               position_kind = case_when(bj$position_route %in% "afli_skikar skiki" ~ "area", !is.na(bj$position_route) ~ "square",
                                         TRUE ~ NA_character_),
               position_route = bj$position_route)

# Check and write ----------------------------------------------------------------------------------------------------
out <- bind_rows(gaz, grounds, brei) |> mutate(source = "oracle")
stopifnot(nrow(out) == nrow(o) + nrow(k) + nrow(b), "one row with no name in ornefni and one in brei_nofn" = sum(is.na(out$name)) == 2,
          "positions lie round Iceland" = all(is.na(out$lat) | (out$lat > 59 & out$lat < 72 & out$lon > -35 & out$lon < -5)))
print(knitr::kable(out |> group_by(source_table) |> summarise(rows = n(), names = n_distinct(name),
  no_name = sum(is.na(name)), recorded = sum(position_basis == "recorded"), area = sum(position_kind %in% "area"), square = sum(position_kind %in% "square"), none = sum(position_basis == "none")),
  caption = "staging/ornefni/oracle_name"))
print(table(route = out$position_route, useNA = "ifany"))

nanoparquet::write_parquet(out, fd_staging("ornefni", "oracle_name.parquet"))
