#!/usr/bin/env python3
"""Build public/geo.json for the calculator's optional ZIP code field.

Sources (all public, no keys):
  * Census 2020 ZCTA-to-county relationship file  -> which counties each ZIP (ZCTA) covers, by land area
  * FHFA conforming loan limits by county (xlsx)  -> conventional limits, 1-4 units
  * HUD FHA forward mortgage limits by county      -> FHA limits, 1-4 units
  * Census ACS 5-year summary file, tables B25103 (median real estate taxes paid) and
    B25077 (median home value)                     -> county property-tax estimate (taxes / value)

Limits are written for the calendar year the script runs in (the January run picks up the new year).
If a source for that year isn't published yet, the previous geo.json values for that part are kept
and the year label says which year they are.
"""
import csv, io, json, os, re, sys, datetime, urllib.request
from collections import defaultdict

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'public', 'geo.json')
UA = {'User-Agent': 'Mozilla/5.0 (home-calculator-site data build)'}
YEAR = int(os.environ.get('GEO_YEAR') or datetime.date.today().year)

def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        if r.status != 200: raise RuntimeError(f'{url}: HTTP {r.status}')
        data = r.read()
    print(f'  fetched {url} ({len(data):,} bytes)')
    return data if binary else data.decode('utf-8-sig', 'replace')

def try_get(url, binary=False):
    try: return get(url, binary)
    except Exception as e:
        print(f'  not available: {url} ({e})'); return None

prev = {}
if os.path.exists(OUT):
    with open(OUT, encoding='utf-8') as f: prev = json.load(f)

# Connecticut: the 2020 ZIP file uses the old 8 counties; FHFA, HUD and the ACS now use 9 planning regions.
# Each old county is split across the regions it overlaps (by towns); the page asks which one when they differ.
CT_REGIONS = {
    '09001': ['09120', '09190'],          # Fairfield -> Greater Bridgeport, Western CT
    '09003': ['09110', '09140'],          # Hartford -> Capitol, Naugatuck Valley (Bristol, Southington)
    '09005': ['09160', '09140', '09190'], # Litchfield -> Northwest Hills, Naugatuck Valley, Western CT
    '09007': ['09130'],                   # Middlesex -> Lower CT River Valley
    '09009': ['09170', '09140'],          # New Haven -> South Central, Naugatuck Valley
    '09011': ['09180', '09130'],          # New London -> Southeastern, Lower CT River Valley
    '09013': ['09110', '09150'],          # Tolland -> Capitol, Northeastern
    '09015': ['09150', '09180'],          # Windham -> Northeastern, Southeastern
}

# ---------- 1. ZIP -> county ----------
print('Census ZCTA-county relationship file')
rel = get('https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt')
rows = csv.DictReader(io.StringIO(rel), delimiter='|')
parts = defaultdict(list)          # zcta -> [(county, land, water)]
county_names = {}
for r in rows:
    z, c = r['GEOID_ZCTA5_20'].strip(), r['GEOID_COUNTY_20'].strip()
    county_names[c] = r['NAMELSAD_COUNTY_20'].strip()
    if not z: continue
    parts[z].append((c, int(r['AREALAND_PART'] or 0), int(r['AREAWATER_PART'] or 0)))

zips = {}
for z, ps in parts.items():
    land = sum(p[1] for p in ps)
    tot = land if land > 0 else sum(p[2] for p in ps)
    shares = defaultdict(float)
    for c, l, w in ps:
        share = (l if land > 0 else w) / tot if tot else 1 / len(ps)
        targets = CT_REGIONS.get(c, [c])
        for t in targets: shares[t] += share / len(targets)
    keep = sorted(((c, s) for c, s in shares.items() if s >= 0.02), key=lambda x: -x[1])
    if not keep: keep = [max(shares.items(), key=lambda x: x[1])]
    norm = sum(s for _, s in keep)
    if len(keep) == 1: zips[z] = keep[0][0]
    else: zips[z] = [[c, max(1, round(100 * s / norm))] for c, s in keep]
print(f'  {len(zips):,} ZIP areas')

# ---------- 2. FHFA conforming limits ----------
import openpyxl
def fhfa(year):
    data = try_get(f'https://www.fhfa.gov/document/d/cll/fullcountyloanlimitlist{year}_hera-based_final_flat.xlsx', True)
    if not data: return None
    ws = openpyxl.load_workbook(io.BytesIO(data), read_only=True).active
    out, hdr = {}, None
    for row in ws.iter_rows(values_only=True):
        if hdr is None:
            if row and str(row[0]).strip() == 'FIPS State Code': hdr = row
            continue
        if not row or not row[0] or not str(row[0]).strip().isdigit(): continue
        fips = str(row[0]).strip().zfill(2) + str(row[1]).strip().zfill(3)
        out[fips] = {'name': str(row[2]).strip(), 'st': str(row[3]).strip(), 'lim': [int(v) for v in row[5:9]]}
    print(f'  FHFA {year}: {len(out):,} counties')
    return out

print('FHFA conforming loan limits')
conf_year, conf = YEAR, fhfa(YEAR)
if conf is None: sys.exit(f'FHFA {YEAR} county file not found; nothing written.')
st_fips = {v['st']: k[:2] for k, v in conf.items()}

