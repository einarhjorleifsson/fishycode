# The ship register from 2023-12-19 on, the `vessel` schema's own history, through plan 028's decision model, set after
# the frozen history before it: the register's tables from the first year to the latest dump (plan 028 step 6).
# Side: preprocessing (vessels). See plan 014; plan 028 §4.3 and step 6; decisions 132 and 142.
#
# Input:  curated/vessel/skipaskra/*.parquet                    the history to 2023-12-19, frozen (`once`, decision 136)
#         raw/oracle/vessel/{vessel,vessel_*,vessel_*_hist}.parquet   the `vessel` schema, as dumped
#         raw/oracle/ufs/{skip,skip_jn,skipasaga}.parquet          the fisheries' witness after 2023-12-19
#         curated/vessel/mmsi.parquet                           the MMSI archive's windows (plan 016)
#         overrides/skipaskra_reviewed.csv                      a person's decisions (D1)
# Output: curated/vessel/register/<table>.parquet, for vessel_hist, vessel_identification_hist, vessel_measurement_hist,
#         vessel_engines_hist, vessel_operational_hist, vessel_fishery_hist, vessel_owners_hist, vessel_mmsi_hist,
#         vessel_event, registered, decision and annual_call_sign: the history's rows to 2023-12-19, the live rows after
#         curated/check/vessel_register_open.parquet - each open row's columns against the `vessel` schema's current tables
#
# - From 2023-12-19 the `vessel` schema answers (plan 028 §4.3). It is one register source, and dated, so of the model's
#   rules: D3 takes its versions; D1 applies; D2's rules act as in the history (an IMO number failing its check digit
#   gives way to ufs's that keeps it, or goes `open`; a call sign below 15 m length overall goes `open`; a GT off the
#   formula is flagged); D4 and D5 have no annual series to act on. A stretch's status counts the fisheries' lineage
#   (ufs) and the radio's (the MMSI archive's call signs).
# - Of several engines, the main one (usage code A).
# - On the register: the schema's status "Á aðalskipaskrá", the main register.
# - Rows split at 2023-12-19, where the schema's own history begins. The boundary is `continued` when the live row
#   gives the same values as the history's on the columns both carry, else `system_start`: a change on some day
#   before, not on that one.
# - An open row has no `valid_to`: it holds at the dump.

library(dplyr)
library(tidyr)
library(nanoparquet)
library(DBI)
library(duckdb)

END <- as.Date("2023-12-19")
FAR <- as.Date("2100-01-01")                       # an open end, inside the computation only
TABLES <- c("vessel_hist", "vessel_identification_hist", "vessel_measurement_hist", "vessel_engines_hist",
            "vessel_operational_hist", "vessel_fishery_hist")
COLS <- bind_rows(SK_HIST, tibble(table = "vessel_hist", column = "usage_category_no", type = "text"))
hist_of <- function(n) read_parquet(fd_curated("vessel", "skipaskra", paste0(n, ".parquet")))

# The `vessel` schema after 2023-12-19 -----------------------------------------------------------------------------------
vs <- bind_rows(sk_vessel_schema()) |> mutate(value_num = suppressWarnings(as.numeric(value)))
dump_day <- max(as.Date(vs$t1), na.rm = TRUE)
dump_day <- max(dump_day, as.Date(max(sk_ora("vessel", "vessel_hist")$hist_datetime)))
# One engine at a time, all its columns from it (choosing column by column would mix two engines): the main one (usage
# code A) where the hull has one; of two main engines, the one that began last, then the stronger, then the lower id
vkey0 <- sk_ora("vessel", "vessel") |> transmute(vessel_id, vid = as.integer(registration_no))
ev_ <- sk_ora("vessel", "vessel_engines_hist") |> filter(hist_operation != "DEL") |> inner_join(vkey0, by = "vessel_id") |>
  transmute(vid, eid = vessel_engines_id, record = paste0("vessel_engines_hist:", vessel_eng_hist_id), t1 = as.Date(valid_from),
            a = pmax(as.Date(valid_from), END), b = coalesce(as.Date(valid_to), FAR), main = usage_code %in% "A", power) |>
  filter(a < b)
