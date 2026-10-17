# The STK mobile-id -> vid assignment rebuilt as a SEGMENT TABLE that tiles every mobile-id.
# Side: once (vessel key). See plan 014.
#
# Input:  curated/vessel/{vessel_ais_key,vessel_identity}.parquet, raw/oracle/stk/trail (stk_trail()),
#         staging/skipaskra/annual_call_sign.parquet,
#         curated/check/ais_key_split_candidates.parquet, curated/check/ais_key_audit_w1.parquet,
#         curated/check/ais_key_audit_lb_{hits,n}.parquet (logbook and landings per month),
# Output: curated/check/ais_key_segments.parquet - one row per segment of a mobile-id
#
# Plan 009 phase 2. The maintainer's invariant: a mobile-id that has a vessel has a
# vessel for its FULL period, first ping to last, so no ping is unassigned. A segment table
# satisfies that by construction: cut each mobile-id's timeline, and every stretch between cuts
# gets a vid.
#
# CUTS (over-cutting is harmless - two neighbouring segments of one vid are merged):
#   * a silence of >= 180 days where the split reader fires >= 2 families
#     (ais_key_split_candidates: 'strong' >= 3, 'review' = 2);
#   * a change of the vid that W1 (the vid's own other-provider AIS, co-located with the
#     mobile-id) confirms, cut in the middle of the months between the two confirmed runs;
#   * a silence of a year or more; a candidate vid's registration day; a change of the annual register's holder;
#   * the edges of a reviewed row (since the key redo of 2026-10-17).
# A segment starts on the first ping after a silence, so the silence belongs to the segment
# before it and the periods touch exactly.
#
# THE VID OF A SEGMENT, best evidence first, with the source recorded:
#   0. reviewed   a person's verdict in overrides/ais_key_segments_reviewed.csv replaces the vid (an input);
#   1. physical   W1 confirms a vid in >= 3 months of the segment;
#   2. registry   the registry gives the mobile-id's own call sign or MMSI to one vid over it; for 2007-2022
#                 the annual ship register dates the holder by year and outranks the identity windows. An SKB
#                 code in the mobile-id's own identifier is its registration, vid 100000 + n, over its whole span;
#   3. logbook    one vid's logbook stations explain >= 80 % of its stations over the segment, by a
#                 clear margin (>= 0.1) over every other vid, with >= 30 stations - calibrated at
#                 year level (decision 047); landings alone count only at >= 90 % with a margin of
#                 0.3, because a vessel that calls at every port (a ferry) otherwise wins them all;
#   4. continuity the key's vid for that stretch (never left empty - the weakest grade). For an
#                 ICELANDIC vid the key rows that came from the ODS are NOT used here (the ODS is
#                 given up as an input, plan 009 phase 5): a stretch with no evidence borrows the vid
#                 of the neighbouring segment of the same mobile-id, flagged by its source, also where that
#                 vessel's registered lifetime does not cover it (since 2026-10-17). FOREIGN
#                 vessels (vids 3700-4999 only; Icelandic vids resume above 4999) have no other
#                 evidence, so their matches are read from overrides/stk_foreign_mid_vid.csv, which
#                 keeps them without the ODS file (extracted once, unchanged), and are labelled
#                 `foreign: kept override`.
# A negative key vid (an ODS `drop`) is NOT decided by a rule: it stays NA and is listed.
# `vid_no_ods` is the same rule with the ODS-sourced key rows removed from the continuity step; it
# is kept only so the dependence on those rows stays visible. The ODS is not a judge of this table
# (maintainer, 2026-09-29): disagreements with it are decided on evidence, like any other.
#
# `device` marks gear devices (an MMSI of class 941/99/97): not vessels, but the link to the carrying vid is kept.
#
# ACCEPTANCE (asserted): the segments tile every mobile-id with no gap or overlap; every ping is
# in exactly one segment; and pings outside a vid are only those on an explicit drop.
# This check REPORTS. It never writes a vid into the key; a reviewed table replaces the ODS as an
# input only when plan 009 phase 5 says so.
#
# Identifiers are vid and MMSI. Names are not read.

library(dplyr)
library(tidyr)
library(nanoparquet)

STK <- stk_trail_sql()   # R/stk_trail.R: the trail in its preferred form, read as `from (%s)`
MIN_W1_MONTHS <- 3L   # months of W1 confirmation that name a vid over a segment
STARTUP_END <- as.Date("2009-01-01")

# Every input is sorted on all its columns as it is read. The steps below keep "the first" row of a tie in
# places (distinct(.keep_all = TRUE), slice(1), x[1]), so the result depended on the row order of the files,
# which the audit does not fix: the same evidence in another row order moved segment boundaries by a month or
# two (2026-10-08, plan 013 phase 2; decision 070 had read this as a loop in the key). Sorting makes the result
# the same every run; which row SHOULD win each tie is an open question (plan 013, logic questions).
read_parquet <- function(...) {
  d <- nanoparquet::read_parquet(...)
  d[do.call(order, unname(as.list(d))), , drop = FALSE]
}

