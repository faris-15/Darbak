/**
 * Authentication & session management — admin portal login flow.
 *
 * Cross-browser regression coverage for:
 *   - successful login as an admin -> SPA opens, token persisted
 *   - rejected login when API returns 401
 *   - non-admin (driver/shipper) accounts blocked from the portal
 *   - token persistence across reloads
 *   - logout clears local storage and reloads the login screen
 *   - network failure surfaces a friendly Arabic error
 */
import { test, expect } from './fixtures/api-mock';

test.describe('Admin login screen', () => {
  test('renders Arabic login UI with RTL layout', async ({ adminPage }) => {
    await expect(adminPage.locator('html')).toHaveAttribute('dir', 'rtl');
    await expect(adminPage.locator('html')).toHaveAttribute('lang', 'ar');
    await expect(adminPage.locator('#login-screen')).toBeVisible();
    await expect(adminPage.locator('#login-form')).toBeVisible();
    await expect(adminPage.locator('text=تسجيل الدخول للوحة التحكم المركزية')).toBeVisible();
  });

  test('rejects non-admin accounts with an explicit message', async ({ api, adminPage }) => {
    api.mockLogin({ admin: false, success: true });
    await adminPage.locator('#identifier').fill('driver@test.local');
    await adminPage.locator('#password').fill('correct-password');
    await adminPage.locator('#login-form button[type="submit"]').click();
    await expect(adminPage.locator('#login-error')).toBeVisible();
    await expect(adminPage.locator('#login-error')).toContainText('صلاحيات الأدمن');
    await expect(adminPage.locator('#login-screen')).toBeVisible();
  });

  test('shows server error message on 401', async ({ api, adminPage }) => {
    api.mockLogin({ success: false, status: 401 });
    await adminPage.locator('#identifier').fill('wrong@test.local');
    await adminPage.locator('#password').fill('bad-password');
    await adminPage.locator('#login-form button[type="submit"]').click();
    await expect(adminPage.locator('#login-error')).toBeVisible();
    await expect(adminPage.locator('#login-error')).toContainText('بيانات الدخول غير صحيحة');
  });

  test('successful login hides the login screen and stores token', async ({ api, adminPage }) => {
    await adminPage.locator('#identifier').fill('admin@test.local');
    await adminPage.locator('#password').fill('correct-password');
    await adminPage.locator('#login-form button[type="submit"]').click();
    await expect(adminPage.locator('#login-screen')).toBeHidden();
    const token = await adminPage.evaluate(() => window.localStorage.getItem('darbak_admin_token'));
    expect(token).toBe('fake.admin.jwt');
  });

  test('network failure surfaces a friendly error', async ({ context, adminPage }) => {
    await context.route('**/api/auth/login', (route) => route.abort('failed'));
    await adminPage.locator('#identifier').fill('admin@test.local');
    await adminPage.locator('#password').fill('any-password');
    await adminPage.locator('#login-form button[type="submit"]').click();
    await expect(adminPage.locator('#login-error')).toBeVisible();
    await expect(adminPage.locator('#login-error')).toContainText('خطأ في الاتصال');
  });

  test('form refuses to submit when fields are empty (HTML validation)', async ({ adminPage }) => {
    await adminPage.locator('#login-form button[type="submit"]').click();
    await expect(adminPage.locator('#login-screen')).toBeVisible();
    const id = adminPage.locator('#identifier');
    await expect(id).toHaveJSProperty('validity.valueMissing', true);
  });
});

test.describe('Authenticated session', () => {
  test('SPA boots straight to dashboard when token already in localStorage', async ({ authenticatedAdminPage }) => {
    await expect(authenticatedAdminPage.locator('#login-screen')).toBeHidden();
    await expect(authenticatedAdminPage.locator('#dashboard-section')).toBeVisible();
    await expect(authenticatedAdminPage.locator('#section-title')).toContainText('لوحة التحكم');
  });

  test('logout clears token and reloads the login screen', async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'));
    await page.reload();
    await expect(page.locator('#dashboard-section')).toBeVisible();

    await page.locator('#logout-btn').click();
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('#login-screen')).toBeVisible({ timeout: 10_000 });
    const token = await page.evaluate(() =>
      window.localStorage.getItem('darbak_admin_token')
    );
    expect(token).toBeNull();
  });
});
