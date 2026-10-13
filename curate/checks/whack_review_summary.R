# whack_review_summary.R — speed and results of rb_whack_clean() on the whole AIS record, for the review package.
#
# Input:  staging/ais/ping_clean and staging/ais/ping_whacky (read-only): together, with the "invalid" and "duplicate"
#         stages left out, exactly the pings rb_whack_clean() judged in production (decision 069).
# Output: console tables in markdown, for the README of github.com/einarhjorleifsson/test; nothing written.
#
#   WHACK_MODE=df      per year, batches of whole vessels (BATCH_PINGS), collect() then rb_whack_clean() on the data
#                      frame - the way ais_ping_clean.R runs it. Times the read and the filter apart, checks the flags
#                      equal production, and counts kept legs over 1 km at more than 25 kn.
#   WHACK_MODE=duckdb  the whole record as one lazy DuckDB table, one rb_whack_clean() call, counted in DuckDB.
# Run each under /usr/bin/time -l for the peak memory (resident set):
#   /usr/bin/time -l env WHACK_MODE=df Rscript curate/checks/whack_review_summary.R
# The data stay in fishydata: only counts and times go into the review package. Time ramb as installed from GitHub
# (remotes::install_github("einarhjorleifsson/ramb")): a build from a tested source folder can be unoptimised.

source(here::here("R", "paths.R"))
source(here::here("R", "duckdb_temp.R"))
source(here::here("curate/checks", "whack_shims.R"))  # adapters for ramb functions removed 2026-10-11
suppressMessages({library(dplyr); library(duckdbfs); library(ramb)})
configure_duckdb_temp()
MODE <- Sys.getenv("WHACK_MODE", "df")
BATCH_PINGS <- 5e6
STAGES <- c("vmask", "spike", "forward")

input <- function() {
  cols <- c("vid", "time", "lon", "lat", "year")
  union_all(open_dataset(fd_staging("ais", "ping_clean")) |> select(all_of(cols)),
            open_dataset(fd_staging("ais", "ping_whacky")) |> filter(whack_stage %in% STAGES) |> select(all_of(cols)))
}
fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
rd <- packageDescription("ramb")
cat(sprintf("ramb %s (%s %s); R %s; %s\n", rd$Version, rd$RemoteType %||% "local", substr(rd$RemoteSha %||% "", 1, 7),
            getRversion(), Sys.info()[["machine"]]))

if (MODE == "df") {
  prod <- open_dataset(fd_staging("ais", "ping_whacky")) |> filter(whack_stage %in% STAGES) |>
    count(year, whack_stage) |> collect()
  years <- input() |> distinct(year) |> collect() |> pull(year) |> sort()
  res <- list()
  for (yr in years) {
    x <- input() |> filter(year == yr)
    vid_n <- x |> count(vid) |> collect() |> arrange(desc(n))
    groups <- split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)
    read_s <- 0; filt_s <- 0; st <- c(vmask = 0, spike = 0, forward = 0); legs_fast <- 0
    for (g in groups) {
      read_s <- read_s + system.time(d <- x |> filter(vid %in% g) |> collect())[["elapsed"]]
      filt_s <- filt_s + system.time(o <- rb_whack_clean(d))[["elapsed"]]
      st <- st + table(factor(o$whack_stage, names(st)))
      k <- o[!o$whack, ]                                  # rb_whack_clean returns rows sorted by vid, time
      same <- k$vid[-1] == k$vid[-nrow(k)]
      m <- rb_calc_distance(k$lon[-nrow(k)], k$lat[-nrow(k)], k$lon[-1], k$lat[-1])
      s <- as.numeric(k$time[-1]) - as.numeric(k$time[-nrow(k)])
      legs_fast <- legs_fast + sum(same & m > 1000 & m / pmax(s, 10) > 25 * 0.514444, na.rm = TRUE)
      rm(d, o, k); gc(FALSE)
    }
    p <- prod |> filter(year == yr); p <- setNames(p$n, p$whack_stage)[names(st)]; p[is.na(p)] <- 0
    res[[length(res) + 1]] <- data.frame(year = yr, pings = sum(vid_n$n), read_s, filter_s = filt_s,
                                         vmask = st[["vmask"]], spike = st[["spike"]], forward = st[["forward"]],
                                         legs_fast, equals_production = all(st == p))
    message(sprintf("%d: %s pings, filter %.1f s", yr, fmt(sum(vid_n$n)), filt_s))
  }
  r <- bind_rows(res) |> mutate(flagged = vmask + spike + forward)
  cat("\nflags equal production in every year:", all(r$equals_production), "\n\n")
  cat("| year | pings | flagged | % | vmask | spike | forward | filter, s |\n|---|---|---|---|---|---|---|---|\n")
  cat(sprintf("| %d | %s | %s | %.2f | %s | %s | %s | %.0f |\n", r$year, fmt(r$pings), fmt(r$flagged), 100 * r$flagged / r$pings,
              fmt(r$vmask), fmt(r$spike), fmt(r$forward), r$filter_s), sep = "")
  tot <- colSums(r[, c("pings", "flagged", "vmask", "spike", "forward", "read_s", "filter_s", "legs_fast")])
  cat(sprintf("| all | %s | %s | %.2f | %s | %s | %s | %.0f |\n", fmt(tot[["pings"]]), fmt(tot[["flagged"]]),
              100 * tot[["flagged"]] / tot[["pings"]], fmt(tot[["vmask"]]), fmt(tot[["spike"]]), fmt(tot[["forward"]]), tot[["filter_s"]]))
  cat(sprintf("\nread %.1f min, filter %.1f min, %s pings/s through the filter; kept legs > 1 km at > 25 kn: %s\n",
              tot[["read_s"]] / 60, tot[["filter_s"]] / 60, fmt(round(tot[["pings"]] / tot[["filter_s"]])), fmt(tot[["legs_fast"]])))
} else {
  t <- system.time(r <- rb_whack_clean(input()) |> count(whack_stage) |> collect())[["elapsed"]]
  print(as.data.frame(r))
  cat(sprintf("\nDuckDB, one call: %s pings in %.1f min\n", fmt(sum(r$n)), t / 60))
}
