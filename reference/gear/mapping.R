# Gear vocabulary — hand-maintained
# Side: preprocessing (reference). See plan 014.
# Input:  (none)
# Output: data/gear/gear_mapping.parquet

# Notes on gear codes (gid) by data-source (schema):
#  schema afli:         uses historical gear code values (version == "old" below)
#  schema fs_afladagbok: uses the new code values       (version == "new" below)
#  schema adb:          the GEAR schema's codes (GEAR.FISHING_GEAR), the historical ones and a few of its
#                       own (51 crab trap, 53 every dredge, 124, 125); adb's table fishing_gear maps them to
#                       the new (FS) codes and agrees with `map` below on all 16 codes they share
#                       (dump of 2026-10-16, checked by Claude, not by a person). curate/corrections/
#                       logbook_gear.R reads that table (decision 154)

# NOTES:
# * Downstream analysis
#  * The primary gear code used will be version "new"
#. * The station tables derived will though have both gear codes. Use name:
#.   * "gid" representing the new version
#.   * "gid_old" representing the old code
#
# TODO:
#  * Add criterion for maximum duration
#  * Add criterion for maximum distance

library(tidyverse)
library(nanoparquet)


asfis <- read_parquet(fd_raw("oracle", "asfis", "asfis.parquet")) |> rename(latin = scientific_name)
# create table -----------------------------------------------------------------








# The `map` column is a one-way canonical lookup between versions:
#   For "new" rows: map = corresponding old gid
#   For "old" rows: map = corresponding new gid
# The mapping is many-to-one in both directions — the old schema used more
# granular sub-types that collapse to fewer new codes (e.g. three mesh sizes of
# seine net → one "Dragnót"; five midwater trawl types → one "Flotvarpa").
# Consequence: round-trips old → new → old and new → old → new are lossy for
# the collapsed gears; the reverse lookup always returns the canonical
# representative, not the original sub-type.
# "target2" is my own attempt to create target code that may conform to the
# icelandic fisheries. Code is partially based on the FAO asfis code system and
# also some creative thinking.
gear_mapping <-
  tribble(
   ~version,    ~gid,         ~veiðarfæri,  ~map,  ~gear, ~target, ~target2,
      "new",       1,      "Skötuselsnet",    91,   "GNS",  "DEF",  "MON",
      "new",       2,      "Þorskfisknet",     2,   "GNS",  "DEF",  "GAD",
      "new",       3,      "Grásleppunet",    25,   "GNS",  "DEF",  "LUM",
      "new",       4,       "Rauðmaganet",    29,   "GNS",  "DEF",  "LUM",
      "new",       5,            "Reknet",    11,   "GND",  "SPF",  "SPF",
      "new",       6,         "Botnvarpa",     6,   "OTB",  "DEF",  "DEF",
      "new",       7,        "Humarvarpa",     9,   "OTB",  "CRU",  "NEP",
      "new",       8,        "Rækjuvarpa",    14,   "OTB",  "CRU",  "SHR",
      "new",       9,         "Flotvarpa",     7,   "OTM",  "SPF",  "SPF",
      "new",      10,              "Nót",     12,    "PS",  "SPF",  "SPF",
      "new",      11,          "Dragnót",      5,   "SDN",  "DEF",  "DEF",
      "new",      12,             "Lína",      1,   "LLS",  "DEF",  "DEF",
      "new",      13,   "Landbeitt lína",      1,   "LLS",  "DEF",  "DEF",
      "new",      14,         "Handfæri",      3,   "LHM",  "DEF",  "DEF",
      "new",      15,           "Plógur",     15,   "DRB",  "DES",  "DES",
      "new",      16,           "Gildra",     17,   "FPO",  "DEF",  "DEF",
      "new",      17,     "Annað - Hvað",     99,   "MIS",  "DWF",  "DWF",
      "new",      18,         "Eldiskví",     NA,      NA,     NA,     NA,
      "new",      19,         "Sjóstöng",     45,   "LHP",  "FIF",  "FIF",
      "new",      20,    "Kræklingalína",     42,      NA,     NA,     NA,
      "new",      21,        "Línutrekt",      1,   "LLS",  "DEF",  "DEF",
      "new",      22,       "Grálúðunet",     92,   "GNS",  "DEF",  "GHL",
      "new",      23,           "Kafari",     41,   "DIV",  "DES",  "DES",
      "new",      24,     "Sláttuprammi",     NA,   "HMS",  "SWD",  "SWD",
      "new",      25,       "Þaraplógur",     NA,   "DRB",  "SWD",  "KEL",
      "old",       1,             "Lína",     12,   "LLS",  "DEF",  "DEF",
      "old",       2,              "Net",      2,   "GNS",  "DEF",  "DEF",
      "old",       3,         "Handfæri",     14,   "LHM",  "DEF",  "DEF",
      "old",       4,         "Þorsknót",     NA,      NA,     NA,     NA,
      "old",       5,   "Dragnót 135 mm",     11,    "SDN", "DEF",  "DEF",
      "old",       6,        "Botnvarpa",      6,   "OTB",  "DEF",  "DEF",
      "old",       7,        "Flotvarpa",      9,   "OTM",  "SPF",  "SPF",
      "old",       8,   "Spærlingsvarpa",      9,   "OTM",  "SPF",  "XXX",
      "old",       9,       "Humarvarpa",      7,   "OTB",  "CRU",  "NEP",
      "old",      10,        "Síldarnót",     10,    "PS",  "SPF",  "HER",
      "old",      11,           "Reknet",      5,   "GND",  "SPF",  "SPF",
      "old",      12,         "Loðnunót",     10,    "PS",  "SPF",  "CAP",
      "old",      13,    "Loðnuflotvarpa",     9,   "OTM",  "SPF",  "CAP",
      "old",      14,        "Rækjuvarpa",     8,   "OTB",  "CRU",  "SHR",
      "old",      15,   "Hörpudiskplógur",    15,   "DRB",  "MOL",  "SCL",
      "old",      16,       "Grálúðulína",    12,   "LLS",  "DEF",  "GHL",
      "old",      17,       "Þorskgildra",    16,   "FPO",  "DEF",  "GAD",
      "old",      18,      "Krabbagildra",    16,   "FPO",  "CRU",  "CRB",
      "old",      19,     "Gulllaxavarpa",     9,   "OTM",  "SPF",  "ARG",
      "old",      20,   "Ýmis veiðarfæri",    17,   "MIS",  "DWF",  "DWF",
      "old",      21,  "Síldar-/kolmunnaflotvarpa",     9,   "OTM",  "SPF", "SPF",
      "old",      25,      "Grásleppunet",     3,   "GNS",  "DEF",  "LUM",
      "old",      26,    "Dragnót 120 mm",    11,   "SDN",  "DEF",  "DEF",
      "old",      29,       "Rauðmaganet",     4,   "GNS",  "DEF",  "LUM",
      "old",      35,    "Dragnót 155 mm",    11,    "SDN", "DEF",  "DEF",
      # 38's target (ARI, quahog) does not hold for afli's 38 in 2017-18: the in-house gear edits made it the
      # dredge for sea cucumber (14,696 stations), sea urchin (832) and whelk (787), where the list has 40 and
      # 39 (archive/2026-10-afli-layers, edits_gear; measured by Claude, not checked by a person)
      "old",      38,    "Kúffisksplógur",    15,   "DRB",  "MOL",  "ARI",
      "old",      39,  "Beitukóngsgildra",    16,   "FPO",  "MOL",  "WHL",
      "old",      40,    "Ígulkeraplógur",    15,   "DRB",  "DES",  "ECH",
      "old",      41,    "Ígulkerakafari",    23,   "DIV",  "DES",  "ECH",
      "old",      42,     "Kræklingalína",    20,      NA,     NA,     NA,
      "old",      45,          "Sjóstöng",    19,    "LHP",  "FIF", "FIF",
      "old",      91,       "Skötuselsnet",    1,    "GNS",  "DEF",  "MON",
      "old",      92,         "Grálúðunet",   22,    "GNS",  "DEF",  "GHL",
      "old",      99,  "Óskráð veiðarfæri",   17,    "MIS",  "DWF",  "DWF") |>
  mutate(gid = as.integer(gid),
         map = as.integer(map))

