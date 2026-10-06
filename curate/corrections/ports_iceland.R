# Hand the Iceland/Faroe harbour artifact to staging under its own pid column, with its names corrected.
#
# Input:  raw/ports/ports_iceland_faroe.gpkg       159 harbours (bootstrap of 2026-10-01)
# Output: staging/ports/ports_iceland_faroe.gpkg   157 harbours, pid renamed pid_bootstrap,
#                                                  port/hid corrected, the bootstrap's in port_bootstrap/hid_bootstrap
#
# raw/ is immutable, so this writes a copy; reference/ports/ports_all.R reads the
# staging copy. Declaration: curate/corrections/ports_iceland.yml
#
# The defects this file used to repair by editing the artifact (Hellnar's polygon
# shared by two non-harbours, buffers 57 % too small, IS-HVK at Hornvík, IS-STK a
# Stykkishólmur berth) are fixed at the source since the bootstrap was re-run from
# the full trail (decision 058); the first bootstrap's file is in raw/ports/archive/.
# What is left is the rename, the guards that the fixes held, and the name corrections below.

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

# Names (2026-10-06, while preparing the WGSFD harbour file) -------------------
# The bootstrap's place list misnames a few harbours, and its hid came from matching
# that name against Fiskistofa's list, so a wrong name carries a wrong hid: IS-SEL lies
# on the coast of Skagi (65.97N) and was given Selfoss's landing code 9, Selfoss being
# inland. Selvík has no code of its own. The bootstrap's values stay in *_bootstrap.
renamed <- tribble(
  ~pid_bootstrap, ~from,           ~to,
  "IS-SEL",       "Selfoss",       "Selvík",        # maintainer 2026-10-06
  "FO-HUS",       "Husevig",       "Hósvík",        # at 62.15N 6.93W; Husevig is the Danish name of Húsavík, Sandoy
  "IS-HST",       "Hesteyrar",     "Hesteyri",      # Hesteyrar is the genitive
  "IS-LAN",       "Landeyjarhöfn", "Landeyjahöfn",
  "FO-TVO",       "Tvoeyri",       "Tvøroyri",
  "FO-SRV",       "Sorvágur",      "Sørvágur",
  "FO-VES",       "Vestmanhafn",   "Vestmanna",
  "FO-VBR",       "Velbastadur",   "Velbastaður",
  "FO-SYN",       "Steymnes",      "Streymnes",
  "FO-KVI",       "Klakksvík",     "Klaksvík")
hid_wrong <- "IS-SEL"
# Not harbours (maintainer 2026-10-06): IS-NUK is named "in Breiðafjörður", which is not a
# place name, and IS-SVD (STK code SVD, also in Breiðafjörður) was never named, only "CHECK"
dropped   <- c("IS-NUK", "IS-SVD")

stopifnot(all(paste(renamed$pid_bootstrap, renamed$from) %in%
                paste(ports$pid_bootstrap, ports$port)),
          all(dropped %in% ports$pid_bootstrap))

ports <- ports |>
  filter(!pid_bootstrap %in% dropped) |>
  mutate(port_bootstrap = port, hid_bootstrap = hid) |>
  left_join(renamed |> select(pid_bootstrap, to), by = "pid_bootstrap") |>
  mutate(port = coalesce(to, port),
         hid  = if_else(pid_bootstrap %in% hid_wrong, NA, hid)) |>
  select(-to)

stopifnot(nrow(ports) == 157,
          !any(duplicated(ports$port)),
          is.na(ports$hid[ports$pid_bootstrap == "IS-SEL"]))

write_sf(ports, fd_staging("ports", "ports_iceland_faroe.gpkg"), delete_dsn = TRUE)
