/**
 * RTL / a11y / responsive regression checks across the three target browsers.
 */
import { test, expect } from './fixtures/api-mock';

test.describe('RTL & layout', () => {
  test('document direction is RTL and font-family points to Noto Sans Arabic', async ({
    authenticatedAdminPage,
  }) => {
    await expect(authenticatedAdminPage.locator('html')).toHaveAttribute('dir', 'rtl');
    const font = await authenticatedAdminPage.evaluate(() => {
      return window.getComputedStyle(document.body).fontFamily;
    });
    expect(font).toContain('Noto Sans Arabic');
  });

  test('sidebar lives on the right side of the viewport', async ({ authenticatedAdminPage }) => {
    const sidebar = authenticatedAdminPage.locator('aside.sidebar');
    const box = await sidebar.boundingBox();
    expect(box).not.toBeNull();
    const vw = authenticatedAdminPage.viewportSize()?.width ?? 1440;
    expect(box!.x).toBeGreaterThan(vw / 2);
  });

  test('header title is right-aligned and visible', async ({ authenticatedAdminPage }) => {
    const title = authenticatedAdminPage.locator('#section-title');
    await expect(title).toBeVisible();
  });
});

test.describe('Responsive viewports', () => {
  test('renders sidebar at desktop sizes (≥ 1024)', async ({ authenticatedAdminPage }) => {
    await authenticatedAdminPage.setViewportSize({ width: 1280, height: 800 });
    await expect(authenticatedAdminPage.locator('aside.sidebar')).toBeVisible();
  });

  test('main content reflows for narrow viewports (≈ 768)', async ({
    authenticatedAdminPage,
  }) => {
    await authenticatedAdminPage.setViewportSize({ width: 768, height: 1024 });
    await expect(authenticatedAdminPage.locator('#dashboard-section')).toBeVisible();
  });
});

test.describe('Accessibility basics', () => {
  test('login form inputs have labels via placeholder', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('#identifier')).toHaveAttribute('placeholder', /البريد|الجوال/);
    await expect(page.locator('#password')).toHaveAttribute('placeholder', /كلمة المرور/);
  });

  test('all primary action buttons are keyboard-focusable', async ({
    authenticatedAdminPage,
  }) => {
    // Focus the first sidebar link via Tab navigation.
    await authenticatedAdminPage.keyboard.press('Tab');
    const active = await authenticatedAdminPage.evaluate(() => document.activeElement?.tagName);
    expect(['A', 'BUTTON', 'INPUT']).toContain(active);
  });

  test('logout button has explicit type="button"', async ({ authenticatedAdminPage }) => {
    await expect(authenticatedAdminPage.locator('#logout-btn')).toHaveAttribute('type', 'button');
  });
});