eb <- bind_rows(ev_ |> select(vid, d = a), ev_ |> select(vid, d = b)) |> distinct() |> arrange(vid, d) |>
  group_by(vid) |> mutate(e = lead(d)) |> ungroup() |> filter(!is.na(e))
eng_pick <- eb |> inner_join(ev_, by = "vid", relationship = "many-to-many") |> filter(a <= d, d < b) |>
  arrange(vid, d, desc(main), desc(t1), desc(coalesce(power, -1)), eid) |> group_by(vid, d) |> slice(1) |> ungroup() |>
  select(vid, record, s = d, e)
eng_rows <- vs |> filter(table == "vessel_engines_hist") |> inner_join(eng_pick, by = c("vid", "record"), relationship = "many-to-many") |>
  mutate(t1 = s, t2 = if_else(e >= FAR, as.Date(NA), e)) |> select(-s, -e)
vs <- bind_rows(vs |> filter(table != "vessel_engines_hist"), eng_rows)
live <- vs |>
  filter(is.na(t2) | t2 > END) |>
  inner_join(COLS, by = c("table", "column")) |>
  mutate(a = pmax(t1, END), b = coalesce(t2, FAR)) |>
  filter(a < b)
lc <- sk_comparable(live |> select(-type), COLS |> filter(table %in% TABLES)) |>
  mutate(a = pmax(t1, END), b = coalesce(t2, FAR), fam = "vessel", prio = 1L, rule = NA_character_, basis = "recorded")
# D1: a person's decision outranks the schema
rv <- utils::read.csv("overrides/skipaskra_reviewed.csv", colClasses = "character")
if (nrow(rv)) {
  rvl <- rv |> mutate(a = pmax(as.Date(valid_from), END), b = as.Date(ifelse(valid_to == "", as.character(FAR), valid_to))) |>
    filter(a < b) |> left_join(COLS, by = c("table", "column"))
  lc <- bind_rows(lc, rvl |> transmute(vid = as.integer(vid), table, column, type, value, v = value, cmp = key_txt(value),
                                      num = suppressWarnings(as.numeric(value)), dec = as.integer(dec_of(value)), a, b,
                                      source = paste0("review:", reviewer), lineage = "review", fam = "review", prio = 0L,
                                      rule = "D1", basis = "recorded", record = paste("review", date, reason)))
}
lc <- lc |> mutate(cid = row_number())
message("the `vessel` schema after 2023-12-19: ", nrow(lc), " values to choose from (dump of ", dump_day, ")")

