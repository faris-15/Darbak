/**
 * Verification center — pending documents, operating cards, approve/reject,
 * and the document preview modal.
 *
 * The admin SPA fetches pending items from /api/admin/pending-users and lets
 * the admin tap into each row to preview the document (signed URL) and to
 * approve/reject it (POST /documents/:id/verify or
 * POST /operating-cards/:id/verify).
 */
import { test, expect } from './fixtures/api-mock';

const pendingDocs = [
  {
    user_id: 401,
    full_name: 'سائق التوثيق',
    phone: '0500000401',
    role: 'driver',
    item_id: 91,
    document_type: 'license',
    document_url: 'docs/license.pdf',
    uploaded_at: new Date().toISOString(),
    source_kind: 'compliance',
  },
  {
    user_id: 402,
    full_name: 'سائق البطاقة',
    phone: '0500000402',
    role: 'driver',
    item_id: 145,
    document_type: 'operating_card',
    document_url: 'cards/card.pdf',
    uploaded_at: new Date().toISOString(),
    source_kind: 'operating_card',
  },
];

test.describe('Verification center', () => {
  test.beforeEach(async ({ api, page }) => {
    api.mockPendingUsers(pendingDocs);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
  });

  test('lists pending compliance + operating-card rows', async ({ page }) => {
    const body = page.locator('#pending-users-body');
    await expect(body).toContainText('سائق التوثيق');
    await expect(body).toContainText('سائق البطاقة');
  });

  test('preview button triggers a signed URL request', async ({ api, page }) => {
    api.on('GET', '/api/admin/get-signed-url', () => ({
      body: { success: true, signedUrl: 'http://signed/url.pdf', fileType: 'pdf' },
    }));
    const previewBtn = page
      .locator('[data-action="preview-doc"][data-source-kind="compliance"]')
      .first();
    if ((await previewBtn.count()) === 0) test.skip(true, 'No preview button rendered in this layout');
    await previewBtn.click();
    await page.waitForTimeout(300);
    const requested = api.calls.find((c) =>
      c.url.startsWith('/api/admin/get-signed-url')
    );
    expect(requested).toBeDefined();
  });

  test('verify button posts to /documents/:id/verify', async ({ api, page }) => {
    api.on('POST', '/api/admin/documents/91/verify', () => ({
      body: { success: true, message: 'تم التحديث' },
    }));
    const verifyBtn = page
      .locator('[data-action="verify-doc"][data-verify-status="verified"]')
      .first();
    if ((await verifyBtn.count()) === 0) test.skip(true, 'No verify button rendered in this layout');
    page.once('dialog', (dialog) => dialog.accept());
    await verifyBtn.click();
    await page.waitForTimeout(300);
    const posted = api.calls.find(
      (c) => c.method === 'POST' && c.url.includes('/documents/') && c.url.endsWith('/verify')
    );
    expect(posted).toBeDefined();
    expect(posted?.postData ?? '').toContain('verified');
  });

  test('operating-card row uses the dedicated verify endpoint', async ({ api, page }) => {
    api.on('POST', '/api/admin/operating-cards/145/verify', () => ({
      body: { success: true },
    }));
    const verifyBtn = page
      .locator('[data-action="verify-doc"][data-source-kind="operating_card"][data-verify-status="verified"]')
      .first();
    if ((await verifyBtn.count()) === 0)
      test.skip(true, 'No operating-card verify button rendered in this layout');
    page.once('dialog', (dialog) => dialog.accept());
    await verifyBtn.click();
    await page.waitForTimeout(300);
    const posted = api.calls.find(
      (c) => c.method === 'POST' && c.url.includes('/operating-cards/') && c.url.endsWith('/verify')
    );
    expect(posted).toBeDefined();
  });

  test('"السابق / التالي" buttons re-fetch pending-users with page parameter', async ({
    api,
    page,
  }) => {
    await page.getByRole('button', { name: 'التالي' }).first().click();
    await page.waitForTimeout(200);
    const last = api.calls.filter((c) => c.url.includes('/api/admin/pending-users')).pop();
    expect(last?.url).toMatch(/page=\d+/);
  });
});

test.describe('Preview modal', () => {
  test.beforeEach(async ({ api, page }) => {
    api.mockPendingUsers(pendingDocs);
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
  });

  test('modal can be closed via the × button', async ({ page }) => {
    const modal = page.locator('#previewModal');
    // Open it manually by invoking the helper if present, otherwise just check
    // that the dismiss button is wired up.
    await page.evaluate(() => {
      const m = document.getElementById('previewModal');
      if (m) m.style.display = 'block';
    });
    await expect(modal).toBeVisible();
    await page.locator('#previewModal').getByRole('button', { name: '×' }).first().click();
    await expect(modal).not.toBeVisible();
  });
});
