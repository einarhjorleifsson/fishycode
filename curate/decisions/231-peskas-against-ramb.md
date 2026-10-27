# 231 — Peskas (WorldFish) and its fishing classifier read against ramb: the pings-and-landings end of the flow, six wishes added

*2026-10-27. The maintainer pointed at a new R package, "care to mine it an create a summary of what may be of use",
then asked "care to clone peskas.coasts", and then "clone https://github.com/WorldFishCenter/ssf-ai-toolkit and mine it
with respect to our project". Claude (AI) read the three repositories against ramb 2026.10.25.5 (9a67e0d). It ran the
counts under "Checked on our data" and on the toolkit's labelled files, and wrote this record and the new wish-list rows
in `docs/one_flow.qmd`. No person has checked them. Nothing went into ramb. Amended the same day at the maintainer's
request: the shore-filter line named the departure radius, which decision 197 retires; it now names the time budget.
Amended again the same day: where the toolkit's example data were copied (under "What was read").*

## What was read

| repository | version, commit | where | lines |
|---|---|---|---|
| `peskas.timor.data.pipeline` | 5.8.1, 619c3fa of 2026-10-26 | `~/R/Pakkar/peskas.timor.data.pipeline`, put there by the maintainer | 8,168 of R |
| `coasts` (repo `peskas.coasts`) | 4.24.1, dcf8a2c of 2026-10-21 | `~/R/Pakkar/peskas.coasts`, cloned 2026-10-27 with its whole history (142 commits) | 14,448 of R |
| `ssf-ai-toolkit` (Python package `ssfaitk`) | 0.1.0, 845f5c1 of 2026-04-30; Peskas installs branch `plug-R`, 325d264 of 2026-03-05 | `~/R/Pakkar/ssf-ai-toolkit`, cloned 2026-10-27 (18 commits on `main`, 32 on `plug-R`) | 11,587 of Python outside `backup/`, on `main` |

The toolkit's example data were copied on 2026-10-27, at the maintainer's request, to
`$FISHYDATA/raw/external/worldfish/ssf-ai-toolkit/`. That is every data file on `main` (845f5c1): 56 files, 113 MB,
kept in the repository's folders, with a `README.txt` saying what each group is. The clones in `~/R/Pakkar` are
untouched. The maintainer, the same day: these are public data.

