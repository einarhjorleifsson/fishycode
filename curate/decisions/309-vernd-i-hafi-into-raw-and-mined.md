# 309 — MFRI's marine-protection folder in raw, mined for place names

*2026-11-09. The maintainer brought a copy of MFRI's server folder `/u4/vernd_i_hafi` (a colleague's working folder on
marine protection: base layers, regulations, habitats) and asked: "put it in a proper place in fishindata. Once done,
mine it. Now particularly interested in placenames and related material." Copied, mined and written by Claude (AI);
no person has checked the counts. Study `$FISHYDATA/archive/2026-11-09-vernd-i-hafi/` (its README has every number
below, by script).*

## What was done

`$FISHYDATA/raw/external/vernd_i_hafi/`, the tree unchanged: 2,144 files, 1.69 GB, copied with `rsync
--ignore-existing` and checked by md5 against the originals, all equal (`_manifest.csv`). The original went to the
macOS Trash (the one-home rule); no repo read its path. `README-provenance.txt` says what each folder holds, with
counts, and where the personal data are (persons' place names, a plotter's marks, a staff path in a column). Nothing
in it was already in `raw/external` but sidecar files. The folder is live on the server; a later copy goes in beside
this one with its own manifest.

## What it holds for place names

- **Regulations with named areas**: 188/2023 (17 closures for vulnerable ecosystems; its 8.A-J equal the coral
  closures of 2005 and 2011), 960/2019 (17 areas named from the text), 961/2019 (12), 814/2026 (the vent field east
  of Grímsey), and Fiskistofa's regulations in force (55 areas with their texts). `uv` (Oracle) ends in 2020 and holds
  960 and 961 without the ground names.
- **Protected and natural areas**: UST's protected areas at sea, NÍ's seal haul-outs, important bird areas and the
  nature register's proposals, all named.
- **Habitat by named ground**: coral polygons of 2016 tagged with 15 ground names, maerl areas, vents, and a study of
  Jökuldjúp (its outline and 48 camera stations' taxa, from Oracle's `hafmynd`, which is not dumped).
- **EMODnet Geology 2025**: ÍSOR's submarine volcanic systems round Iceland, named and outlined, and the slides in the
  fjords.
- **LMÍ's IS 50V of 24.12.2017**: the whole name set, points and lines too; fishycode held only the 2022 polygons.
- **A plotter's TimeZero export of 2025**: a later state of the plotter marks of decision 221 (480 of its 656 objects
  carry a guid of the 2021 export; 165 named objects have a name the staged marks lack). Internal, counts only.

## Found

- The regulation texts write **-dýpi** for five deeps the chart writes -djúp: Jökuldýpi, Lónsdýpi, Hornafjarðardýpi,
  Skeiðarárdýpi, Reynisdýpi (Skaftárdjúpi and Faxadjúpi keep -djúp in the same texts). A current official form, for
  the oldest-ending rule of decision 302.
- **Coral closures named after a deep lie beyond the map's area for it**: seven of 188/2023's (Reynisdjúp, Skaftárdjúp
  1-2, Hornafjarðardjúp 1-2, Lónsdjúp, Papagrunn) have none of their area inside the named area of the örnefni map,
  2-30 km from the map's point for the name, at a median 250-680 m. The regulation's deep reaches down the slope past
  its mouth.
- **Gear closures mostly agree**: 79-100 % of each closure on Sporðagrunn, Sléttugrunn, Digranesflak, Síðugrunn,
  Mýragrunn and Öræfagrunn inside the named area.
- **Jökuldjúp three ways**: 960/2019's "Í Jökuldýpi" (1,205 km², median 225 m) lies 87 % in the map's Jökulbanki and
  none in its Jökuldjúp; the study's outline (7,399 km²) takes the trough's outer half and the shelf edge.
- **Names on no chart read and in no gazetteer held**: Mehlsack (960/2019, a foreign fleet's name in an Icelandic
  regulation), Mardöll and Steinahólsþyrpingin (188/2023), and ÍSOR's Steinahóll, Njörður, Fagurhóll, Grjótahryggur,
  Vesturdjúp and others in EMODnet. Of EMODnet's 86 Icelandic stems, 43 are chart names, 33 within 10 km of the map's
  point.
- **LMÍ 2017 at sea**: 6,573 of its 114,526 features lie outside LMÍ's land (4,965 names, coastal features among them);
  2,999 of the names are in none of 2022's sea names, the chart names or fishycode's name dictionary.
- Defects: the four `virkar_reglugerdir*.shp` of the earlier Fiskistofa download have longitude and latitude swapped;
  three shapefiles are latin1 with no `.cpg`; the coral polygons spell their ground names in ASCII, 17 spellings of 15.

## What this does not do

Nothing is staged and nothing joins the place-name bases (charts and depth model, plan 070): each set is a witness the
maintainer weighs on the map. Staging is a small adapter each in `sources/ornefni/`, the TimeZero export one more entry
in `plotter_mark.R`'s list; not started.