key <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
ident <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  transmute(hvid = as.integer(vid), cs, mmsi, t1 = as.Date(t1), t2 = as.Date(t2), window_basis)
cand <- read_parquet(fd_curated("check", "ais_key_split_candidates.parquet"))
# The day each hull was first registered (the registry's own, day-exact). A call sign follows its hull, so a
# vid cannot be carried by a mobile-id before this date. Measured (decision 048): with this date 0 of 32 reuse
# cases have the successor registered AFTER the switch W1 sees, and 25 fall inside the switch's bracket; the
# identification date is not the hull's start (a hull that changed home port looks newly registered).
hull_start <- read_parquet(fd_raw("oracle", "vessel", "vessel_hist_v.parquet")) |>
  filter(!is.na(registration_no)) |> group_by(registration_no) |> arrange(desc(valid_from)) |> slice(1) |> ungroup() |>
  transmute(vid = as.integer(registration_no), reg_start = as.Date(initial_registration_date))
reg_start_of <- function(v) hull_start$reg_start[match(v, hull_start$vid)]
life <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> transmute(nvid = as.integer(vid), yh1, yh2)
HORIZON <- max(life$yh2, na.rm = TRUE)
ym_of <- function(d) { lt <- as.POSIXlt(d); (lt$year + 1900L) * 12L + lt$mon }   # yh2 never exceeds the registry snapshot horizon: an end AT it is not an end
foreign_keep <- read.csv("overrides/stk_foreign_mid_vid.csv") |>
  transmute(mid, fvid = as.integer(vid), fd1 = as.Date(d1), fd2 = as.Date(d2))
w1 <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet"))
lb_hits <- read_parquet(fd_curated("check", "ais_key_audit_lb_hits.parquet"))
lb_n <- read_parquet(fd_curated("check", "ais_key_audit_lb_n.parquet"))

con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
days <- dplyr::as_tibble(DBI::dbGetQuery(con, sprintf(
  "select mid, cast(time as date) d, count(*) n from (%s) where time >= timestamp '2007-06-01' group by 1, 2 order by 1, 2", STK)))
DBI::dbDisconnect(con, shutdown = TRUE)

# the mobile-id's OWN identifier strings: a call sign (TF + two letters), a 9-digit MMSI, or an SKB code
# (SKB271, skb222, SKB009_MF -> vid 100000 + n; the 99xx placeholder excluded, as in the cascade's `skb` step)
tok <- key |>
  pivot_longer(c(loid, glid), values_to = "s") |>
  filter(!is.na(s)) |> mutate(s = toupper(trimws(s))) |>
  transmute(mid, cs = if_else(grepl("^TF[A-Z]{2}$", s), s, NA_character_),
            mmsi = if_else(grepl("^[0-9]{9}$", s), s, NA_character_),
            skb = suppressWarnings(as.integer(sub("^SKB([0-9]+).*$", "\\1", if_else(grepl("^SKB[0-9]", s), s, NA_character_))))) |>
  mutate(skb = if_else(skb < 9900L, 100000L + skb, NA_integer_)) |>
  filter(!is.na(cs) | !is.na(mmsi) | !is.na(skb)) |> distinct()
holders <- bind_rows(
  tok |> filter(!is.na(cs))   |> inner_join(filter(ident, !is.na(cs)),   by = "cs",   relationship = "many-to-many") |> select(mid, hvid, t1, t2, window_basis),
  tok |> filter(!is.na(mmsi)) |> inner_join(filter(ident, !is.na(mmsi)), by = "mmsi", relationship = "many-to-many") |> select(mid, hvid, t1, t2, window_basis),
  # an SKB code is the registration itself, stated by the unit: it holds for the unit's whole span (key redo of
  # 2026-10-17; before it no SKB unit had a vid)
  tok |> filter(!is.na(skb)) |> transmute(mid, hvid = skb, t1 = as.Date("1900-01-01"), t2 = as.Date("2100-12-31"),
                                          window_basis = "skb code")) |>
  distinct()

# The annual ship register dates a call sign's holder by YEAR over 2007-2022 (sources/skipaskra). A register
# year Y is the state at the START of year Y (~Y-01-01), NOT Y-12-31. Measured (decision 049): no hull
# registered in 2008-2022 is listed in the year it was registered, nearly all the year after (even January
# registrations; asserted below), and of the vessels AIS still hears, 61 were last heard in their last listed
# year against 4 the year after. So a holder listed from Y1 to Y2 held the call sign on Y1-01-01 .. Y2-01-01,
# took it at some point in Y1-1 (the previous holder's last listed year is Y1-1) and lost it at some point in
# Y2. The run is a window [Y1-1-01-01, Y2-12-31]; two neighbouring holders overlap in the handover year, and a
# segment that touches both gets none from the register and is left to the other evidence. It outranks the
# identity windows (decision 049).
annual <- read_parquet(fd_staging("skipaskra", "annual_call_sign.parquet")) |> transmute(cs, vid = as.integer(vid), year)
ann_h <- tok |> filter(!is.na(cs)) |> inner_join(annual, by = "cs", relationship = "many-to-many") |>
  distinct(mid, hvid = vid, year) |> arrange(mid, hvid, year) |>
  group_by(mid, hvid) |> mutate(run = cumsum(year - lag(year, default = first(year)) > 1L)) |>
  group_by(mid, hvid, run) |>
  summarise(t1 = as.Date(sprintf("%d-01-01", min(year) - 1L)), t2 = as.Date(sprintf("%d-12-31", max(year))), .groups = "drop") |>
  mutate(window_basis = "annual register") |> select(-run)
holders <- bind_rows(holders, ann_h)

# A mobile-id is in scope when the key gives it a vessel, OR when W1 confirms a vid on it in >= 3 months
# although the key gave it none (e.g. an identifier typo), unless the key classes it as a device.
key_class <- key |> group_by(mid) |> summarise(entity_class = names(sort(table(entity_class), decreasing = TRUE))[1], .groups = "drop")
w1_named <- w1 |> filter(score >= .8) |> count(mid, vid) |> filter(n >= 3) |> distinct(mid) |>
  left_join(key_class, by = "mid") |> filter(is.na(entity_class) | entity_class %in% c("vessel", "unknown")) |> pull(mid)
