# Each feed identity, over time, to a hull and its vid: the crosswalk of plan 021 (steps 3 and 4).
# Side: preprocessing (vessels). See plan 014; plan 021 §4, §6 b, c, f.
#
# Input:  staging/astd/identity.parquet, staging/astd_b/identity.parquet, staging/emodnet/identity.parquet
#           - what each MMSI feed claims, by MMSI and year (sources/*/identity.R)
#         curated/vessel/vessel_identity.parquet - the Icelandic MMSI periods (plan 016's archive)
#         curated/vessel/vessel.parquet - the IMO and call sign of every registry vid, foreign vids included
#         curated/vessel/vessel_identity_foreign.parquet - the EU and Faroese registers and GFW, by MMSI and period
#         curated/vessel/vessel_ais_key.parquet - STK mobile-id -> vid (frozen, `once`)
#         raw/oracle/stk/mobile.parquet, through stk_mobile() - every STK mobile-id (R/stk_trail.R)
#         staging/aux/maritime_identification_digits.parquet
#         overrides/vessel_ais_link.csv - reviewed links: the only way a held-out MMSI-year gets a hull
#         curated/vessel/vid_ledger/ - hull -> vid, append-only, extended by allocate_vids() (R/allocate_vids.R)
# Output: curated/vessel/vessel_ais_link.parquet - one row per feed id and period: its hull and vid, or the reason it has
#           none. `feed` is `stk` (mobile-id) or `mmsi` (ASTD, astdB and EMODnet: an MMSI names one transmitter in every
#           feed, so it is linked once; `feeds` says which carried it)
#         curated/check/vessel_ais_link_review.parquet - the MMSI-years held out, and the links a person should look at
#
# Which hull an MMSI names, by plan 008 §5.0's hierarchy (plan 021 §4), tried for each MMSI and year:
#   1. an MMSI in the Icelandic archive is its registry vid, in the archive's periods, opened at both ends and cut where
#      the holder changes, exactly as curate/ais_ping_union.R reads it. Nothing below touches such an MMSI;
#   2. else an IMO with a valid check digit: the register's (EU, Faroese) for that MMSI at the time, else the feed's
#      own (§6 c, basis `broadcast`). An IMO that is a registry vid's is that vid: the vid is the keel, as an IMO is.
#      So is the IMO of an MMSI that a reviewed link (below) puts on a registry vid;
#   3. else the register's own id (EU CFR, Faroese id), matched by MMSI. Norway's register has no MMSI and ASTD no call
#      sign, so Norway is reached only through an IMO until GFW's Vessels API pass (below);
#   4. else the MMSI itself (`mmsi_<n>`, basis `broadcast`).
# A name never matches. The years with no evidence of their own take the hull of the years before them, or failing
# that after them: an MMSI is one hull until the evidence splits it (§4), and those years carry basis `reconstructed`.
#
# Held out, with no hull until overrides/vessel_ais_link.csv gives one (§6 c), an MMSI-year where:
#   - the feed claims two or more valid IMOs (`two_imos`), or the registers give two ids (`register_two_ids`). An IMO
#     with 99 % or more of the segment's IMO pings takes it by rule (the maintainer, 2026-10-23): `imo_flag` `dominant`;
#   - the IMO it claims is claimed by another MMSI at the same time: the first and last pings of that IMO on the two
#     overlap by a day or more (`imo_two_mmsis`). A reflag the same day is not. So is an IMO that reaches a registry
#     vid while that vid holds an Icelandic MMSI, by the archive's dates;
#   - its IMO is on two registry vids, or on a vid that has two (`imo_registry_conflict`);
#   - a register reaches it through a call sign that a foreign vid holds (`foreign_vid_candidate`): it may be that vid,
#     whose number landings use (§4), and a vid given now could not be taken back;
#   - it has no evidence and the year it would be carried from is held out (`continued_conflict`).
#
# GFW's Vessels API pass (§6 d) is not built: it waits on the maintainer's token. Its place is rule 2 and 3: the API's
# IMO and call sign by MMSI and period join `reg` below as one more register (source `gfw_api`), so a broadcast hull it
# reaches gets an IMO, or a Norwegian register id through the call sign, and keeps its vid through `alt_keys`.

library(dplyr)
library(tidyr)
library(duckdbfs)
library(nanoparquet)

# Periods are half-open UTC timestamps, [t1, t2): a handover is cut at the first ping of the new holder, and a date
# period of a registry runs to the end of its last day. NA is open; these stand in for it in comparisons only. The end
# is infinity, not a far date: the STK key has stretches to 2106 (decision 183).
T_OPEN1 <- as.POSIXct("1900-01-01", tz = "UTC")
T_OPEN2 <- .POSIXct(Inf, tz = "UTC")
OVERLAP_DAYS <- 1
DOMINANT <- 0.99   # the share of a segment's IMO pings with which one IMO takes it over the others
day_start <- function(d) as.POSIXct(as.Date(d), tz = "UTC")      # a date's first instant
day_after <- function(d) as.POSIXct(as.Date(d) + 1L, tz = "UTC")  # the instant after an inclusive end date
year_start <- function(y) as.POSIXct(paste0(y, "-01-01"), tz = "UTC")

