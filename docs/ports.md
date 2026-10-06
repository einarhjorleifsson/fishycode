# Harbour positions for WGSFD — instructions for data providers

*Draft, 2026-10-06.*

## Purpose

VMS and AIS analyses need to know where harbours are. Pings inside a harbour are not fishing, and
a fishing trip starts and ends in one. The national experts in the group know their own coast
better than any global port list does. So each country supplies its own harbours in one common
format, and the group merges them into one table.

## What to supply

Supply **every place in your country where a fishing vessel may start or end a trip**, at any time
in the period your VMS/AIS data cover. This includes:

- small landing places;
- sheltered anchorages without a pier;
- harbours that are no longer in use.

Foreign harbours your fleet uses may be included too; give each the `country` where it lies.

## Two formats

Each harbour is supplied either as a point with a radius (CSV) or as a polygon (GeoPackage). A
provider may use both, for example polygons for the large harbours and points for small landing
places. **Each harbour should appear once in the whole delivery;** if a harbour is given both as a
point and as a polygon, the polygon is used.

### A. Point and radius: CSV

- One row per harbour.
- Encoding UTF-8. Comma as the separator, `.` as the decimal mark, one header row, column names
  exactly as listed below. Do not use `;` or a decimal comma, even if your locale defaults to them.
- **The point** is the centre of the water area where fishing vessels lie at berth. It is not the
  town centre, the harbour mouth or the UN/LOCODE coordinate.
- **`radius_m`** is the distance on the ground, in metres, from the point to the furthest quay or
  berth used by fishing vessels. It describes the harbour itself.
- If one circle cannot cover the harbour without also covering a long stretch of coast, use a
  polygon instead. Reykjavík is an example: covering both of its basins takes a 3.5 km circle.
- Points are delivered as CSV only, never in the GeoPackage.

### B. Polygons: GeoPackage

- File format `.gpkg`, one layer named `harbours`, CRS **EPSG:4326**. Polygons only.
- One feature per harbour. A harbour with several basins is a `MULTIPOLYGON`, not several rows
  with the same code.
- The geometry must be valid (no self-intersections), and polygons of different harbours must not
  overlap.
- Attribute columns are the same as for the CSV, without `lon`, `lat` and `radius_m`.

## Variables

| Column | Required | Type | Meaning | Example |
|---|---|---|---|---|
| `country` | yes | text, 2 | ISO 3166-1 alpha-2 code of the country where the harbour lies. Faroe Islands is `FO` and Greenland `GL`, not `DK`. | `IS` |
| `harbour_code` | yes | text | The code your national logbook and landings data use for this harbour, or the institute's own stable harbour id. It must be unique within the country and stay the same across deliveries; a code is never reused for another harbour. If your national data use UN/LOCODE, use it here. If the place has no national code, assign one that cannot be confused with a national code and say so in `comment`. | `73` |
| `harbour_name` | yes | text | Local spelling, UTF-8. | `Ísafjörður` |
| `class` | no | text | What the harbour is now (see the vocabulary below). Leave empty if unsure. | `fishing` |
| `lon` | A only | decimal degrees | WGS84, at least 5 decimals. | `-23.12348` |
| `lat` | A only | decimal degrees | WGS84, at least 5 decimals. | `66.06826` |
| `radius_m` | A only | integer | Ground distance in metres, as defined above. | `730` |
| `data_provider` | yes | text | The supplying institute, as an acronym. Name the contact person in the delivery note, not in the file. | `MFRI` |
| `updated` | no | date | `YYYY-MM-DD`, the date this row last changed. | `2026-10-06` |
| `comment` | no | text | Anything someone merging the files needs to know. | |

### Harbour class

The class is optional. When it is given, use one of these values:

| `class` | Meaning |
|---|---|
| `fishing` | Fish are landed here regularly. |
| `mixed` | Fish are landed regularly, alongside other traffic (cargo, ferry). |
| `commercial` | Cargo, ferry or industrial traffic; fish are not landed regularly. |
| `marina` | Mainly leisure craft. |
| `anchorage` | A place where vessels stop without a berth, such as a sheltered bay. |
| `unknown` | Not known. |

## File names

```
<CC>_harbours_<YYYYMMDD>.csv          points and radius
<CC>_harbours_<YYYYMMDD>.gpkg         polygons, layer "harbours"
```

`<CC>` is the code of the supplying country and the date is the delivery date, e.g.
`IS_harbours_20261006.gpkg`. All of a supplier's harbours go in one file, foreign harbours included.
A new delivery **replaces** the previous one in full; it is not a patch.

## Open questions for the group

1. **Foreign harbours.** When two providers supply the same harbour, for example one in its own
   country and one as a harbour its fleet uses abroad, whose polygon is used?
2. **Class.** Is the vocabulary above enough? Should the class be allowed to change over time
   (one class per period), or is the current class enough?
3. **Radius.** Should the radius be specific to each harbour (proposed), or should the group agree
   on a few size classes?
4. **Period.** Which years must the harbour list cover? The start of the data call period?
5. **Custody.** Where does the merged table live, who maintains it, and under what terms may it be
   reused?
