# Depth and fishing effort: open it in your browser

The seabed around Iceland from Olex's 50 m depth grid with GEBCO (Julian Burgos, MFRI), under where Icelandic
vessels fished, from their AIS tracks linked to the logbooks and landings: the depth in colour, its relief and
contours, the fishing effort by gear, year and fishing definition, the ports, and the place names of MFRI's
gazetteer.

**For use inside MFRI only.** The effort is made from vessel-level data, and the place names include names from
Trackwell's hauls and fishermen's plotters, which are not public. Do not pass the folder, or screenshots of names,
outside MFRI.

Prepared with AI assistance (Claude) from fishycode's `products/depth_effort_map/bundle.R` (TODO 185, decision 220);
`VERSION` says when and from which commits.

## Open it

1. Copy the whole folder to your own computer (or unzip `depth_effort_map_bundle.zip`). It opens from a share too, but
   much more slowly.
2. Double-click `index.html`. It opens in your web browser: a recent Chrome, Edge or Firefox.

Nothing to install, no R. The computer needs the internet: the map's program (MapLibre) and the base maps come from
the web; the depth, the effort and the names are in the folder.

The menu (☰, top left) holds the layers and their controls; IS | EN switches the language. The address in the
browser's bar keeps the view and the settings: bookmark it to come back to a view.

The effort is summed in your browser from the folder's data as you move and filter. The first view of a large area
takes a few seconds; it is quicker after.

## How it differs from the maps run from R

- **The depth to zoom 9.** Zoomed in further, the map draws zoom 9's tiles larger; no "depth by cell".
- **The effort's cells stop at 0.01 degrees** (about 0.5 by 1.1 km at 65° N), where the map from R goes to 0.001
  degrees; at any zoom a cell is one to two screen pixels.
- **The interpolated effort only:** the switch to the fixes alone is left out.
- **The "from the view" fits** of the depth are worked out in the browser, by the same rules.
