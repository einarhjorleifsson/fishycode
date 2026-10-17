# The ERS catch reports Iceland exchanged with Norway and the Faroes, 2014-2018, as logbook tables.
# Side: preprocessing (aflaskeyti). See plan 014 and plan 026.
#
# Input:  raw/oracle/dw/dw_aflaskeyti.parquet
#         curated/reference/gear.parquet   (version new: the logbook's gid for the Directorate's code, `map`)
# Output: staging/aflaskeyti/{trip,station,fishing_sample,catch}.parquet
#
# One row per haul and species in the source, every one a catch report (DCA); a haul becomes one station with one
# fishing sample (decision 126, plan 026 §1-2). Every flag is staged: the Icelandic vessels' hauls are mostly in the
# Icelandic logbook already, and curate/logbook.R keeps only those on vessel-days it lacks (plan 026 §7).
#
# Three defects are left for curate/corrections/ (AGENTS.md): the positions are staged as Oracle names them, `lengd`
# as longitude, though they are swapped (aflaskeyti_coordinates.R); Faroese summer times are local
# (aflaskeyti_local_time.R); and some Icelandic vessels report demersal catch gutted (aflaskeyti_weight.R). The source
# has no trips: here they are a vessel's runs of hauls cut at 48-hour gaps, and curate/aflaskeyti_trip.R cuts them at
# landings in Iceland and dates them.

library(tidyverse)
library(duckdbfs)

SCHEMA  <- "aflaskeyti"
# Hours from one haul's end to the next haul's start that end a run. Without a landing between, 95 % of gaps are
# below 23.4 h (Faroese) and 32.5 h (Norwegian) (plan 026 §4).
GAP_MAX <- 48

# hauls ------------------------------------------------------------------------
raw <- duckdbfs::open_dataset(fd_raw("oracle", "dw", "dw_aflaskeyti.parquet")) |>
  collect()

# A haul is a vessel's start time: no vessel starts two at one minute. A haul sent in more than one message (1,131
# Icelandic hauls, one Norwegian) is the latest message's, whole: its species rows replace the earlier ones. Where
# the Icelandic logbook has the haul, the latest message agrees with it in 2,892 of 2,979 species rows and the
# earliest in 2,211 of 2,772 (plan 026 §7). The station key is the haul's lowest aflaskeyti_id, the source's own id.
rows <- raw |>
  mutate(latest = ers_id[order(dagsetning_skeytis_dt, aflaskeyti_id, decreasing = TRUE)[1]],
         .by = c(id_skip, dagsetning_hols_dt)) |>
  filter(ers_id == latest) |>
  mutate(.sid = as.numeric(min(aflaskeyti_id)), .by = c(id_skip, dagsetning_hols_dt))

haul <- rows |>
  arrange(.sid, aflaskeyti_id) |>
  distinct(.sid, .keep_all = TRUE) |>
  transmute(.sid,
            vid      = as.integer(id_skip),
            date     = as_date(dagsetning_hols),
            start    = dagsetning_hols_dt,
            dur      = as.numeric(lengd_hols),
            lon1     = lengd_byrjun, lat1 = breidd_byrjun,   # swapped: aflaskeyti_coordinates.R
            lon2     = lengd_endir,  lat2 = breidd_endir,
            gid_old  = as.integer(id_veidarfaeri))

# gear -------------------------------------------------------------------------
# The Directorate's codes resolve through gear.parquet's `map`: 1 -> 12 (LLS), 6 -> 6, 7 -> 9, 14 -> 8; for a code
# several gids share (1: Lína, Landbeitt lína, Línutrekt) the lowest. Four codes have no row there. MFRI's gear
# register, raw/oracle/gear/veidarfaeri_v (same numbers), gives their ISSCFG class, as does the source's FAO column:
# purse seine with two boats (57, ISSCFG 0110 PS) and with one (56, PS_1; not in the register) is Nót; bottom pair
# trawl (75, 0315 PTB) and twin bottom otter trawl (76, 0313 OTT), Icelandic rows only, are Botnvarpa. gid_old keeps
# the code. (The Icelandic logbook agrees for PTB on 127 matched hauls; for OTT it says Flotvarpa on 2.)
gref <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |>
  filter(version == "new") |>
  collect() |>
  mutate(gid = as.integer(gid))
