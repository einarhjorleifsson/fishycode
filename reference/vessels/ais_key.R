# Classify the mobileid-localid-globalid in the stk-data
#  Focus on vessel data
#   * Assign MMSI, if possible to all Icelandic vessels
#   * Attempt to assign MMSI to foreign vessels
#   * Attempt to write the code flow so it can easily be updated
#     once new data are compiled (Not there yet)
#
#  The code includes many "tests", intended to capture possible match issues
#   as upstream as possible. The code is a result of iterative procedure where
#   overlaps (same mobileid on 2-3 vessels) are reported in the dual spreadsheet,
#   then whole process run a again, checking again for issues at each step.

# TODO: ------------------------------------------------------------------------
#   MOVE ALL MANUAL MATCHING TO THE DUAL DOCUMENT - done
#   VID 3700-4999: these are foreign vessels — no further matching effort planned
#   UNMATCHED ICELANDIC MMSI (genuine vessels, not in registry — need Fiskistofa lookup):
#     mid 114902 MMSI 251950001 (active 2015-16, 2024+)
#     mid 118765 MMSI 251068418 (active 2015)
#     mid 139879 MMSI 251898641 (active 2021-2023)
#   ODS DATE ERROR: mid 101097 (vid 1328) — d1/d2 in ODS are both in 2008 (~15-day window)
#     but mid is active 2007-2026; no=2 (vid 3025) starts 2023-09-07.
#     Correct ODS no=1 to: d1=2007-06-01, d2=2023-09-06
# NEWS
# 202X-12-31
#
# 2024-10-24
#  * consolidation, review and addition of older matches
# INPUT
#    oracle stk.trail
#    oracle stk.mobile
#    data/auxillary/maritime_identification_digits.parquet
#    data/vessels/vessels_iceland.parquet
#    older matches of mobileid and vessel registration number
#     see: ~/R/Pakkar2/omar/data-raw/00_SETUP_mobile-vid-match.R
#          last updated 2024-02-12
#          ops$einarhj.mobile_vid
#
# OUTPUT
# data-raw/stk-mmsi-vessel-match/******.parquet

library(nanoparquet)
library(duckdbfs)
library(tidyverse)

options(knitr.kable.NA = '')
#library(mar)

#con <- connect_mar()

# a stk summary helper function
lh <- function(d) {
  d |>
    group_by(.loid, .glid) |>
    reframe(n = n(), pings = sum(pings)) |>
    arrange(-n) |>
    mutate(cn = round(cumsum(n / sum(n)) * 100, 2),
           .after = n) |>
    mutate(pp = round(pings / sum(pings) * 100, 2)) |>
    knitr::kable()
}
lh_speed <- function(MID, trim = TRUE) {
  d <-
    STK |>
    filter(mid %in% MID) |>
    select(mid, time, speed) |>
    collect() |>
    mutate(speed = ifelse(speed > 15, 15, speed))
  if(trim) {
    d <- d |> filter(time >= ymd_hms("2007-06-01 00:00:00"))
  }
  d |>
    ggplot(aes(time, speed)) + geom_point(size = 0.1) +
    facet_wrap(~ mid, ncol = 1) +
    scale_x_datetime(date_breaks = "2 year", date_labels = "%Y")
}
lh_overlaps <- function(d) {
  d |>
    group_by(vid) |>
    mutate(n = n()) |>
    ungroup() |>
    filter(n > 1, !is.na(vid)) |>
    arrange(vid, d2) |>
    group_by(vid) |>
    mutate(dt = difftime(lead(d1), d2, units = "day"),
           dt = as.numeric(dt)) |>
    mutate(overlap = case_when(dt < -1 ~ "yes",
                               .default = "no")) |>
    filter(overlap == "yes") |>
    pull(vid) |>
    unique() ->
    vid_overlap
  d |>
    filter(vid %in% vid_overlap) |>
    arrange(vid, d2) |>
    group_by(vid) |>
    mutate(overlap = case_when(d2 > lead(d1) ~ "yes",
                               .default = "no"))
}
lh_overlaps_plot <- function(MID, stkX) {
  STK |>
    filter(mid %in% MID) |>  # Need to check this
    select(mid, loid, glid, time, speed) |>
    mutate(speed = ifelse(speed > 15, 15, speed)) |>
    collect() |>
    left_join(stkX,
              by = join_by(mid == mid, loid == loid, glid == glid,
                           between(time, d1, d2))) |>
    ggplot(aes(time, speed, colour = factor(mid))) +
    geom_point(size = 0.01) +
    facet_wrap(~ vid, ncol = 1) +
    scale_x_datetime(date_breaks = "2 year", date_labels = "%Y")
}

