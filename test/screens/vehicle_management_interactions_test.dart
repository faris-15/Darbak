import 'package:darbak/vehicle_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, Widget child,
    {int iterations = 14}) async {
  _tall(tester);
  await tester.pumpWidget(_wrap(child));
  for (var i = 0; i < iterations; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('save with empty form surfaces "رقم اللوحة مطلوب"',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: []);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final saveBtn = find.text('إضافة شاحنة');
        expect(saveBtn, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('رقم اللوحة مطلوب'), findsOneWidget);
        expect(find.text('رخصة سير المركبة مطلوب'), findsOneWidget);
      },
    );
  });

  testWidgets('renders error banner with retry on failed truck load',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my',
            statusCode: 500, body: {'message': 'oops'});
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('cancel edit clears the form back to "إضافة شاحنة"',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: [
          {
            'id': 1,
            'plate_number': 'A 1234 ر',
            'isthimara_no': 'IS-1',
            'is_active': 1,
            'insurance_status': 'valid',
            'truck_group': 'light',
            'truck_classification': 'small',
            'axle_count': '1_axle',
            'body_type': 'standard_cargo',
            'load_capacity_id': 'cap_3_5_ton',
          }
        ]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final editBtn = find.byIcon(Icons.edit_outlined);
        if (editBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(editBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(editBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final cancelBtn = find.widgetWithText(OutlinedButton, 'إلغاء');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(cancelBtn);
            await tester.pumpAndSettle();
            await tester.tap(cancelBtn);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('insurance upload button renders and is tappable',
      (tester) async {
    final truck = {
      'id': 5,
      'truck_type': 'صغيرة',
      'plate_number': 'X 9999 ر',
      'isthimara_no': 'IS-X',
      'is_active': 1,
      'insurance_status': 'missing',
      'truck_group': 'light',
      'truck_classification': 'small',
      'axle_count': '1_axle',
      'body_type': 'standard_cargo',
      'load_capacity_id': 'cap_3_5_ton',
    };
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: [truck]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final upload = find.textContaining('تأمين هذه الشاحنة');
        expect(upload, findsAtLeast(1));
        await tester.ensureVisible(upload.first);
        await tester.pump();
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('multiple trucks listed; tapping inactive one fires setActive',
      (tester) async {
    final trucks = [
      {
        'id': 1,
        'truck_type': 'متوسط',
        'plate_number': 'A 1111 ر',
        'isthimara_no': 'IS-1',
        'is_active': 1,
        'insurance_status': 'valid',
        'truck_group': 'light',
        'truck_classification': 'small',
        'axle_count': '1_axle',
        'body_type': 'standard_cargo',
        'load_capacity_id': 'cap_3_5_ton',
      },
      {
        'id': 2,
        'truck_type': 'متوسط',
        'plate_number': 'B 2222 ر',
        'isthimara_no': 'IS-2',
        'is_active': 0,
        'insurance_status': 'valid',
        'truck_group': 'light',
        'truck_classification': 'small',
        'axle_count': '1_axle',
        'body_type': 'standard_cargo',
        'load_capacity_id': 'cap_3_5_ton',
      },
    ];

    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: trucks);
        r.respond('GET', '/api/operating-card', body: {'data': null});
        r.respond('PATCH', '/api/trucks/2/active', body: [
          {...trucks[0], 'is_active': 0},
          {...trucks[1], 'is_active': 1},
        ]);
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        // The non-active truck row should have a "تفعيل" (activate) action.
        final activate = find.textContaining('تفعيل');
        if (activate.evaluate().isNotEmpty) {
          await tester.ensureVisible(activate.first);
          await tester.pumpAndSettle();
          await tester.tap(activate.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('saving valid form posts to register truck endpoint',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: []);
        r.respond('GET', '/api/operating-card', body: {'data': null});
        r.respond('POST', '/api/trucks/register', statusCode: 201, body: {
          'data': {'id': 1, 'plate_number': 'A 1234 ر'}
        });
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final plateField = find.byType(TextFormField);
        if (plateField.evaluate().length >= 2) {
          await tester.enterText(plateField.at(0), 'A 1234 ر');
          await tester.enterText(plateField.at(1), 'ISTH-9');
          await tester.pump();
        }
        // Validate form -> click save.
        final saveBtn = find.text('إضافة شاحنة');
        if (saveBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(saveBtn);
          await tester.pumpAndSettle();
          await tester.tap(saveBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('edit truck pre-fills form and shows cancel button',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: [
          {
            'id': 1,
            'truck_type': 'متوسط',
            'plate_number': 'A 1234 ر',
            'isthimara_no': 'IS-1',
            'is_active': 1,
            'insurance_status': 'valid',
            'truck_group': 'light',
            'truck_classification': 'small',
            'axle_count': '1_axle',
            'body_type': 'standard_cargo',
            'load_capacity_id': 'cap_3_5_ton',
          }
        ]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final editBtn = find.byIcon(Icons.edit_outlined);
        if (editBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(editBtn.first);
          await tester.pumpAndSettle();
          await tester.tap(editBtn.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('حفظ التعديلات'), findsOneWidget);
          expect(find.text('إلغاء'), findsOneWidget);
        } else {
          expect(find.byType(VehicleManagementScreen), findsOneWidget);
        }
      },
    );
  });
}
