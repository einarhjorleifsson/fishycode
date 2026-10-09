# The STK vessel match, cross-checked against landings - but from the RAW side.
# Side: once (vessel key). See plan 014.
#
# Input:  raw/ais/stk/mobile.parquet, raw/ais/stk/trail/,
#         curated/vessel/vessel.parquet, curated/vessel/vessel_ais_key.parquet,
#         curated/landing/landings.parquet
# Output: curated/check/ais_key_reused_callsign.parquet - one row per vessel in question
#
# curate/checks/ais_key_landings.R found vid 3047 (HILDUR): call sign TFBR sends
# 235,121 pings to vid 1473, which never landed a fish, while 3047 - 3,770 landings -
# has no AIS identity at all (curate/corrections/ais_key_callsign_reuse.yml). That
# check works off the FINISHED key, so it only sees a vessel that ended up with
# NO vid at all. It cannot see a vessel that got a WRONG vid, nor tell a wrong
# match from a vessel that genuinely never transmitted.
#
# This check instead goes to raw/ais/stk/mobile.parquet and raw/ais/stk/trail/
# directly: for every Icelandic vid with a real call sign and landings, does ANY
# STK mobile id broadcasting that exact call sign have pings covering the vid's
# own landing window? If so, the vessel unmistakably transmitted to STK - the
# question is only whether vessel_ais_key.parquet ever assigns that mid to this
# vid. reference/vessels/ais_key.R's call-sign step is a flat, timeless set
# (arrange + slice picks ONE vid per call sign for the mid's whole span), so a
# reused call sign - routine for Icelandic TF signs - sends the earlier holder's
# pings to whichever vid holds the sign now.
#
# This REPORTS and does not repair. A reviewed conclusion re-enters through
# overrides/ as an input, never as a computed output - the AIS -> vid -> logbook
# -> AIS cycle AGENTS.md warns about.
#
# The maintainer's own caution, 2026-09-23, applies directly to this check's
# output: landings/logbook date and vid entries carry their own occasional
# errors (rarer for electronic "vísir" records), and the mid-to-vid SPLIT DATE
# itself may be wrong rather than the vid being wholly wrong. So this does not
# assert one answer - it buckets by how strong the signal is and leaves the
# ambiguous middle for a human:
#
#   A  ghost           the mid's current vid has ZERO landings, ever (or the mid
#                      is not in the key at all) - the vid the call sign is
#                      pinned to could not have made those landings. Same shape
#                      as the confirmed 3047/1473 case.
#   B  handover        the current vid DOES land fish, but its landing window
#                      and the candidate vid's do not overlap at all - reads as
#                      a clean handover where the key's split date needs moving,
#                      not as the wrong vid.
#   D  single_day      the candidate vid has exactly one landing, sitting inside
#                      a much larger continuously-operating vid's own span - as
#                      likely a landings vid-entry typo as an AIS defect.
#   C  overlapping     both vids land heavily over the SAME years under the same
#                      call sign - two real vessels cannot hold one radio call
#                      sign at once, so one side of the registry's `cs` is stale,
#                      but which is not decidable from AIS + landings alone.
#
# Restricted to domestic vessels (call sign starts "TF", vid < 3700).
# reference/vessels/ais_key.R already states foreign vids (3700-4999) get no
# further matching effort, so an unmatched foreign call sign is expected, not a
# finding.
#
# Extended to lods, 2026-09-26, same rationale as check_ais_key_landings.R: reads
# the merged curated/landing/landings.parquet rather than raw agf alone.
# `landings` is a trip count (distinct .lid) here too.

library(dplyr)
library(tidyr)
library(nanoparquet)
library(duckdbfs)

norm <- function(x) toupper(gsub("[^A-Za-z0-9]", "", x))

reg <- read_parquet(fd_curated("vessel", "vessel.parquet")) |>
  filter(!is.na(cs), startsWith(cs, "TF"), cs != "TF", vid < 3700) |>
  mutate(cs_t = norm(cs)) |>
  filter(nchar(cs_t) >= 4) |>
  select(vid, vessel, cs, cs_t)

lnd <-
  read_parquet(fd_curated("landing", "landings.parquet")) |>
  group_by(vid) |>
  reframe(landings = n_distinct(.lid),
          first_landing = as.Date(min(date)),
          last_landing  = as.Date(max(date))) |>
  filter(vid >= 5)

reg_l <- reg |> inner_join(lnd, by = "vid")

# raw stk mobile ids whose broadcast identity string carries a usable call sign,
# joined to their actual ping span in the trail - independent of vessel_ais_key.
mob <-
  read_parquet(fd_raw("ais", "stk", "mobile.parquet")) |>
  mutate(loid_t = toupper(gsub("[^A-Za-z0-9]", "", loid)),
         glid_t = toupper(gsub("[^A-Za-z0-9]", "", glid))) |>
  filter(nchar(glid_t) >= 4 | nchar(loid_t) >= 4)

