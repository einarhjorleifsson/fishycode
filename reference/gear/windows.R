# windows.R — what a gear's fishing window looks like, and how fast it fishes.
#
# Input:  curated/reference/gear.parquet   (reference/gear/mapping.R; the gid -> gear vocabulary)
# Output: curated/reference/gear_window.parquet
#
# One row per NEW-version gid (the code `fishing_sample` carries as `gid`). This is
# a support table for curate/station_window.R, deliberately not columns on
# gear.parquet: `s1`/`s2` here are a gear's SPEED thresholds in knots and must not
# be confused with a station's outer time bounds, which docs/grammar.qmd also
# calls s1/s2 (plan 006 §2). The two never share a table.
#
# Columns
#   gear_class  towed | static | other. Decides which logbook times are the vessel
#               being active (plan 010 §2): towed fishes between t2 and t3; static
#               is active twice, at the set (from t1) and the haul (t3 to t4); the
#               time in between is gear in the water with the vessel elsewhere and
#               is NOT a window. other has no usable event times, so it gets the
#               station date (basis "synthesised").
#   s1, s2      speed window, knots. Ported from the pre-restructuring
#               fishyweb/scripts/00_DATASET_gear.R tribble (agf_gid = this gid).
#               Fleet-wide and declared, not fitted (maintainer, 2026-09-30): they
#               were obtained for the fleet as a whole, work reasonably, and could
#               be refined - per vessel class, per era, or from the speed profile
#               of recorded windows. `s_basis` says so on every row, so a refined
#               value can arrive beside "declared_fleet" instead of replacing it.
#               See the check at the foot of this file.
#   set_max_min Longest plausible set, minutes, for closing the open-ended set
#               window. NA until estimated from the speed profile after t1 (plan
#               010 Q9); it is an assumption and is never invented here.
#
# Adding max-duration and max-distance criteria (mapping.R's TODO) belongs in this
# file, not in mapping.R: they are properties of a window, not of a vocabulary.

library(tidyverse)
library(nanoparquet)

gear <- read_parquet(fd_curated("reference", "gear.parquet")) |>
  filter(version == "new") |>
  select(gid, veidarfaeri = `veiðarfæri`, gear, target)

# The speed windows are keyed to gid. `veidarfaeri` is carried in the tribble so the
# join below can prove the two lists still mean the same gear, rather than trusting
# that the numbers line up.
speed <- tribble(
  ~gid, ~veidarfaeri,        ~s1,   ~s2,
     1, "Skötuselsnet",     0.000, 2.500,
     2, "Þorskfisknet",     0.000, 1.700,
     3, "Grásleppunet",     0.000, 1.700,
     4, "Rauðmaganet",      0.000, 1.700,
     5, "Reknet",           0.050, 1.125,
     6, "Botnvarpa",        2.625, 4.700,
     7, "Humarvarpa",       2.375, 3.700,
     8, "Rækjuvarpa",       1.750, 3.000,
     9, "Flotvarpa",        2.625, 6.000,
    10, "Nót",              0.000, 1.700,
    11, "Dragnót",          0.250, 2.900,
    12, "Lína",             0.375, 2.750,
    13, "Landbeitt lína",   0.375, 2.750,
    14, "Handfæri",         0.025, 1.700,
    15, "Plógur",           1.200, 2.900,
    16, "Gildra",           0.100, 2.000,
    19, "Sjóstöng",         0.125, 1.250,
    21, "Línutrekt",        0.100, 2.200,
    22, "Grálúðunet",       0.050, 1.400,
    24, "Sláttuprammi",     0.000, 1.400,
    25, "Þaraplógur",       2.300, 4.000) |>
  mutate(gid = as.integer(gid))

# Gear codes are ICES GearType. GND (drift net) and FPO (pots) are static by the
# shape of their recorded times (GND: t1, t3, t4 all present; FPO: rare). PS fishes
# in an instant and has no window.
static <- c("LLS", "GNS", "GND", "LHM", "FPO")
towed  <- c("OTB", "OTM", "SDN", "DRB")

gear_window <-
  gear |>
  left_join(speed |> rename(veidarfaeri_speed = veidarfaeri), by = "gid") |>
  mutate(
    gear_class = case_when(gear %in% towed  ~ "towed",
                           gear %in% static ~ "static",
                           .default = "other"),
    set_max_min = NA_integer_,
    s_basis = if_else(is.na(s1), NA_character_, "declared_fleet")) |>
  select(gid, veidarfaeri, gear, target, gear_class, s1, s2, s_basis, set_max_min,
         veidarfaeri_speed)

# check: the speed list and the vocabulary agree on what each gid is ----------
mismatch <- gear_window |>
  filter(!is.na(veidarfaeri_speed), veidarfaeri != veidarfaeri_speed)
if (nrow(mismatch) > 0) {
  print(mismatch)
  stop("gear_window: speed table and gear vocabulary disagree on gid(s) above")
}
# a gear with a code and a class but no speed window cannot be speed-filtered
no_speed <- gear_window |> filter(!is.na(gear), is.na(s1))
if (nrow(no_speed) > 0) {
  message("gear_window: no speed window (expected for MIS/DIV/HMS and unmapped gids):")
  print(no_speed |> select(gid, veidarfaeri, gear, gear_class))
}

gear_window |>
  select(-veidarfaeri_speed) |>
  write_curated(fd_curated("reference", "gear_window.parquet"),
                inputs = fd_curated("reference", "gear.parquet"))

# check: are the declared speeds consistent with the data? ---------------------
# Not run here (reads the AIS sweep). Measured 2026-09-30 for plan 010 Phase 1, AIS
# speed inside RECORDED windows (towed [t2,t3], static [t3,t4]), share inside [s1,s2]:
#   OTB 6 .885 · OTB 7 .949 · OTB 8 .909 · OTM 9 .960 · SDN 11 .700 (2019)
#   LLS 12 .914 · GNS 2 .656 · GNS 3 .625 · GNS 22 .856 (all years)
# Trawls and longline agree. Nets run loose: their recorded hauls include steaming
# (q90 of speed is 7.5-8.4 kn), so the window, not the speed range, is what to doubt.
