# Call sign, local sign (ÍS-8) and name of each vessel over time (plan 016 §4 step 6b), from the ship register's history
# (plan 028 step 7).
# Side: preprocessing (vessels). See plan 014.
#
# Input:  curated/vessel/register/vessel_identification_hist.parquet  the register's call sign and local sign, every year:
#                                                                      the decision model's choice among the PDFs, Hreiðar,
#                                                                      kvoti and ufs and the `vessel` schema (decisions 136,
#                                                                      142), within the hull's registered life
#         curated/vessel/register/vessel_hist.parquet                 the register's name, likewise
#         curated/vessel/register/decision.parquet                    the witnesses of each value
# Output: curated/vessel/vessel_sign.parquet - one row per vid, kind (cs | uid | name), value and period [t1, t2)
#
# A vid is the hull for life; its marks are attributes at a time, and they wander: call signs and local signs pass
# between hulls, and hulls change name. `vessel_identity` times only the MMSI, so this is a table of its own (splitting
# identity's rows would repeat its MMSI windows, and through the ping union the pings).
#
#   value       as the register writes it: TFBR, ÍS-8, HUGINN
#   key         for matching: upper case, Icelandic letters folded (Í -> I, Þ -> TH, ...), a local sign as letters and
#               a 3-digit number (IS008, as vessel.parquet's uid; STK's loid writes some that way: ÞH061)
#   t1, t2      whole days, t2 exclusive; 2099-12-31 open
#   source      the witnesses of the value in the register's decisions, joined by "+": pdf | hreidar | kvoti.skipasaga |
#               ufs.skip_jn | vessel | samgongustofa | mbl (the register's own `source` names a row's, not a column's)
#   window      source (one stretch of the register) | merged (consecutive stretches of one value) | cut (closed where
#               the next holder took the mark) | conflict (two hulls on one mark at once: for a reader to settle)
#   basis       the register's
#
# The register chooses one value per hull and column at a time and keeps it only while the hull is on the register, so
# a hull holds one mark of a kind at a time, and a struck hull's mark ends with its registration. Across hulls nothing
# forbids two on one mark, so a call sign or local sign still gets one holder at a time here, bar a few flagged
# conflicts. A name is history for a reader, never a key: one name is on many hulls at once.

library(dplyr)
library(nanoparquet)

OPEN <- as.Date("2099-12-31")
fold <- function(x) {
  x <- toupper(trimws(x))
  x <- chartr("ÁÉÍÓÚÝÖÆÏÄ", "AEIOUYOAIA", x)
  x <- gsub("Þ", "TH", gsub("Ð", "D", x))
  gsub("[^A-Z0-9]", "", x)
}
uid_value <- function(st, nr) if_else(is.na(st) | is.na(nr), NA_character_, paste0(toupper(trimws(st)), "-", nr))
uid_key   <- function(st, nr) if_else(is.na(st) | is.na(nr), NA_character_, paste0(fold(st), sprintf("%03d", nr)))

reg <- function(table) read_parquet(fd_curated("vessel", "register", paste0(table, ".parquet"))) |>
  mutate(vid = as.integer(registration_no), t1 = valid_from, t2 = coalesce(valid_to, OPEN))
dec <- read_parquet(fd_curated("vessel", "register", "decision.parquet"),
                    col_select = c("registration_no", "table", "column", "valid_from", "valid_to", "source")) |>
  mutate(valid_to = coalesce(valid_to, OPEN))
# the witnesses of a row's columns (each row lies inside one decision per column), as source families
fam <- function(s) vapply(strsplit(s, "[;+] ?"), function(p) paste(sort(unique(sub(":.*$", "", p))), collapse = "+"), "")
col_source <- function(d, tab, cols) {
  d <- d |> mutate(.i = row_number())
  s <- dec |> filter(table == tab, column %in% cols) |>
    inner_join(d |> select(.i, vid, t1), by = join_by(registration_no == vid, valid_from <= t1, valid_to > t1)) |>
    group_by(.i) |> summarise(source = fam(paste(source, collapse = "; ")), .groups = "drop")
  d |> select(-source) |> left_join(s, by = ".i") |> select(-.i)
}

# Sources --------------------------------------------------------------------------------------------------------------
ident <- reg("vessel_identification_hist") |>
  mutate(cs = na_if(toupper(trimws(call_sign)), ""), st = na_if(trimws(region_acronym), ""),
         nr = suppressWarnings(as.integer(region_no)))
cs   <- ident |> filter(!is.na(cs)) |> transmute(vid, kind = "cs", value = cs, key = fold(cs), t1, t2, source, basis) |>
  col_source("vessel_identification_hist", "call_sign")
uid  <- ident |> filter(!is.na(st), nr > 0) |>
  transmute(vid, kind = "uid", value = uid_value(st, nr), key = uid_key(st, nr), t1, t2, source, basis) |>
  col_source("vessel_identification_hist", c("region_acronym", "region_no"))
name <- reg("vessel_hist") |> filter(!is.na(name), trimws(name) != "") |>
  transmute(vid, kind = "name", value = toupper(trimws(name)), key = fold(name), t1, t2, source, basis) |>
  col_source("vessel_hist", "name")
