# Call sign, local sign (ÍS-8) and name of each vessel over time (plan 016 §4 step 6b).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  staging/skipaskra/annual_call_sign.parquet       the annual register's call sign per vid and year, 2007-2022, the
#                                                          state at the start of the year (a frozen input from the `once`
#                                                          project, sources/skipaskra/annual_call_sign.R)
#         raw/oracle/kvoti/skipasaga.parquet              Fiskistofa's dated history: local sign (einkst, einknr) and name
#                                                          (heiti), 1990s to 2023-12-07
#         raw/oracle/vessel/vessel_identification_hist_v.parquet Oracle's dated call sign and local sign (KE-18 from 1954)
#         raw/oracle/vessel/vessel_hist_v.parquet                Oracle's dated name and register status
#         raw/oracle/vessel/vessel_v.parquet                     vessel_id -> vid
# Output: curated/vessel/vessel_sign.parquet - one row per vid, kind (cs | uid | name), value and period [t1, t2)
#
# A vid is the hull for life; its marks are attributes at a time, and they wander: since 2007, 114 of the annual
# register's 517 call signs and 1,614 of 4,101 local signs have passed between hulls, and 1,250 hulls have changed name.
# `vessel_identity` times only the MMSI, so this is a table of its own (splitting identity's rows would repeat its MMSI
# windows, and through the ping union the pings).
#
#   value       as the register writes it: TFBR, ÍS-8, HUGINN
#   key         for matching: upper case, Icelandic letters folded (Í -> I, Þ -> TH, ...), a local sign as letters and
#               a 3-digit number (IS008, as vessel.parquet's uid; STK's loid writes some that way: ÞH061)
#   t1, t2      whole days, t2 exclusive; 2099-12-31 open
#   source      annual_register | skipasaga | oracle_hist
#   window      source (as the source dates it) | cut (closed where the next holder took the mark: a struck hull's last
#               mark stays open in the sources, as ÍS-8 on 1660 from 1996) | merged (consecutive periods of one value) |
#               registration (the source's placeholder start, 1901-01-01, replaced by the hull's first registration) |
#               conflict (two hulls on one mark at once, mostly both taking it on the same day: for a reader to settle)
#
# A call sign or local sign has one holder at a time, bar a few flagged conflicts. A name is history for a reader, never a key: on
# 2020-07-01 HAFDÍS was on 21 hulls at once. Oracle's rows count only while the hull is on the register: a struck hull
# keeps its last call sign open there (TFBR "current" on 1473, 2815 and 3047 at once).

library(dplyr)
library(nanoparquet)

OPEN <- as.Date("2099-12-31")
fold <- function(x) {
  x <- toupper(trimws(x))
  x <- chartr("ÁÉÍÓÚÝÖÆ", "AEIOUYOA", x)
  x <- gsub("Þ", "TH", gsub("Ð", "D", x))
  gsub("[^A-Z0-9]", "", x)
}
uid_value <- function(st, nr) if_else(is.na(st) | is.na(nr), NA_character_, paste0(toupper(trimws(st)), "-", nr))
uid_key   <- function(st, nr) if_else(is.na(st) | is.na(nr), NA_character_, paste0(fold(st), sprintf("%03d", nr)))
as_day <- function(x) as.Date(format(x, "%Y-%m-%d"))

v <- read_parquet(fd_raw("oracle", "vessel", "vessel_v.parquet")) |>
  transmute(vessel_id = as.integer(vessel_id), vid = as.integer(registration_no), foreign = status %in% "Erlent")
FOREIGN <- v$vid[v$foreign]

# Oracle: the periods a hull is on the register (any status but struck), to clip its marks to
oh <- read_parquet(fd_raw("oracle", "vessel", "vessel_hist_v.parquet")) |>
  transmute(vid = as.integer(registration_no), from = as_day(valid_from), to = coalesce(as_day(valid_to), OPEN),
            status, name = trimws(name), reg = as_day(initial_registration_date))
# 1901-01-01 is the sources' placeholder for "held since some unknown day": several hulls then hold one sign at once from
# 1901 (711 of 735 conflicts in a first version). A hull cannot carry a mark before it was registered, so such a period
# starts at the hull's first registration instead (window "registration").
PLACEHOLDER <- as.Date("1901-01-01")
registered_on <- oh |> filter(!is.na(reg), reg > PLACEHOLDER) |> group_by(vid) |> summarise(reg = min(reg), .groups = "drop")
from_registration <- function(d) d |>
  left_join(registered_on, by = "vid") |>
  mutate(placeholder = t1 <= PLACEHOLDER & !is.na(reg), t1 = if_else(placeholder, reg, t1)) |>
  filter(t2 > t1) |>
  select(-reg)
