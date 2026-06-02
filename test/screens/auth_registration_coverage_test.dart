import 'package:darbak/auth_screens.dart';
import 'package:darbak/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_app(child));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('document override cancel shows snackbar on upload step',
      (tester) async {
    await _pump(
      tester,
      RegistrationScreen(
        role: 'shipper',
        initialStepForTest: 2,
        pickDocumentOverride: () async => null,
      ),
    );
    await tester.tap(find.text('رفع السجل التجاري'));
    await tester.pump();
    expect(find.text('لم يتم اختيار أي ملف'), findsOneWidget);
  });

  testWidgets('pickDocument override success shows picked snackbar', (tester) async {
    await _pump(
      tester,
      RegistrationScreen(
        role: 'shipper',
        initialStepForTest: 2,
        pickDocumentOverride: () async => (path: 'x.pdf', name: 'x.pdf'),
      ),
    );
    await tester.tap(find.text('رفع السجل التجاري'));
    await tester.pump();
    expect(find.text('تم اختيار الملف بنجاح'), findsOneWidget);
  });
}