# ... or when the REGISTRY names it: the mobile-id's own call sign or MMSI belongs to a registered vid
# (mid 101444 = call sign TFGA, no vid in the key because its other field is only 'RE').
reg_named <- holders |> distinct(mid) |> left_join(key_class, by = "mid") |>
  filter(is.na(entity_class) | entity_class %in% c("vessel", "unknown")) |> pull(mid)
# ... or when a kept foreign match names it: the ODS used to put these in the key, and it no longer exists
foreign_mids <- foreign_keep$mid
has_vessel <- Reduce(union, list(key |> filter(!is.na(vid), vid > 0) |> distinct(mid) |> pull(mid), w1_named, reg_named, foreign_mids))
span <- days |>
  filter(mid %in% has_vessel) |>
  group_by(mid) |>
  summarise(first = min(d), last = max(d), total = sum(n), .groups = "drop")
# a valid key row has d1 <= d2; an inverted row (a typo) covers nothing
kv <- key |> filter(mid %in% has_vessel, !is.na(vid), d1 <= d2) |>
  select(mid, kvid = vid, kd1 = d1, kd2 = d2, kstep = step)
end_of <- kv |> group_by(mid) |> summarise(kend = max(kd2), .groups = "drop")

## Cuts ------------------------------------------------------------------------------------------
cut_silence <- cand |>
  filter(tier %in% c("strong", "review"), mid %in% has_vessel) |>
  transmute(mid, cut = as.Date(d_next),
            basis = paste0("silence of ", gap, " d, ", n_families, " families"))

st <- w1 |>
  filter(score >= .8, mid %in% has_vessel) |>
  transmute(mid, vid, y, m, ym = y * 12L + m - 1L, md = as.Date(sprintf("%d-%02d-15", y, m)))
blocks <- function(d) {
  d |> arrange(mid, ym) |> group_by(mid) |>
    mutate(blk = cumsum(vid != lag(vid, default = first(vid)))) |>
    group_by(mid, vid, blk) |>
    summarise(a = min(ym), b = max(ym), n = n(), .groups = "drop")
}
# drop isolated months of a neighbour first, so a lone month cannot cut a long run
b1 <- blocks(st) |> filter(n >= MIN_W1_MONTHS)
st2 <- st |>
  inner_join(select(b1, mid, vid, a, b), by = c("mid", "vid"), relationship = "many-to-many") |>
  filter(ym >= a, ym <= b) |> distinct(mid, vid, ym, .keep_all = TRUE)
chg <- blocks(st2) |>
  filter(n >= MIN_W1_MONTHS) |>
  arrange(mid, a) |> group_by(mid) |>
  mutate(next_a = lead(a), next_vid = lead(vid)) |> ungroup() |>
  filter(!is.na(next_a), next_vid != vid)
cut_w1 <- chg |>
  transmute(mid, prev_end = b, next_start = next_a, mi = (b + 1L + next_a) %/% 2L,
            cut = as.Date(sprintf("%d-%02d-01", mi %/% 12L, mi %% 12L + 1L)),
            basis = "W1 confirms a different vid from here; date placed mid-way between the two runs")
# a silence between the two runs already carries the change: do not cut twice
cut_w1 <- cut_w1 |>
  left_join(cut_silence, by = "mid", relationship = "many-to-many", suffix = c("", "_s")) |>
  group_by(mid, cut, basis, prev_end, next_start) |>
  summarise(covered = any(!is.na(cut_s) & cut_s >= as.Date(sprintf("%d-%02d-01", prev_end %/% 12L, prev_end %% 12L + 1L)) &
                          cut_s <= as.Date(sprintf("%d-%02d-28", next_start %/% 12L, next_start %% 12L + 1L))), .groups = "drop") |>
  filter(!covered) |> transmute(mid, cut, basis)
# A silence of a year or more is cut whatever the split reader says: measured, 20 % (>= 365 d) to 35 %
# (>= 730 d) of them are a change of vessel, and a cut that changes nothing is merged away again.
cut_long <- days |>
  filter(mid %in% has_vessel) |> arrange(mid, d) |> group_by(mid) |>
  mutate(gap = as.numeric(d - lag(d))) |> ungroup() |>
  filter(!is.na(gap), gap >= 365) |>
  transmute(mid, cut = d, basis = paste0("silence of ", gap, " d (any silence of a year or more is cut)"))
# A candidate vid's registration date is a cut: nothing before it can be that vessel
cand_vids <- bind_rows(distinct(st, mid, vid), distinct(holders, mid, vid = hvid),
                       key |> filter(!is.na(vid), vid > 0) |> distinct(mid, vid) |> mutate(vid = as.integer(vid)))
cut_reg <- cand_vids |>
  mutate(reg_start = reg_start_of(vid)) |> filter(!is.na(reg_start)) |>
  inner_join(span, by = "mid") |> filter(reg_start > first, reg_start <= last) |>
  transmute(mid, cut = reg_start, basis = paste0("vid ", vid, " was registered on this day"))
# ASSERTED, not assumed: a hull's first register year is the year AFTER it was registered (state at the start
# of the year). Same-year listings would mean a Y-12-31 state.
first_listed <- annual |> group_by(vid) |> summarise(y1 = min(year), .groups = "drop") |>
  inner_join(mutate(hull_start, ry = as.integer(format(reg_start, "%Y"))), by = "vid") |> filter(ry >= 2008, ry <= 2022) |> mutate(lag = y1 - ry)
