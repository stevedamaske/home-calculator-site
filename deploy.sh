#!/usr/bin/env bash
# Deploys the Home Purchase Calculator to Cloudflare (Workers static assets, free plan).
# Usage:  ./deploy.sh            deploy ./public as-is
#         ./deploy.sh --login    sign in to Cloudflare first (one time)
[ -x "$0" ] || chmod a+x "$0"
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v npx >/dev/null 2>&1; then
  echo "Node.js is required (npx not found). Install it with: brew install node" >&2
  exit 1
fi

if [ "${1:-}" = "--login" ] || ! npx --yes wrangler@latest whoami 2>/dev/null | grep -qi "associated with the email"; then
  if [ ! -t 0 ]; then
    echo "Not signed in to Cloudflare. Run ./deploy.sh --login in Terminal once." >&2
    exit 1
  fi
  echo "Signing in to Cloudflare (a browser window will open)..."
  npx --yes wrangler@latest login
fi

for f in public/index.html public/app.js public/rates.json public/dpa.json; do
  [ -s "$f" ] || { echo "Missing $f" >&2; exit 1; }
done

# Refuse to ship broken data files.
for f in public/rates.json public/dpa.json; do
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" \
    || { echo "$f is not valid JSON" >&2; exit 1; }
done

node --check public/app.js || { echo "public/app.js has a syntax error" >&2; exit 1; }

rates_date=$(node -e "console.log(JSON.parse(require('fs').readFileSync('public/rates.json','utf8')).asOf)")
echo "Deploying (rates as of $rates_date)..."
npx --yes wrangler@latest deploy
