# Depth unit is metres

*Decided by the maintainer 2026-09-23. Settles the gate on TODO items 1 and 1b.*

## The decision

`z1`/`z2` are declared in **metres**, product-wide, in every merged and curated
table. `docs/output-schema.md:88` (afli's own schema table) is amended to say so —
previously it declared `z1`/`z2` with no unit, which is why neither
[`adb_vs_fs_afladagbok`](../corrections/adb_vs_fs_afladagbok.yml) nor
[`afli_depth_units`](../corrections/afli_depth_units.yml) could be called wrong
before this.

Consequence for the two correction files: `adb` already records metres
(GEBCO-verified, `adb_vs_fs_afladagbok.yml` defect 1) and needs no conversion.
`fs_afladagbok` and `afli` record fathoms outside the drift window and need
converting; inside the 2010–2012 drift window, `afli` rows already in metres are
left alone and rows still in fathoms are converted. The `repair` line in
`adb_vs_fs_afladagbok.yml` that floated dividing `adb` by 1.8288 is superseded —
that would have picked the wrong side.

## Any correction to a reported depth must carry a basis column

This is not a new rule — it is [`AGENTS.md`](../../AGENTS.md)'s existing
"every inferred value carries a `basis`" invariant, applied here because depth is
the first place in the product where a reported number is being changed rather
than just annotated. Per the project's **never destroy the original** rule, the
converted column does not overwrite: it sits beside the original, exactly as
wacky-coordinate recovery keeps `w_lon`/`w_lat` beside corrected `lon`/`lat`.

Concretely, for `z1`/`z2`: keep the source value unconverted as `z1_raw`/`z2_raw`,
and add `z1_basis`/`z2_basis` with values `"recorded"` (already metres, untouched)
or `"reconstructed"` (converted, or — inside the `afli` drift window —
vessel-period-classified and then converted). No `"synthesised"` case here; nothing
is being filled in from a model, only re-expressed in a different unit.

This binds both repairs, not just `afli`'s: any station whose `z1`/`z2` differs
from `z1_raw`/`z2_raw` must show `z1_basis` (or `z2_basis`) as `"reconstructed"`,
and a bean count of `basis == "reconstructed"` by year/source is how each repair's
own **check** should be written — not an average ratio, which is exactly the
mistake `afli_depth_units.yml`'s `false_start` already recorded once.

## Pelagic gear is out of scope for the GEBCO cross-check

Flagged by the maintainer 2026-09-23, after the method above was already in use:
the GEBCO ratio test assumes `z1` is a bottom/seabed depth, comparable to the
raster cell it is indexed to. That holds for demersal and static gear, but a
pelagic gear (trawl or purse seine fishing in midwater) may report the *fishing*
depth — where the net or seine actually sits in the water column — which need not
be anywhere near the seabed, independent of what unit it is recorded in. A
correct-unit pelagic record can produce a GEBCO ratio far from both 1.0 and
1.8288, and would be misread as noise or, worse, as evidence for a unit it is not
in.

This project already carries the gid split needed to exclude these stations:
`curate/link_lid_map.R` derives `pelagic_gids` from `reference/gear.parquet`
(gids 7, 8, 9, 10, 12, 13, 19, 21, 24 — see `docs/project-review.qmd:167`) rather
than joining on gear name. Both depth-unit repairs must filter to
`!(gid %in% pelagic_gids)` before computing any GEBCO ratio, at every stage —
baseline, anomaly detection, and the per-vessel-period classification in
`afli_depth_units.yml`. Pelagic stations are not thereby assumed correct; they
are simply not classifiable by this method, and ship with `z1_basis` /
`z2_basis` = `"recorded"` (unconverted) until a different check exists for them.
`afli_depth_units.yml`'s existing measurements should be rechecked once this
filter is applied — the vessel population counts (65 / 157 / 46 of 268) were
computed without it and may shift.

## What this does not decide

Not the `afli` switch-date estimation itself (still per `(vid, period)`, still
GEBCO-based, still row-level classification forbidden — see
`afli_depth_units.yml`), not a check for pelagic-gear depth itself, and not
`adb_vs_fs_afladagbok`'s longitude-sign defect, which is unrelated and still
open.

## Implemented and rebuilt, 2026-09-23

`curate/corrections/afli_depth_units.R` (per-vessel switch-date fit) and a flat
conversion for `fs_afladagbok` in `curate/logbook.R` both ran via
`targets::tar_make(names = c("afli_depth_units", "logbook"))`.
`curated/logbook/station.parquet` now has `z1`/`z2` in metres product-wide for
both sources, with `z1_raw`/`z2_raw`/`z1_basis`/`z2_basis` on every row (0 rows
with one set and not the other). adb is still not wired in (TODO item 1,
longitude sign).

Validated by rerunning this decision's own GEBCO check on the rebuilt table,
non-pelagic/deep/in-box afli stations only: median `gebco_depth / z1` sits at
1.01–1.03 every year from 1990 to 2023 (was ~1.83–1.90 before conversion,
confirming the fathom rows actually convert) — a 2% spread, well inside the
5% the check asks for. 2024 alone reads 0.34, but on 13 rows total; afli's own
coverage is tailing off there as fs_afladagbok/adb take over, not a defect.
