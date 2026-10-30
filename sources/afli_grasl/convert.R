# afli's own lumpfish logbook (grásleppuskýrslur) as a logbook source of its own, at the vessel-day (TODO 167).
# Side: preprocessing (logbook). See plan 014.
#
# Input:  raw/oracle/afli/grasl_sokn.parquet   per vessel, day and square: roe kg, lumpfish and lumpsucker counted,
#                                              nets hauled, nights, depth (1977-2016)
#         raw/oracle/afli/grasl_stofn.parquet  per vessel-year: the salting stage (teg_verkunar), barrels, roe, net
#         curated/reference/gear.parquet       the gear of gid 3 (GNS_LUM) and 4 (GNS_LUR)
# Output: staging/afli_grasl/{trip,station,fishing_sample,catch}.parquet   the shape curate/logbook.R reads
#         staging/afli_grasl/record.parquet       every grasl_sokn row in one outcome (staged, or why not), with what
#                                                 the merge does not take: the fish counted, the lumpfish area, the
#                                                 nets, the nights, the depth and the stage
#         staging/afli_grasl/vessel_year.parquet  grasl_stofn's vessel-years: stage, barrels, roe, net, mesh, flag
#
# The maintainer chose it on 2026-10-30 (plan 051 ask c, option B of $FISHYDATA/archive/2026-10-whole-weight/
# lumpfish.md §7; plan 054 ask d: built now, its factors provisional until HV 2020-33's authors answer). One grasl_sokn
# row is one station: a vessel's day in a square (reitur), with no time and no position but the square. Its trip is
# the vessel-day, the unit its catch sits on, coarser than a fix (the project's done-criterion 2). The days hold catch
# no other source holds: 7 vessel-days of 2005-2016 are also in the main logbook (lumpfish.md §3.8), which the merge
# keeps there (tier 5, curate/logbook.R).
#
# The catch is the roe as logged, kg_hrogn, under grásleppa (sid 951), in the state of its vessel-year's salting stage:
# `condition` "stage 1".."stage 4" (with all fluid, drained, ready for salting, salted; HV 2020-33), or "stage unknown"
# where grasl_stofn gives none. calc_whole_weight() (R/whole_weight.R) reads its factor to the whole lumpfish from the
# factor table's `lumpfish logbook` rows: roe / the stage's factor x 100/29.4, basis reconstructed. The fish counted
# (fj_grasl lumpfish, fj_raudm lumpsucker) stay in record.parquet: the merge's catch is kilograms. No raising to the
# barrels: they are per vessel-year, kept in vessel_year.parquet. A vessel-year whose roe, read any way (the days'
# roe, grasl_stofn's own, the days' fish x 0.881 kg, Table 1's stage-1 roe per fish), is under 20 kg a barrel is flagged
# `barrels_implausible` (15, lumpfish.md §3.4), one with barrels and no roe at all `barrels_no_roe` (27); neither is
# corrected. `g_sokn` and `g_stofn` are older copies of
# 1982-1991 (lumpfish.md §3.1) and are not read. The free-text note (athugasemd) is not read.
#
# Effort: nets hauled (dregin) as effort_count, unit nets; nights soaked (naetur) as the duration, a night taken as
# 24 hours (duration_m = naetur x 1440), so effort is net-nights, the unit of MFRI's lumpfish CPUE. The gear is
# grásleppunet (gid 3), or rauðmaganet (gid 4) on a day that counted lumpsucker only. The depth (dypi) is kept as
# recorded in z1; its unit is not known, so the merge reads it as z1_raw with no depth in metres.
#
# The date as recorded, with the year the record gives (vear) for its vessel-year: 6 rows' dates lie in another year
# than vear (5 of 2013 under 2016, 1 of 2011 under 2010), and are staged as dated. A date before the logbook began
# (1977) is not a date, and the row is not staged.
#
# The ids: grasl_sokn has none, and the table ends in 2016, so .sid is the row's rank in a fixed order of every column
# read (stable while the table is), and .tid the vessel-day's rank, as text like the other schemas' trip ids.

library(dplyr)

SCHEMA <- "afli_grasl"
ROE_PER_BARREL_MIN <- 20       # kg; below it a vessel-year's barrels are impossible (lumpfish.md §3.4)
ROE_PER_FISH <- 0.881          # kg of fresh roe per lumpfish counted (HV 2020-33, Table 1, stage 1)
FIRST_DAY <- as.Date("1977-01-01")

# Vessel-years ---------------------------------------------------------------------
stofn <- duckdbfs::open_dataset(fd_raw("oracle", "afli", "grasl_stofn.parquet")) |> collect() |>
  transmute(vid = as.integer(skipnr), year = as.integer(vear), stage = as.integer(teg_verkunar), net = gerd_neta,
            mesh = moskvi, barrels = tunnur, roe_year = hrogn)
stopifnot("a vessel-year twice in grasl_stofn" = !anyDuplicated(stofn[c("vid", "year")]))

# Days -----------------------------------------------------------------------------
sokn <- duckdbfs::open_dataset(fd_raw("oracle", "afli", "grasl_sokn.parquet")) |>
  select(-athugasemd) |> collect() |>
  transmute(vid = as.integer(skipnr), date = as.Date(vedags), year = as.integer(vear), sq = as.integer(reitur),
            sq_lumpfish = as.integer(grasl_reitur), z = as.integer(dypi), nets = as.integer(dregin),
            nights = as.integer(naetur), n_lumpfish = as.integer(fj_grasl), n_lumpsucker = as.integer(fj_raudm),
            roe = as.integer(kg_hrogn)) |>
  arrange(vid, date, year, sq, sq_lumpfish, z, nets, nights, n_lumpfish, n_lumpsucker, roe)

