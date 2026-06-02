/**
 * Centralised, composable mock backend for the admin portal Playwright tests.
 *
 * Usage:
 *
 *   import { test, expect } from '../fixtures/api-mock';
 *
 *   test('something', async ({ adminPage, api }) => {
 *     api.mockStats({ summary: { totalUsers: 42 } });
 *     await adminPage.goto('/');
 *     // ...
 *   });
 *
 * Why a fixture?
 *  - Lets every test customise individual endpoints without redeclaring all
 *    of them.
 *  - Routes are scoped to the `BrowserContext` so isolation between tests is
 *    automatic — no shared mutable state.
 *  - We seed sane defaults so a test that only cares about, e.g., the users
 *    table doesn't crash because /api/admin/stats was unmocked.
 */
import { test as base, expect, type Page, type BrowserContext } from '@playwright/test';

export type ApiResponse = {
  status?: number;
  body?: unknown;
  headers?: Record<string, string>;
};

export type ApiCallLog = {
  url: string;
  method: string;
  postData: string | null;
};

type Handler = (request: { url: string; method: string; postData: string | null }) => ApiResponse;

export class ApiMock {
  private handlers = new Map<string, Handler>();
  public calls: ApiCallLog[] = [];

  constructor(private readonly context: BrowserContext) {}

  /**
   * Install the route catcher. Matches every /api/** request and dispatches
   * it through the registered handlers (with sensible fallbacks).
   */
  async attach() {
    await this.context.route('**/api/**', async (route, request) => {
      const url = new URL(request.url());
      const pathname = url.pathname; // e.g. /api/admin/stats
      const method = request.method();
      const key = `${method} ${pathname}`;
      const wildcardKey = `* ${pathname}`;
      const postData = request.postData() || null;

      this.calls.push({ url: pathname + (url.search || ''), method, postData });

      const handler =
        this.handlers.get(key) ||
        this.handlers.get(wildcardKey) ||
        this.matchPattern(method, pathname);

      const response = handler
        ? handler({ url: request.url(), method, postData })
        : this.defaultResponse(pathname);

      await route.fulfill({
        status: response.status ?? 200,
        contentType: 'application/json; charset=utf-8',
        headers: response.headers,
        body: JSON.stringify(response.body ?? { success: true, data: [] }),
      });
    });
  }

  /** Register a handler for an exact `METHOD /api/path`. */
  on(method: string, path: string, handler: Handler | ApiResponse) {
    const wrapped: Handler =
      typeof handler === 'function' ? handler : () => handler;
    this.handlers.set(`${method.toUpperCase()} ${path}`, wrapped);
    return this;
  }

  /** Convenience helpers for the most common admin endpoints. */
  mockLogin(opts: { admin?: boolean; success?: boolean; status?: number } = {}) {
    const success = opts.success ?? true;
    return this.on('POST', '/api/auth/login', () => ({
      status: opts.status ?? (success ? 200 : 401),
      body: success
        ? {
            success: true,
            token: 'fake.admin.jwt',
            user: { id: 1, full_name: 'مدير', role: opts.admin === false ? 'driver' : 'admin' },
          }
        : { success: false, message: 'بيانات الدخول غير صحيحة' },
    }));
  }

  mockStats(payload: Record<string, unknown> = {}) {
    return this.on('GET', '/api/admin/stats', () => ({
      body: {
        success: true,
        data: {
          summary: {
            totalUsers: 42,
            driversCount: 25,
            companiesCount: 17,
            activeTrips: 7,
            completedTrips: 31,
            pendingBidsCount: 5,
            totalRevenue: 124500,
            pendingVerifications: 3,
            ...(payload as any).summary,
          },
          userStats: (payload as any).userStats ?? [
            { role: 'driver', total: 25 },
            { role: 'shipper', total: 17 },
          ],
          shipmentStats: (payload as any).shipmentStats ?? [
            { status: 'delivered', total: 31 },
            { status: 'en_route', total: 4 },
          ],
          pendingUsersCount: 3,
          recentShipments: (payload as any).recentShipments ?? [],
          activities: (payload as any).activities ?? [],
        },
      },
    }));
  }

  mockOverviewCharts(series?: Array<{ date: string; shipments: number; bids: number }>) {
    const defaultSeries = Array.from({ length: 7 }, (_, i) => ({
      date: new Date(Date.now() - (6 - i) * 86_400_000).toISOString().slice(0, 10),
      shipments: 2 + (i % 3),
      bids: 1 + (i % 4),
    }));
    return this.on('GET', '/api/admin/overview-charts', () => ({
      body: { success: true, data: { series: series ?? defaultSeries } },
    }));
  }