mid <- read_parquet(fd_staging("aux", "maritime_identification_digits.parquet"))$MID

# A name, compared and never matched (§4): two sets of names (`|`-separated) are the same vessel's unless no word of
# one is like a word of the other: equal, one inside the other, or a typo apart (at most 15 % of the letters, one in a
# short word), or the names equal with blanks and signs removed. Words under three letters are not compared, and NA is no
# evidence: the same. Generous on purpose: a wrong "same" only carries a hull over, as before the cut; a wrong
# "different" splits one vessel in two ("HDMS HVIDBJORNEN", "HVIDBJOERNEN" and "DANISH WARSHIP F360" are one ship).
name_words <- function(x) { w <- unlist(strsplit(toupper(x), "[^A-Z0-9]+")); unique(w[nchar(w) >= 3]) }
same_name1 <- function(x, y) {
  if (is.na(x) || is.na(y)) return(TRUE)
  cx <- gsub("[^A-Z0-9|]", "", toupper(x)); cy <- gsub("[^A-Z0-9|]", "", toupper(y))
  if (length(intersect(strsplit(cx, "|", fixed = TRUE)[[1]], strsplit(cy, "|", fixed = TRUE)[[1]]))) return(TRUE)
  a <- name_words(x); b <- name_words(y)
  if (!length(a) || !length(b)) return(TRUE)
  for (u in a) for (w in b) {
    if (u == w || (nchar(u) >= 4 && nchar(w) >= 4 && (grepl(u, w, fixed = TRUE) || grepl(w, u, fixed = TRUE)))) return(TRUE)
    if (utils::adist(u, w)[1, 1] <= max(1, floor(0.15 * max(nchar(u), nchar(w))))) return(TRUE)
  }
  FALSE
}
same_name <- function(a, b) mapply(same_name1, a, b, USE.NAMES = FALSE)
add_names <- function(set, x) {
  if (is.na(x)) return(set)
  if (is.na(set)) return(x)
  paste(unique(c(strsplit(set, "|", fixed = TRUE)[[1]], strsplit(x, "|", fixed = TRUE)[[1]])), collapse = "|")
}

## The feeds' claims ----------------------------------------------------------------------------------------------------
astd   <- duckdbfs::open_dataset(fd_staging("astd", "identity.parquet"))
astd_b <- duckdbfs::open_dataset(fd_staging("astd_b", "identity.parquet"))
emn    <- duckdbfs::open_dataset(fd_staging("emodnet", "identity.parquet"))

# One row per MMSI, year, IMO and name, with its pings and its first and last ping. An IMO that fails the check digit
# names nothing (plan 021, assumed), so it counts as none.
cl <- bind_rows(
  astd |> group_by(mmsi, year, imo, name) |>
    summarise(pings = sum(pings), hours = sum(hours), hours_box = sum(hours_box),
              t_first = min(t_first), t_last = max(t_last), .groups = "drop") |> collect() |> mutate(feed = "astd"),
  astd_b |> group_by(mmsi, year) |>
    summarise(pings = sum(pings), t_first = min(t_first), t_last = max(t_last), .groups = "drop") |> collect() |>
    mutate(feed = "astd_b"),
  emn |> group_by(mmsi, year, imo, name) |>
    summarise(pings = sum(pings), t_first = min(t_first), t_last = max(t_last), .groups = "drop") |> collect() |>
    mutate(feed = "emodnet")) |>
  mutate(year = as.integer(year), imo = if_else(is_valid_imo(imo), imo, NA_character_),
         name = na_if(toupper(trimws(name)), ""),
         hours = coalesce(hours, 0), hours_box = coalesce(hours_box, 0))

my <- cl |> group_by(mmsi, year) |>
  summarise(astd = any(feed == "astd"), astd_b = any(feed == "astd_b"), emodnet = any(feed == "emodnet"),
            pings = sum(pings), hours = sum(hours), hours_box = sum(hours_box), .groups = "drop") |>
  mutate(kind = mmsi_kind(mmsi, mid))
feeds_of <- function(astd, astd_b, emodnet)
  sub("^;", "", paste0(if_else(astd, "astd", ""), if_else(astd_b, ";astd_b", ""), if_else(emodnet, ";emodnet", "")))

# Each IMO an MMSI claims in a year, with the first and last ping that carries it
iy <- cl |> filter(!is.na(imo)) |> group_by(mmsi, year, imo) |>
  summarise(pings = sum(pings), t_first = min(t_first), t_last = max(t_last), .groups = "drop")

## The registries -------------------------------------------------------------------------------------------------------
vi <- read_parquet(fd_curated("vessel", "vessel_identity.parquet"))
v  <- read_parquet(fd_curated("vessel", "vessel.parquet"))
vf <- read_parquet(fd_curated("vessel", "vessel_identity_foreign.parquet")) |>
  select(source, external_id, mmsi, cs, imo, t1, t2) |>
  mutate(mmsi = trimws(mmsi), cs = toupper(trimws(cs)),
         r1 = coalesce(day_start(t1), T_OPEN1), r2 = coalesce(day_after(t2), T_OPEN2))