lh_mmsi_expectations <- function(d) {
  d |>
    filter(vid > 0) |>
    #filter(step != "duals") |>
    left_join(v_all |> select(vid, mmsi, yh1, yh2)) |>
    filter(is.na(mmsi)) |>
    arrange(desc(d2)) |>
    knitr::kable(caption = "Don't expect missing mmsi for 'recent' d2")
}


# Check that it doesn't match any non-letter
letters_only <- function(x) !grepl("[^A-Za-z]", x)
# Check that it doesn't match any non-number
numbers_only <- function(x) !grepl("\\D", x)

str_extract_between_parenthesis <- function(x) {
  str_match(x, "(?<=\\().+?(?=\\))")
}

str_extract_dmy_period <-
  function(x) {
    str_extract(x, "\\d+\\D+\\d+\\D+\\d+")
  }

# Data -------------------------------------------------------------------------

## Various auxillary informations ----------------------------------------------
## Maritime identification digits
MID <-
  read_parquet(fd_staging("aux", "maritime_identification_digits.parquet")) |>
  # used for classifying likely incomplete mmsi-signals
  mutate(MID_child = paste0("98", MID),
         MID_aid = paste0("99", MID))
## Call sign prefix - flag state
cs.prefix.all <-
  read_parquet(fd_staging("aux", "callsign_prefix.parquet"))
cs.prefix <-
  cs.prefix.all |>
  # critical, lot of mess with TF in stk localid and globalid
  filter(cs_prefix != "TF")
## vessel registry
#  should really add skemmtibatar
v_all <-
  read_parquet(fd_curated("vessel", "vessel.parquet")) |>
  mutate(vidc = as.character(vid))
v_mmsi <-
  v_all |>
  filter(!is.na(mmsi))

## Known (via ad hoc) non-vessel localid or globalid ---------------------------
# Until 2026-09-22 these five vectors were ~250 literals inline here, and they were
# the only entity classifier that has ever existed in any of the eight repos. They
# are a reviewed *input* - a nine-character truncated Icelandic place name is not
# derivable from anything, so a human decided each row - and AGENTS.md puts reviewed
# inputs in overrides/, not in a script. Membership is unchanged; `type` below is
# byte-for-byte what it was.
stk_overrides <- read_stk_overrides()
.ov <- function(g) stk_overrides$value[stk_overrides$legacy_group == g]
fixed        <- .ov("fixed")
kvi          <- .ov("kvi")
hafro        <- .ov("hafro")
net_glid     <- .ov("net_glid")
unknown_glid <- .ov("unknown_glid")

## Vessel info for local- and globalid classification --------------------------
# suffix 2 is when mmsi not available
CS <-
  v_mmsi |>
  filter(!is.na(cs)) |>
  filter(nchar(cs) %in% 4:7) |>
  pull(cs) |>
  unique()
CS2 <-
  v_all |>
  filter(!vid %in% 3700:4999) |>
  filter(!is.na(cs)) |>
  filter(nchar(cs) %in% 4:7) |>
  pull(cs) |>
  unique()
CS3 <-
  v_all |>
  filter(vid %in% 3700:4999) |>
  filter(!is.na(cs)) |>
  filter(nchar(cs) %in% 4:7) |>
  pull(cs) |>
  unique()
UID <-
  v_mmsi |>
  filter(!is.na(uid)) |>
  pull(uid) |>
  unique()
UID2 <-
  v_all |>
  filter(!is.na(uid)) |>
  pull(uid) |>
  unique()
VID <-
  v_mmsi |>
  filter(source == "ISL", !is.na(vid)) |>
  pull(vid) |>
  as.character()
VID2 <-
  v_all |>
  filter(source == "ISL", !is.na(vid)) |>
  pull(vid) |>
  as.character()

