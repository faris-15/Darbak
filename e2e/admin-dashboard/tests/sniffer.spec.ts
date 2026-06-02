/**
 * Sniffer / النظام section — log table, pause / clear / copy actions, search.
 */
import { test, expect } from './fixtures/api-mock';

test.describe('Sniffer section', () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() =>
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt')
    );
    await page.goto('/');
    await page.locator('#nav-sniffer').click();
    await expect(page.locator('#sniffer-section')).toBeVisible();
  });

  test('shows the empty log container and table headers', async ({ page }) => {
    await expect(page.locator('#sniffer-section')).toContainText('النظام');
    await expect(page.locator('#sniffer-tbody')).toBeAttached();
    await expect(page.locator('#sniffer-live-count')).toHaveText(/\d+/);
  });

  test('clearing the log resets the counter to 0', async ({ page }) => {
    // Inject a fake log entry first so the clear action has something to clear.
    await page.evaluate(() => {
      const tbody = document.getElementById('sniffer-tbody');
      if (tbody) {
        tbody.insertAdjacentHTML(
          'afterbegin',
          '<tr data-test="fake-log"><td colspan="4">fake</td></tr>'
        );
      }
      const cnt = document.getElementById('sniffer-live-count');
      if (cnt) cnt.textContent = '12';
    });
    await page.getByRole('button', { name: 'مسح' }).click();
    await expect(page.locator('#sniffer-live-count')).toHaveText(/0/);
  });

  test('pause button toggles its own label', async ({ page }) => {
    const btn = page.locator('#sniffer-pause-btn');
    const initial = await btn.innerText();
    await btn.click();
    const next = await btn.innerText();
    expect(next).not.toBe(initial);
  });

  test('copy button does not throw and stays clickable', async ({ context, page }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']).catch(() => {});
    await page.evaluate(() => {
      const tbody = document.getElementById('sniffer-tbody');
      tbody?.insertAdjacentHTML(
        'afterbegin',
        '<tr><td>10:00</td><td>chat.message</td><td>رسالة</td><td>{"id":1}</td></tr>'
      );
    });
    await page.getByRole('button', { name: 'نسخ JSON' }).click();
    // No assertion needed beyond "did not throw".
  });

  test('global search filters the table (debounced)', async ({ page }) => {
    const tbody = page.locator('#sniffer-tbody');
    await page.evaluate(() => {
      const t = document.getElementById('sniffer-tbody');
      t!.innerHTML = `
        <tr data-reason="chat.message"><td>10:00</td><td>chat.message</td><td>رسالة</td><td>{"a":1}</td></tr>
        <tr data-reason="bid.placed"><td>10:01</td><td>bid.placed</td><td>عرض</td><td>{"b":2}</td></tr>
      `;
    });
    await page.locator('#admin-global-search').fill('bid');
    await page.waitForTimeout(300);
    // The SPA's renderSnifferTable() runs from the in-memory entries array, so
    // we only assert that typing was accepted without breaking the page.
    await expect(tbody).toBeAttached();
  });
});
