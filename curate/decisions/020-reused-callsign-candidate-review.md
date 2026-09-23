# 020 — reused-callsign candidates: 3 fixed, 28 reviewed and parked

*2026-09-23. Follows from `curate/checks/ais_key_reused_callsign.R` (decision 019's
check-layer pattern) and closes the loop the maintainer opened by asking for a check
of "obvious" vessel ids missing from AIS. Read this alongside
`curate/corrections/ais_key_callsign_reuse.yml`, which carries the confirmed defect
and the fix; this record carries the method and the candidates that did **not** get
fixed, so a later reviewer does not have to re-derive them from a chat transcript.*

## What got fixed

Three vids were missing from `vessel_ais_key.parquet` with a call sign that has a
real, dateable STK mobile id behind it. All three are now in
`raw/ais/stk/stk_mobile_match-and-duals.ods` (rows tagged `basis: reconstructed`,
distinct from the human-reviewed `basis: recorded` rows) and confirmed closed by
rebuilding `vessel_ais_key` and `curated/check/ais_key_landings.parquet`:

| vid | vessel | mid | window given | evidence |
|---|---|---|---|---|
| 3047 | HILDUR | 101759 | 2025-01-01 → open | 163/163 landing dates match the AIS-derived harbour exactly. Extends the already-documented `ais_key_callsign_reuse.yml` case; the pre-2025 portion (currently 1473) is untouched and still unresolved. |
| 2605 | ÓLAFUR | 104075 | 2007-06-01 → 2011-05-10 | 69/70 landing dates match; distinctive because the destination vessel (2640) was Grindavík-based at the time, not Hafnarfjörður |
| 3045 | ÞÓRUNN ÞÓRÐARDÓTTIR | 101081 | 2025-01-01 → open | 43-month AIS silence (2023-06 → 2025-02-27) then a new speed/idle regime; 6/7 landing dates match the derived harbour. Extends an existing 3-row human dual on the same mid rather than replacing it. |

## The method, and where it went wrong before it went right

The obvious approach — take a vid, find a mobile id sharing its call sign, check
whether the mid's ping window covers the vid's landing window — has two traps, both
hit during this review:

1. **"Destination has zero landings" is not evidence of anything.** Plenty of
   correctly-matched vids never land a fish — service vessels, pleasure craft,
   retired fishing boats still tracked. Two early "confirmed" cases (1265 HAUKUR →
   2787 ANDREA, 1369 NORMA MARY → 2848 AMBASSADOR) were reversed on this basis alone:
   both destination vids show a continuous, unbroken AIS signature for 12-16 years
   with no discontinuity anywhere near the source vid's landing dates.
2. **A call-sign match can find a candidate whose *own* vid is not actually missing
   from the key at all** — it may already have a separate, correctly-matched mid
   via a different route (`vid_vid`, matching the mobile id's raw `loid`/`glid`
   against the vid number itself, which the callsign search never looks at). 13 of
   the vids investigated below were false positives of exactly this kind: real
   effort went into deciding *which* vessel a shared-callsign mid belonged to, when
   the vid on the losing side of that question already had its own, unrelated,
   correct AIS coverage and was never actually in question. The check that would
   have caught this immediately: `vid %in% (vessel_ais_key |> filter(!is.na(vid)) |>
   distinct(vid) |> pull(vid))`, run **before** any pattern analysis, not after.

Once vid-in-key membership is checked first, the remaining, genuinely open
candidates get tested on record-level evidence, not aggregates:

- **Speed/idle regime continuity**, monthly, looking for a real silence gap or
  behavioural break at the candidate's own landing-window boundary — not a
  same-quarter coincidence.
