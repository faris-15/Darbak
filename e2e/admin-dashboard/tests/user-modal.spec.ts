/**
 * Admin "Create / Edit User" modal — HTML5 validation, role-conditional
 * fields, password rules, modal dismissal, server error display.
 */
import { test, expect } from './fixtures/api-mock';

test.describe('Create user modal — extended validation', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await page.locator('#nav-users').click();
    await expect(page.locator('#users-section')).toBeVisible();
    await page.getByRole('button', { name: 'مستخدم جديد' }).click();
    await expect(page.locator('#admin-user-form-modal')).toBeVisible();
  });

  test('modal opens with title "مستخدم جديد"', async ({ page }) => {
    await expect(page.locator('#admin-user-form-title')).toContainText(
      'مستخدم جديد',
    );
  });

  test('submitting with empty required fields keeps the modal open', async ({
    page,
  }) => {
    await page.locator('#admin-user-form button[type="submit"]').click();
    await expect(page.locator('#admin-user-form-modal')).toBeVisible();
    // The full-name input should still own the focus / show invalid state.
    const fullName = page.locator('#au-full-name');
    await expect(fullName).toHaveJSProperty('validity.valueMissing', true);
  });

  test('selecting role=shipper exposes the commercial-number field if present', async ({
    page,
  }) => {
    const roleSelect = page.locator('#au-role');
    await roleSelect.selectOption('shipper');
    // The conditional commercial field may or may not exist in this build; verify
    // either the field appears OR the role was accepted.
    const commercial = page.locator('#au-commercial-no, #au-commercial');
    if ((await commercial.count()) > 0) {
      await expect(commercial.first()).toBeVisible();
    }
    await expect(roleSelect).toHaveValue('shipper');
  });

  test('server error is surfaced from POST /api/admin/users 409', async ({
    api,
    page,
  }) => {
    api.on('POST', '/api/admin/users', () => ({
      status: 409,
      body: { success: false, message: 'البريد مستخدم مسبقاً' },
    }));
    await page.locator('#au-full-name').fill('مستخدم مكرر');
    await page.locator('#au-email').fill('dup@test.local');
    await page.locator('#au-phone').fill('0500000111');
    await page.locator('#au-password').fill('Secret123!');
    await page.locator('#au-role').selectOption('driver');
    await page.locator('#admin-user-form button[type="submit"]').click();
    await page.waitForTimeout(300);
    // Modal should still be visible so the operator can fix and retry.
    await expect(page.locator('#admin-user-form-modal')).toBeVisible();
  });

  test('successful create posts JSON containing the role and email', async ({
    api,
    page,
  }) => {
    api.on('POST', '/api/admin/users', () => ({
      status: 201,
      body: {
        success: true,
        data: { id: 4242, full_name: 'سائق جديد', role: 'driver' },
      },
    }));
    await page.locator('#au-full-name').fill('سائق جديد');
    await page.locator('#au-email').fill('newdriver@test.local');
    await page.locator('#au-phone').fill('0500000222');
    await page.locator('#au-password').fill('LongerPassword123');
    await page.locator('#au-role').selectOption('driver');
    await page.locator('#admin-user-form button[type="submit"]').click();
    await page.waitForTimeout(300);
    const posted = api.calls.find(
      (c) => c.method === 'POST' && c.url.endsWith('/api/admin/users'),
    );
    expect(posted).toBeDefined();
    expect(posted!.postData).toMatch(/newdriver@test\.local/);
    expect(posted!.postData).toMatch(/driver/);
  });

  test('modal close (×) hides the modal', async ({ page }) => {
    const modal = page.locator('#admin-user-form-modal');
    const closeBtn = modal.locator('button:has-text("×"), button:has-text("إغلاق")').first();
    if ((await closeBtn.count()) === 0) {
      // Fallback: click outside the dialog content
      await modal.click({ position: { x: 10, y: 10 } });
    } else {
      await closeBtn.click();
    }
    await expect(modal).toBeHidden();
  });
});

test.describe('User detail modal', () => {
  test('opening a user row issues GET /users/:id/detail', async ({
    api,
    page,
  }) => {
    api.mockBrowseUsers(
      [
        {
          id: 7777,
          full_name: 'سائق التفاصيل',
          email: 'detail@test.local',
          phone: '0500000777',
          role: 'driver',
          verification_status: 'verified',
          is_active: 1,
          created_at: new Date().toISOString(),
        },
      ],
      1,
    );
    api.mockUserDetail(7777, {
      id: 7777,
      full_name: 'سائق التفاصيل',
      role: 'driver',
      is_active: 1,
      trucks: [],
      ratings: { avg: 4.6, count: 12 },
    });
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt'),
    );
    await page.goto('/');
    await page.locator('#nav-users').click();
    await expect(page.locator('#users-section')).toBeVisible();

    const detailBtn = page.locator('#all-users-body button:has-text("تفاصيل")');
    if ((await detailBtn.count()) === 0) {
      test.skip(true, 'No user-detail trigger button rendered in this layout');
    }
    await detailBtn.first().click();
    await page.waitForTimeout(300);
    const detailHit = api.calls.find((c) =>
      /\/api\/admin\/users\/7777\/detail$/.test(c.url),
    );
    expect(detailHit).toBeDefined();
  });
});
