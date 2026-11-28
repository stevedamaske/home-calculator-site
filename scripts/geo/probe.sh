#!/usr/bin/env bash
set -u
UA="Mozilla/5.0 (home-calculator-site data build)"
echo "== ACS summary file tables"
for y in 2024; do for t in b25103 b25077; do
  u="https://www2.census.gov/programs-surveys/acs/summary_file/$y/table-based-SF/data/5YRData/acsdt5y$y-$t.dat"
  curl -sSL -A "$UA" "$u" -o /tmp/$t-$y.dat -w "$y $t %{http_code} %{size_download}\n"; head -c 300 /tmp/$t-$y.dat; echo; grep -m2 '0500000US09110\|0500000US01001' /tmp/$t-$y.dat | cut -c1-160
done; done
echo "== HUD layout"
curl -sSL -A "$UA" https://apps.hud.gov/pub/chums/file_layouts.html -o /tmp/fl.html
python3 - <<'P'
import re,html
t=open('/tmp/fl.html',encoding='latin-1').read()
i=t.find('Limits2010'); i=t.find('Limits2010',i+20)
s=html.unescape(re.sub(r'<[^>]+>',' ',t[i:i+9000])); s=re.sub(r'[ \t]+',' ',s); s=re.sub(r'\n\s*\n+','\n',s)
print(s[:3500])
P
echo "== HUD forward file"
for y in 2026 2027; do curl -sSL -A "$UA" "https://apps.hud.gov/pub/chums/cy$y-forward-limits.txt" -o /tmp/fwd$y.txt -w "$y %{http_code} %{size_download}\n"; done
wc -l /tmp/fwd2026.txt; head -3 /tmp/fwd2026.txt; grep -m3 ' CT\|CT ' /tmp/fwd2026.txt; grep -m2 'HARRIS' /tmp/fwd2026.txt
