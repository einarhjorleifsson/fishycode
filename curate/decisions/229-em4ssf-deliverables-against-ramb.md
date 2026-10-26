# 229 — EM4SSF's deliverables read against ramb: the same flow for small-scale fisheries, no code yet, nine wishes added

*2026-10-26. The maintainer asked for the folder `~/stasi/EM4SSF` to be mined: "are they not trying to do the same as is
now in ramb. anything in ramb that may be missing". Claude (AI) read the five deliverables against ramb 2026.10.25.5
(9a67e0d) and wrote this record and the new wish-list rows in `docs/one_flow.qmd`. No person has checked them.
Nothing went into ramb.*

## What the folder holds

Five PDFs and no code. The same day they moved, by the maintainer's choice, to `$FISHYDATA/raw/external/em4ssf/`.
Every file there was checked by sha256 against the original, and the original folder went to the macOS Trash. Nothing
read the old path. The folder's `README-provenance.txt` gives each file's sha256 and Ares number; where the files came
from is not recorded. EM4SSF (*Enhancing Monitoring for Sustainable Small-scale Fisheries*) is
EMFAF project 101241632, from 2025-09-01 for 30 months. It is coordinated by A. N. Tassetti (CNR-IRBIM) and T. Mendo,
with DTU, IPMA, HCMR, UPC and ICES as partners, and has five case studies: Italy, Spain, Portugal, Denmark and Greece. All
five deliverables are marked public (PU), but each carries a proprietary-rights statement. Here they are summarised in
our own words and cited by number and section, never quoted.

| file | deliverable | version, date | pages | md5 |
|---|---|---|---|---|
| `Attachment_2.pdf` | D1.1 Data management plan (WP1, CNR-IRBIM) | 3.0, 2026-02-28 | 24 | `1c981568778b3bd7ff8cec88140a4edc` |
| `Attachment_3.pdf` | D2.1 Common format for VT data (WP2, DTU: Egekvist, Rufino) | 1.1, 2026-02-27 | 10 | `7f637c95e1efb9ff4be4083ae2a8a59a` |
| `Attachment_4.pdf` | D2.2 Template for validation of on-board activities (WP2, DTU: Egekvist, Rufino); the template in seven languages | 1.1, 2026-06-30 | 41 | `9d2720eb10052d3e5462d5d22d5f7f1a` |
| `Attachment_0.pdf` | D5.2 Communication and dissemination plan (WP5, CNR-IRBIM) | 3, 2026-02-10 | 23 | `1ae5eb9428b2679b76d0b7e51af18970` |
| `Attachment_1.pdf` | D5.3 Communication toolkit (WP5, CNR-IRBIM) | 3.0, filed 2026-03-03 | 13 | `84b7a093c43b0febf4275bc6b1c3ffb3` |

## The same aim, narrower, and not yet written

- **The aim overlaps ramb's.** WP4 is to build one workflow in R and Python, applied alike in every case study. It cleans
  the tracks, cuts trips, classifies activity and makes gridded effort and maps (D1.1 §2, §3.1.3-3.1.4, §3.3.3). These
  are ramb's rows from the ping flags to the products.
- **What it leaves out.** It plans no catch split over fixes, no logbook ↔ landings link, no basis on each value and no
  matching of two feeds. Its ground truth is observers and fishers (D2.2), and the logbook is one source among them.
- **Its code is not written yet.** Code, workflows and protocols are due on GitHub and Zenodo as D4.1 (month 21, May
  2027) and D4.2 (month 29, January 2028), with a peer-reviewed software paper, D4.3, in month 29 (D5.2 §5).
  - A hackathon is set for month 15: November 2026 in Ancona, also in `docs/ices_reports.yml`, which says it is to
    harmonise code.
  - WKSSFGEO3 is in month 28, December 2027.
- **Where its methods start.** Its starting points are WKSSFGEO2, iapesca, TACSAT/EFLALO and Rufino et al. 2023 (D2.1
  §1-2). ramb already has the WKSSFGEO2 examples and the trip rules of CNR-IRBIM and iapesca, each checked against the
  published code (decision 148, `docs/one_flow.qmd`).
- **Records meet the track by time.** Observers record times, not positions; positions come from a tracker carried on
  the trip (D2.2 §2.1). That is ramb's design: a record meets the pings by its times (`rb_create_record_windows`).

## What they ask for that ramb lacks

