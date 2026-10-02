// Fails if the compiled Flutter web app cannot boot or reports a browser error.
const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const output = process.argv[2] || 'web-smoke.png';
  const appUrl = process.env.APP_URL || 'http://127.0.0.1:8080/';
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const errors = [];

  // A fresh Web session probes csrf.php to discover whether an HttpOnly cookie
  // already exists. Keep this static-build smoke deterministic without hiding
  // failures from any same-origin application asset.
  await page.route('**/csrf.php', route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ csrf_token: null }),
    }),
  );
  await page.route('**/me.php', route =>
    route.fulfill({
      status: 401,
      contentType: 'application/json',
      body: JSON.stringify({
        error: { code: 'UNAUTHORIZED', message: 'No smoke-test session' },
      }),
    }),
  );

  page.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
  page.on('console', message => {
    const text = message.text();
    const expectedAnonymousProbe =
      text.includes('status of 401') && text.includes('Unauthorized');
    if (message.type() === 'error' && !expectedAnonymousProbe) {
      errors.push(`console: ${text}`);
    }
  });
  page.on('response', response => {
    const url = new URL(response.url());
    const appOrigin = new URL(appUrl).origin;
    if (url.origin === appOrigin && response.status() >= 400) {
      errors.push(`HTTP ${response.status()}: ${response.url()}`);
    }
  });
  page.on('requestfailed', request => {
    const url = new URL(request.url());
    if (url.origin === new URL(appUrl).origin) {
      errors.push(`request failed: ${request.url()} (${request.failure()?.errorText})`);
    }
  });

  await page.goto(appUrl, { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForFunction(
    () => document.querySelector('flt-glass-pane') ||
          document.querySelector('flt-scene-host') ||
          document.querySelector('flutter-view'),
    null,
    { timeout: 120000 },
  );
  await page.waitForTimeout(2500);
  await page.screenshot({ path: output, fullPage: true });
  await browser.close();

  const uniqueErrors = [...new Set(errors)];
  if (uniqueErrors.length) {
    console.error(uniqueErrors.join('\n'));
    process.exit(1);
  }
  if (!fs.existsSync(output) || fs.statSync(output).size < 1000) {
    throw new Error('Smoke-test screenshot was not created correctly.');
  }
  console.log(`Flutter web booted without browser errors: ${output}`);
})().catch(error => {
  console.error(`FAILED: ${error.stack || error}`);
  process.exit(1);
});
