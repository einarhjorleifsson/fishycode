# Every value every witness gives for an Icelandic hull's register record, in one long table (plan 028 step 3).
# Side: once (register history). See plan 014; plan 028 §4.1 and §6; decision 132.
#
# Input:  staging/skipaskra/{register,draught,event}.parquet          the annual register PDFs, 2004-2022 (decision 130)
#         staging/hreidar/vessel_year.parquet                         Hreiðar's workbook, a row per number and year
#         staging/mbl/register_2023-01.parquet                        mbl's register, scraped 2022-12-28/2023-01-09
#         staging/samgongustofa/register_2022-12-28.parquet           Samgöngustofa's online register, 2022-12-28
#         staging/marinetraffic/icelandic.parquet                     MarineTraffic's hand matches, Icelandic rows
#         raw/oracle/vessel/{vessel,vessel_*_hist}.parquet            the `vessel` schema, history back-filled before 2023-12-19
#         raw/oracle/kvoti/{skipasaga,skipaskra_siglo,skip_extra,veidileyfi,veidileyfi_eydd,veidileyfi_sviptingar,
#                           strandveidileyfi_v,dragnot_leyfi,grasleppusaga,tegund_veidileyfis}.parquet
#         raw/oracle/ufs/{skip,skip_jn,skipasaga,skipasaga_jn}.parquet
#         raw/oracle/ops_einarhj/mmsi_icelandic_registry_20230115.parquet
#         curated/vessel/mmsi.parquet                                 the MMSI archive's holder periods (plan 016)
# Output: curated/vessel/skipaskra/evidence.parquet - one row per vid, table, column, window and witness
#
# The tables and columns are the `vessel` schema's (plan 028 §4.2), with the few it lacks added (`changes`, `draft_light`,
# `weight`, `vessel_event`, `vessel_licence_hist`, `vessel_certificate`). Nothing is chosen here: every value is kept as
# its witness gives it, and the decision model (step 5) settles which one a `_hist` row carries.
#
# - `t1`, `t2`: the window the witness speaks for. An annual edition speaks for its 1 January (t1 = t2); Hreiðar for
#   his year in use; a dated source for its from-to (t2 NA while open); a journal for the moment of the change
#   (`kind` "change"); an undated source has no window ("undated").
# - `lineage` (§6.1): register (the PDFs, the Samgöngustofa scrape, kvoti's copies of the maritime register, the
#   `vessel` schema's hull, identification, measurement, engines and owners), fisheries (kvoti and ufs ship history,
#   operational category, licences), hreidar, mbl, radio (the MMSI lists), observation (MarineTraffic).
# - `record`: the witness's own row, so values printed together stay together.
# - `value` as given (numbers formatted plainly); `value_num` where it reads as a number; `value_norm` for comparing
#   text (upper case, wrap hyphens joined, spaces collapsed).
# - Personal data (plan 028 §7): owners' and operators' names and addresses are kept; kennitala is not carried here
#   (it stays in staging where a public source printed it).
#
# kvoti's skipaskra_siglo stores its measures in hundredths (7.23 m as 723): divided here.

library(dplyr)
library(tidyr)
library(nanoparquet)

ora <- function(schema, table) read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet")))
d8 <- function(x) as.Date(x)
ymd_int <- function(x) as.Date(sprintf("%08d", as.integer(x)), format = "%Y%m%d")
fmt <- function(x) if (is.numeric(x)) ifelse(is.na(x), NA_character_, format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)) else as.character(x)
blank_na <- function(x) { x <- trimws(as.character(x)); x[x %in% c("", "-", "–", "‐", "NA")] <- NA; x }
# a call sign of "0" or the bare prefix "TF" stands for none (164 hulls in kvoti.skipaskra_siglo and the `vessel` schema)
no_sign <- function(x) ifelse(trimws(x) %in% c("0", "", "TF"), NA, x)

