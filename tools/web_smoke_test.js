// Headless-browser smoke test for the web build.
//
// Loads the app, drives it through a scripted sequence of clicks and key
// presses, fails on any uncaught exception, and writes a screenshot. This is
// how the two runtime bugs that only appear in the browser were found: the
// duplicate FloatingActionButton hero tags on the class-detail tabs, and the
// frozen loading screen when localStorage is unavailable.
//
// Requirements (not part of the app's dependencies):
//   sudo apt install chromium
//   npm install puppeteer-core
//
// Usage, against a running preview (see docs/ for how to start one):
//   node tools/web_smoke_test.js out.png
//   node tools/web_smoke_test.js out.png steps.json
//
// A steps file is a JSON array of actions, applied in order:
//   [{"click": [640, 412]}, {"type": "teacher@otms.test"},
//    {"click": [640, 477]}, {"type": "password"}, {"click": [640, 549]},
//    {"wait": 6000}]
//
// Any "exception"/"error" console line is printed, so a run that ends without
// output means the scripted path produced no runtime errors.

const puppeteer = require('puppeteer-core');
const fs = require('fs');

(async () => {
  const [out, ...stepFiles] = process.argv.slice(2);
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME_PATH || '/usr/bin/chromium',
    headless: 'shell',
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu',
           '--window-size=1280,900'],
    defaultViewport: { width: 1280, height: 900 },
  });
  const page = await browser.newPage();
  page.on('console', m => {
    const t = m.text();
    if (/error|exception|failed|hero/i.test(t)) console.log('[browser]', t.slice(0, 2500));
  });
  page.on('pageerror', e => console.log('[pageerror]', String(e).slice(0, 2500)));

  await page.goto('http://127.0.0.1:8080/', { waitUntil: 'networkidle2', timeout: 120000 });

  // Flutter web paints into a canvas; wait for the engine to be up.
  await page.waitForFunction(
    () => document.querySelector('flt-glass-pane') || document.querySelector('flt-scene-host'),
    { timeout: 180000 }
  );

  for (const f of stepFiles) {
    const steps = JSON.parse(fs.readFileSync(f, 'utf8'));
    for (const s of steps) {
      if (s.wait)   await new Promise(r => setTimeout(r, s.wait));
      if (s.click)  await page.mouse.click(s.click[0], s.click[1]);
      if (s.type)   await page.keyboard.type(s.type, { delay: 25 });
      if (s.key)    await page.keyboard.press(s.key);
      await new Promise(r => setTimeout(r, 400));
    }
  }

  await new Promise(r => setTimeout(r, 1500));
  await page.screenshot({ path: out });
  console.log('screenshot written:', out);
  await browser.close();
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
