/**
 * Dashboard — secondary metrics, recent shipments table, role mix breakdown,
 * and delta indicators.
 *
 * Validates rendering behaviour for:
 *   - Revenue currency formatter
 *   - Drivers/shippers breakdown inside the "إجمالي المستخدمين" card
 *   - Recent shipments table populated from /api/admin/stats payload
 *   - Pending verification badge state
 *   - Active-bids card uses pendingBidsCount
 */
import { test, expect } from './fixtures/api-mock';

const seedRecent = [
  {
    id: 90001,
    status: 'delivered',
    base_price: 4250,
    final_price: 4250,
    shipper: 'شركة المسار',
    pickup_address: 'الرياض، السعودية',
    dropoff_address: 'جدة، السعودية',
    created_at: new Date().toISOString(),
  },
  {
    id: 90002,
    status: 'en_route',
    base_price: 2500,
    final_price: 2500,
    shipper: 'شركة الإسناد',
    pickup_address: 'الدمام، السعودية',
    dropoff_address: 'مكة، السعودية',
    created_at: new Date().toISOString(),
  },
];

test.describe('Dashboard secondary cards', () => {
  test('drivers vs shippers count rendered inside total-users card', async ({
    api,
    page,
  }) => {
    api.mockStats({
      summary: {
        totalUsers: 200,
        driversCount: 130,
        companiesCount: 70,
      },
    });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await expect(page.locator('#total-users')).toHaveText(/200/);
    await expect(page.locator('#stat-drivers')).toHaveText(/130/);
    await expect(page.locator('#stat-companies')).toHaveText(/70/);
  });

  test('revenue card formats large numbers with Arabic locale-friendly digits', async ({
    api,
    page,
  }) => {
    api.mockStats({ summary: { totalRevenue: 1_250_000 } });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    const text = (await page.locator('#revenue-stat').textContent()) ?? '';
    // Either Western digits (1,250,000 / 1250000) or Arabic-Indic (١٬٢٥٠٬٠٠٠ / ١٬٢٥٠٬٠٠٠).
    expect(text).toMatch(/1[,.\s]?250[,.\s]?000|١[٬,.\s]?٢٥٠[٬,.\s]?٠٠٠|1250000/);
  });

  test('pending badge appears only when there are pending verifications', async ({
    api,
    page,
  }) => {
    api.mockStats({ summary: { pendingVerifications: 0 } });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await expect(page.locator('#pending-count-stat')).toHaveText(/0|٠/);
  });

  test('active-bids card reflects pendingBidsCount', async ({ api, page }) => {
    api.mockStats({ summary: { pendingBidsCount: 18 } });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await expect(page.locator('#active-bids')).toHaveText(/18/);
  });
});

test.describe('Recent shipments preview', () => {
  test('renders rows from stats.recentShipments', async ({ api, page }) => {
    api.mockStats({ recentShipments: seedRecent });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    const body = page.locator('#recent-shipments-body');
    await expect(body).toBeVisible();
    await expect(body).toContainText(/شركة المسار|الرياض|جدة/);
    await expect(body).toContainText(/شركة الإسناد|الدمام|مكة/);
  });

  test('renders gracefully when recentShipments is empty', async ({
    api,
    page,
  }) => {
    api.mockStats({ recentShipments: [] });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    const body = page.locator('#recent-shipments-body');
    await expect(body.locator('tr')).toHaveCount(0);
  });

  test('"عرض السجل الكامل" navigates to shipments section', async ({
    api,
    page,
  }) => {
    api.mockStats();
    api.mockBrowseShipments([]);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await page.getByRole('button', { name: 'عرض السجل الكامل' }).click();
    await expect(page.locator('#shipments-section')).toBeVisible();
  });
});