# ---------- 3. HUD FHA limits ----------
def hud(year):
    txt = try_get(f'https://apps.hud.gov/pub/chums/cy{year}-forward-limits.txt')
    if not txt: return None
    out, dates, dups = {}, {}, 0
    pat = re.compile(r'203B ([SH])(\d{7})(\d{7})(\d{7})(\d{7})(\d{7})([A-Z]{2})(\d{3})')
    datepat = re.compile(r'((?:19|20)\d{6})\d{7}\d{4}\s*$')     # effective date, median, median year
    for line in txt.splitlines():
        m = pat.search(line)
        if not m or m.group(7) not in st_fips: continue
        key = st_fips[m.group(7)] + m.group(8)
        d = datepat.search(line); d = d.group(1) if d else '0'
        lim = [int(m.group(i)) for i in (3, 4, 5, 6)]
        if key in out:
            dups += 1
            if out[key] != lim: print(f'    {key} has more than one record: {out[key]} ({dates[key]}) vs {lim} ({d})')
            if d < dates[key]: continue           # keep the most recent effective date
        out[key], dates[key] = lim, d
    print(f'  HUD {year}: {len(out):,} counties ({dups} duplicate records)')
    for k in ('36061', '36047', '34017', '06037'):
        print('   ', k, out.get(k))
    return out or None

print('HUD FHA forward limits')
fha_year, fha = YEAR, hud(YEAR)
if fha is None:
    print(f'  HUD {YEAR} file not published yet; FHA county limits left out for now')
    fha_year = None

# ---------- 4. ACS property-tax estimate ----------
def acs_table(year, table):
    txt = try_get(f'https://www2.census.gov/programs-surveys/acs/summary_file/{year}/table-based-SF/data/5YRData/acsdt5y{year}-{table}.dat')
    if not txt: return None
    rdr = csv.reader(io.StringIO(txt), delimiter='|')
    hdr = next(rdr); gi = hdr.index('GEO_ID'); vi = hdr.index(table.upper() + '_E001')
    out = {}
    for r in rdr:
        g = r[gi]
        if g.startswith('0500000US'):
            try: out[g[-5:]] = float(r[vi])
            except ValueError: pass
    return out

print('Census ACS county taxes and values')
acs_year = tax = None
for y in (YEAR - 2, YEAR - 3):
    t, v = acs_table(y, 'b25103'), acs_table(y, 'b25077')
    if t and v:
        acs_year = y
        tax = {c: round(100 * t[c] / v[c], 2) for c in t if c in v and v[c] > 0 and t[c] > 0}
        print(f'  ACS {y - 4}-{y}: {len(tax):,} counties')
        break
if tax is None:
    sys.exit('ACS tables not found; nothing written.')

# ---------- 5. Assemble ----------
base = [min(v['lim'][i] for v in conf.values()) for i in range(4)]
floor = [min(v[i] for v in fha.values()) for i in range(4)] if fha else None
counties = {}
for c in set(conf) | set(county_names):
    if c[:2] == '09' and c in CT_REGIONS: continue          # old CT counties: replaced by regions
    if c not in conf and c not in tax: continue
    name = county_names.get(c) or (conf[c]['name'].title() if c in conf else c)
    if c in conf and c[:2] == '09': name = conf[c]['name']
    st = conf[c]['st'] if c in conf else next((k for k, v in st_fips.items() if v == c[:2]), '')
    e = {'n': name, 's': st}
    if c in tax: e['t'] = tax[c]
    if c in conf and conf[c]['lim'] != base: e['c'] = conf[c]['lim']
    if fha and c in fha and fha[c] != floor: e['f'] = fha[c]
    counties[c] = e

missing = sorted({c for v in zips.values() for c in ([v] if isinstance(v, str) else [x[0] for x in v])} - set(counties))
if missing: print(f'  warning: {len(missing)} ZIP counties without data: {missing[:20]}')

geo = {
    'updatedAt': datetime.date.today().isoformat(),
    'note': 'ZIP areas are Census 2020 ZIP Code Tabulation Areas (approximate USPS ZIPs), matched to counties by land area.',
    'sources': {
        'zip': 'U.S. Census Bureau, 2020 ZCTA to County Relationship File',
        'conf': f'FHFA {conf_year} conforming loan limits by county',
        'fha': f'HUD {fha_year} FHA forward mortgage limits by county' if fha_year else None,
        'tax': f'U.S. Census Bureau, American Community Survey {acs_year - 4}-{acs_year} 5-year estimates (B25103 median real estate taxes / B25077 median home value)',
    },
    'confYear': conf_year, 'confBase': base,
    'fhaYear': fha_year, 'fhaFloor': floor,
    'taxYear': acs_year,
    'counties': dict(sorted(counties.items())),
    'zips': dict(sorted(zips.items())),
}
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(geo, f, ensure_ascii=False, separators=(',', ':'))
print(f'Wrote {OUT}: {os.path.getsize(OUT):,} bytes, {len(counties):,} counties, {len(zips):,} ZIPs')
for z in ('77002', '06103', '06604', '06510', '10001', '96813', '99501', '20001', '00601'):
    v = zips.get(z); cs = [v] if isinstance(v, str) else [x[0] for x in (v or [])]
    print(' ', z, v, [counties.get(c) for c in cs])
