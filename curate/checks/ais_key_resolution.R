# Each discrepancy in the STK key read as eras: which vid when, and what the key says.
# Side: once (vessel key). See plan 014.
#
# Input:  curated/check/ais_key_audit_discrepancy.parquet, ais_key_audit_w1.parquet,
#         ais_key_split_candidates.parquet, curated/vessel/{vessel_ais_key,vessel,vessel_identity}.parquet
# Output: curated/check/ais_key_resolution.parquet - one row per (mid, era)
#
# Phase 2 of curate/plans/009. The audit says WHERE the key disagrees with a witness; a
# person entering an override needs WHEN and WHICH: for each mobile-id in the discrepancy
# register, the runs of months in which one vid's own other-provider AIS (keyed by MMSI) is
# co-located with the mid's pings, set beside the key's vid for the same months and tested
# against the registry. The physical witness only reaches 2013 onwards and only vessels the
# providers hear, so a mid with no W1 era is reported as unresolved, not guessed.
#
# This check REPORTS. It never writes a vid. A row here is a proposal; a person decides, and
# a decided row enters through overrides/ as an input (AGENTS.md: the AIS -> vid -> logbook
# -> AIS loop is broken by a human, not computed).
#
# Identifiers are vid and MMSI. Names are not read.

library(dplyr)
library(nanoparquet)

disc  <- read_parquet(fd_curated("check", "ais_key_audit_discrepancy.parquet"))
w1    <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet"))
cand  <- read_parquet(fd_curated("check", "ais_key_split_candidates.parquet"))
key   <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
reg   <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> select(vid, yh1, yh2)
ident <- read_parquet(fd_curated("vessel", "vessel_identity.parquet")) |>
  transmute(vid, t1 = as.Date(t1), t2 = as.Date(t2))

# yh2 never exceeds the registry snapshot horizon (corrections/vessel_registry_stale_lifetime.yml),
# so a hull that "ends" there is alive, not ended.
HORIZON <- max(reg$yh2, na.rm = TRUE)
STRONG  <- .8     # W1 score at which a month names the vessel (calibrated, decision 047)
MIN_MONTHS <- 3L  # an era needs this many strong months

scope <- disc |>
  group_by(mid) |>
  summarise(discrepancy_types = paste(sort(unique(type)), collapse = "; "), .groups = "drop")

# An era is a run of strong months of ONE vid that no other vid interrupts. Seasonal vessels
# have long W1 silences inside a single tenure and stay one era; a lone month of a vessel
# steaming alongside is dropped (a block shorter than MIN_MONTHS) before eras are formed, so
# it cannot cut a long era in two.
blocks <- function(d) {
  d |>
    arrange(mid, ym) |>
    group_by(mid) |>
    mutate(blk = cumsum(vid != lag(vid, default = first(vid)))) |>
    group_by(mid, vid, blk) |>
    summarise(a = min(ym), b = max(ym), w1_months = n(), w1_score = median(score), .groups = "drop")
}
strong <- w1 |>
  filter(score >= STRONG, mid %in% scope$mid) |>
  mutate(ym = y * 12L + m - 1L)
first_pass <- blocks(strong) |> filter(w1_months >= MIN_MONTHS)
strong2 <- strong |>
  semi_join(first_pass, by = c("mid", "vid")) |>
  inner_join(select(first_pass, mid, vid, a, b), by = c("mid", "vid"), relationship = "many-to-many") |>
  filter(ym >= a, ym <= b) |>
  distinct(mid, vid, ym, .keep_all = TRUE) |>
  select(mid, vid, y, m, score, ym)
eras <- blocks(strong2) |>
  filter(w1_months >= MIN_MONTHS) |>
  mutate(era_from = as.Date(sprintf("%d-%02d-01", a %/% 12L, a %% 12L + 1L)),
         era_to   = as.Date(sprintf("%d-%02d-01", (b + 1L) %/% 12L, (b + 1L) %% 12L + 1L)) - 1L) |>
  group_by(mid) |>
  arrange(era_from, .by_group = TRUE) |>
  mutate(era_no = row_number()) |>
  ungroup()
# a twin is another vid's era overlapping this one in time - two vessels heard at once
eras <- eras |>
  group_by(mid) |>
  mutate(twin = vapply(seq_len(n()), function(i)
    any(era_from[-i] < era_to[i] & era_to[-i] > era_from[i] & vid[-i] != vid[i]), logical(1))) |>
  ungroup()

# What the key says at the middle of each era
mid_date <- function(d1, d2) d1 + as.integer((d2 - d1) / 2)
key_at <- eras |>
  transmute(mid, era_no, d = mid_date(era_from, era_to)) |>
  inner_join(select(key, mid, kvid = vid, d1, d2), by = "mid", relationship = "many-to-many") |>
  filter(d1 <= d, d2 >= d) |>
  group_by(mid, era_no) |>
  summarise(key_vid = paste(sort(unique(kvid[!is.na(kvid)])), collapse = ";"), .groups = "drop")

