# The Icelandic MMSI archive: who held each MMSI, and when, rebuilt from every source we hold (plan 016 §4 step 1).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  raw/mmsi/*.xlsx                        the Fjarskiptastofa lists, dated by file name; a byte-identical copy under
#                                                another name is read once
#         raw/oracle/ops_einarhj/{vessel_mmsi_20190627,_20201215,_20220405,mmsi_icelandic_registry}.parquet
#                                                the Oracle snapshots behind the old archive's sources 1-4 (until plan 018
#                                                copied to raw/mmsi/oracle_*.parquet, whose names stay their `source`)
#         raw/oracle/vessel/vessel_mmsi.parquet  Oracle's current MMSI table, dated by the register's last change
#         raw/oracle/vessel/vessel_v.parquet     that date (max valid_from)
#         raw/vessels/mmsi_iceland_archieves.parquet   the old archive, for its hand-set windows only: 46 rows on 23 MMSIs
#                                                handed from one hull to another, set in 2024 partly from the STK track
#         overrides/mmsi_list_errors.csv, overrides/mmsi_broadcast.csv   confirmed rows only
#                                                (curate/corrections/mmsi_list_errors.yml, mmsi_broadcast_unregistered.yml)
# Output: curated/vessel/mmsi.parquet - one row per MMSI and holder period
#
# The old archive was kept by merging each new list into the last archive (the previous mmsi.R). That merge opened every
# new MMSI from 2007, never closed one that left the list, and could not tell a list's number from one added by hand:
# three boats' broadcast numbers sat in it in place of their official ones (plan 016 §2). Here every row is evidence
# with its source and date, and the windows are derived from that evidence:
#
#   holder     the vid: the registration number as an integer ("0741" in a list and 741 in Oracle are one hull), or for
#              an SKB pleasure craft 100000 + its number (maintainer, 2026-10-14). A vid is a hull for life, except
#              3700-4999 and the SKB range.
#   t1         the first holder of an MMSI from 2007-06-01; a later holder from the day after the previous holder's
#              deregistration date in its note when there is one, else from the first source it appears in.
#   t2         the day before the next holder; for the last holder its deregistration date when the note gives one
#              (the lists and Oracle keep a deregistered hull for years: 1612 sank in 2011 and is still in both), else
#              open (2028-12-24) while the latest list or Oracle has it, else the last source it appears in.
#   window_basis  default | list | note | reconstructed (a hand-set window, or a correction)
#
# Windows from list dates are coarse: the sources are dated 2019, 2020, 2022, 2024-26. A single-holder MMSI is opened
# to all time by curate/ais_ping_union.R anyway, so the windows matter where an MMSI has several holders.

library(dplyr)
library(nanoparquet)

AIS_T1   <- as.Date("2007-06-01")   # STK begins
SENTINEL <- as.Date("2028-12-24")   # the archive's open-ended marker, kept so its readers need not change
SKB_BASE <- 100000L                 # plan 016 §5

holder_vid <- function(sknr) {
  sknr <- trimws(sknr)
  case_when(grepl("^[0-9]+$", sknr)    ~ suppressWarnings(as.integer(sknr)),
            grepl("^SKB[0-9]+$", sknr) ~ SKB_BASE + suppressWarnings(as.integer(sub("^SKB", "", sknr))),
            .default = NA_integer_)
}
as_mmsi <- function(x) {
  x <- if (is.numeric(x)) sprintf("%.0f", as.numeric(x)) else trimws(as.character(x))   # the dump has MMSIs as integers
  if_else(x %in% c("", "NA"), NA_character_, x)
}
pick <- function(d, opts) { hit <- intersect(opts, names(d)); if (length(hit)) d[[hit[1]]] else rep(NA, nrow(d)) }