record <- sokn |>
  mutate(outcome = case_when(is.na(vid) | vid == 0 ~ "no vessel",
                             is.na(date) ~ "no date",
                             date < FIRST_DAY ~ "date impossible",
                             coalesce(roe, 0L) == 0 & coalesce(n_lumpfish, 0L) == 0 & coalesce(n_lumpsucker, 0L) == 0 &
                               coalesce(nets, 0L) == 0 ~ "nothing recorded",
                             .default = "staged"),
         year = coalesce(year, as.integer(format(date, "%Y")))) |>
  left_join(stofn |> select(vid, year, stage), by = c("vid", "year"), relationship = "many-to-one") |>
  mutate(.sid = if_else(outcome == "staged", as.numeric(cumsum(outcome == "staged")), NA_real_))
day <- record |>
  filter(outcome == "staged") |>
  mutate(.tid = as.character(dense_rank(paste(vid, date))))

# Tables in the merge's shape ---------------------------------------------------------
gear <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |>
  filter(version == "new", gid %in% c(3, 4)) |> collect() |>
  transmute(gid = as.integer(gid), gear, target, target2)
stopifnot("gid 3 or 4 is not in the gear reference" = nrow(gear) == 2)

trip <- day |>
  distinct(.tid, vid, date) |>
  transmute(.tid, vid, T1 = as.POSIXct(date, tz = "UTC"), hid1 = NA_integer_, T2 = as.POSIXct(date, tz = "UTC"),
            hid2 = NA_integer_, schema = SCHEMA)
station <- day |>
  transmute(.sid, .tid, date = as.POSIXct(date, tz = "UTC"), lon1 = NA_real_, lat1 = NA_real_, lon2 = NA_real_,
            lat2 = NA_real_, sq, ssq = NA_integer_, z1 = z, z2 = NA_integer_, schema = SCHEMA)
fishing_sample <- day |>
  transmute(.tid, .sid, schema = SCHEMA,
            gid = if_else(coalesce(n_lumpsucker, 0L) > 0 & coalesce(n_lumpfish, 0L) == 0 & coalesce(roe, 0L) == 0, 4L, 3L),
            duration_m = if_else(coalesce(nights, 0L) > 0, nights * 1440, NA_real_), duration_m_raw = duration_m,
            .duration_source = if_else(is.na(duration_m), "none", "recorded"),
            effort_count = if_else(coalesce(nets, 0L) > 0, as.numeric(nets), NA_real_),
            effort_count_basis = if_else(is.na(effort_count), "none", "recorded"),
            effort_count_unit = if_else(is.na(effort_count), NA_character_, "nets")) |>
  left_join(gear, by = "gid") |>
  relocate(gear, target, target2, .after = gid)
catch <- day |>
  filter(roe > 0) |>
  transmute(.sid, sid = 951L, catch = roe, condition = if_else(stage %in% 1:4, paste("stage", stage), "stage unknown"),
            catch_whole = NA_real_, schema = SCHEMA)

# every grasl_sokn row of the vessel-year, by the year the record gives, as lumpfish.md counted them
vessel_year <- stofn |>
  left_join(sokn |> summarise(roe_days = sum(roe, na.rm = TRUE), fish_days = sum(n_lumpfish, na.rm = TRUE),
                              days = n_distinct(date), .by = c(vid, year)),
            by = c("vid", "year")) |>
  mutate(roe_per_barrel = pmax(coalesce(roe_days, 0L), coalesce(roe_year, 0L), coalesce(fish_days, 0L) * ROE_PER_FISH) /
           barrels,
         flag = case_when(coalesce(barrels, 0) <= 0 ~ NA_character_,
                          roe_per_barrel == 0 ~ "barrels_no_roe",
                          roe_per_barrel < ROE_PER_BARREL_MIN ~ "barrels_implausible"),
         schema = SCHEMA)

# Account: every row in one outcome, kg in = kg out ---------------------------------
stopifnot(nrow(record) == nrow(sokn),
          sum(day$roe, na.rm = TRUE) == sum(catch$catch),
          !anyDuplicated(station$.sid), !anyNA(station$.tid), !anyDuplicated(trip$.tid),
          !anyDuplicated(trip[c("vid", "T1")]))
print(count(record, outcome, wt = NULL) |>
        left_join(count(record, outcome, wt = roe, name = "kg_roe"), by = "outcome"))
print(count(catch, condition, wt = catch, name = "kg_roe"))
print(count(vessel_year, flag, wt = barrels, name = "barrels") |> left_join(count(vessel_year, flag), by = "flag"))

dir <- fd_staging(SCHEMA)
for (t in c("trip", "station", "fishing_sample", "catch", "vessel_year"))
  duckdbfs::write_dataset(get(t), file.path(dir, paste0(t, ".parquet")))
record |>
  transmute(.sid, vid, date, year, sq, sq_lumpfish, z, nets, nights, n_lumpfish, n_lumpsucker, roe, stage, outcome,
            schema = SCHEMA) |>
  duckdbfs::write_dataset(file.path(dir, "record.parquet"))
