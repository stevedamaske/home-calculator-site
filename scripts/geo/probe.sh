#!/usr/bin/env bash
# Prints the shape of each source so the build script can be checked against it.
set -u
UA="Mozilla/5.0 (home-calculator-site data build)"
echo "== Census ZCTA-county relationship file"
curl -sSL -A "$UA" https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt -o /tmp/rel.txt; wc -l /tmp/rel.txt; head -3 /tmp/rel.txt; grep -m3 '|09' /tmp/rel.txt
echo "== FHFA county limits"
for y in 2026 2027; do curl -sSL -A "$UA" -o /tmp/fhfa$y.xlsx -w "$y %{http_code} %{size_download} %{content_type}\n" "https://www.fhfa.gov/document/d/cll/fullcountyloanlimitlist${y}_hera-based_final_flat.xlsx"; done
python3 - <<'P'
import openpyxl
for y in (2026,2027):
    try:
        ws=openpyxl.load_workbook(f'/tmp/fhfa{y}.xlsx',read_only=True).active
        rows=list(ws.iter_rows(values_only=True))
        print(y,len(rows)); [print(r) for r in rows[:4]]
        print([r for r in rows if r and str(r[0]).strip() in ('9','09')][:12])
    except Exception as e: print(y,'ERR',e)
P
echo "== Census ACS county taxes"
for y in 2024 2023; do curl -sS -A "$UA" "https://api.census.gov/data/$y/acs/acs5?get=NAME,B25103_001E,B25077_001E&for=county:*" -o /tmp/acs$y.json -w "$y %{http_code} %{size_download}\n"; head -c 300 /tmp/acs$y.json; echo; grep -m3 'Connecticut' /tmp/acs$y.json; done
echo "== HUD FHA limits form"
curl -sSL -A "$UA" https://entp.hud.gov/idapp/fhagov/hicostlook.cfm -o /tmp/hud.html -w "%{http_code} %{size_download}\n"
grep -io '<form[^>]*>\|<input[^>]*>\|<select[^>]*>\|<option[^>]*>[^<]*\|<a [^>]*href="[^"]*"[^>]*>[^<]*' /tmp/hud.html | head -80
