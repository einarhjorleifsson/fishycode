# aflaskeyti_weight.R — the state of each catch weight in dw_aflaskeyti: round, or gutted for some Icelandic vessels.
# Side: preprocessing (aflaskeyti). See plan 014 and plan 026 §7.
#
# Input:  staging/aflaskeyti/{station,trip,catch}.parquet and time.parquet (the hauls, their vid and t2)
#         staging/afli/{trip,fishing_sample,catch}.parquet  (the Icelandic logbook as staged: upstream of the merge)
#         raw/oracle/dw/dw_aflaskeyti.parquet               (upprunaland_cd, the flag: the station key is a row's id)
# Output: staging/aflaskeyti/weight.parquet  (.sid, sid, condition, catch_whole, condition_basis) — a side table,
#         joined onto the catch by curate/logbook.R; catch.parquet is untouched.
#
# Declaration and evidence: curate/corrections/aflaskeyti_weight.yml. Every row says "live weight in kg.", yet where
# the Icelandic logbook has the same haul it holds 1.25 times the ERS weight of demersal species for some vessels
# (gutted against round, catch_by_species_station.R's factor) and the same weight for others: a trait of the vessel.
#   foreign rows                      UNGU  recorded       (landed in Iceland at 0.98-1.13 of it, decision 126)
#   Icelandic, vessel and species
#     with matched hauls              the majority of its matched rows: 1.25 -> GUTT, equal -> UNGU   derived
#     species round for every vessel  UNGU  derived        (blue whiting, redfish, shrimp: equal wherever matched)
#     otherwise                       NA    none           (no evidence; catch_by_species_station.R takes it as round)
# A GUTT weight has no whole weight recorded, so catch_whole is NA there.

library(dplyr)

RATIO_GUTT <- 1.25
TOL        <- 0.01   # relative, around 1 and 1.25
MATCH_S    <- 60     # seconds between the ERS start and the logbook's t2
ROUND_MIN  <- 20     # matched rows a species needs before "round for every vessel" is read off it

od <- function(...) duckdbfs::open_dataset(...)

flag <- od(fd_raw("oracle", "dw", "dw_aflaskeyti.parquet")) |>
  transmute(.sid = as.numeric(aflaskeyti_id), flag = upprunaland_cd) |>
  collect()
haul <- od(fd_staging("aflaskeyti", "station.parquet")) |> select(.sid, .tid) |> collect() |>
  left_join(od(fd_staging("aflaskeyti", "trip.parquet")) |> select(.tid, vid) |> collect(), by = ".tid") |>
  left_join(od(fd_staging("aflaskeyti", "time.parquet")) |> select(.sid, t1, t2) |> collect(), by = ".sid") |>
  transmute(.sid, vid, start = coalesce(t2, t1)) |>
  left_join(flag, by = ".sid", relationship = "one-to-one")
catch <- od(fd_staging("aflaskeyti", "catch.parquet")) |> select(.sid, sid, catch) |> collect()
stopifnot(!anyNA(haul$flag), !anyNA(haul$vid))

# the Icelandic hauls matched to the staged afli logbook ------------------------------------------------------------
isl <- haul |> filter(flag == "ISL")
t_lo <- min(isl$start) - lubridate::days(1)
t_hi <- max(isl$start) + lubridate::days(1)
lb <- od(fd_staging("afli", "fishing_sample.parquet")) |>
  select(.sid, .tid, t2) |>
  filter(!is.na(t2), t2 >= !!t_lo, t2 <= !!t_hi) |>
  inner_join(od(fd_staging("afli", "trip.parquet")) |> select(.tid, vid) |> filter(vid %in% !!unique(isl$vid)),
             by = ".tid") |>
  collect()
match <- isl |>
  inner_join(lb |> rename(.sid_lb = .sid, t2_lb = t2), by = join_by(vid), relationship = "many-to-many") |>
  filter(abs(as.numeric(difftime(t2_lb, start, units = "secs"))) <= MATCH_S) |>
  slice_min(abs(as.numeric(difftime(t2_lb, start, units = "secs"))), n = 1, with_ties = FALSE, by = .sid)
lb_catch <- od(fd_staging("afli", "catch.parquet")) |>
  filter(.sid %in% !!unique(match$.sid_lb)) |>
  summarise(kg_lb = sum(catch, na.rm = TRUE), .by = c(.sid, sid)) |>
  collect() |>
  rename(.sid_lb = .sid)
pairs <- match |>
  select(.sid, .sid_lb, vid) |>
  inner_join(catch, by = ".sid", relationship = "one-to-many") |>
  inner_join(lb_catch, by = c(".sid_lb", "sid")) |>
  filter(catch > 0, kg_lb > 0) |>
  mutate(ratio = kg_lb / catch,
         state = case_when(abs(ratio - 1) <= TOL ~ "UNGU", abs(ratio / RATIO_GUTT - 1) <= TOL ~ "GUTT"))

by_vessel_species <- pairs |>
  filter(!is.na(state)) |>
  count(vid, sid, state) |>
  slice_max(n, n = 1, with_ties = FALSE, by = c(vid, sid)) |>
  select(vid, sid, state_vs = state)
round_species <- pairs |>
  summarise(n = n(), share_round = mean(state %in% "UNGU"), .by = sid) |>
  filter(n >= ROUND_MIN, share_round >= 0.95) |>
  pull(sid)

# every catch row ---------------------------------------------------------------------------------------------------
weight <- catch |>
  left_join(haul |> select(.sid, vid, flag), by = ".sid", relationship = "many-to-one") |>
  left_join(by_vessel_species, by = c("vid", "sid"), relationship = "many-to-one") |>
  mutate(condition = case_when(flag != "ISL"         ~ "UNGU",
                               !is.na(state_vs)      ~ state_vs,
                               sid %in% round_species ~ "UNGU"),
         condition_basis = case_when(flag != "ISL" ~ "recorded",
                                     !is.na(condition) ~ "derived",
                                     .default = "none"),
         catch_whole = if_else(condition %in% "UNGU", as.numeric(catch), NA_real_)) |>
  select(.sid, sid, condition, catch_whole, condition_basis)

cat(sprintf("aflaskeyti weight: %d Icelandic hauls matched to afli, %d station-species pairs\n",
            n_distinct(match$.sid), nrow(pairs)))
print(weight |> left_join(haul |> select(.sid, flag), by = ".sid") |> count(flag, condition, condition_basis))

weight |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "weight.parquet"))
