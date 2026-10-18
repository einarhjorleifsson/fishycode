# kvoti's licence tables and the other records that witness a licence, staged as they are (plan 029 step 1).
# Side: once (licence history). See plan 014; plan 029 §5.1 and §5.7; decision 133.
#
# Input:  raw/oracle/kvoti/{veidileyfi,veidileyfi_eydd,grasleppusaga,grasleppurettindi,grasleppa_veidarfaeri,
#                           dragnot_leyfi,dragnot_timabil,veidileyfi_sviptingar,sv_flokkun,veidileyfi_svipt_undanthaga,
#                           veidileyfi_vanskil,tegund_veidileyfis,svaedi_veidileyfis,yfirlit_veidileyfa,
#                           afla_heimild,heimild,kvotategundir_heiti,uthl_makrill,makrill_flokkur,tilkynning_sokn,
#                           strandveidar}.parquet
#         raw/oracle/fs_afli/{grasl_stofn,grasl_sokn}.parquet
# Output: staging/kvoti/licence*.parquet      the licence register: licences, deleted licences, lumpfish rights and
#                                             their 2021 state, lumpfish nets, Danish seine, revocations, exemptions,
#                                             arrears, and the code lists (type, area, catalogue, revocation cause)
#         staging/kvoti/quota_*.parquet       the quota record's rights (not its catch), quota types, right codes
#         staging/kvoti/mackerel_*.parquet    mackerel allocations 2009/10-2017/18 and the mackerel class
#         staging/kvoti/effort_day_notice.parquet, coastal_trip.parquet, lumpfish_logbook.parquet
#
# Source-shaped: one table per source, columns renamed to the house style and nothing else changed. Dates stay as
# Oracle holds them (TIMESTAMP, UTC). The 1-3 digit years of the revocations, exemptions and arrears are corrected
# beside them by curate/corrections/licence_lost_century.R, never here.
#
# - Rows without a key keep their position in the dump as `row`. The dump is frozen in the `once` project, so the
#   position stays a valid record id.
# - Personal data: kennitala is kept, as the lumpfish right's owner (`owner_kt`) and the net application's operator
#   (`operator_kt`). The maintainer's general rule (2026-10-18): kennitala may be carried up to and including
#   curated/, under $FISHYDATA only, never in the repo, docs or anything published. The free-text notes are kept as
#   given: they give the reason for a storage, deletion or revocation. Staff user names (`snn`, `sbn`, `sng`, `sbg`,
#   `gerandi`) are dropped: nothing uses them. The entry and change times are kept.
# - Not read: the views (copies), veidileyfi_svipt_tilk, veidileyfi_svipt_bodunars, veidileyfi_postlisti,
#   strandveidar_logskradur. afla_heimild's catch (`heimild` X) is not staged: only the rights.

library(dplyr)
library(nanoparquet)

ora <- function(schema, table) read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet")))
stage <- function(d, name) duckdbfs::write_dataset(d, fd_staging("kvoti", paste0(name, ".parquet")))
n0 <- list()

# The licence register -----------------------------------------------------------------------------------------------
licence <- ora("kvoti", "veidileyfi") |>
  transmute(id = as.integer(id), vid = as.integer(skip_nr), licence_type = tegund_leyfis, area = svaedi,
            t1 = i_gildi, t2 = ur_gildi, note = skyring, transfer = flutn_rofi, transfer_date = flutn_dags,
            licence_no = as.integer(leyfis_nr), vlyf_id = as.integer(vlyf_id), unpaid = er_ovirk == 1,
            entered = snt, changed = sbt)
stopifnot("veidileyfi.id is not unique" = !anyDuplicated(licence$id))

licence_deleted <- ora("kvoti", "veidileyfi_eydd") |>
  transmute(row = row_number(), vlyf_id = as.integer(vlyf_id), vid = as.integer(skip_nr), licence_type = tegund_leyfis,
            area = svaedi, t1 = i_gildi, t2 = ur_gildi, note = skyring, licence_no = as.integer(leyfis_nr),
            transfer = flutn_rofi, transfer_date = flutn_dags, entered = snt, deleted = sbt)

