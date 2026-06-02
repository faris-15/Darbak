#!/usr/bin/env node
/**
 * Darbak QA Report generator.
 *
 * Runs the backend Jest suite (with coverage) and the Flutter test suite
 * (with coverage), collects:
 *   - per-suite / per-test pass/fail metadata
 *   - backend coverage-summary.json
 *   - Flutter lcov.info (parsed line-level coverage)
 * and writes a single self-contained, professional HTML dashboard at
 *   docs/test-report/index.html
 *
 * The script never fails on red tests — failed runs still produce a report
 * so engineers can open it and see exactly which assertions broke.
 *
 * Usage:
 *   node tool/generate_test_report.js
 *   node tool/generate_test_report.js --skip-run    # just regenerate from cached artefacts
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const repoRoot = path.resolve(__dirname, '..');
const backendDir = path.join(repoRoot, 'backend');
const adminE2eDir = path.join(repoRoot, 'e2e', 'admin-dashboard');
const adminE2eTestsDir = path.join(adminE2eDir, 'tests');
const reportDir = path.join(repoRoot, 'docs', 'test-report');
const tmpDir = path.join(repoRoot, '.tmp-qa-report');
const skipRun = process.argv.includes('--skip-run');

fs.mkdirSync(tmpDir, { recursive: true });
fs.mkdirSync(reportDir, { recursive: true });

const log = (...args) => console.log('[qa-report]', ...args);

// ---------------------------------------------------------------------------
// 1. Run backend tests
// ---------------------------------------------------------------------------

const jestJsonPath = path.join(tmpDir, 'jest.json');

if (!skipRun) {
  log('Running backend Jest suite with coverage...');
  const result = spawnSync(
    'npx',
    [
      'jest',
      '--runInBand',
      '--ci',
      '--coverage',
      '--json',
      `--outputFile=${jestJsonPath}`,
    ],
    {
      cwd: backendDir,
      stdio: 'inherit',
      shell: true,
      env: { ...process.env, FORCE_COLOR: '0' },
    },
  );
  log('Backend Jest exit code:', result.status);
}

if (!fs.existsSync(jestJsonPath)) {
  console.error('[qa-report] Backend results not found at', jestJsonPath);
  process.exit(1);
}

const jest = JSON.parse(fs.readFileSync(jestJsonPath, 'utf8'));

// ---------------------------------------------------------------------------
// 2. Run Flutter tests
// ---------------------------------------------------------------------------

const flutterNdjsonPath = path.join(tmpDir, 'flutter.ndjson');

if (!skipRun) {
  log('Running Flutter test suite with coverage...');
  const result = spawnSync('flutter', ['test', '--machine', '--coverage'], {
    cwd: repoRoot,
    shell: true,
    env: { ...process.env, FORCE_COLOR: '0' },
  });
  if (result.error || result.status === null) {
    log('Flutter SDK not found, skipping Flutter run.', result.error?.message || '');
  }
  if (result.stdout && result.stdout.length > 0) {
    fs.writeFileSync(flutterNdjsonPath, result.stdout);
  }
  log('Flutter exit code:', result.status);
}

let flutterEvents = [];
if (fs.existsSync(flutterNdjsonPath)) {
  const raw = fs.readFileSync(flutterNdjsonPath, 'utf8');
  flutterEvents = raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith('{'))
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

// ---------------------------------------------------------------------------
// 3. Build backend test summary
// ---------------------------------------------------------------------------

const backendSuites = jest.testResults.map((suite) => {
  const assertions = suite.assertionResults || suite.testResults || [];
  const numFailing = assertions.filter((t) => t.status === 'failed').length;
  const numPassing = assertions.filter((t) => t.status === 'passed').length;
  const numPending = assertions.filter((t) => t.status === 'pending' || t.status === 'skipped').length;
  const numTodo = assertions.filter((t) => t.status === 'todo').length;
  const startTime = suite.startTime || 0;
  const endTime = suite.endTime || 0;
  const durationMs = suite.perfStats?.runtime ?? Math.max(0, endTime - startTime);
  return {
    file: relPath(suite.testFilePath || suite.name || 'unknown', backendDir),
    status: suite.status,
    durationMs,
    numFailing,
    numPassing,
    numPending,
    numTodo,
    failureMessage: suite.failureMessage || suite.message || null,
    tests: assertions.map((t) => ({
      title: [...(t.ancestorTitles || []), t.title || t.fullName || ''].filter(Boolean).join(' › '),
      status: t.status,
      durationMs: t.duration ?? 0,
      failureMessages: t.failureMessages || [],
    })),
  };
});

const backendTotals = {
  total: jest.numTotalTests,
  passed: jest.numPassedTests,
  failed: jest.numFailedTests,
  pending: jest.numPendingTests,
  todo: jest.numTodoTests,
  suites: jest.numTotalTestSuites,
  failedSuites: jest.numFailedTestSuites,
  passedSuites: jest.numPassedTestSuites,
  durationMs: backendSuites.reduce((sum, suite) => sum + (suite.durationMs || 0), 0),
  success: jest.success,
  startTime: jest.startTime,
};

// ---------------------------------------------------------------------------
// 4. Build Flutter test summary
// ---------------------------------------------------------------------------

const flutterTests = new Map();
const flutterSuites = new Map();
let flutterStartTime = null;
let flutterEndTime = null;
let flutterSuccess = null;

for (const event of flutterEvents) {
  if (event.type === 'start' && flutterStartTime == null) flutterStartTime = event.time;
  if (event.type === 'allSuites' && event.success != null) flutterSuccess = event.success;
  if (event.type === 'done') {
    flutterSuccess = event.success ?? flutterSuccess;
    flutterEndTime = event.time;
  }

  if (event.type === 'suite' && event.suite) {
    flutterSuites.set(event.suite.id, {
      ...event.suite,
      tests: [],
    });
  }
  if (event.type === 'testStart' && event.test) {
    const test = {
      id: event.test.id,
      suiteID: event.test.suiteID,
      name: event.test.name,
      url: event.test.url,
      line: event.test.line,
      column: event.test.column,
      startTime: event.time,
      status: 'running',
      hidden: false,
    };
    flutterTests.set(event.test.id, test);
  }
  if (event.type === 'testDone' && event.testID != null) {
    const test = flutterTests.get(event.testID);
    if (!test) continue;
    test.status = event.result || 'unknown';
    test.skipped = !!event.skipped;
    test.hidden = !!event.hidden;
    test.endTime = event.time;
    test.durationMs =
      typeof test.startTime === 'number' && typeof test.endTime === 'number'
        ? Math.max(0, test.endTime - test.startTime)
        : 0;
  }
  if (event.type === 'error' && event.testID != null) {
    const test = flutterTests.get(event.testID);
    if (!test) continue;
    test.errorMessages = test.errorMessages || [];
    test.errorMessages.push({
      error: event.error,
      stackTrace: event.stackTrace,
      isFailure: !!event.isFailure,
    });
  }
}

const flutterSuiteList = [...flutterSuites.values()].map((suite) => {
  const tests = [...flutterTests.values()].filter((t) => t.suiteID === suite.id && !t.hidden);
  const numFailing = tests.filter((t) => t.status === 'error' || t.status === 'failure').length;
  const numPassing = tests.filter((t) => t.status === 'success').length;
  const numPending = tests.filter((t) => t.skipped).length;
  return {
    file: (suite.path || 'unknown').replace(/\\/g, '/'),
    platform: suite.platform || '',
    durationMs: tests.reduce((sum, t) => sum + (t.durationMs || 0), 0),
    numFailing,
    numPassing,
    numPending,
    status: numFailing > 0 ? 'failed' : 'passed',
    tests: tests.map((t) => ({
      title: t.name,
      status:
        t.status === 'success'
          ? 'passed'
          : t.status === 'error' || t.status === 'failure'
            ? 'failed'
            : t.skipped
              ? 'skipped'
              : t.status,
      durationMs: t.durationMs || 0,
      errorMessages: (t.errorMessages || []).map((e) => `${e.error}\n${e.stackTrace || ''}`),
    })),
  };
});

const flutterTotals = flutterSuiteList.reduce(
  (acc, suite) => {
    acc.total += suite.tests.length;
    acc.passed += suite.numPassing;
    acc.failed += suite.numFailing;
    acc.pending += suite.numPending;
    acc.suites += 1;
    if (suite.numFailing > 0) acc.failedSuites += 1;
    else acc.passedSuites += 1;
    acc.durationMs += suite.durationMs;
    return acc;
  },
  {
    total: 0,
    passed: 0,
    failed: 0,
    pending: 0,
    suites: 0,
    passedSuites: 0,
    failedSuites: 0,
    durationMs: 0,
    success: flutterSuccess !== false,
    startTime: flutterStartTime,
  },
);

// ---------------------------------------------------------------------------
// 5. Admin dashboard Playwright results
// ---------------------------------------------------------------------------

const playwrightJsonPath = path.join(adminE2eDir, 'playwright-report', 'results.json');
let adminSuiteList = [];
if (fs.existsSync(playwrightJsonPath)) {
  const playwright = JSON.parse(fs.readFileSync(playwrightJsonPath, 'utf8'));
  adminSuiteList = parsePlaywrightSuites(playwright);
}

const adminTotals = adminSuiteList.reduce(
  (acc, suite) => {
    acc.total += suite.tests.length;
    acc.passed += suite.numPassing;
    acc.failed += suite.numFailing;
    acc.pending += suite.numPending;
    acc.suites += 1;
    if (suite.numFailing > 0) acc.failedSuites += 1;
    else acc.passedSuites += 1;
    acc.durationMs += suite.durationMs;
    return acc;
  },
  {
    total: 0,
    passed: 0,
    failed: 0,
    pending: 0,
    suites: 0,
    passedSuites: 0,
    failedSuites: 0,
    durationMs: 0,
    success: adminSuiteList.every((suite) => suite.numFailing === 0),
  },
);

// ---------------------------------------------------------------------------
// 6. Coverage parsing
// ---------------------------------------------------------------------------

const backendCoverageSummaryPath = path.join(backendDir, 'coverage', 'coverage-summary.json');
let backendCoverageSummary = null;
let backendCoverageFiles = [];
if (fs.existsSync(backendCoverageSummaryPath)) {
  const json = JSON.parse(fs.readFileSync(backendCoverageSummaryPath, 'utf8'));
  backendCoverageSummary = json.total;
  backendCoverageFiles = Object.entries(json)
    .filter(([key]) => key !== 'total')
    .map(([file, data]) => ({
      file: relPath(file, backendDir),
      lines: data.lines.pct,
      statements: data.statements.pct,
      functions: data.functions.pct,
      branches: data.branches.pct,
      linesCovered: data.lines.covered,
      linesTotal: data.lines.total,
    }))
    .sort((a, b) => a.file.localeCompare(b.file));
}

const flutterLcovPath = path.join(repoRoot, 'coverage', 'lcov.info');
let flutterCoverageFiles = [];
let flutterCoverageTotal = null;
if (fs.existsSync(flutterLcovPath)) {
  const lcov = fs.readFileSync(flutterLcovPath, 'utf8');
  let current = null;
  for (const rawLine of lcov.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.startsWith('SF:')) {
      current = {
        file: line.slice(3).replace(/\\/g, '/'),
        linesFound: 0,
        linesHit: 0,
      };
    } else if (line.startsWith('LF:')) {
      current.linesFound = Number(line.slice(3));
    } else if (line.startsWith('LH:')) {
      current.linesHit = Number(line.slice(3));
    } else if (line === 'end_of_record' && current) {
      flutterCoverageFiles.push({
        file: current.file,
        lines:
          current.linesFound === 0 ? 0 : (current.linesHit / current.linesFound) * 100,
        linesCovered: current.linesHit,
        linesTotal: current.linesFound,
      });
      current = null;
    }
  }
  flutterCoverageFiles.sort((a, b) => a.file.localeCompare(b.file));
  const totalFound = flutterCoverageFiles.reduce((s, f) => s + f.linesTotal, 0);
  const totalHit = flutterCoverageFiles.reduce((s, f) => s + f.linesCovered, 0);
  flutterCoverageTotal = {
    lines: totalFound === 0 ? 0 : (totalHit / totalFound) * 100,
    linesCovered: totalHit,
    linesTotal: totalFound,
  };
}

// ---------------------------------------------------------------------------
// 7. Render HTML
// ---------------------------------------------------------------------------

const data = {
  generatedAt: new Date().toISOString(),
  backend: {
    totals: backendTotals,
    suites: backendSuites,
    coverage: {
      total: backendCoverageSummary,
      files: backendCoverageFiles,
    },
  },
  flutter: {
    totals: flutterTotals,
    suites: flutterSuiteList,
    coverage: {
      total: flutterCoverageTotal,
      files: flutterCoverageFiles,
    },
  },
  admin: {
    totals: adminTotals,
    suites: adminSuiteList,
  },
};

const html = renderHtml(data);
const outPath = path.join(reportDir, 'index.html');
fs.writeFileSync(outPath, html);
log(`Wrote report → ${path.relative(repoRoot, outPath).replace(/\\/g, '/')}`);

// ===========================================================================
// HTML rendering
// ===========================================================================

function renderHtml(data) {
  const css = `
:root {
  color-scheme: light dark;
  --bg: #f6f7fb;
  --surface: #ffffff;
  --surface-2: #f1f4fa;
  --text: #1a2238;
  --text-muted: #5a647a;
  --border: #e2e6ef;
  --pass: #16a34a;
  --pass-bg: #dcfce7;
  --fail: #dc2626;
  --fail-bg: #fee2e2;
  --warn: #d97706;
  --warn-bg: #fef3c7;
  --accent: #2563eb;
  --accent-2: #1d4ed8;
  --shadow: 0 8px 24px rgba(15, 23, 42, 0.06), 0 2px 6px rgba(15, 23, 42, 0.04);
  --radius: 14px;
  --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0b1220;
    --surface: #111a2e;
    --surface-2: #15203a;
    --text: #e6ecf7;
    --text-muted: #94a3b8;
    --border: #1f2c47;
    --pass-bg: #052e1a;
    --fail-bg: #3b0a0a;
    --warn-bg: #3a2807;
    --shadow: 0 8px 24px rgba(0, 0, 0, 0.45), 0 2px 6px rgba(0, 0, 0, 0.35);
  }
}
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--text);
  font-family: "Inter", "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 14px;
  line-height: 1.55;
  direction: ltr;
}
.container {
  max-width: 1280px;
  margin: 0 auto;
  padding: 32px 24px 80px;
}
header.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 32px;
  flex-wrap: wrap;
}
header.app-header h1 {
  font-size: 26px;
  margin: 0;
  letter-spacing: -0.01em;
}
header.app-header .subtitle {
  color: var(--text-muted);
  font-size: 13px;
}
header .meta {
  text-align: right;
  font-size: 13px;
  color: var(--text-muted);
}
header .meta .build-status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 999px;
  font-weight: 600;
  margin-bottom: 6px;
}
.build-status.pass { background: var(--pass-bg); color: var(--pass); }
.build-status.fail { background: var(--fail-bg); color: var(--fail); }
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 18px 20px;
  box-shadow: var(--shadow);
}
.card .label { font-size: 12px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.08em; }
.card .value { font-size: 28px; font-weight: 700; margin-top: 6px; letter-spacing: -0.02em; }
.card .secondary { font-size: 12px; color: var(--text-muted); margin-top: 8px; }
.card.pass { border-left: 4px solid var(--pass); }
.card.fail { border-left: 4px solid var(--fail); }
.card.warn { border-left: 4px solid var(--warn); }
.card.accent { border-left: 4px solid var(--accent); }
.tabs {
  display: flex;
  gap: 4px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 24px;
  flex-wrap: wrap;
}
.tab-button {
  background: transparent;
  border: 0;
  border-bottom: 2px solid transparent;
  padding: 10px 16px;
  font: inherit;
  cursor: pointer;
  color: var(--text-muted);
  font-weight: 600;
  border-radius: 6px 6px 0 0;
}
.tab-button:hover { background: var(--surface-2); color: var(--text); }
.tab-button.active { color: var(--accent); border-bottom-color: var(--accent); background: var(--surface); }
.tab-panel { display: none; }
.tab-panel.active { display: block; }
.section { margin-bottom: 32px; }
.section-title { font-size: 15px; font-weight: 700; margin-bottom: 12px; display: flex; gap: 8px; align-items: center; }
.section-title .pill { font-size: 11px; padding: 2px 10px; border-radius: 999px; background: var(--surface-2); color: var(--text-muted); font-weight: 600; }
.toolbar { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; margin-bottom: 12px; }
.toolbar input[type="search"] {
  flex: 1 1 240px;
  min-width: 200px;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
}
.filter-button {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 6px 12px;
  font: inherit;
  cursor: pointer;
  color: var(--text-muted);
  font-weight: 600;
  font-size: 12px;
}
.filter-button.active { background: var(--accent); color: #fff; border-color: var(--accent); }
table.matrix {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  overflow: hidden;
  box-shadow: var(--shadow);
  font-size: 13px;
}
table.matrix th, table.matrix td {
  padding: 10px 14px;
  text-align: left;
  border-bottom: 1px solid var(--border);
  vertical-align: top;
}
table.matrix th { background: var(--surface-2); font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); }
table.matrix tbody tr:last-child td { border-bottom: 0; }
table.matrix tbody tr:hover { background: var(--surface-2); }
.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
}
.status-pill.pass { background: var(--pass-bg); color: var(--pass); }
.status-pill.fail { background: var(--fail-bg); color: var(--fail); }
.status-pill.skip { background: var(--warn-bg); color: var(--warn); }
.status-pill.dot::before {
  content: "";
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}
.suite { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 12px; box-shadow: var(--shadow); overflow: hidden; }
.suite summary { padding: 14px 18px; cursor: pointer; display: flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; list-style: none; }
.suite summary::-webkit-details-marker { display: none; }
.suite summary .file { font-family: var(--mono); font-size: 13px; }
.suite summary .meta { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; color: var(--text-muted); font-size: 12px; }
.suite[open] summary { border-bottom: 1px solid var(--border); background: var(--surface-2); }
.suite .tests { padding: 0; }
.suite .tests table.matrix { border-radius: 0; border: 0; box-shadow: none; }
.suite .tests table.matrix th { background: var(--surface); }
.error-message { background: var(--fail-bg); color: var(--fail); padding: 8px 12px; border-radius: 8px; font-family: var(--mono); white-space: pre-wrap; margin-top: 8px; font-size: 12px; }
.bar { background: var(--surface-2); border-radius: 999px; height: 8px; overflow: hidden; min-width: 100px; }
.bar > span { display: block; height: 100%; background: var(--pass); border-radius: 999px; }
.bar.warn > span { background: var(--warn); }
.bar.fail > span { background: var(--fail); }
.bar.accent > span { background: var(--accent); }
td.coverage-cell { white-space: nowrap; }
.kbd { font-family: var(--mono); background: var(--surface-2); border: 1px solid var(--border); border-radius: 6px; padding: 1px 6px; font-size: 12px; }
footer.app-footer { color: var(--text-muted); font-size: 12px; text-align: center; margin-top: 32px; }
.empty-state { padding: 24px; background: var(--surface); border: 1px dashed var(--border); border-radius: var(--radius); color: var(--text-muted); text-align: center; }
@media (max-width: 640px) {
  .container { padding: 16px; }
  header.app-header h1 { font-size: 22px; }
}
`;

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Darbak QA Report</title>
<style>${css}</style>
</head>
<body>
  <div class="container">
    <header class="app-header">
      <div>
        <h1>Darbak — QA Report</h1>
        <div class="subtitle">Logistics platform • Backend (Node.js / Express) + Mobile (Flutter)</div>
      </div>
      <div class="meta">
        ${renderBuildBadge(data)}
        <div>Generated <span title="${escapeHtml(data.generatedAt)}">${formatDate(data.generatedAt)}</span></div>
      </div>
    </header>

    ${renderSummaryCards(data)}

    <div class="tabs" role="tablist">
      <button class="tab-button active" data-target="overview" role="tab">Overview</button>
      <button class="tab-button" data-target="backend-tests" role="tab">Backend tests</button>
      <button class="tab-button" data-target="flutter-tests" role="tab">Flutter tests</button>
      <button class="tab-button" data-target="admin-tests" role="tab">Admin E2E</button>
      <button class="tab-button" data-target="backend-coverage" role="tab">Backend coverage</button>
      <button class="tab-button" data-target="flutter-coverage" role="tab">Flutter coverage</button>
    </div>

    <section id="overview" class="tab-panel active">
      ${renderOverview(data)}
    </section>

    <section id="backend-tests" class="tab-panel">
      <div class="section-title">Backend Jest <span class="pill">${data.backend.totals.total} tests</span></div>
      ${renderTestToolbar('backend')}
      ${renderSuites(data.backend.suites, 'backend')}
    </section>

    <section id="flutter-tests" class="tab-panel">
      <div class="section-title">Flutter <span class="pill">${data.flutter.totals.total} tests</span></div>
      ${renderTestToolbar('flutter')}
      ${data.flutter.suites.length === 0 ? renderEmptyState('Flutter test results unavailable. Run <span class="kbd">flutter test</span> to populate this section.') : renderSuites(data.flutter.suites, 'flutter')}
    </section>

    <section id="admin-tests" class="tab-panel">
      <div class="section-title">Admin dashboard Playwright <span class="pill">${data.admin.totals.total} browser tests</span></div>
      ${renderTestToolbar('admin')}
      ${data.admin.suites.length === 0 ? renderEmptyState('Admin dashboard Playwright results unavailable. Run <span class="kbd">npm test</span> in <span class="kbd">e2e/admin-dashboard/</span>.') : renderSuites(data.admin.suites, 'admin')}
    </section>

    <section id="backend-coverage" class="tab-panel">
      <div class="section-title">Backend coverage <span class="pill">Jest / Istanbul</span></div>
      ${data.backend.coverage.total ? renderBackendCoverage(data.backend.coverage) : renderEmptyState('Backend coverage summary not found. Run <span class="kbd">npm run test:coverage</span> in <span class="kbd">backend/</span>.')}
    </section>

    <section id="flutter-coverage" class="tab-panel">
      <div class="section-title">Flutter coverage <span class="pill">flutter test --coverage</span></div>
      ${data.flutter.coverage.total ? renderFlutterCoverage(data.flutter.coverage) : renderEmptyState('Flutter coverage not found. Run <span class="kbd">flutter test --coverage</span>.')}
    </section>

    <footer class="app-footer">
      Darbak QA Report • Generated by <span class="kbd">tool/generate_test_report.js</span>
    </footer>
  </div>

<script>
${renderClientScript()}
</script>
</body>
</html>`;
  return html;
}

function renderBuildBadge(data) {
  const passing =
    data.backend.totals.success &&
    data.flutter.totals.failed === 0 &&
    data.admin.totals.failed === 0;
  return `<div class="build-status ${passing ? 'pass' : 'fail'}">
    <span class="dot" aria-hidden="true">●</span>
    ${passing ? 'All test suites passing' : 'Some tests failed'}
  </div>`;
}

function renderSummaryCards(data) {
  const cards = [];
  const totalTests = data.backend.totals.total + data.flutter.totals.total + data.admin.totals.total;
  const totalPassed = data.backend.totals.passed + data.flutter.totals.passed + data.admin.totals.passed;
  const totalFailed = data.backend.totals.failed + data.flutter.totals.failed + data.admin.totals.failed;
  const totalPending = data.backend.totals.pending + data.flutter.totals.pending + data.admin.totals.pending;

  cards.push(card('Total tests', totalTests, `${data.backend.totals.suites + data.flutter.totals.suites + data.admin.totals.suites} suites`, 'accent'));
  cards.push(card('Passed', totalPassed, percentLabel(totalPassed, totalTests), 'pass'));
  cards.push(card('Failed', totalFailed, totalFailed === 0 ? 'No regressions' : 'Action required', totalFailed === 0 ? 'pass' : 'fail'));
  cards.push(card('Skipped / pending', totalPending, totalPending === 0 ? 'None' : 'Review skipped tests', totalPending === 0 ? 'accent' : 'warn'));
  if (data.admin.totals.total > 0) {
    cards.push(card('Admin E2E', data.admin.totals.total, `${data.admin.totals.passed} passed across Playwright`, data.admin.totals.failed === 0 ? 'pass' : 'fail'));
  }
  if (data.backend.coverage.total) {
    const c = data.backend.coverage.total;
    cards.push(card('Backend coverage', `${c.lines.pct.toFixed(1)}%`, `lines ${c.lines.covered}/${c.lines.total}`, coverageTone(c.lines.pct)));
  }
  if (data.flutter.coverage.total) {
    const c = data.flutter.coverage.total;
    cards.push(card('Flutter coverage', `${c.lines.toFixed(1)}%`, `lines ${c.linesCovered}/${c.linesTotal}`, coverageTone(c.lines)));
  }
  if (data.backend.coverage.total && data.flutter.coverage.total) {
    const b = data.backend.coverage.total;
    const f = data.flutter.coverage.total;
    const covered = b.lines.covered + f.linesCovered;
    const total = b.lines.total + f.linesTotal;
    const pct = total > 0 ? (covered / total) * 100 : 0;
    cards.push(card('Total app coverage', `${pct.toFixed(1)}%`, `lines ${covered}/${total} (backend + Flutter)`, coverageTone(pct)));
  }
  return `<div class="cards">${cards.join('')}</div>`;
}

function card(label, value, secondary, tone = 'accent') {
  return `<div class="card ${tone}">
    <div class="label">${escapeHtml(label)}</div>
    <div class="value">${escapeHtml(String(value))}</div>
    <div class="secondary">${secondary}</div>
  </div>`;
}

function coverageTone(pct) {
  if (pct >= 80) return 'pass';
  if (pct >= 50) return 'warn';
  if (pct >= 25) return 'accent';
  return 'fail';
}

function percentLabel(part, total) {
  if (!total) return '–';
  return `${((part / total) * 100).toFixed(1)}% of ${total}`;
}

function renderOverview(data) {
  const platformRow = (label, totals) => `
    <tr>
      <td><strong>${escapeHtml(label)}</strong></td>
      <td>${totals.total}</td>
      <td><span class="status-pill pass">${totals.passed} passed</span></td>
      <td>${totals.failed > 0 ? `<span class="status-pill fail">${totals.failed} failed</span>` : '<span class="status-pill pass dot">0 failed</span>'}</td>
      <td>${totals.pending}</td>
      <td>${formatDuration(totals.durationMs)}</td>
    </tr>`;

  return `
    <div class="section">
      <div class="section-title">Platform breakdown</div>
      <table class="matrix">
        <thead>
          <tr>
            <th>Platform</th>
            <th>Total</th>
            <th>Passed</th>
            <th>Failed</th>
            <th>Skipped</th>
            <th>Duration</th>
          </tr>
        </thead>
        <tbody>
          ${platformRow('Backend (Jest)', data.backend.totals)}
          ${platformRow('Flutter (flutter_test)', data.flutter.totals)}
          ${platformRow('Admin dashboard (Playwright)', data.admin.totals)}
        </tbody>
      </table>
    </div>

    <div class="section">
      <div class="section-title">Suite status</div>
      ${renderSuiteSummaryTable([
        ...data.backend.suites.map((s) => ({ ...s, platform: 'Backend' })),
        ...data.flutter.suites.map((s) => ({ ...s, platform: 'Flutter' })),
        ...data.admin.suites.map((s) => ({ ...s, platform: s.platform || 'Admin E2E' })),
      ])}
    </div>
  `;
}

function renderSuiteSummaryTable(suites) {
  if (!suites.length) return renderEmptyState('No test suites recorded.');
  const rows = suites
    .map((suite) => {
      const failing = suite.numFailing || 0;
      const passing = suite.numPassing || 0;
      const pending = suite.numPending || 0;
      const status = failing > 0 ? 'fail' : 'pass';
      return `<tr>
        <td><span class="status-pill ${status} dot">${status === 'pass' ? 'passed' : 'failed'}</span></td>
        <td><strong>${escapeHtml(suite.platform)}</strong></td>
        <td><code>${escapeHtml(suite.file)}</code></td>
        <td>${passing}</td>
        <td>${failing}</td>
        <td>${pending}</td>
        <td>${formatDuration(suite.durationMs)}</td>
      </tr>`;
    })
    .join('');
  return `<table class="matrix">
    <thead>
      <tr>
        <th>Status</th>
        <th>Platform</th>
        <th>Suite</th>
        <th>Passed</th>
        <th>Failed</th>
        <th>Skipped</th>
        <th>Duration</th>
      </tr>
    </thead>
    <tbody>${rows}</tbody>
  </table>`;
}

function renderTestToolbar(scope) {
  return `<div class="toolbar" data-scope="${scope}">
    <input type="search" placeholder="Filter ${scope} tests by name..." data-search="${scope}" aria-label="Filter ${scope} tests" />
    <button class="filter-button active" data-filter="all" data-scope="${scope}">All</button>
    <button class="filter-button" data-filter="passed" data-scope="${scope}">Passed</button>
    <button class="filter-button" data-filter="failed" data-scope="${scope}">Failed</button>
    <button class="filter-button" data-filter="skipped" data-scope="${scope}">Skipped</button>
  </div>`;
}

function renderSuites(suites, scope) {
  if (!suites.length) return renderEmptyState('No test results to display.');
  return suites
    .map((suite) => {
      const failing = suite.numFailing || 0;
      const status = failing > 0 ? 'fail' : 'pass';
      const open = failing > 0 ? ' open' : '';
      const tests = suite.tests
        .map((t) => {
          const tStatus = t.status === 'passed' || t.status === 'pass' ? 'pass' : t.status === 'failed' || t.status === 'failure' || t.status === 'error' ? 'fail' : 'skip';
          const error = (t.failureMessages && t.failureMessages.length)
            ? `<div class="error-message">${escapeHtml(stripAnsi(t.failureMessages.join('\n')))}</div>`
            : (t.errorMessages && t.errorMessages.length)
              ? `<div class="error-message">${escapeHtml(stripAnsi(t.errorMessages.join('\n')))}</div>`
              : '';
          return `<tr data-status="${tStatus}" data-scope="${scope}">
            <td><span class="status-pill ${tStatus} dot">${tStatusLabel(tStatus)}</span></td>
            <td>${escapeHtml(t.title)}${error}</td>
            <td>${formatDuration(t.durationMs || 0)}</td>
          </tr>`;
        })
        .join('');
      return `<details class="suite" data-scope="${scope}"${open}>
        <summary>
          <span class="file">${escapeHtml(suite.file)}</span>
          <span class="meta">
            <span class="status-pill ${status} dot">${status === 'pass' ? 'passed' : 'failed'}</span>
            <span>${suite.numPassing || 0} passed</span>
            ${failing > 0 ? `<span>${failing} failed</span>` : ''}
            ${(suite.numPending || 0) > 0 ? `<span>${suite.numPending} skipped</span>` : ''}
            <span>${formatDuration(suite.durationMs)}</span>
          </span>
        </summary>
        <div class="tests">
          <table class="matrix">
            <thead>
              <tr>
                <th style="width: 110px;">Status</th>
                <th>Test</th>
                <th style="width: 110px;">Duration</th>
              </tr>
            </thead>
            <tbody>${tests}</tbody>
          </table>
        </div>
      </details>`;
    })
    .join('');
}

function tStatusLabel(status) {
  if (status === 'pass') return 'passed';
  if (status === 'fail') return 'failed';
  if (status === 'skip') return 'skipped';
  return status;
}

function renderBackendCoverage(coverage) {
  const c = coverage.total;
  const cards = `
    <div class="cards" style="margin-bottom: 16px;">
      ${coverageCard('Lines', c.lines)}
      ${coverageCard('Statements', c.statements)}
      ${coverageCard('Functions', c.functions)}
      ${coverageCard('Branches', c.branches)}
    </div>`;
  const rows = coverage.files
    .map((f) => coverageRow(f, true))
    .join('');
  return `${cards}
    <table class="matrix">
      <thead>
        <tr>
          <th>File</th>
          <th>Lines</th>
          <th>Statements</th>
          <th>Functions</th>
          <th>Branches</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function renderFlutterCoverage(coverage) {
  const c = coverage.total;
  const card = `
    <div class="cards" style="margin-bottom: 16px;">
      ${coverageCard('Lines', { pct: c.lines, covered: c.linesCovered, total: c.linesTotal })}
    </div>`;
  const rows = coverage.files
    .map((f) =>
      `<tr>
        <td><code>${escapeHtml(f.file)}</code></td>
        <td class="coverage-cell">${barCell(f.lines)}</td>
        <td class="coverage-cell">${f.linesCovered}/${f.linesTotal}</td>
      </tr>`,
    )
    .join('');
  return `${card}
    <table class="matrix">
      <thead>
        <tr>
          <th>File</th>
          <th>Lines</th>
          <th>Covered</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function coverageCard(label, metric) {
  if (!metric) return '';
  const pct = metric.pct ?? metric.lines ?? 0;
  const tone = coverageTone(pct);
  return `<div class="card ${tone}">
    <div class="label">${escapeHtml(label)}</div>
    <div class="value">${pct.toFixed(1)}%</div>
    <div class="secondary">${metric.covered ?? metric.linesCovered ?? 0} / ${metric.total ?? metric.linesTotal ?? 0}</div>
  </div>`;
}

function coverageRow(f, hasAll) {
  return `<tr>
    <td><code>${escapeHtml(f.file)}</code></td>
    <td class="coverage-cell">${barCell(f.lines)}</td>
    ${hasAll ? `<td class="coverage-cell">${barCell(f.statements)}</td>` : ''}
    ${hasAll ? `<td class="coverage-cell">${barCell(f.functions)}</td>` : ''}
    ${hasAll ? `<td class="coverage-cell">${barCell(f.branches)}</td>` : ''}
  </tr>`;
}

function barCell(pct) {
  const safe = Number.isFinite(pct) ? pct : 0;
  const tone = coverageTone(safe);
  return `<div style="display:flex; align-items:center; gap:8px;">
    <div class="bar ${tone}"><span style="width:${Math.min(100, Math.max(0, safe)).toFixed(1)}%"></span></div>
    <span>${safe.toFixed(1)}%</span>
  </div>`;
}

function renderEmptyState(message) {
  return `<div class="empty-state">${message}</div>`;
}

function renderClientScript() {
  return `
const tabButtons = document.querySelectorAll('.tab-button');
const panels = document.querySelectorAll('.tab-panel');
tabButtons.forEach((btn) => {
  btn.addEventListener('click', () => {
    tabButtons.forEach((b) => b.classList.remove('active'));
    panels.forEach((p) => p.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(btn.dataset.target).classList.add('active');
  });
});

document.querySelectorAll('.filter-button').forEach((btn) => {
  btn.addEventListener('click', () => {
    const scope = btn.dataset.scope;
    document.querySelectorAll('.filter-button[data-scope="' + scope + '"]').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    applyFilter(scope);
  });
});

document.querySelectorAll('input[data-search]').forEach((input) => {
  input.addEventListener('input', () => applyFilter(input.dataset.search));
});

function applyFilter(scope) {
  const activeBtn = document.querySelector('.filter-button.active[data-scope="' + scope + '"]');
  const filter = activeBtn ? activeBtn.dataset.filter : 'all';
  const searchEl = document.querySelector('input[data-search="' + scope + '"]');
  const search = (searchEl ? searchEl.value : '').toLowerCase();

  document.querySelectorAll('details.suite[data-scope="' + scope + '"]').forEach((suite) => {
    let visibleRows = 0;
    suite.querySelectorAll('tbody tr').forEach((row) => {
      const status = row.dataset.status;
      const name = row.textContent.toLowerCase();
      const statusOk = filter === 'all' || filter === status || (filter === 'passed' && status === 'pass') || (filter === 'failed' && status === 'fail') || (filter === 'skipped' && status === 'skip');
      const searchOk = !search || name.includes(search);
      const show = statusOk && searchOk;
      row.style.display = show ? '' : 'none';
      if (show) visibleRows += 1;
    });
    suite.style.display = visibleRows === 0 && (filter !== 'all' || search) ? 'none' : '';
    if (visibleRows > 0 && (filter === 'failed' || search)) suite.open = true;
  });
}
`;
}

function parsePlaywrightSuites(playwright) {
  const suites = new Map();

  const upsertSuite = (file, projectName) => {
    const key = `${file}::${projectName}`;
    if (!suites.has(key)) {
      suites.set(key, {
        file: `${file} (${projectName})`,
        platform: `Admin E2E / ${projectName}`,
        durationMs: 0,
        numFailing: 0,
        numPassing: 0,
        numPending: 0,
        status: 'passed',
        tests: [],
      });
    }
    return suites.get(key);
  };

  const visitSuite = (suite, titleParts = []) => {
    const file = relPath(suite.file || 'unknown', adminE2eTestsDir);
    const isFileSuite = suite.file && suite.title === path.basename(suite.file);
    const nextTitleParts = isFileSuite ? titleParts : [...titleParts, suite.title].filter(Boolean);

    for (const spec of suite.specs || []) {
      for (const test of spec.tests || []) {
        const projectName = test.projectName || test.projectId || 'playwright';
        const target = upsertSuite(file, projectName);
        const results = test.results || [];
        const result = results[results.length - 1] || {};
        const rawStatus = result.status || test.status || 'unknown';
        const expected = test.status === 'expected';
        const status =
          rawStatus === 'passed' && expected
            ? 'passed'
            : rawStatus === 'skipped'
              ? 'skipped'
              : rawStatus === 'passed'
                ? 'passed'
                : 'failed';
        const durationMs = results.reduce((sum, r) => sum + (r.duration || 0), 0);
        const title = [...nextTitleParts, spec.title].filter(Boolean).join(' › ');
        const errorMessages = results
          .flatMap((r) => r.errors || [])
          .map((e) => e.message || e.stack || String(e));

        target.tests.push({
          title,
          status,
          durationMs,
          errorMessages,
        });
        target.durationMs += durationMs;
        if (status === 'passed') target.numPassing += 1;
        else if (status === 'skipped') target.numPending += 1;
        else target.numFailing += 1;
      }
    }

    for (const child of suite.suites || []) {
      visitSuite(child, nextTitleParts);
    }
  };

  for (const suite of playwright.suites || []) {
    visitSuite(suite);
  }

  return [...suites.values()]
    .map((suite) => ({
      ...suite,
      status: suite.numFailing > 0 ? 'failed' : 'passed',
    }))
    .sort((a, b) => a.file.localeCompare(b.file));
}

function relPath(absolute, base) {
  if (!absolute) return 'unknown';
  try {
    if (path.isAbsolute(absolute)) {
      return path.relative(base, absolute).replace(/\\/g, '/') || path.basename(absolute);
    }
    return absolute.replace(/\\/g, '/');
  } catch {
    return String(absolute).replace(/\\/g, '/');
  }
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function stripAnsi(value) {
  return String(value ?? '').replace(/\u001B\[[0-9;]*m/g, '');
}

function formatDuration(ms) {
  if (!Number.isFinite(ms) || ms <= 0) return '0 ms';
  if (ms < 1000) return `${Math.round(ms)} ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(2)} s`;
  const minutes = Math.floor(ms / 60_000);
  const seconds = Math.floor((ms % 60_000) / 1000);
  return `${minutes} m ${seconds} s`;
}

function formatDate(iso) {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}
