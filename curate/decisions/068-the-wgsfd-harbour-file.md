# 068 — The WGSFD harbour file, and the Iceland/Faroe names it exposed

*2026-10-06. Spec `docs/ports.md`; export `products/exports/wgsfd_harbours.R` →
`$FISHYDATA/exports/wgsfd/IS_harbours_<YYYYMMDD>.gpkg`; correction `ports_iceland` (third defect).*

## What was chosen

WGSFD's national experts supply their harbours in one format (`docs/ports.md`). Each supplying country sends
one file, which includes any foreign harbours its fleet uses. A harbour is either a polygon (GeoPackage, layer
`harbours`, EPSG:4326) or a point with a ground radius (CSV). The columns are `country`, `harbour_code`,
`harbour_name`, `class`, `data_provider`, `updated` and `comment`, plus `lon`/`lat`/`radius_m` for a point.

- **No UN/LOCODE field** (maintainer). It looks like a shared key, but in practice it is wrong too often:
  - Codes in the existing contributions were wrong: Algeciras `AEALG`, Grenaa `DEDRG`, and Hafnarfjörður
    `ISHFN`, which is Höfn's code.
  - The coordinates are coarse. Only 28 of the 80 Icelandic codes have one. Of the 22 that match a polygon, the
    median lies 0.7 km outside it, and Garðabær's is 437 km away because of a typo in its longitude.
  - Our own `pid` misses an existing UN/LOCODE for 13 Icelandic harbours on a suffix-stripped name match alone,
    and for about 20 including reviewed matches. For example, Ísafjörður is `IS-ISJ` while the UN/LOCODE `ISISA`
    exists, and `IS-MJO` (Mjóeyri) holds the code UN/LOCODE gives Mjóifjörður.
- **Iceland's `harbour_code` is the `pid` for every harbour** (maintainer). It is treated as the Icelandic
  standard, although it is not one. The `hid` covers 91 of the Icelandic harbours and none of the Faroese.
  `docs/ports.md` allows "the institute's own stable harbour id" for this reason.
- **`class` is given only where a person has reviewed it:** Helguvík `commercial` and Hornvík `anchorage`. The
  classes in `harbour_class.R` measure how long vessels stay; the spec asks whether fish are landed.

## What was found

- **Bootstrap names.** Ten names in the bootstrap's place list were wrong:
  - IS-SEL lies on the coast of Skagi but was called Selfoss, which is inland. It also carried Selfoss's landing
    code 9, because the `hid` was matched on the name. It is Selvík (maintainer).
  - FO-HUS at Hósvík was called Husevig, the Danish name of Húsavík on Sandoy.
  - Eight names were misspelled: Hesteyri, Landeyjahöfn, Tvøroyri, Sørvágur, Vestmanna, Velbastaður, Streymnes
    and Klaksvík.
  - Two features are not harbours: IS-NUK ("Í Breiðarfirði") and IS-SVD ("CHECK").

  All of these are corrected in `curate/corrections/ports_iceland.R`, which keeps the originals in
  `port_bootstrap` and `hid_bootstrap`. The set goes from 159 to 157 harbours.
- **A `pid` moves when a name changes,** because `ports_all.R` mints it from the name:
  - FO-HUS → FO-HOS, FO-KLA → FO-KVI, FO-STE → FO-SYN, FO-TVE → FO-TVO, and Selvík is IS-SEV.
  - **IS-SEL used to name Selfoss/Selvík and now names Seltjarnarnes**, which was IS-SET. A code reused for
    another harbour is the failure `pid` exists to prevent.
  - No override, decision, plan or docs page referred to any of the changed codes.

## State

- `ports_iceland` and `ports_all` are rebuilt.
- `staging/aux/ports.{fgb,gpkg}` were written by the port lines of `reference/geo/shapes.R` (with s2 off) rather
  than the `shapes` target, because that target also rebuilds EUSM (over 10 minutes). The result is 10,062
  features: 10,064 minus the two dropped harbours.
- `shapes`, `port` and the AIS harbour targets are outdated. They take the new `pid`s on the next full
  `tar_make()`.

## Not decided

- How to keep a `pid` stable when a harbour is renamed (for example, pinning the `einar` codes), and whether a
  `pid` should take an existing UN/LOCODE.
- The open questions in `docs/ports.md`.
