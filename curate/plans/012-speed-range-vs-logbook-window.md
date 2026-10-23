# 012 — Speed range and the logbook time window: which one defines "fishing"?

**status:** partly built — step 0 (2026-10-02) and step 4 (gear codes on the trail, decision 085); steps 1–2 not taken
up (decision 093); step 3 (the last haul) not taken up, since §2d and §2k found no unclosed last haul (2026-10-23, Claude's audit, not checked by a person); ask (1) answered 2026-10-23 (decision 201: tows judged against `uv`'s dated regulation areas, which also give step 5 its
baseline); the gillnet floor measured 2026-10-23 (§2m: 0.2 kn recommended); step 5 and the layer open (TODO 34) · **2026-10-02** · **see:** plan `010-ping-activity-link.md` (§2, §11), plan `004-behavioural-fishing-windows.md`,
`reference/gear/windows.R` (the gear `s1`/`s2`), `R/trail_sql.R` (`fishing`), `curate/station_window.R`; the exploratory post
`fishyweb/blog/posts/trawl-footprint/index.qmd` (draft, not rendering).

Drafted with AI assistance (Claude) from the trawl-footprint post of 2026-10-02 and the maintainer's direction.

**Measured** (2026-10-02, `$FISHYDATA`, read-only, trail 2008–2024): §2.
**Assumed:** §3 onward is proposal. The maintainer's statement that captains often forget to close the last haul of a trip is **an
observation not yet seen in the data** (§2d); it is a hypothesis this plan tests.

## 1. The question

`curated/ais/trail` flags a fix `fishing` when a tow window holds it **and** its speed is inside the gear's `[s1, s2]`. Two things
define "fishing" and they disagree: the **logbook window** (times the skipper wrote) and the **speed range** (one pair of numbers
per gear, set by hand in `reference/gear/windows.R`). The maintainer's rule of thumb: where the captain set both haul times,
that window is the best evidence there is, so **the speed range should be read off those pings**, and not declared per gear: first per gear and target, then refined by vessel size class, and per individual vessel only if that is still not enough.

## 2. Measured

a. **The gear range is wrong for the gears, not only for the fleet.** Speed inside *recorded* tow windows, fish trawl (`gid` 6):
mass at 3–4.5 kn, 9 % below 2.625 kn including a spike at 1.75 kn. Per-vessel medians (117 vessels, >5,000 pings) run from
1.9 to 4.2 kn, per-vessel 90th percentiles from 2.2 to 5.3 kn. One range cannot fit that.

b. **Three gears are folded into `OTB`.** `gid` 6 (botnvarpa, fish) 2.85 M tow stations, 7 (humarvarpa, nephrops) 84 k, 8 (rækjuvarpa,
shrimp) 792 k, with gear ranges 2.625–4.7, 2.375–3.7 and 1.75–3.0 kn. The trail carries `gear = OTB` only; `gid` has to be joined from
`station_window` on `(.sid, schema)`. The 12 mile limit in the north-west is closed to fish trawl and open to shrimp trawl, so the
distinction is needed to read the map at all.

c. **Window and speed are not interchangeable.** On 2008–2024 OTB voyages at sea (fish, nephrops and shrimp pooled, 2.625–5.5 kn):
speed alone 47.3 M pings, window alone 53.5 M, both 43.9 M. Of the 53.6 M window pings, about 12 M fail the speed test
(8.0 M slow, 2.4 M fast, 1.6 M with no speed), and about 5.7 M in-range pings sit outside every window.

d. **Last tow of a trip (hypothesis not seen).** Fish trawl, 2008+, trips with two or more stations. Share falling back to the day
window: last station 3.5 %, other stations 4.7 %. Median recorded tow length: last 187 min, others 232 min; over 12 h:
0.20 % vs 0.12 %. A forgotten end would show as a day fallback or a long tow, and neither is more common on the last tow. The
adapter may have repaired or dropped such stations before this table (decision 057, "Overlap QC" in `sources/afli/convert.R`), so absence
here is not absence in the raw data.