# before the system change of 2023-12 the status is empty: not known to be struck, so on the register
on_register <- oh |> filter(!status %in% "Afmáð") |> select(vid, rf = from, rt = to)
clip <- function(d) d |>
  inner_join(on_register, by = "vid", relationship = "many-to-many") |>
  mutate(t1 = pmax(t1, rf), t2 = pmin(t2, rt)) |>
  filter(t2 > t1) |>
  select(-rf, -rt)

# Sources --------------------------------------------------------------------------------------------------------------
ann <- read_parquet(fd_staging("skipaskra", "annual_call_sign.parquet")) |>
  transmute(vid = as.integer(vid), kind = "cs", value = toupper(trimws(cs)), year = as.integer(year)) |>
  filter(!is.na(value), value != "") |>
  transmute(vid, kind, value, t1 = as.Date(paste0(year, "-01-01")), t2 = as.Date(paste0(year + 1L, "-01-01")),
            source = "annual_register")

sk <- read_parquet(fd_raw("oracle", "kvoti", "skipasaga.parquet")) |>
  transmute(vid = as.integer(skip_nr), t1 = as_day(i_gildi), t2 = coalesce(as_day(ur_gildi), OPEN),
            st = na_if(trimws(einkst), ""), nr = suppressWarnings(as.integer(einknr)), name = na_if(trimws(heiti), "")) |>
  filter(vid > 0, !is.na(t1), t2 > t1)
sk_uid  <- sk |> filter(!is.na(st), nr > 0, !vid %in% FOREIGN) |>
  transmute(vid, kind = "uid", value = uid_value(st, nr), key = uid_key(st, nr), t1, t2, source = "skipasaga")
sk_name <- sk |> filter(!is.na(name)) |> transmute(vid, kind = "name", value = toupper(name), t1, t2, source = "skipasaga")

oi <- read_parquet(fd_raw("oracle", "vessel", "vessel_identification_hist_v.parquet")) |>
  transmute(vessel_id = as.integer(vessel_id), t1 = as_day(valid_from), t2 = coalesce(as_day(valid_to), OPEN),
            cs = na_if(toupper(trimws(call_sign)), ""), st = na_if(trimws(region_acronym), ""),
            nr = suppressWarnings(as.integer(region_no))) |>
  inner_join(v |> select(vessel_id, vid), by = "vessel_id") |>
  filter(!is.na(t1), t2 > t1)
oi_cs  <- oi |> filter(!is.na(cs)) |> transmute(vid, kind = "cs", value = cs, t1, t2, source = "oracle_hist") |> clip()
oi_uid <- oi |> filter(!is.na(st), nr > 0, !vid %in% FOREIGN) |>
  transmute(vid, kind = "uid", value = uid_value(st, nr), key = uid_key(st, nr), t1, t2, source = "oracle_hist") |> clip()
oh_name <- oh |> filter(!is.na(name), name != "") |>
  transmute(vid, kind = "name", value = toupper(name), t1 = from, t2 = to, source = "oracle_hist") |> clip()

# Periods --------------------------------------------------------------------------------------------------------------
# Per vid and kind, in time order: the later source wins where two overlap (Oracle after the register), and consecutive
# periods of one value - also across a gap of under two years between sources - are merged.
sign <-
  bind_rows(ann, sk_uid, sk_name, oi_cs, oi_uid, oh_name) |>
  mutate(key = coalesce(key, fold(value))) |>
  filter(!(kind == "uid" & value == "AÁ-999")) |>          # a dummy sign on the placeholder vids 4 and 5
  from_registration() |>
  arrange(vid, kind, t1, desc(t2)) |>
  group_by(vid, kind) |>
  mutate(t2 = if_else(!is.na(lead(t1)) & lead(t1) < t2 & lead(value) != value, lead(t1), t2)) |>
  filter(t2 > t1) |>
  mutate(run = cumsum(value != lag(value, default = "") | t1 > lag(t2, default = as.Date("1900-01-01")) + 730)) |>
  group_by(vid, kind, run) |>
  summarise(value = first(value), key = first(key), t1 = min(t1), t2 = max(t2),
            source = paste(unique(source), collapse = "+"), n = n(), placeholder = any(placeholder), .groups = "drop") |>
  mutate(window = case_when(placeholder ~ "registration", n > 1 ~ "merged", .default = "source")) |>
  select(-run, -n, -placeholder)
# One value per hull at a time: a period ends where the hull's next, different value begins. Oracle's older rows end on
# 1 January, skipasaga gives the day (vid 13: GULLTOPPUR to 2007-01-01 in Oracle, LITLABERG from 2006-12-29), and the
# exact day wins.
sign <- sign |> mutate(.r = row_number())
nxt_v <- sign |>
  inner_join(sign |> select(vid, kind, value2 = value, t1b = t1), by = join_by(vid, kind, t1 < t1b), relationship = "many-to-many") |>
  filter(value2 != value) |>
  group_by(.r) |> summarise(next_value = min(t1b), .groups = "drop")