# Sources --------------------------------------------------------------------------------------------------------------
## The Fjarskiptastofa lists ------------------------------------------------------------------------------------------
list_date <- function(f) {
  b <- basename(f)
  iso <- regmatches(b, regexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", b))
  if (length(iso)) return(as.Date(iso))
  d <- regmatches(b, regexpr("[0-9]{6,8}(?=[.]xlsx$)", b, perl = TRUE))
  if (!length(d)) stop("cannot date the list ", b, call. = FALSE)
  as.Date(d, if (nchar(d) == 8) "%d%m%Y" else "%d%m%y")
}
xl <- list.files(fd_raw("mmsi"), "[.]xlsx$", full.names = TRUE)
xl <- xl[order(!grepl("fjarskiptastofa_[0-9]{4}", basename(xl)))]      # the ISO-named copy wins a tie
xl <- xl[!duplicated(unname(tools::md5sum(xl)))]
lists <- bind_rows(lapply(xl, function(f) {
  dt <- list_date(f)
  readxl::read_excel(f, col_types = "text") |>
    janitor::clean_names() |>
    transmute(mmsi = as_mmsi(mmsi_nr), sknr, cs = kallm, nafn = skip, note = athugasemdir,
              source = paste0("list_", dt), source_date = dt)
}))
LATEST_LIST <- max(lists$source_date)
cat("lists:", paste(sort(unique(lists$source)), collapse = " "), "\n")

## The Oracle snapshots (sources 1-4 of the old archive) --------------------------------------------------------------
snap_files <- c(fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20190627.parquet"),
                fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20201215.parquet"),
                fd_raw("oracle", "ops_einarhj", "vessel_mmsi_20220405.parquet"),
                fd_raw("oracle", "ops_einarhj", "mmsi_icelandic_registry.parquet"))
snaps <- bind_rows(lapply(snap_files, function(f) {
  d  <- read_parquet(f)
  dd <- regmatches(basename(f), regexpr("[0-9]{8}", basename(f)))
  tibble(mmsi = as_mmsi(pick(d, c("mmsi", "mmsi_no", "mmsi_nr"))),
         sknr = as.character(pick(d, c("sknr", "registration_no", "skip_nr", "vid"))),
         cs   = as.character(pick(d, c("cs", "call_sign", "kallm"))),
         nafn = as.character(pick(d, c("nafn", "name", "vessel", "skip", "heiti"))),
         note = as.character(pick(d, c("athugasemdir", "note", "aths"))),
         source = paste0("oracle_", sub("[.]parquet$", "", basename(f))),   # the old copies' names, raw/mmsi/oracle_*
         source_date = if (length(dd)) as.Date(dd, "%Y%m%d") else as.Date(NA))
}))

## Oracle's current table ---------------------------------------------------------------------------------------------
v <- read_parquet(fd_raw("oracle", "vessel", "vessel_v.parquet"))
REGISTER_DATE <- as.Date(max(v$valid_from, na.rm = TRUE))   # the register's last change, not the dump date
oracle_now <- read_parquet(fd_raw("oracle", "vessel", "vessel_mmsi.parquet")) |>
  transmute(mmsi = as_mmsi(mmsi_no), sknr = as.character(registration_no),
            cs = call_sign, nafn = NA_character_,
            note, source = "oracle_vessel_mmsi", source_date = REGISTER_DATE)

ev <- bind_rows(lists, snaps, oracle_now) |>
  filter(!is.na(mmsi)) |>
  mutate(sknr = na_if(trimws(sknr), ""), sknr = na_if(sknr, "NA"), vid = holder_vid(sknr),
         hkey = coalesce(as.character(vid), sknr)) |>
  # a row that names no holder (Oracle's current table leaves most SKB boats without one) is evidence for the holder
  # another source names; it stands alone only when no source names one
  group_by(mmsi) |>
  filter(!is.na(hkey) | all(is.na(hkey))) |>
  ungroup() |>
  mutate(hkey = coalesce(hkey, "unknown"))

# Corrections: source rows that name the wrong vid (curate/corrections/mmsi_list_errors.yml) ---------------------------
le <- read.csv("overrides/mmsi_list_errors.csv", colClasses = "character") |> filter(decision == "confirmed")
for (i in seq_len(nrow(le))) {
  hit <- ev$source == le$source[i] & ev$mmsi == le$mmsi[i] & ev$vid %in% holder_vid(le$sknr_listed[i])
  if (!any(hit)) stop("overrides/mmsi_list_errors.csv row ", i, " matches no list row", call. = FALSE)
  if (le$action[i] == "reject") ev <- ev[!hit, ]
  if (le$action[i] == "move") {
    ev$vid[hit] <- as.integer(le$vid[i]); ev$sknr[hit] <- le$vid[i]; ev$hkey[hit] <- le$vid[i]
  }
  cat("list error:", le$action[i], le$mmsi[i], "on", le$sknr_listed[i], "(", sum(hit), "rows )\n")
}

# One row per MMSI and holder ------------------------------------------------------------------------------------------
pairs <-
  ev |>
  # newest first, and a list before Oracle: the lists' notes carry the deregistration date in full
  arrange(mmsi, hkey, desc(source_date), !startsWith(source, "list_")) |>
  group_by(mmsi, hkey) |>
  summarise(vid = first(vid), sknr = first(sknr),
            cs = first(na.omit(cs)), nafn = first(na.omit(nafn)),
            note = first(na.omit(note[startsWith(source, "list_")]), default = first(na.omit(note))),
            first_seen = suppressWarnings(min(source_date, na.rm = TRUE)),
            last_seen  = suppressWarnings(max(source_date, na.rm = TRUE)),
            current = any(source_date >= LATEST_LIST, na.rm = TRUE),
            sources = paste(sort(unique(source)), collapse = "+"), .groups = "drop") |>
  mutate(first_seen = if_else(is.finite(first_seen), first_seen, as.Date(NA)),
         last_seen  = if_else(is.finite(last_seen), last_seen, as.Date(NA)),
         note_date = suppressWarnings(lubridate::dmy(stringr::str_extract(note, "[0-9]+[^0-9]+[0-9]+[^0-9]+[0-9]+"))),
         note_fate = case_when(
           grepl("sökk|fórst|brann|brennt", tolower(note)) ~ "Fórst",
           grepl("brota|niður", tolower(note)) ~ "Niðurrif",
           grepl("seld|selt", tolower(note))   ~ "Seldur",
           grepl("afsk|afsráð|afrskráð", tolower(note)) | startsWith(tolower(note), "afmáð") ~ "Afskráður",
           startsWith(tolower(note), "teki")   ~ "Úr rekstri",
           .default = NA_character_),
         mmsi_cat = ramb::rb_classify_mmsi(mmsi),
         mmsi_cat = case_when(mmsi == "251991540" ~ "SAR aircraft",
                              note %in% "V/prófana á fjarskiptabúnaði" ~ "testing",
                              nafn %in% c("Radíómiðun hf", "Brimrún hf", "Stefja ehf Ánanaustum 15") ~ "testing",
                              .default = mmsi_cat))

# Windows --------------------------------------------------------------------------------------------------------------
ok_date <- function(d, lo, hi) !is.na(d) & d >= coalesce(lo, AIS_T1) & d <= coalesce(hi, SENTINEL)
win <-
  pairs |>
  arrange(mmsi, coalesce(first_seen, AIS_T1), hkey) |>
  group_by(mmsi) |>
  mutate(zombie_no = row_number(),
         prev_note = lag(note_date), prev_first = lag(first_seen),
         .t1 = case_when(zombie_no == 1 ~ AIS_T1,
                         ok_date(prev_note, prev_first, first_seen) ~ prev_note + 1,
                         .default = first_seen),
         .t1_basis = case_when(zombie_no == 1 ~ "default",
                               ok_date(prev_note, prev_first, first_seen) ~ "note",
                               .default = "list"),
         # struck, scrapped or lost - not merely "seldur", which may be a sale within Iceland
         gone = grepl("afskr|afsráð|afrskráð|afmáð|sökk|fórst|brota|niðurrif|brennt|brann", tolower(note)) &
                ok_date(note_date, .t1, NA),
         .t2 = case_when(row_number() < n() ~ lead(.t1) - 1,
                         gone ~ note_date,
                         current ~ SENTINEL,
                         .default = coalesce(last_seen, SENTINEL)),
         .t2_basis = case_when(row_number() < n() ~ lead(.t1_basis),
                               gone ~ "note",
                               current ~ "default",
                               !is.na(last_seen) ~ "list",
                               .default = "default"),
         current = current & !gone) |>
  ungroup()

## The old archive's hand-set windows ----------------------------------------------------------------------------------
old <- read_parquet(fd_raw("vessels", "mmsi_iceland_archieves.parquet")) |>
  filter(mmsi_t1 != AIS_T1 | mmsi_t2 != SENTINEL) |>
  transmute(mmsi = as_mmsi(mmsi), hkey = as.character(holder_vid(sknr)), hs_t1 = as.Date(mmsi_t1), hs_t2 = as.Date(mmsi_t2))
win <- win |>
  left_join(old, by = c("mmsi", "hkey")) |>
  mutate(mmsi_t1 = coalesce(hs_t1, .t1), mmsi_t2 = coalesce(hs_t2, .t2),
         window_basis = case_when(!is.na(hs_t1) ~ "reconstructed",
                                  .t1_basis == "default" & .t2_basis == "default" ~ "default",
                                  .t1_basis == "note" | .t2_basis == "note" ~ "note",
                                  .default = "list"),
         basis = "recorded")
cat("hand-set windows kept:", sum(!is.na(win$hs_t1)), "of", nrow(old), "\n")

## Corrections: broadcast MMSIs (curate/corrections/mmsi_broadcast_unregistered.yml) ---------------------------------
bc <- read.csv("overrides/mmsi_broadcast.csv", colClasses = "character") |> filter(decision == "confirmed")
cat("broadcast corrections confirmed:", nrow(bc), "of", nrow(read.csv("overrides/mmsi_broadcast.csv")), "\n")
if (nrow(bc)) {
  bc_rows <- bc |>
    transmute(mmsi, vid = suppressWarnings(as.integer(vid)), hkey = coalesce(as.character(vid), "unknown"),
              sknr = as.character(vid), mmsi_t1 = coalesce(as.Date(na_if(t1, "")), AIS_T1),
              mmsi_t2 = coalesce(as.Date(na_if(t2, "")), SENTINEL), mmsi_cat = "vessel",
              sources = "overrides/mmsi_broadcast.csv", window_basis = "reconstructed", basis = "reconstructed",
              current = is.na(na_if(t2, "")))
  # a corrected MMSI is described by the correction alone
  win <- win |> filter(!mmsi %in% bc_rows$mmsi) |> bind_rows(bc_rows)
}

mmsi <-
  win |>
  arrange(mmsi, mmsi_t1) |>
  group_by(mmsi) |> mutate(zombie_no = row_number()) |> ungroup() |>
  select(mmsi, mmsi_cat, sknr, vid, cs, nafn, note, note_date, note_fate, mmsi_t1, mmsi_t2, zombie_no,
         first_seen, last_seen, current, sources, window_basis, basis)

# Assertions -----------------------------------------------------------------------------------------------------------
# An MMSI resolves to one holder at a time; an overlap here would duplicate every ping on it downstream.
ov <- mmsi |> arrange(mmsi, mmsi_t1) |> group_by(mmsi) |> filter(mmsi_t1 <= lag(mmsi_t2)) |> ungroup()
if (nrow(ov)) { print(ov, n = Inf); stop(nrow(ov), " MMSI holder periods overlap", call. = FALSE) }
bad <- mmsi |> filter(mmsi_t2 < mmsi_t1)
if (nrow(bad)) { print(bad, n = Inf); stop(nrow(bad), " windows end before they start", call. = FALSE) }

# A vid with two current vessel MMSIs is reported, not stopped: a boat may carry two transponders, or a tender under
# its number (SKB225). vessel.parquet takes one of them (reference/vessels/registry.R).
two <- mmsi |> filter(mmsi_cat == "vessel", current, !is.na(vid)) |> add_count(vid) |> filter(n > 1)
cat("vids with two current vessel MMSIs:", n_distinct(two$vid), "\n")
print(two |> select(vid, sknr, mmsi, nafn, sources), n = Inf)

print(mmsi |> count(mmsi_cat, window_basis, basis), n = Inf)
write_curated(mmsi, fd_curated("vessel", "mmsi.parquet"),
              inputs = c(xl, snap_files, fd_raw("oracle", "vessel", "vessel_mmsi.parquet"), fd_raw("oracle", "vessel", "vessel_v.parquet"),
                         fd_raw("vessels", "mmsi_iceland_archieves.parquet"),
                         "overrides/mmsi_list_errors.csv", "overrides/mmsi_broadcast.csv"))
