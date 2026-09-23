# 004 — Fishing windows from what the vessel did, not what the skipper wrote

**status:** proposal — nothing built · **2026-09-23** · **see:** `TODO.md` item 18,
`curate/logbook_sensor_gps.R`, `curate/corrections/logger_runs_past_the_station.yml`,
`curate/decisions/010-time-variable-naming.md`

**Measured** — on 2026-09-23, against the 2013 partition of
`curated/logbook/sensor_gps` (58,085 stations, 3,653,458 fixes) and
`curated/logbook/fishing_sample.parquet`:

- which of `t1`..`t4` each gear fills, and how many stations fill none;
- the logger's own span per station against the gear-appropriate window;
- that the over-run is one-sided.

**Assumed** — everything about the classifier: that speed and heading separate
fishing from steaming well enough to place a window, that the transitions are sharp
enough to time, and that the result is worth more than the recorded times. None of
it has been tried. §5 lists the measurements that would decide it, and they come
before any building.

**The principle this plan is written under**, in the maintainer's words, 2026-09-23:
*keep model separate from measurements as far upstream as possible.* Nothing here
proposes to alter a measured table.

## 1. The opening the measurements leave

The logbook's event times are gear-shaped and sparse. On the 2013 logger stations:

| gear | slots filled | stations |
|---|---|---|
| OTB bottom trawl | `.23.` | 38,419 |
| OTM midwater trawl | `.23.` | 5,215 |
| LLS longline | `1..4` | 4,073 |
| GNS gillnet | `1..4` | 1,022 |
| **SDN Danish seine** | **none** | **6,058** |
| **PS purse seine** | **none** | **1,278** |
| LHM handline | `...4` | 93 |

Towed gear fills the inner pair, passive gear the outer pair — one schema, filled by
gear, exactly as `decisions/010` says. But **7,336 stations in one year record no
fishing time at all**, and the maintainer's assessment of the ones that do is that
they are "only vaguely right". `curate/corrections/station_time_whole_day.yml`
already documents stations handed a synthesised 00:00–23:59 window in place of the
missing times.

So for a seventh of the logger's stations there is nothing to improve on — there is
simply nothing there.

## 2. What the logger independently knows

`curated/logbook/sensor_gps` carries, per fix: `time`, `speed`, `heading`, and the
station `.sid`. The DDMMmm fault is confined to `lon`/`lat`
(`curate/corrections/afli_coords.yml`); **time, speed and heading are sound**.

Three independences make this usable, and they are the whole argument:

1. **Speed and heading are measured aboard.** They are not derived from the AIS
   track, from the vid match, or from anything this pipeline computes.
2. **`vid` reaches a logger fix through the logbook** — `.sid → .tid → vid` at
   `logbook_sensor_gps.R:43` — not through `vessel_ais_key`. So it does not inherit
   the misassignment class of `curate/corrections/ais_key_callsign_reuse.yml`.
3. **A classifier on speed and heading needs no position.** It therefore never
   touches the interpolated `lon`/`lat`, which *are* derived from the AIS track —
   and that is what removes the circularity the union's own note at
   `ais_ping_union.R:126` objects to.

Consequence worth stating plainly: such a classifier would run on **100 %** of logger
fixes, not the ~99.7 % that could be positioned — including the 0.3–4.7 % falling
outside any voyage, and 2007, where 97.9 % of fixes could not be positioned at all.

## 3. What is proposed

A **station-level** table: for each `.sid`, a fishing window inferred from the
logger's own speed and heading series, carrying `basis = "reconstructed"` beside the
logbook's `"recorded"`, and a confidence.

Not a position table. Not a merge. The output is a *time window per station*, so it
belongs beside the station, not among the pings.

**`curated/ais/ping` is not touched.** The union's contract is measured positions
with `provider` naming the instrument that saw the vessel; a reconstructed window is
neither a position nor a provider. Keeping it out is the upstream separation the
maintainer asked for, applied at the only place it can be applied.

## 4. What this replaces in the earlier argument

Two objections raised on 2026-09-23 against merging the logger into the union, both
**withdrawn**, recorded so they are not raised again:

- *"Merging inflates density statistics."* Wrong. Effort downstream is estimated from
  the **step** between pings, not from ping counts, so inserting a point splits a
  10-minute step into 5 + 5 and the total is preserved. Spatial allocation is
  unchanged too, since interpolated points lie on the same chord.
- *"The resolution gain is illusory."* True of the *positions* — they are
  `approx()` output along the AIS track and carry no positional information — but
  beside the point. The gain was never positional. It is that speed and heading are
  independent measurements, which is a different asset entirely.

What survives from that discussion is only the third objection: a reconstructed
quantity does not belong in a table whose contract is measurement.

## 5. What to measure before building anything

In this order, each cheap, and any of them can kill it:

1. **Does speed separate?** Distribution of logger speed inside the recorded window
   (`t2..t3`) against outside it, on the 43,634 towed stations. Heavy overlap means
   no classifier.
2. **Does heading separate?** Cog variance during a tow against during steaming.
3. **How sharp are the transitions?** A window needs edges, not just a state.
4. **Where both exist, how far apart are they?** The behavioural window against the
   recorded one. This is the validation, and it also puts a number on "vaguely right".
5. **The seines.** 7,336 stations with no recorded time. If the classifier works
   there it is supplying something that does not exist rather than second-guessing
   something that does — the easiest case to justify and probably the most valuable.

## 6. Two things to get right from the first day

**Carry basis and confidence from the start.** `vessel_ais_key` is this repo's
standing lesson: a fitted model that reads like a registry, whose `AGENTS.md`
description claimed a confidence column it has never had. Whatever this produces
should declare what it is before anyone depends on it.

**It interacts with an open correction.** `logger_runs_past_the_station.yml` measures
that the logger over-runs the recorded window on 39.8 % of stations and *under*-covers
it for passive gear (7.5 h of logger inside a 16.5 h set-to-haul window, because the
vessel leaves the gear soaking and returns). A behavioural window would settle which
of the two is wrong in each case, which is the repair that correction currently lacks.

## 7. Not proposed

Dead reckoning from speed and heading to reconstruct the path between AIS fixes. It
was raised on 2026-09-23 as a way to recover turns that linear interpolation erases,
and it may be worth doing for swept-area work — but it produces *positions*, which is
a heavier claim needing its own validation (the closing-error test against the next
known AIS fix). It is a separate plan if anyone wants it, not part of this one.
