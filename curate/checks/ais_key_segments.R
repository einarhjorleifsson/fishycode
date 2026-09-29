# The STK mobile-id -> vid assignment rebuilt as a SEGMENT TABLE that tiles every mobile-id.
#
# Input:  curated/vessel/{vessel_ais_key,vessel_identity}.parquet, raw/ais/stk/trail,
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
#     mobile-id) confirms, cut in the middle of the months between the two confirmed runs.
# A segment starts on the first ping after a silence, so the silence belongs to the segment
# before it and the periods touch exactly.
#
# THE VID OF A SEGMENT, best evidence first, with the source recorded:
#   1. physical   W1 confirms a vid in >= 3 months of the segment;
#   2. registry   the registry gives the mobile-id's own call sign or MMSI to one vid over it;
#   3. logbook    one vid's logbook stations explain >= 80 % of its stations over the segment, by a
#                 clear margin (>= 0.1) over every other vid, with >= 30 stations - calibrated at
#                 year level (decision 047); landings alone count only at >= 90 % with a margin of
#                 0.3, because a vessel that calls at every port (a ferry) otherwise wins them all;
#   4. continuity the key's vid for that stretch (never left empty - the weakest grade). For an
#                 ICELANDIC vid the key rows that came from the ODS are NOT used here (the ODS is
#                 given up as an input, plan 009 phase 5): a stretch with no evidence borrows the vid
#                 of the neighbouring segment of the same mobile-id, flagged for a person. FOREIGN
#                 vessels (vids 3700-4999 only; Icelandic vids resume above 4999) have no other
#                 evidence, so their matches are read from overrides/stk_foreign_mid_vid.csv, which
#                 keeps them without the ODS file (extracted once, unchanged), and are labelled
#                 `foreign: kept override`.
# A negative key vid (an ODS `drop`) is NOT decided by a rule: it stays NA and is listed.
# `vid_no_ods` is the same rule with the ODS-sourced key rows removed from the continuity step; it
# is kept only so the dependence on those rows stays visible. The ODS is not a judge of this table
# (maintainer, 2026-09-29): disagreements with it are decided on evidence, like any other.
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

STK_GLOB <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
MIN_W1_MONTHS <- 3L   # months of W1 confirmation that name a vid over a segment
STARTUP_END <- as.Date("2009-01-01")

key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
ident <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  transmute(hvid = as.integer(vid), cs, mmsi, t1 = as.Date(t1), t2 = as.Date(t2))
cand <- read_parquet(fd_curated("check", "ais_key_split_candidates.parquet"))
foreign_keep <- read.csv("overrides/stk_foreign_mid_vid.csv") |>
  transmute(mid, fvid = as.integer(vid), fd1 = as.Date(d1), fd2 = as.Date(d2))
w1 <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet"))
lb_hits <- read_parquet(fd_curated("check", "ais_key_audit_lb_hits.parquet"))
lb_n <- read_parquet(fd_curated("check", "ais_key_audit_lb_n.parquet"))

con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
days <- dplyr::as_tibble(DBI::dbGetQuery(con, sprintf(
  "select mid, cast(time as date) d, count(*) n from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1, 2 order by 1, 2", STK_GLOB)))
DBI::dbDisconnect(con, shutdown = TRUE)

has_vessel <- key |> filter(!is.na(vid), vid > 0) |> distinct(mid) |> pull(mid)
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
cuts <- bind_rows(cut_silence, cut_w1)

## Segments --------------------------------------------------------------------------------------
cuts <- cuts |> distinct(mid, cut, .keep_all = TRUE)
frame <- span |>
  left_join(end_of, by = "mid") |>
  transmute(mid, first, last, end = pmax(coalesce(kend, last), last))
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
w1_seg <- segs |>
  inner_join(select(st, mid, vid, md), by = "mid", relationship = "many-to-many") |>
  filter(md >= d1, md <= d2) |>
  count(mid, seg_no, vid, name = "k") |>
  group_by(mid, seg_no) |> arrange(desc(k), .by_group = TRUE) |>
  summarise(w1_vid = vid[1], w1_months = k[1],
            twin_vid = if (n() > 1 && k[2] >= MIN_W1_MONTHS) vid[2] else NA_integer_, .groups = "drop") |>
  filter(w1_months >= MIN_W1_MONTHS)

# the mobile-id's OWN identifier strings: a call sign (TF + two letters) or a 9-digit MMSI
tok <- key |>
  filter(mid %in% has_vessel) |>
  pivot_longer(c(loid, glid), values_to = "s") |>
  filter(!is.na(s)) |> mutate(s = toupper(trimws(s))) |>
  transmute(mid, cs = if_else(grepl("^TF[A-Z]{2}$", s), s, NA_character_),
            mmsi = if_else(grepl("^[0-9]{9}$", s), s, NA_character_)) |>
  filter(!is.na(cs) | !is.na(mmsi)) |> distinct()