licence_lumpfish <- ora("kvoti", "grasleppusaga") |>
  transmute(row = row_number(), licence_no = as.integer(leyfis_nr), vid = as.integer(skip_nr), t1 = i_gildi,
            t2 = ur_gildi, status = stada_leyfis, owner_kt = eigandi, area = svaedi, m3, note = aths, entered = snt,
            changed = sbt)

licence_lumpfish_right <- ora("kvoti", "grasleppurettindi") |>
  transmute(licence_no = as.integer(leyfis_nr), vid = as.integer(skip_nr), stored_since = i_gildi,
            status = stada_leyfis, owner_kt = eigandi, area = svaedi, m3, note = aths, wants_to_fish = vill_a_veidar,
            season_start = upphafsdagur, entered = snt, changed = sbt)

licence_lumpfish_gear <- ora("kvoti", "grasleppa_veidarfaeri") |>
  transmute(row = row_number(), vid = as.integer(skip_nr), operator_kt = kennitala, area = veidisvaedi, t1 = veidi_fra,
            t2 = veidi_til,
            n_nets = fjoldi_neta, headline_m = teinalengd, catch_prev_year_kg = afli_fyrra_ars,
            catch_value_isk = aflaverdm_samtals, roe_prev_year_kg = hrogn_fyrra_ars, roe_value_isk = hrogn_samtals,
            entered = snt, changed = sbt)

seine_period <- ora("kvoti", "dragnot_timabil") |> transmute(year = ar, period = trimws(nr), t1 = fra, t2 = til)
licence_seine <- ora("kvoti", "dragnot_leyfi") |>
  transmute(vid = as.integer(skip_nr), year = ar, period = trimws(timabil), surrendered = dags_afsals,
            requested_by = umbeidandi, note = skyring) |>
  left_join(seine_period, by = c("year", "period")) |>
  relocate(t1, t2, .after = period)
stopifnot("a Danish seine licence has no period" = !anyNA(licence_seine$t1))

licence_revocation <- ora("kvoti", "veidileyfi_sviptingar") |>
  transmute(row = row_number(), vid = as.integer(skip_nr), t1 = i_gildi, t2 = ur_gildi, cause = trimws(flokkur),
            note = trimws(skyring), entered = snt, changed = sbt) |>
  left_join(ora("kvoti", "sv_flokkun") |> transmute(cause = trimws(flokkur), cause_text = skyring), by = "cause")

licence_exemption <- ora("kvoti", "veidileyfi_svipt_undanthaga") |>
  transmute(id = as.integer(id), vid = as.integer(skip_nr), purpose = undanthaga, t1 = i_gildi, t2 = ur_gildi,
            closed = lok, entered = snt, changed = sbt)

licence_arrears <- ora("kvoti", "veidileyfi_vanskil") |>
  transmute(row = row_number(), vid = as.integer(skip_nr), t1 = i_gildi, t2 = ur_gildi, kind = trimws(flokkun),
            note = aths, entered = snt, changed = sbt)

licence_type <- ora("kvoti", "tegund_veidileyfis") |> transmute(licence_type = kodi, name = leyfi, name_en = leyfi_enska)
licence_area <- ora("kvoti", "svaedi_veidileyfis") |> transmute(area = kodi, name = svaedi, name_en = svaedi_enska)
licence_catalogue <- ora("kvoti", "yfirlit_veidileyfa") |>
  transmute(vlyf_id = as.integer(id), licence_type = tegund_leyfis, area = svaedi, t2 = ur_gildi, place = stadsetning,
            season_start = upphaf_veiditimabils, n_days = dagafjoldi, text_id = svaedis_skyring_id, entered = snt)