  mockBrowseUsers(rows: Array<Record<string, unknown>> = [], total = rows.length) {
    return this.on('GET', '/api/admin/users/browse', () => ({
      body: {
        success: true,
        data: rows,
        pagination: { page: 1, limit: 15, total, totalPages: Math.max(1, Math.ceil(total / 15)) },
      },
    }));
  }

  mockBrowseShipments(rows: Array<Record<string, unknown>> = [], total = rows.length) {
    return this.on('GET', '/api/admin/shipments/browse', () => ({
      body: {
        success: true,
        data: rows,
        pagination: { page: 1, limit: 20, total, totalPages: Math.max(1, Math.ceil(total / 20)) },
      },
    }));
  }

  mockPendingUsers(rows: Array<Record<string, unknown>> = []) {
    return this.on('GET', '/api/admin/pending-users', () => ({
      body: {
        success: true,
        data: rows,
        pagination: { page: 1, limit: 8, total: rows.length, totalPages: 1 },
      },
    }));
  }

  mockUserDetail(id: number, payload: Record<string, unknown>) {
    return this.on('GET', `/api/admin/users/${id}/detail`, () => ({
      body: { success: true, data: payload },
    }));
  }

  mockActivityFeed(rows: Array<Record<string, unknown>> = []) {
    return this.on('GET', '/api/admin/activity-feed', () => ({
      body: { success: true, data: rows },
    }));
  }

  mockNotifications(unreadCount = 0, items: Array<Record<string, unknown>> = []) {
    return this.on('GET', '/api/admin/notifications', () => ({
      body: { success: true, data: { unreadCount, items } },
    }));
  }

  /** Pattern-match URLs that include dynamic IDs (e.g. /users/123/active). */
  private matchPattern(method: string, pathname: string): Handler | null {
    if (method === 'PATCH' && /\/api\/admin\/users\/\d+\/active$/.test(pathname)) {
      return () => ({ body: { success: true } });
    }
    if (method === 'POST' && /\/api\/admin\/users\/\d+\/verify$/.test(pathname)) {
      return () => ({ body: { success: true, message: 'تم توثيق المستخدم بنجاح' } });
    }
    if (method === 'PATCH' && /\/api\/admin\/users\/\d+$/.test(pathname)) {
      return () => ({ body: { success: true } });
    }
    if (method === 'GET' && /\/api\/admin\/users\/\d+\/detail$/.test(pathname)) {
      return () => ({
        body: {
          success: true,
          data: { id: 1, full_name: 'تفاصيل افتراضية', role: 'driver', is_active: 1, trucks: [] },
        },
      });
    }
    return null;
  }

  /** Sane default responses so unmocked endpoints don't break the SPA. */
  private defaultResponse(pathname: string): ApiResponse {
    if (pathname.includes('/admin/notifications')) {
      return { body: { success: true, data: { unreadCount: 0, items: [] } } };
    }
    if (pathname.includes('/admin/activity-feed')) {
      return { body: { success: true, data: [] } };
    }
    if (pathname.includes('/admin/stats')) {
      return {
        body: {
          success: true,
          data: {
            summary: {},
            userStats: [],
            shipmentStats: [],
            pendingUsersCount: 0,
            recentShipments: [],
            activities: [],
          },
        },
      };
    }
    if (pathname.includes('/admin/overview-charts')) {
      return { body: { success: true, data: { series: [] } } };
    }
    if (pathname.includes('/browse')) {
      return {
        body: {
          success: true,
          data: [],
          pagination: { page: 1, limit: 15, total: 0, totalPages: 1 },
        },
      };
    }
    return { body: { success: true, data: [] } };
  }
}

type Fixtures = {
  api: ApiMock;
  adminPage: Page;
  authenticatedAdminPage: Page;
};

export const test = base.extend<Fixtures>({
  api: async ({ context }, use) => {
    const api = new ApiMock(context);
    await api.attach();
    api.mockLogin();
    api.mockStats();
    api.mockOverviewCharts();
    api.mockPendingUsers();
    api.mockNotifications();
    api.mockActivityFeed();
    await use(api);
  },

  adminPage: async ({ page }, use) => {
    await page.goto('/');
    await use(page);
  },

  authenticatedAdminPage: async ({ page }, use) => {
    await page.addInitScript(() => {
      window.localStorage.setItem('darbak_admin_token', 'fake.admin.jwt');
    });
    await page.goto('/');
    await use(page);
  },
});

export { expect };
