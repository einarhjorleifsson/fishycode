# Usage: python3 -I check_rows.py <marked.txt> <rows.json>  (the YAML converted by R: yaml -> jsonlite)
# Checks a reading map against the marked report text: pages exist and agree with the markers, a row's own terms
# occur on its cited pages, and no summary copies an 8-word run of the report.
import re, sys, json
txt, yml = sys.argv[1], sys.argv[2]
pages, printed, cur = {}, {}, None
for line in open(txt, encoding="utf-8"):
    m = re.match(r"===== PDF page (\d+) · printed page (\S+) =====", line)
    if m:
        cur = int(m.group(1)); printed[cur] = m.group(2); pages[cur] = ""; continue
    if cur: pages[cur] += line
norm = lambda s: re.sub(r"[^a-z0-9]+", " ", s.lower().replace("‐", "-")).strip()
def rng(s):
    out = []
    for part in str(s).replace("–", "-").split(","):
        part = part.strip()
        if not part: continue
        if "-" in part:
            a, b = part.split("-", 1)
            if a.strip().isdigit() and b.strip().isdigit(): out += list(range(int(a), int(b) + 1)); continue
        if part.isdigit(): out.append(int(part))
        else: out.append(part)
    return out
inv = {}
for k, v in printed.items(): inv.setdefault(v, k)
doc = json.load(open(yml, encoding="utf-8"))
rows = doc.get("topics", [])
alltext = norm(" ".join(pages.values()))
shingles = set()
w = alltext.split()
for i in range(len(w) - 7): shingles.add(" ".join(w[i:i + 8]))
bad = 0
for i, r in enumerate(rows, 1):
    probs = []
    pp = [p for p in rng(r.get("pdf_pages", "")) if isinstance(p, int)]
    if not pp or any(p not in pages for p in pp): probs.append("pdf_pages out of range")
    pr = rng(r.get("pages", ""))
    exp = [printed.get(p) for p in pp]
    if pp and [str(x) for x in pr] != [x for x in exp if x]:
        # allow the printed range to be given as its end points only
        if not (pr and str(pr[0]) == exp[0] and str(pr[-1]) == exp[-1]): probs.append(f"pages {r.get('pages')} vs markers {exp}")
    text = norm(" ".join(pages.get(p, "") for p in pp))
    terms = r.get("terms") or []
    if isinstance(terms, str): terms = [terms]  # a single term arrives unboxed from the merge
    terms = [t for t in terms if str(t).strip()]
    hit = [t for t in terms if norm(str(t)) and norm(str(t)) in text]
    if terms and not hit: probs.append(f"no term found on its pages: {terms}")
    sw = norm(r.get("summary", "")).split()
    cp = [" ".join(sw[j:j + 8]) for j in range(len(sw) - 7) if " ".join(sw[j:j + 8]) in shingles]
    if cp: probs.append(f"summary copies: '{cp[0]}'")
    if probs:
        bad += 1; print(f"row {i} [{r.get('topic')}]: " + "; ".join(probs))
print(f"{len(rows)} rows, {bad} with a problem; {len(doc.get('vocabulary', []))} vocabulary entries")
