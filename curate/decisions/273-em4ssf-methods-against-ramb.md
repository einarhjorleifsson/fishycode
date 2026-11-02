# 273 — EM4SSF's code, method by method, against ramb: all but two steps have a counterpart, and both of those are already on the wish list

*2026-11-02. The maintainer: "Mine both repos. Map the methods provided therein against what is now in ramb (or
fishycode)". Both clones in `~/stasi/em4ssf` were fetched first. Neither has a commit since decision 238 (R at c9fd1ed,
Python at 57e8b7c). Claude (AI) read every script against ramb 2026.11.02.1 (8d728ba) and fishycode 475dc92, and wrote
this record and the two wish-list edits in `docs/one_flow.qmd`. Nothing was run and nothing went into ramb. No person
has checked it. Decision 238's rule holds here. The methods are Mendo et al. 2024's (ICES JMS 81: 390,
https://doi.org/10.1093/icesjms/fsad209, CC BY 4.0) and are cited from its supplements S1 (R) and S2 (Python) in
`raw/external/mendo2024/`. EM4SSF's own changes are described in our words, not quoted.*

## The workflow

There are four steps, and each fishery tunes its thresholds by hand: (1) clean the pings and cut trips, (2) infer
fishing operations, (3) keep the fishing trips, and (4) learn mooring sites from the track, for fleets with no port
list. EM4SSF's preprocessing script is step 1 in one file, writing D2.1's columns. The paper's R and Python share one
method. Where they differ, the difference is noted below. S1's step 4 sets none of its parameters, so the values given
here come from S2.

## The map

| step | Mendo et al. 2024 | ramb | fishycode | how they compare |
|---|---|---|---|---|
| study area | pings outside a hand-set box of latitude and longitude are dropped | no box. `rb_keep_in_polygons()` takes any polygon, and `rb_flag_ping_invalid()` tests only the globe's range | no area limit | generic in ramb |
| duplicates | a ping with the same time and position as another is dropped | `rb_flag_ping_duplicate()` handles copies *between* feeds, by priority. An exact copy within one feed has no function | the union keeps one of each set of rows equal in every column and counts the copies (plan 060). Exact time ties are flagged | the same, in fishycode |
| on land | pings inside a high-resolution coastline polygon are dropped | `rb_detect_in_polygons()` and `rb_drop_in_polygons()` work with any polygon. No `rb_flag_ping_*` function flags land | no land test | generic in ramb, not used here |
| impossible speed | speed is step distance in one UTM zone over time. Every ping reached faster than 25 kn is dropped, speeds are recomputed, and this repeats until none is too fast | `rb_flag_ping_impossible()`, also 25 kn by default, labels and never drops. The nearest methods are `"sequential"` (removes the first too-fast step, then recomputes) and `"forward"` (each ping against the last one kept) | `"clean"`, with the noise floor between feeds (`curate/ais_ping_clean.R`) | same aim, different rule (below) |
| time zone | `DATE_TIME` is read in Europe/London, the zone of the paper's Scottish case | UTC | UTC | TODO 155 (a) |
| trips from records (option a) | named and pointed to Hintzen et al. 2012. Not coded | `rb_link_trip_logbook()`, `rb_add_logbook_trip()` | the logbook trip on every fix | in ramb |
| trips by day (option b) | a trip is a vessel and a calendar day. At each end, pings within 400 m of track from the end and within 200 m of the coastline are dropped | no voyage method without a port list. `rb_create_record_windows()`'s `"day"` makes windows for records, not voyages | voyages between port calls | **not in ramb.** This is the wish list's "trips without a port list" |
| trips between mooring sites (option c) | a trip is a run of pings outside the mooring-site polygons. Pings inside are dropped | `rb_create_voyages(method = "runs")`, with port pings labelled, not dropped | `dwell`, a minimum stay of 2 h | in ramb |
| spurious trips | trips under 1 h, under 50 pings or under 5 km are dropped | `min_pings` (any method), `min_dur_h` (`jepol` only), no minimum distance. `rb_summarise_track()` gives each voyage's numbers | short voyages are kept and labelled (plan 031 §4.7) | partly in ramb |
| gaps and resampling | a trip is split where consecutive pings lie over 500 m apart. Each piece is resampled to 1 minute by linear interpolation, and land is tested again | `rb_interpolate_track()` interpolates onto given times, lazily. Nothing builds a regular time grid or splits at a distance jump. Effort weights each ping by its interval (`rb_calc_step_time()`, `rb_add_effort()`), so hours need no resampling | no resampling. `dt` is on every fix | different route to equal time weights |
| fishing | speed under 3 kn on the resampled track. The paper names EM, HMM and random forests as alternatives, without code | `rb_add_fishing(method = "speed")`, with the range on each ping (`ping_speed_min`, `ping_speed_max`). The track models live in fishymodel (decision 103) | the presets of decision 215: the window × the gear's range, on the ±10 min median speed | in ramb |
| isolated labels | a ping whose two neighbours on each side all carry the other label takes theirs. S2 does this within a trip. S1 does it across the whole table | no label smoother. ramb smooths the speed instead, before the threshold (`rb_calc_speed_smooth()`, `window_s`) | ±10 min median speed (decision 093) | same aim, different construct |
| fishing trips | a trip with at least one fishing ping | a filter on `rb_add_fishing()`'s output, with no function of its own | trail fixes carry voyage and fishing. A fishing vessel's voyage with no record is to be undecided (decision 200, not built) | trivial |
| mooring sites | per vessel: pings under 0.1 kn within 100 m of the coastline, split at 200 m or 2 h, resampled to 1 minute. Then k-means on position, with k from 2 to 9 chosen by mean silhouette. Clusters of 3 points or fewer are dropped. A 95 % ellipse is drawn for each cluster and dropped if an axis exceeds 5 km. The cluster's centre is buffered 200 m, and every vessel's circles are unioned into polygons | none | the port list (`pid`) with the frozen departure radius | **not in ramb.** Planned as learned ports (plan 031 §4.3), by another rule (below) |
| output | D2.1's columns, with the trip's source coded as found by analysis | `trip_basis = "reconstructed"` | the same basis | the format is a wish-list row (decision 229) |

## Where the rules differ enough to change the numbers

- **The speed filter.** Mendo's single pass drops every ping that was reached too fast. A lone spike's next ping is
  measured from the spike, so it is dropped with it. ramb's `"forward"` measures that ping from the last ping kept, so
  it stays. Mendo's filter has no floor on the time step and does not restart after a gap. ramb has both (`min_dt_s`
  10 s and `max_gap_h` 4 h). At a ping a second, position jitter of about 13 m alone reads as 25 kn. Not tested.