print(first_listed |> count(lag) |> knitr::kable(caption = "first register year minus registration year (hulls registered 2008-2022)"))
stopifnot("register year is not the start-of-year state" = mean(first_listed$lag == 0) < .05 && mean(first_listed$lag == 1) > .6)
# The annual register's holder of the mobile-id's call sign changes: cut at the year boundary (the register
# cannot say where inside the year; anything physical outranks it)
cut_ann <- ann_h |> arrange(mid, t1) |> group_by(mid) |>
  filter(hvid != lag(hvid, default = first(hvid))) |> ungroup() |>
  inner_join(span, by = "mid") |> filter(t1 > first, t1 <= last) |>
  transmute(mid, cut = t1, basis = paste0("annual register: vid ", hvid, " holds the call sign from this year"))
# A reviewed row's edges are cuts (the maintainer, 2026-10-17, for mid 108982): a person's verdict on a stretch
# places its boundaries as well as its vid. Before the key redo of 2026-10-17 a reviewed row only replaced the vid
# of the segments lying mostly inside it, so it could not move a boundary the rules had drawn.
ov <- read.csv("overrides/ais_key_segments_reviewed.csv") |> transmute(mid, ovid = as.integer(vid), od1 = as.Date(d1), od2 = as.Date(d2))
cut_ov <- bind_rows(ov |> transmute(mid, cut = od1, basis = paste0("a reviewed row gives vid ", ovid, " from this day")),
                    ov |> transmute(mid, cut = od2 + 1L, basis = paste0("a reviewed row gives vid ", ovid, " to the day before")))
cuts <- bind_rows(cut_ov, cut_silence, cut_w1, cut_long, cut_reg, cut_ann)

## Segments --------------------------------------------------------------------------------------
cuts <- cuts |> distinct(mid, cut, .keep_all = TRUE)
frame <- span |>
  left_join(end_of, by = "mid") |>
  transmute(mid, first, last, end = pmax(coalesce(kend, as.Date("2028-12-24")), last))
segs <- bind_rows(
  frame |> transmute(mid, d1 = first, end),
  cuts |> inner_join(frame, by = "mid") |> filter(cut > first, cut <= last) |> transmute(mid, d1 = cut, end)) |>
  distinct(mid, d1, .keep_all = TRUE) |>
  arrange(mid, d1) |>
  group_by(mid) |>
  mutate(d2 = coalesce(lead(d1) - 1L, end), seg_no = row_number()) |>
  ungroup() |>
  select(mid, seg_no, d1, d2)
seg_basis <- segs |>
  left_join(distinct(cuts, mid, cut, basis), by = c("mid", "d1" = "cut")) |>
  transmute(mid, seg_no, boundary_basis = coalesce(basis, "first ping"))

## Evidence per segment --------------------------------------------------------------------------
# Months a segment is ACTIVE (has STK pings): a short segment cannot have 3 confirmed months
seg_active <- segs |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  distinct(mid, seg_no, ym = ym_of(d)) |>
  count(mid, seg_no, name = "active_months")
# W1 names a vid in a segment with >= 3 confirmed months, or >= 2 when they are >= 80 % of the months
# the segment is active (a brief reappearance, e.g. two months in 2014)
w1_all <- segs |>
  inner_join(select(st, mid, vid, md), by = "mid", relationship = "many-to-many") |>
  filter(md >= d1, md <= d2) |>
  count(mid, seg_no, vid, name = "k") |>
  left_join(seg_active, by = c("mid", "seg_no")) |>
  filter(k >= MIN_W1_MONTHS | (k >= 2 & k >= .8 * active_months)) |>
  select(-active_months)

# A call sign has ONE holder at a time, but the registry's own dated call-sign history only begins on
# 2023-12-19 (the day it was loaded), so it cannot date a reuse in the STK era: `vessel_identity` takes its
# time from hull lifetime and the MMSI archive's windows. Holders are therefore ranked by how well their
# window is DATED - a vid with a hull lifetime and an MMSI window outranks one the registry has no dates for
# ('unbounded') - and the segment goes to the single best-dated holder over it.
BASIS_RANK <- c(`annual register` = 4L, both = 3L, hull_lifetime = 2L, mmsi_window = 2L, unbounded = 1L)
reg_seg <- segs |>
  inner_join(holders, by = "mid", relationship = "many-to-many") |>
  filter(t1 <= d2, t2 >= d1) |>
  mutate(rank = coalesce(BASIS_RANK[window_basis], 1L)) |>
  group_by(mid, seg_no) |>
  filter(rank == max(rank)) |>
  summarise(reg_vid = if (n_distinct(hvid) == 1) hvid[1] else NA_integer_, reg_basis = window_basis[1], .groups = "drop") |>
  filter(!is.na(reg_vid))

ym_of <- function(d) { lt <- as.POSIXlt(d); (lt$year + 1900L) * 12L + lt$mon }
# months whose 15th lies inside the segment; a segment shorter than that cannot be scored
segm <- segs |>
  mutate(m1 = ym_of(d1) + (as.POSIXlt(d1)$mday > 15L), m2 = ym_of(d2) - (as.POSIXlt(d2)$mday < 15L)) |>
  filter(m2 >= m1) |> select(mid, seg_no, m1, m2)
