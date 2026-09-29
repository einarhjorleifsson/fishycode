# Is every Icelandic vessel that should be in STK represented in it - IN TIME? The vessel-first view.
#
# Input:  curated/check/ais_key_segments.parquet, curated/check/ais_key_audit_w1.parquet,
#         curated/ais/ping (other providers: astd, astdB, keyed by MMSI -> vid), curated/landing/landings,
#         curated/logbook/trip, raw/ais/stk/trail
# Output: curated/check/ais_key_vessel_recall.parquet - one row per (vid, state, reason) span of months
#
# Every other check starts from a mobile-id and asks which vessel it is. This one starts from the
# vessels, and it is a MISSINGNESS ACCOUNTING: the unit is a vessel-MONTH, never a vessel. A vessel
# represented in 2008-2012 and absent after is not "represented"; a vessel whose mobile-id was taken
# away in 2016 is missing from 2016. Time is the whole point.
#
# Population, strongest evidence first: the months another provider HEARS the vessel (astd/astdB
# carry the MMSI, so vid is unambiguous; from 2013), then months with landings or logbook trips. A
# month with no landing or logbook is NOT evidence against a vid: a vessel may stop fishing and keep
# its mid, or start later.
#
# For each vessel-month, one of three states:
#   reported          a mobile-id the table assigns to the vid in that month reports (has STK pings);
#   assigned, silent  the table assigns a mobile-id to the vid then, but it has no pings that month;
#   unassigned        no mobile-id is assigned to the vid in that month.
# and, for the last two, a reason:
#   a mid is co-located, assigned to another vid   W1 finds a mobile-id with this vessel, but the table
#                                                  gives it another vid (a tug and its tow, a tender);
#   a mid is co-located, it has no vid             W1 finds one and the table gives it none;
#   no mid co-located                              nothing in STK moves with this vessel that month:
#                                                  its STK transponder is off, absent or not covered.
#
# This check REPORTS. Identifiers are vid and MMSI; names are not read. Foreign vids (3700-4999) are
# not the target; Icelandic vids resume above 4999.

library(dplyr)
library(tidyr)
library(nanoparquet)

STK_GLOB  <- file.path(fd_path("raw", "ais", "stk", "trail"), "year=*", "*.parquet")
PING_GLOB <- file.path(fd_path("curated", "ais", "ping"), "year=*", "*.parquet")
ym_of <- function(d) { lt <- as.POSIXlt(d); (lt$year + 1900L) * 12L + lt$mon }
FOREIGN <- 3700:4999

seg <- read_parquet(fd_curated("check", "ais_key_segments.parquet")) |>
  mutate(d1 = as.Date(d1), d2 = as.Date(d2)) |> filter(!is.na(vid), !vid %in% FOREIGN)
w1 <- read_parquet(fd_curated("check", "ais_key_audit_w1.parquet")) |>
  filter(score >= .8) |> transmute(mid, vid, ym = y * 12L + m - 1L)
reg <- read_parquet(fd_curated("vessel", "vessel.parquet")) |> select(vid, mmsi, mclass, loa) |> filter(vid > 0, !vid %in% FOREIGN)

con <- DBI::dbConnect(duckdb::duckdb(), config = list(memory_limit = "16GB"))
q <- function(sql) dplyr::as_tibble(DBI::dbGetQuery(con, sql))
ais <- q(sprintf("select vid, year(time) * 12 + month(time) - 1 ym, count(*) n from read_parquet('%s') where provider <> 'stk' group by 1, 2", PING_GLOB)) |>
  filter(n >= 20, !vid %in% FOREIGN)
days <- q(sprintf("select mid, cast(time as date) d, count(*) n from read_parquet('%s') where time >= timestamp '2007-06-01' group by 1, 2", STK_GLOB))
lnd <- q(sprintf("select distinct vid, year(date) * 12 + month(date) - 1 ym from read_parquet('%s') where date >= date '2007-06-01'", fd_curated("landing", "landings.parquet"))) |> filter(!vid %in% FOREIGN)
lgb <- q(sprintf("select distinct vid, year(T1) * 12 + month(T1) - 1 ym from read_parquet('%s') where T1 >= timestamp '2007-06-01'", fd_curated("logbook", "trip.parquet"))) |> filter(!vid %in% FOREIGN)
DBI::dbDisconnect(con, shutdown = TRUE)
LAST <- max(ym_of(days$d))

