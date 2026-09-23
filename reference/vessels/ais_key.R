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
#    curated/vessel/vessel.parquet, curated/vessel/vessel_identity.parquet
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
## Call sign prefix - flag state, passed to stk_entity_class() below
cs.prefix.all <-
  read_parquet(fd_staging("aux", "callsign_prefix.parquet"))
## vessel registry
#  should really add skemmtibatar
v_all <-
  read_parquet(fd_curated("vessel", "vessel.parquet")) |>
  mutate(vidc = as.character(vid))
v_mmsi <-
  v_all |>
  filter(!is.na(mmsi))
# One row per mmsi, current holder - used only for the final "stamp an mmsi onto
# every assigned vid" step below, which is a display convenience, not a match.
# The matching itself (NA_mmsi tier) uses vessel_identity, time-aware.
v_mmsi_no_dupes <-
  v_mmsi |>
  arrange(mmsi, desc(mmsi_t2), desc(vid)) |>
  group_by(mmsi) |>
  slice(1) |>
  ungroup()
## Identity periods - the time-aware replacement for v_mmsi's "current value"
#  lookups. See R/vid_match.R for why: a call sign, uid or mmsi is an ATTRIBUTE
#  of a vid at a time, not a fact about the vid forever, and the matching below
#  requires the mobile-id's own [d1,d2] window to overlap the period that
#  actually held the identifier.
vessel_identity <-
  read_parquet(fd_curated("vessel", "vessel_identity.parquet"))

## Known (via ad hoc) non-vessel localid or globalid ---------------------------
# A reviewed *input* - a nine-character truncated Icelandic place name is not
# derivable from anything, so a human decided each row - and AGENTS.md puts
# reviewed inputs in overrides/, not in a script. Passed to stk_entity_class()
# directly below; the per-group vectors the old classification block pulled out
# of it (fixed/kvi/hafro/net_glid/unknown_glid) no longer have a reader now that
# the block is gone.
stk_overrides <- read_stk_overrides()

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


