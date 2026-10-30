# 252 — The tour app's port codes are the landing system's place numbers, translated as the landings are: no override

*2026-10-30. Plan 054 ask k, plan 019 §2 item 3, TODO 73. Found by Claude (AI), read-only, and not checked by a person.
It came out of the maintainer's question, put while a voted draft was being reviewed: "why can you not see this from
the positions?". The maintainer's choice: "Yes, no override". The work is in
`$FISHYDATA/archive/2026-10-30-plan054-tour-ports/` (README, `tour_port_pid.R`, `ais_witness.R`). Nothing is built.*

## What this supersedes

Decision 210 item 2: "the port translation is a reviewed override in `overrides/`". Plan 054 ask k had the override
drafted by Claude and reviewed by the maintainer before rebuild A. Neither is needed.

## Found

Plan 019 read the tour app's `landing_port_id` as a code of the app's own, since only 498 of 40,695 matched pairs share
a code with `ws_veidiferd`. It is not the app's own. It is the Directorate's place number, `kvoti.stadur.stad_nr`, which
the landing system uses as `hid`; `ws_veidiferd` holds another code (`hafnarnumer_id`).
- **The code list:** all 75 codes the tour app uses are in `stadur`, with names that fit. For example, 35 is Akranes,
  49 Flatey á Breiðafirði, 0 Höfn vantar (port missing), and 159 Gámur/Sigling (decision 169's disposition).
- **The reference:** `curated/reference/port.parquet` already translates `hid` to a pid for 71 of the 75 codes,
  covering 35,749 of the 35,792 tour trips.
- **The vote agrees where it is clear.** The draft first voted on witnesses: the trip's `ws_veidiferd` copy, the
  vessel's landing that day, and the AIS port call it came into. On all 54 of its clear codes that the landings also
  use, the voted pid equals the landings' own `hid` → pid.
- **The vote is wrong for 9 small codes.** It counted where the boats landed or came in, not what the code means: 5
  Stokkseyri, 7 Eyrarbakki, 15 Hafnir, 19 Garður, 25 Vogar, 31 Kópavogur, 49 Flatey, 64 Alviðruvör and 127 Egilsstaðir.
  For 49, the landings said Stykkishólmur on all 16 votes; the track said Flatey on all 20, as the code does.
- **Four codes have no pid** (43 trips): 0 (port missing), 159 (a disposition, not a port), 102 (Litli Árskógssandur,
  which the reference names with no pid) and 127 (Egilsstaðir, inland).

## Chosen (the maintainer)

- **The tour app's code is read as `hid`** and translated through `curated/reference/port.parquet`, as the landings
  are, with basis `recorded`. There is no override, and no review.
- **The four codes with no pid get none.** A new code is translated by the reference when it appears there.
- **The code is the skipper's declared port.** Where the vessel came in is the track's to say: `trip_reconciled` ranks
  the AIS port call first (decision 174), and a trip with no track takes its port from the code or its landing. The two
  can differ. Code 85 is Blönduós, while most of its trips came into Akranes by the track
  (`ais_votes.csv`).
