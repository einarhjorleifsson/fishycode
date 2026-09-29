# The STK mid -> vid key, audited row by row against witnesses that never read it.
#
# Input:  curated/vessel/vessel_ais_key.parquet, curated/ais/ping (other providers),
#         raw/ais/stk/trail, curated/logbook/{station,trip}.parquet,
#         curated/landing/landings.parquet, curated/check/ais_key_registry.parquet,
#         curated/check/ais_key_split_candidates.parquet,
#         overrides/ais_key_callsign_reuse_reviewed.csv
# Output: curated/check/ais_key_audit_ledger.parquet      - one row per key row
#         curated/check/ais_key_audit_discrepancy.parquet - one row per discrepancy
#
# A bookkeeping audit first: every assignment is a record, each witness says what it
# sees, and the ledger says whether they agree. The statistics in
# R/audit_witnesses.R are background tests, not the finding. Design: curate/plans/009;
# what it found and how far each witness can be trusted: curate/decisions/047.
#
# The witnesses (none reads the key's verdict; identifiers are vid and MMSI, never names):
#   W1 other-provider AIS co-located with the STK pings, keyed by MMSI -> vid. Physical.
#   W2 logbook stations, W3 landing harbours - scored per year, and a contradiction
#      needs a second witness or W1.
#   W6 the mid number as a clock; real ping spans, not the key's sentinel d2.
#   Split candidates (curate/checks/ais_key_split_candidates.R): silences where a human-style
#      reading of profile, position and registry says the vessel changed.
#
# This check REPORTS. It never writes a vid. Per AGENTS.md the AIS -> vid -> logbook
# -> AIS loop is circular and is broken by a human: a reviewed conclusion re-enters
# through overrides/ as an input.

library(dplyr)
library(tidyr)
library(nanoparquet)

## Inputs ----------------------------------------------------------------------------
STK_GLOB  <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
PING_GLOB <- file.path(fd_path("curated", "ais", "ping"), "year=*", "*.parquet")
STATION   <- fd_path("curated", "logbook", "station.parquet")
TRIP      <- fd_path("curated", "logbook", "trip.parquet")
LANDINGS  <- fd_path("curated", "landing", "landings.parquet")

key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2))
key_v <- key |>
  filter(!is.na(vid), vid > 0, entity_class == "vessel") |>
  select(mid, K = vid, d1, d2, step, tier)

# 16 GB is what the largest month of W1/W2 needs to stay in memory
con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
q <- function(sql) dplyr::as_tibble(DBI::dbGetQuery(con, sql))

last_oth <- q(sprintf("select max(time) t from read_parquet('%s') where provider <> 'stk'", PING_GLOB))$t
LAST_Y <- as.integer(format(last_oth, "%Y")); LAST_M <- as.integer(format(last_oth, "%m"))
months_from <- function(y1, m1) {
  ym <- seq(y1 * 12 + m1 - 1, LAST_Y * 12 + LAST_M - 1)
  tibble(y = ym %/% 12, m = ym %% 12 + 1)
}
YEARS <- 2007:(LAST_Y - 1)   # the last year is partial; a partial year is not scored

## W1: co-location, 2013 onwards (the first other-provider data) ---------------------------
w1 <- purrr::map(seq_len(nrow(months_from(2013, 1))), function(i) {
  ym <- months_from(2013, 1)[i, ]
  mid15 <- as.Date(sprintf("%d-%02d-15", ym$y, ym$m))
  kp <- key_v |> filter(d1 <= mid15, d2 >= mid15) |> transmute(mid = as.numeric(mid), vid = as.integer(K))
  audit_w1_month(con, ym$y, ym$m, STK_GLOB, PING_GLOB, kp)
})
bind_w <- function(l, f) bind_rows(lapply(l, function(o) mutate(as_tibble(o[[f]]), y = o$y, m = o$m)))
H1  <- bind_w(w1, "hits"); OPP <- bind_w(w1, "opp"); NM <- bind_w(w1, "n_mid")
P1 <- OPP |>
  left_join(H1, by = c("mid", "vid", "y", "m")) |>
  mutate(hit_pings = coalesce(hit_pings, 0L), score = hit_pings / opp)

# key mid-months with the key vid's own W1 score
mg <- NM |>
  inner_join(key_v, by = "mid", relationship = "many-to-many") |>
  mutate(d15 = as.Date(sprintf("%d-%02d-15", y, m))) |>
  filter(d15 >= d1, d15 <= d2) |>
  left_join(select(P1, mid, K = vid, y, m, opp_k = opp, score_k = score), by = c("mid", "K", "y", "m")) |>
  mutate(opp_k = coalesce(opp_k, 0L))

