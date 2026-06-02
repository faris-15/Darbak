/**
 * Notification bell — badge, panel rendering, mark-all-as-read flow.
 *
 * Covers:
 *  - Unread count badge visibility for 0 / 1+ unread notifications
 *  - Panel toggle open/close
 *  - Renders notification rows from /api/admin/notifications
 *  - "تعليم الكل" calls POST /api/admin/notifications/read with all unread keys
 *  - SPA tolerates a 5xx from notifications endpoint
 */
import { test, expect } from './fixtures/api-mock';

const sampleNotifs = [
  {
    id: 11,
    key: 'verification:11',
    title: 'طلب توثيق جديد',
    body: 'سائق جديد بانتظار المراجعة',
    type: 'verification',
    is_read: 0,
    read: false,
    created_at: new Date(Date.now() - 2 * 60_000).toISOString(),
  },
  {
    id: 12,
    key: 'shipment:12',
    title: 'شحنة مكتملة',
    body: 'تم تسليم الشحنة #5001 بنجاح',
    type: 'shipment',
    is_read: 0,
    read: false,
    created_at: new Date(Date.now() - 30 * 60_000).toISOString(),
  },
  {
    id: 13,
    key: 'system:13',
    title: 'تنبيه نظام',
    body: 'إعادة تشغيل مجدولة',
    type: 'system',
    is_read: 1,
    read: true,
    created_at: new Date(Date.now() - 24 * 3_600_000).toISOString(),
  },
];

test.describe('Notification bell — badge & panel', () => {
  test('unread badge is hidden when unreadCount = 0', async ({ api, page }) => {
    api.mockNotifications(0, []);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await expect(page.locator('#notif-badge')).toBeHidden();
  });

  test('unread badge appears with non-zero count', async ({ api, page }) => {
    api.mockNotifications(2, sampleNotifs);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await expect(page.locator('#notif-badge')).toBeVisible();
    await expect(page.locator('#notif-badge')).toHaveText(/[12]/);
  });

  test('toggle opens panel and renders notification rows', async ({
    api,
    page,
  }) => {
    api.mockNotifications(2, sampleNotifs);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#notif-toggle').click();
    await expect(page.locator('#notif-panel')).toBeVisible();
    const list = page.locator('#notif-list');
    await expect(list).toContainText(/طلب توثيق|شحنة مكتملة|تنبيه نظام/);
  });

  test('"تعليم الكل" sends a mark-all-read request', async ({ api, page }) => {
    api.mockNotifications(2, sampleNotifs);
    api.on('POST', '/api/admin/notifications/read', () => ({
      body: { success: true },
    }));
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#notif-toggle').click();
    await page.getByRole('button', { name: 'تعليم الكل' }).click();
    await page.waitForTimeout(250);
    const posted = api.calls.find(
      (c) =>
        c.method === 'POST' && c.url.includes('/api/admin/notifications/read'),
    );
    expect(posted).toBeTruthy();
    expect(posted?.postData ?? '').toContain('verification:11');
    expect(posted?.postData ?? '').toContain('shipment:12');
  });

  test('500 from notifications endpoint does not crash the SPA', async ({
    context,
    page,
  }) => {
    await context.route('**/api/admin/notifications**', (route) =>
      route.fulfill({ status: 500, body: '{}' }),
    );
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await expect(page.locator('#dashboard-section')).toBeVisible();
    await expect(page.locator('#notif-toggle')).toBeVisible();
  });

  test('panel closes when clicking outside the bell', async ({
    api,
    page,
  }) => {
    api.mockNotifications(1, sampleNotifs.slice(0, 1));
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#notif-toggle').click();
    await expect(page.locator('#notif-panel')).toBeVisible();
    await page.locator('#dashboard-section').click({
      position: { x: 50, y: 200 },
    });
    await expect(page.locator('#notif-panel')).toBeHidden();
  });
});
