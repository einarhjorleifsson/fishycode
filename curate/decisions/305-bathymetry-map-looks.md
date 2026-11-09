# 305 — The bathymetry map's looks: quiet by default, seven to pick, the ports a reference layer

*2026-11-09. At the maintainer's word: "On contours, colours and "texture" ... Care to give the above some thought";
"Quiet depth palette"; "Yes, make default"; "can we actually have some other options - i kind of like "seabed guess,
fading with depth""; "Ergo the user can select between certain limited preset options"; "Let's say 5 base options,
which you now have to design laboriously"; "The three options already on the map are nice - so 2 (could make it 3)
more options to go"; "Yes, fix quiet"; "I wanted a sixth look - suggest that one is quite daring"; "possibly based on
the widest hypso in tidyterra - make that actually two daring ones"; "or some other than hypso that is available in
tidyterra"; "if we should put the harbours as an additional reference layer". Designed, coded, measured and checked by
Claude (AI); no person has checked the measures. The study: `$FISHYDATA/archive/2026-11-09-seabed-colour/` (its
README, step by step; scripts 01-05).*

## Why

The maintainer liked the bathymetry map with the depth's colour at 0 %, the relief and the contours alone, "really
revealing at a lot of levels", and asked how colour could carry more: depth, or the seabed's material (mud, sand,
rough ground, kelp, seaweed), and texture for rough ground.

## What was found

- **The depth grid is no witness of the seabed's material.** On the 4,287 bottom marks of the current sea charts
  (decision 301), the 50 m grid's roughness (VRM over 250 m) and hollows (BPI over 3 km) hardly part the materials: on
  smooth ground 56 % of mud marks, 50 % of sand, 47 % of stones, 34 % of rock. Depth parts them most (median mud 132 m,
  sand 84 m, rock 38 m). No mark is weed or seagrass, so the charts are no witness of kelp either. Smooth on the grid is
  also where there are no soundings (GEBCO filled in), and the grid's own seams read as texture. A colour for the
  seabed's material is given only where a witness exists; none is drawn from depth or roughness.
- **The map's place names are not the örnefni model.** Its names layer is plan 044's gazetteer
  (`curated/place_name/`, built 2026-11-06 at fc45a24); the örnefni map's names (`archive/2026-11-08-ornefni-map/`) are
  a study's, not adopted.

## What was done

`products/bathymetry_map/bathymetry_map.R` gains palettes of its own, offered as a short list (`bathymetry_palettes()`),
passed to `rb_map(palettes = )`, so ramb is unchanged. Each designed in OKLab and measured: lightness steps, the step
between neighbours under simulated colour-blind vision (Machado et al. 2009), the distance of each end from the base
map's land (Positron's `#FAFAF8` and its landcover's green), and for overlays the distance by hue alone.

- **quiet**, the default, in equal shares: pale cyan-grey to mid grey-blue, lightness 0.935 to 0.586. First made
  from 0.964, its shallow end sat 0.014 from the land and its shallows read as land in Breiðafjörður; fixed, hue and
  chroma kept (now 0.037). On a log scale Faxaflói's 40-75 m took its two darkest steps; in equal shares the bay parts.
- **seabed**: the look of the study's "seabed guess, fading with depth", by depth alone (sand into mud, seen through the
  water), at even lightness 0.84 to 0.40. A look, not a substrate.
- **deep**: ramb's.
- **chart**: the sea's one colour convention, the nautical chart's: shallow blue to deep near white (0.70 to 0.95).
- **grey**: a ground for other layers, chroma under 0.01: by hue alone no overlay colour of five sets comes nearer than
  0.042, against 0.005 to 0.016 for the others.
- **drained** and **haxby**, the two daring ones, from tidyterra 1.3.0 (115 palettes ranked by their path in OKLab):
  drained is `gmt_globe_hypso`, the land palette of the widest span, turned onto the seabed (the deeps its lowland, the
  banks its hills); haxby is GRASS's, marine geology's multibeam palette. 17 stops each at even steps along their path,
  their whitest stops dropped so the shallowest water stays off the land. Both lean on hue (0.023 and 0.024 at the
  smallest step under colour-blind vision).

Left out: **night**, for the dark base map, as the contours are drawn in a fixed dark colour and vanish on it;
wiki-schwarzwald-cont (most stops), whose broad red reads as heat; srtm_plus's sea and land in one, purple in the
shallows. The depth's checkbox off is the relief alone.

**The ports** (`bathymetry_map_build(ports = TRUE)`): the effort map's ports layer, from its `map.json` and
`curated/reference/port_geometry.parquet`, after the place names, off when the page opens; left out where the table is
not there, as in the kit. `products/depth_effort_map/`, which added the same layer itself, no longer does: it lists all
eighteen palettes and opens as before, gn_yl at 52 %.

## What it changes

Every map built on `bathymetry_map_build()` (the bathymetry map, its server, the study maps) opens the depth in quiet,
lists the seven and carries the ports. The exported bundles and the kit (`exports/`) are as they were until rebuilt.
Checked on a trial server (port 8814): the list, links opening each look, a reload restoring the colour settings, the
depth off and on, the ports' checkbox off and its tiles served, no console errors; both maps' configs built in R.

## Open

The palettes belong in ramb's `rb_map_palettes()` when its viewer is next opened; the bundles and the kit rebuilt with
them (TODO 185). A look that sets more than a palette (the scale, the bands, the contours' colour, the base map), which
night and a chart's fixed bands would need, is a ramb viewer change, not asked for.
