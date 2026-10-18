# Usage type, engine power and length of each vessel by year, each with its basis (plan 016 §4 step 5, §7 h, i), from the
# ship register's history (plan 028 step 7).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  curated/vessel/register/vessel_hist.parquet              the register's usage type (code and text) and power
#                                                                   (power_kw), every year, within the hull's registered
#                                                                   life (decisions 136, 142, 144)
#         curated/vessel/register/vessel_engines_hist.parquet      the main engine's power, where power_kw is missing
#         curated/vessel/register/vessel_measurement_hist.parquet  length overall (max_length)
#         curated/vessel/register/decision.parquet                 the witnesses of each value
#         staging/hreidar/vessel_year.parquet                      Hreiðar's segment (Megingerð), 2007-2021
#         raw/oracle/vessel/vessel_v.parquet                       the `vessel` schema's current values: hulls the register
#                                                                   does not carry (foreign, never on the main register)
# Output: curated/vessel/vessel_year.parquet - one row per vid (in the `vessel` schema) and year, 2007 to this year
#
# vessel.parquet holds today's values for every year. A hull's use, engine and length change. The effort on a fix is
# kW x hours, so the kW of the fix's own year is what curate/ais_trail.R needs, and the usage type of the year tells
# leisure from fishing, and an expected absence of logbooks and landings from a gap. Each attribute takes the first that
# has it, and says which in its basis:
#
#   register          the register's value in force on 1 July of the year
#   register_later    the register's earliest value after that date (a hull registered later)
#   register_earlier  the register's last value before it (a hull struck before)
#   current           the `vessel` schema's current value, for a hull the register never carries
#   none
#
# and its witnesses in `*_source` (pdf | hreidar | vessel | kvoti... joined by "+", from the register's decisions). kW
# is the vessel's power (power_kw); the main engine's power stands in where power_kw is missing (13 hull-years on the
# register). mclass is the `vessel` schema's usage-category code (the PDFs' printed types mapped to it, decision 136);
# `usage` keeps the register's text. SKB pleasure craft are not in the register and have no row here.

library(dplyr)
library(nanoparquet)

YEARS <- 2007:as.integer(format(Sys.Date(), "%Y"))
OPEN <- as.Date("2099-12-31")
num <- function(x) suppressWarnings(as.numeric(gsub(",", ".", as.character(x))))
f_reg <- function(t) fd_curated("vessel", "register", paste0(t, ".parquet"))

dec <- read_parquet(f_reg("decision"), col_select = c("registration_no", "table", "column", "valid_from", "valid_to", "source")) |>
  mutate(valid_to = coalesce(valid_to, OPEN))
fam <- function(s) vapply(strsplit(s, "[;+] ?"), function(p) paste(sort(unique(sub(":.*$", "", p))), collapse = "+"), "")
# one register column as a series of (vid, a, b, value, source): each row lies inside one decision per column
series <- function(tab, col, value_col = col, numeric = TRUE) {
  d <- read_parquet(f_reg(tab)) |>
    transmute(vid = as.integer(registration_no), a = valid_from, b = coalesce(valid_to, OPEN), value = .data[[value_col]])
  if (numeric) d <- d |> mutate(value = num(value)) |> filter(!is.na(value), value > 0) else d <- d |> filter(!is.na(value))
  d |>
    left_join(dec |> filter(table == tab, column == col) |> select(vid = registration_no, da = valid_from, db = valid_to, source),
              by = join_by(vid, a >= da, a < db)) |>
    mutate(source = fam(coalesce(source, ""))) |>
    select(vid, a, b, value, source)
}

v <- read_parquet(fd_raw("oracle", "vessel", "vessel_v.parquet")) |>
  transmute(vid = as.integer(registration_no), mclass_now = as.integer(usage_category_no),
            kw_now = num(power_kw), loa_now = num(max_length))
grid <- tidyr::expand_grid(vid = v$vid, year = YEARS) |> mutate(d = as.Date(paste0(year, "-07-01")))