# W1 verdict per mid-month: best vid >= .8 vs the key's own
best1 <- P1 |>
  filter(opp >= 20) |>
  group_by(mid, y, m) |>
  arrange(desc(score), desc(opp), .by_group = TRUE) |>
  slice(1) |>
  ungroup() |>
  filter(score >= .8) |>
  select(mid, y, m, V = vid, vscore = score)
cls <- best1 |>
  full_join(transmute(mg, mid, y, m, K, kscore = coalesce(score_k, 0), kopp = opp_k), by = c("mid", "y", "m")) |>
  mutate(kscore = coalesce(kscore, 0), kopp = coalesce(kopp, 0L),
         cl = case_when(is.na(V) ~ "no_strong_vid", is.na(K) ~ "key_none_witness_has_vid",
                        K == V ~ "agree", kscore >= .5 ~ "twin_both_strong",
                        kopp >= 20 ~ "refuted_key_covered_low", .default = "key_silent_other_vid_loud"))
alt <- cls |>
  filter(cl == "key_silent_other_vid_loud") |>
  left_join(NM, by = c("mid", "y", "m")) |>
  group_by(mid, vid = K) |>
  summarise(w1_alt_vid = paste(sort(unique(V)), collapse = ";"), w1_alt_months = n(),
            w1_alt_pings = sum(n_stk), .groups = "drop")

## W2 / W3: logbook and landings, 2007-06 onwards ---------------------------------------
w2 <- purrr::map(seq_len(nrow(months_from(2007, 6))), function(i) {
  ym <- months_from(2007, 6)[i, ]
  audit_w2_month(con, ym$y, ym$m, STK_GLOB, STATION, TRIP)
})
H2 <- bind_w(w2, "hits") |> select(mid, vid, y, m, hits)
N2 <- bind_w(w2, "n") |> rename(n = n_st)

DBI::dbExecute(con, sprintf("create or replace table ev as select distinct mid, cast(time as date) d, hid from read_parquet('%s') where hid is not null and io = 'I' and time >= timestamp '2007-06-01'", STK_GLOB))
DBI::dbExecute(con, sprintf("create or replace table ld as select distinct vid, date d, pid, \".lid\" lid from read_parquet('%s') where date >= date '2007-06-01' and pid is not null and vid is not null", LANDINGS))
truth <- mg |>
  filter(opp_k >= 50, coalesce(score_k, 0) >= .8) |>
  transmute(mid = as.numeric(mid), vid = as.integer(K), y, m)
w3_cw <- audit_w3_crosswalk(con, truth)
H3 <- q("select ev.mid, ld.vid, year(ld.d) y, month(ld.d) m, count(distinct ld.lid) hits from ld join cw on cw.pid = ld.pid join ev on ev.hid = cw.hid and abs(datediff('day', ev.d, ld.d)) <= 1 group by 1,2,3,4")
N3 <- q("select vid, year(d) y, month(d) m, count(distinct lid) n from ld group by 1,2,3")

## Synthesis: one verdict per key (mid, vid, year) ------------------------------------------
mid_year <- q(sprintf("select mid, year(time) y from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1, 2", STK_GLOB))
grid <- key_v |>
  crossing(y = YEARS, m = 1:12) |>
  mutate(d15 = as.Date(sprintf("%d-%02d-15", y, m))) |>
  filter(d15 >= d1, d15 <= d2) |>
  select(mid, K, y, m, step, tier) |>
  semi_join(mid_year, by = c("mid", "y"))
W2 <- audit_score_year(grid, H2, N2, 30)
W3 <- audit_score_year(grid, H3, N3, 15)
W1 <- mg |>
  mutate(cov = opp_k >= 20,
         v = case_when(!cov ~ "uncovered", score_k >= .8 ~ "support", score_k < .5 ~ "contradict", .default = "middling")) |>
  group_by(mid, K, y) |>
  summarise(w1_cov = sum(cov), w1_sup = sum(v == "support"), w1_con = sum(v == "contradict"), .groups = "drop") |>
  mutate(w1 = case_when(w1_cov == 0 ~ "uncovered", w1_con > 0 & w1_sup == 0 ~ "contradict",
                        w1_sup > 0 & w1_con == 0 ~ "support", w1_sup > 0 ~ "mixed", .default = "middling"))
Z <- W1 |> select(mid, K, y, w1) |>
  full_join(select(W2, mid, K, y, w2 = v), by = c("mid", "K", "y")) |>
  full_join(select(W3, mid, K, y, w3 = v), by = c("mid", "K", "y")) |>
  mutate(across(c(w1, w2, w3), ~ coalesce(.x, "uncovered")))
