# Usage: python3 -I check_all.py <dir> <id> [<id> ...]
# For each report: checks <dir>/<id>.lean.json against <dir>/<id>.txt (as check_rows.py, plus a loose check of code
# rows), then prints the diagram test over all the reports given.
import json, os, re, sys, subprocess, collections as C
d, ids = sys.argv[1], sys.argv[2:]
here = os.path.dirname(os.path.abspath(__file__))
stop = set("the and of for in on to a an with by from at as or data vms ais".split())
def rng(s):
    a = [int(x) for x in re.findall(r"\d+", str(s))]; return set(range(a[0], a[-1] + 1)) if a else set()
allsub, offrows, reps_by_theme = [], [], C.defaultdict(set)
for i in ids:
    print(f"== {i}")
    print(subprocess.run(["python3", "-I", os.path.join(here, "check_rows.py"), f"{d}/{i}.txt", f"{d}/{i}.lean.json"], capture_output=True, text=True).stdout.strip().split("\n")[-1])
    J = json.load(open(f"{d}/{i}.lean.json", encoding="utf-8"))
    pages, cur = {}, None
    for line in open(f"{d}/{i}.txt", encoding="utf-8"):
        m = re.match(r"===== PDF page (\d+) ", line)
        if m: cur = int(m.group(1)); pages[cur] = ""; continue
        if cur: pages[cur] += line.lower()
    bad = [r["name"] for r in J.get("code") or [] if not any(w in " ".join(pages.get(p, "") for p in rng(r.get("pdf_pages")))
           for w in [w for w in re.findall(r"[a-z0-9]+", str(r["name"]).lower()) if len(w) > 3 and w not in stop] or [""])]
    print(f"code rows: {len(J.get('code') or [])}, {len(bad)} with no distinctive word of the name on their pages {bad[:6]}")
    sub = [r for r in J["topics"] if r.get("kind") in ("method", "definition", "finding")]
    allsub += sub
    for r in sub:
        if r.get("step") == "none" and r.get("kind") in ("method", "definition"): reps_by_theme[r.get("theme")].add(i)
on = [r for r in allsub if r.get("step") != "none"]
print(f"\n== diagram test over {len(ids)} reports: {len(on)}/{len(allsub)} substantive rows on a diagram row ({100*len(on)//max(1,len(allsub))}%)")
print("by step:", dict(C.Counter(r['step'] for r in on).most_common()))
print("'other' box by step:", dict(C.Counter(r['step'] for r in on if r.get('box') == 'other').most_common()))
print("off-diagram themes, by number of reports with method or definition rows (the criterion: three or more):")
for t, s in sorted(reps_by_theme.items(), key=lambda x: -len(x[1])): print(f"   {len(s)}  {t}")
