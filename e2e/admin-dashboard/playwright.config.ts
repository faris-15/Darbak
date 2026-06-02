/**
 * Playwright configuration for the Darbak admin dashboard.
 *
 * The admin dashboard is a single-page HTML application served by the Node
 * backend at `/admin`. For deterministic, hermetic e2e tests we serve the
 * static HTML file directly from a tiny local file server and use
 * `page.route()` (see `tests/fixtures/api-mock.ts`) to mock every `/api/*`
 * call. That keeps the suite reproducible across machines and CI without
 * requiring MySQL, Firebase, or S3.
 *
 * Browsers under test:
 *   - chromium     (stands in for Google Chrome)
 *   - edge         (Chromium with the bundled Microsoft Edge channel)
 *   - firefox      (Mozilla Firefox)
 *
 * Run all three:    npx playwright test
 * Run a single:     npx playwright test --project=firefox
 */
import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';

const PORT = Number(process.env.E2E_PORT || 4321);
const BASE_URL = `http://127.0.0.1:${PORT}`;
const REPORT_DIR = path.join(__dirname, 'playwright-report');

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: [
    ['list'],
    ['html', { outputFolder: REPORT_DIR, open: 'never' }],
    ['json', { outputFile: path.join(REPORT_DIR, 'results.json') }],
  ],
  timeout: 30_000,
  expect: { timeout: 7_500 },
  use: {
    baseURL: BASE_URL,
    locale: 'ar-SA',
    timezoneId: 'Asia/Riyadh',
    actionTimeout: 5_000,
    navigationTimeout: 12_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    ignoreHTTPSErrors: true,
    viewport: { width: 1440, height: 900 },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'edge',
      use: {
        ...devices['Desktop Edge'],
        channel: 'msedge',
      },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
  ],
  webServer: {
    command: `node ${path.join(__dirname, 'tools', 'serve-admin.js')} --port=${PORT}`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    stdout: 'pipe',
    stderr: 'pipe',
    timeout: 30_000,
  },
});