sign <- sign |>
  left_join(nxt_v, by = ".r") |>
  mutate(t2 = if_else(!is.na(next_value) & next_value < t2, next_value, t2)) |>
  filter(t2 > t1) |>
  select(-.r, -next_value)

# One holder at a time for a call sign or a local sign: a period ends where another hull next takes the mark, whichever
# row that is (a struck hull's stale period can span several later holders: KE-18 on 567 from 1954).
marks <- sign |> filter(kind %in% c("cs", "uid")) |> mutate(.r = row_number())
nxt <- marks |>
  inner_join(marks |> select(kind, key, vid2 = vid, t1b = t1), by = join_by(kind, key, t1 < t1b), relationship = "many-to-many") |>
  filter(vid2 != vid) |>
  group_by(.r) |> summarise(next_other = min(t1b), .groups = "drop")
held <- marks |>
  left_join(nxt, by = ".r") |>
  mutate(cut = !is.na(next_other) & next_other < t2,
         t2 = if_else(cut, next_other, t2),
         window = if_else(cut, "cut", window)) |>
  filter(t2 > t1) |>
  select(-.r, -next_other, -cut)
# one hull's overlapping pieces of one mark are one period
held <- held |>
  arrange(kind, key, vid, t1) |>
  group_by(kind, key, vid) |>
  mutate(run = cumsum(t1 > lag(cummax(as.numeric(t2)), default = -Inf))) |>
  group_by(kind, key, vid, run) |>
  summarise(value = first(value), t1 = min(t1), t2 = max(t2), source = paste(unique(unlist(strsplit(source, "[+]"))), collapse = "+"),
            window = if (n() > 1) "merged" else first(window), .groups = "drop") |>
  select(-run)
# what is left is two hulls on one mark at once - mostly both taking it on the same day in the source. Kept and flagged
# `conflict`, for a reader to settle, rather than settled by a rule that would be a guess.
held <- held |>
  arrange(kind, key, t1) |>
  group_by(kind, key) |>
  mutate(conflict = (t1 < lag(cummax(as.numeric(t2)), default = -Inf)) |
                    (lead(t1, default = OPEN + 1) < t2)) |>
  ungroup() |>
  mutate(window = if_else(conflict, "conflict", window)) |>
  select(-conflict)
sign <- bind_rows(held, sign |> filter(kind == "name")) |>
  mutate(basis = "recorded") |>
  arrange(vid, kind, t1)

# Assertions -----------------------------------------------------------------------------------------------------------
# A call sign or local sign has one holder at a time, except the flagged conflicts; they must stay rare.
cf <- sign |> filter(window == "conflict")
cat("conflict periods (two hulls on one mark at once):", nrow(cf), "of", sum(sign$kind %in% c("cs", "uid")),
    "; by kind:", paste(names(table(cf$kind)), table(cf$kind), collapse = ", "), "\n")
# the limit is on the AIS era (STK from 2007), where the key reads marks; older conflicts are history
m7 <- sign |> filter(kind %in% c("cs", "uid"), t2 > as.Date("2007-01-01"))
cat("of them reaching 2007:", sum(m7$window == "conflict"), "of", nrow(m7), "\n")
if (sum(m7$window == "conflict") > 0.01 * nrow(m7)) stop("more than 1% of mark periods since 2007 conflict", call. = FALSE)
un <- sign |> filter(kind %in% c("cs", "uid"), window != "conflict") |> arrange(kind, key, t1) |> group_by(kind, key) |>
  filter(t1 < lag(t2)) |> ungroup()
if (nrow(un)) { print(un, n = 20); stop(nrow(un), " overlapping mark periods not flagged", call. = FALSE) }
two <- sign |> arrange(vid, kind, t1) |> group_by(vid, kind) |> filter(t1 < lag(t2)) |> ungroup()
cat("periods where a vid holds two values of one kind at once:", nrow(two), "\n")

print(sign |> count(kind, source, window), n = Inf)
for (k in c("cs", "uid", "name")) {
  s7 <- sign |> filter(kind == k, t2 > as.Date("2007-01-01"))
  cat(k, ": marks on more than one hull since 2007:", s7 |> distinct(key, vid) |> count(key) |> filter(n > 1) |> nrow(),
      "of", n_distinct(s7$key), "; hulls with more than one:", s7 |> distinct(key, vid) |> count(vid) |> filter(n > 1) |> nrow(), "\n")
}

write_curated(sign, fd_curated("vessel", "vessel_sign.parquet"),
              inputs = c(fd_staging("skipaskra", "annual_call_sign.parquet"), fd_raw("oracle", "kvoti", "skipasaga.parquet"),
                         fd_raw("oracle", "vessel", "vessel_identification_hist_v.parquet"), fd_raw("oracle", "vessel", "vessel_hist_v.parquet"),
                         fd_raw("oracle", "vessel", "vessel_v.parquet")))