# Every identifier the registry actually holds, for the equipment rule in
# R/entity_class.R: a net buoy is registered under a made-up id derived from its
# ship's, so the test is "the remainder, once a trailing digit comes off, is a real
# call sign or a real vid".
known_ids <- unique(c(CS, CS2, CS3, VID2))

lnd <-
  read_parquet(fd_raw("landings", "agf", "aflagrunnur.parquet")) |>
  #read_parquet(fd_curated("landing", "agf_stations.parquet")) |>
  group_by(vid = skip_numer) |>
  reframe(n = n(),
          min = min(londun_hefst),
          max = max(londun_hefst)) |>
  filter(vid >= 5)

## stk summary -----------------------------------------------------------------
STK <-
  open_dataset(fd_raw("ais", "stk", "trail"))
mobile <- open_dataset(fd_raw("ais", "stk", "mobile.parquet"))
stk <-
  STK |>
  group_by(mid, year) |>
  mutate(n = n()) |>
  ungroup() |>
  mutate(n = n()) |>
  filter(n >= 10) |>
  left_join(mobile) |>
  group_by(mid, loid, glid) |>
  summarise(pings = n(),
            n_years = n_distinct(year),
            d1 = min(time, na.rm = TRUE),
            d2 = max(time, na.rm = TRUE),
            .groups = "drop") |>
  collect() |>
  # these used when using join with between
  mutate(d1 = as_date(d1),
         d2 = as_date(d2) + ddays(1)) |>  # rather than 23:59:59 if time was used
  # this however includes the first second of next day
  arrange(mid, d1, d2) |>
  mutate(.rid = 1:n(),
         .before = mid)

# Older matches ----------------------------------------------------------------
older <-
  read_parquet(fd_raw("ais", "stk", "einarhj_mobile-vid.parquet")) |>
  select(mid:vid, no, t1, t2) |>
  # add loid and glid where missing
  left_join(stk |> select(mid, loid_tmp = loid, glid_tmp = glid, d1, d2),
            by = join_by(mid)) |>
  mutate(loid = ifelse(is.na(loid), loid_tmp, loid),
         glid = ifelse(is.na(glid), glid_tmp, glid)) |>
  select(-c(loid_tmp, glid_tmp)) |>
  arrange(mid) |>
  group_by(mid) |>
  mutate(n.mid = n()) |>
  ungroup()

# Join manual (duals) ----------------------------------------------------------
manual <-
  fd_raw("ais", "stk", "stk_mobile_match-and-duals.ods") |>
  #fd_staging("stk_mobile_match-and-duals", "stk_mobile_match-and-duals.ods") |>
  readODS::read_ods() |>
  select(mid:d2) |>
  # Guard: fix swapped d1/d2 (ODS date-entry errors)
  mutate(d1_tmp = pmin(d1, d2, na.rm = TRUE),
         d2     = pmax(d1, d2, na.rm = TRUE),
         d1     = d1_tmp) |>
  select(-d1_tmp)

stk1 <-
  stk |>
  left_join(manual |>
              select(mid, vid, no, .d1 = d1, .d2 = d2)) |>
  mutate(d1 = case_when(!is.na(.d1) ~ .d1,
                        .default = d1),
         d2 = case_when(!is.na(.d2) ~ .d2,
                        .default = d2)) |>
  select(-c(.d1, .d2)) |>
  mutate(step = case_when(!is.na(vid) ~ "manuals",
                          .default = NA))


