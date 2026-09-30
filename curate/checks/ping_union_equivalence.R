# One-off equivalence test for the per-year pruning of curate/ais_ping_union.R (branch union-per-year-pruning).
# Old full-scan code (git show main:curate/ais_ping_union.R -> /tmp/ais_ping_union_before.R) vs the new pruned
# d_for(YR), same key: row counts by provider, distinct vids and coordinate/time sums must be identical. Run with
# TMPDIR set to a stable directory (R's own temp folder vanished mid-run once). Not yet run to completion.
suppressMessages({library(dplyr)}); for (f in list.files("R", full.names=TRUE, pattern="[.]R$")) source(f); options(width=200)
mk <- function(file, loop_marker) { L <- readLines(file); i <- grep("^# write out", L)[1]; e <- new.env(parent = globalenv()); eval(parse(text = L[seq_len(i-1)]), envir = e); e }
fp <- function(q, YR) { q <- q |> mutate(year = year(time)) |> filter(year == YR)
  a <- q |> count(provider) |> collect() |> arrange(provider)
  b <- q |> summarise(nv = n_distinct(vid), slat = sum(lat, na.rm = TRUE), slon = sum(lon, na.rm = TRUE), st = sum(dplyr::sql("epoch(time)"), na.rm = TRUE), sv = sum(vid, na.rm = TRUE)) |> collect()
  list(counts = a, sums = b) }
old <- mk("/tmp/ais_ping_union_before.R"); new <- mk("curate/ais_ping_union.R")
d_old <- old$d
for (YR in c(2007, 2014, 2017)) {
  t_old <- system.time(f_old <- fp(d_old, YR))[["elapsed"]]
  t_new <- system.time(f_new <- fp(new$d_for(YR), YR))[["elapsed"]]
  same <- isTRUE(all.equal(f_old$counts, f_new$counts)) && isTRUE(all.equal(f_old$sums, f_new$sums, tolerance = 1e-9))
  cat(sprintf("\n== %d  old %6.1f s | new %6.1f s | identical: %s\n", YR, t_old, t_new, same)); print(as.data.frame(f_new$counts)); if (!same) { print(as.data.frame(f_old$counts)); print(f_old$sums); print(f_new$sums) } }