# Long form: `d` holds vid, t1, t2, record and columns named "<table>.<column>"
longer <- function(d, source, lineage, kind, edition = NA_integer_, page = NA_integer_) {
  cols <- grep("[.]", names(d), value = TRUE)
  if (!"edition" %in% names(d)) d$edition <- edition
  if (!"page" %in% names(d)) d$page <- page
  d |>
    mutate(across(all_of(cols), ~ blank_na(fmt(.x)))) |>
    pivot_longer(all_of(cols), names_to = "key", values_to = "value", values_drop_na = TRUE) |>
    transmute(vid = as.integer(vid), table = sub("[.].*$", "", key), column = sub("^[^.]*[.]", "", key), value,
              t1 = d8(t1), t2 = d8(t2), source = if (length(source) == 1) source else source, lineage, kind,
              edition = as.integer(edition), page = as.integer(page), record = as.character(record))
}

ev <- list()

# The annual register PDFs ---------------------------------------------------------------------------------------------
reg <- read_parquet(fd_staging("skipaskra", "register.parquet"))
ev$pdf <- reg |>
  transmute(vid, t1 = as.Date(paste0(edition, "-01-01")), t2 = t1, edition, page, record = paste0("pdf:", edition, ":", page, ":", y),
            vessel_hist.name = name, vessel_hist.previous_name = previous_name, vessel_hist.usage_category = ship_type,
            vessel_hist.open = ifelse(section == "open", 1L, 0L), vessel_hist.classification_society = class_society,
            vessel_hist.construction_place = built_place, vessel_hist.construction_year = built_year,
            vessel_hist.construction_station = yard, vessel_hist.hull_material = hull_material, vessel_hist.imo_no = imo,
            vessel_hist.power_indicator = power_index, vessel_hist.changes = changes,
            vessel_identification_hist.district = district, vessel_identification_hist.region_acronym = region_acronym,
            vessel_identification_hist.region_no = region_no, vessel_identification_hist.call_sign = call_sign,
            vessel_identification_hist.home_port = home_port,
            vessel_measurement_hist.length = length_reg, vessel_measurement_hist.max_length = loa,
            vessel_measurement_hist.width = breadth, vessel_measurement_hist.depth = depth,
            vessel_measurement_hist.brutto_grt = grt, vessel_measurement_hist.brutto_weight_tons = gt,
            vessel_measurement_hist.netto_weight_tons = nt,
            vessel_engines_hist.manufacturer_name = engine_make, vessel_engines_hist.year = engine_year,
            vessel_engines_hist.power = engine_kw,
            vessel_owners_hist.name = owner, vessel_owners_hist.address = address, vessel_owners_hist.postal_no = postcode,
            vessel_owners_hist.town = town) |>
  longer(paste0("pdf:", reg$edition[1]), "register", "snapshot")
ev$pdf$source <- paste0("pdf:", ev$pdf$edition)

dr <- read_parquet(fd_staging("skipaskra", "draught.parquet"))
ev$draught <- dr |>
  transmute(vid, t1 = as.Date(paste0(edition, "-01-01")), t2 = t1, edition, page, record = paste0("pdf_draught:", edition, ":", vid),
            vessel_measurement_hist.draft = draft_loaded, vessel_measurement_hist.draft_light = draft_light,
            vessel_measurement_hist.weight = weight, vessel_measurement_hist.draught_length = length,
            vessel_measurement_hist.draught_breadth = breadth) |>
  longer("pdf_draught", "register", "snapshot")
ev$draught$source <- paste0("pdf_draught:", ev$draught$edition)

# an edition lists the previous year's events; one without a printed date speaks for that whole year
evt <- read_parquet(fd_staging("skipaskra", "event.parquet"))
ev$event <- evt |>
  transmute(vid, edition, page, record = paste0("pdf_event:", edition, ":", page, ":", y),
            t1 = coalesce(date, as.Date(paste0(edition - 1, "-01-01"))), t2 = coalesce(date, as.Date(paste0(edition - 1, "-12-31"))),
            vessel_event.event = ifelse(is.na(subkind), kind, paste(kind, subkind, sep = ":")),
            vessel_event.section = section, vessel_event.fate = fate, vessel_event.remark = remark,
            vessel_event.last_re_registration = last_rereg, vessel_event.name = name, vessel_event.district = district,
            vessel_event.home_port = home_port, vessel_event.brutto_weight_tons = gt, vessel_event.deck_code = deck_code) |>
  longer("pdf_event", "register", "event")
