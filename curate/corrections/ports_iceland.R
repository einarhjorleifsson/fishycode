# Reviewed corrections to the frozen Iceland/Faroe harbour artifact.
#
# Input:  raw/ports/ports_iceland_faroe.gpkg       159 harbours, as bootstrapped
# Output: staging/ports/ports_iceland_faroe.gpkg   156 harbours, corrected
#
# raw/ is immutable, so this writes a corrected copy rather than editing in
# place; reference/ports/ports_all.R reads the staging copy. Declaration:
# curate/corrections/ports_iceland.yml
#
# The producer (reference/ports/bootstrap_iceland_faroe.R) is a one-time
# bootstrap that cannot be re-run — its STK input does not exist here, and
# re-running it would re-close the circle described in its header. So the
# correction is applied to the artifact, declaratively and re-runnably.

library(sf)
library(tidyverse)
sf::sf_use_s2(FALSE)

ports <- read_sf(fd_raw("ports", "ports_iceland_faroe.gpkg"))
stopifnot(nrow(ports) == 159)

# -- 1. Two records that are not harbours --------------------------------------
# Hellnar's coordinate pair had been copy-pasted onto the Hellissandur and
# Hnífsdalur rows of the bootstrap's ports_add tribble, so all three carried the
# SAME polygon. One AIS ping then matched three harbours and a left join emitted
# three rows — the long-standing "+70 rows" defect (decision 004).
#
# Removed rather than re-pointed: neither is a proper harbour. Their codes in
# the landings and logbook databases (41, 71) denote where the fish was
# PROCESSED, not where a vessel berthed — which is also why STK never flagged
# them and why they needed hand-adding. Hnífsdalur's 4,982 logbook arrivals run
# 1975-1993 and then stop: a processing plant's lifetime, not a harbour's.
#
# Their CODES still resolve — curated/reference/port.parquet carries them from
# kvoti.stadur with pid NA. See TODO 12b; a code must not need a polygon.
drop_pid <- c("IS-HLS",   # Hellissandur, hid 41
              "IS-HDL",   # Hnífsdalur,   hid 71
              "IS-HVK")   # see below

# IS-HVK is dropped too, for a different reason: it is a harbour, but this
# polygon is in the wrong place. The bootstrap built it from the raw STK code HVK
# (1,128 events at 66.4N, -22.4W) while the pid is Hólmavík (65.7N, -21.7W), 80 km
# away. The rebuilt bootstrap excludes those events and builds Hólmavík from the
# HK/HOL events; until that rebuild is promoted, Hólmavík has no einar polygon
# rather than a wrong one. Its code (hid 81) still resolves by name via kvoti.

# -- 2. Restore the intended 500 m radius --------------------------------------
# The hand-added ports were buffered in EPSG:3857, whose unit is a metre only at
# the equator (scale factor sec(lat)), so they came out at 500*cos(lat) =
# 203-224 m. EPSG:3057 is metres over Iceland, so the buffer is exact there.
rebuffer_pid <- c("IS-VIK", "IS-HLL", "IS-ALV", "IS-OGV")
BUFFER_M <- 500

ports <- ports |> filter(!pid %in% drop_pid)
fixed <- ports |>
  filter(pid %in% rebuffer_pid) |>
  st_transform(3057) |> st_centroid() |> st_buffer(BUFFER_M) |>
  st_transform(st_crs(ports))
ports <- bind_rows(ports |> filter(!pid %in% rebuffer_pid), fixed) |> arrange(pid)

stopifnot(
  nrow(ports) == 156,
  !any(duplicated(st_as_text(st_geometry(ports)))),
  all(!drop_pid %in% ports$pid),
  all(abs(sqrt(as.numeric(st_area(st_transform(
    ports |> filter(pid %in% rebuffer_pid), 3057))) / pi) - BUFFER_M) < 1)
)

# -- 3. There is ONE pid namespace, and this file does not define it -----------
# The bootstrap assigned its own codes (Hellnar = IS-HLL). ports_all.R then
# reassigns pid globally via build_pid() (Hellnar = IS-HEN). Two columns named
# `pid` meaning different things is how harbour_codes.R came to publish 59
# harbour codes whose pid existed nowhere, joining to nothing, silently
# (TODO 3e). Renaming it here makes that mistake impossible to repeat rather
# than merely discouraged: after this, exactly one column in the pipeline is
# called `pid`, and it is the one build_pid() issues.
ports <- ports |> rename(pid_bootstrap = pid)
stopifnot(!"pid" %in% names(ports))

write_sf(ports, fd_staging("ports", "ports_iceland_faroe.gpkg"), delete_dsn = TRUE)