pingspan <-
  open_dataset(fd_raw("ais", "stk", "trail")) |>
  filter(mid %in% !!unique(mob$mid)) |>
  group_by(mid) |>
  summarise(pings = n(), t1 = min(time, na.rm = TRUE), t2 = max(time, na.rm = TRUE)) |>
  collect() |>
  filter(pings > 0)

mobp <- mob |> inner_join(pingspan, by = "mid") |> select(mid, glid_t, loid_t, pings, t1, t2)

key <- read_parquet(fd_curated("vessel", "vessel_ais_key_cascade.parquet")) |>
  distinct(mid, key_vid = vid)

## For every vid, find the best-covering mid sharing its call sign ------------
best_match <- function(i) {
  r <- reg_l[i, ]
  cands <- mobp |> filter(glid_t == r$cs_t | loid_t == r$cs_t)
  if (nrow(cands) == 0) return(NULL)
  cands <- cands |>
    mutate(covers = as.Date(t1) <= r$last_landing & as.Date(t2) >= r$first_landing)
  best <- cands |> arrange(desc(covers)) |> slice(1)
  if (!best$covers) return(NULL)
  cbind(r[, c("vid", "vessel", "cs", "landings", "first_landing", "last_landing")], best)
}
covering <- bind_rows(lapply(seq_len(nrow(reg_l)), best_match))

## Is that mid already keyed to THIS vid, under any time window? -------------
already_ok <- covering |>
  left_join(key, by = "mid", relationship = "many-to-many") |>
  group_by(vid, vessel, cs, landings, first_landing, last_landing, mid, pings, t1, t2) |>
  summarise(is_correctly_keyed = any(key_vid == vid, na.rm = TRUE), .groups = "drop")

mismatch <- already_ok |> filter(!is_correctly_keyed)

## Bucket by how strong the signal is -----------------------------------------
# Carry the SOURCE vid's own landing window alongside each destination row, so
# the handover test never has to look back into another frame mid-summarise.
dst <- mismatch |>
  select(vid, vessel, cs, landings, first_landing, last_landing, mid) |>
  left_join(key, by = "mid", relationship = "many-to-many") |>
  distinct(vid, vessel, cs, landings, first_landing, last_landing, mid, key_vid) |>
  left_join(lnd |> rename(dst_landings = landings, dst_first = first_landing, dst_last = last_landing),
            by = c("key_vid" = "vid")) |>
  left_join(reg |> select(vid, dst_vessel = vessel), by = c("key_vid" = "vid"))

bucket <- dst |>
  group_by(vid, vessel, cs, landings, first_landing, last_landing) |>
  summarise(
    all_ghost = all(is.na(key_vid) | is.na(dst_landings)),
    all_handover = all(is.na(key_vid) | is.na(dst_landings) |
                          dst_last < first_landing | dst_first > last_landing),
    assigned_to = paste0(coalesce(as.character(key_vid), "UNMATCHED"),
                         ifelse(is.na(dst_vessel), "",
                                paste0(" (", dst_vessel, ", ", coalesce(as.character(dst_landings), "0"),
                                       " lnd ", dst_first, "..", dst_last, ")")),
                        collapse = "; "),
    .groups = "drop") |>
  mutate(category = case_when(
    all_ghost                    ~ "A_ghost",
    all_handover                 ~ "B_handover",
    first_landing == last_landing ~ "D_single_day",
    .default                     = "C_overlapping"
  )) |>
  select(-all_ghost, -all_handover)

out <- mismatch |>
  distinct(vid, mid, pings) |>
  right_join(bucket, by = "vid") |>
  select(vid, vessel, cs, landings, first_landing, last_landing, mid, pings, category, assigned_to) |>
  arrange(category, desc(landings))

## Emit ------------------------------------------------------------------------
print(out |> count(category, name = "vessels") |>
        knitr::kable(caption = "ais_key_reused_callsign"))
print(out |> filter(category == "A_ghost") |>
        select(vid, vessel, cs, landings, first_landing, last_landing, assigned_to) |>
        knitr::kable(caption = "ghost: current vid could not have made these landings"))

write_curated(out, fd_curated("check", "ais_key_reused_callsign.parquet"),
              # stk/trail/ is a partitioned directory, not a file - tools::md5sum()
              # cannot hash it, so it is left out of `inputs` like every other
              # directory-shaped source in this repo; the single mobile.parquet
              # file still ties this check to the raw STK identity table.
              inputs = c(vessel_ais_key = fd_curated("vessel", "vessel_ais_key_cascade.parquet"),
                         vessel         = fd_curated("vessel", "vessel.parquet"),
                         stk_mobile     = fd_raw("ais", "stk", "mobile.parquet"),
                         landing        = fd_curated("landing", "landings.parquet")))
