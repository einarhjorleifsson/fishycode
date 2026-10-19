# Usage: python3 -I compact_text.py <marked.txt> <compact.txt>
# From a page-marked report text (mark_pages.sh), writes a compact one for reading: page markers kept, runs of spaces
# collapsed, and dropped: contents lines (dot leaders), lines that are mostly digits (table bodies; captions stay),
# reference lists, and the list of participants (no personal names are read).
import re, sys
src, out = sys.argv[1], sys.argv[2]
mode, keep = None, []
for raw in open(src, encoding="utf-8"):
    if raw.startswith("===== PDF page"): keep.append(raw.rstrip("\n")); continue
    l = re.sub(r"\s+", " ", raw).strip()
    if not l: continue
    if re.fullmatch(r"(\d+(\.\d+)*\s+|annex \d+[:.]?\s*)?(references|literature cited|bibliography)", l, re.I):
        mode = "refs"; keep.append(l + " [list omitted]"); continue
    if re.match(r"(annex \d+[:.]?\s*)?list of participants", l, re.I) and not re.search(r"\.{4,}", l):
        mode = "part"; keep.append(l + " [list omitted]"); continue
    if mode and ((re.match(r"annex \d+", l, re.I) and not re.search(r"\.{4,}", l)) or re.match(r"\d+(\.\d+)*\s+[A-Z][a-z]", l)):
        mode = None
    if mode: continue
    if re.search(r"\.{5,}\s*\d+$|…{3,}", l): continue
    s = l.replace(" ", "")
    if len(s) > 3 and sum(ch.isdigit() or ch in ".,%-–()" for ch in s) > 0.6 * len(s): continue
    keep.append(l)
open(out, "w", encoding="utf-8").write("\n".join(keep) + "\n")
