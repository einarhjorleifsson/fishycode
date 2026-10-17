# The Faroese vessel registry (Føroya Skipaskráseting), scraped one vessel
# per file.
# Side: preprocessing (fro). See plan 014.
#
# Input:  raw/external/fro/vid-*.csv  (long variable,value,vid_id format)
# Output: staging/fro/vessel.parquet — one row per FRO vid
#
# No change history is carried per field (plan 008 §4/§5.0: a single snapshot
# per vessel, first-registration date is the only date this source gives at
# all) — `t1` is that date, `t2` is left NA (open/unbounded), collapsing to
# a period happens in reference/vessels/identity_foreign.R, not here.
#
# "Einki ásett" ("not set") is this source's own NA spelling — cleaned in the
# long form, before pivoting, so every downstream column sees a real NA.
#
# Numbers are written Faroese/Danish-style, dot as both thousands separator
# and decimal point ("3.694.00" = 3,694.00): every dot but the last is a
# thousands separator, so drop every dot that is followed by another dot.
# Dimensions and engine power carry a unit suffix ("65.900 metrar",
# "8.000.00 KW") stripped before parsing.

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(nanoparquet)

parse_fro_number <- function(x) {
  x <- str_remove(x, " ?(metrar|KW)$")
  x <- str_remove_all(x, "\\.(?=.*\\.)")
  suppressWarnings(as.numeric(x))
}

files <- list.files(fd_raw("external", "fro"), pattern = "^vid-.*\\.csv$", full.names = TRUE)
cat("fro files:", length(files), "\n")

read_one <- function(f) {
  d <- read_csv(f, col_types = cols(.default = "c"), show_col_types = FALSE)
  d |>
    # the scrape leaves a stray U+00A0 (non-breaking space) in place of an
    # ordinary space in places - found via "2003 / Kimek A/S" silently
    # failing to split on " / ". Normalized once, here, rather than working
    # around it in every downstream regex.
    mutate(value = str_replace_all(value, " ", " ")) |>
    # the source spells its own NA both "Einki ásett" and "einki ásett" -
    # 709 of 6,129 occurrences sampled are the lowercase form
    mutate(value = if_else(str_to_lower(value) == "einki ásett", NA_character_, value)) |>
    # a handful of files carry the same variable twice (e.g. "Eigari" listed
    # per owner share) - keep the first, a full ownership breakdown is not
    # what this table is for
    distinct(variable, .keep_all = TRUE) |>
    pivot_wider(id_cols = vid_id, names_from = variable, values_from = value)
}

raw <- bind_rows(lapply(files, read_one))
cat("parsed rows:", nrow(raw), "\n")

fro <-
  raw |>
  # split on the FIRST " / " only - a shipyard name can itself contain a
  # slash ("Sp/f ...", a Faroese company-form abbreviation), so splitting on
  # every "/" would break it. Either half commonly reads "Einki ásett" on its
  # own ("1986 / Einki ásett", or both unset) - a whole-field NA check
  # upstream cannot see that, so each half gets its own check below.
  mutate(.yard_parts = str_split_fixed(`Byggiár / skipasmiðja`, " / ", 2)) |>
  transmute(
    vid                 = as.integer(vid_id),
    name                = Skipanavn,
    registration_number = Skrásetingarnr,
    cs                  = Kallimerki,
    mmsi                = MMSI,
    homeport            = Heimstaður,
    registry             = Skrá,
    status              = Status,
    vessel_type         = Slag,
    owner               = coalesce(Eigari, Eigarar),
    lessee              = Leigari,
    imo                 = `IMO nummar`,
    build_year          = suppressWarnings(as.integer(.yard_parts[, 1])),
    shipyard            = if_else(str_to_lower(str_trim(.yard_parts[, 2])) == "einki ásett",
                                  NA_character_, str_trim(.yard_parts[, 2])),
    t1                  = as.Date(`Skrásett fyrstu ferð`, format = "%d-%m-%Y"),
    hull_material       = Byggitilfar,
    gross_tonnage       = parse_fro_number(Bruttotons),
    net_tonnage         = parse_fro_number(Nettotons),
    gross_register_tons = parse_fro_number(Bruttoregistartons),
    net_register_tons   = parse_fro_number(Nettoregistartons),
    length              = parse_fro_number(Longd),
    breadth             = parse_fro_number(Breidd),
    depth               = parse_fro_number(Dýpd),
    loa                 = parse_fro_number(`Longd yviralt (LOA)`),
    engine_maker        = Motorslag,
    engine_type         = Motortypur,
    engine_power_kw     = parse_fro_number(Motororka)
  )

stopifnot(!anyDuplicated(fro$vid))
cat("with an imo:", sum(!is.na(fro$imo)), "  with an mmsi:", sum(!is.na(fro$mmsi)), "\n")

fro |>
  nanoparquet::write_parquet(fd_staging("fro", "vessel.parquet"))