gmap <- gref |>
  filter(!is.na(map)) |>
  arrange(gid) |>
  distinct(map, .keep_all = TRUE) |>
  transmute(gid_old = as.integer(map), gid) |>
  bind_rows(tibble(gid_old = c(56L, 57L, 75L, 76L), gid = c(10L, 10L, 6L, 6L)))

haul <- haul |>
  left_join(gmap, by = "gid_old", relationship = "many-to-one") |>
  left_join(gref |> select(gid, gear, target, target2), by = "gid", relationship = "many-to-one")
stopifnot(!anyNA(haul$gid))

# trip -------------------------------------------------------------------------
# A run is a vessel's hauls with no gap of GAP_MAX hours or more; its key is its first station's.
haul <- haul |>
  mutate(end = start + minutes(dur)) |>
  arrange(vid, start, .sid) |>
  mutate(new_run = coalesce(as.numeric(difftime(start, lag(end), units = "hours")) >= GAP_MAX, TRUE),
         .tid    = as.character(.sid[cummax(if_else(new_run, row_number(), 0L))]),
         .by     = vid)

trip <- haul |>
  summarise(T1 = min(start), .by = c(.tid, vid)) |>
  transmute(.tid, vid, T1, hid1 = NA_integer_, T2 = as.POSIXct(NA, tz = "UTC"), hid2 = NA_integer_,
            source = "ERS DCA (dw_aflaskeyti)", schema = SCHEMA)

# station ----------------------------------------------------------------------
station <- haul |>
  transmute(.sid, .tid, date, lon1, lat1, lon2, lat2, schema = SCHEMA)

# fishing sample ---------------------------------------------------------------
# Mobile gear and purse seine: the reported start is t2 and the duration t2 to t3; on the Icelandic trawl rows t2
# matches the logbook within a minute and the duration equals t3 - t2 (decision 126). Longlines: start to end is
# setting start to hauling end, t1 to t4 (Norwegian LL: 7.7 kn in the first hour, 1.9 kn in the last; plan 026 §2),
# so the soak, t2 to t3, is not known. A duration of 0 is not one: 50 purse seine sets (41 of them Faroese) and 13
# Norwegian LL hauls.
fishing_sample <- haul |>
  mutate(static = gear == "LLS",
         timed  = dur > 0) |>
  transmute(.tid, .sid, gid_old, gid = as.numeric(gid), gear, target, target2,
            t1 = if_else(static, start, NA),
            t2 = if_else(!static, start, NA),
            t3 = if_else(!static & timed, end, NA),
            t4 = if_else(static & timed, end, NA),
            duration_m       = if_else(!static & timed, dur, NA_real_),
            .t2_source       = if_else(!static, "data", NA_character_),
            .t3_source       = if_else(!static & timed, "derived", NA_character_),
            .duration_source = case_when(static ~ "missing", timed ~ "data", .default = "implausible"),
            schema = SCHEMA)

# catch ------------------------------------------------------------------------
# Round weight: every row says "live weight in kg.", and the weight landed in Iceland is 0.98-1.13 of it, never
# near 1.25 (decision 126). Whole kilograms on every row.
catch <- rows |>
  summarise(kg = sum(afli_kg), .by = c(.sid, id_fisktegund)) |>
  transmute(.sid, sid = as.integer(id_fisktegund), condition = "UNGU",
            catch_whole = as.numeric(kg), catch = as.integer(kg), schema = SCHEMA) |>
  arrange(.sid, sid)

stopifnot(!anyDuplicated(station$.sid), !anyDuplicated(trip$.tid),
          all(catch$.sid %in% station$.sid), all(station$.tid %in% trip$.tid))

# save -------------------------------------------------------------------------
trip           |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "trip.parquet"))
station        |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "station.parquet"))
fishing_sample |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "fishing_sample.parquet"))
catch          |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "catch.parquet"))
