# 107 — ASTD 2026-02 to 2026-06 loaded as delivered, the IMO-only gap declared

*2026-10-15. Written by Claude (AI-assisted); the choice is the maintainer's ("load 2026-02 to 2026-06 into staging as
they are, with a correction entry declaring the IMO-only gap"). TODO 64.*

## What was found

The maintainer added five ASTD zips (2026-02 to 2026-06) to `raw/ais/astd/` on 2026-10-15. Each was read in full
before loading. The format matches the earlier months, but the content is a different extraction: every row has an
IMO number. So the months hold 4,900-5,800 MMSIs against 11,700-16,600, and 160-165 Icelandic MMSIs against 400-950.
The numbers, and what the same months of 2025 owed to the vessels now missing, are in
`curate/corrections/astd_2026_imo_only.yml`.

## What was chosen

To load the months as they are, rather than hold them back until the provider sends the extraction used up to
2026-01. The IMO-numbered vessels' fixes are sound, and the gap is reported where analysts read:
- `docs/ais_trail.qmd`, under "Gaps in the feeds";
- `docs/data-dict.yaml`, on `ais_ping`;
- the correction entry, with its detection rule (a month in which every row has an IMO number) and the repair, should
  full months arrive.

No column flags the gap: the missing fixes have no rows to carry one.

## Done

- `dump/ais/astd.R` wrote the five partitions on 2026-10-15 (Written 5, Skipped 155, Failed 0). Their rows and MMSIs
  equal the full read of the raw CSVs, month by month. Through the union's own reader and filter they give
  2.02-2.23 M Icelandic rows on 160-165 MMSIs a month, against 4.22 M on 474 in 2026-01.
- They carry an empty `ship_id` column, which the canonical schema has held since 2023-08 and 2023-09 were loaded;
  `open_dataset()` takes the first file's 40 columns and does not see it.
- `ais_ping_union` tracks no staging file, so it was marked outdated by hand. It was outdated already, by plan 016.

`dump/ais/astd.R` extracts every zip before it checks whether the month is already in staging, so a run that adds
five months decompresses all 160. Moving the check above the extraction is a two-line change, left for a run that
is not in progress.
