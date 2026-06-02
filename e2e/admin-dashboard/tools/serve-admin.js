#!/usr/bin/env node
/**
 * Tiny static file server used by Playwright as a `webServer`.
 *
 * Why a custom server instead of `http-server`? We need to:
 *   - serve `backend/admin_portal/index.html` at both `/` and `/admin`
 *   - serve static assets from `assets/`
 *   - return 200 for the `/api/auth/login` *preflight* so the CSP origin
 *     resolves; the actual response is intercepted by `page.route()` in tests
 *
 * No external dependencies — only the Node standard library.
 */
'use strict';

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { URL } = require('node:url');

const args = process.argv.slice(2);
const portArg = args.find((a) => a.startsWith('--port='));
const PORT = Number(portArg ? portArg.split('=')[1] : process.env.PORT || 4321);

const ROOT = path.resolve(__dirname, '..', '..', '..');
const ADMIN_HTML = path.join(ROOT, 'backend', 'admin_portal', 'index.html');
const ASSETS_DIR = path.join(ROOT, 'assets');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const sendFile = (res, filePath, status = 200) => {
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not Found');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(status, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': '*',
    });
    fs.createReadStream(filePath).pipe(res);
  });
};

const server = http.createServer((req, res) => {
  try {
    const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
    const pathname = decodeURIComponent(url.pathname);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS',
      });
      res.end();
      return;
    }

    // Health probe used by Playwright's webServer to know the port is up.
    if (pathname === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }

    if (pathname === '/' || pathname === '/admin' || pathname === '/admin/') {
      sendFile(res, ADMIN_HTML);
      return;
    }

    // Allow Playwright tests to intercept any /api/* call with page.route().
    // If the test forgot to mock the call, return a stub 200 so the SPA stays
    // alive instead of breaking on a CORS preflight.
    if (pathname.startsWith('/api/')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, data: [] }));
      return;
    }

    if (pathname.startsWith('/assets/')) {
      const rel = pathname.replace(/^\/assets\//, '');
      sendFile(res, path.join(ASSETS_DIR, rel));
      return;
    }

    if (pathname.startsWith('/admin/')) {
      sendFile(res, ADMIN_HTML);
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not Found');
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(`Server error: ${err.message}`);
  }
});

server.listen(PORT, '127.0.0.1', () => {
  // eslint-disable-next-line no-console
  console.log(`[admin-e2e] static admin portal on http://127.0.0.1:${PORT}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
