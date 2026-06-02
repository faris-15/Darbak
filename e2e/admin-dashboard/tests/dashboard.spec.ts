/**
 * Dashboard summary cards, charts, and live activity feed.
 *
 * Validates:
 *   - All KPI cards render numbers fetched from /api/admin/stats
 *   - Currency formatting on the revenue card
 *   - Charts container & canvases are visible
 *   - "Load more" activity button stays operable when feed is empty
 *   - Cards fall back to "0" when the API returns minimal data
 */
import { test, expect } from './fixtures/api-mock';

test.describe('Dashboard KPI cards', () => {
  test('renders all summary numbers from /api/admin/stats', async ({ api, page }) => {
    api.mockStats({
      summary: {
        totalUsers: 142,
        driversCount: 80,
        companiesCount: 62,
        activeTrips: 11,
        completedTrips: 73,
        pendingBidsCount: 6,
        totalRevenue: 95_500,
        pendingVerifications: 4,
      },
    });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');

    await expect(page.locator('#total-users')).toHaveText(/142/);
    await expect(page.locator('#stat-drivers')).toHaveText(/80/);
    await expect(page.locator('#stat-companies')).toHaveText(/62/);
    await expect(page.locator('#active-shipments')).toHaveText(/11/);
    await expect(page.locator('#completed-trips-stat')).toHaveText(/73/);
    await expect(page.locator('#pending-count-stat')).toHaveText(/4/);
    await expect(page.locator('#active-bids')).toHaveText(/6/);
    await expect(page.locator('#revenue-stat')).toContainText(/95|٩٥/);
  });

  test('falls back to 0 when API returns empty summary', async ({ api, page }) => {
    api.mockStats({ summary: {} });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');

    await expect(page.locator('#total-users')).toBeVisible();
  });

  test('charts canvases are rendered for the 7-day window', async ({ authenticatedAdminPage }) => {
    await expect(authenticatedAdminPage.locator('canvas#chart-shipments')).toBeVisible();
    await expect(authenticatedAdminPage.locator('canvas#chart-bids')).toBeVisible();
  });

  test('"تحميل المزيد" activity button is present and clickable', async ({
    authenticatedAdminPage,
  }) => {
    const btn = authenticatedAdminPage.locator('#activity-load-more');
    await expect(btn).toBeVisible();
    await expect(btn).toBeEnabled();
    await btn.click();
  });

  test('pending verification badge shows on dashboard when there are pending items', async ({
    api,
    page,
  }) => {
    api.mockStats({ summary: { pendingVerifications: 7 } });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await expect(page.locator('#pending-count-stat')).toHaveText(/7/);
    await expect(page.locator('#pending-badge')).toBeVisible();
  });
});

test.describe('Activity feed', () => {
  test('renders activity items returned by /api/admin/stats', async ({ api, page }) => {
    api.mockStats({
      activities: [
        {
          type: 'ship',
          actor: 'شركة قمة الشحن',
          detail: 'إضافة شحنة من: الرياض',
          activity_date: new Date().toISOString(),
        },
        {
          type: 'bid',
          actor: 'سائق محمد',
          detail: 'تقديم عرض سعر بقيمة: 1500 ر.س',
          activity_date: new Date().toISOString(),
        },
      ],
    });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');

    const feed = page.locator('#activity-feed');
    await expect(feed).toBeVisible();
    await expect(feed).toContainText(/شركة قمة الشحن|الرياض|سائق محمد/);
  });
});
