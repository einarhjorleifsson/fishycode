# The bathymetry map: open it in your browser

The seabed around Iceland from Olex's 50 m depth grid with GEBCO (Julian Burgos, MFRI), on an interactive map:
the depth in colour, the relief shaded, contours, and the place names of MFRI's gazetteer. The depth's colours, the
contour levels and the shading's intensity can follow the view as you move, or stay as you set them.

**For use inside MFRI only.** The place names include names from Trackwell's hauls and fishermen's plotters, which are
not public. Do not pass the folder, or screenshots of names, outside MFRI.

Prepared with AI assistance (Claude) from fishycode's `products/bathymetry_map/bundle.R` (TODO 185); `VERSION` says
when and from which commits.

## Open it

1. Copy the whole folder to your own computer (or unzip `bathymetry_map_bundle.zip`). It opens from a share too, but
   more slowly.
2. Double-click `index.html`. It opens in your web browser: a recent Chrome, Edge or Firefox.

Nothing to install, no R. The computer needs the internet: the map's program (MapLibre) and the base maps come from
the web; the depth and the names are in the folder.

The menu (☰, top left) holds the layers and their controls; IS | EN switches the language. The address in the
browser's bar keeps the view and the settings: bookmark it, or copy it with the menu's link button, to come back to a
view. A link only works on a computer with the folder at the same place.

## What is in the folder (about 245 MB)

- `index.html` — the map
- `tiles/` — the depth as elevation tiles, to zoom 9 (a pixel about 65 m at 65° N)
- `data/` — the place names
- `VERSION` — when and from what it was made

## How it differs from the map run from R

- **The depth to zoom 9.** Zoomed in further, the map draws zoom 9's tiles larger: a little softer than the grid's
  50 m, and the contours follow them.
- **No "depth by cell".** That layer is drawn by a server from the full depth grid.
- **The "from the view" fits** (the depth's floor and cap, the contour levels, the shading's intensity) are worked out
  in the browser from the tiles in view, by the same rules, so their values can differ slightly from the server's.
