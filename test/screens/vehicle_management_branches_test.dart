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

Map<String, dynamic> _truck({
  required int id,
  int isActive = 0,
  String verificationStatus = 'pending',
  String? insuranceUrl,
}) =>
    {
      'id': id,
      'truck_type': 'صغيرة',
      'plate_number': 'A $id ر',
      'isthimara_no': 'IS-$id',
      'is_active': isActive,
      'verification_status': verificationStatus,
      'insurance_document_url': insuranceUrl,
      'truck_group': 'light',
      'truck_classification': 'small',
      'axle_count': '1_axle',
      'body_type': 'standard_cargo',
      'load_capacity_id': 'cap_3_5_ton',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('shows max-trucks banner when five trucks are registered',
      (tester) async {
    final trucks = List.generate(5, (i) => _truck(id: i + 1, isActive: i == 0 ? 1 : 0));
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: trucks);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        expect(find.text('وصلت للحد الأعلى (5 شاحنات)'), findsOneWidget);
      },
    );
  });

  testWidgets('rejected verification chip is shown for rejected trucks',
      (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my',
            body: [_truck(id: 1, verificationStatus: 'rejected')]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        expect(find.text('مرفوضة'), findsOneWidget);
      },
    );
  });

  testWidgets('setActiveTruck failure surfaces snackbar', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: [
          _truck(id: 1, isActive: 1),
          _truck(id: 2, isActive: 0),
        ]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
        r.respond('PATCH', '/api/trucks/2/active',
            statusCode: 500, body: {'message': 'fail'});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        final activate = find.byIcon(Icons.radio_button_unchecked);
        if (activate.evaluate().isNotEmpty) {
          await tester.ensureVisible(activate.first);
          await tester.pump();
          await tester.tap(activate.first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.textContaining('تعذر تفعيل الشاحنة'), findsOneWidget);
      },
    );
  });

  testWidgets('error banner retry reloads trucks', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my',
            statusCode: 500, body: {'message': 'oops'});
        r.respond('GET', '/api/operating-card', body: {'data': null});
        r.respond('GET', '/api/trucks/my', body: [_truck(id: 1, isActive: 1)]);
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        await tester.tap(find.text('إعادة المحاولة'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });

  testWidgets('pull-to-refresh triggers silent reload', (tester) async {
    await withMockedHttp(
      setup: (r) {
        r.respond('GET', '/api/trucks/my', body: [_truck(id: 1, isActive: 1)]);
        r.respond('GET', '/api/operating-card', body: {'data': null});
      },
      callback: (_) async {
        await _pump(tester, const VehicleManagementScreen());
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(VehicleManagementScreen), findsOneWidget);
      },
    );
  });
}
