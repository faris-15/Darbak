import 'package:darbak/app_widgets.dart';
import 'package:darbak/trip_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 1,
      'user_role': 'driver',
      'auth_token': 't',
    });
  });

  testWidgets('TripTrackingScreen "بدء الرحلة" advances current step',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(
      const TripTrackingScreen(
        shipmentId: '7',
        driverName: 'أحمد',
        driverRating: '4.8',
        driverPhone: '0500000000',
      ),
    ));
    await tester.pumpAndSettle();

    final startBtn = find.widgetWithText(ElevatedButton, 'بدء الرحلة');
    expect(startBtn, findsOneWidget);
    await tester.tap(startBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('تم تحديث الحالة: جاري النقل'), findsOneWidget);
  });

  testWidgets('TripTrackingScreen "إثبات التسليم" navigates to PoD screen',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(
      const TripTrackingScreen(
        shipmentId: '7',
        driverName: 'أحمد',
        driverRating: '4.8',
        driverPhone: '0500000000',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'إثبات التسليم'));
    await tester.pumpAndSettle();
    expect(find.byType(ProofOfDeliveryScreen), findsOneWidget);
  });

  testWidgets('ProofOfDeliveryScreen submit without photo shows snack',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(
      const ProofOfDeliveryScreen(shipmentId: '7'),
    ));
    await tester.pumpAndSettle();
    final submit =
        find.widgetWithText(DarbakPrimaryButton, 'تأكيد التسليم');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('يرجى التقاط صورة للشحنة أولاً'),
      findsOneWidget,
    );
  });

  testWidgets('TripTrackingScreen chat icon is present in app bar',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(
      const TripTrackingScreen(
        shipmentId: '7',
        driverName: 'أحمد',
        driverRating: '4.8',
        driverPhone: '0500000000',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
  });

  testWidgets('PenaltyScreen dispute button shows snack and confirm pops route',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PenaltyScreen(shipmentData: {
                    'shipment_id': 99,
                    'bid_amount': '2000',
                    'expected_delivery_at': DateTime.now()
                        .subtract(const Duration(days: 4))
                        .toIso8601String(),
                    'delivered_at': DateTime.now().toIso8601String(),
                  }),
                ),
              ),
              child: const Text('open-penalty'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open-penalty'));
    await tester.pumpAndSettle();
    expect(find.byType(PenaltyScreen), findsOneWidget);

    final disputeBtn = find.widgetWithText(OutlinedButton, 'الاعتراض على العقوبة');
    expect(disputeBtn, findsOneWidget);
    await tester.ensureVisible(disputeBtn);
    await tester.pumpAndSettle();
    await tester.tap(disputeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('تم رفع طلب اعتراض، سيراجع الأدمن الحالة'), findsOneWidget);

    final confirmBtn =
        find.widgetWithText(ElevatedButton, 'تأكيد واستلام المستحقات');
    await tester.ensureVisible(confirmBtn);
    await tester.pumpAndSettle();
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
    expect(find.byType(PenaltyScreen), findsNothing);
    expect(find.text('open-penalty'), findsOneWidget);
  });
}