## Entity class ------------------------------------------------------------------
# Computed straight from loid/glid, before any vid is matched - it does not need
# the type string the old classification block built, only to feed it. See
# R/entity_class.R.
stk2 <-
  stk1 |>
  bind_cols(stk_entity_class(stk1$loid, stk1$glid,
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

# Time-aware evidence matching ---------------------------------------------------
# Replaces the flat CS/CS2/CS3/UID/UID2 + v_mmsi "current value" lookups below with
# joins against vessel_identity, constrained by the mobile-id's own [d1,d2] window
# overlapping the period that held the identifier. See R/vid_match.R for why, and
# plan 003 §3.1/§4.1 and decision 015 for what this was blocked on: the classifier
# could not be fixed piecemeal while the rules keyed on its pasted `type` string.
# Every step below fills `vid` only where it is still NA - the manual duals sheet,
# already joined into stk1, keeps first claim - and the tiers are ordered the same
# way the cascade they replace was: agreement, then identifier-plus-corroboration,
# then a bare identifier, then a bare call sign, then a hail mary, then mmsi.
#
# .rid is NOT a unique key by this point - the manual duals join in stk1 can split
# one mobile-id into several period rows carrying the same .rid (see the afmadur
# section below). Joining match results back on .rid would silently conflate those
# rows' evidence, so this section uses its own row key instead.
base <-
  stk3 |>
  mutate(.mrid = dplyr::row_number(),
         .lo = suppressWarnings(as.integer(loid)),
         .gl = suppressWarnings(as.integer(glid)))

## vid_vid / vid2_vid2 - both fields state the same vid, agreeing ----------------
# Not time-gated: a vid is not an attribute at a time, it is the keel itself
# (AGENTS.md - "the vid stays with the vessel from cradle to grave").
stk4a <-
  base |>
  mutate(vid = case_when(
           !is.na(vid) ~ vid,
           loid == glid & !is.na(.lo) & as.character(.lo) %in% VID  ~ as.numeric(.lo),
           .default = vid),
         step = case_when(!is.na(vid) & is.na(step) ~ "vid_vid", .default = step))
stk4a |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk4a |> lh_mmsi_expectations()

# vid2_vid2 - same agreement, for a vid with no MMSI on record (VID2 but not VID:
# the 3700-4999 foreign range, or a domestic vid the registry never gave one).
stk4 <-
  stk4a |>
  mutate(vid = case_when(
           !is.na(vid) ~ vid,
           loid == glid & !is.na(.lo) & as.character(.lo) %in% VID2  ~ as.numeric(.lo),
           .default = vid),
         step = case_when(!is.na(vid) & is.na(step) ~ "vid2_vid2", .default = step))
stk4 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")

## vid_cs / vid2_cs - loid states the vid, glid confirms its call sign -----------
# vid_cs if the vid has an MMSI on record (VID, domestic proper); vid2_cs if it is
# only in VID2 (the 3700-4999 foreign range, or a domestic vid with no MMSI). Both
# use the same time-aware confirmation - this is the fix for TFBR: vessel_identity
# has no row for vid 1473 carrying cs TFBR at all (its holder in 2011 was one of
# 2815 or 3047, per decision 015), so confirm_vid() cannot manufacture a match for
# it the way the old flat v_mmsi$cs column did.
.probe_vc <-
  stk4 |>
  filter(is.na(vid), !is.na(.lo), as.character(.lo) %in% VID2) |>
  transmute(.rid = .mrid, vid = .lo, val = glid, d1, d2)
.hit_vc <- confirm_vid(.probe_vc, vessel_identity, "cs")
stk5 <-
  stk4 |>
  left_join(.hit_vc |> rename(.vid = vid), by = c(".mrid" = ".rid")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid, !is.na(.vid) ~ .vid, .default = vid),
         step = case_when(
           !is.na(vid) & is.na(step) & !is.na(.vid) & as.character(.vid) %in% VID ~ "vid_cs",
           !is.na(vid) & is.na(step) & !is.na(.vid) ~ "vid2_cs",
           .default = step)) |>
  select(-.vid)
stk5 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk5 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## uid_cs - loid is a uid, glid confirms that SAME vid's call sign ---------------
# Both fields must resolve to one vessel_identity period at once (match_identity_pair),
# not two separate single-field matches that happen to agree by chance.
.probe_uc <-
  stk5 |>
  filter(is.na(vid)) |>
  transmute(.rid = .mrid, val1 = loid, val2 = glid, d1, d2)
.hit_uc <- match_identity_pair(.probe_uc, vessel_identity, "uid", "cs")
stk6 <-
  stk5 |>
  left_join(.hit_uc |> rename(.vid = vid), by = c(".mrid" = ".rid")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid, !is.na(.vid) ~ .vid, .default = vid),
         step = case_when(!is.na(vid) & is.na(step) & !is.na(.vid) ~ "uid_cs", .default = step)) |>
  select(-.vid)
stk6 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk6 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_vid - glid states a vid outright, no corroboration required ----------------
# VID membership already requires the vid to have an MMSI on record, which was
# the old step's sanity check.
stk7 <-
  stk6 |>
  mutate(vid = case_when(
           !is.na(vid) ~ vid,
           !is.na(.gl) & as.character(.gl) %in% VID ~ as.numeric(.gl),
           .default = vid),
         step = case_when(!is.na(vid) & is.na(step) ~ "NA_vid", .default = step))
stk7 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk7 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_cs - glid alone matches a call sign, time-aware and unambiguous ------------
.probe_cs <-
  stk7 |>
  filter(is.na(vid)) |>
  transmute(.rid = .mrid, val = glid, d1, d2)
.hit_cs <- match_time_aware(.probe_cs, vessel_identity, "cs")
stk8 <-
  stk7 |>
  left_join(.hit_cs |> rename(.vid = vid), by = c(".mrid" = ".rid")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid, !is.na(.vid) ~ .vid, .default = vid),
         step = case_when(!is.na(vid) & is.na(step) & !is.na(.vid) ~ "NA_csts", .default = step)) |>
  select(-.vid)
