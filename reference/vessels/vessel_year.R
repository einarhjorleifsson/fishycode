# Usage type, engine power and length of each vessel by year, each with its basis (plan 016 §4 step 5, §7 h, i).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  raw/external/hreidar/data-raw/HREIDAR_Islensk_skip.xlsx   one row per vid and year to 2021 ("Data main")
#         raw/oracle/vessel/vessel_hist_v.parquet                          Oracle's dated history: usage category, kW
#         raw/oracle/vessel/vessel_measurement_hist_v.parquet              Oracle's dated history: length (by vessel_id)
#         raw/oracle/vessel/vessel_v.parquet                               the current register; vessel_id -> vid
#         raw/oracle/vessel/usage_category.parquet                         the usage-category codes
# Output: curated/vessel/vessel_year.parquet - one row per vid (in the register) and year, 2007 to this year
#
# vessel.parquet holds today's values for every year. A hull's use, engine and length change: in 2007-2021, 437 of
# 2,835 vids change usage type and 351 change kW in Hreiðar's table. The effort on a fix is kW x hours, so the kW of the
# fix's own year is what curate/ais_trail.R needs, and the usage type of the year tells leisure from fishing, and an
# expected absence of logbooks and landings from a gap. Each attribute takes the first source that has it:
#
#   hreidar       Hreiðar's table, 2007-2021 (keyed on Skskr.nr., reliable from 2007: decision 046)
#   oracle_hist   Oracle's history, the row in force on 1 July of the year
#   oracle_later  Oracle's earliest row after that date - for 2022-23 mostly the register's system change of 2023-12
#   current       today's register
#
# mclass is Oracle's usage-category code; `usage` keeps Hreiðar's or Oracle's own text. SKB pleasure craft are not in
# the register and have no row here.

library(dplyr)
library(nanoparquet)

YEARS <- 2007:as.integer(format(Sys.Date(), "%Y"))

# Hreiðar's names that are not Oracle's category names, mapped by meaning; the text is kept in `usage`
HREIDAR_USAGE <- c("SKEMMTISKIP" = 62L, "OLÍUSKIP" = 48L, "RANNSÓKNASKIP" = 44L, "FISKI, FARÞEGASKIP" = 64L,
                   "DRÁTTARBÁTUR" = 50L, "BRUNNBÁTUR" = 67L,
                   "UPPSJÁVARSKIP" = 33L, "TOGSKIP" = 33L, "LÍNUBÁTUR" = 33L)
num <- function(x) suppressWarnings(as.numeric(gsub(",", ".", as.character(x))))

uc <- read_parquet(fd_raw("oracle", "vessel", "usage_category.parquet")) |>
  transmute(mclass = as.integer(usage_category_no), key = toupper(trimws(name)))
usage_code <- function(txt) {
  key <- toupper(trimws(txt))
  coalesce(uc$mclass[match(key, uc$key)], unname(HREIDAR_USAGE[key]))
}

v <- read_parquet(fd_raw("oracle", "vessel", "vessel_v.parquet")) |>
  transmute(vid = as.integer(registration_no), vessel_id = as.integer(vessel_id),
            mclass_now = as.integer(usage_category_no), kw_now = num(power_kw), loa_now = num(max_length))

# Hreiðar ------------------------------------------------------------------------------------------------------------
h <- readxl::read_excel(fd_raw("external", "hreidar", "data-raw", "HREIDAR_Islensk_skip.xlsx"),
                        sheet = "Data main", guess_max = 50000) |>
  suppressWarnings() |>
  transmute(vid = suppressWarnings(as.integer(`Skskr.nr.`)), year = suppressWarnings(as.integer(`Ár`)),
            usage_h = Notkunarteg, segment = `Megingerð`, kw_h = num(`KW mælt`), loa_h = num(`Mesta lengd`)) |>
  filter(!is.na(vid), year %in% YEARS) |>
  distinct(vid, year, .keep_all = TRUE) |>
  mutate(kw_h = if_else(kw_h > 0, kw_h, NA_real_), loa_h = if_else(loa_h > 0, loa_h, NA_real_))

# Oracle's history ---------------------------------------------------------------------------------------------------
mid_year <- function(y) as.Date(paste0(y, "-07-01"))
as_day <- function(x) as.Date(format(x, "%Y-%m-%d"))
oh <- read_parquet(fd_raw("oracle", "vessel", "vessel_hist_v.parquet")) |>
  transmute(vid = as.integer(registration_no), from = as_day(valid_from), to = as_day(valid_to),
            mclass_o = as.integer(usage_category_no), usage_o = usage_category, kw_o = num(power_kw))
