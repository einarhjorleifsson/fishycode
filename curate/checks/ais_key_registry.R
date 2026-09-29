# Invariants of the STK vessel match, against the vessel registry.
#
# Input:  curated/vessel/vessel_ais_key.parquet, curated/vessel/vessel.parquet,
#         raw/ais/stk/trail (ping counts per mobile-id and year, for check 3b)
# Output: curated/check/ais_key_registry.parquet  - one row per violation
#
# `_targets.R` says "wrong vid assignment is a known error class - see
# curate/checks/". Until now that pointed at a directory holding one script about
# whacky positions. These are the assertions `reference/vessels/ais_key.R` already
# makes, as `knitr::kable(caption = "Expect none")` printed into a console nobody
# reads - turned into a table that persists and can be diffed between builds.
#
# This check REPORTS. It never writes a vid. Per AGENTS.md the AIS -> vid ->
# logbook -> AIS loop is circular and is broken by a human outside the DAG: a
# reviewed conclusion re-enters through overrides/ as an input.

library(dplyr)
library(nanoparquet)

key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet"))
reg <- read_parquet(fd_curated("vessel", "vessel.parquet"))

assigned <- key |> filter(!is.na(vid))

# Rows are either mobile-id level (a bad assignment) or vid level (a vessel that
# should be in the key and is not), so the mobile-id columns are nullable.
flag <- function(d, check, note) {
  if (!nrow(d)) return(NULL)
  d |>
    transmute(check = check, note = note,
              mid, loid, glid, vid, step, type, entity_class, pings,
              d1 = as.Date(d1), d2 = as.Date(d2))
}

## 1. a vid that is not a number a registry can hold ----------------------------
# The duals spreadsheet carries negative vids - -2605 on mid 101661, -467 on
# 100193. Whether that is a convention meaning "reviewed and rejected" or two
# typos has never been written down, which is the point of flagging it.
v_negative <- assigned |> filter(vid <= 0)

## 2. a vid that is not in the registry at all ----------------------------------
v_unknown <- assigned |> filter(vid > 0, !vid %in% reg$vid)

## 3. an assignment outside the vessel's own registered period ------------------
# ais_key.R now computes this against curated/vessel/vessel_identity.parquet and
# carries it as lifetime_conflict. It FLAGS rather than withdraws, and the reason
# is measured: the first version withdrew all 81, and 20 of them - 1.39 M of the
# 1.83 M pings - are vessels that were actively landing fish throughout the
# disputed window. The registry lifetime is stale for those, not the match.
#
# So the useful output is the split, not the count. A row with landings inside the
# window is a registry defect; a row without is a candidate wrong match. Which is
# which is a human's call entering through overrides/, because deciding it here
# from landings would close the AIS -> vid -> logbook -> AIS cycle.
lnd_span <-
  read_parquet(fd_raw("landings", "agf", "aflagrunnur.parquet")) |>
  group_by(vid = skip_numer) |>
  reframe(l1 = as.Date(min(londun_hefst)), l2 = as.Date(max(londun_hefst)))
v_lifetime <-
  assigned |>
  filter(lifetime_conflict) |>
  left_join(lnd_span, by = "vid") |>
  mutate(note2 = if_else(!is.na(l2) & l2 >= as.Date(d1) & l1 <= as.Date(d2),
                         "landed fish during the window - the REGISTRY date is stale",
                         "no landings in the window - candidate wrong match"))

## 3b. a mobile-id that only PARTLY overlaps the vessel's registered life ------
# Check 3 (lifetime_conflict) fires only when the mobile-id is active WHOLLY outside
# [yh1, yh2]. A mid that starts before the hull was born, or runs on after the hull
# left the register, is missed: the reused-call-sign case, where the mid belongs to
# one hull for part of its window and another for the rest (decisions 044/045/046).
#
# yh1/yh2 are the year range of Hreidar's annual table (registry.R), so this is the
# registry's own evidence read at ping-year grain - not an independent witness
# (decision 046). Two limits are built in rather than left to the reader:
#   * yh2 is a snapshot horizon, never above 2021 (corrections/
#     vessel_registry_stale_lifetime.yml), so "after the hull's end" is only claimed
#     where yh2 < HORIZON. "Before the hull's birth" needs no such guard.
#   * years are compared with +-1 year of tolerance; the table is annual.
# Reported only past MIN_PINGS or MIN_FRAC of the row's pings (and FLOOR), and never for a row
# check 3 already flags. Foreign hulls (3700-4999) are excluded: the keel rule does
# not hold above 3700, so a vid there has no single lifetime to compare against.
STK_ERA   <- 2007L
HORIZON   <- max(reg$yh2, na.rm = TRUE)
MIN_PINGS <- 1000L
MIN_FRAC  <- 0.05
FLOOR     <- 100L   # a fraction alone is not evidence: 3 pings of 3 is noise

mid_year <-
  duckdbfs::open_dataset(fd_raw("ais", "stk", "trail")) |>
  # the trail carries time outliers (1970-2106, corrections/stk_trail_time_outliers.yml)
  dplyr::mutate(yr = year(time)) |>
  dplyr::filter(dplyr::between(yr, STK_ERA, HORIZON)) |>
  dplyr::count(mid, yr, name = "n") |>
  dplyr::collect()

