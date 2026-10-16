# stk_hid_pid.R — crosswalk from STK's alphabetic harbour code to the standard harbour key.
# Side: preprocessing (stk). See plan 014.
#
# Input:  raw/oracle/stk/trail (stk_trail())                     (hid, io, lon, lat per ping)
#         staging/aux/ports.fgb                 (standard pid, port, numeric hid; source == "einar")
#         overrides/stk_hid_pid.csv             (reviewed overrides: hid, pid, reviewed_date, reason)
# Output: curated/reference/stk_hid_pid.parquet one row per STK `hid`
#
# Plan 011 §3.2. STK ships its own harbour code (`AST`, `OFS`, `THO`, ...) with every in/out event.
# That code is a different namespace from the standard `pid` (and from the logbook's numeric hid),
# and it is not reliable: one code can name two harbours (`A`, `R`), two codes the same harbour
# (`DAL`/`DL`), and the polygons that tag the pings were once drawn from these very events.
#
# The seed is a data rule, not a typed table: for each `hid`, which standard polygon do its `I`
# events fall in? The modal polygon is the proposed `pid`, and the evidence (shares, second
# candidate, share outside every polygon) is kept next to it so a reviewer sees why. Nothing is
# decided here that a person has not seen: rows needing a decision carry `status != "auto"`, and a
# reviewed decision re-enters as an INPUT through overrides/stk_hid_pid.csv, never as a computed
# result (AGENTS: cycles are broken by a human, outside the DAG).
#
# Two refinements to the plain modal rule (2026-10-01, from the first review):
#   * Tolerance. An event just outside every polygon is not a different harbour: the polygons
#     are hulls of `I` points and are tight (STM, BAK, HVF, KDN sat 0.02-1.1 km outside). An event
#     outside all polygons but within NEAR_KM of its code's modal polygon counts toward that
#     polygon. This applies ONLY to a code already anchored (at least ANCHOR of its events INSIDE
#     the modal polygon); an unanchored code (A, STY, KEF, ...) keeps its misses, so the rule can
#     never silently merge a harbour that has no polygon into the nearest one.
#   * Collision. A code whose second polygon holds at least COLLIDE_SHARE of its events and lies at
#     least COLLIDE_KM from the first names two harbours (THH, THO): status "collision", and the
#     code cannot resolve a pid. An override `BY_POSITION` records that decision: `pid` is NA
#     and `resolve = "position"`, meaning "take the pid from the event's own polygon".
#
# `basis`: "reconstructed" = the modal-polygon rule; "recorded" = a reviewed override.
#
# Circularity, stated: the polygons were drawn around `I` events, so an `I` event lies in its own
# code's polygon by construction. This table therefore shows which codes COLLIDE, ALIAS or have no
# polygon (the second-candidate share and the outside share); it cannot prove a code correct.

library(dplyr)
library(sf)
sf::sf_use_s2(FALSE)

# -- Parameters ----------------------------------------------------------------

AUTO_SHARE    <- 0.90  # modal polygon holds at least this share of a code's `I` events: auto
OUTSIDE_MAX   <- 0.50  # more than this share outside every polygon: unmatched
LOW_N         <- 50    # fewer `I` events than this: flagged, not trusted
NEAR_KM       <- 1.5   # an outside event this close to the modal polygon counts toward it ...
ANCHOR        <- 0.50  # ... but only for a code with at least this share INSIDE that polygon
COLLIDE_SHARE <- 0.05  # second polygon holds at least this share of the events ...
COLLIDE_KM    <- 5     # ... and lies at least this far from the first: the code names two harbours

# Codes the one-time polygon bootstrap deliberately dropped (reference/ports/
# bootstrap_iceland_faroe.R): not harbours, or yacht harbours, or generic. Listed here so the
# table says WHY they have no polygon instead of showing them as unexplained misses.
BOOTSTRAP_EXCLUDED <- c("ISL", "DNG", "BER", "REYF", "RYH", "LSGUFA", "GYH", "IYH", "AYH",
                        "GRYYH", "R", "MJO", "MJOIF")

# -- Events --------------------------------------------------------------------

ev <- stk_trail() |>
  filter(!is.na(hid), !is.na(io), !is.na(lon), !is.na(lat)) |>
  mutate(lon4 = round(lon, 4), lat4 = round(lat, 4)) |>
  group_by(io, hid, lon4, lat4) |>
  summarise(n = n(), .groups = "drop") |>
  collect()

# -- Standard polygons ----------------------------------------------------------

P <- sf::read_sf(fd_staging("aux", "ports.fgb")) |>
  filter(source == "einar") |>
  select(pid, port, hid_logbook = hid) |>
  sf::st_make_valid()

ev_i <- ev |> filter(io == "I")
hit  <- sf::st_intersects(sf::st_as_sf(ev_i, coords = c("lon4", "lat4"), crs = 4326, remove = FALSE), P)
ev_i$pid <- vapply(hit, function(h) if (length(h)) P$pid[h[1]] else NA_character_, "")

# Nearest polygon, in metres, for the events that fall in none (planar degrees are not distances).
P_m  <- sf::st_transform(P, 3575)
out  <- which(is.na(ev_i$pid))
pts  <- sf::st_transform(sf::st_as_sf(ev_i[out, ], coords = c("lon4", "lat4"), crs = 4326), 3575)
nn   <- sf::st_nearest_feature(pts, P_m)
ev_i$near_pid <- NA_character_
ev_i$near_d   <- NA_real_
ev_i$near_pid[out] <- P$pid[nn]
ev_i$near_d[out]   <- as.numeric(sf::st_distance(pts, P_m[nn, ], by_element = TRUE))

