import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/widgets/shipment_path.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('ShipmentPath renders pickup/dropoff labels and values', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(
          body: ShipmentPath(pickupCity: 'الرياض', dropoffCity: 'جدة'),
        ),
      ),
    );

    expect(find.text('منطقة الاستلام: الرياض'), findsOneWidget);
    expect(find.text('منطقة التسليم: جدة'), findsOneWidget);
  });

  testWidgets('ShipmentPath falls back to dash for empty locations', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(
          body: ShipmentPath(pickupCity: ' ', dropoffCity: null),
        ),
      ),
    );

    expect(find.text('منطقة الاستلام: -'), findsOneWidget);
    expect(find.text('منطقة التسليم: -'), findsOneWidget);
  });

  testWidgets('ShipmentPath exposes semantic labels for route icons', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(
          body: ShipmentPath(pickupCity: 'الرياض', dropoffCity: 'جدة'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('موقع الاستلام'), findsOneWidget);
    expect(find.bySemanticsLabel('موقع التسليم'), findsOneWidget);
  });
}
