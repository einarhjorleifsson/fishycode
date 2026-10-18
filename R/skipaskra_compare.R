# skipaskra_compare.R — how the register's witnesses are compared: one normal form per column type.
#
# Function definitions only (targets sources R/ wholesale). Used by curate/checks/skipaskra_discrepancy.R and
# reference/vessels/skipaskra_history.R (plan 028 steps 4-5), so a check and the decision model never disagree on
# whether two values are the same.
#
# Input:  the evidence table, curated/vessel/skipaskra/evidence.parquet (reference/vessels/skipaskra_evidence.R)
# Output: none
#
# - Text is compared on its letters and digits, upper case, Unicode-composed: a word wrapped across a cell
#   ("FÁSKRÚÐSFJÖRÐU R") or a stop ("HF.") is no difference.
# - Hull materials are sets ("EIK OG FURA" = "FURA OG EIK"); classification societies are bodies (SI and SS are the
#   maritime authority; DG and NG, DNV GL, follow NV).
# - Numbers agree when equal at the coarser of the two precisions, the finer rounded or truncated. Precision is read
#   off each value as stored, which keeps no trailing zero: some editions print GRT and NT to one decimal or none.

key_txt <- function(x) gsub("[^\\p{L}\\p{N}]", "", stringi::stri_trans_nfc(toupper(x)), perl = TRUE)

key_material <- function(x) {
  p <- strsplit(gsub(",", " OG ", toupper(ifelse(is.na(x), "", x))), "\\s+OG\\s+")
  k <- vapply(p, function(w) paste(sort(key_txt(w[w != ""])), collapse = "+"), "")
  ifelse(is.na(x) | k == "", NA, k)
}

key_class <- function(x) {
  k <- key_txt(x)
  dplyr::case_when(k %in% c("SI", "SS") | grepl("^SAMG|^SIGL", k) ~ "AUTHORITY",
                   k %in% c("NV", "DG", "NG", "DNV", "DNVGL") ~ "DNV",
                   TRUE ~ k)
}

dec_of <- function(v) ifelse(grepl("\\.", v), nchar(sub("^[^.]*\\.", "", v)), 0L)

num_agree <- function(a, da, b, db) {
  s <- 10^pmin(da, db)
  fine <- ifelse(da >= db, a, b); coarse <- ifelse(da >= db, b, a)
  abs(round(fine * s) - round(coarse * s)) < 0.5 | abs(floor(fine * s + 1e-7) - round(coarse * s)) < 0.5
}

# the IMO number's check digit: the first six digits weighted 7 to 2, summed, last digit of the sum
imo_ok <- function(x) {
  x <- as.character(x); ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  d <- matrix(as.integer(unlist(strsplit(ifelse(ok, x, "0000000"), ""))), ncol = 7, byrow = TRUE)
  ok & as.vector(d[, 1:6, drop = FALSE] %*% (7:2)) %% 10 == d[, 7]
}

# The columns the witnesses are compared on, and how. Owners' addresses are not: the sources write them in different
# grammatical cases, with or without postcode and town.
SK_CMP <- tibble::tribble(
  ~table, ~column, ~type,
  "vessel_hist", "name", "text", "vessel_hist", "previous_name", "text", "vessel_hist", "usage_category", "text",
  "vessel_hist", "open", "text", "vessel_hist", "classification_society", "class",
  "vessel_hist", "construction_place", "text", "vessel_hist", "construction_year", "num",
  "vessel_hist", "construction_station", "text", "vessel_hist", "hull_material", "material",
  "vessel_hist", "imo_no", "text", "vessel_hist", "power_indicator", "num",
  "vessel_identification_hist", "district", "text", "vessel_identification_hist", "region_acronym", "text",
  "vessel_identification_hist", "region_no", "num", "vessel_identification_hist", "call_sign", "text",
  "vessel_identification_hist", "home_port", "text",
  "vessel_measurement_hist", "length", "num", "vessel_measurement_hist", "max_length", "num",
  "vessel_measurement_hist", "width", "num", "vessel_measurement_hist", "depth", "num",
  "vessel_measurement_hist", "brutto_grt", "num", "vessel_measurement_hist", "brutto_weight_tons", "num",
  "vessel_measurement_hist", "netto_weight_tons", "num",
  "vessel_engines_hist", "manufacturer_name", "text", "vessel_engines_hist", "year", "num",
  "vessel_engines_hist", "power", "num",
  "vessel_owners_hist", "name", "text")

# The evidence in comparable form: `v` the value cleaned of a source's additions, `num` and `dec` for numbers, `cmp` the
# normal form. Rows that cannot be compared are left out:
# - mbl's types, which follow the fishery and not the register's key;
# - a district of letters alone, which is compared as region_acronym;
# - the `vessel` schema's one-letter engine makes, which are the engine type ("D") in its back-filled rows.
# kvoti.skip_extra writes two societies in one code ("SINV"): split into two rows.
sk_comparable <- function(evi, cmp = SK_CMP) {
  d <- evi |>
    dplyr::inner_join(cmp, by = c("table", "column")) |>
    dplyr::filter(!(source == "mbl" & column == "usage_category"),
                  !(column == "district" & !grepl("[0-9]", value)),
                  !(source == "vessel:vessel_engines_hist" & column == "manufacturer_name" & nchar(key_txt(value)) == 1)) |>
    dplyr::mutate(v = dplyr::case_when(source == "mbl" & table == "vessel_hist" & column == "name" ~
                                         sub("\\s+\\p{Lu}{1,2}[- ]?\\d{1,3}$", "", value, perl = TRUE),
                                       source == "mbl" & column == "manufacturer_name" ~ sub("\\.\\s*\\d{1,2}-\\d{4}$", "", value),
                                       TRUE ~ value),
                  num = ifelse(type == "num" & !is.na(value_num) & value_num != 0, value_num, NA_real_),
                  is_pdf = grepl("^pdf:", source),
                  dec = ifelse(type == "num", as.integer(dec_of(value)), NA_integer_),
                  cmp = dplyr::case_when(type == "num" ~ ifelse(is.na(num), NA, as.character(num)),
                                         type == "material" ~ key_material(v),
                                         type == "class" ~ key_class(v),
                                         TRUE ~ key_txt(v))) |>
    dplyr::filter(!is.na(cmp), cmp != "")
  two <- d$source == "kvoti.skip_extra" & d$column == "classification_society" & nchar(d$cmp) == 4
  dplyr::bind_rows(d[!two, ], d[two, ] |> tidyr::separate_longer_position(v, width = 2) |> dplyr::mutate(cmp = key_class(v)))
}

# ufs.skip_jn dates each call sign and IMO from the change that set it to the day before the next change
sk_journal_intervals <- function(d) {
  d |> dplyr::filter(kind == "change") |> dplyr::arrange(vid, table, column, t1) |>
    dplyr::group_by(vid, table, column) |> dplyr::mutate(t2 = dplyr::lead(t1) - 1) |> dplyr::ungroup()
}