hh <- lb_hits |> filter(mid %in% has_vessel) |> mutate(ym = y * 12L + m - 1L)
nn <- lb_n |> mutate(ym = y * 12L + m - 1L)
cand_hits <- segm |>
  inner_join(hh, by = "mid", relationship = "many-to-many") |>
  filter(ym >= m1, ym <= m2) |>
  group_by(mid, seg_no, witness, vid, m1, m2) |> summarise(hits = sum(hits), .groups = "drop")
cand_n <- cand_hits |>
  distinct(mid, seg_no, witness, vid, m1, m2) |>
  inner_join(nn, by = c("witness", "vid"), relationship = "many-to-many") |>
  filter(ym >= m1, ym <= m2) |>
  group_by(mid, seg_no, witness, vid) |> summarise(n = sum(n), .groups = "drop")
lb_sc <- cand_hits |>
  inner_join(cand_n, by = c("mid", "seg_no", "witness", "vid")) |>
  mutate(s = hits / n) |>
  filter((witness == "w2" & n >= 30) | (witness == "w3" & n >= 15))
pick <- function(d, thr, margin) {
  d |> group_by(mid, seg_no) |> arrange(desc(s), desc(n), .by_group = TRUE) |>
    summarise(lb_vid = vid[1], lb_s = s[1], lb_n = n[1], lb_margin = s[1] - if (n() > 1) s[2] else 0, .groups = "drop") |>
    filter(lb_s >= thr, lb_margin >= margin)
}
lb_w2 <- lb_sc |> filter(witness == "w2") |> pick(.8, .1) |> mutate(lb_src = "logbook")
lb_w3 <- lb_sc |> filter(witness == "w3") |> pick(.9, .3) |> mutate(lb_src = "landings") |> anti_join(lb_w2, by = c("mid", "seg_no"))
lb_seg <- bind_rows(lb_w2, lb_w3) |> select(mid, seg_no, lb_vid, lb_src, lb_s, lb_n)

# what the key already says for the stretch: the row overlapping it most, else the nearest
key_seg <- segs |>
  inner_join(kv, by = "mid", relationship = "many-to-many") |>
  mutate(overlap = pmax(0, as.numeric(pmin(d2, kd2) - pmax(d1, kd1)) + 1),
         dist = pmax(0, as.numeric(kd1 - d2), as.numeric(d1 - kd2))) |>
  group_by(mid, seg_no) |>
  arrange(desc(overlap), dist, .by_group = TRUE) |>
  slice(1) |> ungroup() |>
  transmute(mid, seg_no, key_vid = kvid, key_step = kstep)

foreign_seg <- segs |>
  inner_join(foreign_keep, by = "mid", relationship = "many-to-many") |>
  mutate(overlap = pmax(0, as.numeric(pmin(d2, fd2) - pmax(d1, fd1)) + 1), dist = pmax(0, as.numeric(fd1 - d2), as.numeric(d1 - fd2))) |>
  group_by(mid, seg_no) |> arrange(desc(overlap), dist, .by_group = TRUE) |> slice(1) |> ungroup() |>
  transmute(mid, seg_no, foreign_vid = fvid)

# When W1 confirms SEVERAL vids over a segment (a tug and its tow travel together and both fit), the
# vid the key already names wins if it is among them, then the one with most months, and on a tie the
# vid the registry names for the stretch (mid 103251: a tug and its tow, 16 months each; the annual register
# gives the call sign to the tow). The key's ODS-sourced rows are not used for that.
w1_seg <- w1_all |>
  left_join(key_seg |> transmute(mid, seg_no, kf = if_else(coalesce(key_step, "") == "manuals", NA_integer_, key_vid)),
            by = c("mid", "seg_no")) |>
  left_join(select(reg_seg, mid, seg_no, rg = reg_vid), by = c("mid", "seg_no")) |>
  group_by(mid, seg_no) |>
  arrange(desc(vid == kf & !is.na(kf)), desc(k), desc(vid == rg & !is.na(rg)), .by_group = TRUE) |>
  summarise(w1_vid = vid[1], w1_months = k[1], twin_vid = if (n() > 1) vid[2] else NA_integer_, .groups = "drop")

pings <- segs |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  group_by(mid, seg_no) |> summarise(pings = sum(n), .groups = "drop")