# Months the table ASSIGNS a mobile-id to the vid (time-aware: the segment's own dates), and months an
# assigned mobile-id actually REPORTS
seg_m <- seg |> transmute(vid, mid, m1 = ym_of(d1), m2 = pmin(ym_of(d2), LAST)) |> filter(m2 >= m1) |>
  mutate(len = m2 - m1 + 1L) |>
  (\(x) tibble(vid = rep(x$vid, x$len), mid = rep(x$mid, x$len), ym = sequence(x$len, from = x$m1)))() |>
  distinct(vid, mid, ym)
assigned_m <- seg_m |> distinct(vid, ym)
reports_m <- seg_m |>
  inner_join(days |> transmute(mid, ym = ym_of(d), n) |> group_by(mid, ym) |> summarise(n = sum(n), .groups = "drop"), by = c("mid", "ym")) |>
  distinct(vid, ym)

# W1: which mobile-id moves with the vessel, and what vid the table gives that mobile-id THEN
mid_vid_m <- seg_m |> rename(seg_vid = vid)
w1_state <- w1 |>
  left_join(mid_vid_m, by = c("mid", "ym"), relationship = "many-to-many") |>
  group_by(vid, ym) |>
  summarise(w1_mid_has_other_vid = any(!is.na(seg_vid) & seg_vid != vid),
            w1_mid_has_no_vid = all(is.na(seg_vid)), .groups = "drop")

account <- function(pop, label) {
  pop |>
    left_join(mutate(assigned_m, assigned = TRUE), by = c("vid", "ym")) |>
    left_join(mutate(reports_m, reports = TRUE), by = c("vid", "ym")) |>
    left_join(w1_state, by = c("vid", "ym")) |>
    mutate(assigned = coalesce(assigned, FALSE), reports = coalesce(reports, FALSE),
           state = case_when(reports ~ "reported", assigned ~ "assigned, silent", .default = "unassigned"),
           reason = case_when(state == "reported" ~ NA_character_,
                              coalesce(w1_mid_has_other_vid, FALSE) ~ "a mid is co-located, assigned to another vid",
                              !is.na(w1_mid_has_no_vid) & w1_mid_has_no_vid ~ "a mid is co-located, it has no vid",
                              .default = "no mid co-located"),
           population = label)
}
heard <- account(distinct(ais, vid, ym), "heard by AIS (astd/astdB)")
fish <- account(bind_rows(mutate(lnd, kind = "landings"), mutate(lgb, kind = "logbook")) |> anti_join(ais, by = c("vid", "ym")) |> distinct(vid, ym), "landings or logbook, not heard by AIS")
mo <- bind_rows(heard, fish)

# Spans: consecutive months of one state and reason per vessel
spans <- mo |> filter(state != "reported") |>
  arrange(population, vid, state, reason, ym) |>
  group_by(population, vid, state, reason) |>
  mutate(run = cumsum(ym - lag(ym, default = first(ym)) > 1L)) |>
  group_by(population, vid, state, reason, run) |>
  summarise(from = min(ym), to = max(ym), months = n(), .groups = "drop") |>
  mutate(from = sprintf("%d-%02d", from %/% 12L, from %% 12L + 1L), to = sprintf("%d-%02d", to %/% 12L, to %% 12L + 1L)) |>
  select(-run) |>
  left_join(reg, by = "vid") |>
  arrange(desc(months))

print(mo |> count(population, state, name = "vessel_months") |> group_by(population) |> mutate(share = round(vessel_months / sum(vessel_months), 4)) |>
        knitr::kable(caption = "ais_key_vessel_recall: vessel-months"))
print(mo |> filter(population == "heard by AIS (astd/astdB)", state != "reported") |> count(state, reason, name = "vessel_months") |>
        knitr::kable(caption = "missing AIS-heard vessel-months, by reason"))
print(mo |> filter(population == "heard by AIS (astd/astdB)") |> mutate(year = ym %/% 12L) |>
        group_by(year) |> summarise(months = n(), reported = round(mean(state == "reported"), 3), assigned_silent = round(mean(state == "assigned, silent"), 3),
                                    unassigned = round(mean(state == "unassigned"), 3), .groups = "drop") |> knitr::kable(caption = "AIS-heard vessel-months by year"))

write_curated(spans, fd_curated("check", "ais_key_vessel_recall.parquet"),
              inputs = c(segments = fd_curated("check", "ais_key_segments.parquet"),
                         w1 = fd_curated("check", "ais_key_audit_w1.parquet"),
                         vessel = fd_curated("vessel", "vessel.parquet")))
