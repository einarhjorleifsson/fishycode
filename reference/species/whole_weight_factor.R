# whole_weight_factor.R — one factor table from a weight as landed or logged to the whole weight (plan 051 step 3).
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  reference/species/whole_weight_factor.yml     the periods, the logbook's map, the lumpfish logbook's stages
#         raw/oracle/ask/astand.parquet                 the landing system's state codes and names
#         raw/oracle/agf/aflagrunnur.parquet            the rows the products' yearly means are computed from
# Output: curated/reference/whole_weight_factor.parquet  one row per scope, species, state (or condition), area and
#         period: scope, kind, sid, state, state_name, condition, area, from, to, factor, factor_p10, factor_p90,
#         regulation, basis, witness, provisional, n_rows, kg, read_sid, note
#
# Scopes: `landings`, the landing system's factor per species, state and period (kind `period`, or `year mean` for
# the products processed at sea, whose factor is set per landing, or `listed`, a species, state and area agf holds
# that neither covers, with its factor over every row); `logbook`, the rows calc_whole_weight()
# (R/whole_weight.R) reads, one per logged condition and period, copied from the landings row it reads; `lumpfish
# logbook`, afli's own lumpfish logbook's salting stages (TODO 167). `held` rows are kept and not applied. A sid NA
# is any species the scope gives no row of its own; `to` NA is open. A period whose witness is `regulation` is split
# by fishing year, each year's regulation on the total allowable catch its witness where it prints the same factor.

library(dplyr)

decl <- yaml::read_yaml("reference/species/whole_weight_factor.yml")
d <- function(x) if (is.null(x)) as.Date(NA) else as.Date(x)
sids <- function(x) if (is.null(x) || identical(x, "any")) NA_integer_ else as.integer(unlist(x))
states <- function(x) if (identical(x, "any")) NA_character_ else as.character(unlist(x))
astand <- duckdbfs::open_dataset(fd_raw("oracle", "ask", "astand.parquet")) |>
  transmute(state = as.character(astand), state_name = heiti) |> collect()

# The landings' periods ---------------------------------------------------------
periods <- bind_rows(lapply(decl$periods, \(p) tidyr::expand_grid(
  sid = sids(p$sid), state = states(p$state),
  tibble(from = d(p$from), to = d(p$to), factor = p$factor, regulation = p$regulation %||% NA_real_,
         reg_group = p$reg_group %||% NA_character_, basis = p$basis, witness = p$witness,
         witness_landings = p$witness_landings %||% NA_character_, note = p$note %||% NA_character_))))

## Each regulated period by fishing year, its regulation the witness ----------
# A fishing year runs 1 September to 31 August. A year whose regulation was read and prints the same factor is
# `recorded` with that regulation; one not read keeps the landings' own witness, `derived`. A regulation that prints
# another factor stops the build: the table and the regulation disagree.
fy_start <- function(y) as.Date(sprintf("%d-09-01", y))
regs <- bind_rows(tibble(fy = integer(), reg = character(), reg_group = character(), reg_factor = numeric()),
                  lapply(if (is.null(decl$regulations)) list() else decl$regulations, \(r) tibble(
  fy = as.integer(substr(r$fishing_year, 1, 4)), reg = sprintf("%s, %s", r$regulation, r$article),
  reg_group = names(r$factors), reg_factor = as.numeric(unlist(r$factors)))))
