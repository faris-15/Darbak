# Enterprise Testing Guide

This repository now has a layered QA architecture for the Flutter app and Node.js backend.

## Test Strategy

Backend tests are split into:

- `backend/tests/unit`: pure business logic and validation tests.
- `backend/tests/integration`: Express route tests using production routes, JWT middleware, validators, controllers, and a mocked MySQL pool.
- `backend/tests/socket`: Socket.IO chat tests using a fake Socket.IO harness.
- `backend/tests/helpers`: reusable DB, auth, S3, Firebase, FCM, app, and factory helpers.

Flutter tests are split into:

- `test/models`: API model parsing and serialization tests.
- `test/utils`: formatter and display helper tests.
- `test/truck_classification`: truck catalog and dependent dropdown logic tests.
- `test/widgets`: widget behavior, fallback, semantics, and interaction tests.
- `integration_test`: launch/smoke tests for device/emulator execution.

The test system avoids real MySQL, Firebase, S3/MinIO, FCM, and external HTTP calls. Backend tests fail loudly when unexpected SQL or outbound HTTP appears.

## Backend Commands

Run from `backend/`:

```bash
npm test
npm run test:unit
npm run test:integration
npm run test:socket
npm run test:coverage
npm run test:ci
```

Coverage output:

- Text summary prints in the terminal.
- HTML report is generated at `backend/coverage/lcov-report/index.html`.
- LCOV file is generated at `backend/coverage/lcov.info`.

## Unified QA Dashboard (HTML)

A single, professional HTML report aggregates **every test case (passed, failed, skipped) and the full coverage matrix** for both backend and Flutter into one page. Open it in any browser; no server, no dependencies.

Run from the repository root:

```bash
node tool/generate_test_report.js
# or, from backend/
npm run test:report
```

After it finishes, open:

```
docs/test-report/index.html
```

The dashboard contains:

- **Top status badge** — green when all suites pass, red otherwise.
- **Summary cards** — total tests, passed, failed, skipped, backend coverage %, Flutter coverage %.
- **Overview tab** — backend vs Flutter platform breakdown plus a sortable suite-status table.
- **Backend tests tab** — every Jest suite as a collapsible card; expand to see each `describe › it` test, status pill, duration and full failure stack on red tests. Search box and `All / Passed / Failed / Skipped` filters work per scope.
- **Flutter tests tab** — same UX for `flutter test` results.
- **Backend coverage tab** — per-file lines, statements, functions and branches with colored bars.
- **Flutter coverage tab** — per-file line coverage parsed from `coverage/lcov.info`.

To regenerate the HTML without re-running tests (uses cached artefacts in `.tmp-qa-report/`):

```bash
node tool/generate_test_report.js --skip-run
# or
npm --prefix backend run test:report:fast
```

The dashboard is fully self-contained (inline CSS/JS, no external network calls) and is safe to upload as a CI artefact, attach to PRs, or share with non-engineering stakeholders.

## Flutter Commands

Run from the repository root:

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter test --coverage
dart run tool/check_lcov_min.dart coverage/lcov.info --min=7
```

Run integration tests on a connected emulator/device:

```bash
flutter test integration_test
```

Flutter coverage output:

- LCOV file is generated at `coverage/lcov.info`.
- Convert to HTML locally with `genhtml coverage/lcov.info -o coverage/html` if `lcov` is installed.

## CI/CD

GitHub Actions workflow: `.github/workflows/qa.yml`.

It runs:

- Backend `npm ci` and `npm run test:ci`.
- Flutter `flutter pub get`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, and `flutter test --coverage`.
- Coverage artifacts upload for backend and Flutter.

## Coverage Policy

Backend Jest has strict per-file thresholds for core risk modules:

- `utils/encryption.js`
- `utils/auctionLive.js`
- `utils/lateDeliveryPenalty.js`
- `utils/shipmentTruckMatch.js`
- `utils/truckClassificationValidator.js`
- `constants/truckClassification.js`
- `middleware/authMiddleware.js`

Current CI uses a pragmatic Flutter line coverage gate (`--min=7`) because the existing Flutter app has many large screens that were not previously designed for dependency injection. Raise this gate in stages as more screens are refactored into injectable services/widgets:

1. 7%: current baseline gate.
2. 40%: after service/model/widget expansion.
3. 60%: after API/service injection refactors.
4. 80%: after major screens have widget coverage.
5. 90%+: final enterprise target.

For backend, CI currently enforces the measured baseline so coverage cannot regress while the suite is expanded. Critical helper/security modules already have much higher gates than the global baseline. Raise `coverageThreshold.global` in `backend/jest.config.js` as new controller/route suites are added.

## What Is Covered Now

Backend:

- Encryption key validation and AES round trips.
- Auction deadline edge cases.
- Late-delivery penalty rules and caps.
- Truck classification catalog invariants and validator edge cases.
- Shipment/truck matching and a fixed invalid group validation gap.
- JWT auth, admin permission, KYB verification, disabled accounts.
- Auth routes: registration, login, Firebase login, password reset, profile update, device token.
- Bid routes: create, single active room, auction expiry, license expiry, withdraw, notification calls.
- Chat socket auth, join permissions, message send, read receipt deduplication.

Flutter:

- SAR formatter parsing/formatting/validation.
- Shipment display helpers.
- Bid and chat message model parsing.
- Truck classification catalog/service.
- SAR price, profile avatar, shipment path widgets.
- App launch smoke test.

## Adding New Tests

Backend route test pattern:

```js
const { buildTestApp } = require('../helpers/testApp');
const { dbMock } = require('../helpers/db');

dbMock.expectSelect(/FROM users WHERE id = \?/i).returns([{ id: 1 }]);
const res = await request(buildTestApp({ routes: ['auth'] })).get('/api/auth/profile/1');
```

Flutter widget test pattern:

```dart
await tester.pumpWidget(buildTestApp(MyWidget()));
expect(find.text('expected'), findsOneWidget);
```

## Known Next Steps

- Refactor large Flutter screens to inject repositories/services so API calls can be mocked without network.
- Add database migration tests against a disposable MySQL container for true FK/cascade validation.
- Add API contract tests for shipments, trucks, admin dashboard, uploads, ratings, notifications, and operating cards.
- Add e2e mobile flows with a seeded backend test fixture once DB migrations are normalized.
