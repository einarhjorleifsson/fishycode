# The logbooks' gear, rigging and per-haul sensor columns, each in one outcome, and their code lists (plan 052)
# Side: preprocessing (reference). See plan 014.
# Input:  raw/oracle/afli/rafr_stofn_{fotreipi,gerd_poka,skiljugerd,gerd_kroka,beita_t,sjolag,botngerd}.parquet,
#         raw/oracle/fs_afladagbok/ws_stofn_{gerd_plogs,tegund_gildru,tegund_notar}.parquet,
#         raw/oracle/adb/{dredge_type,trap_type,surrounding_net_type}.parquet (the labels, as recorded)
# Output: curated/reference/gear_part_map.parquet   one row per source column (and gear, where its meaning depends on
#                                                   the gear): the table, part and measure it fills, or why it is not
#                                                   used; its unit, the factor to SI, its plausible range, its code list
#         curated/reference/gear_part_code.parquet  the code lists: each source's code, the one list's type, the label
#
# Written by Claude (AI) on 2026-10-29, from plan 052's measurements ($FISHYDATA/archive/2026-10-29-gear-rigging-sensor/,
# its column map 09) and the checks of the same day recorded in decision 244; not checked by a person.
#
# The map is the one record of each column's unit (plan 052 §5) and is read by sources/{afli,fs_afladagbok,adb}/part.R.
# `table` is the table without its layer: afli's "toga" is rafr_toga (loaded) and toga (edited) both. `gears` limits a
# row to the station's gear classes (ICES, reference/gear/mapping.R); "!X" excludes X. A column's value on a gear no
# row covers is counted, not carried (the trawl form a dredge app filled with 1s, plan 052 §2).
#
# `zero`: "empty" (a 0 is the apps' empty field: no value, counted), "value" (0 is a value: a flag, a code, calm) or
# "placeholder" (the value is kept raw with no SI value, plan 052 ask f). `placeholder` lists further raw values read so.
# `min_si`, `max_si`: outside, the value is kept and flagged `implausible` (AGENTS.md: an extreme value is flagged, not
# corrected); the bounds are physical and wide (sea water -3 to 25 degC, above any North Atlantic fishing ground; wind
# to 40 m/s, beyond Beaufort 12), and set where the tails show sentinels (9999, -99) or the apps' 1s.
# `basis` is "reconstructed" where the column's meaning is read from its values (plan 052 §4, ask g).

library(tidyverse)
library(duckdbfs)

# Map --------------------------------------------------------------------------
m <- function(schema, table, column, use, part = NA, measure = NA, gears = NA, rank = 1L, unit_raw = NA,
              to_si = NA_real_, zero = "empty", placeholder = NA, min_si = NA_real_, max_si = NA_real_,
              code_list = NA, basis = "recorded", flag = NA, type_fixed = NA, quantity = NA, place = NA,
              moment = NA, mount = NA, instrument = NA, special = FALSE, note = NA)
  tibble(schema, table, column, use, part, measure, gears, rank = as.integer(rank), unit_raw, to_si, zero,
         placeholder, min_si, max_si, code_list, basis, flag, type_fixed, quantity, place, moment, mount,
         instrument, special, note)
FATHOM <- 1.8288
FOOT   <- 0.3048
TOWNET <- "OTB,OTM,SDN"   # the gears with a net and a codend in afli's towing table
TRAWL  <- "OTB,OTM"
# Measured 2026-10-30 (decision 245)
GILLNET_M <- paste(
  "metres, read from the values: the regulation on cod gillnets (115/2006, art. 6) counts a net as 60 fathoms of",
  "netting, some 30 fathoms (55 m) when hung at the usual half; the values are 50-67 (median 54-59), and the AIS",
  "displacement while hauling is 0.5-1.2 times nets x length on most afli stations, not 1.8 as fathoms would give")
DREDGE_FT <- paste(
  "Feet by the documents (the schema's PLOG_STAERD, fs_afladagbok's comment) and by the scallop dredges, 86 % of",
  "afli's values (8 x 8 x 2: 2.4 x 2.4 x 0.6 m; as metres a frame 8 m long, 2 m high); the sea urchin and sea",
  "cucumber dredges of 2003 on (2-4 wide, 1 high) read as metres. No rule picks the unit per record: kept raw")

nu <- function(schema, table, column, note) m(schema, table, column, "not_used", note = note)
key <- function(schema, table, column) m(schema, table, column, "key", note = "the station's key (.sid)")
audit <- function(schema, table) nu(schema, table, c("snt", "sng", "sbt", "sbg"),
                                    "audit: Oracle's user and time of the row's insert and update")
# A sensor reading: quantity, place, moment, mount and instrument (plan 052 §5). A bottom or headline reading is made at
# depth, so on the gear; a surface or air reading on the vessel. The source names no instrument but the headline's.
sensor <- function(schema, table, column, quantity, place, moment, mount, instrument, unit_raw, ...)
  m(schema, table, column, "sensor_summary", quantity = quantity, place = place, moment = moment, mount = mount,
    instrument = instrument, unit_raw = unit_raw, ...)
temp <- function(schema, table, column, place, moment, mount, instrument = "unknown", ...)
  sensor(schema, table, column, "temperature", place, moment, mount, instrument, "degC", to_si = 1,
         zero = "placeholder", min_si = if (place == "air") -40 else -3, max_si = if (place == "air") 35 else 25, ...)