split_by_year <- function(p) {
  if (p$witness != "regulation") return(select(p, -witness_landings))
  stopifnot("a regulated period names its landings witness" = !is.na(p$witness_landings))
  last <- as.integer(format(coalesce(p$to, Sys.Date()), "%Y"))
  y <- seq(as.integer(format(p$from, "%Y")) - 1L, last)
  y <- y[fy_start(y + 1L) - 1 >= p$from & fy_start(y) <= coalesce(p$to, as.Date("2999-12-31"))]
  tibble(sid = p$sid, state = p$state, fy = y,
         from = pmax(fy_start(y), p$from), to = pmin(fy_start(y + 1L) - 1, coalesce(p$to, as.Date("2999-12-31"))),
         factor = p$factor, regulation = p$regulation, reg_group = p$reg_group, note = p$note) |>
    mutate(to = if_else(is.na(p$to) & fy == max(fy), as.Date(NA), to)) |>
    left_join(regs, by = c("fy", "reg_group"), relationship = "many-to-one") |>
    mutate(basis = if_else(is.na(reg), "derived", "recorded"),
           witness = coalesce(reg, p$witness_landings)) -> out
  bad <- filter(out, !is.na(reg_factor), abs(reg_factor - regulation) > 1e-9)
  if (nrow(bad)) stop("the regulation prints another factor: ", paste(unique(bad$reg), collapse = "; "))
  select(out, -fy, -reg, -reg_factor)
}
periods <- bind_rows(lapply(seq_len(nrow(periods)), \(i) split_by_year(periods[i, ]))) |>
  mutate(scope = "landings", kind = "period", area = "IS", .before = 1)

## The products processed at sea: yearly means from the rows ------------------
rows <- duckdbfs::open_dataset(fd_raw("oracle", "agf", "aflagrunnur.parquet")) |>
  filter(magn > 0) |>
  mutate(year = as.integer(year(londun_hefst)), f = magn_oslaegt / magn, day = as.Date(londun_hefst))
summarise_rows <- function(x, by) x |>
  summarise(factor = sum(magn_oslaegt) / sum(magn), factor_p10 = quantile_cont(f, 0.1),
            factor_p90 = quantile_cont(f, 0.9), d0 = min(day), d1 = max(day), n_rows = n(), kg = sum(magn),
            .by = all_of(by)) |>
  collect() |>
  mutate(across(starts_with("factor"), \(v) round(v, 4)), sid = as.integer(fisktegund), state = as.character(astand),
         area = veidisvaedi)
year_mean <- rows |>
  filter(astand %in% !!as.integer(decl$year_mean_states)) |>
  summarise_rows(c("fisktegund", "astand", "veidisvaedi", "year")) |>
  transmute(scope = "landings", kind = "year mean", sid, state, area,
            from = as.Date(sprintf("%d-01-01", year)), to = as.Date(sprintf("%d-12-31", year)),
            factor, factor_p10, factor_p90, basis = "derived", witness = "aflagrunnur rows", n_rows, kg,
            note = sprintf("set per landing; landed %s to %s", d0, d1))

## The rest, listed: every species, state and area agf holds that no period or yearly mean covers ---
covered <- function(k) {
  own <- semi_join(k, periods, by = c("sid", "state", "area"))
  any <- semi_join(k, filter(periods, is.na(sid)), by = c("state", "area"))
  bind_rows(own, any, semi_join(k, year_mean, by = c("sid", "state", "area"))) |> distinct(sid, state, area)
}
keys <- summarise_rows(rows, c("fisktegund", "astand", "veidisvaedi"))
listed <- keys |>
  anti_join(covered(keys), by = c("sid", "state", "area")) |>
  transmute(scope = "landings", kind = "listed", sid, state, area, from = d0, to = d1, factor, factor_p10, factor_p90,
            basis = "derived", witness = "aflagrunnur rows", n_rows, kg,
            note = "no period: the factor over every row, with its 10-90 % range")

# The logbook: the landings row each logged condition reads ---------------------
# A map entry for named species takes precedence over the entry for any species; a fallback carries its own factor.
map <- bind_rows(lapply(decl$logbook, \(m) tibble(
  condition = m$condition, sid = sids(m$sid), state = as.character(m$state), read_sid = m$read_sid %||% NA_integer_,
  factor = m$factor %||% NA_real_, fallback = isTRUE(m$fallback), basis = m$basis %||% NA_character_,
  witness = m$witness %||% NA_character_, note = m$note %||% NA_character_)))
landing_period <- filter(periods, !is.na(sid))
named <- filter(map, !is.na(sid), !fallback) |>
  mutate(read_sid = coalesce(read_sid, sid)) |>
  inner_join(landing_period |> select(read_sid = sid, state, from, to, factor_read = factor, basis_read = basis,
                                      witness_read = witness, regulation),
             by = c("read_sid", "state"), relationship = "many-to-many")
