# The historical aggregates: afli's monthly summaries as ops$sigfus holds them, the fleet's Nephrops, and ICES's
# statistic for Iceland, each its own table, kept apart from the logbook and the landings (plan 056 §5).
# Side: preprocessing (logbook). See plan 014.
#
# Input:  staging/ops_sigfus/{nephrops,shrimp,seine}_monthly.parquet
#         curated/logbook/{trip,station,catch}.parquet        afli's hauls, duplicates out, for repeats_hauls
#         raw/oracle/ops_einarhj/ices_landed_catch.parquet    ICES's landings statistic, read where the dump put it
#         curated/landing/{landings,catch}.parquet, curated/reference/species.parquet   the landed kg ICES is set against
# Output: curated/aggregate/logged_monthly.parquet  every summary row with a vessel or a boat code
#         curated/aggregate/nephrops_fleet.parquet  the fleet's Nephrops of 1960-1972: no vessel, quantity unknown
#         curated/aggregate/ices.parquet            Iceland's rows of the statistic
#
# One quantity per table (plan 055 rule 1): logged kg, an unknown quantity, a statistic. None is added to another, and
# none to the logbook: where afli's hauls hold a summary's kilograms the summary repeats them (plan 041 §3.3), so the
# rule is a flag here, never a drop. A cell is the vessel x month x species where the summary names a vessel, else the
# month x place x species (the square, or the shrimp area), set against afli's hauls in it; the summary repeats them
# where the hauls hold at least 95 % of its kg. The old gear code is not in the cell: it moves 0.8 t (plan 041 §2).
# ICES is a witness, compiled from the landings from 1966 (decision 266), never a check on them. Its species-years are
# set against the landed kg of the same species and year, where the landings hold the year and the species, and a
# species-year above ten times them is flagged: the step that splits a total leaves it out (plan 055 rule 5).

source("R/paths.R")
source("R/write_curated.R")
suppressMessages({
  library(dplyr)
  library(DBI)
})
Sys.setenv(TZ = "UTC")

REPEAT_SHARE <- 0.95
ICES_FLAG_RATIO <- 10

con <- dbConnect(duckdb::duckdb())
q  <- function(s) as_tibble(dbGetQuery(con, s))
pq <- function(p) sprintf("read_parquet('%s')", p)
lb <- function(t) fd_curated("logbook", paste0(t, ".parquet"))
stg <- function(t) fd_staging("ops_sigfus", paste0(t, "_monthly.parquet"))