holders <- bind_rows(
  tok |> filter(!is.na(cs))   |> inner_join(filter(ident, !is.na(cs)),   by = "cs",   relationship = "many-to-many") |> select(mid, hvid, t1, t2),
  tok |> filter(!is.na(mmsi)) |> inner_join(filter(ident, !is.na(mmsi)), by = "mmsi", relationship = "many-to-many") |> select(mid, hvid, t1, t2)) |>
  distinct()
reg_seg <- segs |>
  inner_join(holders, by = "mid", relationship = "many-to-many") |>
  filter(t1 <= d2, t2 >= d1) |>
  group_by(mid, seg_no) |>
  summarise(reg_vid = if (n_distinct(hvid) == 1) hvid[1] else NA_integer_, .groups = "drop") |>
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
         ods_key = !is.na(key_step) & key_step == "manuals" & !is.na(key_vid) & key_vid > 0,
         is_foreign = !is.na(key_vid) & key_vid %in% 3700:4999,
         # continuity may use the key's vid unless the key row came from the ODS (that file is not an input)
         key_free = if_else(ods_key, NA_integer_, key_vid),
         drop_seg = !is.na(key_vid) & key_vid <= 0 & is.na(w1_vid) & is.na(reg_vid) & is.na(lb_vid),
         vid = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, !is.na(lb_vid) ~ lb_vid, drop_seg ~ NA_integer_, !is.na(key_free) ~ key_free, .default = foreign_vid),
         source = case_when(!is.na(w1_vid) ~ "physical", !is.na(reg_vid) ~ "registry", !is.na(lb_vid) ~ lb_src, drop_seg ~ "drop: a person decides",
                            is.na(key_free) & !is.na(foreign_vid) ~ "foreign: kept override", .default = "continuity"),
         vid_no_ods = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, !is.na(lb_vid) ~ lb_vid, drop_seg ~ NA_integer_,
                                !ods_key & key_vid > 0 ~ key_vid, .default = NA_integer_))
# an Icelandic stretch with no evidence and no ODS-free key row borrows its neighbour's vid
tbl <- tbl |>
  arrange(mid, seg_no) |>
  group_by(mid) |>
  mutate(need = is.na(vid) & !drop_seg, vid_nb = vid) |>
  tidyr::fill(vid_nb, .direction = "downup") |>
  ungroup() |>
  mutate(vid = if_else(need & !is.na(vid_nb), vid_nb, vid),
         source = if_else(need & !is.na(vid_nb), "continuity: neighbour", source),
         agrees_key = !is.na(vid) & vid == key_vid)

SRC <- c("physical", "registry", "logbook", "landings", "continuity", "continuity: neighbour", "foreign: kept override", "drop: a person decides")
# two neighbouring segments of one vid are one segment
merged <- tbl |>
  arrange(mid, seg_no) |>
  group_by(mid) |>
  mutate(sig = paste(vid, vid_no_ods),
         grp = cumsum(is.na(vid) | is.na(lag(vid)) | sig != lag(sig))) |>
  group_by(mid, grp) |>
  summarise(d1 = min(d1), d2 = max(d2), vid = vid[1],
            source = SRC[min(match(source, SRC))],
            key_vid = key_vid[which.max(pings)], vid_no_ods = vid_no_ods[1],
            w1_months = sum(w1_months, na.rm = TRUE), twin_vid = twin_vid[!is.na(twin_vid)][1],
            boundary_basis = boundary_basis[1], pings = sum(pings), .groups = "drop") |>
  group_by(mid) |> mutate(seg_no = row_number()) |> ungroup() |>
  mutate(agrees_key = !is.na(vid) & vid == key_vid,
         startup_phase = d1 < STARTUP_END,
         grade = case_when(source == "physical" ~ "A", source %in% c("registry", "logbook") ~ "B", source == "landings" ~ "C", source %in% c("continuity", "continuity: neighbour") ~ "D", source == "foreign: kept override" ~ "E", .default = "-")) |>
  select(mid, seg_no, d1, d2, vid, source, grade, key_vid, agrees_key, vid_no_ods, w1_months, twin_vid,
         boundary_basis, startup_phase, pings)

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
    "pings is in exactly one segment; pings on no vid (explicit drops only):", format(sum(unassigned$pings), big.mark = ","), "\n")
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
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         lb_hits = fd_curated("check", "ais_key_audit_lb_hits.parquet"),
                         lb_n = fd_curated("check", "ais_key_audit_lb_n.parquet"),
                         split_candidates = fd_curated("check", "ais_key_split_candidates.parquet")))
