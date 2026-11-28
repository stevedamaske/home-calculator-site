// Smoke test of the calculator in the three browser engines:
//   Chromium (Chrome, Edge, Opera, Samsung Internet), Firefox (Gecko) and WebKit (Safari, every iPhone browser).
// Serves ./public locally, walks through the main features at desktop and phone width, and fails on any
// script error or wrong result. Run by .github/workflows/browser-check.yml.
import { chromium, firefox, webkit, devices } from 'playwright';
import { spawn } from 'node:child_process';

const PORT = 8123, URL = `http://localhost:${PORT}/index.html`;
const server = spawn('python3', ['-m', 'http.server', String(PORT), '--directory', 'public'], { stdio: 'ignore' });
await new Promise(r => setTimeout(r, 1500));

const failures = [];
const check = (ok, what, where) => { if (!ok) failures.push(`${where}: ${what}`); console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${what}`); };

// ONLY=chromium (or firefox / webkit) limits a local run to one engine
const ONLY = process.env.ONLY;

async function run(name, type, ctxOpts) {
  if (ONLY && type.name() !== ONLY) return;
  console.log(`\n== ${name}`);
  const c = (ok, what) => check(ok, what, name);
  const browser = await type.launch();
  const ctx = await browser.newContext(ctxOpts);
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error' && !/favicon|help\.json/.test(m.text())) errors.push(m.text()); });
  try {
    await page.goto(URL); await page.waitForTimeout(1200);
    const val = sel => page.$eval(sel, e => e.value);
    const text = sel => page.$eval(sel, e => e.textContent);

    await page.click('#price'); await page.keyboard.type('400000');
    c(await val('#price') === '400,000', 'price gets live commas (400,000)');
    await page.waitForTimeout(200);
    c(!/^\$0\b/.test(await text('#outMonthly')), 'monthly payment calculates');

    await page.click('#insPer button[data-v="mo"]');
    c(await val('#ins') === '150', 'insurance /mo switch converts 1,800/yr to 150');

    await page.click('#zip'); await page.keyboard.type('78704');
    await page.waitForFunction(() => /Travis County/.test(document.getElementById('zipHint').textContent), null, { timeout: 8000 }).catch(() => {});
    c(/Travis County, TX/.test(await text('#zipHint')), 'ZIP 78704 finds Travis County, TX');
    c(await val('#dpaState') === 'TX' && await val('#dpaArea') === 'Austin', 'ZIP picks TX and Austin assistance');
    await page.fill('#zip', ''); await page.click('#zip'); await page.keyboard.type('10001'); await page.waitForTimeout(400);
    c(await page.$('#zipWarn button') !== null, 'ZIP 10001 shows the orange (!) mismatch note');

    await page.fill('#zip', ''); await page.dispatchEvent('#zip', 'input');
    await page.selectOption('#dpaState', 'CA'); await page.waitForTimeout(300);
    await page.click('[data-use="ca-myhome"]'); await page.waitForTimeout(200);
    const amt = await val('#dpaAmt');
    c(/[1-9]/.test(amt), 'choosing a program fills the assistance amount');
    await page.click('label:has(#dpaAmt) .helpi'); await page.waitForTimeout(200);
    c(/Filled in from MyHome/.test(await text('#helpText')), 'assistance amount ⓘ explains the program');
    await page.keyboard.press('Escape');

    await page.click('#themeBtn');
    c(await page.evaluate(() => document.documentElement.dataset.theme) === 'light', 'theme switch turns on light mode');
    await page.reload(); await page.waitForTimeout(1000);
    c(await page.evaluate(() => document.documentElement.dataset.theme) === 'light', 'light mode is remembered after reload');
    c(await val('#price') === '400,000', 'inputs are remembered after reload');

    c(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1)), 'no sideways scrolling');
  } catch (e) {
    c(false, `test crashed: ${e.message.split('\n')[0]}`);
  }
  c(errors.length === 0, `no script errors${errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''}`);
  await browser.close();
}

const desktop = { viewport: { width: 1280, height: 900 } };
await run('Chromium (Chrome / Edge / Opera) · desktop', chromium, desktop);
await run('Firefox · desktop', firefox, desktop);
await run('WebKit (Safari) · desktop', webkit, desktop);
await run('Chromium · Android phone', chromium, devices['Pixel 7']);
await run('WebKit · iPhone', webkit, devices['iPhone 15']);

server.kill();
console.log(failures.length ? `\n${failures.length} check(s) failed:\n- ${failures.join('\n- ')}` : '\nAll browsers passed.');
process.exit(failures.length ? 1 : 0);