All three are WorldFish's and public on GitHub: the two R packages under the GPL, the toolkit under Apache 2.0. Timor's
pipeline is thin: every function that is not Timor's own
(storage, PDS ingestion, raising, the effort grid, catch per hour) is in `coasts`, the hub the four country pipelines
call. Both repos carry agent notes (`CLAUDE.md`, and Timor's `.claude/rules/` scoped by path), which state most of what
follows; the code was read where a claim mattered.

## What Peskas is

- **Data.** Landings surveyed at the landing site with a phone form (KoboToolbox), and solar GPS trackers from Pelagic
  Data Systems (PDS) on part of the fleet, reporting about every 7 seconds. There are no logbooks, no hauls and no AIS.
- **On ramb's spectrum.** It sits at the pings-and-trip-catch end of `docs/one_flow.qmd`.
  - A landing is matched to a tracked trip when the device and the day are the only ones of each (Timor's `merge_trips()`).
  - Fishing fixes come from a classifier in WorldFish's `ssf-ai-toolkit` (Python, called from R), and only those fixes
    are stored (below).
  - The catch is raised to the fleet from a boat census.
- **Raised twice.** Timor raises by trips per tracked boat × census boats × catch per landing. For Kenya, Zanzibar and
  Mozambique `coasts` raises the same way and also by FAO's ARTFISH, and keeps both, so the two can be compared.

## What it has that ramb lacks

These are the first five of the six new rows in the wish list of `docs/one_flow.qmd`; the sixth is the toolkit's
(below).

1. **Catch per hour fitted across trips** (`coasts` `run_nnls_cpue()`).
   - Each trip's catch of a species is the sum over the H3 cells it fished of its hours there times the cell's catch
     per hour. The rates are solved by non-negative least squares, one species at a time.
   - Its own rule of thumb is three times more trips than cells.
   - `rb_share_catch` shares a unit's catch by its fixes' hours: one rate within the unit, wherever its fixes lie.
   - A fitted rate is a second route for catch known only by the trip. It can be scored on the well-recorded part: add
     the hauls of trawlers up to trips, fit, and compare with the hauls (the third of the product's done criteria).
2. **Raising, with each fallback named and an error stated** (`coasts` `raise_catch_fao()`, `compound_re()`).
   - ARTFISH multiplies census boats by days fished and by catch per fishing day.
   - A cell with fewer than five trips takes a pooled value, and `catch_source` and `effort_source` say which. This is
     our `basis` by another name.
   - Each total carries the compound relative error at 90 %, graded pass (up to 15 %), warn (up to 20 %) or fail.
   - Iceland's landings are a census, so no catch needs raising. The effort of vessels that land but carry no track
     does (the coverage problem), and fishycode does not estimate it.
3. **The effort held in long intervals, reported.**
   - `coasts` `prepare_tracks_for_effort()` caps or drops a long interval, as `rb_add_effort` does.
   - Its documentation measures what is at stake. On 3,814 trips, intervals over an hour were 0.6 % of the data and half
     of all fishing hours. The cap is 15 minutes for trackers that report every 7 seconds.
   - ramb flags each capped interval (`interval_flag`), but nothing reports the share. It was counted once here (below).
4. **A provider's re-issued trips** (`coasts` `index_trip_duplicates()`, `drop_overlapping_pings()`).
   - PDS re-cuts trips after delivery: an identifier is retired, or comes to describe another window. The same points
     then sit under two trips.
   - A whole copy is found by an order-free fingerprint of its time and position triples. The survivor is chosen by a
     stable rule: a preferred trip first, then the most points, then the lowest identifier.
   - Pings shared in part are dropped, one copy kept.
   - `rb_flag_ping_duplicate` finds a second feed's copy of a ping, not a feed that repeats itself under new keys.
5. **A versioned release, its shape checked** (Timor's `upload_dataverse()` and `check_portal_contract()`).
   - The validated landings go to Harvard Dataverse once a month, as a new version under one DOI.
   - The README is filled from a template, with its column table read from the data API's own descriptions. A column
     with no description stops the release.
   - After every export, the output set is compared with a frozen earlier one. Names, columns, nesting and types fail the
     run. Row counts and numbers are only reported, since accepting a moved number is a person's call.
   - fishycode's `R/fingerprint.R` compares two builds but fails nothing, and `manifest.yml` is unbuilt (decision 000,
     step 7). Only aggregates could go out this way (the disclosure rule).

## The classifier behind Peskas' effort: `ssf-ai-toolkit`

- **What runs.** Not the code on `main`. `coasts` installs the `plug-R` branch, whose R wrapper calls
  `statistical_effort_v3.py`. It is a hand-weighted score, not a trained model:
  - six yes/no rules: speed in the fishing range, high turning, a straight path, a winding path, fixes in a tight
    cluster, and variable speed;
  - speed and turning are averaged over a centred 10-minute window, and the path's shape (straightness, sinuosity,
    radius of gyration) is taken over all fixes within 1 km;
  - two bonuses for combined patterns and a penalty for transit speed; a fix is fishing when its score reaches half the
    total weight;
  - a run shorter than three fixes takes its neighbours' state;
  - `coasts` then keeps only the fishing fixes off land and at least 0.25 km from the coast, and stores only those.
- **Never scored as it runs.**
  - An earlier rule module (`statistical_effort_classifier`, now in `backup/`) was scored in a notebook on the Kenyan
    labels below: accuracy 0.54, F1 0.34 for fishing, a macro F1 of 0.50. That is no better than chance.
  - v3 has no score against labels.
  - A random forest (`EffortClassifier`, 400 trees) scores 0.96 in another notebook, on all 193,934 labelled fixes. No
    held-out split appears anywhere in the history, and its trained file was never committed. The number measures fit
    to the training data, not accuracy on new trips.
  - Peskas' effort grids and catch rates per cell therefore rest on an unscored score. It is our third done criterion
    seen from outside: the error has to be measured on the well-recorded part, with whole trips held out (the scoring
    row).
- **Labelled data** (cited in the benchmark and gear rows).
  - `data/dfKenyaAll_Tracks_df_cleaned.csv` holds Kenyan tracks with an observer's label on each fix.
    - It has 193,934 fixes of 239 trips and 548 hauls (`Trip_Haul_ID`) at 3 sites, from 2015-12-21 to 2018-04-07.
    - They were logged by three models of hand-held Garmin and a "legacy 2015_16" group, at a median interval of 16 s.
    - Labels: Sailing 114,473, Fishing 40,291, Searching 39,170.
    - It is in none of ramb's example data, nor among decision 148's.
  - `examples/data/all_zanzibar_*.csv` hold 8,223 Zanzibar trips from PDS trackers, July 2024 to January 2026, with
    features per trip (294 trips have two rows).
    - Each carries a gear in seven groups: ring net 2,625 rows, handline 2,031, gillnet 1,543, longline 1,132,
      unknown 671, seine 285, trap 230.
    - Each of the 98 boat names carries one gear, so the label is the boat's, not the trip's.
  - Neither file says where its data came from or on what terms; the Apache licence covers the code. The Kenyan file
    names its 8 observers (`Observer`; counted here, never printed). The authors would be asked before ramb carries
    either.
- **Movement features** (the sixth new row).
  - v3 computes on every fix the turning angle, and speed's mean and coefficient of variation over a time window. It
    also computes straightness, sinuosity and radius of gyration over a distance window.
  - ramb computes none of these; fishymodel's step-and-turn HMM uses turning angles inside its fit only.
  - They are what a learned classifier takes in.
- **Searching.** The toolkit counts searching as fishing (`_activity_to_binary`); EM4SSF's activity code puts it under
  not fishing (decision 229). The Kenyan labels keep the two apart, so either reading can be scored.
- **Not of use.**
  - The shore filter. Removing fishing within 0.25-0.5 km of the coast would remove inshore fishing in Iceland
    (lumpfish nets). Port calls serve better: they say which port the vessel was in, and fishing near the shore stays
    fishing. They are found from the port polygons and, by decision 197, a time budget: a silence near a port is a call
    when, less the time to sail from the last fix to the port and from the port to the next fix, it still reaches the
    minimum stay. The budget holds at any ping rate. It replaces the frozen departure radius, and is decided but not
    yet built.
  - The trip phases on `main`, not in production: the first and last 5 % of fixes, or those within 1 km of a trip's
    ends, are never fishing. It stands in for a port list.
  - The gear and vessel predictors, which are stubs (a logistic regression on a trip's duration, distance and mean
    speed).
  - The hex grid, which repeats `coasts`.
  - The CPUE notebooks, which regress Kenyan landing sites' catch per trip on effort with site and year fixed effects.
    That is stock status, modelling.

## Checked on our data

- **Long intervals.** On `curated/ais/trail` as built at 916b901 (decision 218), the fixes the `fishing` preset keeps,
  with hours, number 112,865,401 and hold 9,154,736 hours.

  | interval | fixes | share | hours | share |
  |---|---|---|---|---|
  | over 15 min | 1,178,504 | 1.04 % | 842,076 | 9.2 % |
  | over 1 h | 195,975 | 0.17 % | 286,472 | 3.1 % |
  | capped at 2 h | 64,258 | 0.06 % | 128,516 | 1.4 % |

  - The hours are counted after the cap; the trail does not keep how long a capped interval really was.
  - Over all 578,991,257 fixes with hours, those over an hour hold 20.9 % of the hours.
  - Under the preset, then, long intervals weigh far less here than on Peskas' trackers.
- **H3 and positions out of range.** `coasts` `valid_coordinates()` drops a position out of range before indexing,
  because H3 does not reject a finite latitude past 90. It reflects it over the pole and returns an ordinary cell
  (measured there with h3jsr).
  - DuckDB's H3 extension, which `curate/ais_ping_tag.R` calls before any cleaning, does the same. A latitude of 91 at
    22° W comes back as a cell at 89° N, 158° E, with no error.
  - In `staging/ais/ping_tagged`, 11 of 589,267,384 pings have a latitude past 90 and 1,317 a longitude past 180.
  - None of these 1,325 received a depth, habitat or area: their cells lie outside `area_h3`. Harmless today, though
    nothing guards against it.

## Lessons that echo ours

- **An unpinned web source moved published numbers.** FishBase's "latest" moved from release 25.04 to 26.06 on a
  container rebuild. Two families kept their names with no species, and a taxon of 5 % of landed weight left Timor's
  portal on two runs, with no error. Timor pins the release now. fishycode's `lookups` reads two Wikipedia pages on
  every build (decision 218): the same exposure, with less at stake.
- **Every device that ever was, not who owns it now.** Picking trackers by their current owner dropped the history of
  any tracker that changed hands. Timor keeps a roster of every device ever deployed, against which it rebuilds the IMEI
  a fishery officer wrote down in part (about 7 of 15 digits). It is the lesson of the STK key's segments and of
  reading the register as evidence.
- **A key is flagged, never blanked.** A landing date in the future stays and is flagged, because it is the merge key,
  and blanking it would hide a typo that can be corrected.

## Not of use here

- The survey form's reshaping, lengths into weights (Iceland weighs), nutrients, and the imputation of missing months
  (Amelia). Imputation is modelling, not bookkeeping.
- Timor's `merge_trips()`, one landing to one tracked trip per device and day; `rb_link_trip_landings` steps through
  more.
- Joining a trip cut in two (`merge_consecutive_trips()`), which ramb's stretches do.
- The incremental store behind `coasts`' effort grid. A trip's effort is kept per cell and day, so it can be withdrawn
  when PDS revises the trip, and a run may delete at most a set share of the store. fishycode rebuilds from raw instead;
  this matters only if it ever updates nightly.

## Seen in passing

`validate_pds_data()` in the Timor package has two slips. Alert 12, a one-way trip, can never fire, because a catch-all
branch comes before it in the `case_when()`. Its threshold is `start_end_km * 100`, so 3 km reads as 300 m. They could
go to the authors as a `curate/issues/` note; none has been written.

## Not done

- Nothing has been built in ramb, and no `TODO.md` item has been opened. Which rows to build is the maintainer's choice.
- The toolkit's authors have not been asked where the Kenyan and Zanzibar data come from or on what terms.
- The toolkit's code was read, never run.
