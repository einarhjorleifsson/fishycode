# gear_logbook_vs_landing.R — is the logbook's trawl gear right? Landings as an independent witness (plan 012)
#
# Input:  curated/ais/trail, curated/logbook/station_window.parquet, curated/logbook/lid_map.parquet,
#         curated/landing/catch.parquet
# Output: printed tables only (exploratory, read-only; not a target, nothing written)
#
# The logbook says which trawl a station used (gid 6 fish, 7 nephrops, 8 shrimp). The landings of the matched
# trip carry their own gear code and the species landed (sid 41 is shrimp). The two systems are filled in by
# different people, so where they agree the gear is probably right and where they disagree one is wrong.
#   A. Per trip with a single OTB gear in the logbook: logbook gid against the landing's dominant gid.
#   B. North-west, near the coast (fjords are shrimp ground; a fish trawl there is suspect): the gears the
#      logbook reports there, and what the same trips landed. "Near the coast" is distance to the Natural Earth
#      coastline, a stand-in for a fjord polygon that does not exist in $FISHYDATA.

library(dplyr)
library(duckdbfs)
library(sf)
source(here::here("R/paths.R"))

spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
DBI::dbExecute(duckdbfs::cached_connection(), sprintf("SET temp_directory = '%s'", spill))

SHRIMP <- 41L
sw <- open_dataset(fd_curated("logbook", "station_window.parquet")) |> filter(gid %in% 6:8) |> distinct(.sid, schema, gid)

# logbook trip -> landing, and what the landing holds ------------------------------
lid <- open_dataset(fd_curated("logbook", "lid_map.parquet")) |>
  filter(match_type %in% c("01 exact", "02 exact ±1 day", "03 vid_date")) |> select(.tid, tschema = schema, .lid)
land <- open_dataset(fd_curated("landing", "catch.parquet")) |>
  group_by(.lid, gid) |> summarise(t = sum(catch), shrimp = sum(if_else(sid == !!SHRIMP, catch, 0)), .groups = "drop") |>
  group_by(.lid) |>
  summarise(land_gid = arg_max(gid, t), landed = sum(t), shrimp_share = sum(shrimp) / sum(t), n_land_gid = n_distinct(gid)) |>
  collect()

# A. logbook vs landing gear, trips with one OTB gear ------------------------------
trip_gid <- sw |> inner_join(open_dataset(fd_curated("logbook", "station_window.parquet")) |>
                               filter(phase == "tow") |> select(.sid, schema, .tid), by = c(".sid", "schema")) |>
  distinct(.tid, schema, gid) |> collect() |>
  group_by(.tid, schema) |> filter(n() == 1) |> ungroup()
a <- trip_gid |> inner_join(lid |> collect(), by = c(".tid", "schema" = "tschema")) |>
  inner_join(land, by = ".lid") |> filter(landed > 0)
cat("A. trips by logbook gid (rows) and the landing's dominant gid (columns)\n")
print(table(logbook = a$gid, landing = a$land_gid))
cat("\nshare of trips where the two agree, and the median shrimp share of the landing\n")
a |> group_by(gid) |> summarise(trips = n(), agree = mean(gid == land_gid), shrimp_share_median = median(shrimp_share)) |> print()

# B. north-west, near the coast ------------------------------------------------------
bb <- c(-24.3, -21.4, 65.5, 66.6)
cell <- 0.01
nw <- open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2008, year <= 2024, gear == "OTB", phase == "tow", n_sid == 1,
         lon >= !!bb[1], lon <= !!bb[2], lat >= !!bb[3], lat <= !!bb[4]) |>
  inner_join(sw, by = c(".sid", "schema")) |>
  mutate(x = floor(lon / !!cell) * !!cell + !!cell / 2, y = floor(lat / !!(cell / 2)) * !!(cell / 2) + !!cell / 4) |>
  group_by(x, y, .tid, schema, gid) |>
  summarise(fixes = n(), towing = sum(as.numeric(speed >= 2.625 & speed <= 4.7 & !(provider == "gps" & abs(speed - 1.943846) < 1e-4))),
            at_shrimp_speed = sum(as.numeric(speed >= 1.75 & speed < 2.625)), slow = sum(as.numeric(speed < 1.75)), fast = sum(as.numeric(speed > 4.7)),
            .groups = "drop") |> collect()