# The reviewed links, applied below (after the computed ones) and read here for the IMOs they give a registry vid.
# A confirmed row replaces whatever was computed for that MMSI in [t1, t2) (UTC; a date is its first instant, an empty
# field is open); hull `none` says it is no vessel. An accessory (a net relay, a tender) takes its ship's hull with role
# `accessory` (§6 b).
as_utc <- function(x) as.POSIXct(ifelse(nchar(x) == 10, paste(x, "00:00:00"), x), tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
ov <- readr::read_csv("overrides/vessel_ais_link.csv", col_types = readr::cols(.default = "c")) |>
  filter(decision == "confirmed") |>
  mutate(t1 = as_utc(t1), t2 = as_utc(t2))
stopifnot(all(ov$feed == "mmsi"), all(ov$role %in% c("vessel", "accessory")),
          all(grepl("^(vid|imo|mmsi|eu|fro)_|^none$", ov$hull)))

# An IMO that is a registry vid's names that vid. So does the IMO of an MMSI that a reviewed link puts on a registry vid
# (the maintainer, 2026-10-23): the one IMO it carries in the link's period, from the feeds or a register. A foreign vid
# (3699-4999) has none in vessel.parquet, and without this an MMSI carrying the same hull's IMO (the vessel sold abroad)
# would get a hull and a vid of its own. A reviewed link whose MMSI carries two IMOs in its period gives none. An IMO on
# two vids (8817540: 1352 and 2220), or a vid with two IMOs (vessel.parquet and vessel_identity disagreeing), names no
# vid: one of them is wrong, and a person says which.
imo_vid_reg <- bind_rows(v |> select(vid, imo), vi |> select(vid, imo)) |>
  filter(!is.na(vid), is_valid_imo(imo)) |> distinct()
ov_vid <- ov |> filter(startsWith(hull, "vid_")) |>
  transmute(mmsi = feed_id, vid = as.integer(sub("^vid_", "", hull)), o1 = coalesce(t1, T_OPEN1), o2 = coalesce(t2, T_OPEN2))
imo_vid_ov <- bind_rows(
  ov_vid |> inner_join(iy, by = "mmsi", relationship = "many-to-many") |>
    filter(t_first < o2, t_last >= o1) |> select(mmsi, vid, o1, imo),
  ov_vid |> inner_join(vf |> filter(source %in% c("eu", "fro"), is_valid_imo(external_id)), by = "mmsi",
                       relationship = "many-to-many") |>
    filter(r1 < o2, r2 > o1) |> transmute(mmsi, vid, o1, imo = external_id)) |>
  distinct() |>
  group_by(mmsi, vid, o1) |> filter(n() == 1) |> ungroup() |>
  distinct(vid, imo)
imo_vid <- bind_rows(imo_vid_reg, imo_vid_ov) |> distinct()
imo_registry_conflict <- imo_vid |>
  filter(imo %in% imo[duplicated(imo)] | vid %in% vid[duplicated(vid)]) |> pull(imo) |> unique()
imo_vid <- imo_vid |> filter(!imo %in% imo_registry_conflict)

# Every IMO a register holds, for plan 021 §2.2's route 4 ("the IMO in a register"); a reviewed link is not a register
imo_in_register <- unique(c(imo_vid$imo[imo_vid$imo %in% imo_vid_reg$imo], vf$imo[is_valid_imo(vf$imo)]))

# Foreign vids (Oracle's `Erlent`): reachable only through a call sign, which a register may hold with an MMSI
fvid_cs <- v |> filter(foreign, !is.na(cs)) |> transmute(cs = toupper(trimws(cs)), fvid = vid) |> distinct()

## 1. The Icelandic MMSIs: the archive's periods, as the union reads them -------------------------------------------------
# One holder matches at any time; several are split where the holder changes, the first open at the start and the last
# at the end. A period with no known hull (curate/corrections/mmsi_broadcast_unregistered.yml) is kept after the opening,
# so it cuts its neighbour's window, and has no vid. A time between two holders' periods has none either.
isl_mmsi <- unique(vi$mmsi[!is.na(vi$mmsi)])
isl <- vi |>
  filter(!is.na(mmsi), mmsi %in% my$mmsi) |>
  distinct(mmsi, vid, source, t1 = mmsi_t1, t2 = mmsi_t2) |>
  group_by(mmsi) |> arrange(t1, .by_group = TRUE) |>
  mutate(t1 = if_else(row_number() == 1L, as.POSIXct(NA, tz = "UTC"), day_start(t1)),
         t2 = if_else(row_number() == n(),  as.POSIXct(NA, tz = "UTC"), day_after(t2))) |>
  ungroup()
stopifnot(!anyDuplicated(isl[c("mmsi", "t1")]))
isl_gap <- isl |> group_by(mmsi) |>
  mutate(g1 = lag(t2), g2 = t1) |> ungroup() |>
  filter(!is.na(g1), !is.na(g2), g2 > g1) |>
  transmute(mmsi, t1 = g1, t2 = g2, vid = NA_integer_, source = NA_character_, gap = TRUE)
isl <- bind_rows(isl |> mutate(gap = FALSE), isl_gap) |>
  transmute(feed = "mmsi", feed_id = mmsi, t1, t2,
            hull = if_else(!is.na(vid), paste0("vid_", vid), NA_character_),
            link = if_else(!is.na(vid), "isl", NA_character_),
            basis = if_else(!is.na(vid), "recorded", NA_character_),
            vid_reason = case_when(!is.na(vid) ~ NA_character_, gap ~ "isl_gap", TRUE ~ "isl_unregistered"),
            register = tolower(source), role = "vessel")

## 2-4. Every other valid MMSI, by segment --------------------------------------------------------------------------------
# A segment is a year, cut where the claims hand over without overlapping (the maintainer, 2026-10-17, amending §6 c):
#   - `imo_handover`: two or more IMOs in a year, each one's last ping before the next one's first: cut at the first
#     ping of each later IMO. IMOs whose pings overlap hold the year out (`two_imos`);
#   - `name_handover`: pings with no IMO under a name that differs from every name the year's IMO pings carry, all
#     before the first IMO ping or all after the last: cut there. Such pings inside the IMO's span cut nothing.
fy_mmsi <- my |> filter(kind == "ship", !mmsi %in% isl_mmsi) |> pull(mmsi) |> unique()
fcl <- cl |> filter(mmsi %in% fy_mmsi)
fiy <- iy |> filter(mmsi %in% fy_mmsi) |> arrange(mmsi, year, t_first)

imo_cut <- fiy |>
  group_by(mmsi, year) |>
  filter(n() >= 2) |>
  mutate(clean = all(as.numeric(t_first[-1]) > cummax(as.numeric(t_last))[-n()])) |>
  filter(clean, row_number() > 1) |>
  ungroup() |>
  transmute(mmsi, year, cut = t_first, why = "imo_handover")
two_imo_years <- fiy |> count(mmsi, year) |> filter(n >= 2) |>
  left_join(imo_cut |> distinct(mmsi, year) |> mutate(clean = TRUE), by = c("mmsi", "year")) |>
  mutate(clean = coalesce(clean, FALSE))

imo_span <- fiy |> group_by(mmsi, year) |>
  summarise(fi = min(t_first), li = max(t_last), .groups = "drop") |>
  anti_join(two_imo_years |> filter(!clean), by = c("mmsi", "year"))
imo_names <- fcl |> filter(!is.na(imo), !is.na(name)) |> group_by(mmsi, year) |>
  summarise(inames = paste(unique(name), collapse = "|"), .groups = "drop")
name_cut <- fcl |> filter(is.na(imo), !is.na(name)) |>
  group_by(mmsi, year, name) |> summarise(f = min(t_first), l = max(t_last), .groups = "drop") |>
  inner_join(imo_span, by = c("mmsi", "year")) |>
  filter(l < fi | f > li) |>
  left_join(imo_names, by = c("mmsi", "year")) |>
  filter(!same_name(name, inames)) |>
  # pings after the IMO's last cut once, at the first of them; pings before its first, once, at the IMO's first ping
  mutate(side = if_else(f > li, "after", "before"), cut = if_else(side == "after", f, fi)) |>
  group_by(mmsi, year, side) |>
  summarise(cut = min(cut), .groups = "drop") |>
  transmute(mmsi, year, cut, why = "name_handover")

seg <- bind_rows(my |> filter(mmsi %in% fy_mmsi) |> transmute(mmsi, year, pt = year_start(year), why = NA_character_),
                 imo_cut |> rename(pt = cut), name_cut |> rename(pt = cut)) |>
  arrange(mmsi, year, pt) |>
  distinct(mmsi, year, pt, .keep_all = TRUE) |>
  mutate(s1 = pt,
         s2 = if_else(lead(mmsi, default = "") == mmsi & lead(year, default = -1L) == year, lead(pt), year_start(year + 1L)),
         seg = row_number()) |>
  select(seg, mmsi, year, s1, s2, cut = why)

# Each claim to the segment it starts in
sc <- fcl |> select(mmsi, year, feed, imo, name, pings, hours, hours_box, t_first, t_last) |>
  inner_join(seg, by = join_by(mmsi, year, between(t_first, s1, s2, bounds = "[)")))
s_imo <- sc |> filter(!is.na(imo)) |> group_by(seg, imo) |>
  summarise(p = sum(pings), f = min(t_first), l = max(t_last), .groups = "drop") |>
  group_by(seg) |> arrange(desc(p), .by_group = TRUE) |>
  summarise(n_imo = n(), imo_feed = first(imo), imo_share = first(p) / sum(p), imo_f = first(f), imo_l = first(l),
            imos = paste(imo, collapse = ";"), imo_other = if (n() > 1) paste(imo[-1], collapse = ";") else NA_character_,
            .groups = "drop")
# The segment's names, all of them for the comparison, the most frequent to show
s_name <- sc |> filter(!is.na(name)) |> group_by(seg, name) |> summarise(p = sum(pings), .groups = "drop") |>
  group_by(seg) |> arrange(desc(p), .by_group = TRUE) |>
  summarise(names = paste(name, collapse = "|"), name = first(name), .groups = "drop")
s_vol <- sc |> group_by(seg) |>
  summarise(astd = any(feed == "astd"), astd_b = any(feed == "astd_b"), emodnet = any(feed == "emodnet"),
            pings = sum(pings), hours = sum(hours), hours_box = sum(hours_box), .groups = "drop")

overlapping <- function(src) {
  seg |> select(seg, mmsi, s1, s2) |>
    inner_join(vf |> filter(source %in% src, !is.na(mmsi)), by = "mmsi", relationship = "many-to-many") |>
    filter(r1 < s2, r2 > s1)
}
reg <- overlapping(c("eu", "fro")) |> distinct(seg, source, external_id, cs)
reg_s <- reg |> group_by(seg) |>
  summarise(n_reg = n_distinct(external_id), reg_id = first(external_id),
            reg_ids = paste(sort(unique(external_id)), collapse = ";"),
            reg_source = paste(sort(unique(source)), collapse = ";"), .groups = "drop")
gfw_s <- overlapping("gfw") |> distinct(seg) |> mutate(gfw = TRUE)
fcand_s <- reg |> inner_join(fvid_cs, by = "cs", relationship = "many-to-many") |>
  group_by(seg) |> summarise(fvids = paste(sort(unique(fvid)), collapse = ";"), .groups = "drop")

# An IMO on two MMSIs at the same time, Icelandic MMSIs included as the other party
ic <- iy |> filter(mmsi_kind(mmsi, mid) == "ship")
twin <- ic |> inner_join(ic, by = c("imo", "year"), suffix = c("", "_b"), relationship = "many-to-many") |>
  filter(mmsi != mmsi_b) |>
  mutate(overlap_days = as.numeric(difftime(pmin(t_last, t_last_b), pmax(t_first, t_first_b), units = "days"))) |>
  filter(overlap_days >= OVERLAP_DAYS) |>
  group_by(mmsi, year, imo) |>
  summarise(twin_with = paste(sort(unique(mmsi_b)), collapse = ";"), overlap_days = max(overlap_days), .groups = "drop")

# An IMO that reaches a registry vid while that vid holds an Icelandic MMSI is an IMO on two MMSIs at once as well,
# whether or not the Icelandic MMSI broadcasts its IMO: the archive's own dates here, not the opened windows
isl_held <- vi |> filter(!is.na(mmsi), !is.na(vid)) |>
  distinct(rvid = vid, isl_mmsi = mmsi, p1 = day_start(mmsi_t1), p2 = day_after(mmsi_t2))

a <- seg |>
  left_join(s_vol, by = "seg") |>
  left_join(s_imo, by = "seg") |>
  left_join(s_name, by = "seg") |>
  left_join(reg_s, by = "seg") |>
  left_join(gfw_s, by = "seg") |>
  left_join(fcand_s, by = "seg") |>
  left_join(twin, by = c("mmsi", "year", imo_feed = "imo")) |>
  mutate(n_reg = coalesce(n_reg, 0L), n_imo = coalesce(n_imo, 0L), gfw = coalesce(gfw, FALSE),
         # IMOs that overlap hold a segment out, unless one has 99 % or more of its IMO pings: that one takes it
         dominant = n_imo >= 2 & imo_share >= DOMINANT,
         one_imo = n_imo == 1 | dominant,
         twin_with = if_else(one_imo, twin_with, NA_character_),
         reg_imo = n_reg == 1 & is_valid_imo(reg_id),
         imo = case_when(reg_imo ~ reg_id, one_imo ~ imo_feed),
         link = case_when(reg_imo ~ "register_imo", one_imo ~ "feed_imo", n_reg == 1 ~ "register_id"),
         imo_differs = reg_imo & one_imo & imo_feed != reg_id,
         imo_flag = if_else(dominant, "dominant", NA_character_)) |>
  left_join(imo_vid |> transmute(imo, rvid = vid), by = "imo")
vid_twin <- a |> filter(!is.na(rvid)) |>
  transmute(seg, rvid, f = coalesce(imo_f, s1), l = coalesce(imo_l, s2)) |>
  inner_join(isl_held, by = "rvid", relationship = "many-to-many") |>
  filter(as.numeric(difftime(pmin(l, coalesce(p2, T_OPEN2)), pmax(f, coalesce(p1, T_OPEN1)), units = "days")) >= OVERLAP_DAYS) |>
  group_by(seg) |> summarise(vid_twin = paste(sort(unique(isl_mmsi)), collapse = ";"), .groups = "drop")
a <- a |>
  left_join(vid_twin, by = "seg") |>
  mutate(twin_with = coalesce(twin_with, vid_twin),
         held = case_when(n_reg >= 2 ~ "register_two_ids",
                          n_imo >= 2 & !dominant ~ "two_imos",
                          !is.na(twin_with) ~ "imo_two_mmsis",
                          imo %in% imo_registry_conflict ~ "imo_registry_conflict",
                          !is.na(fvids) & is.na(rvid) ~ "foreign_vid_candidate"),
         hull = case_when(!is.na(rvid) ~ paste0("vid_", rvid), !is.na(imo) ~ paste0("imo_", imo),
                          link == "register_id" ~ reg_id),
         state = if_else(!is.na(held), paste0("!", held), hull)) |>
  arrange(mmsi, s1)

# Carry the evidence over the segments that have none: forward, then the leading ones backward. A segment under a name
# that differs from the one carried is another vessel (case 2 of the maintainer's direction, 2026-10-17: the IMO stops
# and the name changes at once): it starts a broadcast hull of its own, which the segments after it under that name
# join. An MMSI with no evidence at all is one broadcast hull, whatever its names: a name alone splits nothing.
carry <- function(mmsi, state, nm) {   # nm: the segment's names, `|`-separated
  n <- length(state); src <- ifelse(is.na(state), NA_integer_, seq_len(n)); split <- rep(FALSE, n)
  from <- rep(NA_character_, n)
  pass <- function(idx) {
    cs <- NA_character_; cn <- NA_character_; ci <- NA_integer_; cm <- ""
    for (i in idx) {
      if (mmsi[i] != cm) { cs <- NA_character_; cn <- NA_character_; ci <- NA_integer_; cm <- mmsi[i] }
      if (!is.na(state[i])) {
        if (!identical(state[i], cs)) cn <- NA_character_
        cs <- state[i]; ci <- src[i]
        cn <- add_names(cn, nm[i])
        next
      }
      if (is.na(cs)) next
      if (same_name1(nm[i], cn)) {
        state[i] <<- cs; src[i] <<- ci; cn <- add_names(cn, nm[i])
      } else {
        state[i] <<- paste0("mmsi_", mmsi[i], "@", i); src[i] <<- i; split[i] <<- TRUE; from[i] <<- cn
        cs <- state[i]; ci <- i; cn <- nm[i]
      }
    }
  }
  pass(seq_len(n))
  pass(rev(seq_len(n)))
  list(state = state, src = src, split = split, from = from)
}
own <- !is.na(a$state)
mixed <- a$mmsi %in% intersect(a$mmsi[own], a$mmsi[!own])
k <- carry(a$mmsi[mixed], a$state[mixed], a$names[mixed])
a$state2 <- a$state; a$src <- ifelse(own, seq_len(nrow(a)), NA_integer_); a$split <- FALSE
a$state2[mixed] <- k$state; a$src[mixed] <- which(mixed)[k$src]; a$split[mixed] <- k$split
a$split_from <- NA_character_; a$split_from[mixed] <- k$from

a <- a |>
  mutate(own = !is.na(state),
         src_link = link[src], src_name = name[src], src_s1 = s1[src],
         held = case_when(startsWith(state2, "!") & own ~ sub("^!", "", state2),
                          startsWith(state2, "!") ~ "continued_conflict"),
         hull = case_when(!is.na(held) ~ NA_character_,
                          !is.na(state2) ~ state2,
                          TRUE ~ paste0("mmsi_", mmsi)),
         link = case_when(!is.na(held) ~ NA_character_,
                          own ~ link,
                          startsWith(hull, "mmsi_") ~ "mmsi",
                          TRUE ~ src_link),
         basis = case_when(!is.na(held) ~ NA_character_,
                           !own & !startsWith(hull, "mmsi_") ~ "reconstructed",
                           link %in% c("register_imo", "register_id") ~ "recorded",
                           TRUE ~ "broadcast"),
         imo_flag = case_when(!is.na(held) | startsWith(hull, "mmsi_") ~ NA_character_,
                              own ~ imo_flag,
                              TRUE ~ imo_flag[src]),
         register = paste0(coalesce(reg_source, ""), if_else(gfw, if_else(is.na(reg_source), "gfw", ";gfw"), "")),
         register = na_if(register, ""),
         # the other keys this MMSI has had in the segment, for allocate_vids() (§6 i)
         alt = paste(paste0("mmsi_", mmsi),
                     coalesce(gsub("(^|;)([0-9]{7})(?=;|$)", "\\1imo_\\2", reg_ids, perl = TRUE), ""),
                     coalesce(gsub("(^|;)([0-9]{7})", "\\1imo_\\2", imos), ""), sep = ";"))
# A split hull's key is the MMSI and the day it starts: stable while that start is
at <- which(grepl("@", a$hull))
if (length(at)) {
  start <- tapply(as.numeric(a$s1[at]), a$hull[at], min)
  a$hull[at] <- paste0(sub("@.*", "", a$hull[at]), "_",
                       format(as.POSIXct(start[a$hull[at]], origin = "1970-01-01", tz = "UTC"), "%Y%m%d"))
}

## Periods: consecutive segments with the same outcome --------------------------------------------------------------------
keys_minus <- function(alt, hull) {
  k <- setdiff(unique(unlist(strsplit(alt, ";"))), c("", hull))
  if (length(k)) paste(sort(k), collapse = ";") else NA_character_
}
nonisl <- a |>
  arrange(mmsi, s1) |>
  mutate(rk = paste(mmsi, hull, link, basis, imo_flag, held, register, sep = "|"),
         run = cumsum(rk != lag(rk, default = ""))) |>
  group_by(run) |>
  summarise(mmsi = first(mmsi), t1 = first(s1), t2 = last(s2), cut = first(cut), hull = first(hull), link = first(link),
            basis = first(basis), imo_flag = first(imo_flag), held = first(held), register = first(register),
            feeds = feeds_of(any(astd, na.rm = TRUE), any(astd_b, na.rm = TRUE), any(emodnet, na.rm = TRUE)),
            alt = paste(alt, collapse = ";"), .groups = "drop") |>
  mutate(alt_keys = mapply(keys_minus, alt, hull, USE.NAMES = FALSE)) |>
  left_join(imo_vid |> transmute(hull = paste0("vid_", vid), vimo = imo), by = "hull") |>
  transmute(feed = "mmsi", feed_id = mmsi, t1, t2, cut, hull, link, basis,
            vid_reason = if_else(!is.na(held), "held_out", NA_character_), held, register, role = "vessel",
            # the hull's IMO: its key, or the registry vid's that the IMO reached; a register-id or broadcast hull has none
            imo = if_else(!is.na(hull) & startsWith(hull, "imo_"), sub("^imo_", "", hull), vimo),
            # `dominant`: the segment's feed claimed other IMOs too, and this one took it with 99 % of the IMO pings
            imo_flag, feeds, alt_keys)

## MMSIs that name no vessel ------------------------------------------------------------------------------------------------
invalid <- my |> filter(kind != "ship", !mmsi %in% isl_mmsi) |>
  group_by(mmsi, kind) |>
  summarise(t1 = year_start(min(year)), t2 = year_start(max(year) + 1L),
            feeds = feeds_of(any(astd), any(astd_b), any(emodnet)), .groups = "drop") |>
  transmute(feed = "mmsi", feed_id = mmsi, t1, t2, vid_reason = "invalid_mmsi", mmsi_kind = kind,
            role = if_else(kind == "craft_associated", "accessory", "other"), feeds)

isl <- isl |> left_join(my |> group_by(mmsi) |> summarise(feeds = feeds_of(any(astd), any(astd_b), any(emodnet))),
                        by = c(feed_id = "mmsi")) |>
  mutate(imo = NA_character_)

link <- bind_rows(isl, nonisl, invalid) |>
  mutate(mmsi_kind = mmsi_kind(feed_id, mid))

## Reviewed links (overrides/vessel_ais_link.csv, read above) ---------------------------------------------------------------
for (i in seq_len(nrow(ov))) {
  o <- ov[i, ]
  o1 <- coalesce(o$t1, T_OPEN1); o2 <- coalesce(o$t2, T_OPEN2)
  hit <- link$feed_id == o$feed_id & coalesce(link$t1, T_OPEN1) < o2 & coalesce(link$t2, T_OPEN2) > o1
  pieces <- bind_rows(
    link[hit & coalesce(link$t1, T_OPEN1) < o1, ] |> mutate(t2 = o1),
    link[hit & coalesce(link$t2, T_OPEN2) > o2, ] |> mutate(t1 = o2))
  link <- bind_rows(link[!hit, ], pieces,
                    tibble(feed = "mmsi", feed_id = o$feed_id, t1 = o$t1, t2 = o$t2,
                           hull = na_if(o$hull, "none"), link = "override", basis = "recorded", role = o$role,
                           vid_reason = if_else(o$hull == "none", "override_none", NA_character_),
                           mmsi_kind = mmsi_kind(o$feed_id, mid),
                           imo = if_else(startsWith(o$hull, "imo_"), sub("^imo_", "", o$hull), NA_character_)))
}

## STK: the frozen key, as it is ------------------------------------------------------------------------------------------
# A mid's last stretch, if open, has no end: NA, not the key's open-end date (decisions 183, 184). Its other stretches end
# where the key ends them, the two open ones that a one-day stretch follows included (mids 102543, 103872).
key <- read_parquet(fd_curated("vessel", "vessel_ais_key.parquet"))
stk <- key |>
  group_by(mid) |> mutate(open_end = d2_is_open & d1 == max(d1)) |> ungroup() |>
  transmute(feed = "stk", feed_id = format(mid, scientific = FALSE, trim = TRUE), t1 = day_start(d1),
            t2 = if_else(open_end, as.POSIXct(NA, tz = "UTC"), day_after(d2)), vid,
            hull = if_else(!is.na(vid), paste0("vid_", vid), NA_character_),
            link = if_else(!is.na(vid), "stk_key", NA_character_), basis = if_else(!is.na(vid), basis, NA_character_),
            vid_reason = case_when(!is.na(vid) ~ NA_character_,
                                   grepl("a person decides", step) ~ "awaiting_review",
                                   entity_class == "vessel" ~ "unkeyed",
                                   TRUE ~ entity_class),
            role = case_when(entity_class == "vessel" ~ "vessel",
                             entity_class %in% c("net_relay", "child_vessel") ~ "accessory",
                             TRUE ~ "other"),
            register = "stk")
# The key was frozen before the dump of 2026-10 (decision 111): STK's mobile table names 14,355 trail mobile-ids it never
# saw (0.56 M pings, 0.48 M of them in 2026, median one ping). They are rowed, with the reason, until the key is redone.
mobile <- stk_mobile() |> distinct(mid) |> collect()
stk <- bind_rows(stk, tibble(feed = "stk", feed_id = format(setdiff(mobile$mid, key$mid), scientific = FALSE, trim = TRUE),
                             vid_reason = "not_in_key"))

## Step 4: hull -> vid --------------------------------------------------------------------------------------------------------
ledger <- read_vid_ledger()
link <- link |>
  left_join(ledger |> select(hull, lvid = vid), by = "hull") |>
  mutate(vid = case_when(!is.na(hull) & startsWith(hull, "vid_") ~ as.integer(sub("^vid_", "", hull)),
                         TRUE ~ lvid),
         vid_reason = case_when(!is.na(vid) ~ NA_character_,
                                !is.na(vid_reason) ~ vid_reason,
                                !is.na(hull) ~ "unallocated")) |>
  select(-lvid) |>
  bind_rows(stk) |>
  mutate(imo_register = !is.na(imo) & imo %in% imo_in_register) |>
  select(feed, feed_id, t1, t2, cut, vid, vid_reason, hull, link, basis, held, role, mmsi_kind, register, imo,
         imo_flag, imo_register, feeds, alt_keys) |>
  arrange(feed, feed_id, coalesce(t1, T_OPEN1))

## Checks (plan 021 §7) ------------------------------------------------------------------------------------------------------
# Every feed id has a row: every MMSI the three feeds carry, every STK mobile-id
stopifnot(setequal(unique(link$feed_id[link$feed == "mmsi"]), unique(my$mmsi)),
          setequal(unique(link$feed_id[link$feed == "stk"]),
                   format(union(key$mid, mobile$mid), scientific = FALSE, trim = TRUE)),
          all(!is.na(link$vid) | !is.na(link$vid_reason)),
          all(coalesce(link$t1, T_OPEN1) < coalesce(link$t2, T_OPEN2)))
# One vid per feed id at a time: no two rows of a feed id overlap
ovl <- link |> mutate(s1 = coalesce(t1, T_OPEN1), s2 = coalesce(t2, T_OPEN2)) |> arrange(feed, feed_id, s1) |>
  filter(feed == lag(feed) & feed_id == lag(feed_id) & s1 < lag(s2))
if (nrow(ovl)) stop("vessel_ais_link: ", nrow(ovl), " rows overlap another of the same feed id, e.g. ",
                    paste(head(unique(ovl$feed_id)), collapse = ", "))
# One vid per IMO, and one IMO per vid
iv <- link |> filter(!is.na(imo), !is.na(vid)) |> distinct(imo, vid)
if (anyDuplicated(iv$imo)) stop("vessel_ais_link: an IMO on two vids: ", paste(head(iv$imo[duplicated(iv$imo)]), collapse = ", "))
if (anyDuplicated(iv$vid)) stop("vessel_ais_link: a vid with two IMOs: ", paste(head(iv$vid[duplicated(iv$vid)]), collapse = ", "))

## What a person should look at -------------------------------------------------------------------------------------------
# Every segment held out, and the links that stand but rest on less: a register IMO the feed contradicts, an IMO taken
# by its share over the others the feed claimed (`imo_other`), a cut at a handover, a carried-over segment's split by name
review <- a |>
  filter(!is.na(held) | imo_differs | dominant | split | !is.na(cut)) |>
  mutate(reason = coalesce(held, if_else(imo_differs, "register_feed_imo_differ", NA_character_),
                           if_else(dominant, "dominant_imo", NA_character_),
                           if_else(split, "split_by_name", NA_character_), cut),
         held_out = !is.na(held)) |>
  left_join(iy |> group_by(mmsi, year) |> arrange(desc(pings), .by_group = TRUE) |>
              summarise(imo_claims = paste0(imo, " (", pings, " pings, ", format(t_first, "%Y-%m-%d %H:%M"), " to ",
                                            format(t_last, "%Y-%m-%d %H:%M"), ")", collapse = "; "), .groups = "drop"),
            by = c("mmsi", "year")) |>
  transmute(mmsi, year, s1, s2, reason, held_out, hull, imo_claims, imo_share, imo_other, twin_with, reg_ids, fvids, name = names,
            split_from, src_name, src_s1, pings, hours, hours_box, feeds = feeds_of(coalesce(astd, FALSE), coalesce(astd_b, FALSE),
                                                                            coalesce(emodnet, FALSE))) |>
  arrange(desc(hours_box), mmsi, s1)

## Write --------------------------------------------------------------------------------------------------------------------
cat("vessel_ais_link:", format(nrow(link), big.mark = ","), "rows\n")
print(link |> count(feed, link, basis, vid_reason) |> arrange(feed, desc(n)), n = Inf)
print(review |> count(reason, held_out, name = "segments"), n = Inf)
print(two_imo_years |> count(clean, name = "mmsi_years"))

inputs <- c(astd_identity = fd_staging("astd", "identity.parquet"),
            astd_b_identity = fd_staging("astd_b", "identity.parquet"),
            emodnet_identity = fd_staging("emodnet", "identity.parquet"),
            vessel_identity = fd_curated("vessel", "vessel_identity.parquet"),
            vessel = fd_curated("vessel", "vessel.parquet"),
            vessel_identity_foreign = fd_curated("vessel", "vessel_identity_foreign.parquet"),
            vessel_ais_key = fd_curated("vessel", "vessel_ais_key.parquet"),
            stk_mobile = fd_raw("oracle", "stk", "mobile.parquet"),
            overrides = "overrides/vessel_ais_link.csv")
write_curated(link, fd_curated("vessel", "vessel_ais_link.parquet"), inputs = inputs)
write_curated(review, fd_curated("check", "vessel_ais_link_review.parquet"), inputs = inputs)
