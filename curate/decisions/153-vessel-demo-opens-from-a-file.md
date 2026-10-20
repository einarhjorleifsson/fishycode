# 153 — The vessel overview as a demo that opens from a file

*2026-10-20.*

- **Who chose.** The maintainer: a self-contained demo of the vessel overview to send a colleague under a
  confidentiality agreement; the trips with an AIS voyage in June 2018; vessel ids and names anonymised, the rest as it
  is; "platform agnostic", "should not depend on R", "as easy to launch as possible - like no shell command"; and, of
  the three asks put to them, about 30 vessels across the gears, free online tiles, the internet allowed. The rest is
  Claude's and not yet reviewed: the window per vessel, what counts as an identifier, the Esri tiles (below), keeping
  the record ids.
- **Who did the work.** Claude (Anthropic), in one session: the page's bundle mode, the builder, the checks and this
  record.

## Done

- **The page has a bundle mode** (`products/vessel_overview/www/app.js`). A meta tag `bundle` turns it on. Each answer
  then comes from a script beside the page, `data/v<vid>.js`, holding the service's parquet as base64, since a page
  opened as a file may load a script but may not `fetch()`. The register, the photos, the call sign and the MMSI are
  hidden, and the years offered are the bundle's. One page serves both, so there is no second copy (`AGENTS.md`).
- **`answer()` takes `where` and `inner`** (`products/vessel_overview/api.R`), so the builder narrows the service's own
  SQL and column allowlist instead of restating them. The service passes neither; `check.R` passes (79 answers, 10
  refusals, one photo).
- **`products/exports/vessel_demo.R`** writes `$FISHYDATA/exports/vessel_demo_2018-06/` (the page with its script
  inlined, `data/`, a README for the colleague), the same zipped, and the key from the demo's numbers to vids beside
  it, `vessel_demo_2018-06_key.csv`, which never goes with the folder.
  - The vessels: those with a logbook trip on an AIS voyage overlapping the month (the trail's `.tid` on the voyage's
    pings), drawn at random within their main gear (most hauls on those trips): LHM 6, LLS 5, GNS 5, OTB 5, SDN 3,
    OTM 2, PS 2, DRB 2.
  - A vessel's window runs from the start of its first voyage overlapping the month to the end of its last. In it, as
    they are: pings, voyages, port calls, the logbook trips overlapping it or on its pings, their hauls and catch, and
    the landings in it or linked to those trips.
  - Anonymised: the vid becomes 1-30 in random order and the name "Vessel nn". Call sign, MMSI, IMO, register, history
    and photos are left out (empty answers). Ports, positions and the `.tid`, `.sid`, `.lid` ids are kept. The builder
    stops if the list names a vessel, a register answer is not empty, or a vessel's answer may carry a vessel column.
- **A defect found on the way, in both modes:** `tripGaps()` read `S.tr` after `choose()` had cleared it, when the
  previous vessel's chart redrew. Guarded.

## Measured

- **June 2018:** 10,794 voyages overlap the month, of 1,357 vessels. 875 vessels have a logbook trip on one: 6,409
  trips, 2.2 M pings, 49 MB of trail parquet. Their main gear: LHM 595, LLS 92, GNS 81, OTB 61, SDN 26, OTM 11, PS 5,
  DRB 4.
- **The bundle:** 30 vessels, 7.0 MB, 4.9 MB zipped; 163 to 18,417 pings a vessel.
- **Opened as a file** (`file://`), driven headless on macOS: Chrome and Firefox 158 both start DuckDB-WASM from
  jsdelivr and load all 30 vessels in both modes, 12-52 ms each after the data, with no console error.
- **Tiles from a file:** a page opened as a file sends no Referer. CARTO's light tiles then answer "API key required",
  and OpenStreetMap's "Access blocked". Esri's light grey canvas serves without a key: 18 tiles, all 200. The bundle
  draws Esri's, to zoom 16; the service still draws Mapbox's with the token.
- **Three windows run 7-9 months** (vessels 1, 5 and 24): a voyage overlapping June that long, likely a port call
  missed (TODO 90). They are kept as the data are.

## Not settled

- **Safari and Windows are untested** (TODO 96). Edge on Windows is Chromium, as Chrome is.
- **The anonymity is shallow.** A track, its home port and its catch can be matched to public AIS. The folder goes to
  one colleague under an agreement and is never published (plan 001 §3). Plan 001's open question, what may leave
  `fishydata`, is not answered by this.
- **The basis for sending it** under MFRI's data policy (gagnastefna) is the maintainer's to settle (TODO 96).
