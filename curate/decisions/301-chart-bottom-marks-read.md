# 301 — The current sea charts' bottom marks read at 1:300 000, 1:100 000 and 1:40 000, by INT 1's code list; their named rings place a small name's feature

*2026-11-08. At the maintainer's word: "should we mine the substrate marks on the natt.is maps - like in a
sub-session", then, after a pilot, "Yes, read 1:300 000", "Read 1:100 000" and "Read 1:40 000"; of the hazard
symbols, "When we go into higher zoom - we may find star sign (*) and other signs that denotate placenames or hazards.
Mine those as well"; "Stop here" when the harbour plans were offered; and "Yes, write it". Read by Claude Sonnet 5.5
subagents and macOS's own text recognizer, coded, checked on samples by eye and counted by Claude (AI); no person has
checked the readings or the counts. Internal only: the charts are Landhelgisgæslan's work (Sjómælingar Íslands),
served for viewing. The study, its scripts and every table: `$FISHYDATA/archive/2026-11-08-chart-bottom-types/` (its
README).*

## Why

TODO 186 read the current charts (gis.natt.is) for their names and left out the short bottom-type marks they print in
the sea (`S`, `St`, `M`, `h` ...). Decision 300 found the older 1:750 000 chart prints none, and the maintainer asked
whether the current charts' marks, and the substrate words in the smaller names, say what the seabed is.

## The code list

A mark is defined by its list. The Icelandic charts' key is Kort 1, "Tákn og skammstafanir í sjókortum", 2012,
Landhelgisgæslan's edition of INT 1 (the chart catalogue, Kortaskrá 2025-04, PDF pages 3 and 10-11). No copy was
found online. INT 1's international column is the same in every national edition, so Section J (the nature of the
seabed) and Section K (rocks, wrecks, obstructions) were taken from Kartverket's Norwegian edition. Both PDFs are in
`raw/external/chart_symbols/`, with their sources, checksums and pages in its `README-provenance.txt`; Kartverket's is
cited by section, never republished.

The list, `results/int1_section_j.csv`: 14 types (S sand, M mud, Cy clay, Si silt, St stones, G gravel, P pebbles,
Cb cobbles, R rock, Bo boulders, Co coral or coralline algae, Sh shells, Wd weed, Sg seagrass) and 10 qualifiers, each
with its S-57 value (NATSUR, NATQUA). The charts also print older forms off today's list (`Rk`; `SM`, `SG`, `MS`, `SSt`,
`StS` with no dot), decoded apart and flagged, and `#`, K 31 foul ground ("to be avoided by vessels anchoring,
trawling"), flagged `foul`. `h` alone in the sea is "hard", not hour. Whether Kort 1 adds national abbreviations is not
known until it is seen.

## What was read

Every kept window of TODO 186's images of a layer, in chunks of 25, one subagent a chunk; macOS's Vision framework
read each layer too (seconds, no tokens). A pilot of 20 windows (208,478 tokens) came first.

| | 1:300 000 | 1:100 000 | 1:40 000 |
|---|---:|---:|---:|
| Windows | 225 | 643 | 255 |
| Sonnet tokens | 1,249,189 | 3,559,220 | 1,433,396 |
| Marks, each counted once across overlapping windows | 1,087 | 2,584 | 616 |
| Rings (a small closed contour or danger line) | 644 | 1,997 | 662 |
| Named rings | 32 | 186 | 107 |

Sand is the commonest main part at every scale; stones and mud next. The 1:40 000 charts cover three stretches only
(Breiðafjörður round Stykkishólmur, inner Faxaflói, Vestmannaeyjar and the coast north of it). The north-east,
Melrakkaslétta to Glettinganes, prints almost no marks at 1:300 000.

## How good

- **Sonnet's marks are real**: of 24 drawn at random from those Vision did not find, 24, 22 and 24 (1:300 000,
  1:100 000, 1:40 000); at 1:100 000 one is not in its crop and one unclear. The pilot's windows read again give the
  same marks, 64 of 65, 50 of 51 and 32 of 32.
- **Vision finds about half** (635 of 1,325; 1,761 of 3,205; 525 of 761 marks read, the same text), the small grey
  marks least, and adds light-sector, buoy and name letters. A second reader, not a substitute.
- **Not measured**: the marks both miss. A mark sits at its cell's centre, within about 1.3 km at 1:300 000 and 0.5 km
  at 1:100 000; 12 fall on land in narrow fjords.

## The named rings

INT 1 has no symbol for an isolated mound (the maintainer's "isolated mounds location whose name then may appear aside
them"): it shows as a small closed contour, a danger line or a least depth, often with its name beside it. **325 rings
carry a name; 319 are among TODO 186's names**, a median 1.6, 0.9 and 0.5 km from where TODO 186 placed the name's
label. The ring is the feature's own position; the label is only near it. Where the readers called a ring a rise or a
hollow, the depth grid mostly agrees (at 1:100 000, 866 of the 898 rises the grid can judge).

## The name words

1,487 sea names searched; 117 hold a substrate word (-hraun, -leir, -for, -flaga, -flös, -hlein, -flúð ...). **A
substrate word goes only with the small name that carries it** (the maintainer, 2026-11-08: "we would not link
substrate to such 'broad' names"): never to a bay, fjord, deep or region, and never from a land name
(Hraunsfjörður, Rauðasandsgrunn). Against the marks within 5 km, at 1:100 000: -hraun names have 41 % stones or gravel
near against 28 % of all marks; -leir names 16 % mud, silt or clay against 14 %. A hint, not a test: neighbouring
names share their marks and a label is not its feature.

## The hazard symbols

Piloted on 10 windows at 1:40 000 with the instructions `scripts/read_prompt_symbols.md` (101,801 tokens): 16 symbols
in 3 windows, 13 rocks awash (`*`), 2 underwater rocks (`+`), 1 other, none with a name, read right where checked; the
bottom marks the same as the full read's (35 of 35). The maintainer's rule: where a name sits beside a `*`, the
symbol is the feature's position.

## What it means

The current charts are a seabed source at a mark's resolution, read for about 5,550 tokens a window, and their named
rings place a small name better than its label. For plan 070 the rings are the small names' positions (§2.8); the marks
are bottom types at points, never an area, and the words describe their own small feature only.

## Open

Each needs the maintainer's word; costs in the study's README.

- The harbour plans, 1:10-15 000, with the symbols: 682 windows, about 3.8 M tokens.
- The symbol pass at 1:40 000: 255 windows, about 1.4 M.
- K42 (1:160 000) and K44 (1:70 000): 84 windows, about 0.5 M.
- Kort 1 itself, for any national abbreviation (one mark may be `S.Sk`).
- Landhelgisgæslan's electronic charts hold every mark as data (S-57 SBDARE, with NATSUR and NATQUA); asking them is
  the maintainer's call.