# Classification ---------------------------------------------------------------
stk2 <-
  stk1 |>
  # The order matters in the case_when
  mutate(.loid =
           case_when(
             loid %in% fixed ~ "fixed",
             loid %in% kvi ~ "kvi",
             loid %in% VID ~ "vid",
             loid %in% VID2 ~ "vid2",
             #
             loid %in% CS ~ "cs",
             loid %in% CS2 ~ "cs2",
             loid %in% CS3 ~ "cs3",
             loid %in% UID ~ "uid",
             loid %in% UID2 ~ "uid2",
             # NOT widened to one-character prefixes, though ten of the 711 ITU
             # allocations are one (2 B F G I K M N R W) and this misses every
             # French, British and Italian call sign - 936 mobile-ids, 1.2 M
             # pings. Tried 2026-09-22 and reverted: `type` is pasted from both
             # fields and the steps below match it as a literal, so widening the
             # classifier renamed NA_cs to cs4_cs and unmatched four vessels that
             # the NA_cs step had been catching. The classifier cannot be fixed
             # while the rules key on its output. entity_class carries the same
             # signal harmlessly - see R/entity_class.R - and the real repair is
             # plan 003 step 5.
             str_sub(loid, 1, 2) %in% cs.prefix$cs_prefix &
               !numbers_only(str_trim(loid)) &
               !str_starts(loid, "MOB_")  ~ "cs4",
             numbers_only(loid) & str_sub(loid, 1, 5) %in% MID$MID_child ~ "mmsi.other",
             numbers_only(loid) & str_sub(loid, 1, 5) %in% MID$MID_aid ~ "mmsi.other",
             numbers_only(loid) & nchar(loid) == 9  ~ "mmsi",
             .default = NA)) |>
  mutate(.glid =
           case_when(
             glid %in% fixed ~ "fixed",
             glid %in% kvi ~ "kvi",
             glid %in% hafro ~ "hafro",
             glid %in% unknown_glid ~ "unknown",
             str_detect(tolower(glid), "_net") ~ "net",
             glid %in% net_glid ~ "net",
             glid %in% VID ~ "vid",
             glid %in% VID2 ~ "vid2",
             # numbers_only(glid) & nchar(glid) == 9 ~ "mmsi",
             glid %in% CS ~ "cs",
             glid %in% CS2 ~ "cs2",
             glid %in% CS3 ~ "cs3",
             glid %in% UID ~ "uid",
             glid %in% UID2 ~ "uid2",
             str_sub(glid, 1, 2) %in% cs.prefix$cs_prefix &
               !numbers_only(str_trim(glid)) &
               !str_starts(glid, "MOB_")  ~ "cs4",
             numbers_only(glid) & str_sub(glid, 1, 5) %in% MID$MID_child ~ "mmsi.other",
             numbers_only(glid) & str_sub(glid, 1, 5) %in% MID$MID_aid ~ "mmsi.other",
             numbers_only(glid) & nchar(glid) == 9 ~ "mmsi",
             #numbers_only(glid) & nchar(glid) == 7 & !omar::vessel_valid_imo(glid) ~ "imo",
             .default = NA)) |>
  mutate(type = paste0(replace_na(.loid, "NA"), "_", replace_na(.glid, "NA"))) |>
  select(-c(.loid, .glid))

## Entity class ----------------------------------------------------------------
# `type` records which pair of rules fired. That is provenance for the cascade
# below, not a vocabulary a consumer can use: until now the only way to ask "is
# this a vessel" was to test whether the string contained the word "fixed". The
# entity class answers it directly, from loid and glid alone, before any vid is
# matched, and carries the basis AGENTS.md requires. See R/entity_class.R.
stk2 <-
  stk2 |>
  bind_cols(stk_entity_class(stk2$loid, stk2$glid,
                             overrides = stk_overrides,
                             cs_prefix = cs.prefix.all$cs_prefix,
                             known_ids = known_ids))

stk2 |> lh_overlaps() |> filter(vid > 0) |>  knitr::kable(caption = "Expect none")

# Join older -------------------------------------------------------------------
#  Note: the filter(n.mid == 1) filters out all but one of the older vid 3700 to 4999
stk3 <-
  stk2 |>
  left_join(older |> filter(n.mid == 1) |> select(mid, vid_older = vid))
stk3 |> lh_overlaps() |> filter(vid > 0) |> knitr::kable(caption = "Expect none")
stk3 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## vid_vid ---------------------------------------------------------------------
stk4 <-
  stk3 |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "vid_vid" & loid == glid ~ as.numeric(glid),
                         .default = vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "vid_vid",
                          .default = step))
stk4 |>
  filter(type == "vid_vid") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type vid_vid (expect none)")

# duals with overlaps
stk4 |> lh_overlaps() |> filter(vid > 0) |> knitr::kable(caption = "Expect vid 1511, 7807")
stk4 |> lh_mmsi_expectations()