# the value in force on 1 July, else the earliest after it, else the last before it
pick <- function(s, nm) {
  on <- grid |> inner_join(s, by = join_by(vid, d >= a, d < b)) |> mutate(basis = "register")
  later <- grid |> anti_join(on, by = c("vid", "year")) |> inner_join(s, by = join_by(vid, d < a)) |>
    arrange(vid, year, a) |> distinct(vid, year, .keep_all = TRUE) |> mutate(basis = "register_later")
  earlier <- grid |> anti_join(on, by = c("vid", "year")) |> anti_join(later, by = c("vid", "year")) |>
    inner_join(s, by = join_by(vid, d >= b)) |>
    arrange(vid, year, desc(b)) |> distinct(vid, year, .keep_all = TRUE) |> mutate(basis = "register_earlier")
  out <- bind_rows(on, later, earlier) |> select(vid, year, value, basis, source)
  stopifnot("one value per vid and year" = !anyDuplicated(out[c("vid", "year")]))
  setNames(out, c("vid", "year", nm, paste0(nm, "_basis"), paste0(nm, "_source")))
}

uc  <- series("vessel_hist", "usage_category_no")
use <- series("vessel_hist", "usage_category", numeric = FALSE) |> rename(usage = value) |> select(-source)
pk  <- series("vessel_hist", "power_kw")
eng <- series("vessel_engines_hist", "power")
loa <- series("vessel_measurement_hist", "max_length")
p_mclass <- pick(uc, "mclass")
p_usage  <- grid |> inner_join(use, by = join_by(vid, d >= a, d < b)) |> distinct(vid, year, .keep_all = TRUE) |> select(vid, year, usage)
# power_kw in force on 1 July, else the main engine's power that day, else power_kw before or after
p_kw     <- pick(pk, "kw")
p_eng    <- pick(eng, "e") |> filter(e_basis == "register")
p_kw     <- full_join(p_kw, p_eng, by = c("vid", "year")) |>
  mutate(use_e = !is.na(e) & !kw_basis %in% "register",
         kw = if_else(use_e, e, kw), kw_source = if_else(use_e, e_source, kw_source), kw_basis = if_else(use_e, "register", kw_basis)) |>
  select(vid, year, kw, kw_basis, kw_source)
p_loa    <- pick(loa, "loa")
seg <- read_parquet(fd_staging("hreidar", "vessel_year.parquet"), col_select = c("nr", "year", "segment")) |>
  transmute(vid = as.integer(nr), year = as.integer(year), segment) |> filter(!is.na(vid), year %in% YEARS, !is.na(segment)) |>
  distinct(vid, year, .keep_all = TRUE)

current <- function(x, now, b) if_else(is.na(x) & !is.na(now) & now > 0, "current", coalesce(b, "none"))
vessel_year <-
  grid |>
  left_join(v, by = "vid") |>
  left_join(p_mclass, by = c("vid", "year")) |>
  left_join(p_usage, by = c("vid", "year")) |>
  left_join(p_kw, by = c("vid", "year")) |>
  left_join(p_loa, by = c("vid", "year")) |>
  left_join(seg, by = c("vid", "year")) |>
  mutate(
    mclass_basis = if_else(is.na(mclass) & !is.na(mclass_now), "current", coalesce(mclass_basis, "none")),
    usage = if_else(mclass_basis == "register", usage, NA_character_),
    mclass = coalesce(as.integer(mclass), mclass_now),
    kw_basis = current(kw, kw_now, kw_basis),
    kw = coalesce(kw, if_else(kw_now > 0, kw_now, NA_real_)),
    loa_basis = current(loa, loa_now, loa_basis),
    loa = coalesce(loa, if_else(loa_now > 0, loa_now, NA_real_))) |>
  select(vid, year, mclass, usage, mclass_basis, mclass_source, segment, kw, kw_basis, kw_source, loa, loa_basis, loa_source) |>
  arrange(vid, year)

# Checks ---------------------------------------------------------------------------------------------------------------
stopifnot("one row per vid and year" = !anyDuplicated(vessel_year[c("vid", "year")]))
cat("vessel-years:", nrow(vessel_year), " vids:", n_distinct(vessel_year$vid), " years:", paste(range(YEARS), collapse = "-"), "\n")
print(vessel_year |> count(year > 2021, kw_basis) |> tidyr::pivot_wider(names_from = kw_basis, values_from = n, values_fill = 0))
print(vessel_year |> count(year > 2021, mclass_basis) |> tidyr::pivot_wider(names_from = mclass_basis, values_from = n, values_fill = 0))

write_curated(vessel_year, fd_curated("vessel", "vessel_year.parquet"),
              inputs = c(f_reg("vessel_hist"), f_reg("vessel_engines_hist"), f_reg("vessel_measurement_hist"), f_reg("decision"),
                         fd_staging("hreidar", "vessel_year.parquet"), fd_raw("oracle", "vessel", "vessel_v.parquet")))
