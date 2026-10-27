const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const path = require('node:path');

const productionUrl = process.env.LMS_PRODUCTION_PREVIEW || 'http://127.0.0.1:8080/';
const showcaseUrl = process.env.LMS_SHOWCASE_PREVIEW || 'http://127.0.0.1:8081/';
const output = process.env.LMS_SCREENSHOT_DIR || 'docs/images';

async function waitForFlutter(page) {
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 60000 });
  await page.waitForTimeout(3500);
  const semantics = page.locator('flt-semantics-placeholder');
  if (await semantics.count()) {
    await semantics.first().click({ force: true }).catch(() => {});
    await page.waitForTimeout(500);
  }
}

async function open(page, url) {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
  await waitForFlutter(page);
}

(async () => {
  await fs.mkdir(output, { recursive: true });
  const browser = await chromium.launch({ headless: true });

  const mobile = await browser.newPage({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
  });
  await open(mobile, productionUrl);
  await mobile.screenshot({
    path: path.join(output, 'login-mobile.png'),
    fullPage: false,
  });
  await mobile.close();

  const teacher = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
  });
  await open(teacher, `${showcaseUrl}?role=teacher`);
  await teacher.screenshot({
    path: path.join(output, 'teacher-dashboard.png'),
    fullPage: false,
  });

  // Use the physical center of the first card. Flutter's semantics tree is
  // useful for assertions, but direct CanvasKit pointer coordinates are more
  // stable for activating an InkWell in headless screenshot builds.
  await teacher.mouse.click(465, 690);
  await teacher.waitForTimeout(2500);
  await teacher.screenshot({
    path: path.join(output, 'class-workspace.png'),
    fullPage: false,
  });
  await teacher.close();

  const student = await browser.newPage({
    viewport: { width: 1280, height: 900 },
    deviceScaleFactor: 1,
  });
  await open(student, `${showcaseUrl}?role=student`);
  await student.screenshot({
    path: path.join(output, 'student-dashboard.png'),
    fullPage: false,
  });
  await student.close();

  await browser.close();
  console.log(`Portfolio screenshots written to ${output}`);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