- **Smoothing.** Mendo takes a majority of labels over ±2 one-minute pings. ramb takes a median of speeds over
  ±`window_s` (fishycode uses ±10 min). They agree on a lone flip. ramb's also holds through longer jitter. That
  claim is not measured on Mendo's rule.
- **Equal time per ping.** Mendo gets it by resampling, ramb by `dt`. Resampling creates positions across a gap of up
  to 500 m. `dt` leaves positions as they were recorded and caps long intervals (`rb_cap_effort()`).
- **Learned ports.** Plan 031's bench (`$FISHYDATA/archive/2026-10-plan031/`, `bench_methods.R`) prototyped another
  rule. It took grid cells of 0.01° × 0.005° where a vessel stays 2 h or a silence of 2 h begins, kept the cells where
  3 or more vessels stop, and merged neighbouring cells. On Iceland it found 96.7-100 % of the landing ports. The
  learned ports away from the list were on no other list either: anchorages, shelter, grounds or fish farms. Mendo's
  rule differs in four ways. It needs a coastline. It learns per vessel, and one vessel's site is enough. It needs no
  stay, only still pings. Its k is at least 2 for every vessel, and the union then merges a lone site's halves. The two
  rules have not been run on the same data.

## What this means

- **Every step has a counterpart in ramb but two**, and the wish list in `docs/one_flow.qmd` already holds both: trips
  without a port list (row 1, where this record adds Mendo's day trips) and mooring sites learned from the track (plan
  031 §4.3). The record also adds the regular time grid to the interpolation row.
- **Decision 234's yardstick would allow a recode.** Mendo et al. 2024 exists only as scripts in PDFs. A recode would
  stand if it is checked against the paper's own output and credited in ramb's `inst/COPYRIGHTS`. There are three
  candidates, and none is chosen:
  1. the day trip with its coastal end trim, as a `rb_create_voyages()` method for tracks with no port list;
  2. Mendo's mooring sites, scored against plan 031's grid rule on the bench's measures (landing ports found, false
     ports), since plan 031 builds learned ports anyway;
  3. a regular time grid, as a helper, because the HMMs and Mendo et al. 2023's set finder assume one (decision 234
     built it by hand).
- **The maintainer chooses** which, if any, and whether before the Ancona hackathon (November 2026). TODO 155 (b)
  retraces the code after it.