## vid_cs match ----------------------------------------------------------------
stk5 <-
  stk4 |>
  mutate(.vid = case_when(type == "vid_cs" ~ as.numeric(loid),
                          .default = -9999),
         .cs = case_when(type == "vid_cs" ~ glid,
                         .default = "XXXX")) |>
  left_join(v_mmsi |> select(.vid = vid, .cs = cs) |> mutate(type = "vid_cs"),
            by = join_by(.vid, .cs, type)) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "vid_cs" & vid_older == .vid & glid == .cs ~ vid_older,
                         type == "vid_cs" & is.na(vid_older) ~ .vid,
                         type == "vid_cs" & vid_older == 6643 ~ vid_older,  # single case
                         .default = vid)) |>
  select(-c(.vid, .cs)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "vid_cs",
                          .default = step))
stk5 |>
  filter(type == "vid_cs") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type vid_cs (expect none)")

stk5 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
if(FALSE) {
  lh_overlaps_plot(c(103851, 101223), stk5) # expected, vid 2718 has one mid inbetween another mid
}
stk5 |> filter(!vid %in% 3700:4999) |>  lh_mmsi_expectations()
## uid_cs match ----------------------------------------------------------------
stk6 <-
  stk5 |>
  mutate(.uid = case_when(type == "uid_cs" ~ loid,
                          .default = "XXXX"),
         .cs = case_when(type == "uid_cs" ~ glid,
                         .default = "XXXX")) |>
  left_join(v_mmsi |> select(.vid = vid, .cs = cs, .uid = uid) |> mutate(type = "uid_cs"),
            by = join_by(.cs, .uid, type)) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "uid_cs" & vid_older == .vid ~ vid_older,
                         type == "uid_cs" & !is.na(vid_older) ~ vid_older,
                         .default = vid)) |>
  select(-c(.cs, .uid, .vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "uid_cs",
                          .default = step))
stk6 |>
  filter(type == "uid_cs") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type uid_cs (expect none)")
stk6 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
stk6 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_vid match ----------------------------------------------------------------
stk7 <-
  stk6 |>
  mutate(.vid = case_when(type == "NA_vid" ~ glid,
                          .default = NA)) |>
  left_join(v_mmsi |> select(.vid = vidc, mmsi) |> mutate(type = "NA_vid"),
            by = join_by(.vid, type)) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "NA_vid" & !is.na(mmsi) ~ as.integer(.vid),
                         .default = vid)) |>
  select(-c(.vid, mmsi)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "NA_vid",
                          .default = step))
stk7 |>
  filter(type == "NA_vid") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type NA_vid (expect none)")

stk7 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
if(FALSE) {
  lh_overlaps_plot(c(101081), stk7) # Still dubious, second period for 2067 may be a wrong allocation
}
stk7 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_cs ------------------------------------------------------------------------
stk8 <-
  stk7 |>
  mutate(.cs = glid) |>
  left_join(v_mmsi |> select(.cs = cs, .vid = vid, .uid = uid, yh1, yh2) |> mutate(type = "NA_cs")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "NA_cs" & vid_older == .vid  ~ vid_older,
                         type == "NA_cs" & !is.na(.vid) ~ .vid,
                         .default = vid)) |>
  select(-c(.cs, .vid, .uid, yh1, yh2)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "NA_csts",
                          .default = step))
stk8 |>
  filter(type == "NA_cs") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type NA_cs (expect none)")
stk8 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
stk8 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## vid2_cs ---------------------------------------------------------------------
# Question if this should come next
stk9 <-
  stk8 |>
  mutate(.cs = glid) |>
  left_join(v_mmsi |>
              select(.cs = cs, .vid = vidc, .uid = uid, yh1, yh2) |> mutate(type = "vid2_cs") |>
              # did this to not get many-to-many
              filter(yh2 > 2013)) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "vid2_cs" ~ as.numeric(.vid),
                         .default = vid)) |>
  select(-c(.cs, .vid, .uid, yh1, yh2)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "vid2_cs",
                          .default = step))
stk9 |>
  filter(type == "vid2_cs") |>
  filter(is.na(vid)) |>
  knitr::kable()
stk9 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
stk9 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()


if(FALSE) {
  lnd |>
    filter(!vid %in% c(stk9 |> select(vid) |> drop_na() |> pull(vid))) |>
    arrange(desc(max)) |>
    left_join(v_all) |>
    knitr::kable(caption = "List of vessels in landings not in stk")

  # CHECK THIS
  v_all |> filter(vid == 3027)
  stk9 |> filter(vid == 1115)
  v_all |> filter(cs == "TFAU")
  v_all |> filter(uid == "RE245")
  v_all |> filter(uid == "GK011")
}

