# 326 — TODO 182 closed: the store rebuilt from `stk_hid_pid` and `afli_sent` down, and the effort grids after it

*2026-11-17. At the maintainer's word ("Ok, we are back - care to proceed"), after the question where the effort files
stood. Built, checked and counted by Claude (AI); no person has checked it. The study, with its scripts, log and
tables: `$FISHYDATA/archive/2026-11-17-todo182-rebuild/` (its README).*

## What was built

The 42 targets outdated by decisions 310, 311, 313 and 314 and by the correction `stk_misdated_2026` (TODO 182), from
`stk_hid_pid` down through the union, and the logbook chain from `afli_sent` down (decision 312 edited its script,
which `targets` cannot see, so it was invalidated by hand after the fingerprints). Left out on purpose:
`ais_catch` and `check_allocation_audit` (decision 261) and the place-name sessions' 17 targets. Built at c2f1362 with
ramb 2026.11.09.4 and DuckDB 1.5.6, under the heavy-job lock, 20:08-23:43 UTC, then both effort grids
(`products/effort_map/grid.R`, plain and `fixes`) by 23:52. Freeing disk for it was decisions 324 and 325.

## What it found

Each decision's effect is the one its scratch test measured:

- **182**: 62,891 of STK's AIS pings, 491 VMS reports and 74 kept arrivals moved back a day, 1,384 labelled
  `misdated_undecided`, exactly as on the scratch store of 2026-11-09. The trail gains 16,459 rows in 2026, most
  likely the moved reports, which the clean no longer drops as jumps (not traced), and `trail_match` 8,962.
- **310**: the union holds 14,802 more pings of 2007-2013, arrivals kept inside their port as fixes; the scratch run
  counted 14,803, and the one ping is not traced. Port calls 1,668,927 → 1,664,438, with 311 and 182 together.
- **312**: only the overlap labels (`.checks`) of `staging/afli_sent/fishing_sample` changed; nothing below them.
- **314**: the GPS logger's fixes of vids 2917, 2173 and 2411 are 268,991 positioned and 5,663 without, as tested;
  on all 408 logger vessels, 21,206,767 positioned and 764,965 without.

Below them: voyages +254, `trip_voyage` −19, `trip_landing` +2, and port and time columns of `trip_reconciled` and v0's
trip table; the logbook's own tables are equal row for row. The effort grids pass `grid.R`'s own check (hours,
kW-hours and fixes equal to the trail's in 731 preset-gear-years).

## The stamps

Other sessions committed four times during the build (plans 074 and 076, `TODO.md` only), so `fd.commit` is one of
five commits, and 405 files written while plan 076's text was uncommitted carry `fd.dirty` true. Nothing committed in
that window is code, so the scripts that ran are c2f1362's; a code edit made and reverted in between is not excluded
by any record. ramb 2026.11.09.4 (09182bc, equal to its `origin/main`) was installed from its tree on 2026-11-10, so
the stamp reads `@none`; its changes since 2026.11.09.2 are in the map viewer only.

## Left

- `~/stasi/scratch-182/`, TODO 182's scratch store: deleted 2026-11-18 at the maintainer's word ("Yes, delete it"),
  its file list in `$FISHYDATA/archive/2026-11-09-stk-outage-misdated/deleted_2026-11-18.csv`.
- `check_sync()` will list the 405 dirty stamps; they stay as written.