isl <- rnaturalearth::ne_countries(scale = 10, returnclass = "sf") |> filter(name == "Iceland") |> st_transform(3057) |> st_union()
pts <- nw |> distinct(x, y) |> st_as_sf(coords = c("x", "y"), crs = 4326, remove = FALSE) |> st_transform(3057)
pts$d_km <- as.numeric(st_distance(pts, isl)) / 1000
nw <- nw |> left_join(st_drop_geometry(pts), by = c("x", "y")) |> mutate(zone = if_else(d_km < 5, "within 5 km of coast", "further out"))

cat("\nB. north-west tow fixes by logbook gear and zone\n")
nw |> group_by(zone, gid) |> summarise(fixes = sum(fixes), at_fish_trawl_speed = sum(towing, na.rm = TRUE) / sum(fixes),
            between_1.75_2.6 = sum(at_shrimp_speed, na.rm = TRUE) / sum(fixes), below_1.75 = sum(slow, na.rm = TRUE) / sum(fixes), above_4.7 = sum(fast, na.rm = TRUE) / sum(fixes), trips = n_distinct(paste(.tid, schema)), .groups = "drop") |>
  group_by(zone) |> mutate(share = fixes / sum(fixes)) |> print()

cat("\nwhat the matched trips landed, by logbook gear and zone (trips with a landing)\n")
nw |> group_by(zone, gid, .tid, schema) |> summarise(fixes = sum(fixes), .groups = "drop") |>
  inner_join(lid |> collect(), by = c(".tid", "schema" = "tschema")) |>
  inner_join(land, by = ".lid") |>
  group_by(zone, gid) |>
  summarise(trips = n(), landing_gid_agrees = mean(gid == land_gid), shrimp_share_median = median(shrimp_share, na.rm = TRUE),
            shrimp_lt_10pct = mean(shrimp_share < .10, na.rm = TRUE), with_landed_weight = sum(!is.na(shrimp_share)), .groups = "drop") |> print()

# C. who are the fish trawls near the coast? Vessel power of the gid 6 fixes by zone -------------------------
vk <- open_dataset(fd_curated("vessel", "vessel.parquet")) |> filter(flag == "ISL") |> select(vid, kw, loa) |> collect() |>
  group_by(vid) |> slice(1) |> ungroup()
nwv <- open_dataset(fd_curated("ais", "trail")) |>
  filter(year >= 2008, year <= 2024, gear == "OTB", phase == "tow", n_sid == 1,
         lon >= !!bb[1], lon <= !!bb[2], lat >= !!bb[3], lat <= !!bb[4]) |>
  inner_join(sw |> filter(gid == 6), by = c(".sid", "schema")) |>
  mutate(x = floor(lon / !!cell) * !!cell + !!cell / 2, y = floor(lat / !!(cell / 2)) * !!(cell / 2) + !!cell / 4) |>
  group_by(x, y, vid) |> summarise(fixes = n(), .groups = "drop") |> collect() |>
  left_join(distinct(nw, x, y, zone), by = c("x", "y")) |> left_join(vk, by = "vid")
cat("\nC. fish-trawl (gid 6) tow fixes in the north-west by zone and vessel power\n")
nwv |> mutate(kw_class = cut(kw, c(0, 300, 600, 1000, 1500, Inf))) |>
  group_by(zone, kw_class) |> summarise(fixes = sum(fixes), vessels = n_distinct(vid), .groups = "drop") |>
  group_by(zone) |> mutate(share = round(fixes / sum(fixes), 3)) |> print(n = Inf)