e. **Level 1 measured, 2026-10-02** (`curate/checks/gear_speed_range.R`; recorded windows, `n_sid == 1`, 2008–2024, speed in knots):

   | gear | tow fixes | q05 | q25 | median | q75 | q95 | declared | inside declared |
   |---|---|---|---|---|---|---|---|---|
   | 6 fish trawl (OTB, DEF) | 38.5 M | 2.19 | 3.40 | 3.74 | 4.06 | 4.70 | 2.625–4.7 | 88 % |
   | 7 nephrops trawl (OTB, CRU) | 3.2 M | 2.20 | 2.80 | 3.00 | 3.20 | 3.53 | 2.375–3.7 | 91 % |
   | 8 shrimp trawl (OTB, CRU) | 5.1 M | 1.80 | 2.20 | 2.41 | 2.60 | 3.07 | 1.75–3.0 | 90 % |
   | 9 midwater trawl (OTM, SPF) | 3.7 M | 2.20 | 3.66 | 4.20 | 4.70 | 5.40 | 2.625–6.0 | 92 % |

   - **The gear level separates the gears clearly and the declared trawl ranges are roughly right.** Interquartile ranges do not
     overlap between shrimp, nephrops and fish trawl, and each declared range keeps 88–92 % of its recorded tow fixes. The one range
     that is wrong in kind is the old page's single 2.6–5.5 kn for all trawls (shrimp and nephrops tow at 2.2–3.2 kn).
   - **The "hump" below the fish trawl's lower limit is mostly the GPS logger.** 7.6 % of all `gps` speeds, and 12.1 % of `gps` fish-trawl tow
     fixes, are exactly 1.943846 kn, which is 1.000 m/s. Share of fish-trawl tow fixes below 2.625 kn: stk 4.7 %, astd 4.6 %, emodnet
     5.7 %, **gps 14.9 %**. Without the logger the fish-trawl lower tail is thin; pooled quantiles (q025 = 1.94 kn) are the logger's value.
     Whether 1 m/s is a placeholder, a unit rounding or real slow towing is unknown and needs the logger's raw speed column.
   - **Provider matters more than period.** Fish-trawl medians: stk 3.80, astd 3.74, gps 3.69, emodnet 3.72; by period 3.79, 3.73, 3.74.
     STK speeds are quantised to 0.1 kn.
   - **Recorded windows only inform speed for trawls.** For Danish seine (11), jigging (14) and static gear (1–5, 12, 16, 22) the window holds
     steaming and drifting as well as the working part (Danish seine: median 2.1 kn, q95 9.1 kn; only 63 % inside the declared range).
     The method of §3 does not carry over to them without a different window; this plan stays with the towed gears.
   - Not yet measured: gear × target beyond the four above (`DRB` 15, `SDN` 11 have a target of `DES` and `DEF`), and whether the per-vessel spread
     (§2a) shrinks once the placeholder (§2f) is out.

f. **The logger's 1 m/s is a placeholder, not a speed** (measured 2026-10-02, same script §4). The logger's raw speed (`skip_hradi`) is m/s on a
   0.1 kn grid (spikes every 0.0514 m/s); exactly **1.000 m/s** is off that grid and has 1.77 M rows, more than any neighbouring value.
   - *When:* 0.01–0.14 % of `gps1` speeds up to 2019, then **12 % in 2020, 39 % in 2021, 37 % in 2022, 24 % in 2023**. `gps2` has 0.07 %; it is the
     older table (`sjalfvirkir_maelar`, `gps1`) that carries it, concentrated in some vessels (95th percentile of the per-vessel share 17 %, max 49 %).
   - *Placeholder, by two witnesses:* where the logger's fix ties an AIS ping, the AIS speed beside a 1.000 m/s logger value has median 3.40 kn
     (stk) and 3.32 kn (astd), the ordinary towing speed, not 1.94 kn. Where `gps1` and `gps2` both hold the same fix and `gps1` says 1.000 m/s they
     agree only 17 % of the time, against 97 % otherwise. So `ais_ping_trail.R`'s statement that the two tables "never disagree" is false
     for these rows.
   - *Effect now:* each such fix in a tow window is below the gear's `s1` and so is `fishing = FALSE`: 12 % of the logger's fish-trawl tow fixes, and most of
     the 14.9 % below 2.625 kn that §2e attributed to the logger. From 2020 on the logger is a large share of the record, so this biases `fishing`
     low from 2020 on.
   - *Not known:* why (firmware, a clamp, a default written when the sensor had no fix). The raw speed column cannot say; the logger vendor might.

