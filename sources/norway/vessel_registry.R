# Norwegian vessel register, "Fartøy og eier i første eierledd" — one sheet
# per year snapshot, from Fiskeridirektoratet.
# Side: preprocessing (norway). See plan 014.
#
# Input:  raw/external/nor/norway_vessel-registry.xlsx (sheets "2001".."2022")
# Output: staging/norway/vessel_registry.parquet — one row per (fartoy_id, year)
#
# Literal, one sheet bound per year - no NOR call-sign/name change history is
# detected here (plan 008 §5.0/§7 Phase 2/3): collapsing consecutive identical
# years into a single period is reference/vessels/identity_foreign.R's job, once,
# not this adapter's. No MMSI column exists in this source at all — plan
# 008 §2/§4 already found this; matching Norwegian vessels leans on `cs`.

library(readxl)
library(dplyr)
library(purrr)
library(nanoparquet)

p <- fd_raw("external", "nor", "norway_vessel-registry.xlsx")
# every year sheet the workbook holds, oldest first (decision 181); a fixed 2001:2022 stood here
years <- sort(grep("^[0-9]{4}$", excel_sheets(p), value = TRUE))
stopifnot(length(years) > 0)

nor <-
  purrr::map(years, function(yr) {
    read_excel(p, sheet = yr, col_types = c(
      "text", "text", "text", "text", "text", "text", "text", "text", "text",
      "numeric", "numeric", "numeric", "numeric", "numeric",
      "text", "text", "text", "text", "text", "text", "numeric"
    )) |>
      transmute(
        year               = as.integer(yr),
        fartoy_id          = `Fartøy ID`,
        data_as_of         = `Data pr.`,
        county             = Fylke,
        municipality       = Kommune,
        registration_mark  = Registreringsmerke,
        cs                 = Radiokallesignal,
        name               = Fartøynavn,
        loa                = `Største lengde`,
        breadth            = Bredde,
        build_year         = as.integer(`Byggeår - fartøy`),
        engine_power_kw    = Motorkraft,
        engine_build_year  = as.integer(`Byggeår - motor`),
        owner_id           = `Eier ID`,
        owner              = Fartøyeier,
        postal_code        = Postnummer,
        post_place         = Poststed,
        org_form_code      = `Organisasjonsform (kode)`,
        org_form           = Organisasjonsform,
        ownership_share    = Eierandel
      )
  }) |>
  bind_rows()

cat("rows before owner de-duplication:", nrow(nor), "  years:", n_distinct(nor$year),
    "  distinct fartoy_id:", n_distinct(nor$fartoy_id), "\n")

# "første eierledd" (first ownership tier) - 199 (fartoy_id, year) groups carry
# more than one owner row (co-ownership), same phenomenon as fro's "Eigari"/
# "Eigarar". Kept: the largest ownership_share, ties broken by owner_id, so
# the result is deterministic. A full ownership breakdown is not what this
# table is for, same call as sources/fro/convert.R's.
nor <-
  nor |>
  arrange(fartoy_id, year, desc(ownership_share), owner_id) |>
  distinct(fartoy_id, year, .keep_all = TRUE)

cat("rows after:", nrow(nor), "\n")
stopifnot(!anyDuplicated(nor[c("fartoy_id", "year")]))

nor |>
  nanoparquet::write_parquet(fd_staging("norway", "vessel_registry.parquet"))
