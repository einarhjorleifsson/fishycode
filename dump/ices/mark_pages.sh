#!/bin/zsh
# Usage: mark_pages.sh <pdf> <out.txt>
# Writes the PDF's text, one block per page, each opened by a marker line that gives the PDF page index and the
# printed page number read from the page header (ICES report style: "4 | ICES SCIENTIFIC REPORTS ..." on even pages,
# "ICES | WGSFD 2025 | 5" on odd pages); "-" where the header carries none.
pdf=$1; out=$2; tmp=$(mktemp)
n=$(pdfinfo "$pdf" | awk '/^Pages/{print $2}')
: > "$out"
for i in $(seq 1 $n); do
  pdftotext -layout -f $i -l $i "$pdf" "$tmp" 2>/dev/null
  head=$(grep -v '^[[:space:]]*$' "$tmp" | head -1 | tr -s ' ' | sed 's/^ //; s/ $//')
  p=$(print -r -- "$head" | awk -F' [|] ' 'NF>=2 { if ($1 ~ /^([0-9]+|[ivxlc]+)$/) print $1; else if ($NF ~ /^([0-9]+|[ivxlc]+)$/) print $NF }')
  print -r -- "===== PDF page $i · printed page ${p:--} =====" >> "$out"
  tr -d "\f" < "$tmp" >> "$out"; print >> "$out"
done
rm -f "$tmp"
