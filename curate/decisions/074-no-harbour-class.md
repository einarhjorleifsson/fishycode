# 074 — Harbours carry no class; one minimum stay for every harbour

*2026-10-09. Maintainer's decision; recorded by Claude (AI-assisted). Closes TODO item 33 without building it. The
code change (removing `reference/ports/harbour_class.R` and its target; one minimum stay in `curate/harbour_stay.R`)
is part of TODO 45.*

## Decided

- The harbour class per period goes, and so does a class at all: harbours are a static, upfront input (polygon and
  departure radius), not something the AIS flow derives per year.
- The minimum stay becomes one value for all harbours. Reviewed labels (`overrides/harbour_class.csv`: Hornvík
  `no_pier`, Helguvík `cargo`) may stay as description; they set nothing.

## Why

- **The class did one job:** the minimum stay (`curate/harbour_stay.R:93`: 2 h at a `landing` harbour, 4 h elsewhere).
- **It bought little.** Decision 063 measured a global 2 h minimum over 2007–2026 against the class rule:
  1,540,538 against 1,528,400 stays (+12,138, +0.8 %), the same landing coverage (94.3 / 96.9 % against
  94.3 / 96.8 %; 28,219 against 28,520 landings with no stay).
- **It was the fragile part.** Its thresholds and three-year pooling were marked provisional and never settled;
  32 of the 128 judged harbours changed class between years in the build of decision 073, 23 of them in and out
  of `landing`. And it depended on the vessel key and all of step 0 through `stk_event` → `ping_clean`.
- **The WGSFD flow needs none.** `rb_find_trip_stays()` takes a minimum stay; other countries have no class either.

## Open

Which single minimum (2 h, the decision-063 candidate, or another) is fixed with the TODO 45 build, counted
against decision 073's stays. Hornvík's anchorage stops become stays at 2 h; whether it should be marked
"not a place a trip ends" is counted then.