ev$event$source <- paste0("pdf_event:", ev$event$edition)

# Hreiðar's workbook ---------------------------------------------------------------------------------------------------
hr <- read_parquet(fd_staging("hreidar", "vessel_year.parquet")) |> filter(!is.na(year), nr < 90000)
ev$hreidar <- hr |>
  transmute(vid = nr, t1 = as.Date(paste0(year, "-01-01")), t2 = as.Date(paste0(year, "-12-31")), record = paste0("hreidar:", xl_row),
            vessel_hist.name = name, vessel_hist.usage_category = usage, vessel_hist.segment = segment,
            vessel_hist.open = case_when(grepl("^O", deck) ~ 1L, grepl("^L", deck) ~ 0L),
            vessel_hist.construction_year = build_year, vessel_hist.construction_country = build_country,
            vessel_hist.construction_place = build_town, vessel_hist.hull_material = hull_material,
            vessel_hist.horse_power = hp,
            vessel_identification_hist.region_acronym = district, vessel_identification_hist.region_no = district_no,
            vessel_identification_hist.home_port = home_port,
            vessel_measurement_hist.brutto_grt = grt, vessel_measurement_hist.brutto_grt_older = grt_old,
            vessel_measurement_hist.brutto_weight_tons = gt, vessel_measurement_hist.length = length,
            vessel_measurement_hist.max_length = loa,
            vessel_engines_hist.power = kw, vessel_engines_hist.engine_type = engine_type,
            vessel_fishery_hist.name = operator,
            vessel_event.out_of_use = year_out, vessel_event.fate = fate, vessel_event.note_register = note_register) |>
  longer("hreidar", "hreidar", "interval")

# mbl and the Samgöngustofa scrape ------------------------------------------------------------------------------------
mbl <- read_parquet(fd_staging("mbl", "register_2023-01.parquet"))
ev$mbl <- mbl |>
  transmute(vid, t1 = as.Date("2022-12-28"), t2 = as.Date("2023-01-09"), record = paste0("mbl:", vid),
            vessel_hist.name = name, vessel_hist.previous_name = previous_name, vessel_hist.usage_category = type,
            vessel_hist.construction_year = build_year, vessel_hist.construction_station = yard,
            vessel_hist.construction_place = build_place, vessel_hist.hull_material = hull_material,
            vessel_hist.imo_no = imo, vessel_hist.changes = changes, vessel_hist.horse_power = hp,
            vessel_identification_hist.home_port = home_port, vessel_identification_hist.call_sign = no_sign(call_sign),
            vessel_measurement_hist.length = length, vessel_measurement_hist.max_length = loa,
            vessel_measurement_hist.width = breadth, vessel_measurement_hist.depth = depth,
            vessel_measurement_hist.brutto_grt = grt, vessel_measurement_hist.brutto_weight_tons = gt,
            vessel_measurement_hist.netto_weight_tons = nt,
            vessel_engines_hist.manufacturer_name = engine,
            vessel_operational_hist.operational_category = operational_category,
            vessel_operational_hist.processing_licence = processing_licence,
            vessel_fishery_hist.name = operator, vessel_mmsi_hist.mmsi_no = mmsi) |>
  longer("mbl", "mbl", "snapshot")

