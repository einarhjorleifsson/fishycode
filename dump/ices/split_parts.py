# Usage: python3 -I split_parts.py <compact.txt> <max_chars>
# Splits a compact report text at page markers into near-equal parts of at most max_chars each:
# <stem>.part1.txt, ... Prints each part's PDF page range and size. A report under max_chars stays whole.
import math, re, sys
src, mx = sys.argv[1], int(sys.argv[2])
pages = re.split(r"(?m)^(?====== PDF page )", open(src, encoding="utf-8").read())
pages = [p for p in pages if p.strip()]
total = sum(len(p) for p in pages); n = max(1, math.ceil(total / mx)); target = total / n
parts, cur = [], []
for p in pages:
    if cur and sum(map(len, cur)) + len(p) > target * 1.08 and len(parts) < n - 1: parts.append(cur); cur = []
    cur.append(p)
parts.append(cur)
stem = src[:-len(".compact.txt")]
for i, pp in enumerate(parts, 1):
    first = re.match(r"===== PDF page (\d+)", pp[0]).group(1); last = re.match(r"===== PDF page (\d+)", pp[-1]).group(1)
    out = f"{stem}.part{i}.txt" if len(parts) > 1 else f"{stem}.part1.txt"
    open(out, "w", encoding="utf-8").write("".join(pp))
    print(f"{out.split('/')[-1]}: PDF pages {first}-{last}, {sum(map(len, pp))//1000}k chars, {''.join(pp).count(chr(10))} lines")