v_partial <-
  assigned |>
  filter(!lifetime_conflict, vid > 0, !vid %in% 3700:4999) |>
  inner_join(reg |> select(vid, yh1, yh2), by = "vid") |>
  filter(!is.na(yh1) | !is.na(yh2)) |>
  inner_join(mid_year, by = "mid", relationship = "many-to-many") |>
  filter(yr >= lubridate::year(d1), yr <= lubridate::year(d2)) |>
  mutate(.side = case_when(!is.na(yh1) & yr < yh1 - 1L ~ "before",
                           !is.na(yh2) & yh2 < HORIZON & yr > yh2 + 1L ~ "after",
                           .default = "in")) |>
  group_by(mid, loid, glid, vid, step, type, entity_class, d1, d2, yh1, yh2) |>
  summarise(.all = sum(n),
            .before = sum(n[.side == "before"]),
            .after  = sum(n[.side == "after"]),
            .groups = "drop") |>
  mutate(.out = .before + .after) |>
  filter(.out >= FLOOR, .out >= MIN_PINGS | .out / .all >= MIN_FRAC) |>
  mutate(pings = .all,
         note2 = paste0(
           case_when(.before > 0 & .after > 0 ~ "before and after",
                     .before > 0 ~ "before the hull's first registered year",
                     .default = "after the hull's last registered year"),
           " (", prettyNum(.out, big.mark = ","), " of ", prettyNum(.all, big.mark = ","),
           " pings, hull ", coalesce(as.character(yh1), "?"), "-",
           coalesce(as.character(yh2), "?"), ") - candidate reused identifier or wrong match"))

## 4. one vessel, two mobile-ids open at the same time --------------------------
# d2 is the 2028-12-24 sentinel on 31,791 of 31,859 rows, so when a vessel changes
# transponder the OLD mobile-id's window never closes. Either the old one really
# fell silent, in which case closing d2 from evidence removes this, or the vessel
# has two simultaneous tracks and its trips are wrong.
v_two_open <-
  assigned |>
  arrange(vid, d1) |>
  group_by(vid) |>
  mutate(.next_d1 = lead(d1), .next_mid = lead(mid)) |>
  ungroup() |>
  filter(!is.na(.next_d1), d2 > .next_d1) |>
  mutate(note2 = paste0("overlaps mid ", .next_mid, " from ", as.Date(.next_d1)))

## 5. a vid on a mobile-id that is not a vessel ---------------------------------
# Asserted in ais_key.R itself and expected to be empty. Here so that it stays
# empty rather than being true once.
v_nonvessel <- assigned |> filter(entity_class != "vessel")

## 6. an Icelandic vessel that should be in the key and is not ------------------
# The completeness target, in the maintainer's words (2026-09-22): "we still want
# all icelandic vid (i.e. not the 3700-4999) to be assigned to STK, of course the
# limit is the time period of the STK - the vessel registry contains some really
# old vessels that were no longer in existence when the STK began."
#
# So the population is Icelandic hulls whose registry lifetime reaches into the STK
# era. 1,873 vessels have yh2 < 2007 and are correctly absent; they are excluded
# here rather than counted as a gap.
#
# Stratified, because the strata mean different things. mclass 63 is the bulk of
# what is missing and a small open boat may simply carry no transponder, which is
# not a defect. A vessel with an MMSI, or one over 15 m, almost certainly should be
# trackable, and those are the rows worth a human's time.
registry_gap <-
  reg |>
  filter(source == "ISL", !vid %in% 3700:4999) |>
  filter(is.na(yh2) | yh2 >= STK_ERA) |>
  filter(!vid %in% assigned$vid) |>
  mutate(mid = NA_real_, loid = NA_character_, glid = NA_character_,
         step = NA_character_, type = NA_character_,
         entity_class = NA_character_, pings = NA_real_,
         d1 = as.Date(NA), d2 = as.Date(NA),
         .why = case_when(
           !is.na(mmsi)            ~ "has an MMSI - should be trackable",
           !is.na(loa) & loa >= 15 ~ "15 m or over - should be trackable",
           is.na(yh2)              ~ "no yh2 in the registry, so 'alive in the STK era' is assumed",
           .default = paste0("mclass ", coalesce(as.character(mclass), "?"),
                             "; may legitimately carry no transponder")))

## Emit -------------------------------------------------------------------------
out <-
  bind_rows(
    flag(v_negative,  "negative_vid",
         "vid <= 0; convention or typo has never been recorded"),
    flag(v_unknown,   "vid_not_in_registry",
         "assigned a vid the vessel registry does not hold"),
    flag(v_lifetime,  "outside_vessel_lifetime",
         v_lifetime$note2),
    flag(v_partial,   "partly_outside_vessel_lifetime",
         v_partial$note2),
    flag(v_two_open,  "two_mids_open",
         "another mobile-id claims this vid over an overlapping period"),
    flag(v_nonvessel, "vid_on_non_vessel",
         "a vid is assigned to something entity_class says is not a vessel"),
    if (nrow(registry_gap))
      registry_gap |>
        transmute(check = "icelandic_vessel_not_in_ais", note = .why,
                  mid, loid, glid, vid, step, type, entity_class, pings, d1, d2))
if (is.null(out)) out <- tibble(check = character(), note = character())

# print(): source() does not echo top-level values, which is why the 21
# knitr::kable diagnostics in ais_key.R have never once been seen by anyone.
print(out |> count(check, name = "rows") |>
        knitr::kable(caption = "ais_key_registry"))
print(out |> filter(check == "outside_vessel_lifetime") |> count(note, name = "rows") |>
        knitr::kable(caption = "Matched to a hull the registry says was not there"))
print(out |> filter(check == "partly_outside_vessel_lifetime") |> summarise(rows = n(), pings = sum(pings)) |>
        knitr::kable(caption = "Mobile-id that outlives, or predates, its hull"))
print(out |> filter(check == "icelandic_vessel_not_in_ais") |> count(note, name = "vessels") |>
        arrange(-vessels) |>
        knitr::kable(caption = "Icelandic hulls alive in the STK era with no mobile-id"))

write_curated(out, fd_curated("check", "ais_key_registry.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         vessel         = fd_curated("vessel", "vessel.parquet")))