sgs <- read_parquet(fd_staging("samgongustofa", "register_2022-12-28.parquet"))
ev$samgongustofa <- sgs |>
  transmute(vid, t1 = as.Date("2022-12-28"), t2 = t1, record = paste0("samgongustofa:", vid),
            vessel_hist.name = name, vessel_hist.usage_category = type, vessel_hist.status = status,
            vessel_hist.construction_year = build_year, vessel_hist.construction_station = yard,
            vessel_identification_hist.region_acronym = district, vessel_identification_hist.region_no = district_no,
            vessel_identification_hist.home_port = home_port,
            vessel_measurement_hist.length = length, vessel_measurement_hist.brutto_grt = grt,
            vessel_measurement_hist.brutto_weight_tons = gt) |>
  longer("samgongustofa:2022-12-28", "register", "snapshot")

# The `vessel` schema --------------------------------------------------------------------------------------------------
vkey <- ora("vessel", "vessel") |> transmute(vessel_id, vid = as.integer(registration_no))
vh <- function(table) ora("vessel", table) |> filter(hist_operation != "DEL") |> inner_join(vkey, by = "vessel_id") |>
  mutate(t1 = d8(valid_from), t2 = d8(valid_to))
ev$vessel_hist <- vh("vessel_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_hist:", vessel_hist_id),
            vessel_hist.name = name, vessel_hist.previous_name = previous_name, vessel_hist.usage_category = usage_category,
            vessel_hist.usage_category_no = usage_category_no, vessel_hist.status = status, vessel_hist.open = open,
            vessel_hist.imo_no = imo_no, vessel_hist.construction_year = construction_year,
            vessel_hist.construction_place = construction_place, vessel_hist.construction_station = construction_station,
            vessel_hist.construction_country = construction_country,
            vessel_hist.classification_society = classification_society, vessel_hist.hull_material = hull_material,
            vessel_hist.power_kw = power_kw, vessel_hist.horse_power = horse_power,
            vessel_hist.power_indicator = power_indicator, vessel_hist.operation_area = operation_area,
            vessel_event.initial_registration = d8(initial_registration_date)) |>
  longer("vessel:vessel_hist", "register", "interval")
ev$vessel_ident <- vh("vessel_identification_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_identification_hist:", vessel_iden_hist_id),
            vessel_identification_hist.region_acronym = region_acronym, vessel_identification_hist.region_no = region_no,
            vessel_identification_hist.call_sign = no_sign(call_sign), vessel_identification_hist.home_port = home_port,
            vessel_identification_hist.home_port_no = home_port_no) |>
  longer("vessel:vessel_identification_hist", "register", "interval")
ev$vessel_meas <- vh("vessel_measurement_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_measurement_hist:", vessel_meas_hist_id),
            vessel_measurement_hist.length = length, vessel_measurement_hist.max_length = max_length,
            vessel_measurement_hist.width = width, vessel_measurement_hist.depth = depth,
            vessel_measurement_hist.draft = draft, vessel_measurement_hist.brutto_grt = brutto_grt,
            vessel_measurement_hist.brutto_weight_tons = brutto_weight_tons,
            vessel_measurement_hist.netto_weight_tons = netto_weight_tons,
            vessel_measurement_hist.brutto_grt_older = brutto_grt_older) |>
  longer("vessel:vessel_measurement_hist", "register", "interval")
ev$vessel_eng <- vh("vessel_engines_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_engines_hist:", vessel_eng_hist_id),
            vessel_engines_hist.manufacturer_name = manufacturer_name, vessel_engines_hist.year = year,
            vessel_engines_hist.power = power, vessel_engines_hist.usage_code = usage_code) |>
  longer("vessel:vessel_engines_hist", "register", "interval")
ev$vessel_op <- vh("vessel_operational_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_operational_hist:", vessel_op_hist_id),
            vessel_operational_hist.operational_category_no = operational_category_no,
            vessel_operational_hist.operational_category = operational_category,
            vessel_operational_hist.license_system = license_system) |>
  longer("vessel:vessel_operational_hist", "fisheries", "interval")
ev$vessel_own <- vh("vessel_owners_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_owners_hist:", vessel_owners_id, ":", vessel_own_hist_id),
            vessel_owners_hist.name = name, vessel_owners_hist.address = address,
            vessel_owners_hist.postal_no = postal_no, vessel_owners_hist.percentage = percentage) |>
  longer("vessel:vessel_owners_hist", "register", "interval")
