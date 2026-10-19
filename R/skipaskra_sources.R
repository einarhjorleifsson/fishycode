# skipaskra_sources.R — the register's witnesses read into one long form: a row per vid, table, column, window and value.
#
# Function definitions only (targets sources R/ wholesale). Used by reference/vessels/skipaskra_evidence.R (the frozen
# history's evidence, `once` project) and reference/vessels/vessel_register.R (the live part, main project), so both
# read the `vessel` schema and ufs with one mapping (plan 028 steps 3 and 6).
#
# Input:  raw/oracle/vessel/{vessel,vessel_*_hist}.parquet, raw/oracle/ufs/{skip,skip_jn,skipasaga,skipasaga_jn}.parquet
# Output: none
#
# The long form (sk_longer()): `vid`, `table`, `column` (the `vessel` schema's names), `value` as given (numbers
# formatted plainly, blanks NA), `t1`, `t2` (the window the witness speaks for), `source`, `lineage`, `kind`,
# `edition`, `page`, `record` (the witness's own row).

sk_ora <- function(schema, table) nanoparquet::read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet")))
sk_d8 <- function(x) as.Date(x)
sk_fmt <- function(x) if (is.numeric(x)) ifelse(is.na(x), NA_character_, format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)) else as.character(x)
sk_blank_na <- function(x) { x <- trimws(as.character(x)); x[x %in% c("", "-", "–", "‐", "NA")] <- NA; x }
# a call sign of "0" or the bare prefix "TF" stands for none (164 hulls in kvoti.skipaskra_siglo and the `vessel` schema)
sk_no_sign <- function(x) ifelse(trimws(x) %in% c("0", "", "TF"), NA, x)

# `d` holds vid, t1, t2, record and columns named "<table>.<column>"
sk_longer <- function(d, source, lineage, kind, edition = NA_integer_, page = NA_integer_) {
  cols <- grep("[.]", names(d), value = TRUE)
  if (!"edition" %in% names(d)) d$edition <- edition
  if (!"page" %in% names(d)) d$page <- page
  d |>
    dplyr::mutate(dplyr::across(dplyr::all_of(cols), ~ sk_blank_na(sk_fmt(.x)))) |>
    tidyr::pivot_longer(dplyr::all_of(cols), names_to = "key", values_to = "value", values_drop_na = TRUE) |>
    dplyr::transmute(vid = as.integer(vid), table = sub("[.].*$", "", key), column = sub("^[^.]*[.]", "", key), value,
                     t1 = sk_d8(t1), t2 = sk_d8(t2), source, lineage, kind,
                     edition = as.integer(edition), page = as.integer(page), record = as.character(record))
}