g. **Level 2 measured, 2026-10-02: power, length and age explain almost none of the towing speed** (`curate/checks/gear_speed_by_vessel.R`; recorded tow
   windows of the three OTB gears, 2008–2024, placeholder excluded, groups of ≥ 200 fixes by vessel × year × provider; 138 fish, 27 nephrops and 72 shrimp
   trawlers with kW, LOA and a registry age). Share of the fix-level speed variance within a gear that each set of predictors explains:

   | predictors | fish (6) | nephrops (7) | shrimp (8) |
   |---|---|---|---|
   | provider | 0.1 % | 0.2 % | 0.2 % |
   | provider + log kW | 0.4 % | 0.9 % | 1.8 % |
   | provider + log LOA | 0.5 % | 1.0 % | 2.0 % |
   | provider + age | 0.2 % | 3.2 % | 0.2 % |
   | provider + kW + LOA + age | 0.6 % | 4.2 % | 2.2 % |
   | provider + year | 0.2 % | 2.5 % | 1.3 % |
   | provider + **vessel** | **6.2 %** | **9.8 %** | **7.4 %** |

   - Most of the speed variance is within the tow and within the vessel and neither the gear, power nor age touches it. The vessel itself explains 6–10 %.
     kW, LOA and age together account for **9 %** of that vessel-attributable part for fish trawl (41 % nephrops, 28 % shrimp, on 27 and 72 vessels).
   - The effects are small: per doubling of kW, mean tow speed rises 0.05 kn (fish), 0.15 kn (nephrops), 0.13 kn (shrimp); per 10 years of age it falls
     0.02, 0.05 and 0.01 kn. By kW class the fish trawl means are flat at 3.6–3.8 kn from 300 to over 3,000 kW. The one class that separates is
     **under 300 kW**: fish 2.30 kn (12 vessels, 56 k fixes), shrimp 2.02 kn against 2.4–2.5 for the larger.
   - Limits of the measurement: `kw` and `loa` are one value per hull (a refit or re-engining is invisible); `yh1` is the year the hull first appears in the
     Hreiðar registry, not the year it was built, so age is an upper bound; the 1.0 m/s logger placeholder is out but speeds are otherwise as in the trail.

h. **Level 3 measured, 2026-10-02: a vessel's range is stable in location, but a per-vessel range is no better than the gear's** (`curate/checks/vessel_speed_range_stability.R`;
   recorded tow windows, OTB gears 6–8, 2008–2024, placeholder excluded, vessel-years with ≥ 2,000 fixes: 1,077 fish (123 vessels, 102 with ≥ 3 years),
   164 nephrops (25), 281 shrimp (67)).
   - *Stability.* After removing the provider offset, the yearly **median** is stable within a vessel: ICC 0.67 fish, 0.68 nephrops, 0.50 shrimp (within-vessel sd
     0.11–0.18 kn, between-vessel 0.16–0.25 kn). The **tails** are less so: ICC of the yearly q05 0.49 / 0.66 / 0.56 and of q95 0.53 / 0.53 / 0.32, with a within-vessel sd of
     0.4–0.5 kn for the fish trawl's tails.
   - *Out of sample.* Applying a vessel's **previous-year** 5–95 % range to this year's tow fixes keeps 90.0 % (fish), 90.2 % (nephrops) and 89.7 % (shrimp), against 90.3, 90.6
     and 90.5 % in sample, **91.0, 92.4 and 90.7 % for the declared gear range** and 90.8, 91.0 and 91.0 % for the gear's pooled 5–95 %. Same coverage, no gain.
   - *Width.* The mean 5–95 % width of a vessel-year is 2.01 kn (fish), 1.14 (nephrops), 1.36 (shrimp), against 2.00, 1.23 and 1.29 pooled and 2.08, 1.33, 1.25 declared. A per-vessel range is
     not narrower, so it cannot exclude more non-tow speeds at equal coverage; it only shifts.
   - *So:* the vessel carries a stable offset (§2g's 6–10 % of the variance), not a different shape. Not yet tested: a **shifted gear range** (vessel median plus the gear's pooled
     half-widths) out of sample, which uses the stable part and none of the unstable tails.