ev$vessel_fish <- vh("vessel_fishery_hist") |>
  transmute(vid, t1, t2, record = paste0("vessel_fishery_hist:", vessel_fish_hist_id),
            vessel_fishery_hist.name = name, vessel_fishery_hist.address = address, vessel_fishery_hist.postal_no = postal_no) |>
  longer("vessel:vessel_fishery_hist", "fisheries", "interval")

# The Directorate of Fisheries' ship history (kvoti to 2020, ufs after) -------------------------------------------------
ks <- ora("kvoti", "skipasaga")
ev$kvoti_saga <- ks |>
  transmute(vid = skip_nr, t1 = i_gildi, t2 = ur_gildi, record = paste0("kvoti.skipasaga:", skip_nr, ":", saga_nr),
            vessel_hist.name = heiti, vessel_hist.deck = dekk,
            vessel_identification_hist.region_acronym = einkst, vessel_identification_hist.region_no = einknr,
            vessel_identification_hist.home_port_no = heimah,
            vessel_measurement_hist.brutto_grt = brl, vessel_measurement_hist.length_fisheries = lengd,
            vessel_measurement_hist.brutto_weight_tons = bruttotonn, vessel_measurement_hist.length = skrad_lengd,
            vessel_measurement_hist.width = skrad_breidd, vessel_measurement_hist.depth = skrad_dypt,
            vessel_operational_hist.operational_category_no = flokkur) |>
  longer("kvoti.skipasaga", "fisheries", "interval")

ufs_key <- ora("ufs", "skip") |> transmute(skip_id = id, vid = as.integer(skip_numer))
saga_cols <- function(d) d |>
  transmute(vid, t1 = gildir_fra, t2 = gildir_til, record,
            vessel_hist.name = heiti, vessel_hist.deck = dekk,
            vessel_identification_hist.region_acronym = einkennisstafir, vessel_identification_hist.region_no = einkennisnumer,
            vessel_identification_hist.home_port_no = heimahofn_id,
            vessel_measurement_hist.brutto_grt = bruttolestir, vessel_measurement_hist.length_fisheries = lengd,
            vessel_measurement_hist.brutto_weight_tons = bruttotonn, vessel_measurement_hist.length = skrad_lengd,
            vessel_measurement_hist.width = skrad_breidd, vessel_measurement_hist.depth = skrad_dypt,
            vessel_operational_hist.utgerdarflokkur_id = utgerdarflokkur_id)
ev$ufs_saga <- ora("ufs", "skipasaga") |> inner_join(ufs_key, by = "skip_id") |>
  mutate(record = paste0("ufs.skipasaga:", id)) |> saga_cols() |> longer("ufs.skipasaga", "fisheries", "interval")
ev$ufs_saga_jn <- ora("ufs", "skipasaga_jn") |> filter(jn_operation != "DEL") |> inner_join(ufs_key, by = "skip_id") |>
  # two users can change one row in the same second, so the session tells them apart
  mutate(record = paste0("ufs.skipasaga_jn:", id, ":", format(jn_datetime, "%Y%m%d%H%M%S"), ":", jn_session)) |> saga_cols() |>
  longer("ufs.skipasaga_jn", "fisheries", "interval")
# the journal of ufs.skip: each insert or update of a vessel's call sign and IMO, at the moment it was made
ev$ufs_skip_jn <- ora("ufs", "skip_jn") |> filter(jn_operation != "DEL", !is.na(skip_numer)) |>
  transmute(vid = skip_numer, t1 = jn_datetime, t2 = as.Date(NA), record = paste0("ufs.skip_jn:", id, ":", format(jn_datetime, "%Y%m%d%H%M%S")),
            vessel_identification_hist.call_sign = no_sign(kallmerki), vessel_hist.imo_no = imo_numer) |>
  longer("ufs.skip_jn", "fisheries", "change")