## afli: the towing table (rafr_toga, toga) ------------------------------------------------------------------------
afli_toga <- bind_rows(
  key("afli", "toga", "visir"),
  nu("afli", "toga", "ibotni", "a time: the gear on the bottom (t2), the fishing sample's"),
  nu("afli", "toga", "togtimi", "a duration: the tow time, the fishing sample's"),
  temp("afli", "toga", "botnhiti", "bottom", "1", "gear"),
  temp("afli", "toga", "botnhiti_lok", "bottom", "2", "gear"),
  m("afli", "toga", "hoflina", "gear_part", "headline", "length_m", TOWNET, unit_raw = "m", to_si = 1, min_si = 3,
    max_si = 3000, note = "metres, not the feet of Oracle's comment: plan 052 §2, account 15"),
  m("afli", "toga", "moskvi", "gear_part", "codend", "mesh_size_mm", TOWNET, unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000, note = "the loader copied moskvi_staerd here where nothing was sent (the XML map)"),
  m("afli", "toga", "moskvi", "gear_part", "dredge", "mesh_size_mm", "DRB", unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000),
  sensor("afli", "toga", "hoflinum", "fitted", "headline", NA, "gear", "headline_sensor", "j/n",
         code_list = "yes_no", zero = "value"),
  m("afli", "toga", "hlerar", "rigging_part", "door", "weight_kg", TRAWL, unit_raw = "kg", to_si = 1, min_si = 20,
    max_si = 9000),
  m("afli", "toga", "grandarar", "rigging_part", "sweep", "length_m", TOWNET, unit_raw = "m", to_si = 1, min_si = 2,
    max_si = 1000, note = "metres, not the fathoms of Oracle's comment: plan 052 §2, account 15"),
  sensor("afli", "toga", "nemi", "fitted", "gear", NA, "gear", "catch_sensor", "j/n", code_list = "yes_no",
         zero = "value"),
  m("afli", "toga", "togle", "rigging_part", "rope", "length_m", "SDN", unit_raw = "fathom", to_si = FATHOM,
    min_si = 20, max_si = 20000, note = "fathoms throughout: sent so before 2011, sent in metres and converted by the loader after (the XML map)"),
  m("afli", "toga", "virle", "rigging_part", "wire", "length_m", "SDN", unit_raw = "fathom", to_si = FATHOM,
    min_si = 20, max_si = 20000, note = "0 on every row"),
  nu("afli", "toga", "fjikilo", "an observation of the catch (shrimp per kg): fishing_sample.catch_nperkg (plan 052 §5)"),
  m("afli", "toga", "staerd", "gear_part", "net", "meshes_around", "OTB", unit_raw = "meshes", to_si = 1,
    min_si = 10, max_si = 10000, note = "the shrimp trawl's meshes around (the schema's STAERD)"),
  nu("afli", "toga", "gerd", "0 on every row; the shrimp trawl's type, 'obsolete' in the schema"),
  m("afli", "toga", "pl_breidd", "gear_part", "dredge", "width_m", "DRB", unit_raw = "unknown",
    note = paste("the edited layer holds 49,080 (1972-2021), rafr_ 5.", DREDGE_FT)),
  m("afli", "toga", "pl_lengd", "gear_part", "dredge", "length_m", "DRB", unit_raw = "unknown",
    note = "the edited layer holds 44,292, rafr_ 5; as pl_breidd"),
  m("afli", "toga", "pl_haed", "gear_part", "dredge", "height_m", "DRB", unit_raw = "unknown",
    note = "the edited layer holds 2,515, rafr_ 5; as pl_breidd"),
  sensor("afli", "toga", "botn_gerd", "bottom_type", "bottom", "1", NA, "observed", "code", to_si = 1,
         code_list = "bottom_type", note = "empty in both layers; the sent layer's BOTNGERD is read instead"),
  m("afli", "toga", "tvo_veidarf", "rigging_part", "rig", "n", "OTB,OTM,DRB", special = TRUE,
    note = "a flag, 0 one gear and 1 two, with the skipper's remark (stofn.athugas) a second witness: decision 241; built by sources/afli/part.R"),
  m("afli", "toga", "skge_nr", "gear_part", "grid", "type", TOWNET, code_list = "grid", zero = "value",
    note = "codes 1 and 2 are in no code table: unknown_code"),
  m("afli", "toga", "legggluggi", "gear_part", "square_window", "present", TOWNET, zero = "value"),
  m("afli", "toga", "leggpoki", "gear_part", "square_codend", "present", TOWNET, zero = "value",
    note = "a square-mesh codend ('leg bag': adb's mesh_type comment names T45 so); not a copy of legggluggi"),
  m("afli", "toga", "nafn_vorpu", "gear_part", "gear", "type_raw", TOWNET, note = "the trawl's name, as typed"),
  m("afli", "toga", "ummal", "gear_part", "net", "circumference_m", TRAWL, unit_raw = "m", to_si = 1, min_si = 2,
    max_si = 5000, note = "the circumference at the wing-belly join"),
  sensor("afli", "toga", "gerd_maelis", "fitted", "gear", NA, "gear", "sounder", "text", code_list = "sounder",
         note = "the sounder's type or make as typed: the row says it was fitted"),
  m("afli", "toga", "fermetrar", "rigging_part", "door", "area_m2", TRAWL, unit_raw = "m2", to_si = 1, min_si = 0.5,
    max_si = 40, note = paste(
      "square metres by the schema (HLERAR@FERMETRAR). Above 40 (12,264 edited, 11,149 loaded rows, 27 vessels) not m2:",
      "read so the doors weigh 44 kg per m2, against 420 elsewhere. Not square feet: none is a ft2 reading of a door",
      "the vessel logs in m2 at the same weight; 2,649 are its area with the decimal point lost (105 for 10.5), 9,119",
      "another number at the same weight, 435 at a weight it logs no area for, 57 the sentinel 999 (decision 245)")),
  m("afli", "toga", "efri_grandarar", "rigging_part", "upper_bridle", "length_m", TRAWL, unit_raw = "m", to_si = 1,
    min_si = 2, max_si = 1000),
  sensor("afli", "toga", "hoflinu_dypi", "depth", "gear", "1", "gear", "headline_sensor", "fathom or m, by record",
         placeholder = "0,1", min_si = 2, max_si = 2000,
         note = "fathoms or metres by the element sent and the loader; the sent message is read first (sources/afli/part.R)"),
  sensor("afli", "toga", "hoflinu_dypi_lok", "depth", "gear", "2", "gear", "headline_sensor", "fathom or m, by record",
         placeholder = "0,1", min_si = 2, max_si = 2000),
  temp("afli", "toga", "hoflinu_hiti", "headline", "1", "gear", "headline_sensor"),
  temp("afli", "toga", "hoflinu_hiti_lok", "headline", "2", "gear", "headline_sensor"),
  m("afli", "toga", "moskvi_gerd", "gear_part", "codend", "mesh_orientation", TOWNET, code_list = "mesh_orientation",
    zero = "value", note = "0, 45, 90 as fs_afladagbok's T0, T45, T90; 1, 3, 6, 50, 80 and others: unknown_code"),
  m("afli", "toga", "moskvi_gerd", "gear_part", "dredge", "mesh_orientation", "DRB", code_list = "mesh_orientation",
    zero = "value"),
  m("afli", "toga", "fj_byrda", "gear_part", "panel", "n", "SDN", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 10, basis = "reconstructed", note = "the Danish seine's panels, read from the values 2 and 4 (ask g)"),
  m("afli", "toga", "moskvi_vod", "gear_part", "net", "mesh_size_mm", "SDN", unit_raw = "mm", to_si = 1, min_si = 10,
    max_si = 1000, note = "the Danish seine's body mesh"),
  m("afli", "toga", "sk_rimlabil", "gear_part", "grid", "bar_spacing_mm", TOWNET, unit_raw = "mm", to_si = 1,
    min_si = 5, max_si = 300),
  m("afli", "toga", "lengd_poka", "gear_part", "codend", "length_m", TOWNET, unit_raw = "m", to_si = 1, min_si = 2,
    max_si = 200),
  m("afli", "toga", "moskvi_staerd", "gear_part", "codend", "mesh_size_mm", TOWNET, rank = 2, unit_raw = "mm",
    to_si = 1, min_si = 10, max_si = 1000, note = "the codend section's mesh: where moskvi has none"),
  m("afli", "toga", "moskvi_fj_ummali", "gear_part", "codend", "meshes_around", TOWNET, unit_raw = "meshes", to_si = 1,
    min_si = 10, max_si = 10000),
  m("afli", "toga", "moskvi2_staerd", "gear_part", "codend_2", "mesh_size_mm", TOWNET, unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000, basis = "reconstructed", note = "a second codend, read from the values (ask g)"),
  m("afli", "toga", "moskvi2_fj_ummali", "gear_part", "codend_2", "meshes_around", TOWNET, unit_raw = "meshes",
    to_si = 1, min_si = 10, max_si = 10000, basis = "reconstructed"),
  m("afli", "toga", "gerd_poka", "gear_part", "codend", "type", TOWNET, code_list = "codend_type"),
  m("afli", "toga", "fotreipi", "gear_part", "footrope", "type", TOWNET, code_list = "footrope",
    note = "a code, not a length (fishing_sample.length_fotreipi holds it as one, plan 052 §5)"),
  m("afli", "toga", "moskvi_belg_staerd", "gear_part", "belly", "mesh_size_mm", TOWNET, unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000),
  m("afli", "toga", "moskvi_staersti", "gear_part", "net", "mesh_size_max_mm", "OTM", unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 100000, basis = "reconstructed",
    note = "the pelagic trawl's largest mesh, read from the values (ask g)"),
  m("afli", "toga", "moskvi_minnsti", "gear_part", "net", "mesh_size_min_mm", "OTM", unit_raw = "mm", to_si = 1,
    min_si = 5, max_si = 1000, basis = "reconstructed"),
  temp("afli", "toga", "uppsj_hiti", "surface", "1", "vessel"),
  temp("afli", "toga", "uppsj_hiti_lok", "surface", "2", "vessel"),
  audit("afli", "toga"))