is_sup <- \(x) x == "support"; is_con <- \(x) x == "contradict"
Z <- Z |>
  mutate(n_sup = is_sup(w1) + is_sup(w2) + is_sup(w3), n_con = is_con(w1) + is_con(w2) + is_con(w3),
         n_cov = (w1 != "uncovered") + (w2 != "uncovered") + (w3 != "uncovered"),
         # A contradiction needs a second witness, or W1. Alone, W3 is fooled by a ferry
         # that enters every port and W2 by a fixed station in a crowded fishing ground.
         verdict = case_when(
           n_cov == 0                                             ~ "uncovered",
           n_con >= 2 | w1 == "contradict"                        ~ if_else(n_sup >= 1, "conflict", "contradicted"),
           n_con == 1                                             ~ "single_witness_flag",
           n_sup >= 1 & (is_sup(w1) | n_sup >= 2)                    ~ "confirmed",
           n_sup >= 1                                             ~ "supported_one_witness",
           .default                                               = "covered_none_supports"))

# fit but not unique is not weak; weak in EVERY covered year is what a wrong mid looks like
weak_pairs <- bind_rows(select(W2, mid, K, y, s_key), select(W3, mid, K, y, s_key)) |>
  group_by(mid, K, y) |> summarise(s = max(s_key), .groups = "drop") |>
  group_by(mid, K) |> summarise(yrs = n(), weak = sum(s < .5), .groups = "drop") |>
  filter(yrs >= 3, weak / yrs >= .8)

## Two vids on one mid in sequence, from W1 ------------------------------------------------
strong <- P1 |> filter(opp >= 20, score >= .8) |> mutate(ym = y * 12 + m - 1)
eras <- strong |>
  arrange(mid, vid, ym) |>
  group_by(mid, vid) |>
  mutate(era = cumsum(ym - lag(ym, default = first(ym)) > 3)) |>
  group_by(mid, vid, era) |>
  summarise(a = min(ym), b = max(ym), n = n(), .groups = "drop") |>
  filter(n >= 3)
two <- eras |>
  inner_join(eras, by = "mid", suffix = c("1", "2"), relationship = "many-to-many") |>
  filter(vid1 != vid2, b1 < a2) |>
  group_by(mid) |> slice_min(a2 - b1, n = 1, with_ties = FALSE) |> ungroup() |>
  mutate(t1 = as.Date(sprintf("%d-%02d-15", (b1 - 1) %/% 12, (b1 - 1) %% 12 + 1)),
         t2 = as.Date(sprintf("%d-%02d-15", a2 %/% 12, a2 %% 12 + 1)))
key_at <- function(mid_, d_) {
  tibble(mid = mid_, d = d_) |>
    left_join(key_v, by = "mid", relationship = "many-to-many") |>
    filter(d1 <= d, d2 >= d) |> group_by(mid, d) |> slice(1) |> ungroup() |> select(mid, d, k = K)
}
two <- two |>
  left_join(key_at(two$mid, two$t1) |> rename(t1 = d, key1 = k), by = c("mid", "t1")) |>
  left_join(key_at(two$mid, two$t2) |> rename(t2 = d, key2 = k), by = c("mid", "t2")) |>
  mutate(split = case_when(key1 == vid1 & key2 == vid2 ~ "key_splits_correctly",
                           key1 %in% vid1 & !key2 %in% vid2 ~ "key_has_only_first",
                           !key1 %in% vid1 & key2 %in% vid2 ~ "key_has_only_second",
                           is.na(key1) & is.na(key2) ~ "key_none", .default = "key_wrong_both"),
         two_era = paste0(split, ": ", vid1, " then ", vid2)) |>
  filter(split != "key_splits_correctly") |>
  select(mid, two_era)

## Split candidates: silences where a human-style reading says the vessel changed -----------
# Computed by curate/checks/ais_key_split_candidates.R (profile, position, registry); here it
# only annotates the ledger, so the audit does not repeat that work.
split <- read_parquet(fd_curated("check", "ais_key_split_candidates.parquet")) |>
  filter(tier %in% c("strong", "review"), !ods_split) |>
  group_by(mid, vid) |>
  summarise(split_tier = if_else(any(tier == "strong"), "strong", "review"), split_silences = n(), .groups = "drop")

