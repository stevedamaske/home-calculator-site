# Home Purchase Calculator — itoowouldlikeahouse.com

FHA, VA and conventional purchase calculator with live market rates, rate buydowns, buyer and seller closing costs, and down payment assistance for all 50 states plus DC. Static site, no server code, on Cloudflare's free plan.

```
public/index.html   the calculator (single file: HTML, CSS, JS)
public/rates.json   market rates + FHA/VA/conventional rules
public/dpa.json     down payment assistance programs
public/help.json    text and links for the ⓘ explanations
public/_headers     security headers; JSON never cached
wrangler.jsonc      static-assets config and custom domain (no Worker code)
deploy.sh           optional manual deploy from a computer
```

## How it deploys
Cloudflare Workers Builds is connected to this repo. Every push to `main` deploys automatically to itoowouldlikeahouse.com — nothing to run locally.

## Data refresh
A scheduled Claude task runs every Friday at 9:30 AM ET. It updates `public/rates.json`, `public/dpa.json` and `public/help.json` (link checks and rule changes in the ⓘ explanations), commits them to `main` as "Data refresh YYYY-MM-DD", and Cloudflare redeploys. It never changes `index.html` or any other file.

## Caching
- `index.html`: Cloudflare's default `Cache-Control: public, max-age=0, must-revalidate` — browsers check for a new version on every load, so a deploy shows up on the next visit.
- `*.json`: `Cache-Control: no-cache` from `public/_headers`, and the page also fetches them with `cache: 'no-store'` — rates and programs are always the latest deployed copy.

Check the live headers:
```
curl -sI https://itoowouldlikeahouse.com/ | grep -i cache-control
curl -sI https://itoowouldlikeahouse.com/rates.json | grep -i cache-control
```

## ⓘ explanations
Tapping the ⓘ next to a field opens a short explanation with a link to an official source (CFPB, VA, HUD, FHFA). The wording lives in `public/help.json`; numbers written as `{{token}}` (FHA MIP, upfront MIP, VA funding fee, conforming limit, seller-concession cap) are filled in from `rates.json` and the current inputs. Editing `help.json` doesn't reset saved inputs. A copy is built into `index.html` as a fallback.

## Saved inputs
A visitor's inputs are kept only in their own browser (localStorage key `home-calc-v3`; no cookies, nothing on the server). They are cleared automatically when:
- the calculator's code changes — the page fingerprints its own script, so any edit to `index.html` resets saved inputs on the next visit (the weekly data refresh does not); or
- 48 hours pass without use — checked on load and whenever an open tab comes back into view.

A short notice tells the visitor why their inputs were reset.

## Making changes
Edit files in `public/`, commit and push to `main` (or merge a pull request). Cloudflare deploys within a minute or two.

## Manual deploy (optional)
If Cloudflare's GitHub build is ever disconnected: install Node (`brew install node`), then run `./deploy.sh` (first time: `./deploy.sh --login`). It validates the JSON files and deploys `public/` with Wrangler.
