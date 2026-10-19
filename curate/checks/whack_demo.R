# whack_demo.R — how whacky position detection works, on toy data and on ours.
#
# Input:  ramb's whacks1 (toy; rb_read_example(), ramb >= 2026.10.16.1), staging/ais/ping_tagged (ours, read-only)
# Output: console tables and two PNGs in tempdir(); nothing is written to $FISHYDATA.
#
# Not the afli "wacky coordinates" (a DDMMmm encoding fault, see
# curate/corrections/afli_coords.yml). A whacky POSITION is one a vessel could not
# have reached: the implied speed from its neighbours exceeds kn_max.

source(here::here("R", "paths.R"))
library(dplyr)
library(ggplot2)
library(ramb)
source(here::here("curate/checks", "whack_shims.R"))  # adapters for ramb functions removed 2026-10-11

# 1. The idea, on toy data ----------------------------------------------------
# whack_fwdbwd: a point is whacky if the speed INTO it and OUT OF it both exceed
# kn_max. Requiring both spares the first point after a data gap.
whacks1 <- dplyr::collect(ramb::rb_read_example("whacks1"))
toy <- whacks1 |> filter(vid == 1, tid == 1)
toy |>
  rb_whack_fwdbwd(kn_max = 25) |>
  filter(whack | whacks) |>
  select(time, lon, lat, whacks, whack) |>
  print()   # `whacks` is the dataset's truth; `whack` is the detector

# whack_forward compares against the last point it KEPT, not the previous one, so
# it also catches a run of consecutive bad points that are slow among themselves.
toy |> rb_whack_forward(kn_max = 25) |> count(whack2) |> print()

# 2. On our data --------------------------------------------------------------
library(duckdbfs)
ais <- open_dataset(fd_staging("ais", "ping_tagged"))

flag <- function(v, yr) {
  ais |>
    filter(year == yr, vid == v) |>
    select(vid, time, lon, lat, provider) |>
    collect() |>
    rb_whack_fwdbwd(kn_max = 25) |>
    rb_whack_forward(kn_max = 25) |>
    mutate(status = case_when(whack ~ "pass 1: spike",
                              whack2 ~ "pass 2: off-track",
                              .default = "kept"))
}

plot_track <- function(d, title) {
  ggplot(d, aes(lon, lat)) +
    geom_path(data = filter(d, status == "kept"), colour = "grey50", linewidth = 0.3) +
    geom_point(aes(colour = status), size = 0.6) +
    scale_colour_manual(values = c(kept = "grey50", `pass 1: spike` = "red",
                                   `pass 2: off-track` = "orange")) +
    coord_quickmap() + labs(title = title)
}

# Simple: one spike in 457 pings. 11 s after the bad fix the vessel is back where it was.
simple <- flag(5466, 2012)
simple |> count(status) |> print()
w <- which(simple$whack)
simple[(w - 2):(w + 2), ] |> select(time, lon, lat, status) |> print()
ggsave(file.path(tempdir(), "whack_simple.png"), plot_track(simple, "vid 5466, 2012"))

# Very bad: a logger that reports one axis wrong (lon 0, lat 76, lat 67 among a true
# 23.5 W / 66.0 N). 42% of the vid's pings are flagged, and the first rows show the
# limits of the method: the first ping of a vid has no predecessor, so a bad one
# survives (row 1, lat 67.1); and the detector only sees that two neighbours
# disagree, not which is wrong, so when bad pings are frequent it flags the GOOD
# ping between two bad ones too (rows 4, 6, 8 are on the true position).
bad <- flag(239, 2012)
bad |> count(status) |> print()
bad |> slice(1:10) |> select(time, lon, lat, status) |> print()
ggsave(file.path(tempdir(), "whack_bad.png"), plot_track(bad, "vid 239, 2012"))

# 3. The whole dataset, and what it costs -------------------------------------
# Pass 1 is a lazy DuckDB window query (LAG/LEAD per vid): nothing enters R but the
# one-row-per-year summary, so memory is flat and the parquet scan is the cost.
# Pass 2 is a sequential scan per vessel (C++ in ramb) and has to run in R, so it is
# timed on a vessel batch and extrapolated by pings.
pass1_year <- function(yr) {
  ais |>
    filter(year == yr) |>
    select(vid, time, lon, lat) |>
    rb_whack_fwdbwd(kn_max = 25) |>
    summarise(pings = n(), whack = sum(as.integer(whack), na.rm = TRUE)) |>
    collect()
}

years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()
timing <- purrr::map(years, \(yr) {
  t <- system.time(r <- pass1_year(yr))[["elapsed"]]
  bind_cols(year = yr, r, pass1_sec = t)
}) |> bind_rows() |>
  mutate(share_pct = round(100 * whack / pings, 2), pings_per_sec = round(pings / pass1_sec))
print(timing, n = Inf)
timing |> summarise(pings = sum(pings), whack = sum(whack), minutes = sum(pass1_sec) / 60) |> print()

# Pass 2 on the 50 busiest vessels of one year
yr <- 2017
vids <- ais |> filter(year == yr) |> count(vid) |> arrange(desc(n)) |> head(50) |> collect()
t2 <- system.time(
  p2 <- ais |> filter(year == yr, vid %in% vids$vid) |> select(vid, time, lon, lat) |>
    collect() |> rb_whack_forward(kn_max = 25)
)[["elapsed"]]
cat(sprintf("pass 2: %s pings, %.1f s (%.0f pings/s), %.2f%% flagged\n",
            format(nrow(p2), big.mark = ","), t2, nrow(p2) / t2, 100 * mean(p2$whack2)))
