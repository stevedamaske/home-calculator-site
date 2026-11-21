# Home Purchase Calculator — Cloudflare deploy kit

```
public/index.html   the calculator
public/rates.json   market rates + FHA/VA/conventional rules
public/dpa.json     down payment assistance programs
public/_headers     security headers; JSON never cached
wrangler.jsonc      static-assets config (no Worker code, free plan)
deploy.sh           validates the files and deploys
```

## First deploy (Mac)
1. Install Node if needed: `brew install node`
2. `./deploy.sh` (the first run opens a browser to sign in to Cloudflare)
3. Wrangler prints your URL: `https://home-calculator.<your-subdomain>.workers.dev`

## Custom domain (optional)
In the dashboard, open Workers & Pages → home-calculator → Settings → Domains & Routes → Add → Custom domain, and enter e.g. `homes.yourdomain.com`. The domain must already be on your Cloudflare account. DNS and the certificate are set up automatically.

## Keep it private (optional)
Zero Trust → Access → Applications → Add a self-hosted app for that hostname, with an Allow policy listing your email addresses (one-time PIN login). Free for up to 50 users.

## Updating
Replace the files in `public/` and run `./deploy.sh` again.
The daily refresh task updates rates.json and dpa.json only on the claude.ai copy. This copy keeps the data it was deployed with until you redeploy.
