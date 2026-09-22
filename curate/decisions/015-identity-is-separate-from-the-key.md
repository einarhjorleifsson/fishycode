# 015 — The keel and its names are two tables, and the registry's dates are not evidence

*2026-09-22. Step 5 of `curate/plans/003-stk-vessel-identity.md`, partly built.
Every number is measured against the rebuilt tables.*

## What was built

**`curated/vessel/vessel_identity.parquet`** — `vid, t1, t2, mmsi, cs, uid, vessel,
imo, flag, mclass, source, window_basis, zombie_no`. 5,169 periods. The vid is the
keel; everything else is an attribute of it *at a time*. It asserts, and the
assertion passes, that `(mmsi, time)` resolves to exactly one hull.

**`vessel_ais_key.parquet` gains `lifetime_conflict` and `lifetime_note`** — 81 rows
where the mobile-id is active wholly outside the period the registry recognises the
hull. `mmsi` stays on the key; removing it, as plan §4.1 proposed, would break
`sources/stk/convert.R` and three joins in `ais_ping_union.R` for no gain now that
the time-correct answer is available beside it.

**`curate/ais_ping_union.R` resolves the commercial feeds through identity.** This is
the largest correctness change in the step and it was not in the plan, because the
plan had not noticed the second consumer.

## The bug nobody had looked at

`ais_ping_union.R:45` and `:60` resolved the ASTD and ASTDB feeds — 2.77 bn and 0.90 bn
rows — with:

```r
inner_join(vid |> select(mmsi, vid) |> distinct() |> filter(!is.na(mmsi)))
```

No time dimension at all. The registry reissues **21 MMSIs** from one hull to the
next, and `ais_key.R:650` attaches exactly one vid per MMSI, chosen by
`arrange(mmsi, desc(mmsi_t2), desc(vid)) |> slice(1)` — always the later holder. So
for every one of the 21, **the earlier hull's entire commercial-feed era is
attributed to its successor**: ÁRBAKUR's become KRISTRÚN's, LITLI HAMAR's
become SIGURLAUG's.

It is 21 of 21 — the earlier holder every time, never the later — because
`desc(mmsi_t2)` guarantees it.

**Measured after the rebuild, the recovery is smaller than that framing implies: 8
of the 21 earlier holders gained commercial pings, not 21.** The rest had none to
recover, because `astd` coverage is thin before 2013 and most of these handovers are
earlier than that — ÓLAFUR's era is 2007–08, where there is no commercial feed at
all. The defect was real and structural; the data it was destroying was in eight
cases, not twenty-one. Worth stating, because the mechanism argued for a bigger
number than the evidence supports.

The join is now `by = join_by(mmsi, between(date_time_utc, t1, t2))`.

## Intersection, not preference — the thing that made TFBR visible

`vessel_identity` first took the MMSI window where one existed and fell back to the
hull lifetime. That was wrong. `reference/vessels/mmsi.R:23` writes `2007-06-01` and
`2028-12-24` as **defaults** for every vessel whose MMSI has never been reissued, so
an `mmsi_t1`/`mmsi_t2` pair is usually a placeholder. Preferring it reopened windows
that ought to be shut: vid 1473 HÓLMBERG, struck in 2006, got a window running to
2028 — which is exactly how call sign TFBR went on matching for fifteen years after
the hull was gone.

Both bounds are now applied. `window_basis` says which were available: `both` 2,457,
`unbounded` 2,244, `hull_lifetime` 396, `mmsi_window` 72.

## Flag, do not withdraw — and the reason is measured

The first implementation **withdrew** the 81 conflicting matches, nulling `vid` and
keeping the candidate in `vid_rejected`. Coverage fell from 62.39 % to 62.07 %. Then
the withdrawn rows were checked against landings:

**20 of the 81, carrying 1,392,095 of the 1,833,528 pings, are vessels that were
actively landing fish throughout the window the registry says they did not exist in.**

| vid | vessel | registry says | landings |
|---|---|---|---|
| 2730 | GULLBERG | `yh2` 2013 | 1,880, last 2026-03-10 |
| 3017 | KRISTRÚN | `yh1` = `yh2` = 2021 | 313, 2022-08-08 → 2026-03-05 |
| 2173 | TÓMAS ÞORVALDSSON | `yh2` 1995 | 2,318, 2019-08-07 → 2026-04-07 |
| 3007 | INDRIÐI KRISTINS | `yh1` = `yh2` = 2021 | 5,869, 2022-08-11 → 2026-04-13 |

