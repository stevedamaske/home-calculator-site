#!/usr/bin/env bash
# Prints the shape of each source so the build script can be checked against it.
set -u
UA="Mozilla/5.0 (home-calculator-site data build)"
echo "== Census ZCTA-county relationship file"
curl -sSL -A "$UA" https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt -o /tmp/rel.txt -w "%{http_code} %{size_download}\n"; wc -l /tmp/rel.txt; head -3 /tmp/rel.txt; grep -m3 '|09001|' /tmp/rel.txt
echo "== Census ACS county taxes"
for y in 2024 2023; do curl -sSL -A "$UA" "https://api.census.gov/data/$y/acs/acs5?get=NAME,B25103_001E,B25077_001E&for=county:*" -o /tmp/acs$y.json -w "$y %{http_code} %{size_download} %{url_effective}\n"; head -c 300 /tmp/acs$y.json; echo; grep -m3 'Connecticut' /tmp/acs$y.json; done
echo "== HUD FHA limits list (POST)"
curl -sSL -A "$UA" -X POST https://entp.hud.gov/idapp/fhagov/hicost1.cfm --data "sorted=state&state=CT&county_name=&county=&msa_name=&msa_code=&limit_type=FHA&limit_year=CY2026&last_upd_m=&last_upd_d=&last_upd_y=" -o /tmp/hudct.html -w "%{http_code} %{size_download} %{url_effective}\n"
sed -e 's/<[^>]*>/ /g' /tmp/hudct.html | tr -s ' \t' ' ' | grep -v '^ *$' | head -60
grep -io '<form[^>]*>\|<input[^>]*>\|<a [^>]*href="[^"]*"' /tmp/hudct.html | head -30