stk8 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk8 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## VID_OLDER -----------------------------------------------------------------------
# hail mary, step may be premature
stk10 <-
  stk8 |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         is.na(vid) & !is.na(vid_older) & pings > 100 ~ vid_older,
                         .default = vid)) |>
  mutate(step = case_when(!is.na(vid) & is.na(step) & pings > 100 ~ "older",
                          .default = step))
stk10 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")
stk10 |> filter(!vid %in% 3700:4999) |> lh_mmsi_expectations()

## NA_mmsi - glid is a 9-digit mmsi, time-aware -----------------------------------
# vessel_identity asserts (mmsi, time) resolves to one hull (decision 015), so an
# ambiguous NA_mmsi candidate should not occur - match_time_aware drops it anyway
# if it ever does, same as every step above.
.probe_mmsi <-
  stk10 |>
  filter(is.na(vid)) |>
  transmute(.rid = .mrid,
            val = if_else(numbers_only(glid) & nchar(glid) == 9, glid, NA_character_),
            d1, d2)
.hit_mmsi <- match_time_aware(.probe_mmsi, vessel_identity, "mmsi")
stk11 <-
  stk10 |>
  left_join(.hit_mmsi |> rename(.vid = vid), by = c(".mrid" = ".rid")) |>
  mutate(vid = case_when(!is.na(vid) ~ vid,
                         !is.na(.vid) & pings >= 30 ~ .vid,
                         .default = vid),
         step = case_when(!is.na(vid) & is.na(step) & !is.na(.vid) ~ "NA_mmsi", .default = step)) |>
  select(-.vid)
stk11 |> filter(vid > 0) |> lh_overlaps() |> knitr::kable(caption = "Expect none")

rm(base, .probe_vc, .hit_vc, .probe_uc, .hit_uc, .probe_cs, .hit_cs, .probe_mmsi, .hit_mmsi)
stk11 <- stk11 |> select(-c(.mrid, .lo, .gl)) |> mutate(type = step)

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

# Lifetime flag ----------------------------------------------------------------
# A match is only as good as the hull being alive to make it. curated/vessel/
# vessel_identity.parquet gives each vid the period the Icelandic registry actually
# recognises - the INTERSECTION of the hull's yh1..yh2 and the MMSI's own window,
# because mmsi.R writes 2007-06-01/2028-12-24 as defaults and those are
# placeholders, not evidence.
#
# 81 matches fall outside their hull's period, 1.83 M pings. The first version of
# this withdrew them. That was wrong, and the landings database says so: 20 of the
# 81, carrying 1.39 M of the 1.83 M pings, are vessels that were actively landing
# fish throughout the disputed window. GULLBERG's yh2 is 2013 and it has 1,880
# landings running to 2026; KRISTRUN's yh1 and yh2 are both 2021 and it lands
# through 2026. The registry lifetime is stale, not the match.
#
# So this FLAGS. Per AGENTS.md a correction adds a column and never overwrites, and
# the cycle rule means the choice between "stale registry" and "wrong match" is a
# human's, made once, entering through overrides/. curate/checks/ais_key_registry.R
# reports the 81 with the landings evidence beside them.
.idy <-
  read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  group_by(vid) |>
  summarise(i_t1 = min(t1), i_t2 = max(t2), .groups = "drop")
stk11d <-
  stk11c |>
  left_join(.idy, by = "vid") |>
  mutate(lifetime_conflict = !is.na(vid) & vid > 0 & coalesce(step, "") != "afmadur" &
           (is.na(i_t1) | as.Date(d1) > i_t2 | as.Date(d2) < i_t1),
         lifetime_note = case_when(
           !lifetime_conflict    ~ NA_character_,
           is.na(i_t1)           ~ "hull has no period in the registry during the STK era",
           .default              = "mobile-id active wholly outside the hull's registry period")) |>
  select(-c(i_t1, i_t2))
stk11d |>
  filter(lifetime_conflict) |>
  select(mid, loid, glid, vid, step, lifetime_note, pings, d1, d2) |>
  arrange(-pings) |>
  knitr::kable(caption = "Matched to a hull the registry says was not there then")

# Add MMSI to Icelandic vessels ------------------------------------------------
stk12 <-
  stk11d |>
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
