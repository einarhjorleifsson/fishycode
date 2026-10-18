# 137 — The vessel overview runs on the laptop, from `products/`, and shows names but no kennitala (plan 030's asks)

*2026-10-18. The maintainer's answers to plan 030's seven asks, each the proposed option; written by Claude
(AI-assisted). Nothing was built.*

## Decided

| ask | answer |
|---|---|
| a. where the app runs | **the laptop first**: the R service on 127.0.0.1, with the browser on the same machine. A server can come later |
| b. the whole photo set | **the maintainer looks for it**: where the scrape ran (the Shiny server's home, `/home/haf/einarhj`), `~/stasi/skipaskra/jpg/`, or the Trash copy. The index is built now on the 1,000 files, with the rest listed as `missing` |
| c. the basemap | **the Mapbox token in `.Renviron`**, which is not the token revoked on 2026-10-16. The browser receives it; restricting it to the app's URL is optional |
| d. where the code lives | **`products/vessel_overview/`** in fishycode: `server.R` and a `www/` page, the repo's first JavaScript |
| e. owner and operator names | **shown**, as the register prints them. Kennitala, addresses, phone numbers and web pages are never served |
| f. the 2022 scrape scripts in `raw/external/skipaskra/R/` | **kept as the record** of the files they made, read-only. `dump/vessels/mbl.R` replaces them and is the only one ever run; no verbatim copy goes into git (plan 030 §2) |
| g. the register panel before plan 028 step 6 | **today and the history**: `vessel.parquet` for today and the history to 2023-12-19, each labelled with its date |

**Amended 2026-10-18 — ask h**, put after a prototype measured both ways (plan 030 §4.1): **both**. The R service
chooses and serves the vessel's rows, with its fixed endpoints and column allowlist (17 KB to 1.7 MB a vessel-year).
DuckDB-WASM in the page reads them, and can run its own SQL on them with no further request. DuckDB-WASM does not
read the trail files itself: that fetched 31.6-119 MB a vessel-year, and httpuv's static server serves no byte
ranges. The maintainer's words: "Ask h: both. The R service serves the vessel's rows with its column allowlist, and
DuckDB-WASM in the page reads them."

## What it changes

- Plan 030's steps 1-4 can be built. Step 5 waits on ask b: the whole photo set found, or a new scrape asked for.
- Building step 1 (the `mbl_photo` target) needs the maintainer's go, like every build. Steps 2-4 build no target.
- The asks were put by Claude with a recommended option first. The maintainer took each recommendation.
