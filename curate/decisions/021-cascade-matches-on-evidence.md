# 021 — The cascade matches on evidence now, not a pasted label

*2026-09-23. The last unbuilt piece of step 5, `curate/plans/003-stk-vessel-identity.md`
§4.1 and §5 step 5. Every number is measured against the rebuilt
`vessel_ais_key.parquet` and its two check tables.*

## What was built

`reference/vessels/ais_key.R`'s classification block — the one that built a `type`
string like `"vid_cs"` by pasting together `.loid`/`.glid` labels, which decision 013
found could not be corrected piecemeal because the cascade below matched that string
as a literal — is gone. In its place, `R/vid_match.R` gives the cascade three
operations, all against `vessel_identity` (decision 015) instead of `vessel.parquet`'s
one-row-per-vid current value:

- `match_time_aware()` — a bare field (a call sign, a uid, an mmsi) against the
  identity table, keeping only a mobile-id whose own `[d1,d2]` window overlaps
  exactly one vid's period. More than one candidate is left unmatched.
- `confirm_vid()` — one field already states the vid outright (`loid` parses to a
  registered vid); the other field must belong to *that* vid's own period, still
  time-overlapping.
- `match_identity_pair()` — two fields (uid and cs) must resolve to the same period
  at once, not two single-field matches that happen to agree.

Every tier of the old cascade (`vid_vid`, `vid_cs`, `uid_cs`, `NA_vid`, `NA_cs`,
`vid2_cs`, `vid2_vid2`, `older`, `NA_mmsi`) is rebuilt on these three, in the same
order. `loid_cs` and `afmadur` were already evidence-based (decision 013) and are
untouched. `CS`, `CS2`, `CS3`, `UID`, `UID2` and the five override vectors the old
classification block pulled out of `stk_overrides` are gone — nothing reads them
now that nothing builds `type` from them.

**A second bug, found while wiring this up:** `.rid` is not a unique row key past
`stk1` — the manual duals join can split one mobile-id into several period rows
sharing one `.rid` (the `afmadur` section already knew this, in a comment). Joining
match results back on `.rid` would have silently merged those rows' evidence. The
matching section uses its own `dplyr::row_number()` key instead.

## What it actually fixed, measured against the previous build

301,540,525 total pings (the `pings` column, unchanged mechanic, still double-counts
multi-period mids per plan 003 §2). Assigned rows 3,168 → 3,170, distinct vids
3,028 → 3,038, pings-with-a-vid 192,636,683 → 192,745,033 (+108,350). Small net
movement, because most of the cascade's tiers were already unambiguous; the
structural difference is *which* rows moved, not how many.

**TFAJ (mid 101779)**: `loid` states vid 2593, `glid` is `TFAJ`. `vessel.parquet`
lists `TFAJ` for two vids (1567, struck 2001; 2842 ÓLI Á STAÐ, 2017–2021 and still
landing 17,128 times through 2026-04-14) and not for 2593 at all. The old flat
`vid_cs` join failed on 2593 and fell through to `vid2_cs`'s `yh2 > 2013` heuristic,
which landed on 2842 — right, but not because anything checked the mobile-id's own
window against it. The new `confirm_vid` step checks `loid`'s stated 2593 first,
finds no period where 2593 held `TFAJ`, and falls through the same way to the
time-aware `NA_cs` tier, which resolves `TFAJ` to 2842 unambiguously because that is
the only vid whose identity period carries it. Same for `TFFS` (100290 → 1359),
`TFNF`, `TFIA`, `TFNG`, `1840` — six mobile-ids, 440,863 pings, all now landing on
the vid whose registered period actually covers the mobile-id's transmissions
rather than whichever vid the flat lookup preferred.

**`TFJI` (mid 102561, loid `SF055`) newly matched**, 275,140 pings — the largest
single change. `SF055` is not a call sign the old cascade's uid/cs sets recognised
at all; time-aware `NA_cs` on `TFJI` resolves to 2895 VIÐEY, which the check layer
had been reporting as an unmatched ghost (see below).

## What it surfaced instead of fixing