om <- read_parquet(fd_raw("oracle", "vessel", "vessel_measurement_hist_v.parquet")) |>
  transmute(vessel_id = as.integer(vessel_id), from = as_day(valid_from), to = as_day(valid_to), loa_o = num(max_length)) |>
  inner_join(v |> select(vessel_id, vid), by = "vessel_id") |>
  select(-vessel_id)

# the row in force on 1 July, else the earliest one after it
at_mid_year <- function(hist, grid) {
  g <- grid |> mutate(d = mid_year(year))
  inforce <- g |> inner_join(hist, by = join_by(vid, d >= from, d < to)) |>
    arrange(vid, year, desc(from)) |> distinct(vid, year, .keep_all = TRUE) |> mutate(when = "oracle_hist")
  later <- g |> anti_join(inforce, by = c("vid", "year")) |>
    inner_join(hist, by = join_by(vid, d < from)) |>
    arrange(vid, year, from) |> distinct(vid, year, .keep_all = TRUE) |> mutate(when = "oracle_later")
  bind_rows(inforce, later) |> select(-d, -from, -to)
}

grid <- tidyr::expand_grid(vid = v$vid, year = YEARS)
o_use <- at_mid_year(oh |> select(vid, from, to, mclass_o, usage_o), grid) |> rename(use_when = when)
o_kw  <- at_mid_year(oh |> filter(!is.na(kw_o), kw_o > 0) |> select(vid, from, to, kw_o), grid) |> rename(kw_when = when)
o_loa <- at_mid_year(om |> filter(!is.na(loa_o), loa_o > 0), grid) |> rename(loa_when = when)

vessel_year <-
  grid |>
  left_join(v, by = "vid") |>
  left_join(h, by = c("vid", "year")) |>
  left_join(o_use, by = c("vid", "year")) |>
  left_join(o_kw, by = c("vid", "year")) |>
  left_join(o_loa, by = c("vid", "year")) |>
  mutate(
    mclass_h = usage_code(usage_h),
    mclass = coalesce(mclass_h, mclass_o, mclass_now),
    usage  = case_when(!is.na(mclass_h) ~ usage_h, !is.na(mclass_o) ~ usage_o, .default = NA_character_),
    mclass_basis = case_when(!is.na(mclass_h) ~ "hreidar", !is.na(mclass_o) ~ use_when,
                             !is.na(mclass_now) ~ "current", .default = "none"),
    kw = coalesce(kw_h, kw_o, if_else(kw_now > 0, kw_now, NA_real_)),
    kw_basis = case_when(!is.na(kw_h) ~ "hreidar", !is.na(kw_o) ~ kw_when,
                         !is.na(kw_now) & kw_now > 0 ~ "current", .default = "none"),
    loa = coalesce(loa_h, loa_o, if_else(loa_now > 0, loa_now, NA_real_)),
    loa_basis = case_when(!is.na(loa_h) ~ "hreidar", !is.na(loa_o) ~ loa_when,
                          !is.na(loa_now) & loa_now > 0 ~ "current", .default = "none")) |>
  select(vid, year, mclass, usage, mclass_basis, segment, kw, kw_basis, loa, loa_basis) |>
  arrange(vid, year)

# Checks ---------------------------------------------------------------------------------------------------------------
stopifnot("one row per vid and year" = !anyDuplicated(vessel_year[c("vid", "year")]))
cat("vessel-years:", nrow(vessel_year), " vids:", n_distinct(vessel_year$vid), " years:", paste(range(YEARS), collapse = "-"), "\n")
print(vessel_year |> count(year > 2021, kw_basis) |> tidyr::pivot_wider(names_from = kw_basis, values_from = n))
print(vessel_year |> count(year > 2021, mclass_basis) |> tidyr::pivot_wider(names_from = mclass_basis, values_from = n))
cat("unmapped Hreiðar usage names:", paste(unique(h$usage_h[is.na(usage_code(h$usage_h)) & !is.na(h$usage_h)]), collapse = ", "), "\n")

write_curated(vessel_year, fd_curated("vessel", "vessel_year.parquet"),
              inputs = c(fd_raw("external", "hreidar", "data-raw", "HREIDAR_Islensk_skip.xlsx"),
                         fd_raw("oracle", "vessel", "vessel_hist_v.parquet"), fd_raw("oracle", "vessel", "vessel_measurement_hist_v.parquet"),
                         fd_raw("oracle", "vessel", "vessel_v.parquet"), fd_raw("oracle", "vessel", "usage_category.parquet")))
