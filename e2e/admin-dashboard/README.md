# Darbak Admin Dashboard — Playwright E2E

Cross-browser regression suite for the admin SPA at
`backend/admin_portal/index.html`.

## Browsers under test

| Project    | Engine          | Channel  |
|------------|-----------------|----------|
| `chromium` | Chromium        | -        |
| `edge`     | Chromium        | `msedge` |
| `firefox`  | Mozilla Gecko   | -        |

Each spec runs in all three browsers.

## Setup (one time)

```bash
cd e2e/admin-dashboard
npm install
npx playwright install
# Optionally install the Edge channel:
npx playwright install msedge
```

## Run

```bash
# all browsers
npm test

# one browser
npm run test:chromium
npm run test:edge
npm run test:firefox

# open the HTML report
npm run report
```

## How it works

- `tools/serve-admin.js` is a 0-dependency Node static server. Playwright's
  `webServer` boots it on port `4321` (configurable via `E2E_PORT`).
- The server serves `backend/admin_portal/index.html` at `/` and `/admin`,
  and falls back to a stub `{ success: true, data: [] }` for any `/api/**`
  request that isn't intercepted by a test.
- `tests/fixtures/api-mock.ts` provides an `ApiMock` Playwright fixture that
  wires `page.route('**/api/**', …)`, captures every call into `api.calls`
  for assertions, and ships with composable helpers like
  `api.mockStats(...)`, `api.mockBrowseUsers(...)`, etc.
- Tests are written with `test.describe` blocks per feature area
  (auth, dashboard, navigation, users, shipments, verification, sniffer,
  rtl & accessibility).

## Adding a new test

1. `import { test, expect } from './fixtures/api-mock';`
2. Either request `adminPage` (loads `/` already navigated) or
   `authenticatedAdminPage` (seeds a fake admin token in localStorage so the
   SPA boots straight into the dashboard).
3. Mock any endpoints your test cares about via the `api` fixture.
4. Make UI assertions against the SPA's stable DOM ids.

```ts
test('my new flow', async ({ api, authenticatedAdminPage }) => {
  api.on('GET', '/api/admin/something', () => ({ body: { success: true, data: [] } }));
  await authenticatedAdminPage.locator('#nav-users').click();
  await expect(authenticatedAdminPage.locator('#users-section')).toBeVisible();
});
```