## Ledger: one row per key row ----------------------------------------------------------------
fp <- q(sprintf("select mid, cast(min(time) as date) first_ping, cast(max(time) as date) last_ping, count(*) pings from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1", STK_GLOB))
cz <- Z |>
  group_by(mid, vid = K) |>
  summarise(cells = n(), c_confirmed = sum(verdict == "confirmed"), c_one_witness = sum(verdict == "supported_one_witness"),
            c_covered_none = sum(verdict == "covered_none_supports"), c_uncovered = sum(verdict == "uncovered"),
            c_single_flag = sum(verdict == "single_witness_flag"), c_contradicted = sum(verdict %in% c("contradicted", "conflict")),
            w1_support_years = sum(w1 == "support"), .groups = "drop")
reg <- read_parquet(fd_curated("check", "ais_key_registry.parquet")) |>
  filter(check == "partly_outside_vessel_lifetime") |> transmute(mid, vid, partial_lifetime = note)
reviewed <- read.csv("overrides/ais_key_callsign_reuse_reviewed.csv")

ledger <- key |>
  select(.rid, mid, vid, d1, d2, step, tier, entity_class, mmsi) |>
  left_join(fp, by = "mid") |>
  left_join(cz, by = c("mid", "vid")) |>
  left_join(alt, by = c("mid", "vid")) |>
  left_join(two, by = "mid") |>
  left_join(reg, by = c("mid", "vid")) |>
  left_join(split, by = c("mid", "vid")) |>
  mutate(across(c(cells, starts_with("c_"), w1_support_years), ~ coalesce(.x, 0L)),
         weak_every_year = mid %in% weak_pairs$mid,
         reviewed_override = mid %in% reviewed$mid,
         discrepancy = case_when(
           !is.na(w1_alt_vid)       ~ "W1: another vid on this mid",
           !is.na(two_era)          ~ "two vids in sequence, key splits wrongly",
           !is.na(partial_lifetime) ~ "mid outlives or predates the hull",
           c_contradicted > 0       ~ "contradicted by two witnesses",
           .default = NA_character_),
         audit_status = case_when(
           !is.na(discrepancy)                        ~ "discrepancy",
           is.na(vid)                                 ~ "no vid claimed",
           cells == c_uncovered                       ~ "no witness reaches",   # every cell was uncovered
           w1_support_years > 0                       ~ "ok: physical (W1)",
           c_confirmed > 0                            ~ "ok: two witnesses",
           c_one_witness > 0                          ~ "ok: one witness",
           c_single_flag > 0 | !is.na(split_tier)        ~ "review",
           .default                                   = "covered, none supports"))

discrepancy <- bind_rows(
  ledger |> filter(!is.na(w1_alt_vid)) |>
    transmute(type = "w1_other_vid_on_mid", mid, key_vid = vid, other_vid = w1_alt_vid,
              evidence = paste0("W1 co-location: ", w1_alt_months, " mid-months, ", w1_alt_pings, " moving pings")),
  ledger |> filter(!is.na(two_era)) |>
    transmute(type = "two_vids_in_sequence", mid, key_vid = vid, other_vid = NA_character_, evidence = two_era),
  ledger |> filter(!is.na(partial_lifetime)) |>
    transmute(type = "mid_outside_hull_life", mid, key_vid = vid, other_vid = NA_character_, evidence = partial_lifetime),
  ledger |> filter(c_contradicted > 0) |>
    transmute(type = "contradicted_by_two_witnesses", mid, key_vid = vid, other_vid = NA_character_,
              evidence = paste0(c_contradicted, " year-cell(s)")),
  ledger |> filter(!is.na(split_tier)) |>
    transmute(type = paste0("split_candidate_", split_tier), mid, key_vid = vid, other_vid = NA_character_,
              evidence = paste0(split_silences, " silence(s) >= 180 d the ODS did not split"))) |>
  mutate(key_vid = as.integer(key_vid), reviewed_override = mid %in% reviewed$mid)

print(ledger |> count(audit_status, name = "rows") |> arrange(desc(rows)) |> knitr::kable(caption = "ais_key_audit ledger"))
print(discrepancy |> count(type, name = "rows") |> knitr::kable(caption = "ais_key_audit discrepancies"))

inp <- c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
         ais_key_registry = fd_curated("check", "ais_key_registry.parquet"),
         split_candidates = fd_curated("check", "ais_key_split_candidates.parquet"),
         landings = LANDINGS, station = STATION, trip = TRIP)
write_curated(ledger, fd_curated("check", "ais_key_audit_ledger.parquet"), inputs = inp)
write_curated(discrepancy, fd_curated("check", "ais_key_audit_discrepancy.parquet"), inputs = inp)

DBI::dbDisconnect(con, shutdown = TRUE)