## vid2_vid2 -------------------------------------------------------------------
# When loid == glid and both classify as vid2, the vid is encoded directly in
# loid/glid — same logic as stk4's vid_vid step but for vessels without MMSI
stk9b <-
  stk9 |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "vid2_vid2" & loid == glid ~ as.numeric(loid),
                         .default = vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "vid2_vid2",
                          .default = step))
stk9b |>
  filter(type == "vid2_vid2") |>
  filter(is.na(vid)) |>
  knitr::kable(caption = "Missing vid for type vid2_vid2 where loid==glid (expect none for loid==glid rows)")
stk9b |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 1511, 2718, 7807")
stk9b |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## VID_OLDER -------------------------------------------------------------------
# hail mary, step may be premature
stk10 <-
  stk9b |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         is.na(vid) & !is.na(vid_older) & pings > 100 ~ vid_older,
                         .default = vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) & pings > 100 ~ "older",
                          .default = step))

stk10 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect vid 396, 950, 1511, 2718, 7807")
if(FALSE) {
  lh_overlaps_plot(c(113343, 107082), stk10) # 396
  lh_overlaps_plot(c(107945, 100430), stk10) # 950
}
stk10 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_mmsi ---------------------------------------------------------------------
v_mmsi_no_dupes <-
  v_mmsi |>
  arrange(mmsi, desc(mmsi_t2), desc(vid)) |>
  group_by(mmsi) |>
  slice(1) |>
  ungroup()
stk11 <-
  stk10 |>
  mutate(.mmsi = glid) |>
  left_join(v_mmsi_no_dupes |> select(.vid = vidc, .mmsi = mmsi, yh1, yh2) |> mutate(type = "NA_mmsi")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         type == "NA_mmsi" & pings >= 30 ~ as.numeric(.vid),
                         .default = vid)) |>
  select(-c(.vid, .mmsi, yh1, yh2)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "NA_mmsi",
                          .default = step))
stk11 |>
  filter(type == "NA_mmsi") |>
  filter(!is.na(vid)) |>
  pull(vid) ->
  vids
stk11 |>
  filter(vid %in% vids) |>
  group_by(vid) |>
  mutate(n = n()) |>
  ungroup() |>
  filter(n > 1) |>
  arrange(vid, d2)
if(FALSE) {
  lh_overlaps_plot(c(120568, 100873), stk11)
  lh_overlaps_plot(c(143787, 102969), stk11)
}

## loid_cs -----------------------------------------------------------------------
# The cascade has NA_vid but never had vid_NA: when the LEFT field is the identifier
# and the right one is unrecognised, nothing fires. 96 mobile-ids on 1.29 M pings sit
# in that hole.
#
# Only the undecorated agreement is taken: loid is a registered vid and glid is that
# same vid's own call sign, spelled plainly. Decorated variants are the vessel's
# equipment, not the vessel - see .looks_like_equipment() - and a suffix-stripping
# match would have handed a vid to 42 mobile-ids that were transmitting while the
# ship's own mobile-id was also transmitting.
stk11b <-
  stk11 |>
  mutate(.lvid = suppressWarnings(as.integer(loid))) |>
  left_join(v_all |> select(.lvid = vid, .cs_reg = cs), by = join_by(.lvid)) |>
  mutate(vid = case_when(
           !is.na(vid) ~ vid,
           entity_class == "vessel" & !is.na(.lvid) & !is.na(.cs_reg) &
             toupper(glid) == toupper(.cs_reg) ~ .lvid,
           .default = vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) ~ "loid_cs",
                          .default = step)) |>
  select(-c(.lvid, .cs_reg))
stk11b |>
  filter(step == "loid_cs") |>
  knitr::kable(caption = "loid_cs: loid is the vid, glid is that vid's own call sign")