Two large mobile-ids **lost** their assignment, and the check layer already had a
name for what happened to them before this build, in decision 020's terms: a call
sign whose *current* holder, per landings, has no AIS identity.

- **`TFUT` (mid 133558)**: 253,112 pings. `vessel.parquet` shows `TFUT` on two hulls
  (963, 2173), both struck by 1995 — before the STK era starts. `vessel_identity`
  correctly carries no period for either, because neither was ever alive under this
  call sign after 2007-06-01. The old flat `NA_csts` step ignored that and stamped
  vid 2173 across the whole 2019–2028 window anyway. The real modern user of `TFUT`
  is landings-only evidence: vid 2173's own name in the registry (TÓMAS
  ÞORVALDSSON), 2,318 landings through 2026-04-07 — this mobile-id almost certainly
  belongs to it too, but nothing in the AIS-side registry says so, and guessing from
  landings would close the cycle `AGENTS.md` forbids.
- **`TFPH` (mid 101439, `loid` = 2227)**: `loid` states vid 2227, and `confirm_vid`
  correctly finds that 2227 held `TFPH` from 2007 to 2009. It assigns 2227 to the
  mobile-id's **entire** window, 2007–2028, because the mobile-id itself carries one
  `[d1,d2]` span with no sub-period. But `TFPH`'s modern holder, per landings, is
  2904 PÁLL PÁLSSON — 8,692 landings, the last on 2026-04-13, none of them possible
  for 2227 (its registry period ends 2009). This is the case the old flat `vid2_cs`
  step happened to get right, by a heuristic (`yh2 > 2013`) that had nothing to do
  with the mobile-id's own window and would have failed just as easily somewhere
  else.

**This is a real limitation, not a bug left unfixed by oversight.** A single STK
mobile-id is one row with one `[d1,d2]` span; when the same physical device is
reused by a second vessel without STK splitting the period, no amount of
identifier-matching on that one row can recover the split — the evidence needed is
which pings happened when, not which fields the mobile-id carries. Fixing it means
segmenting a mobile-id's own ping history against `vessel_identity`, which is a
different piece of work than this step scoped.

**Nothing here is silent.** Both cases were already visible to
`curate/checks/ais_key_reused_callsign.R`'s `A_ghost` category and
`curate/checks/ais_key_landings.R`'s `landed_but_no_ais` before this build (the
category count is unchanged at 11 — TFAJ and the newly-matched TFJI/2895 case
dropped out, TFPH and TFUT joined). The check layer's job was always to report AIS
vs. landings disagreement for a human to resolve through `overrides/`; this step
changed which cases fall into that category, not whether the category is checked.

## Gate

Not a 0-change gate like steps 1–4 — this step is a reassignment, and the point was
to reassign some rows correctly. Measured instead:

- No row's `entity_class` other than `"vessel"` carries a `vid` (0, same invariant
  as before).
- `check_ais_key_registry.R`'s `outside_vessel_lifetime` dropped from 77 (decision
  015's figure) to 39 — 8 stale-registry, 31 candidate-wrong-match, both down
  roughly proportionally. Fewer lifetime conflicts is the expected effect of fewer
  wrong matches.
- `two_mids_open` dropped from 137 to 129.
- `check_ais_key_reused_callsign.R`'s four categories total 27 both before and
  after; membership changed as described above.
- `check_ais_key_landings.R`'s `landed_but_no_ais` dropped from 253 to 243.
- The one `vid_not_in_registry` row (vid 4616, mid 102423) is a `manuals`-step row
  from the duals spreadsheet itself, present before this change and untouched by
  it — not something this step introduced.

`staging/stk` was already stale after step 5's first half (decision 015); it stays
stale. Nothing downstream has been rebuilt.

## What plan 003 has left

Steps 6–9 (close `d2` from evidence, the tier column, the ASTD identity table, the
`n >= 10` filter) are still open, `needs: maintainer` per `TODO.md` item 17. The
mobile-id-reuse gap this step surfaced (`TFPH`, `TFUT`, and however many more are in
`A_ghost`) is a candidate for step 6's `d2`-closing work to fold in, since both are
about a mobile-id's window covering more than one vid's actual tenure — but that is
the maintainer's call, not decided here.
