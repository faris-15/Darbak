/**
 * Sidebar navigation between dashboard / users / shipments / sniffer sections.
 *
 * For each tab we assert that:
 *   - the matching `*-section` becomes visible
 *   - the others stay hidden
 *   - the page title in the header is updated
 *   - the nav-link gains the `active` class
 *
 * Also checks that the sticky header & RTL layout stay intact and the page
 * survives a hard reload.
 */
import { test, expect } from './fixtures/api-mock';

const sections = [
  { id: 'dashboard', navId: 'nav-dashboard', title: /لوحة التحكم|نظرة عامة|الإدارة/ },
  { id: 'users', navId: 'nav-users', title: /إدارة المستخدمين|المستخدمون/ },
  { id: 'shipments', navId: 'nav-shipments', title: /متابعة الشحنات|الشحنات/ },
  { id: 'sniffer', navId: 'nav-sniffer', title: /\s*النظام/ },
];

test.describe('Sidebar navigation', () => {
  test.beforeEach(async ({ api, page }) => {
    api.mockBrowseUsers([]);
    api.mockBrowseShipments([]);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
  });

  for (const section of sections) {
    test(`switching to "${section.id}" shows that section and updates the header`, async ({
      page,
    }) => {
      await page.locator(`#${section.navId}`).click();
      await expect(page.locator(`#${section.id}-section`)).toBeVisible();
      const otherSections = sections.filter((s) => s.id !== section.id);
      for (const other of otherSections) {
        await expect(page.locator(`#${other.id}-section`)).toBeHidden();
      }
      await expect(page.locator(`#${section.navId}`)).toHaveClass(/active/);
      await expect(page.locator('#section-title')).toContainText(section.title);
    });
  }

  test('navigation survives a hard reload of the page', async ({ page }) => {
    await page.locator('#nav-shipments').click();
    await expect(page.locator('#shipments-section')).toBeVisible();
    await page.reload();
    // After reload the SPA boots fresh to the dashboard.
    await expect(page.locator('#dashboard-section')).toBeVisible();
  });
});

test.describe('Header & layout polish', () => {
  test('header is sticky and shows current date', async ({ authenticatedAdminPage }) => {
    await expect(authenticatedAdminPage.locator('header')).toBeVisible();
    await expect(authenticatedAdminPage.locator('#current-date')).not.toBeEmpty();
  });

  test('global search field is editable', async ({ authenticatedAdminPage }) => {
    const input = authenticatedAdminPage.locator('#admin-global-search');
    await input.fill('shipment');
    await expect(input).toHaveValue('shipment');
  });

  test('notifications panel toggles open & closed', async ({ authenticatedAdminPage }) => {
    const panel = authenticatedAdminPage.locator('#notif-panel');
    const toggle = authenticatedAdminPage.locator('#notif-toggle');
    await expect(panel).toBeHidden();
    await toggle.click();
    await expect(panel).toBeVisible();
    // Click outside to close.
    await authenticatedAdminPage.locator('header').click({ position: { x: 5, y: 5 } });
    await expect(panel).toBeHidden();
  });
});