## afli: lines, nets and jigs (rafr_lineha, lineha) ----------------------------------------------------------------
afli_lineha <- bind_rows(
  key("afli", "lineha", "visir"),
  m("afli", "lineha", "onglar", "gear_part", "hook", "n", "LLS", unit_raw = "count", to_si = 1, min_si = 10,
    max_si = 5000, note = "hooks per tub"),
  m("afli", "lineha", "bjod", "rigging_part", "unit", "n", "LLS", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 300, type_fixed = "tub"),
  m("afli", "lineha", "dregin", "rigging_part", "unit", "n", "!LHM,!LLS", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 500, type_fixed = "net"),
  m("afli", "lineha", "dregin", "rigging_part", "unit", "n", "LHM", rank = 2, unit_raw = "count", to_si = 1,
    min_si = 1, max_si = 20, type_fixed = "jig", note = "the loader put FAERI@FJOLDI here on 7,968 records (the XML map)"),
  nu("afli", "lineha", "naetur", "a duration: the soak in nights, the fishing sample's"),
  m("afli", "lineha", "moskvi", "gear_part", "net", "mesh_size_mm", unit_raw = "mm", to_si = 1, min_si = 10,
    max_si = 1000, note = "millimetres: Oracle's comment and the schema say inches, the values are mm (plan 052 §2)"),
  m("afli", "lineha", "haed", "gear_part", "net", "height_meshes", unit_raw = "meshes", to_si = 1, min_si = 5,
    max_si = 500),
  m("afli", "lineha", "faeri", "rigging_part", "unit", "n", "LHM", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 20, type_fixed = "jig"),
  nu("afli", "lineha", "klst", "a duration: hours in the sea, the fishing sample's"),
  m("afli", "lineha", "beita", "gear_part", "bait", "type", "LLS", code_list = "bait"),
  m("afli", "lineha", "medal_lengd_neta", "gear_part", "net", "length_m", "!LLS", unit_raw = "m", to_si = 1,
    min_si = 20, max_si = 110, basis = "reconstructed", note = GILLNET_M),
  nu("afli", "lineha", "fj_tap_neta", "an outcome (nets lost): fishing_sample.n_lost"),
  nu("afli", "lineha", c("logn_hefst", "drattur_hefst", "drattur_lykur"), "a time (t1, t3, t4): the fishing sample's"),
  temp("afli", "lineha", "lofthiti", "air", "1", "vessel"),
  temp("afli", "lineha", "uppsjavarhiti", "surface", "1", "vessel"),
  temp("afli", "lineha", "botnhiti", "bottom", "1", "gear", note = "never sent: empty"),
  sensor("afli", "lineha", "sjolag", "sea_state", "surface", "1", NA, "observed", "code", to_si = 1, zero = "value",
         placeholder = "-1", min_si = 0, max_si = 9, code_list = "sea_state"),
  m("afli", "lineha", "beitufrakast", "gear_part", "beitufrakast", "n", unit_raw = "unknown", to_si = 1,
    flag = "meaning_unknown", note = "undocumented, meaning unknown (ask g): kept as recorded, flagged"),
  nu("afli", "lineha", "fj_fiska", "an observation of the catch (fish counted)"),
  m("afli", "lineha", "fj_kroka", "rigging_part", "hook_total", "n", "LLS", unit_raw = "count", to_si = 1,
    min_si = 10, max_si = 100000, note = "hooks in all; else tubs x hooks per tub, derived (sources/afli/part.R)"),
  nu("afli", "lineha", "fjoldi_grasleppa", "empty on every row (lumpfish counted)"),
  nu("afli", "lineha", "long_stutt", "empty on every row (a lumpfish net long or short)"),
  nu("afli", "lineha", "grasleppuhrogn", "an observation of the catch (lumpfish roe, kg), in the edited layer only"),
  audit("afli", "lineha"))

