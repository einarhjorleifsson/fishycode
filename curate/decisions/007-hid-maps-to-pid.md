# 007 — the Icelandic `hid` maps to the standard `pid`

*2026-09-21. Decided and implemented in one session. Consolidates TODO items 3e,
3f and 12b, which are deleted from `TODO.md` now they are done and recorded here.*

## The decision

`pid` — the country-port id minted once in `reference/ports/ports_all.R` — is the
standard harbour key across **logbooks, landings and the AIS trail**. For
Icelandic data the local `hid` (Fiskistofa's `hafnarnumer`) is **mapped** to it.

`hid` is kept beside `pid`, never replaced, per the rule that a correction adds
columns. `curated/reference/port.parquet` is the crosswalk; the geometry lives in
`curated/reference/port_geometry.parquet`.

## Result

| table | columns | coverage |
|---|---|---|
| `curated/landing/landings.parquet` | `hid`, `höfn`, `pid` | 938,345 of 942,984 — 99.5% |
| `curated/logbook/trip.parquet` | `hid1`/`hid2`, `pid1`/`pid2`, `port` | `pid2` 1,764,829 of 1,778,986 — 99.2%; `pid1` 110,959, all of the populated `hid1` |
| AIS `ping_tagged` | `pid`, `hid` | already carried it, via `ports.fgb` |

Trip row count unchanged at 1,815,425 — the joins added no duplicates.

## Three ways this nearly went wrong, all of the same shape

Each was a **code ceasing to exist because something it does not depend on was
absent**. They are recorded together because the pattern will recur wherever a
code and a geometry are conflated (item 3c).

1. **The crosswalk was built from the geometry.** Removing Hellissandur (41) and
   Hnífsdalur (71) as non-harbours took `port.parquet` from 143 rows to 141 and
   stranded **5,235 logbook trips** whose code resolved to nothing. `kvoti.stadur`
   is the code authority and kaenugardr only ever supplied geometry, so the
   crosswalk now joins `ports_kvoti.parquet` and a code resolves whether or not a
   polygon exists.

2. **Two things were called `pid`.** The bootstrap artifact carried its own codes
   (Hellnar = `IS-HLL`) and `ports_all.R` reassigns globally (`IS-HEN`).
   `harbour_codes.R` read the former, so **59 of 129 pids existed nowhere** and
   joined to nothing, silently — 46% of Icelandic harbour codes unable to reach
   the port database, in the exact route this decision establishes. Fixed by
   sourcing `pid` from the consolidated table, and then by **removing the rival
   namespace** rather than agreeing not to read it: the correction renames the
   column to `pid_bootstrap` and asserts no `pid` survives. Telling people not to
   read a column is a convention, and a convention is what failed here.

3. **`drop_na()` was unscoped.** All three adapter lookups used a bare
   `drop_na()`. Once `pid` joined the selection, that would have discarded the 21
   codes with no pid — the sentinels `0` and `999` and the eight country
   placeholders — *along with their names*. Each is now `drop_na(hid, port)`.

## What the remaining ~0.5% is, and why it is not a mapping gap

The codes without a `pid` are not harbours: `0` (5,861 trips) and `999` are
sentinels, `300 Flutningaskip` is a vessel type, `150 Ýmsir staðir` is a
catch-all, and eight are whole countries — `Noregur`, `Danmörk`, `Skotland` and
so on. They need a **type**, not a port identity. That is item 3c, still open,
and it is the reason a plain `hid ↔ pid` join would be wrong.