# afli's hauls -------------------------------------------------------------------
# One row per (year, month, vid, square, shrimp area, species), duplicates out. vid is the trip's.
hauls <- q(sprintf("
  SELECT year(s.\"date\")::INTEGER AS year, month(s.\"date\")::INTEGER AS month, t.vid::INTEGER AS vid,
         s.sq::INTEGER AS sq, s.skiki::INTEGER AS area, c.sid::INTEGER AS sid, sum(c.catch) AS kg
  FROM %s s JOIN %s t ON t.\".tid\" = s.\".tid\" AND t.schema = s.schema
  JOIN %s c ON c.\".sid\" = s.\".sid\" AND c.schema = s.schema
  WHERE s.schema = 'afli' AND (s.twin IS NULL OR s.twin <> 'duplicate') AND year(s.\"date\") < 2000
  GROUP BY ALL", pq(lb("station")), pq(lb("trip")), pq(lb("catch"))))
hauls_by <- function(...) hauls |> group_by(...) |> summarise(hauls_kg = sum(kg, na.rm = TRUE), .groups = "drop")

# The flag: a cell's summaries against its hauls. Every row of a cell carries the cell's verdict.
flag_cells <- function(d, cell, hauls_cell) {
  d |>
    group_by(across(all_of(cell))) |>
    mutate(cell_kg = sum(catch, na.rm = TRUE)) |>
    ungroup() |>
    left_join(hauls_cell, by = cell) |>
    mutate(hauls_kg = coalesce(hauls_kg, 0),
           repeats_hauls = cell_kg > 0 & hauls_kg >= REPEAT_SHARE * cell_kg) |>
    select(-cell_kg)
}

# The summaries ------------------------------------------------------------------
nephrops <- duckdbfs::open_dataset(stg("nephrops")) |> collect()
shrimp   <- duckdbfs::open_dataset(stg("shrimp")) |> collect()
seine    <- duckdbfs::open_dataset(stg("seine")) |> collect()

logged <- bind_rows(
  nephrops |> filter(!is.na(vid)) |> mutate(kind = "nephrops") |>
    flag_cells(c("year", "month", "vid", "sid"), hauls_by(year, month, vid, sid)),
  shrimp |> filter(!is.na(vid)) |> mutate(kind = "shrimp") |>
    flag_cells(c("year", "month", "vid", "sid"), hauls_by(year, month, vid, sid)),
  shrimp |> filter(is.na(vid)) |> mutate(kind = "shrimp") |>
    flag_cells(c("year", "month", "area", "sid"), hauls_by(year, month, area, sid)),
  seine |> mutate(kind = "seine") |>
    flag_cells(c("year", "month", "sq", "sid"), hauls_by(year, month, sq, sid))) |>
  select(kind, .row, year, month, vid, boat_code, sq, ssq, area, svaedi, sid, catch, tow_h, n_sets,
         hauls_kg, repeats_hauls) |>
  arrange(kind, year, month, .row)

fleet <- nephrops |> filter(is.na(vid)) |>
  flag_cells(c("year", "month", "sq", "sid"), hauls_by(year, month, sq, sid)) |>
  select(.row, year, month, sq, ssq, sid, catch, tow_h, hauls_kg, repeats_hauls) |>
  arrange(year, month, .row)

# Every summary row in one outcome, every kilogram once.
stopifnot("a summary row lost or doubled" =
            nrow(logged) + nrow(fleet) == nrow(nephrops) + nrow(shrimp) + nrow(seine),
          "a summary kilogram lost or doubled" =
            isTRUE(all.equal(sum(logged$catch, na.rm = TRUE) + sum(fleet$catch, na.rm = TRUE),
                             sum(nephrops$catch, shrimp$catch, seine$catch, na.rm = TRUE))))

# ICES -------------------------------------------------------------------------------
# Iceland's rows, the area code as recorded but for its padding. sid by the species' FAO code.
ICES <- fd_raw("oracle", "ops_einarhj", "ices_landed_catch.parquet")
ices <- q(sprintf("
  SELECT i.year::INTEGER AS year, trim(i.area) AS area, trim(i.subarea) AS subarea, i.species_code, i.species,
         i.latin_name, i.landings AS landings_t, i.source, s.sid::INTEGER AS sid
  FROM %s i LEFT JOIN (SELECT fao_3a, min(sid) AS sid FROM %s WHERE fao_3a IS NOT NULL GROUP BY 1) s
    ON s.fao_3a = i.species_code
  WHERE i.country ILIKE '%%iceland%%'", pq(ICES), pq(fd_curated("reference", "species.parquet"))))
landed <- q(sprintf("
  SELECT year(l.\"date\")::INTEGER AS year, c.sid::INTEGER AS sid, sum(c.catch) / 1000 AS landed_t
  FROM %s c JOIN %s l ON l.\".lid\" = c.\".lid\" AND l.schema = c.schema GROUP BY ALL",
  pq(fd_curated("landing", "catch.parquet")), pq(fd_curated("landing", "landings.parquet"))))
# Only the years the landings hold whole: the first starts part-way (1992-09), and a seasonal fishery such as
# Nephrops would look absent from it.
span <- q(sprintf("SELECT min(\"date\") AS d0, max(\"date\") AS d1 FROM %s", pq(fd_curated("landing", "landings.parquet"))))
landed_years <- c(as.integer(format(span$d0, "%Y")) + (format(span$d0, "%m-%d") > "01-01"),
                  as.integer(format(span$d1, "%Y")) - (format(span$d1, "%m-%d") < "12-01"))
ices <- ices |>
  left_join(ices |> group_by(year, species_code) |> summarise(species_year_t = sum(landings_t, na.rm = TRUE),
                                                              .groups = "drop"),
            by = c("year", "species_code")) |>
  left_join(landed, by = c("year", "sid")) |>
  mutate(landed_t = if_else(year >= landed_years[1] & year <= landed_years[2], coalesce(landed_t, 0), NA_real_),
         # Only where the landings hold the species that year: a 0 is no witness (a code the landings never use).
         flag = case_when(landed_t > 0 & species_year_t > ICES_FLAG_RATIO * landed_t ~ "exceeds_landings_10x")) |>
  arrange(year, species_code, area, subarea)

# Write --------------------------------------------------------------------------------
out <- function(d, t, inputs) write_curated(d, fd_curated("aggregate", paste0(t, ".parquet")), inputs = inputs)
out(logged, "logged_monthly", c(stg("nephrops"), stg("shrimp"), stg("seine"), lb("station"), lb("trip"), lb("catch")))
out(fleet, "nephrops_fleet", c(stg("nephrops"), lb("station"), lb("trip"), lb("catch")))
out(ices, "ices", c(ICES, fd_curated("reference", "species.parquet"), fd_curated("landing", "catch.parquet"),
                    fd_curated("landing", "landings.parquet")))

cat("\nlogged_monthly by kind: rows, kt, and the rows and kt whose kilograms afli's hauls already hold\n")
logged |> group_by(kind) |>
  summarise(rows = n(), kt = round(sum(catch, na.rm = TRUE) / 1e6, 2), repeats = sum(repeats_hauls),
            repeats_kt = round(sum(catch[repeats_hauls], na.rm = TRUE) / 1e6, 2)) |> print()
cat("\nnephrops_fleet:", nrow(fleet), "rows,", round(sum(fleet$catch, na.rm = TRUE) / 1e6, 2), "kt;",
    sum(fleet$repeats_hauls), "rows whose cell afli's hauls hold\n")
cat("\nices: ", nrow(ices), " rows, ", min(ices$year), "-", max(ices$year), "; flagged species-years:\n", sep = "")
ices |> filter(!is.na(flag)) |> distinct(year, species_code, species_year_t, landed_t, flag) |> print()
dbDisconnect(con, shutdown = TRUE)