default <- filter(map, is.na(sid), !fallback) |>
  select(-sid, -read_sid) |>
  inner_join(landing_period |> select(sid, state, from, to, factor_read = factor, basis_read = basis,
                                      witness_read = witness, regulation),
             by = "state", relationship = "many-to-many") |>
  anti_join(named |> distinct(sid, condition), by = c("sid", "condition")) |>
  mutate(read_sid = sid)
logbook <- bind_rows(named, default) |>
  transmute(scope = "logbook", kind = "period", sid, state, condition, area = "IS", from, to, factor = factor_read,
            regulation, basis = coalesce(basis, basis_read),
            witness = if_else(is.na(witness), witness_read, paste0(witness, "; ", witness_read)),
            read_sid = if_else(read_sid == sid, NA_integer_, read_sid), note)
fallback <- filter(map, fallback) |>
  transmute(scope = "logbook", kind = "fallback", sid = NA_integer_, state, condition, area = NA_character_,
            from = as.Date(NA), to = as.Date(NA), factor, basis, witness, note)
stopifnot("a fallback needs its own factor" = !anyNA(fallback$factor))

# afli's lumpfish logbook: roe at a salting stage to the whole lumpfish (TODO 167) ---
lf <- decl$lumpfish_logbook
lumpfish <- bind_rows(lapply(lf$stages, \(s) tibble(
  scope = "lumpfish logbook", kind = "period", sid = 951L, state = "6", condition = paste("stage", s$stage),
  from = as.Date(NA), to = as.Date(NA), factor = round(100 / lf$gsi / s$factor, 4), basis = "derived",
  witness = lf$witness,
  note = sprintf("roe %s: fresh roe = roe / %.2f; whole = fresh roe x 100/%s", s$name, s$factor, lf$gsi))))

held <- bind_rows(lapply(decl$held, \(h) tibble(
  scope = "held", kind = "held", sid = sids(h$sid), state = as.character(h$state), from = d(h$from), to = d(h$to),
  factor = h$factor, basis = h$basis, witness = h$witness, note = h$note)))

# Checks and write ----------------------------------------------------------------
out <- bind_rows(periods, year_mean, listed, logbook, fallback, lumpfish, held) |>
  select(-any_of("reg_group")) |>
  left_join(astand, by = "state", relationship = "many-to-one") |>
  mutate(provisional = scope %in% c("lumpfish logbook", "held"), condition = as.character(condition)) |>
  select(scope, kind, sid, state, state_name, condition, area, from, to, factor, factor_p10, factor_p90, regulation,
         basis, witness, provisional, n_rows, kg, read_sid, note) |>
  arrange(scope, sid, state, condition, area, from)

stopifnot(!anyNA(out$factor), all(out$factor >= 0), all(is.na(out$to) | is.na(out$from) | out$to >= out$from),
          all(out$basis %in% c("recorded", "derived")))
# No two periods of one key overlap, and a key's open period is its last.
overlap <- out |>
  filter(scope != "held") |>
  mutate(.from = coalesce(from, as.Date("1900-01-01")), .to = coalesce(to, as.Date("2999-12-31"))) |>
  arrange(.from) |>
  mutate(.prev_to = lag(.to), .by = c(scope, sid, state, condition, area)) |>
  filter(!is.na(.prev_to), .from <= .prev_to)
if (nrow(overlap)) { print(overlap); stop("overlapping periods") }
# Every logged condition the logbook map names reads one row on any day: the fallback catches the rest.
stopifnot(sum(out$kind == "fallback") == 1)

print(count(out, scope, kind, basis), n = Inf)
write_curated(out, fd_curated("reference", "whole_weight_factor.parquet"),
              inputs = c("reference/species/whole_weight_factor.yml", fd_raw("oracle", "ask", "astand.parquet"),
                         fd_raw("oracle", "agf", "aflagrunnur.parquet")))
