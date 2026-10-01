# Hand the Iceland/Faroe harbour artifact to staging under its own pid column.
#
# Input:  raw/ports/ports_iceland_faroe.gpkg       159 harbours (bootstrap of 2026-10-01)
# Output: staging/ports/ports_iceland_faroe.gpkg   159 harbours, pid renamed pid_bootstrap
#
# raw/ is immutable, so this writes a copy; reference/ports/ports_all.R reads the
# staging copy. Declaration: curate/corrections/ports_iceland.yml
#
# The defects this file used to repair by editing the artifact (Hellnar's polygon
# shared by two non-harbours, buffers 57 % too small, IS-HVK at Hornvík, IS-STK a
# Stykkishólmur berth) are fixed at the source since the bootstrap was re-run from
# the full trail (decision 058); the first bootstrap's file is in raw/ports/archive/.
# What is left is the rename, and the guards that the fixes held.

library(sf)
library(tidyverse)
sf::sf_use_s2(FALSE)

ports <- read_sf(fd_raw("ports", "ports_iceland_faroe.gpkg"))

# Hellissandur (41) and Hnífsdalur (71) are processing sites, not berths (decision
# 004); Hellnar's polygon must not be shared; the hand-added ports are 500 m.
hand_added <- c("IS-VIK", "IS-HLL", "IS-ALV", "IS-OGV")
stopifnot(
  nrow(ports) == 159,
  !any(duplicated(ports$pid)),
  !any(c("IS-HLS", "IS-HDL") %in% ports$pid),
  !any(duplicated(st_as_text(st_geometry(ports)))),
  all(abs(sqrt(as.numeric(st_area(st_transform(
    ports |> filter(pid %in% hand_added), 3057))) / pi) - 500) < 1),
  # IS-HVK is Hólmavík (65.7N), not Hornvík (66.4N); IS-STK is Stokkseyri (63.8N)
  between(st_coordinates(st_centroid(ports[ports$pid == "IS-HVK", ]))[, 2], 65.6, 65.8),
  between(st_coordinates(st_centroid(ports[ports$pid == "IS-STK", ]))[, 2], 63.7, 63.9)
)

# There is ONE pid namespace, and this file does not define it. The bootstrap
# assigned its own codes (Hellnar = IS-HLL); ports_all.R reassigns pid globally via
# build_pid() (Hellnar = IS-HEN). Renaming here makes the mistake impossible to
# repeat: after this exactly one column in the pipeline is called `pid`.
ports <- ports |> rename(pid_bootstrap = pid)
stopifnot(!"pid" %in% names(ports))

write_sf(ports, fd_staging("ports", "ports_iceland_faroe.gpkg"), delete_dsn = TRUE)