## afmadur -----------------------------------------------------------------------
# "Afmadur" is afmadur, erased - struck off the Icelandic registry. STK relabels the
# transponder with it, keeps the old vid in loid, and the vessel goes on transmitting.
# The vid is still right: it is assigned to the keel and stays with the hull from
# cradle to grave, whatever flag it ends up under.
#
# Measured 2026-09-22 against the registry's own note_date: GNUPUR's afmadur
# mobile-id begins the day after the registry records "Seldur", BJARNI SAEMUNDSSON's
# eight days after, AMANDA's twenty-nine. Nine of fifteen start within days of the
# vessel's PREVIOUS mobile-id falling silent - a clean handover.
#
# The other six overlap their own predecessor in real ping time, which is either a
# handover period or a mobile-id the buyer kept using. Not guessed at: they are
# listed below and left unassigned.
#
# The clash test is a loop over the handful of afmadur rows rather than a join,
# because .rid is NOT a unique key - the duals join above adds 68 rows after .rid is
# assigned - and grouping on it silently collapses those 68.
.afma  <- str_detect(stk11b$glid, regex("^afma", ignore_case = TRUE))
.alvid <- suppressWarnings(as.integer(stk11b$loid))
.assigned <- stk11b |> filter(!is.na(vid)) |> select(avid = vid, ad1 = d1, ad2 = d2)
.clash <- rep(NA, nrow(stk11b))
for (j in which(.afma & !is.na(.alvid))) {
  o <- .assigned[.assigned$avid == .alvid[j], ]
  .clash[j] <- nrow(o) > 0 && any(stk11b$d1[j] < o$ad2 & o$ad1 < stk11b$d2[j])
}
stk11c <-
  stk11b |>
  mutate(.afma = .afma, .lvid = .alvid, .clash = .clash,
         vid = case_when(!is.na(vid) ~ vid,
                         .afma & .lvid %in% v_all$vid & !.clash ~ .lvid,
                         .default = vid),
         step = case_when(!is.na(vid) & is.na(step) ~ "afmadur",
                          .default = step))
stk11c |>
  filter(.afma) |>
  select(mid, loid, glid, vid, step, .clash, pings, d1, d2) |>
  arrange(-pings) |>
  knitr::kable(caption = "afmadur: assigned unless the vessel's own mobile-id overlaps")
stk11c <- stk11c |> select(-c(.afma, .lvid, .clash))

# I AM HERE --------------------------------------------------------------------

lnd |>
  filter(vid < 9900) |>
  filter(!vid %in% c(stk11 |> select(vid) |> drop_na() |> pull(vid))) |>
  arrange(desc(max)) |>
  left_join(v_all) |>
  knitr::kable(caption = "List of vessels in landings not in stk")

# Add MMSI to Icelandic vessels ------------------------------------------------
stk12 <-
  stk11c |>
  left_join(v_mmsi_no_dupes |> select(vid, mmsi))

# Extend the last date ---------------------------------------------------------
# Need to extend the 'last' "d2" within any mobileid to something like 2028-12-24
#  This is so that 'later' stk dumps get included in the between join downstream
stk13 <-
  stk12 |>
  mutate(no = replace_na(no, 1)) |>
  group_by(mid) |>
  mutate(d2 = case_when(no == max(no) ~ ymd("2028-12-24"),
                        .default = d2)) |>
  ungroup()
# Entity class, final pass -----------------------------------------------------
# A matched vid is itself a statement that the thing is a vessel, and it outranks a
# name pattern - six matched Norwegian and Faroese registration marks (N-400-B,
# SF-5-B) read as shore stations before this. It does NOT outrank the reviewed
# override list or an MMSI number range, both of which are stronger evidence than
# a match made by this script.
stk14 <-
  stk13 |>
  mutate(.up = !is.na(vid) & entity_class != "vessel" &
                (is.na(basis) | basis == "reconstructed"),
         entity_class = if_else(.up, "vessel", entity_class),
         basis        = if_else(.up, "recorded", basis)) |>
  select(-.up)

stk14 |>
  count(entity_class, basis) |>
  arrange(-n) |>
  knitr::kable(caption = "Entity class (expect no vid outside entity_class == vessel)")
stk14 |>
  filter(!is.na(vid), entity_class != "vessel") |>
  knitr::kable(caption = "vid assigned to a non-vessel (expect none)")

# SAVE THE STUFF ---------------------------------------------------------------
stk14 |>
  mutate(pings = as.integer(pings),
         n_years = as.integer(n_years),
         vid = as.integer(vid),
         no = as.integer(no),
         vid_older = as.integer(vid_older)) |>
  nanoparquet::write_parquet(fd_curated("vessel", "vessel_ais_key.parquet"))
