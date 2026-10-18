# The annual ship register (Skipaskrá): every entry of every edition, 2004-2022, as printed.
# Side: once (register history). See plan 014; plan 028 step 1; decision 132.
#
# Input:  raw/external/skipaskra/reports/*.pdf          the 19 editions (R/skipaskra_pdf.R reads them)
# Output: staging/skipaskra/register.parquet            one row per edition and entry
#
# An edition of year Y is the register on Y-01-01 (decision 049). Decked ships and open boats are its two sections.
# Text is kept as printed; measures are parsed from the Icelandic print, and `note` says where the print needed
# reading (a shifted cell, decimals cut, a place printed into the year). Nothing is corrected here: the 2020 edition,
# for one, reprints the 2019 register (plan 028 §2.6), and that is a finding for the checks, not a repair.
#
# The owner and the owner's address are kept (maintainer, 2026-10-18). They stay under $FISHYDATA and are never
# published.

library(dplyr)
library(nanoparquet)

eds <- sk_editions()
stopifnot(nrow(eds) == 19, identical(eds$edition, 2004:2022))

reg <- bind_rows(lapply(seq_len(nrow(eds)), function(i) {
  e <- eds[i, ]
  x <- if (e$layout == "A") sk_parse_A(e$file, e$edition) else sk_parse_BC(e$file, e$edition, e$layout)
  x$layout <- e$layout
  x
}))

# Typed columns ----------------------------------------------------------------

note_add <- function(note, cond, what) ifelse(cond, ifelse(is.na(note), what, paste(note, what, sep = "; ")), note)
cut_dec <- function(v) !is.na(v) & grepl(",$", v)

reg <- reg |>
  mutate(
    note = note_add(note, built_year %in% c("0", "0000"), "year_printed_0"),
    note = note_add(note, engine_year %in% "0", "engine_year_printed_0"),
    note = note_add(note, cut_dec(grt) | cut_dec(gt) | cut_dec(nt), "decimals_cut"),
    vid = suppressWarnings(as.integer(sknr)),
    region_acronym = ifelse(grepl(DISTRICT_RE, district), sub("^([^0-9‐–-]+).*$", "\\1", district), NA_character_),
    region_no = ifelse(grepl(DISTRICT_RE, district), suppressWarnings(as.integer(sub("^[^0-9]*", "", district))), NA_integer_),
    note = note_add(note, !is.na(district) & !grepl(DISTRICT_RE, district), "district_unread"),
    postcode = ifelse(grepl("(^| )[0-9]{3} ", address), sub("^.*?(^| )([0-9]{3}) .*$", "\\2", address, perl = TRUE), NA_character_),
    town = ifelse(is.na(postcode), NA_character_, sub("^.*?(^| )[0-9]{3} ", "", address, perl = TRUE)),
    built_year = suppressWarnings(as.integer(ifelse(built_year %in% c("0", "0000"), NA, built_year))),
    engine_year = suppressWarnings(as.integer(ifelse(engine_year %in% "0", NA, engine_year))),
    across(c(engine_kw, grt, length_reg, gt, breadth, nt, depth, loa, power_index), sk_num)) |>
  select(edition, layout, section, page, y, vid, sknr, name, district, region_acronym, region_no, class_society,
         call_sign, home_port, previous_name, owner, address, postcode, town, built_place, built_year, yard,
         ship_type, hull_material, engine_make, engine_year, engine_kw, imo, changes, grt, gt, nt, length_reg,
         breadth, depth, loa, power_index, note) |>
  arrange(edition, section, vid)

# Checks that stop the build ------------------------------------------------------

stopifnot(!anyNA(reg$vid))
dup <- reg |> count(edition, vid) |> filter(n > 1)
if (nrow(dup)) message(nrow(dup), " (edition, vid) pairs are printed twice: ", paste(head(paste(dup$edition, dup$vid), 10), collapse = ", "))

print(reg |> group_by(edition, layout) |>
        summarise(decked = sum(section == "decked"), open = sum(section == "open"), entries = n(),
                  noted = sum(!is.na(note)), .groups = "drop") |>
        knitr::kable(caption = "register: entries per edition"))

write_parquet(reg, fd_staging("skipaskra", "register.parquet"))
