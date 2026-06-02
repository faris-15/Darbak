/**
 * Shipments page — filter, search, status badges, pagination.
 */
import { test, expect } from './fixtures/api-mock';

const sampleShipments = [
  {
    id: 5001,
    status: 'delivered',
    base_price: 1500,
    final_price: 1450,
    shipper_name: 'شركة الفجر',
    driver_name: 'سائق ناصر',
    created_at: new Date().toISOString(),
  },
  {
    id: 5002,
    status: 'en_route',
    base_price: 2200,
    final_price: 2200,
    shipper_name: 'شركة الإنشاء',
    driver_name: 'سائق عبدالله',
    created_at: new Date().toISOString(),
  },
];

test.describe('Shipments page', () => {
  test.beforeEach(async ({ api, page }) => {
    api.mockBrowseShipments(sampleShipments, 2);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#nav-shipments').click();
    await expect(page.locator('#shipments-section')).toBeVisible();
  });

  test('lists shipments with shipper & driver names', async ({ page }) => {
    const body = page.locator('#all-shipments-body');
    await expect(body).toContainText('شركة الفجر');
    await expect(body).toContainText('شركة الإنشاء');
    await expect(body).toContainText(/سائق ناصر|سائق عبدالله/);
    await expect(body).toContainText(/delivered|en_route|تسليم|الطريق/);
  });

  test('status filter sends status query parameter', async ({ api, page }) => {
    await page.locator('#shipments-status').selectOption('delivered');
    await page.getByRole('button', { name: 'تطبيق' }).nth(0).click();
    await page.waitForTimeout(200);
    const last = api.calls
      .filter((c) => c.url.includes('/api/admin/shipments/browse'))
      .pop();
    expect(last?.url).toContain('status=delivered');
  });

  test('search field is included in the next request', async ({ api, page }) => {
    await page.locator('#shipments-search').fill('5001');
    await page.getByRole('button', { name: 'تطبيق' }).nth(0).click();
    await page.waitForTimeout(200);
    const last = api.calls
      .filter((c) => c.url.includes('/api/admin/shipments/browse'))
      .pop();
    expect(last?.url).toContain('q=5001');
  });

  test('date range filter is passed through', async ({ api, page }) => {
    await page.locator('#shipments-from').fill('2026-01-01');
    await page.locator('#shipments-to').fill('2026-05-01');
    await page.getByRole('button', { name: 'تطبيق' }).nth(0).click();
    await page.waitForTimeout(200);
    const last = api.calls
      .filter((c) => c.url.includes('/api/admin/shipments/browse'))
      .pop();
    expect(last?.url).toContain('dateFrom=2026-01-01');
    expect(last?.url).toContain('dateTo=2026-05-01');
  });

  test('pagination next button increments page query', async ({ api, page }) => {
    api.mockBrowseShipments(sampleShipments, 80);
    await page.getByRole('button', { name: 'التالي' }).nth(0).click();
    await page.waitForTimeout(200);
    const last = api.calls
      .filter((c) => c.url.includes('/api/admin/shipments/browse'))
      .pop();
    expect(last?.url).toMatch(/page=2/);
  });
});

test.describe('Shipments page — empty/error', () => {
  test('renders empty body when API returns no data', async ({ api, page }) => {
    api.mockBrowseShipments([], 0);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#nav-shipments').click();
    await expect(page.locator('#shipments-section')).toBeVisible();
  });

  test('SPA survives 500 from /shipments/browse', async ({ context, page }) => {
    await context.route('**/api/admin/shipments/browse**', (route) =>
      route.fulfill({ status: 500, body: '{}' })
    );
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#nav-shipments').click();
    await expect(page.locator('#shipments-section')).toBeVisible();
  });
});
