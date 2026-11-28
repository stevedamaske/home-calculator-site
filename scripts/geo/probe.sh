#!/usr/bin/env bash
set -u
UA="Mozilla/5.0 (home-calculator-site data build)"
echo "== ACS summary file tables"
for y in 2024 2023; do for t in b25103 b25077; do
  u="https://www2.census.gov/programs-surveys/acs/summary_file/$y/table-based-SF/data/5YRData/acsdt5y$y-$t.dat"
  curl -sSL -A "$UA" "$u" -o /tmp/$t-$y.dat -w "$y $t %{http_code} %{size_download}\n"; head -c 400 /tmp/$t-$y.dat; echo; grep -m2 '0500000US09110\|0500000US01001' /tmp/$t-$y.dat | cut -c1-200
done; done
echo "== HUD FHA limits list (POST)"
curl -sSL -A "$UA" -e https://entp.hud.gov/idapp/fhagov/hicostlook.cfm -X POST https://entp.hud.gov/idapp/fhagov/hicost1.cfm --data "sorted=state&state=CT&county_name=&county=&msa_name=&msa_code=&limit_type=FHA&limit_year=CY2026&last_upd_m=&last_upd_d=&last_upd_y=&in_fha=No" -o /tmp/hudct.html -w "%{http_code} %{size_download} %{url_effective}\n"
python3 - <<'P'
import re,html
t=open('/tmp/hudct.html',encoding='latin-1').read()
rows=re.findall(r'<tr[^>]*>(.*?)</tr>',t,re.S|re.I)
print('rows',len(rows))
for r in rows[:30]:
    cells=[html.unescape(re.sub(r'<[^>]+>','',c)).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',r,re.S|re.I)]
    if any(cells): print(cells)
print(re.findall(r'<a [^>]*href="[^"]*"[^>]*>[^<]*',t)[:20])
P
echo "== HUD file layouts page"
curl -sSL -A "$UA" http://www.hud.gov/pub/chums/file_layouts.html -o /tmp/fl.html -w "%{http_code} %{size_download} %{url_effective}\n"
grep -io '<a [^>]*href="[^"]*"[^>]*>[^<]*' /tmp/fl.html | head -40
