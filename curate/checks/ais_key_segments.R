# The STK mobile-id -> vid assignment rebuilt as a SEGMENT TABLE that tiles every mobile-id.
#
# Input:  curated/vessel/{vessel_ais_key,vessel_identity}.parquet, raw/ais/stk/trail,
#         curated/check/ais_key_split_candidates.parquet, curated/check/ais_key_audit_w1.parquet,
#         raw/ais/stk/stk_mobile_match-and-duals.ods (scored against, never read as input)
# Output: curated/check/ais_key_segments.parquet         - one row per segment of a mobile-id
#         curated/check/ais_key_segments_vs_ods.parquet  - each ODS row, reproduced or not
#
# Plan 009 phase 2 / phase 5. The maintainer's invariant: a mobile-id that has a vessel has a
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
#   3. continuity the key's vid for that stretch (never left empty - the weakest grade).
# A negative key vid (an ODS `drop`) is NOT decided by a rule: it stays NA and is listed.
# `vid_no_ods` is the same rule with the key rows that came from the ODS removed from the
# continuity step, so scoring the table against the ODS measures what the rule can do alone.
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
w1 <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet"))

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

# what the key already says for the stretch: the row overlapping it most, else the nearest
key_seg <- segs |>
  inner_join(kv, by = "mid", relationship = "many-to-many") |>
  mutate(overlap = pmax(0, as.numeric(pmin(d2, kd2) - pmax(d1, kd1)) + 1),
         dist = pmax(0, as.numeric(kd1 - d2), as.numeric(d1 - kd2))) |>
  group_by(mid, seg_no) |>
  arrange(desc(overlap), dist, .by_group = TRUE) |>
  slice(1) |> ungroup() |>
  transmute(mid, seg_no, key_vid = kvid, key_step = kstep)

pings <- segs |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  group_by(mid, seg_no) |> summarise(pings = sum(n), .groups = "drop")

tbl <- segs |>
  left_join(seg_basis, by = c("mid", "seg_no")) |>
  left_join(w1_seg, by = c("mid", "seg_no")) |>
  left_join(reg_seg, by = c("mid", "seg_no")) |>
  left_join(key_seg, by = c("mid", "seg_no")) |>
  left_join(pings, by = c("mid", "seg_no")) |>
  mutate(pings = coalesce(pings, 0L),
         drop_seg = !is.na(key_vid) & key_vid <= 0 & is.na(w1_vid) & is.na(reg_vid),
         vid = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, drop_seg ~ NA_integer_, .default = key_vid),
         source = case_when(!is.na(w1_vid) ~ "physical", !is.na(reg_vid) ~ "registry", drop_seg ~ "drop: a person decides",
                            .default = "continuity"),
         # the same rule with the ODS-sourced key rows taken out of the continuity step
         vid_no_ods = case_when(!is.na(w1_vid) ~ w1_vid, !is.na(reg_vid) ~ reg_vid, drop_seg ~ NA_integer_,
                                key_step != "manuals" & key_vid > 0 ~ key_vid, .default = NA_integer_),
         agrees_key = !is.na(vid) & vid == key_vid)

# two neighbouring segments of one vid are one segment
merged <- tbl |>
  arrange(mid, seg_no) |>
  group_by(mid) |>
  mutate(sig = paste(vid, vid_no_ods),
         grp = cumsum(is.na(vid) | is.na(lag(vid)) | sig != lag(sig))) |>
  group_by(mid, grp) |>
  summarise(d1 = min(d1), d2 = max(d2), vid = vid[1],
            source = c("physical", "registry", "continuity", "drop: a person decides")[min(match(source, c("physical", "registry", "continuity", "drop: a person decides")))],
            key_vid = key_vid[which.max(pings)], vid_no_ods = vid_no_ods[1],
            w1_months = sum(w1_months, na.rm = TRUE), twin_vid = twin_vid[!is.na(twin_vid)][1],
            boundary_basis = boundary_basis[1], pings = sum(pings), .groups = "drop") |>
  group_by(mid) |> mutate(seg_no = row_number()) |> ungroup() |>
  mutate(agrees_key = !is.na(vid) & vid == key_vid,
         startup_phase = d1 < STARTUP_END,
         grade = case_when(source == "physical" ~ "A", source == "registry" ~ "B", source == "continuity" ~ "C", .default = "-")) |>
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
covered_pings <- bind_rows(w1_pings, reg_pings) |> distinct(mid, seg_no, d, .keep_all = TRUE) |>
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

## Scored against the ODS: what the rule reproduces without it ----------------------------------
ods <- readODS::read_ods(fd_raw("ais", "stk", "stk_mobile_match-and-duals.ods")) |>
  as_tibble() |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2), vid = as.integer(vid)) |>
  filter(basis == "recorded", !is.na(vid), vid > 0, d1 <= d2) |>
  mutate(ods_row = row_number(), ods_type = type)
sc <- ods |>
  inner_join(days, by = "mid", relationship = "many-to-many") |>
  filter(d >= d1, d <= d2) |>
  inner_join(select(merged, mid, sd1 = d1, sd2 = d2, seg_vid = vid, vid_no_ods, source), by = "mid", relationship = "many-to-many") |>
  filter(d >= sd1, d <= sd2) |>
  group_by(ods_row, mid, ods_vid = vid, ods_type, d1, d2) |>
  summarise(pings = sum(n), with_table = sum(n[!is.na(seg_vid) & seg_vid == ods_vid]),
            no_ods_same = sum(n[!is.na(vid_no_ods) & vid_no_ods == ods_vid]),
            no_ods_other = sum(n[!is.na(vid_no_ods) & vid_no_ods != ods_vid]),
            no_ods_none = sum(n[is.na(vid_no_ods)]),
            physical_or_registry = sum(n[source %in% c("physical", "registry")]), .groups = "drop") |>
  mutate(verdict = case_when(no_ods_same / pings >= .95 ~ "reproduced without the ODS",
                             no_ods_other / pings >= .05 ~ "the table differs: a person decides",
                             no_ods_none / pings >= .05 ~ "unreachable without the ODS",
                             .default = "mostly reproduced"))
print(knitr::kable(sc |> group_by(ods_type, verdict) |> summarise(rows = n(), pings = sum(pings), .groups = "drop"), caption = "ODS rows scored (the ODS was not used as input)"))

write_curated(merged, fd_curated("check", "ais_key_segments.parquet"),
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         split_candidates = fd_curated("check", "ais_key_split_candidates.parquet")))
write_curated(sc, fd_curated("check", "ais_key_segments_vs_ods.parquet"),
              inputs = c(segments = fd_curated("check", "ais_key_segments.parquet")))
