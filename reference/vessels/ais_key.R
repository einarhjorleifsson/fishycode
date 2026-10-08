# The mobile-id -> vid key the pipeline consumes, built from the SEGMENT TABLE (stage 2 of the key).
#
# Input:  curated/check/ais_key_segments.parquet         the evidence-graded segment table (plan 009, decision 047-052)
#         curated/vessel/vessel_ais_key_cascade.parquet  identifiers and entity class of every mobile-id; rows of the
#                                                        mobile-ids the segment table does not cover (navaids, buoys, ...)
#         curated/vessel/{vessel,vessel_identity}.parquet  MMSI of the vid at the time
# Output: curated/vessel/vessel_ais_key.parquet          same columns as before the switch; one row per segment
#         curated/vessel/vessel_ais_device.parquet       gear devices and the vid that carries each: NOT in the key
#
# Before 2026-09-30 this file was the cascade (now reference/vessels/ais_key_cascade.R) and read the manual ODS.
# It cannot be that any more: the segment table reads the cascade, so the two must be separate targets.
#
# What a row means now: a stretch of one mobile-id, tiling every mobile-id the segment table covers from its first
# ping to its last (no ping unassigned), with the vid the best evidence names. `step` records the evidence
# ("segment: physical", ...), `tier` its grade (A physical or reviewed, B registry or logbook, C landings, D continuity,
# E a kept foreign override). A stretch the evidence cannot place has vid NA and is listed for a person: it is a
# row, not a silent hole. Gear devices (MMSI 941/99/97) are not vessels and are left out of the key; their link to the
# carrying vid lives in vessel_ais_device. Nothing is hand-edited: a person's verdict enters through
# overrides/ais_key_segments_reviewed.csv, an input of the segment table.
#
# d2 is a DATE and the last day of a stretch runs to its end; consumers join half-open on d2 + 1
# (sources/stk/convert.R, curate/ais_ping_union.R).

library(dplyr)
library(nanoparquet)

SENTINEL <- as.Date("2028-12-24")
seg <- read_parquet(fd_curated("check", "ais_key_segments.parquet")) |> mutate(mid = as.numeric(mid), d1 = as.Date(d1), d2 = as.Date(d2))
casc <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet"))
ident <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  transmute(vid = as.integer(vid), mmsi, t1 = as.Date(t1), t2 = as.Date(t2)) |> filter(!is.na(mmsi))
reg <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> transmute(vid = as.integer(vid), mmsi_reg = mmsi)

# the mobile-id's own identifier strings, as the cascade read them
ids <- casc |> arrange(mid, d1) |> group_by(mid) |> slice(1) |> ungroup() |> select(mid, loid, glid)

# the MMSI the vid carried during the stretch: the identity window overlapping it most, else the registry's current one
mm <- seg |> filter(!is.na(vid)) |> select(mid, seg_no, vid, d1, d2) |>
  inner_join(ident, by = "vid", relationship = "many-to-many") |>
  mutate(ov = pmax(0, as.numeric(pmin(d2, t2, na.rm = TRUE) - pmax(d1, t1, na.rm = TRUE)) + 1)) |>
  group_by(mid, seg_no) |> arrange(desc(ov), .by_group = TRUE) |> slice(1) |> ungroup() |> select(mid, seg_no, mmsi)

rows <- seg |>
  left_join(ids, by = "mid") |> left_join(mm, by = c("mid", "seg_no")) |> left_join(reg, by = "vid") |>
  transmute(mid, loid, glid, pings = as.integer(pings),
            n_years = as.integer(pmax(1L, as.integer(format(pmin(d2, as.Date("2026-12-31")), "%Y")) - as.integer(format(d1, "%Y")) + 1L)),
            d1, d2, vid = as.integer(vid), no = as.integer(seg_no),
            step = paste0("segment: ", source), entity_class = coalesce(entity_class, "vessel"),
            basis = if_else(source == "foreign: kept override", "recorded", "reconstructed"),
            vid_older = NA_integer_, type = step, lifetime_conflict = NA, lifetime_note = NA_character_,
            mmsi = coalesce(mmsi, mmsi_reg), d2_is_open = d2 >= SENTINEL,
            tier = c(A = "A", B = "B", C = "C", D = "D", E = "E")[grade], device)

device_link <- rows |> filter(device) |> transmute(mid, loid, glid, d1, d2, carrier_vid = vid, pings)
vessel_rows <- rows |> filter(!device) |> select(-device)

# mobile-ids the segment table does not cover keep their cascade rows (navaids, buoys, net relays, shore stations ...)
# A negative cascade vid is an ODS `drop` (a person decided it is not a vessel): no vessel here, the step stays as the record.
rest <- casc |> filter(!mid %in% seg$mid) |> select(any_of(names(vessel_rows))) |>
  mutate(vid = if_else(!is.na(vid) & vid <= 0L, NA_integer_, vid))
key <- bind_rows(vessel_rows, rest) |> mutate(mid = as.numeric(mid)) |> arrange(mid, d1) |> mutate(.rid = row_number(), .before = 1)

# Acceptance: the stretches of a mobile-id in the table tile it - no gap, no overlap
tiles <- vessel_rows |> arrange(mid, d1) |> group_by(mid) |> summarise(ok = all(d1[-1] == d2[-n()] + 1L), .groups = "drop")
stopifnot("a mobile-id's stretches leave a gap or overlap" = all(tiles$ok))
print(key |> summarise(rows = n(), mids = n_distinct(mid), with_vid = sum(!is.na(vid)), pings_no_vid = sum(pings[is.na(vid)], na.rm = TRUE)) |>
        knitr::kable(caption = "vessel_ais_key (from the segment table)"))
print(key |> filter(!is.na(vid)) |> count(tier, step, name = "rows") |> arrange(tier, desc(rows)) |> knitr::kable(caption = "reliability tier"))
cat("gear devices with a link to a carrying vid:", nrow(device_link), "rows,", n_distinct(device_link$mid), "mobile-ids\n")

key_inputs <- c(fd_curated("check", "ais_key_segments.parquet"), fd_curated("vessel", "vessel_ais_key_cascade.parquet"),
                fd_curated("vessel", "vessel.parquet"), fd_curated("vessel", "vessel_identity.parquet"))
write_curated(key, fd_curated("vessel", "vessel_ais_key.parquet"), inputs = key_inputs)
write_curated(device_link, fd_curated("vessel", "vessel_ais_device.parquet"), inputs = key_inputs)