# kvoti's copies of the maritime register --------------------------------------------------------------------------------
sig <- ora("kvoti", "skipaskra_siglo")
h100 <- function(x) ifelse(is.na(x) | x == 0, NA, x / 100)
ev$kvoti_siglo <- sig |>
  transmute(vid = as.integer(skipnr), t1 = dagsfaerslu, t2 = as.Date("2020-07-22"), record = paste0("kvoti.skipaskra_siglo:", skipnr),
            vessel_hist.name = nafnskips, vessel_hist.usage_category_no = notkunarteg,
            vessel_hist.imo_no = ifelse(trimws(imonr) %in% c("0", ""), NA, imonr),
            vessel_hist.power_indicator = h100(aflvisir), vessel_hist.max_propeller_diameter = h100(thvermskrufu),
            vessel_hist.power_kw = h100(vel_kw), vessel_hist.open = case_when(opinn_lokadur == "O" ~ 1L, opinn_lokadur == "L" ~ 0L),
            vessel_identification_hist.district = umdnr,
            vessel_identification_hist.call_sign = no_sign(kallmerki),
            vessel_identification_hist.home_port = heimahofn,
            vessel_measurement_hist.length = h100(skradlengd), vessel_measurement_hist.width = h100(skradbreidd),
            vessel_measurement_hist.depth = h100(skraddypt), vessel_measurement_hist.max_length = h100(mestalengd),
            vessel_measurement_hist.brutto_grt = h100(bruttoruml), vessel_measurement_hist.brutto_weight_tons = h100(bruttotonn),
            vessel_owners_hist.name = eigandi, vessel_owners_hist.address = heimilieiganda,
            vessel_fishery_hist.name = utgerdaradili,
            vessel_certificate.seaworthy_issued = d8(haffaeriutgafudags), vessel_certificate.seaworthy_valid_to = d8(haffaerigildirtil),
            vessel_certificate.seaworthy_extended = d8(haffaeriframlengt)) |>
  longer("kvoti.skipaskra_siglo", "register", "interval")

ex <- ora("kvoti", "skip_extra")
ev$kvoti_extra <- ex |>
  transmute(vid = as.integer(skip_nr), t1 = as.Date(NA), t2 = as.Date(NA), record = paste0("kvoti.skip_extra:", skip_nr),
            vessel_hist.name = heiti, vessel_hist.previous_name = fyrra_nafn_skips,
            vessel_hist.construction_year = smidaar, vessel_hist.construction_place = smidastadur,
            vessel_hist.construction_station = skipasmidastod, vessel_hist.construction_country = smidaland,
            vessel_hist.construction_number = smidanumer, vessel_hist.hull_material_code = efnistegund,
            vessel_hist.classification_society = flokkunarfelag, vessel_hist.usage_category_code = tegund_skips,
            vessel_hist.open = case_when(opinn_batur_eda_thilskip == "O" ~ 1L, opinn_batur_eda_thilskip %in% c("L", "Þ") ~ 0L),
            vessel_identification_hist.district = umdaemisnumer, vessel_identification_hist.call_sign = no_sign(kallnumer),
            vessel_identification_hist.home_port = heimahofn,
            vessel_measurement_hist.length = skrad_lengd, vessel_measurement_hist.width = skrad_breidd,
            vessel_measurement_hist.depth = skrad_dypt, vessel_measurement_hist.max_length = mesta_lengd,
            vessel_measurement_hist.brutto_grt = bruttorumlestir, vessel_measurement_hist.brutto_weight_tons = bruttotonn,
            vessel_measurement_hist.netto_weight_tons = nettotonn,
            vessel_measurement_hist.draft = ifelse(djuprista == 0, NA, djuprista),
            vessel_measurement_hist.weight = ifelse(thyngd_skips == 0, NA, thyngd_skips),
            vessel_owners_hist.name = nafn_eiganda, vessel_owners_hist.address = heimili_eiganda,
            vessel_owners_hist.postal_no = postnumer_eiganda) |>
  longer("kvoti.skip_extra", "register", "undated")