# The quota record ---------------------------------------------------------------------------------------------------
quota_right <- duckdbfs::open_dataset(fd_raw("oracle", "kvoti", "afla_heimild.parquet")) |>
  filter(heimild != "X") |>
  transmute(id, vid = skip_nr, quota_type = ftegund, right = heimild, amount = magn, t1 = i_gildi, t2 = ur_gildi,
            ref = tilvisun, entered = snt, changed = sbt) |>
  collect() |>
  mutate(across(c(id, vid, quota_type, ref), as.integer))
quota_type <- ora("kvoti", "kvotategundir_heiti") |>
  transmute(quota_type = as.integer(kvotategund), parent = as.integer(yfirkvotategund), name = heiti,
            name_en = enskt_heiti, area = veidisvaedi, species = as.integer(fisktegund))
quota_right_code <- ora("kvoti", "heimild") |> transmute(right = tegund, text = lysing)

mackerel_allocation <- ora("kvoti", "uthl_makrill") |>
  transmute(id = as.integer(id), vid = as.integer(skip_nr), fishing_year = timabil, right = trimws(heimild),
            t1 = i_gildi, t2 = ur_gildi, amount = magn, pot = as.integer(pottur), entered = snt)
mackerel_class <- ora("kvoti", "makrill_flokkur") |>
  transmute(vid = as.integer(skip_nr), class = trimws(flokkur), fishing_year = timabil, entered = snt)

# Notices, trips and the lumpfish logbook ----------------------------------------------------------------------------
effort_day_notice <- ora("kvoti", "tilkynning_sokn") |>
  transmute(row = row_number(), vid = as.integer(skip_nr), time = timi, action = as.integer(adgerd),
            valid = gild == 1, line = lina_handf == 1, port = as.integer(hofn))

coastal_trip <- ora("kvoti", "strandveidar") |>
  transmute(row = row_number(), vid = as.integer(skip_nr), port = as.integer(hofn), landing_no = as.integer(komunr),
            t_departure = timi_ur_hofn, t_arrival = timi_i_hofn, invalid = er_ogild == 1,
            departure_trail_id = id_ur_hofn, arrival_trail_id = id_i_hofn)

sets <- ora("fs_afli", "grasl_sokn") |>
  transmute(vid = as.integer(skipnr), year = as.integer(vear), date = as.Date(vedags)) |>
  filter(as.integer(format(date, "%Y")) == year) |>
  group_by(vid, year) |>
  summarise(first_set = min(date), last_set = max(date), n_sets = n(), .groups = "drop")
lumpfish_logbook <- ora("fs_afli", "grasl_stofn") |>
  transmute(vid = as.integer(skipnr), year = as.integer(vear), port = as.integer(ahofn), place = as.integer(stadur),
            processing = as.integer(teg_verkunar), net_type = as.integer(gerd_neta), mesh = moskvi, barrels = tunnur,
            roe = hrogn) |>
  left_join(sets, by = c("vid", "year"))

# Check and write ----------------------------------------------------------------------------------------------------
out <- list(licence = licence, licence_deleted = licence_deleted, licence_lumpfish = licence_lumpfish,
            licence_lumpfish_right = licence_lumpfish_right, licence_lumpfish_gear = licence_lumpfish_gear,
            licence_seine = licence_seine, licence_revocation = licence_revocation,
            licence_exemption = licence_exemption, licence_arrears = licence_arrears, licence_type = licence_type,
            licence_area = licence_area, licence_catalogue = licence_catalogue, quota_right = quota_right,
            quota_type = quota_type, quota_right_code = quota_right_code, mackerel_allocation = mackerel_allocation,
            mackerel_class = mackerel_class, effort_day_notice = effort_day_notice, coastal_trip = coastal_trip,
            lumpfish_logbook = lumpfish_logbook)
stopifnot("a staff user name was staged" = !any(unlist(lapply(out, names)) %in% c("snn", "sbn", "sng", "sbg", "gerandi")))
for (n in names(out)) stage(out[[n]], n)
cat(sprintf("%-24s %9d rows\n", names(out), vapply(out, nrow, integer(1))), sep = "")