tbl <- segs |>
  left_join(seg_basis, by = c("mid", "seg_no")) |>
  left_join(w1_seg, by = c("mid", "seg_no")) |>
  left_join(reg_seg, by = c("mid", "seg_no")) |>
  left_join(lb_seg, by = c("mid", "seg_no")) |>
  left_join(key_seg, by = c("mid", "seg_no")) |>
  left_join(foreign_seg, by = c("mid", "seg_no")) |>
  left_join(pings, by = c("mid", "seg_no")) |>
  mutate(pings = coalesce(pings, 0L),
         # a vid cannot be given to a stretch that STARTS more than 60 days before the vessel was registered
         w1_vid  = if_else(!is.na(w1_vid)  & !is.na(reg_start_of(w1_vid))  & reg_start_of(w1_vid)  > d1 + 60, NA_integer_, w1_vid),
         reg_vid = if_else(!is.na(reg_vid) & !is.na(reg_start_of(reg_vid)) & reg_start_of(reg_vid) > d1 + 60, NA_integer_, reg_vid),
         lb_vid  = if_else(!is.na(lb_vid)  & !is.na(reg_start_of(lb_vid))  & reg_start_of(lb_vid)  > d1 + 60, NA_integer_, lb_vid),
         ods_key = !is.na(key_step) & key_step == "manuals" & !is.na(key_vid) & key_vid > 0,
         is_foreign = !is.na(key_vid) & key_vid %in% 3700:4999,
         # continuity may use the key's vid unless the key row came from the ODS (that file is not an input)
         # ... and never a vid whose vessel was not yet registered: the key itself does this (mid 102284 is given
         # vid 2917 from 2007, registered 2017), so continuity must not repeat it
         key_free = if_else(ods_key | (!is.na(reg_start_of(key_vid)) & reg_start_of(key_vid) > d1 + 60), NA_integer_, key_vid),
         drop_seg = !is.na(key_vid) & key_vid <= 0 & is.na(w1_vid) & is.na(reg_vid) & is.na(lb_vid),
         vid = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, !is.na(lb_vid) ~ lb_vid, drop_seg ~ NA_integer_, !is.na(key_free) ~ key_free, .default = foreign_vid),
         source = case_when(!is.na(w1_vid) ~ "physical", !is.na(reg_vid) ~ "registry", !is.na(lb_vid) ~ lb_src, drop_seg ~ "drop: a person decides",
                            # a foreign match the cascade reaches on its own is still the kept override: same vid, named for what it is
                            !is.na(foreign_vid) & (is.na(key_free) | key_free == foreign_vid) ~ "foreign: kept override", .default = "continuity"),
         vid_no_ods = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, !is.na(lb_vid) ~ lb_vid, drop_seg ~ NA_integer_,
                                !ods_key & key_vid > 0 ~ key_vid, .default = NA_integer_))
# An Icelandic stretch with no evidence and no ODS-free key row borrows its neighbour's vid: the one before it, or for
# the first stretch the one after. Where that vessel did not EXIST then (its registered lifetime does not cover the
# segment) the stretch was left for a person until the key redo of 2026-10-17. The maintainer chose then to fill it as
# well (ais_key_coverage's proposal; the invariant is no unassigned ping), under a source of its own so a reader sees it.
tbl <- tbl |>
  arrange(mid, seg_no) |>
  group_by(mid) |>
  mutate(need = is.na(vid) & !drop_seg, vid_nb = vid) |>
  tidyr::fill(vid_nb, .direction = "downup") |>
  ungroup() |>
  left_join(life, by = c("vid_nb" = "nvid")) |>
  mutate(nb_alive = (is.na(reg_start_of(vid_nb)) | reg_start_of(vid_nb) <= d1 + 60) &
                    (is.na(yh1) | (yh1 <= as.integer(format(d2, "%Y")) + 1L &
                                   (is.na(yh2) | yh2 >= HORIZON | yh2 >= as.integer(format(d1, "%Y")) - 1L))),
         fill_ok = need & !is.na(vid_nb),
         vid = if_else(fill_ok, vid_nb, vid),
         source = case_when(fill_ok & nb_alive ~ "continuity: neighbour",
                            fill_ok ~ "continuity: neighbour, outside its registered lifetime",
                            .default = source),
         agrees_key = coalesce(vid == key_vid, FALSE)) |>
  select(-yh1, -yh2, -vid_nb, -nb_alive, -fill_ok)

# Reviewed segments (overrides/ais_key_segments_reviewed.csv): a person's verdict on a stretch, read as an INPUT,
# never computed. It replaces the vid of any segment that lies mostly (>= 50 % of its days) inside a reviewed row.
ov_seg <- tbl |> select(mid, seg_no, d1, d2) |>
  inner_join(ov, by = "mid", relationship = "many-to-many") |>
  mutate(ov_days = pmax(0, as.numeric(pmin(d2, od2) - pmax(d1, od1)) + 1)) |>
  filter(ov_days >= .5 * (as.numeric(d2 - d1) + 1)) |>
  group_by(mid, seg_no) |> slice_max(ov_days, n = 1, with_ties = FALSE) |> ungroup() |> select(mid, seg_no, ovid)
tbl <- tbl |> left_join(ov_seg, by = c("mid", "seg_no")) |>
  mutate(source = if_else(!is.na(ovid), "reviewed", source), vid = coalesce(ovid, vid),
         vid_no_ods = if_else(!is.na(ovid), ovid, vid_no_ods), agrees_key = coalesce(vid == key_vid, FALSE)) |>
  select(-ovid)

SRC <- c("reviewed", "physical", "registry", "logbook", "landings", "continuity", "continuity: neighbour", "continuity: neighbour, outside its registered lifetime", "foreign: kept override", "drop: a person decides")
# two neighbouring segments of one vid are one segment
merged <- tbl |>
  arrange(mid, seg_no) |>
  group_by(mid) |>
  # a fill outside the neighbour's lifetime stays a segment of its own, so its source is not merged away
  mutate(sig = paste(vid, vid_no_ods, source == "continuity: neighbour, outside its registered lifetime"),
         grp = cumsum(is.na(vid) | is.na(lag(vid)) | sig != lag(sig))) |>
  group_by(mid, grp) |>
  summarise(d1 = min(d1), d2 = max(d2), vid = vid[1],
            source = SRC[min(match(source, SRC))],
            key_vid = key_vid[which.max(pings)], vid_no_ods = vid_no_ods[1],
            w1_months = sum(w1_months, na.rm = TRUE), twin_vid = twin_vid[!is.na(twin_vid)][1],
            boundary_basis = boundary_basis[1], pings = sum(pings), .groups = "drop") |>
  group_by(mid) |> mutate(seg_no = row_number()) |> ungroup() |>
  mutate(agrees_key = coalesce(vid == key_vid, FALSE),
         startup_phase = d1 < STARTUP_END,
         grade = case_when(source %in% c("reviewed", "physical") ~ "A", source %in% c("registry", "logbook") ~ "B", source == "landings" ~ "C", source %in% c("continuity", "continuity: neighbour", "continuity: neighbour, outside its registered lifetime") ~ "D", source == "foreign: kept override" ~ "E", .default = "-")) |>
  select(mid, seg_no, d1, d2, vid, source, grade, key_vid, agrees_key, vid_no_ods, w1_months, twin_vid,
         boundary_basis, startup_phase, pings)