## afli: purse seine (rafr_hringn, hringn) and traps (gildra) ----------------------------------------------------------
afli_other <- bind_rows(
  key("afli", "hringn", "visir"),
  m("afli", "hringn", "l_notar", "gear_part", "seine", "length_m", unit_raw = "fathom", to_si = FATHOM, min_si = 50,
    max_si = 5000, note = "fathoms throughout: sent so before 2011, converted by the loader after (the XML map)"),
  m("afli", "hringn", "d_notar", "gear_part", "seine", "height_m", unit_raw = "fathom", to_si = FATHOM, min_si = 10,
    max_si = 1000),
  m("afli", "hringn", "moskvi", "gear_part", "seine", "mesh_size_mm", unit_raw = "mm", to_si = 1, min_si = 5,
    max_si = 1000),
  nu("afli", "hringn", "kast_nr", "the set's number in the trip: an operation"),
  nu("afli", "hringn", "klukkan", "a time: the set's clock, the fishing sample's"),
  sensor("afli", "hringn", "sjolag", "sea_state", "surface", "1", NA, "observed", "code", to_si = 1, zero = "value",
         placeholder = "-1", min_si = 0, max_si = 9, code_list = "sea_state"),
  nu("afli", "hringn", "athskipst", "free text: staging/afli/note.parquet (decision 213)"),
  audit("afli", "hringn"),
  key("afli", "gildra", "visir"),
  m("afli", "gildra", "gildrur", "rigging_part", "unit", "n", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 5000, type_fixed = "trap"),
  nu("afli", "gildra", "klst", "a duration: hours in the sea, the fishing sample's"))

## afli: the station (rafr_stofn, stofn) -------------------------------------------------------------------------------
afli_stofn <- bind_rows(
  key("afli", "stofn", "visir"),
  sensor("afli", "stofn", "vindatt", "wind_direction", "air", "1", NA, "unknown", "degree", to_si = 1, zero = "value",
         min_si = 0, max_si = 360,
         note = "0 with no wind (speed 0, -1 or none, and force 0 or none) is calm: placeholder (sources/afli/part.R); 990 and above a sentinel"),
  sensor("afli", "stofn", "vindstig", "wind_force", "air", "1", NA, "observed", "Beaufort", to_si = 1, zero = "value",
         min_si = 0, max_si = 12, note = "Beaufort: its median m_sek follows the scale (decision 244)"),
  sensor("afli", "stofn", "m_sek", "wind_speed", "air", "1", NA, "unknown", "m/s", to_si = 1, zero = "value",
         placeholder = "-1", min_si = 0, max_si = 40, note = "above 40 m/s is beyond Beaufort 12 (32.7 m/s and up)"),
  m("afli", "stofn", "athugas", "rigging_part", "rig", "type", special = TRUE,
    note = "the skipper's remark: its twenties are the rig (20-34 twin, 40-54 pair), the rest the mishap (fishing_sample.mishap); decision 241"),
  nu("afli", "stofn", c("dypi", "dypi_lok"), "water depth: the station's z1, z2, its one home (TODO 113)"),
  nu("afli", "stofn", c("skipnr", "veidarf", "ahofn", "vedags", "breidd", "lengd", "reitur", "smareitur", "orreitur",
                        "ldags", "lhofn", "veman", "skiki", "fj_reitur", "fj_skiki", "breidd_lok", "lengd_lok",
                        "breytt_eftir_lokun", "pos_lon", "pos_lat", "aaetladur_afli"),
     "a station or trip field: sources/afli/convert.R's"),
  nu("afli", "stofn", "uppruni", "fs_afli's copy only: where the station came from, sources/afli/convert.R drops it"),
  nu("afli", "stofn", "aths_texti", "free text: staging/afli/note.parquet (decision 213)"),
  nu("afli", "stofn", c("xml_faerslu_visir", "xml_faerslu_version", "xml_sending_visir", "xml_londun_sending_visir",
                        "hledsla_dags"), "the loader's keys to the sent message, and its load date (plan 037)"),
  nu("afli", "stofn", "eytt", "the deletion flag: station.eytt_deleted"),
  nu("afli", "stofn", "er_lesid", "fs_afli's copy only: 1 on 98,248 rows, a loader's mark (read on), not a value of the haul"),
  audit("afli", "stofn"))