i. **The vessel-shifted gear range, out of sample, 2026-10-02** (`curate/checks/vessel_shifted_range.R`; same fixes as §2h). Range = the gear × provider 5–95 % range moved by the vessel's
   offset (its median of speed minus the gear × provider median) in the **previous** year; vessel-years with a qualifying previous year (935 fish, 134 nephrops, 193 shrimp).
   Share of this year's tow fixes kept (fix-weighted):

   | | fish (6) | nephrops (7) | shrimp (8) |
   |---|---|---|---|
   | declared gear range | 91.0 % | 92.4 % | 90.7 % |
   | gear × provider range, unshifted | 90.9 % | 91.4 % | 91.1 % |
   | **shifted by last year's offset** | **91.2 %** | **92.5 %** | **91.3 %** |
   | shifted by this year's offset (in sample) | 91.5 % | 93.0 % | 91.8 % |
   | vessel-years keeping < 80 %: unshifted → shifted | 5.0 → 3.9 % | 5.2 → 1.5 % | 6.7 → 5.7 % |
   | **vessel-years with \|offset\| > 0.3 kn** (106, 14, 49): unshifted → shifted | 85.3 → 89.7 % | 76.9 → 89.4 % | 87.0 → 86.3 % |

   - The overall gain is 0.2–1.1 points. The shift pays only for the vessel-years with a large offset (11 % of fish-trawl vessel-years, 10 % of nephrops, 25 % of shrimp), by
     4 points for fish trawl and 12 for nephrops, and not at all for shrimp. In sample the shift reaches 90.4 and 89.9 % there, so last year's offset recovers most of what it could.
   - The unshifted gear × provider range is no better than the declared range (90.9 against 91.0 % for fish), so the provider-specific ranges buy nothing either.
   - **Reading of §2e–§2i together:** the declared trawl ranges keep about 90 % of recorded tow fixes; size, power, age, provider, period and the vessel's own range add under a point,
     the shift a point on a tenth of the vessel-years. The speed range is a small lever. The defect that moves `fishing` is the logger placeholder (§2f), then the window itself (§2d).