# What the annual register says over each final segment, whatever decided it: the one vid that holds the
# mobile-id's call sign in the years the segment touches (NA when none or several). A segment whose vid
# differs is listed for a person - the register is dated by year only, so it is evidence, not a judge.
# Compared over the CORE of each run only - the span the register certainly places the holder in, Y1-01-01 to
# Y2-01-01. The wider window (a year either side) is where the handover happens, so a segment that lies in it
# is a handover, not a disagreement.
ann_core <- ann_h |> mutate(t1 = as.Date(sprintf("%d-01-01", as.integer(format(t1, "%Y")) + 1L)), t2 = as.Date(sprintf("%d-01-01", as.integer(format(t2, "%Y")))))
ann_seg <- merged |> select(mid, seg_no, d1, d2) |>
  inner_join(ann_core, by = "mid", relationship = "many-to-many") |> filter(t1 <= d2, t2 >= d1) |>
  group_by(mid, seg_no) |> summarise(annual_vid = if (n_distinct(hvid) == 1) hvid[1] else NA_integer_, .groups = "drop")
# Gear devices are not vessels (maintainer, 2026-09-30) but keep their link to the vid that carries them: the
# vid stays on the row, `device` marks it, and a consumer of VESSEL pings filters on `!device`. A mobile-id is a
# device when its own identifier is an MMSI of a class that is not a ship station: 941xxxxxx, 99xxxxxxx
# (aids to navigation) or 97xxxxxxx (AIS-SART, MOB, EPIRB) - a fishing-gear tracker rides its boat while deployed,
# so its position only partly matches the carrier's.
device_mids <- key |> pivot_longer(c(loid, glid), values_to = "s") |>
  filter(grepl("^(941|99|97)[0-9]{6}$", trimws(s))) |> distinct(mid) |> pull(mid)
merged <- merged |> left_join(key_class, by = "mid") |> mutate(device = mid %in% device_mids) |>
  left_join(ann_seg, by = c("mid", "seg_no")) |>
  mutate(annual_disagrees = !is.na(annual_vid) & !is.na(vid) & annual_vid != vid & source != "reviewed")
print(merged |> summarise(segments_with_annual_holder = sum(!is.na(annual_vid)), agree = sum(!is.na(annual_vid) & !annual_disagrees, na.rm = TRUE),
                          disagree = sum(annual_disagrees), pings_disagree = sum(pings[annual_disagrees])) |> knitr::kable(caption = "annual register vs the table"))

## Registration-date cuts inside a witnessed run -------------------------------------------------
# A segment that starts on a vid's registration day while W1 still confirms the PREVIOUS segment's vid inside it: the
# registration says only that the new vessel cannot be there before, not that the old one left (TODO 25, mid 108982:
# 7830 registered 2018-04-13, 2835's own astdB on the mid to 2018-07-19). Listed for a person (the maintainer,
# 2026-10-17); a reviewed row moves such a boundary.
rc <- merged |> arrange(mid, seg_no) |> group_by(mid) |> mutate(prev_vid = lag(vid)) |> ungroup() |>
  filter(grepl("was registered on this day$", boundary_basis), !is.na(prev_vid), !is.na(vid), prev_vid != vid) |>
  select(mid, seg_no, d1, d2, prev_vid) |>
  inner_join(select(st, mid, wvid = vid, md), by = "mid", relationship = "many-to-many") |>
  filter(wvid == prev_vid, md >= d1, md <= d2) |>
  distinct(mid, seg_no) |> mutate(reg_cut_in_w1_run = TRUE)
merged <- merged |> left_join(rc, by = c("mid", "seg_no")) |> mutate(reg_cut_in_w1_run = coalesce(reg_cut_in_w1_run, FALSE))
cat("\nRegistration-date boundaries inside the earlier holder's W1 run (for review):", sum(merged$reg_cut_in_w1_run), "on",
    n_distinct(merged$mid[merged$reg_cut_in_w1_run]), "mobile-ids\n")

## How much of each segment the evidence actually reaches ---------------------------------------
# A segment is graded by its best evidence, but the evidence may cover only part of it (W1 exists
# from 2013 and only where a provider hears the vessel). Count the pings that lie in a month W1
# confirms for the segment's vid, or in the registry holder's period for it, and call the rest
# what it is: carried across the segment by continuity.
w1_days <- merged |> filter(!is.na(vid)) |> select(mid, seg_no, vid, d1, d2) |>
  inner_join(select(st, mid, wvid = vid, md), by = "mid", relationship = "many-to-many") |>
  filter(wvid == vid, md >= d1, md <= d2) |>
  transmute(mid, seg_no, mon = format(md, "%Y-%m")) |> distinct()