stopifnot("every value has its witnesses" = !anyNA(c(cs$source, uid$source, name$source)))

# Periods --------------------------------------------------------------------------------------------------------------
# The register's stretches change wherever any column of their table does, so consecutive stretches of one value that
# touch are one period. A gap is time off the register, or with no value, and is kept.
sign <-
  bind_rows(cs, uid, name) |>
  arrange(vid, kind, t1) |>
  group_by(vid, kind) |>
  mutate(run = cumsum(key != lag(key, default = "") | t1 != lag(t2, default = as.Date("1800-01-01")))) |>
  group_by(vid, kind, run) |>
  summarise(value = first(value), key = first(key), t1 = min(t1), t2 = max(t2),
            source = fam(paste(source, collapse = "+")), basis = paste(sort(unique(basis)), collapse = "+"),
            window = if (n() > 1) "merged" else "source", .groups = "drop") |>
  select(-run)

# One holder at a time for a call sign or a local sign: a period ends where another hull takes the mark over. A local
# sign passes between hulls often, and the later holder's dated change ends the earlier's annual value. A call sign is
# the hull's for life, so another hull takes it over only by holding it to this period's end or beyond.
marks <- sign |> filter(kind %in% c("cs", "uid")) |> mutate(.r = row_number())
nxt <- marks |>
  inner_join(marks |> select(kind, key, vid2 = vid, t1b = t1, t2b = t2), by = join_by(kind, key, t1 < t1b), relationship = "many-to-many") |>
  filter(vid2 != vid, t1b < t2, kind == "uid" | t2b >= t2) |>
  group_by(.r) |> summarise(next_other = min(t1b), .groups = "drop")
held <- marks |>
  left_join(nxt, by = ".r") |>
  mutate(cut = !is.na(next_other),
         t2 = if_else(cut, next_other, t2),
         window = if_else(cut, "cut", window)) |>
  filter(t2 > t1) |>
  select(-.r, -next_other, -cut)
# What is left is two hulls on one mark at once: one holding inside another's (mbl's 2023 page gives 2730 the TFCR it
# held to 2013, while 2892 holds it), or both taking it on the same day. Kept, and the overlap alone flagged `conflict`,
# for a reader to settle, rather than settled by a rule that would be a guess: each period is split where another
# hull's period of the mark starts or ends, the pieces two hulls hold are flagged, and the rest joined again.
bounds <- bind_rows(held |> select(kind, key, d = t1), held |> select(kind, key, d = t2)) |> distinct()
pieces <- held |>
  mutate(.r = row_number()) |>
  left_join(bounds, by = join_by(kind, key, t1 < d, t2 > d), relationship = "many-to-many") |>
  group_by(.r) |>
  reframe(kind = first(kind), key = first(key), vid = first(vid), value = first(value), source = first(source),
          basis = first(basis), window = first(window),
          t1 = sort(unique(c(first(t1), d[!is.na(d)]))), t2 = c(t1[-1], first(t2)))
holders <- pieces |>
  inner_join(held |> select(kind, key, vid2 = vid, h1 = t1, h2 = t2), by = join_by(kind, key, t1 >= h1, t1 < h2), relationship = "many-to-many") |>
  group_by(.r, t1) |> summarise(conflict = n_distinct(vid2) > 1, .groups = "drop")
held <- pieces |>
  left_join(holders, by = c(".r", "t1")) |>
  arrange(.r, t1) |>
  group_by(.r) |>
  mutate(run = cumsum(conflict != lag(conflict, default = first(!conflict)))) |>
  group_by(.r, run, conflict) |>
  summarise(kind = first(kind), key = first(key), vid = first(vid), value = first(value), t1 = min(t1), t2 = max(t2),
            source = first(source), basis = first(basis), window = first(window), .groups = "drop") |>
  mutate(window = if_else(conflict, "conflict", window)) |>
  select(-.r, -run, -conflict)
sign <- bind_rows(held, sign |> filter(kind == "name")) |>
  select(kind, key, vid, value, t1, t2, source, window, basis) |>
  arrange(vid, kind, t1)

# Assertions -----------------------------------------------------------------------------------------------------------
# The register gives a hull one value of a kind at a time.
two <- sign |> arrange(vid, kind, t1) |> group_by(vid, kind) |> filter(t1 < lag(t2)) |> ungroup()
if (nrow(two)) { print(two, n = 20); stop(nrow(two), " periods where a vid holds two values of one kind at once", call. = FALSE) }
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

print(sign |> count(kind, window), n = Inf)
for (k in c("cs", "uid", "name")) {
  s7 <- sign |> filter(kind == k, t2 > as.Date("2007-01-01"))
  cat(k, ": marks on more than one hull since 2007:", s7 |> distinct(key, vid) |> count(key) |> filter(n > 1) |> nrow(),
      "of", n_distinct(s7$key), "; hulls with more than one:", s7 |> distinct(key, vid) |> count(vid) |> filter(n > 1) |> nrow(), "\n")
}

write_curated(sign, fd_curated("vessel", "vessel_sign.parquet"),
              inputs = file.path(fd_curated("vessel", "register"), c("vessel_identification_hist.parquet", "vessel_hist.parquet", "decision.parquet")))