## afli: the sent layer (staging/afli_sent/fishing_sample.parquet; plan 037) ---------------------------------------
# Only what the loader never kept is read from it (the XML map): its other columns hold values rafr_ holds too.
afli_sent <- bind_rows(
  m("afli", "sent", "hook_type", "gear_part", "hook", "type", "LLS", code_list = "hook_type", note = "KROKAR@GERD"),
  m("afli", "sent", "hook_size", "gear_part", "hook", "size", "LLS", note = "KROKAR@STAERD, the hook's number"),
  m("afli", "sent", "hand_baited", "gear_part", "hand_baiting", "present", "LLS", zero = "value", note = "HANDBEITT"),
  m("afli", "sent", "n_per_unit", "gear_part", "hook", "n", "LHM", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 50, note = "FAERI@FJ_KROKA, hooks per jig line"),
  m("afli", "sent", "g_width", "gear_part", "dredge", "width_m", "DRB", unit_raw = "unknown",
    note = "PLOG_STAERD@BREIDD, feet by the schema; 5 records sent it, all as loaded"),
  m("afli", "sent", "g_height", "gear_part", "dredge", "height_m", "DRB", unit_raw = "unknown"),
  m("afli", "sent", "g_length", "gear_part", "dredge", "length_m", "DRB", unit_raw = "unknown"),
  sensor("afli", "sent", "bottom_type", "bottom_type", "bottom", "1", NA, "observed", "code", to_si = 1,
         code_list = "bottom_type", gears = "DRB", note = "BOTNGERD"))

## fs_afladagbok -------------------------------------------------------------------------------------------------------
fs <- "fs_afladagbok"
fs_map <- bind_rows(
  key(fs, "ws_dragnot_varpa", "veidi_id"),
  m(fs, "ws_dragnot_varpa", "hoflina_lengd", "gear_part", "headline", "length_m", TOWNET, unit_raw = "ft",
    to_si = FOOT, min_si = 3, max_si = 3000, note = "feet: the comment, and plan 052 §2's account (a, b)"),
  m(fs, "ws_dragnot_varpa", "moskvi_staerd_poki", "gear_part", "codend", "mesh_size_mm", TOWNET, unit_raw = "mm",
    to_si = 1, min_si = 10, max_si = 1000),
  m(fs, "ws_dragnot_varpa", "tegund_skilju", "gear_part", "grid", "type", TOWNET, code_list = "grid"),
  m(fs, "ws_dragnot_varpa", "hlerar_kg", "rigging_part", "door", "weight_kg", TRAWL, unit_raw = "kg", to_si = 1,
    min_si = 20, max_si = 9000),
  m(fs, "ws_dragnot_varpa", "grandarar_lengd", "rigging_part", "sweep", "length_m", TOWNET, unit_raw = "fathom",
    to_si = FATHOM, min_si = 2, max_si = 1000, note = "fathoms: the comment, and plan 052 §2's account (a, b)"),
  m(fs, "ws_dragnot_varpa", "toglengd", "rigging_part", "rope", "length_m", "SDN", unit_raw = "fathom", to_si = FATHOM,
    min_si = 20, max_si = 20000),
  m(fs, "ws_dragnot_varpa", "moskvi_fj_ummali", "gear_part", "codend", "meshes_around", TOWNET, unit_raw = "meshes",
    to_si = 1, min_si = 10, max_si = 10000,
    note = "the codend's: its values (median 150) are afli's codend meshes around (200), not the net's (2,250), whatever the comment says"),
  m(fs, "ws_dragnot_varpa", "tvo_veidarf", "rigging_part", "rig", "n", TRAWL, unit_raw = "count", to_si = 1,
    min_si = 1, max_si = 3),
  m(fs, "ws_dragnot_varpa", "tvo_veidarf", "rigging_part", "rig", "type", TRAWL, code_list = "rig"),
  m(fs, "ws_dragnot_varpa", "legggluggi", "gear_part", "square_window", "present", TOWNET, zero = "value"),
  m(fs, "ws_dragnot_varpa", "leggpoki", "gear_part", "codend", "mesh_orientation", TOWNET,
    code_list = "mesh_orientation", note = "T0, T45, T90, in a column named for the square-mesh codend"),
  key(fs, "ws_plogur", "veidi_id"),
  m(fs, "ws_plogur", "thyngd", "gear_part", "dredge", "weight_kg", "DRB", unit_raw = "kg", to_si = 1, min_si = 50,
    max_si = 30000, note = "10 kg on the ocean quahog dredge of 3,979 hauls: implausible"),
  m(fs, "ws_plogur", "breidd", "gear_part", "dredge", "width_m", "DRB", unit_raw = "unknown",
    note = paste("feet by the comment; one vessel per kind, constants: 3 x 3 x 3 (ocean quahog; 3 is the app's",
                 "default, decision 170) and 2.5 x 3.6 x 0.2 (sea urchin, metres: 0.2 ft would be 6 cm).", DREDGE_FT)),
  m(fs, "ws_plogur", "lengd", "gear_part", "dredge", "length_m", "DRB", unit_raw = "unknown"),
  m(fs, "ws_plogur", "haed", "gear_part", "dredge", "height_m", "DRB", unit_raw = "unknown"),
  m(fs, "ws_plogur", "moskvi", "gear_part", "dredge", "mesh_size_mm", "DRB", unit_raw = "mm", to_si = 1, min_si = 10,
    max_si = 1000),
  m(fs, "ws_plogur", "tvo_veidarf", "rigging_part", "rig", "n", "DRB", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 3),
  m(fs, "ws_plogur", "tvo_veidarf", "rigging_part", "rig", "type", "DRB", code_list = "rig"),
  m(fs, "ws_plogur", "leggpoki", "gear_part", "dredge", "mesh_orientation", "DRB", code_list = "mesh_orientation"),
  m(fs, "ws_plogur", "gerd", "gear_part", "dredge", "type", "DRB", code_list = "dredge_type"),
  key(fs, "ws_linanethandf", "veidi_id"),
  m(fs, "ws_linanethandf", "fj_kroka", "rigging_part", "hook_total", "n", "!LHM", unit_raw = "count", to_si = 1,
    min_si = 10, max_si = 100000),
  m(fs, "ws_linanethandf", "fj_kroka", "rigging_part", "hook_total", "n", "LHM", unit_raw = "count", to_si = 1,
    flag = "per_jig_or_total",
    note = "on jigs per jig line on some records and in all on others, mixed within every app (decision 244)"),
  m(fs, "ws_linanethandf", "fj_dreginna_neta", "rigging_part", "unit", "n", "!LHM", unit_raw = "count", to_si = 1,
    min_si = 1, max_si = 500, type_fixed = "net"),
  m(fs, "ws_linanethandf", "moskvi_staerd", "gear_part", "net", "mesh_size_mm", unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000),
  m(fs, "ws_linanethandf", "moskvi_haed", "gear_part", "net", "height_meshes", unit_raw = "meshes", to_si = 1,
    min_si = 5, max_si = 500),
  m(fs, "ws_linanethandf", "medal_lengd_neta", "gear_part", "net", "length_m", unit_raw = "m", to_si = 1,
    min_si = 20, max_si = 110, basis = "reconstructed",
    note = paste("the comment's unit brackets are empty;", GILLNET_M)),
  m(fs, "ws_linanethandf", "fj_faera", "rigging_part", "unit", "n", "LHM", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 20, type_fixed = "jig"),
  key(fs, "ws_gildra", "veidi_id"),
  m(fs, "ws_gildra", "fj_gildra", "rigging_part", "unit", "n", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 5000, type_fixed = "trap"),
  m(fs, "ws_gildra", "gerd", "gear_part", "trap", "type", code_list = "trap_type"),
  key(fs, "ws_hringn", "veidi_id"),
  m(fs, "ws_hringn", "lengd_notu", "gear_part", "seine", "length_m", unit_raw = "fathom", to_si = FATHOM, min_si = 50,
    max_si = 5000),
  m(fs, "ws_hringn", "dypt_notu", "gear_part", "seine", "height_m", unit_raw = "fathom", to_si = FATHOM, min_si = 10,
    max_si = 1000),
  m(fs, "ws_hringn", "moskvi_staerd", "gear_part", "seine", "mesh_size_mm", unit_raw = "mm", to_si = 1, min_si = 5,
    max_si = 1000),
  m(fs, "ws_hringn", "tegund_notar", "gear_part", "seine", "type", code_list = "seine_type"),
  key(fs, "ws_kofun", "veidi_id"),
  m(fs, "ws_kofun", "fj_kafara", "rigging_part", "unit", "n", unit_raw = "count", to_si = 1, min_si = 1, max_si = 20,
    type_fixed = "diver"),
  key(fs, "ws_veidi", "id"),
  m(fs, "ws_veidi", "veidarfaeri_efni", "gear_part", "gear", "material", note = "as typed (151 spellings)"),
  nu(fs, "ws_veidi", c("upphaf_dypi", "lok_dypi"), "water depth: the station's z1, z2, its one home"),
  nu(fs, "ws_veidi", "fj_tapadra_veidarfaera", "an outcome (gear lost): fishing_sample.n_lost"),
  nu(fs, "ws_veidi", "athugasemd_txt", "free text: staging/fs_afladagbok/note.parquet (decision 213)"),
  nu(fs, "ws_veidi", c("veidiferd_id", "veidarfaeri_id", "upphaf_timi", "lok_timi", "milli_timi", "upphaf_breidd",
                       "upphaf_lengd", "lok_breidd", "lok_lengd", "breytt", "skraningartimi", "snt"),
     "a station field: sources/fs_afladagbok/convert.R's"),
  nu(fs, "fishing_spot", "*",
     "the tour app (plan 019): its stations are not in the merge, and its ids are not ws_veidi's (29,195 coincide by number, none in the same trip or at the same time)"))