# check validity ---------------------------------------------------------------
gear_mapping |>
  select(gear, target) |>
  distinct() |>
  filter(!is.na(gear)) |>
  mutate(
    v_gear =
      case_when(gear %in% icesVocab::getCodeList("GearType")$Key ~ TRUE,
                .default = FALSE),
    v_target =
      case_when(target %in% icesVocab::getCodeList("TargetAssemblage")$Key ~ TRUE,
                .default = FALSE),
    v_met5 =
      case_when(paste0(gear, "_", target) %in% icesVocab::getCodeList("Metier5_FishingActivity")$Key ~ TRUE,
                .default = FALSE)
    #v_met6 =
    #  case_when(met6 %in% icesVocab::getCodeList("Metier6_FishingActivity")$Key ~ TRUE,
    #            .default = FALSE)
  ) |>
  filter(!v_gear | !v_target | !v_met5) |>
  knitr::kable(caption = "Problems with gear and target not in ICES vocabulary, but met5 and met6 considered valid.")
gear_mapping |>
  write_curated(fd_curated("reference", "gear.parquet"), inputs = fd_raw("oracle", "asfis", "asfis.parquet"))
# check: have I captured all gears in the logbook data? ------------------------
read_parquet(fd_raw("oracle", "afli", "stofn.parquet")) |>
  count(gid = veidarf) |>
  left_join(gear_mapping |> filter(version == "old")) |>
  knitr::kable()
read_parquet(fd_raw("oracle", "fs_afladagbok", "ws_veidi.parquet")) |>
  count(gid = veidarfaeri_id) |>
  left_join(gear_mapping |> filter(version == "new")) |>
  knitr::kable()