# Silences of the mid inside the gap between an era's end and the next one's start
boundary <- eras |>
  group_by(mid) |>
  arrange(era_no, .by_group = TRUE) |>
  mutate(prev_to = lag(era_to)) |>
  ungroup() |>
  filter(!is.na(prev_to)) |>
  select(mid, era_no, prev_to, era_from) |>
  left_join(select(cand, mid, d_prev, d_next, gap), by = "mid", relationship = "many-to-many") |>
  filter(is.na(d_prev) | (d_prev >= prev_to - 45 & d_next <= era_from + 45)) |>
  group_by(mid, era_no) |>
  summarise(boundary = if (all(is.na(gap))) "between months, no silence" else
                       paste0("inside a ", max(gap, na.rm = TRUE), "-day silence"), .groups = "drop")

# What kind of thing the key says each mid is. A net relay or beacon rides with a vessel and is
# heard as one; it must not be assigned that vessel's vid.
mid_class <- key |>
  group_by(mid) |>
  summarise(entity_class = names(sort(table(entity_class), decreasing = TRUE))[1], .groups = "drop")

# A device carried between vessels alternates: its own key vid is one of its eras while at
# least two other vids also have eras. A vessel that changed hands does not.
alt <- eras |>
  left_join(key_at, by = c("mid", "era_no")) |>
  group_by(mid) |>
  summarise(alternates = any(key_vid == as.character(vid)) &&
              sum(key_vid != as.character(vid)) >= 2 &&
              n_distinct(vid[key_vid != as.character(vid)]) >= 1 && n() >= 3, .groups = "drop")

out <- eras |>
  left_join(alt, by = "mid") |>
  left_join(key_at, by = c("mid", "era_no")) |>
  left_join(boundary, by = c("mid", "era_no")) |>
  left_join(reg, by = "vid") |>
  left_join(mid_class, by = "mid") |>
  left_join(scope, by = "mid") |>
  mutate(
    boundary = coalesce(boundary, if_else(era_no == 1L, "first era", "between months, no silence")),
    key_vid = coalesce(key_vid, ""),
    key_agrees = key_vid == as.character(vid),
    # the registry allows this vid at these dates: alive by then, and not ended before
    registry_ok = (is.na(yh1) | yh1 <= as.integer(format(era_from, "%Y")) + 1L) &
                  (is.na(yh2) | yh2 >= HORIZON | yh2 >= as.integer(format(era_to, "%Y")) - 1L),
    action = case_when(
      !is.na(entity_class) & entity_class != "vessel" ~ "not a vessel: a device heard with this vid, leave the key",
      alternates ~ "the mid moves between vids, its own included: a device carried between vessels, read by hand",
      twin      ~ "two vessels heard at once: read by hand",
      key_agrees ~ "key already right",
      key_vid == "" ~ "key has no vid here: assign",
      .default  = "key differs: reassign"),
    # how much rests on it: months in which the vid's own AIS was co-located with the mid
    strength = case_when(w1_months >= 12 ~ "strong", w1_months >= 6 ~ "moderate", .default = "weak"),
    proposal = action %in% c("key has no vid here: assign", "key differs: reassign") & registry_ok & !twin) |>
  select(mid, era_no, vid, era_from, era_to, w1_months, w1_score, entity_class, key_vid, key_agrees,
         registry_ok, twin, boundary, action, strength, proposal, discrepancy_types)

# A discrepancy mid with no era is not resolved by W1; say so, with why nothing reaches it
unresolved <- scope |>
  anti_join(out, by = "mid") |>
  transmute(mid, era_no = NA_integer_, vid = NA_integer_, era_from = as.Date(NA), era_to = as.Date(NA),
            w1_months = NA_integer_, w1_score = NA_real_, entity_class = NA_character_, key_vid = NA_character_, key_agrees = NA,
            registry_ok = NA, twin = NA, boundary = NA_character_,
            action = "unresolved: no W1 era (before 2013, or not heard by any provider)",
            strength = NA_character_, proposal = FALSE, discrepancy_types)
out <- bind_rows(out, unresolved) |> arrange(mid, era_no)

print(out |> count(action, name = "rows") |> knitr::kable(caption = "ais_key_resolution"))
print(out |> summarise(mids = n_distinct(mid), mids_with_a_proposal = n_distinct(mid[proposal %in% TRUE]),
                       proposals = sum(proposal %in% TRUE)) |> knitr::kable(caption = "reviewable proposals"))

write_curated(out, fd_curated("check", "ais_key_resolution.parquet"),
              inputs = c(discrepancy = fd_curated("check", "ais_key_audit_discrepancy.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         split_candidates = fd_curated("check", "ais_key_split_candidates.parquet"),
                         vessel_ais_key = fd_curated("vessel", "vessel_ais_key_cascade.parquet")))