## adb ------------------------------------------------------------------------------------------------------------------
# adb copies fs_afladagbok's gear tables field for field (decision 171): equal on every shared station but where adb
# writes 0 for fs's empty (net mesh, square window) and the dredge weight it lost (decision 244). Its units are fs's.
adb_map <- bind_rows(
  key("adb", "trawl_and_seine_net", "fishing_station_id"),
  m("adb", "trawl_and_seine_net", "headline", "gear_part", "headline", "length_m", TOWNET, unit_raw = "ft",
    to_si = FOOT, min_si = 3, max_si = 3000),
  m("adb", "trawl_and_seine_net", "bridle", "rigging_part", "sweep", "length_m", TOWNET, unit_raw = "fathom",
    to_si = FATHOM, min_si = 2, max_si = 1000),
  m("adb", "trawl_and_seine_net", "mesh_size", "gear_part", "codend", "mesh_size_mm", TOWNET, unit_raw = "mm",
    to_si = 1, min_si = 10, max_si = 1000),
  m("adb", "trawl_and_seine_net", "mesh_type", "gear_part", "codend", "mesh_orientation", TOWNET,
    code_list = "mesh_orientation"),
  m("adb", "trawl_and_seine_net", "grid_no", "gear_part", "grid", "type", TOWNET, code_list = "grid",
    note = "a name, not a number, despite the column's"),
  m("adb", "trawl_and_seine_net", "square_window", "gear_part", "square_window", "present", TOWNET,
    note = "0 is empty: adb writes it where fs_afladagbok holds none (102 of 217,569 shared stations hold a value)"),
  m("adb", "trawl_and_seine_net", "otterboard_weight", "rigging_part", "door", "weight_kg", TRAWL, unit_raw = "kg",
    to_si = 1, min_si = 20, max_si = 9000),
  m("adb", "trawl_and_seine_net", "circumference_mesh_number", "gear_part", "codend", "meshes_around", TOWNET,
    unit_raw = "meshes", to_si = 1, min_si = 10, max_si = 10000),
  m("adb", "trawl_and_seine_net", "rope", "rigging_part", "rope", "length_m", "SDN", unit_raw = "fathom",
    to_si = FATHOM, min_si = 20, max_si = 20000),
  m("adb", "trawl_and_seine_net", "two_fg", "rigging_part", "rig", "n", TRAWL, unit_raw = "count", to_si = 1,
    min_si = 1, max_si = 3),
  m("adb", "trawl_and_seine_net", "two_fg", "rigging_part", "rig", "type", TRAWL, code_list = "rig"),
  key("adb", "dredge", "fishing_station_id"),
  m("adb", "dredge", "dredge_no", "gear_part", "dredge", "type", "DRB", code_list = "dredge_type"),
  m("adb", "dredge", "width", "gear_part", "dredge", "width_m", "DRB", unit_raw = "unknown",
    note = "fs_afladagbok's values (its ws_plogur.breidd)"),
  m("adb", "dredge", "length", "gear_part", "dredge", "length_m", "DRB", unit_raw = "unknown"),
  m("adb", "dredge", "height", "gear_part", "dredge", "height_m", "DRB", unit_raw = "unknown"),
  m("adb", "dredge", "weight", "gear_part", "dredge", "weight_kg", "DRB", unit_raw = "kg", to_si = 1, min_si = 50,
    max_si = 30000, note = "empty: lost in the copy from fs_afladagbok"),
  m("adb", "dredge", "two_dredges", "rigging_part", "rig", "n", "DRB", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 3),
  m("adb", "dredge", "two_dredges", "rigging_part", "rig", "type", "DRB", code_list = "rig"),
  m("adb", "dredge", "mesh_size", "gear_part", "dredge", "mesh_size_mm", "DRB", unit_raw = "mm", to_si = 1,
    min_si = 10, max_si = 1000),
  m("adb", "dredge", "mesh_type", "gear_part", "dredge", "mesh_orientation", "DRB", code_list = "mesh_orientation",
    note = "empty"),
  key("adb", "line_and_net", "fishing_station_id"),
  m("adb", "line_and_net", "hooks", "rigging_part", "hook_total", "n", "!LHM", unit_raw = "count", to_si = 1,
    min_si = 10, max_si = 100000),
  m("adb", "line_and_net", "hooks", "rigging_part", "hook_total", "n", "LHM", unit_raw = "count", to_si = 1,
    flag = "per_jig_or_total", note = "as fs_afladagbok's fj_kroka"),
  m("adb", "line_and_net", "nets", "rigging_part", "unit", "n", "!LHM", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 500, type_fixed = "net"),
  m("adb", "line_and_net", "mesh_size", "gear_part", "net", "mesh_size_mm", unit_raw = "mm", to_si = 1, min_si = 10,
    max_si = 1000, note = "0 is empty: adb writes it where fs_afladagbok holds none"),
  m("adb", "line_and_net", "net_height_meshes", "gear_part", "net", "height_meshes", unit_raw = "meshes", to_si = 1,
    min_si = 5, max_si = 500),
  m("adb", "line_and_net", "net_length", "gear_part", "net", "length_m", unit_raw = "m", to_si = 1, min_si = 20,
    max_si = 110, basis = "reconstructed", note = paste("metres by adb's comment, its values fs_afladagbok's;", GILLNET_M)),
  m("adb", "line_and_net", "pole_and_lines", "rigging_part", "unit", "n", "LHM", unit_raw = "count", to_si = 1,
    min_si = 1, max_si = 20, type_fixed = "jig"),
  key("adb", "trap", "fishing_station_id"),
  m("adb", "trap", "trap_no", "gear_part", "trap", "type", code_list = "trap_type", note = "empty"),
  m("adb", "trap", "number_of_traps", "rigging_part", "unit", "n", unit_raw = "count", to_si = 1, min_si = 1,
    max_si = 5000, type_fixed = "trap"),
  key("adb", "surrounding_net", "fishing_station_id"),
  m("adb", "surrounding_net", "surrounding_net_no", "gear_part", "seine", "type", code_list = "seine_type",
    zero = "value"),
  m("adb", "surrounding_net", "length", "gear_part", "seine", "length_m", unit_raw = "fathom", to_si = FATHOM,
    min_si = 50, max_si = 5000, note = "fathoms, as fs_afladagbok's lengd_notu: equal on all 1,276 shared stations"),
  m("adb", "surrounding_net", "height", "gear_part", "seine", "height_m", unit_raw = "fathom", to_si = FATHOM,
    min_si = 10, max_si = 1000),
  m("adb", "surrounding_net", "mesh_size", "gear_part", "seine", "mesh_size_mm", unit_raw = "mm", to_si = 1,
    min_si = 5, max_si = 1000),
  key("adb", "diving", "fishing_station_id"),
  m("adb", "diving", "divers", "rigging_part", "unit", "n", unit_raw = "count", to_si = 1, min_si = 1, max_si = 20,
    type_fixed = "diver", note = "no rows"),
  key("adb", "fishing_station", "fishing_station_id"),
  m("adb", "fishing_station", "fishing_gear_material", "gear_part", "gear", "material", note = "as typed"),
  nu("adb", "fishing_station", c("depth", "depth_end"), "water depth: the station's z1, z2, its one home"),
  nu("adb", "fishing_station", "lost_fishing_gear", "an outcome (gear lost): fishing_sample.n_lost"),
  nu("adb", "fishing_station", "note", "free text: staging/adb/note.parquet (decision 213)"),
  nu("adb", "fishing_station", c("fishing_trip_id", "fishing_gear_no", "fishing_start", "fishing_end", "latitude",
                                 "longitude", "latitude_end", "longitude_end", "location", "tow_start", "modified",
                                 "registered"),
     "a station field: sources/adb/convert.R's"))