A vessel that lands 1,880 times up to 2026 existed in 2026. So `yh2` is not recording
when the hull ceased to exist, and withdrawing on the strength of it would have
discarded 1.39 M pings of *correct* assignment. Declared as
`curate/corrections/vessel_registry_stale_lifetime.yml`.

The guard flags instead. Per `AGENTS.md` a correction adds a column and never
overwrites, and the choice between "stale registry" and "wrong match" is a human's,
entering through `overrides/`. `curate/checks/ais_key_registry.R` now reports the
split rather than a count: **21 stale registry, 56 candidate wrong match.**

## TFBR is visible and still not fixable here

With the intersection in place, mid 101759 is flagged: 235,121 pings on a hull with
no registry period during the STK era. But it has **two** lifetime-compatible
alternatives holding TFBR — 2815 DÍSA and 3047 HILDUR — so the registry cannot choose
between them, and choosing on landings would close the cycle. It stays
`curate/corrections/ais_key_callsign_reuse.yml`, now *visible in a check* rather than
only in a yml file, which is the improvement actually available.

## Addendum, same day: `yh2` is a horizon, and it cost 99.9 M rows

Applying the identity window to `ais_ping_union.R` as a plain `between` join came
back **95.5 M astd rows short**. Attributing the loss: 755 hulls, 99,943,759 rows,
and almost every one of them has `yh2 == 2021` — BALDVIN NJÁLSSON 666,258 rows,
EINAR GUÐNASON 383,205, JÓNÍNA BRYNJA 375,618.

**`yh2` never exceeds 2021 anywhere in the registry.** 2,264 of the 4,714 hulls that
carry one carry 2021, and 1,244 of those landed fish after 2022, the most recent on
2026-04-14. It is the horizon of the snapshot that was loaded, not the year a hull
ceased to exist.

Two changes followed. `reference/vessels/identity.R` treats a hull reaching the
registry's own `max(yh2)` as **open**, computed from the data so a later dump moves
it — which drops the key's `lifetime_conflict` from 77 to 53 and the "registry is
stale" subset from 21 to 14. And the MMSI-keyed feeds resolve on `mmsi_t1`/`mmsi_t2`
rather than on the intersected hull window, because the two answer different
questions: the intersection asks whether a hull was registered, the MMSI window asks
who was transmitting under that number. Using the intersection left 2011–2019
belonging to nobody on `251146240`, whose MMSI transferred in 2011 to a hull with
`yh1` 2020.

The identity table now asserts both directions — no MMSI resolving to two hulls at
once, and no MMSI unclaimed between two holders. Both pass.

**The undercount is the lesson.** This defect was first declared at 21 vessels and
1.39 M pings, measured from the 81 rows the key's lifetime flag raised. That flag only
ever sees a mobile-id active *wholly* outside its window, so it structurally cannot
see a vessel transmitting both before and after a 2021 cap — which is all 755 of them.
A check that can only detect the extreme case reports the extreme case and reads like
a total.

## What step 5 did not do

The cascade's own lookups are still flat sets. `CS`, `CS2`, `CS3`, `UID`, `VID`,
`VID2` at `ais_key.R:245–288` are still `pull() |> unique()` with no time, and the
`type` classification is still pure set membership. Making *those* time-aware is the
rewrite plan §4.1 describes, and step 3 established it cannot be done piecemeal —
correcting any classifier renames `type` and unmatches rows in steps that key on the
old string. It needs the cascade restructured so rules match on evidence rather than
on a pasted label, and that is a session of its own.

What is built instead is the guard: a wrong match born of a flat set is now *flagged*
against a time-aware table, even though the set that produced it has not changed.

## Gate

Steps 1–4's invariant still holds. Against the previous build: **0 vids changed, 0
lost, 0 steps changed, 0 mmsi changed.** Coverage is unmoved at 62.43 % vid / 59.77 %
mmsi, which is the point — this step adds columns and fixes a consumer, it does not
reassign.

**`staging/ais/ping_union` is now stale** and so is everything below it. The ASTD and
ASTDB joins changed, and 21 MMSIs will resolve differently. Nothing has been rebuilt;
`tar_make()` will say so.