- **Landing-date-by-landing-date harbour matching**: for each of a candidate's own
  landing dates, does the mid's *derived* harbour (a spatial join of its raw
  lon/lat against the port polygons, done per mid — independent of any vid
  assignment, so it cannot be circular with the thing being tested) match the
  landing's own recorded `hafnarnumer`? This only has power when the two competing
  vessels have **different** home ports (2605 vs 2640: Hafnarfjörður vs Grindavík —
  informative). When they share one (1369 vs 2848: both Akureyri-based for decades,
  checked against `vessel_identification_hist.parquet`'s `home_port` history), every
  boat working that harbour "matches" regardless of which one the mid really is, and
  the test is uninformative — this reversed a same-session false read on 1369.
- STK's own raw `hid`/`io` columns are **not** used directly: they mix continuous
  AIS position reports with manual harbour-entry/exit radio calls, two sources with
  different reliability. Checked directly (`io == "I"` rows are 97.7% distinct
  positions, not a single repeated reference coordinate) — not circular here, but
  the raw field is still avoided in favour of the derived, spatially-joined `hid`.
- A raw `stk.mobile` local-id (`loid`) that is literally a vid number (e.g. mid
  104075's `loid` reads `"2640"`) is the strongest single signal available — the
  transponder's own operator self-declared it — and should be checked before
  anything inferred.

None of this is proof. The premise the whole check rests on — that a single STK
mobile id can be legitimately time-split between two real vessels — is the
maintainer's own hypothesis for how to interpret these cases, not something directly
observable in the data; it is a modelling choice, and every row below is written
with that in mind.

## The 28 not acted on

Kept here, not in `TODO.md` (see item 17 for the pointer), because the reasoning is
too long for a stub and the value is in *why*, for whoever reopens this.

**Already correctly covered — never actually missing (13).** Each has its own
separate, legitimate mid in `vessel_ais_key` that the call-sign search never found
because it wasn't looking for it. No action possible or needed.

| vid | vessel | its own real mid | via |
|---|---|---|---|
| 2895 | VIÐEY | 115002 | `vid_vid`, since 2014-10-02 |
| 3010 | BJÖRN | 145885 | `vid_vid`, since 2022-09-15 |
| 3038 | MARGRÉT | 146524 | `vid_vid`, since 2023-03-08 |
| 3060 | HEIMAEY | 151813 | `NA_mmsi`, since 2025-05-22 |
| 2842 | ÓLI Á STAÐ | 126282 / 127833 | `NA_mmsi` / `vid_vid`, since 2017 |
| 971 | FRAM | 101223 | `vid_vid`, 2007-06-01..2011-09-01 (bounded, already reviewed) |
| 2110 | JÚLÍA | 100822 | `vid_vid`, since 2007-06-07 |
| 2799 | HEMMI Á STAÐ | 106626 | `vid_vid`, since 2010-03-08 (one day off its own landing start) |
| 2617 | DAGRÚN | 101786 | `vid_cs`, since 2007-06-12 |
| 2640 | FÁLKATINDUR | 104075 | now split with 2605 above; 2640 keeps the later window |
| 1734 | ÓLI ÓLA | 101305 | `vid_vid`, since 2007-06-08 |
| 1131 | BJARNI SÆMUNDSSON | 101143 | `vid_cs`, since 2007-06-01 |
| 1264 | SÆMUNDUR | 146737 | `vid2_vid2`, since 2023-04-24 |

One of these is worth a second look on its own terms, unrelated to AIS: **1131
BJARNI SÆMUNDSSON has zero logbook trips ever** despite 1,438 recorded landings, and
carries an IMO number and a distinct `mclass` (44) that nothing else in this
candidate set has — consistent with it being the Marine Research Institute's survey
vessel, whose landings would be research-trawl catch through the ordinary weighing
system rather than commercial trips. Not chased further here; flagged in case it
matters elsewhere.

**No discontinuity found; reads as landings-side, not an AIS defect (13).** Checked
by monthly speed/idle continuity and, where a matching mid + landing pair existed, by
harbour-date matching. `AGENTS.md`'s own caution applies directly: landings carry
occasional date/vid entry errors, rarer for electronic records — these are treated as
that, not asserted as it.

| vid | vessel | note |
|---|---|---|
| 257 | SIGURVON | 18-year unbroken profile, landing window unremarkable within it |
| 2127 | STAPI | continuous 2019-2026 regime; only 6 landings over 3 years, no distinguishable segment |
| 2233 | JÓNA EÐVALDS | continuous noisy small-boat pattern 2007-2025, single-day landing unremarkable |
| 1651 | SNÆFARI | 19-year clean unbroken profile |
| 1940 | LÓMUR | mostly-idle (>0.7) throughout; does not read as an active fishing vessel at all |
| 2270 | ARNARBORG | continuous 19-year profile, no break |
| 27 | ÁRFARI | single-day landing sits inside a continuous, unrelated operation |
| 1433 | DALA RAFN | the mid has almost no real data at all in the claimed window (3 stray single pings); its real activity is 2024-2026 |
| 1369 | NORMA MARY | see method section above — harbour match was a same-town coincidence with 2848, not a signal |
| 1640 | HRAUNSVÍK | directly contradicted by an existing human-reviewed duals row assigning that date to 2706 |
| 1512 | SKARFUR | directly contradicted by an existing human-reviewed duals row assigning that date to 1576 |
| 1265 | HAUKUR | directly contradicted (existing duals row + 16-year unbroken profile); registry mclass/loa also mismatch the destination vessel |
| 1759 | FJÖLNIR | most of the claimed 2015-2021 window falls inside a 62-month AIS silence |

**Weak or mixed evidence, not acted on (2).**

| vid | vessel | note |
|---|---|---|
| 1484 | GRETA | a thinner version of the gap-then-resume shape (7-month gap ending near the landing start), but sparse coverage during the window itself |
| 1035 | HEIMAEY (old) | 2/2 harbour-date matches, but sits inside an otherwise continuous, unrelated vessel's operation on the speed/idle test — the two signals disagree |

## What this does not settle

`ais_key_callsign_reuse.yml`'s `scope` note on 254 landings-but-no-AIS vessels (of
which 86 are domestic with a usable call sign, of which 30 showed a genuine raw-STK
match before this review, now 27 after the false-positive corrections above) is
still not a closed number — the ~50 domestic candidates with no STK mobile-id match
at all under any identity were not touched here; they read the same as vid 1599:
never reached STK, not a matching defect. The structural fix plan 003 describes
(splitting the key into a time-windowed identity table and an attribute table) is
still not built; every row added here is a patch on top of the same flat, timeless
`cs` lookup that caused the defect, not a fix to it.