# One value per elementary stretch, then neighbours merged ---------------------------------------------------------------
con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
invisible(dbExecute(con, sprintf("SET temp_directory = '%s'", spill)))
# of overlapping rows (two main engines), the one that began last: its own start, not the window's clipped to 2023-12-19
duckdb_register(con, "cand", lc |> transmute(cid, vid, tab = table, col = column, prio, a, b, t0 = coalesce(t1, a)))
pick <- dbGetQuery(con, "
  WITH bnd AS (SELECT DISTINCT vid, tab, col, d FROM (SELECT vid, tab, col, a AS d FROM cand UNION ALL SELECT vid, tab, col, b FROM cand)),
  el AS (SELECT * FROM (SELECT vid, tab, col, d AS s, lead(d) OVER (PARTITION BY vid, tab, col ORDER BY d) AS e FROM bnd) WHERE e IS NOT NULL)
  SELECT vid, tab, col, s, e, cid FROM (
    SELECT el.*, c.cid, row_number() OVER (PARTITION BY el.vid, el.tab, el.col, el.s ORDER BY c.prio, c.t0 DESC, c.cid DESC) AS rk
    FROM el JOIN cand c ON c.vid = el.vid AND c.tab = el.tab AND c.col = el.col AND c.a <= el.s AND el.s < c.b) WHERE rk = 1")
pk <- pick |> rename(table = tab, column = col) |>
  left_join(lc |> select(cid, value, cmp, num, dec, type, source, lineage, record, rule, basis), by = "cid") |>
  arrange(vid, table, column, s) |>
  mutate(mkey = if_else(type %in% c("text", "class"), coalesce(key_txt(value), "<none>"), cmp)) |>
  group_by(vid, table, column) |>
  mutate(new = is.na(lag(e)) | lag(e) != s | !sk_agree_v(mkey, num, dec, lag(mkey), lag(num), lag(dec)) |
           coalesce(rule != lag(rule), xor(is.na(rule), is.na(lag(rule)))), seg = cumsum(new)) |> ungroup()
seg <- pk |> group_by(vid, table, column, seg) |>
  summarise(valid_from = min(s), valid_to = max(e), value = last(value), cmp = last(cmp), num = last(num), dec = last(dec),
            source = paste(unique(source), collapse = "; "), lineage = first(lineage), rule = first(rule), basis = first(basis),
            .groups = "drop") |>
  mutate(sid = row_number(), flag = NA_character_)

## D2: the register's own rules, on the schema's values ------------------------------------------------------------------
at <- function(tab, col, d) {           # a column's chosen value on a date, by vid
  s <- seg |> filter(table == tab, column == col) |> select(vid, f = valid_from, t = valid_to, x = num)
  d |> left_join(s, by = "vid", relationship = "many-to-many") |> filter(is.na(f) | (f <= d & d < t)) |>
    group_by(sid) |> summarise(x = first(x), .groups = "drop")
}
ufs <- bind_rows(sk_ufs()) |> mutate(value_num = suppressWarnings(as.numeric(value)))
ufs_c <- sk_comparable(ufs, COLS)
ufs_c <- bind_rows(ufs_c |> filter(kind != "change"), sk_journal_intervals(ufs_c))
imo_bad <- seg |> filter(column == "imo_no", !imo_ok(value)) |> select(sid, vid, d = valid_from)
imo_alt <- imo_bad |> inner_join(ufs_c |> filter(column == "imo_no", source == "ufs.skip_jn") |> select(vid, t1, t2, oval = value), by = "vid",
                                 relationship = "many-to-many") |>
  filter(t1 <= d, is.na(t2) | t2 >= d, imo_ok(oval)) |> group_by(sid) |> summarise(oval = first(oval), .groups = "drop")
cs_short <- seg |> filter(column == "call_sign") |> select(sid, vid, d = valid_from) |>
  left_join(at("vessel_measurement_hist", "max_length", seg |> filter(column == "call_sign") |> select(sid, vid, d = valid_from)), by = "sid") |>
  filter(!is.na(x), x < 15)
gtq <- seg |> filter(column == "brutto_weight_tons") |> select(sid, vid, d = valid_from, g = num)
gtq <- gtq |> left_join(at("vessel_measurement_hist", "length", gtq) |> rename(L = x), by = "sid") |>
  left_join(at("vessel_measurement_hist", "width", gtq) |> rename(B = x), by = "sid") |>
  filter(!is.na(g), !is.na(L), !is.na(B), L < 15, abs(g - 0.031 * L^2 * B) > 0.01 * 0.031 * L^2 * B + 0.01)
seg <- seg |>
  mutate(flag = case_when(sid %in% imo_bad$sid ~ "imo_check_digit", sid %in% cs_short$sid ~ "call_sign_short",
                          sid %in% gtq$sid ~ "gt_formula", TRUE ~ flag),
         value_printed = if_else(sid %in% imo_alt$sid, value, NA_character_),
         value = if_else(sid %in% imo_alt$sid, imo_alt$oval[match(sid, imo_alt$sid)], value),
         cmp = if_else(sid %in% imo_alt$sid, key_txt(value), cmp),
         rule = case_when(sid %in% imo_alt$sid ~ "D2", sid %in% c(imo_bad$sid, cs_short$sid) ~ "D2_open", TRUE ~ rule))
message("D2: ", nrow(imo_bad), " IMO numbers fail their check digit (", nrow(imo_alt), " take ufs's), ", nrow(cs_short),
        " call signs below 15 m, ", nrow(gtq), " GTs off the formula (flagged)")

## Status: the fisheries' and the radio's lineages on each stretch's first day --------------------------------------------
mm <- read_parquet(fd_curated("vessel", "mmsi.parquet")) |> filter(!is.na(vid), !is.na(cs))
radio <- mm |> transmute(vid = as.integer(vid), tab = "vessel_identification_hist", col = "call_sign", lineage = "radio",
                         a = mmsi_t1, b = if_else(mmsi_t2 >= as.Date("2028-12-24"), as.Date(NA), mmsi_t2), value = cs,
                         cmp = key_txt(cs), num = NA_real_, dec = NA_integer_)
wit <- bind_rows(ufs_c |> filter(source != "ufs.skipasaga_jn") |>
                   transmute(vid, tab = table, col = column, lineage, a = t1, b = t2, value, cmp, num, dec), radio)
anc <- seg |> transmute(sid, vid, tab = table, col = column, d = valid_from, clin = lineage, cmp, num, dec)
st <- sk_lineages(con, anc, wit)
dbDisconnect(con, shutdown = TRUE)
unlink(spill, recursive = TRUE)
seg <- seg |> left_join(st |> select(sid, n_lineages = n_lin, n_agree = n_agr, alternatives = alt), by = "sid") |>
  mutate(n_lineages = coalesce(n_lineages, 1L), n_agree = coalesce(n_agree, 1L),
         status = case_when(rule %in% "D1" ~ "reviewed", rule %in% "D2_open" ~ "open", rule %in% "D2" ~ "resolved",
                            n_lineages <= 1 ~ "single", n_agree == n_lineages ~ "agreed", TRUE ~ "resolved"),
         rule = case_when(status == "resolved" & is.na(rule) ~ "D3", rule %in% "D2_open" ~ "D2", TRUE ~ rule))

# On the register after 2023-12-19, set after the history's runs ---------------------------------------------------------
reg_h <- hist_of("registered")
stat <- vs |> filter(table == "vessel_hist", column == "status", is.na(t2) | t2 > END) |>
  transmute(vid, a = pmax(t1, END), b = coalesce(t2, FAR), on = value == "Á aðalskipaskrá") |> filter(a < b) |>
  arrange(vid, a) |> group_by(vid) |> mutate(g = cumsum(c(TRUE, diff(on) != 0 | head(b, -1) != tail(a, -1)))) |>
  group_by(vid, g, on) |> summarise(a = min(a), b = max(b), .groups = "drop") |> filter(on)
open_h <- reg_h |> filter(window_to == "open")
live_runs <- stat |> transmute(vid, valid_from = a, valid_to = b,
                               window_from = if_else(a == END, if_else(vid %in% open_h$registration_no, "continued", "system_start"), "dated"),
                               window_to = if_else(b >= FAR, "open", "dated"))
registered <- bind_rows(
  reg_h |> mutate(window_to = case_when(window_to != "open" ~ window_to,
                                        registration_no %in% live_runs$vid[live_runs$valid_from == END] ~ "continued",
                                        TRUE ~ "system_start")) |> rename(vid = registration_no) |>
    mutate(part = "history"),
  live_runs |> mutate(part = "live", dated_from = if_else(window_from == "dated", "vessel:vessel_hist", NA_character_),
                      dated_to = if_else(window_to == "dated", "vessel:vessel_hist", NA_character_))) |>
  arrange(vid, valid_from) |> group_by(vid) |> mutate(run = row_number()) |> ungroup() |>
  mutate(valid_to = if_else(valid_to >= FAR, as.Date(NA), valid_to))
message("on the register after 2023-12-19: ", nrow(live_runs), " runs on ", n_distinct(live_runs$vid), " hulls; ",
        sum(live_runs$window_from == "continued"), " continue one of the history's")

# The live stretches, while on the register, and the rows they make ----------------------------------------------------
clip <- seg |>
  inner_join(live_runs |> select(vid, p_from = valid_from, p_to = valid_to, pw_from = window_from, pw_to = window_to),
             by = "vid", relationship = "many-to-many") |>
  filter(valid_from < p_to, valid_to > p_from) |>
  mutate(window_from = if_else(valid_from <= p_from, pw_from, "dated"),
         valid_from = pmax(valid_from, p_from), valid_to = pmin(valid_to, p_to)) |>
  arrange(vid, table, column, valid_from) |> group_by(vid, table, column) |>
  mutate(window_to = if_else(!is.na(lead(valid_from)) & lead(valid_from) == valid_to, "dated", if_else(valid_to == p_to, pw_to, "dated"))) |>
  ungroup() |> mutate(run = as.integer(factor(paste(vid, p_from))))
dec_live <- clip |> transmute(vid, table, column, valid_from, valid_to, window_from, window_to, value, value_printed, source, basis,
                              status, rule, flag, n_lineages, n_agree, alternatives, editions = NA_character_, page = NA_integer_, run)
vkey <- sk_ora("vessel", "vessel") |> transmute(vid = as.integer(registration_no), vessel_id = as.integer(vessel_id))
assemble <- function(tab) {
  cs <- dec_live |> filter(table == tab)
  b <- bind_rows(cs |> select(vid, run, d = valid_from), cs |> select(vid, run, d = valid_to)) |> distinct() |>
    arrange(vid, run, d) |> group_by(vid, run) |> mutate(e = lead(d)) |> ungroup() |> filter(!is.na(e))
  w <- b |> inner_join(cs, by = c("vid", "run"), relationship = "many-to-many") |> filter(valid_from <= d, d < valid_to)
  meta <- w |> group_by(vid, run, d, e) |>
    summarise(window_from = if (any(valid_from == d & window_from %in% c("system_start", "continued"))) window_from[valid_from == d & window_from %in% c("system_start", "continued")][1] else "dated",
              window_to = if (any(valid_to == e & window_to == "open")) "open" else "dated",
              source = names(sort(table(sub("[:;].*$", "", source)), decreasing = TRUE))[1], basis = "recorded",
              status = sk_worst(status), rule = paste(sort(unique(na.omit(rule))), collapse = ","),
              disputed = paste(sort(unique(column[status %in% c("resolved", "open", "reviewed")])), collapse = ","),
              n_lineages = max(n_lineages), n_agree = min(n_agree), .groups = "drop") |>
    mutate(rule = na_if(rule, ""), disputed = na_if(disputed, ""))
  vals <- w |> select(vid, run, d, column, value) |> pivot_wider(names_from = column, values_from = value)
  meta |> left_join(vals, by = c("vid", "run", "d")) |> left_join(vkey, by = "vid") |>
    rename(registration_no = vid, valid_from = d, valid_to = e) |> relocate(vessel_id, registration_no, valid_from, valid_to) |>
    select(-run) |> mutate(edition_first = NA_integer_, edition_last = NA_integer_, part = "live")
}
live_rows <- setNames(lapply(TABLES, assemble), TABLES)

# The history's rows, then the live ones, split at 2023-12-19 ------------------------------------------------------------
shared_cols <- function(tab) intersect(COLS$column[COLS$table == tab], unique(dec_live$column[dec_live$table == tab]))
same_row <- function(h, l, cols) {      # history row (open at END) and live row (from END) agree on the shared columns
  ok <- rep(TRUE, nrow(h))
  for (cl in cols) {
    a <- h[[cl]]; b <- l[[cl]]
    if (is.null(a) || is.null(b)) next
    ty <- COLS$type[COLS$table == tab_now & COLS$column == cl][1]
    na_a <- is.na(a); na_b <- is.na(b)
    same <- if (ty == "num") { x <- suppressWarnings(as.numeric(a)); y <- suppressWarnings(as.numeric(b))
      !is.na(x) & !is.na(y) & num_agree(x, dec_of(a), y, dec_of(b)) } else if (ty == "material") key_material(a) == key_material(b)
      else if (ty == "class") key_class(a) == key_class(b) else key_txt(a) == key_txt(b)
    ok <- ok & ((na_a & na_b) | (!na_a & !na_b & coalesce(same, FALSE)))
  }
  ok
}
out <- list()
for (tab_now in TABLES) {
  h <- hist_of(tab_now) |> mutate(part = "history")
  l <- live_rows[[tab_now]]
  hk <- h |> filter(window_to == "open") |> select(registration_no, hrow = valid_from)
  lk <- l |> filter(valid_from == END) |> select(registration_no)
  pair <- h |> filter(window_to == "open") |> semi_join(lk, by = "registration_no") |> arrange(registration_no)
  lp <- l |> filter(valid_from == END) |> semi_join(pair, by = "registration_no") |> arrange(registration_no)
  same <- same_row(pair, lp, shared_cols(tab_now))
  cont <- pair$registration_no[same]
  # the columns whose value changes at 2023-12-19, on the live row
  diffcols <- vapply(seq_len(nrow(pair)), function(k) paste(Filter(function(cl) !same_row(pair[k, ], lp[k, ], cl), shared_cols(tab_now)), collapse = ","), "")
  l$changed_at_start <- diffcols[match(paste(l$registration_no, l$valid_from), paste(lp$registration_no, END))]
  l$changed_at_start[!is.na(l$changed_at_start) & l$changed_at_start == ""] <- NA
  h <- h |> mutate(window_to = case_when(window_to != "open" ~ window_to, registration_no %in% cont ~ "continued", TRUE ~ "system_start"))
  l <- l |> mutate(window_from = case_when(valid_from != END ~ window_from, registration_no %in% cont ~ "continued", TRUE ~ "system_start"))
  if (tab_now == "vessel_hist") l <- l |> mutate(usage_category_no = as.integer(usage_category_no))
  out[[tab_now]] <- bind_rows(h, l) |> mutate(valid_to = if_else(valid_to >= FAR, as.Date(NA), valid_to)) |>
    arrange(registration_no, valid_from)
}

## Owners, a set at a time: the history's, then the schema's ------------------------------------------------------------
own_l <- vs |> filter(table == "vessel_owners_hist", is.na(t2) | t2 > END) |>
  select(vid, record, column, value, t1, t2) |> pivot_wider(names_from = column, values_from = value, values_fn = function(v) v[1]) |>
  transmute(vid, valid_from = pmax(t1, END), valid_to = coalesce(t2, FAR), name, address, postal_no,
            percentage = suppressWarnings(as.numeric(percentage)), national_identity_no = sk_pad_kt(national_identity_no),
            national_identity_no_source = if_else(is.na(national_identity_no), NA_character_, "vessel:vessel_owners_hist"),
            source = "vessel:vessel_owners_hist", window_from = "dated", basis = "recorded") |>
  filter(valid_from < valid_to) |>
  inner_join(live_runs |> select(vid, p_from = valid_from, p_to = valid_to), by = "vid", relationship = "many-to-many") |>
  filter(valid_from < p_to, valid_to > p_from) |>
  mutate(window_from = if_else(valid_from <= p_from, "system_start", "dated"),
         valid_from = pmax(valid_from, p_from), valid_to = pmin(valid_to, p_to)) |> select(-p_from, -p_to) |>
  left_join(vkey, by = "vid") |> rename(registration_no = vid) |> mutate(part = "live")
out$vessel_owners_hist <- bind_rows(hist_of("vessel_owners_hist") |> mutate(part = "history"), own_l) |>
  mutate(valid_to = if_else(valid_to >= FAR, as.Date(NA), valid_to)) |> arrange(registration_no, valid_from)

## Events, MMSI, the call sign on each 1 January ----------------------------------------------------------------------------
ev_l <- bind_rows(
  live_runs |> filter(window_from == "dated") |> transmute(vid, event = "on_register", date = valid_from, window = "dated",
                                                           year = as.integer(format(valid_from, "%Y")), source = "vessel:vessel_hist", basis = "derived"),
  live_runs |> filter(window_to == "dated") |> transmute(vid, event = "off_register", date = valid_to, window = "dated",
                                                         year = as.integer(format(valid_to, "%Y")), source = "vessel:vessel_hist", basis = "derived")) |>
  left_join(vkey, by = "vid") |> rename(registration_no = vid)
vessel_event <- bind_rows(hist_of("vessel_event") |> mutate(part = "history"), ev_l |> mutate(part = "live")) |>
  arrange(registration_no, coalesce(date, as.Date(paste0(year, "-07-01"))), event)
vessel_mmsi_hist <- read_parquet(fd_curated("vessel", "mmsi.parquet")) |>
  filter(!is.na(vid), vid >= 1, vid <= 9999, !(vid >= 3700 & vid <= 4999)) |>
  transmute(registration_no = as.integer(vid), mmsi_no = mmsi, call_sign = cs, valid_from = mmsi_t1,
            valid_to = if_else(is.na(mmsi_t2) | mmsi_t2 >= as.Date("2028-12-24"), as.Date(NA), mmsi_t2),
            window_from = if_else(mmsi_t1 == as.Date("2007-06-01"), "archive_start", "dated"),
            window_to = if_else(is.na(valid_to), "open", "dated"), source = "mmsi", window_basis, basis = "recorded", note) |>
  left_join(vkey |> rename(registration_no = vid), by = "registration_no") |> relocate(vessel_id) |> arrange(registration_no, valid_from)
yd <- function(y) as.Date(paste0(y, "-01-01"))
annual_call_sign <- tidyr::crossing(year = 2004:as.integer(format(dump_day, "%Y")),
                                    out$vessel_identification_hist |> filter(!is.na(call_sign)) |> select(registration_no, valid_from, valid_to, call_sign)) |>
  filter(valid_from <= yd(year), is.na(valid_to) | yd(year) < valid_to) |>
  transmute(year = as.integer(year), vid = registration_no, cs = call_sign, form = "history") |> arrange(year, vid)
decision <- bind_rows(hist_of("decision") |> mutate(part = "history"),
                      dec_live |> rename(registration_no = vid) |> mutate(part = "live")) |>
  mutate(valid_to = if_else(valid_to >= FAR, as.Date(NA), valid_to)) |> arrange(registration_no, table, column, valid_from)

# Checks ----------------------------------------------------------------------------------------------------------------
for (tab in TABLES) {
  o <- out[[tab]] |> group_by(registration_no) |> arrange(valid_from, .by_group = TRUE) |>
    summarise(overlap = sum(valid_from < lag(coalesce(valid_to, FAR)), na.rm = TRUE), .groups = "drop")
  stopifnot(sum(o$overlap) == 0)
}
stopifnot(!anyNA(decision$status))
## every open row against the schema's current tables, registered hulls, column by column ------------------------------
cur <- sk_ora("vessel", "vessel") |> mutate(vid = as.integer(registration_no))
regd <- cur$vid[cur$status %in% "Á aðalskipaskrá"]
CUR <- list(vessel_hist = "vessel", vessel_identification_hist = "vessel_identification", vessel_measurement_hist = "vessel_measurement",
            vessel_engines_hist = "vessel_engines", vessel_operational_hist = "vessel_operational", vessel_fishery_hist = "vessel_fishery")
chk <- bind_rows(lapply(TABLES, function(tab) {
  ct <- sk_ora("vessel", CUR[[tab]])
  if (!"registration_no" %in% names(ct)) ct <- ct |> left_join(vkey |> rename(registration_no = vid), by = "vessel_id")
  ct$registration_no <- as.integer(ct$registration_no)
  if (tab == "vessel_engines_hist") ct <- ct |> arrange(registration_no, desc(usage_code %in% "A"), desc(valid_from),
                                                       desc(coalesce(power, -1)), vessel_engines_id) |>
    distinct(registration_no, .keep_all = TRUE)
  if (tab == "vessel_identification_hist") ct$call_sign <- sk_no_sign(ct$call_sign)
  op <- out[[tab]] |> filter(is.na(valid_to), registration_no %in% regd)
  cols <- intersect(intersect(shared_cols(tab), names(ct)), names(op))
  bind_rows(lapply(cols, function(cl) {
    j <- op |> select(registration_no, h = all_of(cl)) |> mutate(h = as.character(h)) |>
      left_join(ct |> distinct(registration_no, .keep_all = TRUE) |> transmute(registration_no, c = sk_blank_na(sk_fmt(.data[[cl]]))), by = "registration_no")
    ty <- COLS$type[COLS$table == tab & COLS$column == cl][1]
    # a zero is no value, in the history as in the evidence (sk_comparable())
    eq <- if (ty == "num") { x <- suppressWarnings(as.numeric(j$h)); y <- suppressWarnings(as.numeric(j$c)); x[x %in% 0] <- NA; y[y %in% 0] <- NA
      (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & abs(x - y) < 1e-6) } else (is.na(j$h) & is.na(j$c)) | coalesce(key_txt(j$h) == key_txt(j$c), FALSE)
    tibble(table = tab, column = cl, registration_no = j$registration_no, history_value = j$h, current_value = j$c, equal = eq)
  }))
}))
print(chk |> group_by(table, column) |> summarise(rows = n(), equal = sum(equal), .groups = "drop") |>
        knitr::kable(caption = "open rows against the `vessel` schema's current tables, registered hulls"))
message("open rows against the current tables: ", sum(chk$equal), " of ", nrow(chk), " values equal")
print(decision |> filter(part == "live") |> count(table, status, rule) |> pivot_wider(names_from = status, values_from = n, values_fill = 0) |>
        knitr::kable(caption = "live stretches by table, status and rule"))

# Write -----------------------------------------------------------------------------------------------------------------
inputs <- c(file.path(fd_curated("vessel", "skipaskra"), paste0(c(TABLES, "vessel_owners_hist", "vessel_event", "registered", "decision"), ".parquet")),
            fd_raw("oracle", "vessel", paste0(c("vessel", paste0(TABLES, ""), "vessel_owners_hist", "vessel_identification",
                                                "vessel_measurement", "vessel_engines", "vessel_operational", "vessel_fishery"), ".parquet")),
            fd_raw("oracle", "ufs", paste0(c("skip", "skip_jn", "skipasaga"), ".parquet")), fd_curated("vessel", "mmsi.parquet"),
            "overrides/skipaskra_reviewed.csv")
w <- function(d, name) write_curated(d, fd_curated("vessel", "register", paste0(name, ".parquet")), inputs = inputs)
for (tab in TABLES) w(out[[tab]], tab)
w(out$vessel_owners_hist, "vessel_owners_hist")
w(vessel_mmsi_hist, "vessel_mmsi_hist")
w(vessel_event, "vessel_event")
w(registered |> rename(registration_no = vid), "registered")
w(decision, "decision")
w(annual_call_sign, "annual_call_sign")
write_curated(chk, fd_curated("check", "vessel_register_open.parquet"), inputs = inputs)