gear_part_map <- bind_rows(afli_toga, afli_lineha, afli_other, afli_stofn, afli_sent, fs_map, adb_map) |>
  mutate(map_id = row_number(), .before = 1)
stopifnot(
  "a column is mapped twice to one part and measure on one gear" =
    !anyDuplicated(gear_part_map[c("schema", "table", "column", "gears", "part", "measure")]),
  "a used column names no part or quantity" =
    with(gear_part_map, all(use %in% c("key", "not_used") | !is.na(part) | !is.na(quantity))),
  "a not-used column gives no reason" = with(gear_part_map, all(use != "not_used" | !is.na(note))))

# Code lists -------------------------------------------------------------------
rd <- function(schema, table) duckdbfs::open_dataset(fd_raw("oracle", schema, paste0(table, ".parquet"))) |> collect()
lst <- function(list, schema, code, type, label) tibble(list, schema, code = as.character(code), type, label)
slug <- function(code, slugs) unname(slugs[as.character(code)])
fr <- rd("afli", "rafr_stofn_fotreipi")
gp <- rd("afli", "rafr_stofn_gerd_poka")
sk <- rd("afli", "rafr_stofn_skiljugerd")
gk <- rd("afli", "rafr_stofn_gerd_kroka")
GRID <- c("Engin skilja" = "none", "Seiðaskilja" = "juvenile", "Smárækjuskilja/Seiðaskilja" = "small_shrimp_juvenile",
          "Fiskiskilja" = "fish", "Meðaflaskilja" = "bycatch", "Humarskilja" = "nephrops")