w1_pings <- w1_days |>
  inner_join(merged |> select(mid, seg_no, d1, d2), by = c("mid", "seg_no")) |>
  inner_join(days |> mutate(mon = format(d, "%Y-%m")), by = c("mid", "mon"), relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |> select(mid, seg_no, d, n)
reg_pings <- merged |> filter(!is.na(vid)) |> select(mid, seg_no, vid, d1, d2) |>
  inner_join(holders, by = "mid", relationship = "many-to-many") |>
  filter(hvid == vid, t1 <= d2, t2 >= d1) |>
  transmute(mid, seg_no, from = pmax(d1, t1), to = pmin(d2, t2)) |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= from, d <= to) |> select(mid, seg_no, d, n)
# A logbook/landing month is evidence for the vid only when the mid explains at least half of that
# month's stations or landings AND at least two of them; a single hit is not evidence.
lb_months <- hh |>
  inner_join(nn, by = c("witness", "vid", "ym"), suffix = c("", "_n")) |>
  filter(hits >= 2, hits / n >= .5) |>
  distinct(mid, vid, ym)
lb_pings <- merged |> filter(!is.na(vid)) |>
  mutate(m1 = ym_of(d1), m2 = ym_of(d2)) |> select(mid, seg_no, vid, d1, d2, m1, m2) |>
  inner_join(lb_months, by = c("mid", "vid"), relationship = "many-to-many") |>
  filter(ym >= m1, ym <= m2) |> distinct(mid, seg_no, ym, d1, d2) |>
  inner_join(mutate(days, ym = ym_of(d)), by = c("mid", "ym"), relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |> select(mid, seg_no, d, n)
covered_pings <- bind_rows(w1_pings, reg_pings, lb_pings) |> distinct(mid, seg_no, d, .keep_all = TRUE) |>
  group_by(mid, seg_no) |> summarise(evidence_pings = sum(n), .groups = "drop")
merged <- merged |>
  left_join(covered_pings, by = c("mid", "seg_no")) |>
  mutate(evidence_pings = coalesce(evidence_pings, 0L), evidence_share = if_else(pings > 0, evidence_pings / pings, 0))

## Acceptance -----------------------------------------------------------------------------------
tiles <- merged |> arrange(mid, d1) |> group_by(mid) |>
  summarise(tiles = all(d1[-1] == d2[-n()] + 1), starts_at_first_ping = TRUE, .groups = "drop")
stopifnot("segments leave a gap or overlap" = all(tiles$tiles))
stopifnot("a ping is in no segment or in two" = sum(merged$pings) == sum(span$total))
unassigned <- merged |> filter(is.na(vid))
cat("\nACCEPTANCE: segments tile all", nrow(span), "mobile-ids; every one of", format(sum(span$total), big.mark = ","),
    "pings is in exactly one segment; pings on no vid (a drop or a stretch for a person, listed):", format(sum(unassigned$pings), big.mark = ","), "\n")
# A reviewed row is exempt: a vid's own AIS can place it with a mobile-id before its registration (a new vessel on
# sea trials: mid 146259 and vid 3037 from 81 days before it was registered, 100 % of 1,071 opportunities).
# The fills outside a neighbour's lifetime are exempt too, and counted on their own (the maintainer's choice, 2026-10-17).
FILL_OUT <- "continuity: neighbour, outside its registered lifetime"
before_reg <- merged |> filter(!is.na(vid), !source %in% c("reviewed", FILL_OUT)) |> mutate(rs = reg_start_of(vid)) |> filter(!is.na(rs), d1 < rs - 60)
cat("\nSegments that START more than 60 d before their vid was registered:", nrow(before_reg), "on", format(sum(before_reg$pings), big.mark = ","), "pings (must be 0; reviewed rows and fills exempt)\n")
cat("Stretches filled with a neighbour outside its registered lifetime:", sum(merged$source == FILL_OUT), "on",
    format(sum(merged$pings[merged$source == FILL_OUT]), big.mark = ","), "pings,", n_distinct(merged$mid[merged$source == FILL_OUT]), "mobile-ids\n")
w1_check <- st |>
  inner_join(transmute(merged, mid, d1, d2, seg_vid = vid), by = "mid", relationship = "many-to-many") |>
  filter(md >= d1, md <= d2) |>
  summarise(strong_months = n(), months_in_a_segment_of_another_vid = sum(is.na(seg_vid) | seg_vid != vid))
print(knitr::kable(w1_check, caption = "W1 against the table (a twin or a companion vessel accounts for the rest)"))
print(knitr::kable(merged |> count(source, name = "segments") |> left_join(merged |> group_by(source) |> summarise(pings = sum(pings), .groups = "drop"), by = "source"), caption = "ais_key_segments"))
print(knitr::kable(merged |> filter(!is.na(vid)) |> summarise(pings_with_direct_evidence = sum(evidence_pings), pings_carried_by_continuity = sum(pings) - sum(evidence_pings), share_with_direct_evidence = round(sum(evidence_pings) / sum(pings), 3)), caption = "how much of the assignment the evidence reaches"))
print(knitr::kable(merged |> summarise(mids = n_distinct(mid), segments = n(), differ_from_key_segments = sum(!agrees_key & !is.na(vid)),
                                        pings_relabelled = sum(pings[!agrees_key & !is.na(vid)]), startup_segments = sum(startup_phase)), caption = "against the current key"))

write_curated(merged, fd_curated("check", "ais_key_segments.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key_cascade.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         lb_hits = fd_curated("check", "ais_key_audit_lb_hits.parquet"),
                         lb_n = fd_curated("check", "ais_key_audit_lb_n.parquet"),
                         split_candidates = fd_curated("check", "ais_key_split_candidates.parquet"),
                         annual_call_sign = fd_staging("skipaskra", "annual_call_sign.parquet")))