ev$kvoti_extra_reg <- ex |> filter(!is.na(frumskraning)) |>
  transmute(vid = as.integer(skip_nr), t1 = ymd_int(frumskraning), t2 = t1, record = paste0("kvoti.skip_extra:", skip_nr),
            vessel_event.event = "registration:first") |>
  longer("kvoti.skip_extra", "register", "event")

# Licences ------------------------------------------------------------------------------------------------------------
lt <- ora("kvoti", "tegund_veidileyfis") |> transmute(tegund_leyfis = kodi, licence_name = leyfi)
# kvoti's licence id is not unique per row (a deleted licence is kept once per copy), so the record adds the row
lic <- function(d, src) d |> left_join(lt, by = "tegund_leyfis") |>
  transmute(vid = skip_nr, t1 = i_gildi, t2 = ur_gildi, record = paste0(src, ":", vlyf_id, ":", row_number()),
            vessel_licence_hist.licence_type = tegund_leyfis, vessel_licence_hist.licence_name = licence_name,
            vessel_licence_hist.area = svaedi, vessel_licence_hist.licence_no = leyfis_nr, vessel_licence_hist.note = skyring)
ev$lic <- ora("kvoti", "veidileyfi") |> lic("kvoti.veidileyfi") |> longer("kvoti.veidileyfi", "fisheries", "interval")
ev$lic_deleted <- ora("kvoti", "veidileyfi_eydd") |> lic("kvoti.veidileyfi_eydd") |>
  mutate(vessel_licence_hist.deleted = TRUE) |> longer("kvoti.veidileyfi_eydd", "fisheries", "interval")
ev$lic_coastal <- ora("kvoti", "strandveidileyfi_v") |> lic("kvoti.strandveidileyfi_v") |>
  longer("kvoti.strandveidileyfi_v", "fisheries", "interval")
ev$lic_revoked <- ora("kvoti", "veidileyfi_sviptingar") |>
  transmute(vid = skip_nr, t1 = i_gildi, t2 = ur_gildi, record = paste0("kvoti.veidileyfi_sviptingar:", skip_nr, ":", format(i_gildi, "%Y%m%d%H%M"), ":", row_number()),
            vessel_licence_hist.revocation = coalesce(flokkur, "revoked"), vessel_licence_hist.note = skyring) |>
  longer("kvoti.veidileyfi_sviptingar", "fisheries", "interval")
ev$lic_seine <- ora("kvoti", "dragnot_leyfi") |>
  transmute(vid = skip_nr, t1 = as.Date(paste0(ar, "-01-01")), t2 = as.Date(paste0(ar, "-12-31")),
            record = paste0("kvoti.dragnot_leyfi:", skip_nr, ":", ar, ":", timabil, ":", row_number()),
            vessel_licence_hist.licence_name = "dragnót", vessel_licence_hist.period = timabil) |>
  longer("kvoti.dragnot_leyfi", "fisheries", "interval")
ev$lic_lump <- ora("kvoti", "grasleppusaga") |>
  transmute(vid = skip_nr, t1 = i_gildi, t2 = ur_gildi, record = paste0("kvoti.grasleppusaga:", leyfis_nr, ":", format(i_gildi, "%Y%m%d"), ":", row_number()),
            vessel_licence_hist.licence_name = "grásleppa", vessel_licence_hist.licence_no = leyfis_nr,
            vessel_licence_hist.area = svaedi, vessel_licence_hist.status = stada_leyfis, vessel_licence_hist.note = aths) |>
  longer("kvoti.grasleppusaga", "fisheries", "interval")

# MMSI and MarineTraffic -----------------------------------------------------------------------------------------------
mm <- read_parquet(fd_curated("vessel", "mmsi.parquet")) |> filter(!is.na(vid))
ev$mmsi <- mm |>
  transmute(vid, t1 = mmsi_t1, t2 = mmsi_t2, record = paste0("mmsi:", mmsi, ":", vid),
            vessel_mmsi_hist.mmsi_no = mmsi, vessel_mmsi_hist.window_basis = window_basis) |>
  longer("mmsi", "radio", "interval")