fs_grid <- c("Engin skilja", "Seiðaskilja", "Smárækjuskilja/Seiðaskilja", "Fiskiskilja", "Meðaflaskilja")
DREDGE <- c("Hörpudisksplógur" = "scallop", "Kúffisksplógur" = "ocean_quahog", "Ígulkeraplógur" = "sea_urchin",
            "Sæbjúguplógur" = "sea_cucumber")
TRAP   <- c("Krabbagildra" = "crab", "Beitukóngsgildra" = "whelk")
SEINE  <- c("Síldarnót" = "herring", "Loðnunót" = "capelin", "Óþekkt" = "unknown")
fs_dr <- rd("fs_afladagbok", "ws_stofn_gerd_plogs"); adb_dr <- rd("adb", "dredge_type")
fs_tr <- rd("fs_afladagbok", "ws_stofn_tegund_gildru"); adb_tr <- rd("adb", "trap_type")
fs_se <- rd("fs_afladagbok", "ws_stofn_tegund_notar"); adb_se <- rd("adb", "surrounding_net_type")
bait  <- rd("afli", "rafr_stofn_beita_t")
sea   <- rd("afli", "rafr_stofn_sjolag")
bot   <- rd("afli", "rafr_stofn_botngerd")

gear_part_code <- bind_rows(
  lst("footrope", "afli", fr$id, slug(fr$id, c("1" = "rockhopper", "2" = "rope", "3" = "chain", "4" = "discs",
                                                "5" = "steel_bobbins", "6" = "rubber_bobbins", "999" = "other")),
      fr$heiti),
  lst("codend_type", "afli", gp$id, slug(gp$id, c("1" = "capelin", "2" = "herring", "3" = "blue_whiting",
                                                  "4" = "speni", "5" = "sekkur", "6" = "redfish", "999" = "other")),
      gp$heiti),
  lst("grid", "afli", sk$id, unname(GRID[sk$heiti]), sk$heiti),
  lst("grid", "fs_afladagbok", fs_grid, unname(GRID[fs_grid]), fs_grid),
  lst("grid", "adb", fs_grid, unname(GRID[fs_grid]), fs_grid),
  lst("hook_type", "afli", gk$id, slug(gk$id, c("1" = "j", "2" = "ez", "3" = "ez_w", "4" = "o", "5" = "wide_gap",
                                                "6" = "jig", "7" = "halibut", "999" = "other")), gk$heiti),
  # Bait and the bottom: one source each, so the list's code is afli's own, the label naming it
  lst("bait", "afli", bait$id, as.character(bait$id), bait$data),
  lst("bottom_type", "afli", bot$id, as.character(bot$id), bot$heiti),
  lst("sea_state", "afli", sea$id, as.character(sea$id), sea$skyring),
  lst("mesh_orientation", "afli", c(0, 45, 90), c("T0", "T45", "T90"), c("0", "45", "90")),
  lst("mesh_orientation", "fs_afladagbok", c("T0", "T45", "T90"), c("T0", "T45", "T90"), c("T0", "T45", "T90")),
  lst("mesh_orientation", "adb", c("T0", "T45", "T90"), c("T0", "T45", "T90"),
      c("T0: side", "T45: leg bag", "T90: cross")),
  lst("sounder", "afli", c("SONAR", "Furuno", "Furano", "marport", "Marport", "MARPORT", "scanmar"),
      c("sonar", "furuno", "furuno", "marport", "marport", "marport", "scanmar"),
      c("SONAR", "Furuno", "Furano", "marport", "Marport", "MARPORT", "scanmar")),
  lst("yes_no", "afli", c("j", "n"), c("1", "0"), c("já", "nei")),
  lst("dredge_type", "fs_afladagbok", fs_dr$id, unname(DREDGE[fs_dr$heiti]), fs_dr$heiti),
  lst("dredge_type", "adb", adb_dr$dredge_no, unname(DREDGE[adb_dr$dredge_name]), adb_dr$dredge_name),
  lst("trap_type", "fs_afladagbok", fs_tr$id, unname(TRAP[fs_tr$heiti]), fs_tr$heiti),
  lst("trap_type", "adb", adb_tr$trap_no, unname(TRAP[adb_tr$trap_name]), adb_tr$trap_name),
  lst("seine_type", "fs_afladagbok", fs_se$id, unname(SEINE[fs_se$heiti]), fs_se$heiti),
  lst("seine_type", "adb", adb_se$surrounding_net_no, unname(SEINE[adb_se$surrounding_net_name]),
      adb_se$surrounding_net_name),
  # Made by the staging scripts from a count, not read from a source's list
  lst("rig", "fs_afladagbok", 1:3, c("single", "twin", "triple"), c("1", "2", "3")),
  lst("rig", "adb", 1:3, c("single", "twin", "triple"), c("1", "2", "3")))
stopifnot("a code list entry has no type" = !anyNA(gear_part_code$type),
          "a code is listed twice" = !anyDuplicated(gear_part_code[c("list", "schema", "code")]),
          "a mapped code list does not exist" =
            all(na.omit(gear_part_map$code_list) %in% gear_part_code$list))

# Export -------------------------------------------------------------------------------------------------------------
inputs <- c(fd_raw("oracle", "afli", paste0("rafr_stofn_", c("fotreipi", "gerd_poka", "skiljugerd", "gerd_kroka",
                                                              "beita_t", "sjolag", "botngerd"), ".parquet")),
            fd_raw("oracle", "fs_afladagbok", paste0("ws_stofn_", c("gerd_plogs", "tegund_gildru", "tegund_notar"),
                                                     ".parquet")),
            fd_raw("oracle", "adb", paste0(c("dredge_type", "trap_type", "surrounding_net_type"), ".parquet")))
gear_part_map  |> write_curated(fd_curated("reference", "gear_part_map.parquet"),  inputs = inputs)
gear_part_code |> write_curated(fd_curated("reference", "gear_part_code.parquet"), inputs = inputs)