These are the nine new rows in the wish list of `docs/one_flow.qmd`:

1. **Their exchange format, in and out** (D2.1 tables 1-2).
   - The raw table is `VESSEL_ID`, `DATE_TIME`, `LATITUDE`, `LONGITUDE`, `SPEED`, `COG`, `HEADING` and `DATA_SOURCE`.
   - The processed table adds `TRIP_ID`, `ACTIVITY_ID`, `ACTIVITY` and `GEAR`, each with a `_SOURCE` column.
   - ramb has no reader or writer for it; its WKSSFGEO examples are renamed in `data-raw/` only.
2. **The source of each value** (D2.1 table 3). Five codes say where a value came from: logbook, observer, analysis,
   sensor or other. ramb's `basis` says how a value was obtained, which is a different question. Neither answers the
   other, and ramb has no observer or sensor as a source of records.
3. **One activity code on every fix** (D2.1 table 4). It has two levels: fishing (setting, hauling, shooting) and not
   fishing (steaming, harbour, searching, transport, transhipment).
   - ramb has the pieces: port calls, record phases and `rb_add_fishing`. No function labels the fixes in this code.
   - Nothing in ramb stands behind searching, transport or transhipment.
   - ramb's example sets keep each source's own labels (`Fishing`/`Other`; `hauling`/`shooting`/`steaming`).
4. **Observer events, one row each** (D2.2). Each setting or hauling is its own row, with a start, an end and the number
   of the event it is linked to. ramb's records are one row per station, with t1-t4. Nothing pairs a setting with its
   hauling into one record or keeps the unpaired ones.
5. **Gear size as recorded** (D2.2). For static gear: net panels and panel width, pots and their spacing, hooks, and
   bait. For active gear: the number of trawls or dredges towed at once, and their openings. `rb_predict_gear_width`
   covers the width of towed gear only (BENTHIS).
6. **Soak as fishing time** (D2.1 §2.1).
   - D2.1 separates the vessel's effort (days at sea, engine power) from the gear's (soak time, net length, hooks).
   - It cites Implementing Regulation (EU) 2025/2196. In it, fishing time covers setting, soaking, hauling and removing
     the catch, and each set and haul position of static gear is reported (phased in to 2030).
   - `rb_add_effort` gives each fix the time it stands for. The time the gear soaks while the vessel is elsewhere cannot
     be a sum over the vessel's fixes, and static-gear pressure (quantity × soak) is not built.
   - Neither this regulation nor the tracking rule of Control Regulation (EU) 2023/2842 (D1.1 §1.1) was cited in
     fishycode before.
7. **A summary of each dataset** (D2.1 §2.1, after Rufino et al. 2023 Table 1).
   - It asks for: vessels, valid and invalid trips, the most fishing events in a trip, length overall and engine power,
     and the distance and duration of trips.
   - `rb_summarise_track` gives pings, time span, speed, step distance and duration, voyages and ports. It has no vessel
     attributes, no event counts and no trip validity.
   - D2.1 does not say what makes a trip valid.
8. **Course and depth limits, and gaps reported** (D1.1 §8.1). ramb tests positions (`rb_flag_ping_invalid`) and speed
   (`rb_flag_ping_impossible`) but not course or depth. A gap longer than `max_gap_h` only restarts the speed scan; it is
   never reported.
9. **Maps safe to publish** (D1.1 §3.1.4, §6.1, §7.1). Only aggregated maps that cannot identify a vessel go public.
   ramb's grids (`rb_bin_midpoint`) neither count the vessels in a cell nor mask a cell with too few. fishycode applies
   ICES's three-vessel rule in `products/ices_vms_datacall/build.R` only.

The deliverables also ask for seven wishes already in the list, and those rows now cite them as well: duplicates, land
and speed checks; days at sea; static-gear size and pressure; sets, hauls and soak; grids; scoring against observers;
and anonymising tracks.

## Inconsistencies in the deliverables

- **Gear codes.** D2.1 names ICES's gear vocabulary (vocab.ices.dk, ref 1653); D1.1 §3.1.1.2 names FAO's ISSCFG.
- **The processed table's key.** The key is vessel, time, latitude and longitude (D2.1 §2.1), so two fixes at one time
  with different positions are both kept. fishycode flags exact time ties.

## Not done

- Nothing has been built in ramb, and no `TODO.md` item has been opened. What to build, and whether before the
  November hackathon, is the maintainer's choice.