# -- Per code --------------------------------------------------------------------

by_pid <- ev_i |>
  group_by(hid, pid) |>
  summarise(n = sum(n), .groups = "drop") |>
  group_by(hid) |>
  mutate(share = n / sum(n)) |>
  ungroup()

n_I <- by_pid |> group_by(hid) |> summarise(n_I = sum(n), .groups = "drop")
n_U <- ev |> filter(io == "U") |> group_by(hid) |> summarise(n_U = sum(n), .groups = "drop")

inside <- by_pid |> filter(!is.na(pid)) |> arrange(hid, desc(n))
top1 <- inside |> group_by(hid) |> slice(1) |> ungroup() |>
  transmute(hid, seed_pid = pid, n_in = n, share_in = share)
top2 <- inside |> group_by(hid) |> slice(2) |> ungroup() |>
  transmute(hid, pid_2 = pid, share_pid_2 = share)

# Tolerance: outside events whose nearest polygon is the code's modal one, within NEAR_KM.
near <- ev_i |>
  filter(is.na(pid)) |>
  inner_join(top1 |> select(hid, seed_pid, share_in), by = "hid") |>
  filter(share_in >= ANCHOR, near_pid == seed_pid, near_d <= NEAR_KM * 1000) |>
  group_by(hid) |>
  summarise(n_near = sum(n), .groups = "drop")
n_out <- ev_i |> filter(is.na(pid)) |> group_by(hid) |> summarise(n_out = sum(n), .groups = "drop")

x <- n_I |>
  full_join(n_U, by = "hid") |>
  left_join(top1, by = "hid") |>
  left_join(top2, by = "hid") |>
  left_join(near, by = "hid") |>
  left_join(n_out, by = "hid") |>
  mutate(n_I = coalesce(n_I, 0), n_U = coalesce(n_U, 0), n_in = coalesce(n_in, 0),
         n_near = coalesce(n_near, 0), n_out = coalesce(n_out, 0),
         share_pid = if_else(n_I > 0, (n_in + n_near) / n_I, 0),
         share_near = if_else(n_I > 0, n_near / n_I, 0),
         share_pid_2 = coalesce(share_pid_2, 0),
         share_outside = if_else(n_I > 0, (n_out - n_near) / n_I, NA_real_)) |>
  # distance between the two candidate polygons: a second candidate next door is a second berth,
  # one far away is a second harbour
  mutate(km_2 = vapply(seq_len(n()), function(i) {
    if (is.na(seed_pid[i]) || is.na(pid_2[i])) return(NA_real_)
    as.numeric(sf::st_distance(P_m[P_m$pid == seed_pid[i], ], P_m[P_m$pid == pid_2[i], ])[1, 1]) / 1000
  }, 0)) |>
  mutate(status = case_when(
    hid %in% BOOTSTRAP_EXCLUDED                               ~ "bootstrap_excluded",
    n_I == 0                                                  ~ "no_I_events",
    share_outside > OUTSIDE_MAX | is.na(seed_pid)             ~ "unmatched",
    n_I < LOW_N                                               ~ "low_n",
    share_pid_2 >= COLLIDE_SHARE & km_2 >= COLLIDE_KM         ~ "collision",
    share_pid >= AUTO_SHARE                                   ~ "auto",
    TRUE                                                      ~ "review"),
    # a "review" code that also splits across two polygons is the collision case
    status = if_else(status == "auto" & share_pid_2 >= 0.05, "review", status)) |>
  left_join(sf::st_drop_geometry(P), by = c("seed_pid" = "pid")) |>
  mutate(pid = seed_pid, resolve = "code", basis = "reconstructed", override_reason = NA_character_)

# -- Reviewed overrides re-enter here, as an input --------------------------------

ov_file <- "overrides/stk_hid_pid.csv"
ov <- read.csv(ov_file, colClasses = "character")
if (nrow(ov)) {
  stopifnot(all(c("hid", "pid", "reason") %in% names(ov)),
            !anyDuplicated(ov$hid),
            all(ov$pid %in% P$pid | ov$pid %in% c("NONE", "BY_POSITION")))
  x <- x |>
    left_join(ov |> transmute(hid, ov_pid = pid, ov_reason = reason), by = "hid") |>
    mutate(pid = case_when(is.na(ov_pid) ~ pid, ov_pid %in% c("NONE", "BY_POSITION") ~ NA_character_, TRUE ~ ov_pid),
           resolve = if_else(!is.na(ov_pid) & ov_pid == "BY_POSITION", "position", resolve),
           basis = if_else(is.na(ov_pid), basis, "recorded"),
           status = if_else(is.na(ov_pid), status, "override"),
           override_reason = ov_reason) |>
    select(-ov_pid, -ov_reason)
  # names follow the final pid, not the seed
  x <- x |> select(-port, -hid_logbook) |>
    left_join(sf::st_drop_geometry(P), by = "pid")
}

out <- x |>
  transmute(hid, pid, resolve, port, hid_logbook, status, basis, n_I = as.integer(n_I), n_U = as.integer(n_U),
            seed_pid, share_pid, share_near, pid_2, share_pid_2, km_2, share_outside, override_reason) |>
  arrange(desc(n_I))

stopifnot(!anyDuplicated(out$hid))

out |> write_curated(
  fd_curated("reference", "stk_hid_pid.parquet"),
  inputs = c(fd_staging("aux", "ports.fgb"), ov_file,
             list.files(fd_raw("oracle", "stk", "trail"), pattern = "parquet$", recursive = TRUE,
                        full.names = TRUE)))

message(sprintf("stk_hid_pid: %d codes; %s", nrow(out),
                paste(names(table(out$status)), table(out$status), collapse = ", ")))