j. **Is the logbook's gear right? The landings as a witness, 2026-10-02** (`curate/checks/gear_logbook_vs_landing.R`; logbook trips linked to landings through `lid_map` match types 01–03, the landing's
   gear and species from `landing/catch.parquet`, species 41 = shrimp).
   - *Agreement.* Trips with one OTB gear in the logbook, logbook gear against the landing's dominant gear: **fish trawl 92.9 %** of 41,241 trips, **nephrops 99.5 %** of 5,213, **shrimp 98.4 %** of 7,770.
     The fish-trawl disagreements are mostly one landing gear, 15 (2,554 trips), which in the logbook is the plough/dredge code; whether that is a landing-system coding quirk or a real
     mismatch is not known. 118 trips logged as shrimp trawl were landed as fish trawl (1.5 %).
   - *North-west, within 5 km of the coast* (distance to the Natural Earth coast, 2008–2024; a stand-in for a fjord polygon, which does not exist in `$FISHYDATA`). Logbook gear of the tow fixes: shrimp trawl **86 %**,
     fish trawl **14 %** (41,552 fixes, 1,041 trips); further out, 97 % fish trawl.
   - *Those fish-trawl trips are not shrimp trips mislabelled.* 97.9 % of the 961 with a landing landed under 10 % shrimp (median 0 %), against a median 90 % shrimp for the shrimp-logged trips further out.
   - *But by speed they look like slow tows.* 71 % of their fixes are at 1.75–2.6 kn (shrimp-trawl speed; the same band holds 72 % of the shrimp-logged fixes there), 11 % at the fish-trawl 2.6–4.7 kn, against 84 % further out.
   - *And by vessel they are small boats.* 52 % of the near-coast fish-trawl fixes come from 12 vessels under 300 kW and 35 % from 10 vessels of 300–600 kW; further out it is 1.5 % and 26 %. This is the
     under-300 kW class that §2g found towing at 2.3 kn.
   - *So:* the logbook gear is right more often than not and the landings confirm it; the near-coast fish trawl is a population of **slow, small vessels landing fish**, not a gear error that the landings can
     see. Whether such trawling inside the limit is allowed is a question about the rule and any permits, not something these data decide; a flag, not a correction.
   - *Consequence for the speed range:* a single fish-trawl range misfits these vessels by construction; the one split §2g found worth making (under about 300 kW, or the vessel's own offset, §2i) is the same
     population.

k. **The logger is switched on and off with the logbook, 2026-10-02** (`curate/checks/logger_vs_tow_window.R`; 477,412 afli OTB stations with a logger and a recorded tow window, 2008–2024; logger fixes are stamped
   to afli stations only, `.sid < 0`). `t1` and `t4` are not recorded for trawls, so the window is `t2`–`t3` and the comparison is with that.
   - *Start: the logger starts with the tow.* Fixes per 15 minutes: 462 k in the first quarter-hour after the window start, **2.7–9 k** in each quarter-hour before it. The first fix falls a median of 6 min after
     `t2` (logger interval about 8.5 min; 40 % within 5 min, 89 % within 15 min). So the logger's start *is* the logbook's `t2`, one event written twice: the logger's own start carries no evidence of when the tow began.
   - *End: it does not stop with the tow.* The last fix is a median of 42 min after `t3` (only 9 % within 15 min); 72 % of all logger fixes are inside the window. Mean speed after `t3` (fish trawl): 3.8 kn before,
     2.8 kn in the first quarter-hour (haul-in), 5.3 kn then 6–7.5 kn (steaming and the next shot), with steaming over 6 kn in 5.5 % of the first quarter-hour's fixes. The logger is therefore
     a witness to the *end* of the tow that the logbook window does not contain.
   - *Last tow of a trip, forgotten end?* In the first quarter-hour after the recorded end, 14 % of the last tow's logger fixes are already above 6 kn against 5.5 % for other tows (mean 3.44 against 2.78 kn);
     by 30 min, 77 % against 44 %. The vessel is steaming sooner after the last tow, as expected; the slightly faster first quarter-hour suggests the end is, on some last tows, logged somewhat **late**, not early. It
     does not show the logger holding tow speed past the recorded end, which is what an unclosed haul would look like.
   - *So for the speed range:* inside a window the logger's speed is a measured GPS speed, as good as AIS speed (§2e: medians within 0.1 kn), but it exists only for the tow by design and adds no check of the window's
     start. The speed ranges of §2e–§2i should therefore be read from AIS pings, with the logger as a cross-check, not pooled with it. The logger's after-`t3` speeds are the new information it carries.

l. **Vessel × gear for the stretch pairing, and over what period, 2026-10-14** (Claude, AI-assisted; the maintainer's question for TODO 61: vessel × gear rather than gear, and the full
   period rather than a month). Script and log: `$FISHYDATA/archive/2026-10-speed-range/`. Recorded tow fixes of all years (`n_sid = 1`, `phase = 'tow'`, `win_basis = 'recorded'`,
   towed gear, 58.8 M fixes); "offset" = the vessel × gear median minus the gear's median, used where the vessel × gear has ≥ 2,000 such fixes.
   - *Drift within vessel × gear* (vessel-years with ≥ 2,000 fixes). The sd of the yearly median around the vessel × gear's own, against the sd between vessels, in kn:
     fish trawl (gid 6) 0.17 / 0.51, shrimp (8) 0.17 / 0.24, nephrops (7) 0.09 / 0.22, dredge (15) 0.12 / 0.32, **pelagic trawl (9) 0.45 / 0.41, Danish seine (11) 0.48 / 0.38**.
     The mean gap between two yearly medians grows with the years between them, slowly: fish trawl 0.07 kn at 1 year, 0.15 at 8; pelagic trawl 0.26 → 0.42; Danish seine 0.16 → 0.33.
     For the trawls the vessel is the larger effect and the drift is small; for pelagic trawl and Danish seine the year-to-year noise is as large as the difference between vessels.
   - *The offsets.* Fish trawl: median −0.06 kn, 5–95 % −1.19 to +0.21 (the slow tail is §2j's small near-coast vessels); 23 of 121 vessels beyond ±0.3 kn, holding 4 % of the fixes.
     Pelagic trawl: 39 of 113 beyond ±0.3 kn (17 % of fixes).
   - *The pairing* (decision 092's settings, 397,248 tow operations of 2010, 2013, 2016, 2019, 2023 and 2025; each variant changes one thing):

     | variant | paired | start within 15 / 30 min | end within 15 / 30 min | fish in tow | not fish ≥ 30 min out |
     |---|---|---|---|---|---|
     | A the prototype: declared range of the vessel's commonest gear in the month | 93.9 % | 51.3 / 70.6 % | 50.4 / 65.6 % | 92.2 % | (86.8 %) |
     | B declared range of the fix's gear (the nearest declared tow) | 94.0 % | 51.5 / 70.8 % | 50.6 / 65.8 % | 92.6 % | 82.7 % |
     | **C B shifted by the vessel × gear offset, all years** | 93.9 % | **52.3 / 71.6 %** | **52.4 / 67.2 %** | 93.3 % | 82.7 % |
     | D the vessel × gear's own 5–95 %, all years | 94.4 % | 52.4 / 68.0 % | 55.6 / 67.8 % | 94.0 % | 79.7 % |
     | E as C, offset of the test year only | 93.7 % | 52.5 / 71.7 % | 52.7 / 67.4 % | 93.4 % | 82.7 % |
     | F as C, offset of all other years (out of sample) | 93.8 % | 52.2 / 71.4 % | 52.2 / 67.0 % | 93.2 % | 82.6 % |
     | G as C, offset of the previous year | 93.8 % | 52.3 / 71.4 % | 51.9 / 66.7 % | 93.0 % | 82.7 % |

     "Fish in tow": fixes in recorded tows whose ±10 min speed is in range. "Not fish": at-sea fixes ≥ 30 min from any declared tow out of range. A's figure is flattered: a fix in a month
     with no tow gets no range under A.
   - *By gear:* bottom trawl (294 k tows) gains most from C: start within 15 min 54.4 → 55.6 %, end 57.1 → 58.4 %, paired 94.2 → 94.7 %. Pelagic trawl gains 1.7 points of pairing from B
     (vessels switch gear within a month), and its end agreement most from E (35.3 → 37.8 %). **Danish seine loses pairing under every shift** (97.9 → 94.7 % under C). Under D its end within
     15 min jumps 20 → 48 %, while its start within 30 min falls 83 → 63 %: one range cannot hold both its phases (decision 090). Dredges do best under D (paired 83.3 → 85.6 %).
   - *So:*
     - **Vessel × gear as an offset on the gear's range** gains about a point in boundary agreement and 0.7 in fish-in-tow at no cost in specificity. This is §2i's finding, now for the
       pairing.
     - **The full period is enough.** It equals the out-of-sample estimate (F), so it is not flattered by the test year. The test year alone (E) adds a few tenths, and the previous
       year (G) slightly less.
     - The vessel's own range (D) is wider: it trades the start for the end, and 3 points of specificity.
     - The gear a fix takes should come from the nearest declared tow, not from the month.
     - Danish seine wants no shift until it has a phase model.
   - *Outcome* (maintainer, 2026-10-14, asking whether this beats the status quo): the vessel × gear shift is not taken up. The gain is agreement with the logbook, not accuracy, and does not pay for a table, a fallback and an exception. `fishing` tests the ±10 min speed instead (decision 093).

m. **A gillnet speed floor from the recorded hauls, 2026-10-23** (decision 201; Claude (AI), read-only on the build of 2026-10-22, **not checked by a person**). Script, tables and a
   README in `$FISHYDATA/archive/2026-10-todo34-uv-areas/`. The declared gillnet ranges (gid 1-4, 22) start at 0 kn, so a stopped gillnetter passes the speed test (decision 198).
   - *Every gillnet fix in one class* (23,419,323 fixes in a gillnet window or on a gillnet voyage, 2007-2026; the account closes in every year; the recomputed ±10 min median reproduces
     `fishing` and `fishing_flow` on every fix). Fishing today: 10,641,382 fixes, 876 k h. A floor can touch 10.6 M of them: recorded hauls at sea 3.54 M, other gillnet windows 2.18 M,
     windows in a port call 344 k (97 k h), and the voyage rule's passes (no-haul voyages 3.52 M, soaks 630 k, hauling-like 283 k, after the last haul 80 k). Sets, fixes with no speed and
     the voyage rule's fails cannot change.
   - *The recorded hauls' median speed* (5.24 M fixes at sea): p01 0.16, p05 0.35, p10 0.48 kn; among those the flow calls fishing 0.10 / 0.30 / 0.40. p05 by year 0.20-0.50, lower since
     2022 (0.25-0.32). Speeds step on STK's 0.1 kn grid.
   - *Candidate floors* (share of today's fishing fixes stopped): at 0.2 kn the hauls lose 1.85 % (8.8 k of 249 k h) and 9 of 287 vessels over a fifth of theirs; 97.8 % of the port-call
     fixes go (92 k h), 29 % of the soaks, 23 % of the no-haul voyages; 230 k of 876 k fishing hours in all. At 0.3 kn (near the 5th percentile decision 201 named): 6.0 %, 78 vessels, 98.3 %,
     34 %, 26 %. At 0.1 kn: 1.2 %, 8 vessels, 96.5 %, 28 %, 23 %.
   - *Recommended* (Claude's, for the maintainer): **0.2 kn** for gid 1-4 and 22, its basis the recorded hauls. Above it the haul loss triples for half a point more of the port fixes. A rule
     that no fix in a port call is fishing would remove those whatever their speed: a separate choice.
   - *Note:* `uv`'s regulation areas were measured the same morning before the task was narrowed (an inventory, a scratch layer, the tows scored). They are kept as a note in the
     folder's `uv_note/`, a basis for nothing; `uv`'s holdings are recorded in decision 201.

## 3. Proposal

**Principle.** A *recorded* window (both haul times logged) is the training set for the speed range; a *derived* or *synthesised* window is
a thing to be tested by the speed, never a source of it. This keeps the cycle open: AGENTS.md says a cycle is broken by a human outside the
DAG, and here the range comes only from recorded windows, never from windows the speed has already adjusted.

0. **Fix the logger first (done 2026-10-02: `speed` NA and tagged, `fishing` NA without a speed, trail rebuilt and verified; see `curate/corrections/logger_speed_placeholder.yml`).** Where the logger speed is exactly 1.000 m/s, set `speed` to NA and `speed_basis` to `"placeholder"`, keeping the value in
   `speed_raw` (never destroy the original; `speed_basis` already carries provenance). Done in `curate/ais_ping_trail.R` (and check the `gps1`/`gps2` collapse
   rule there, which takes "whichever has it" and so can pick the placeholder). `fishing` for those fixes is then NA, not FALSE. Rerun `ping_trail` →
   `ais/trail`. Measure afterwards: fix counts flipped, the logger share below `s1`, and the 2020–2023 `fishing` share by provider.
1. **A speed range at three levels, explored in this order, each only if the one above is not enough** (maintainer, 2026-10-02):
   1. **Gear and target (measured, §2e: confirms the declared trawl ranges to within ~10 %, the largest defect being the GPS logger value; what is left is to decide whether to replace them).** `gear_window` already carries `target` (`DEF` fish, `CRU` crustaceans, `SPF` small pelagic), and `gid` splits the
      three OTB gears. Per `gid` (or gear × target) the range from recorded windows replaces the hand-set `s1`/`s2`. Measure first
      how much of the variance this already explains; the declared ranges for 6, 7 and 8 differ by up to 0.9 kn at the low end.
   2. **Vessel size class within that (measured, §2g: little to gain; at most one split under about 300 kW).** `vessel.parquet` has `loa`, `kw`, `kw_total` and `grt` per registration period (`yh1`–`yh2`), so a vessel's
      class can be year-specific. The class edges are to be *read off the data* (speed against `loa`/`kw` in recorded windows), not chosen first.
   3. **The individual vessel (measured, §2h: stable median, but a range of its own gains no coverage and no width over the gear's; the vessel-shifted gear range, tested in §2i, gains 0.2–1 point overall and 4–12 points for the tenth of vessel-years with a large offset)**, only where classes leave a residual that matters: `(vid, gid)` quantiles, with `n` and a `basis`
      (`recorded` when n ≥ 2,000, otherwise the class range, otherwise the gear range). Decide the quantiles (2.5/97.5 used in the
      exploration), the minimum n, and whether per year.

   Each level is a table with the same columns, so the consumer takes the most specific range available and `basis` says which level it
   came from. Stop at the level where an extra level stops changing which pings are flagged (pings flipped, share by gear, §2c).
2. **Use it in `fishing`**, in place of `gear_window.s1/s2` in `R/trail_sql.R`. Compare before and after on real data, as the repo does:
   pings flipped, share by gear, the NW map by gear. This changes `fishing`, so `ais/trail` and everything downstream of it
   (`trail_match`, the docs) is rerun in full; the maintainer has accepted that.
3. **Test the window by the speed.** For each tow, run length of towing speed just outside the recorded ends. Compare last tows with
   others (§2d). If the maintainer's hypothesis holds the last tow's speed run extends past its end; the response is a flagged
   extension (`win_basis = "extended"`), never an overwrite. *Not taken up (2026-10-23, Claude's audit, not checked by a
   person): §2d and §2k already answer it; no unclosed last haul is seen, and the end looks late on some last tows.*
4. **Keep fish, nephrops and shrimp apart** everywhere (`gid` onto the trail so no join is needed downstream), and carry the landing's gear beside the logbook's as a **check, never an overwrite**
   (`gid_landing`, `gear_agrees`): §2j shows 93–99 % agreement, so the disagreeing 1–7 % is a short list to look at, not a population to relabel.
5. **12 mile limit.** Needs a legal line (baselines), which is not in `$FISHYDATA`. Until then a 22.2 km buffer on the Natural Earth
   coast is an *approximation* and a lower bound (the legal line lies further out across fjords and bays).

## 4. Open, for the maintainer

- Whether fish-trawl tows of small vessels near the coast (§2j) are permitted, so the flag can say "suspect" or "expected"; and a fjord polygon, since 5 km from the coast is a crude stand-in.
- Where to get the baseline / 12 nm polygon (`staging/aux/`), and whether tows of a fish trawl inside it are errors in the logbook gear
  or illegal fishing: that is not ours to label.
- How far down the hierarchy to go (gear and target, size class, vessel), per year or not; the quantiles.
- Whether `gid` joins onto the trail as a column (a rebuild of the trail, partitioned by month).

## 5. Not decided here

The exploration post is a draft (`draft: true`); it hit an out-of-memory spill in a join, which is a signal that the `gid` and range
should be columns of the trail, not computed in the post.