ev$mmsi_2023 <- ora("ops_einarhj", "mmsi_icelandic_registry_20230115") |> filter(!is.na(vid)) |>
  transmute(vid, t1 = as.Date("2023-01-15"), t2 = t1, record = paste0("mmsi_20230115:", mmsi, ":", vid),
            vessel_mmsi_hist.mmsi_no = mmsi, vessel_identification_hist.call_sign = no_sign(cs)) |>
  longer("ops_einarhj.mmsi_icelandic_registry_20230115", "radio", "snapshot")
mt <- read_parquet(fd_staging("marinetraffic", "icelandic.parquet")) |> filter(!is.na(vid), vid < 3700 | (vid >= 5000 & vid < 10000))
ev$marinetraffic <- mt |>
  transmute(vid, t1 = date_recorded, t2 = date_recorded, record = paste0("marinetraffic:", file, ":", mobileid),
            vessel_mmsi_hist.mmsi_no = mmsi, vessel_hist.imo_no = imo, vessel_identification_hist.call_sign = no_sign(cs),
            vessel_hist.name = name) |>
  longer("marinetraffic", "observation", "snapshot")

# Bind, normalise, write -----------------------------------------------------------------------------------------------
norm_txt <- function(x) {
  x <- toupper(enc2utf8(x))
  x <- gsub("([[:alpha:]])[-‐–] +([[:alpha:]])", "\\1\\2", x, perl = TRUE)   # a word broken across a wrapped cell
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}
evidence <- bind_rows(ev) |>
  filter(!is.na(vid)) |>
  mutate(value_num = suppressWarnings(as.numeric(value)), value_norm = norm_txt(value),
         kind = ifelse(kind == "interval" & is.na(t1) & is.na(t2), "undated", kind)) |>
  relocate(vid, table, column, value, value_num, value_norm, t1, t2) |>
  arrange(vid, table, column, t1, source)

stopifnot(!anyNA(evidence$source), !anyNA(evidence$lineage), !anyNA(evidence$table), !anyNA(evidence$column),
          all(evidence$lineage %in% c("register", "fisheries", "hreidar", "mbl", "radio", "observation")))

print(evidence |> count(lineage, source = sub(":[0-9]{4}$", "", source)) |> arrange(lineage, desc(n)) |>
        knitr::kable(caption = "evidence: rows per witness"))
print(evidence |> count(table) |> knitr::kable(caption = "evidence: rows per table"))

inputs <- c(file.path(fd_staging("skipaskra"), c("register.parquet", "draught.parquet", "event.parquet")),
            fd_staging("hreidar", "vessel_year.parquet"), fd_staging("mbl", "register_2023-01.parquet"),
            fd_staging("samgongustofa", "register_2022-12-28.parquet"), fd_staging("marinetraffic", "icelandic.parquet"),
            fd_curated("vessel", "mmsi.parquet"),
            fd_raw("oracle", "vessel", paste0(c("vessel", "vessel_hist", "vessel_identification_hist", "vessel_measurement_hist",
                                                "vessel_engines_hist", "vessel_operational_hist", "vessel_owners_hist",
                                                "vessel_fishery_hist"), ".parquet")),
            fd_raw("oracle", "kvoti", paste0(c("skipasaga", "skipaskra_siglo", "skip_extra", "veidileyfi", "veidileyfi_eydd",
                                               "veidileyfi_sviptingar", "strandveidileyfi_v", "dragnot_leyfi", "grasleppusaga",
                                               "tegund_veidileyfis"), ".parquet")),
            fd_raw("oracle", "ufs", paste0(c("skip", "skip_jn", "skipasaga", "skipasaga_jn"), ".parquet")),
            fd_raw("oracle", "ops_einarhj", "mmsi_icelandic_registry_20230115.parquet"))
write_curated(evidence, fd_curated("vessel", "skipaskra", "evidence.parquet"), inputs = inputs)