# The `vessel` schema's history tables: every version, the back-filled years before 2023-12-19, the system's own after,
# the current one with no t2. Deletions left out.
sk_vessel_schema <- function() {
  vkey <- sk_ora("vessel", "vessel") |> dplyr::transmute(vessel_id, vid = as.integer(registration_no))
  vh <- function(table) sk_ora("vessel", table) |> dplyr::filter(hist_operation != "DEL") |>
    dplyr::inner_join(vkey, by = "vessel_id") |> dplyr::mutate(t1 = sk_d8(valid_from), t2 = sk_d8(valid_to))
  list(
    vessel_hist = vh("vessel_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_hist:", vessel_hist_id),
                       vessel_hist.name = name, vessel_hist.previous_name = previous_name, vessel_hist.usage_category = usage_category,
                       vessel_hist.usage_category_no = usage_category_no, vessel_hist.status = status, vessel_hist.open = open,
                       vessel_hist.imo_no = imo_no, vessel_hist.construction_year = construction_year,
                       vessel_hist.construction_place = construction_place, vessel_hist.construction_station = construction_station,
                       vessel_hist.construction_country = construction_country,
                       vessel_hist.classification_society = classification_society, vessel_hist.hull_material = hull_material,
                       vessel_hist.power_kw = power_kw, vessel_hist.horse_power = horse_power,
                       vessel_hist.power_indicator = power_indicator, vessel_hist.operation_area = operation_area,
                       vessel_event.initial_registration = sk_d8(initial_registration_date)) |>
      sk_longer("vessel:vessel_hist", "register", "interval"),
    vessel_ident = vh("vessel_identification_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_identification_hist:", vessel_iden_hist_id),
                       vessel_identification_hist.region_acronym = region_acronym, vessel_identification_hist.region_no = region_no,
                       vessel_identification_hist.call_sign = sk_no_sign(call_sign), vessel_identification_hist.home_port = home_port,
                       vessel_identification_hist.home_port_no = home_port_no) |>
      sk_longer("vessel:vessel_identification_hist", "register", "interval"),
    vessel_meas = vh("vessel_measurement_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_measurement_hist:", vessel_meas_hist_id),
                       vessel_measurement_hist.length = length, vessel_measurement_hist.max_length = max_length,
                       vessel_measurement_hist.width = width, vessel_measurement_hist.depth = depth,
                       vessel_measurement_hist.draft = draft, vessel_measurement_hist.brutto_grt = brutto_grt,
                       vessel_measurement_hist.brutto_weight_tons = brutto_weight_tons,
                       vessel_measurement_hist.netto_weight_tons = netto_weight_tons,
                       vessel_measurement_hist.brutto_grt_older = brutto_grt_older) |>
      sk_longer("vessel:vessel_measurement_hist", "register", "interval"),
    vessel_eng = vh("vessel_engines_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_engines_hist:", vessel_eng_hist_id),
                       vessel_engines_hist.manufacturer_name = manufacturer_name, vessel_engines_hist.year = year,
                       vessel_engines_hist.power = power, vessel_engines_hist.usage_code = usage_code) |>
      sk_longer("vessel:vessel_engines_hist", "register", "interval"),
    vessel_op = vh("vessel_operational_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_operational_hist:", vessel_op_hist_id),
                       vessel_operational_hist.operational_category_no = operational_category_no,
                       vessel_operational_hist.operational_category = operational_category,
                       vessel_operational_hist.license_system = license_system) |>
      sk_longer("vessel:vessel_operational_hist", "fisheries", "interval"),
    vessel_own = vh("vessel_owners_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_owners_hist:", vessel_owners_id, ":", vessel_own_hist_id),
                       vessel_owners_hist.name = name, vessel_owners_hist.address = address,
                       vessel_owners_hist.postal_no = postal_no, vessel_owners_hist.percentage = percentage,
                       vessel_owners_hist.national_identity_no = national_identity_no) |>
      sk_longer("vessel:vessel_owners_hist", "register", "interval"),
    vessel_fish = vh("vessel_fishery_hist") |>
      dplyr::transmute(vid, t1, t2, record = paste0("vessel_fishery_hist:", vessel_fish_hist_id),
                       vessel_fishery_hist.name = name, vessel_fishery_hist.address = address, vessel_fishery_hist.postal_no = postal_no,
                       vessel_fishery_hist.identity_no = identity_no) |>
      sk_longer("vessel:vessel_fishery_hist", "fisheries", "interval"))
}

# ufs, the Directorate of Fisheries' ship history after kvoti: the saga, its journal of old versions, and the journal of
# each vessel's call sign and IMO
sk_ufs <- function() {
  ufs_key <- sk_ora("ufs", "skip") |> dplyr::transmute(skip_id = id, vid = as.integer(skip_numer))
  saga_cols <- function(d) d |>
    dplyr::transmute(vid, t1 = gildir_fra, t2 = gildir_til, record,
                     vessel_hist.name = heiti, vessel_hist.deck = dekk,
                     vessel_identification_hist.region_acronym = einkennisstafir, vessel_identification_hist.region_no = einkennisnumer,
                     vessel_identification_hist.home_port_no = heimahofn_id,
                     vessel_measurement_hist.brutto_grt = bruttolestir, vessel_measurement_hist.length_fisheries = lengd,
                     vessel_measurement_hist.brutto_weight_tons = bruttotonn, vessel_measurement_hist.length = skrad_lengd,
                     vessel_measurement_hist.width = skrad_breidd, vessel_measurement_hist.depth = skrad_dypt,
                     vessel_operational_hist.utgerdarflokkur_id = utgerdarflokkur_id)
  list(
    ufs_saga = sk_ora("ufs", "skipasaga") |> dplyr::inner_join(ufs_key, by = "skip_id") |>
      dplyr::mutate(record = paste0("ufs.skipasaga:", id)) |> saga_cols() |> sk_longer("ufs.skipasaga", "fisheries", "interval"),
    ufs_saga_jn = sk_ora("ufs", "skipasaga_jn") |> dplyr::filter(jn_operation != "DEL") |> dplyr::inner_join(ufs_key, by = "skip_id") |>
      # two users can change one row in the same second, so the session tells them apart
      dplyr::mutate(record = paste0("ufs.skipasaga_jn:", id, ":", format(jn_datetime, "%Y%m%d%H%M%S"), ":", jn_session)) |> saga_cols() |>
      sk_longer("ufs.skipasaga_jn", "fisheries", "interval"),
    ufs_skip_jn = sk_ora("ufs", "skip_jn") |> dplyr::filter(jn_operation != "DEL", !is.na(skip_numer)) |>
      dplyr::transmute(vid = skip_numer, t1 = jn_datetime, t2 = as.Date(NA),
                       record = paste0("ufs.skip_jn:", id, ":", format(jn_datetime, "%Y%m%d%H%M%S")),
                       vessel_identification_hist.call_sign = sk_no_sign(kallmerki), vessel_hist.imo_no = imo_numer) |>
      sk_longer("ufs.skip_jn", "fisheries", "change"))
}
