import 'package:darbak/location_picker_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  testWidgets('MapLocationPickerScreen renders map and confirm button',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrap(
        MapLocationPickerScreen(
          title: 'اختر الموقع',
          themeColor: Colors.green,
          initialLocation: const LatLng(24.7136, 46.6753),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('اختر الموقع'), findsOneWidget);
    expect(find.text('تأكيد الموقع الحالي'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_sharp), findsOneWidget);
  });

  testWidgets('confirm button pops with lat/lng payload', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final popped = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapLocationPickerScreen(
                        title: 'موقع',
                        themeColor: Colors.green,
                        initialLocation: const LatLng(24.7, 46.6),
                      ),
                    ),
                  );
                  result = Map<String, dynamic>.from(popped as Map);
                },
                child: const Text('open-map'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('تأكيد الموقع الحالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(result, isNotNull);
    expect(result!['lat'], closeTo(24.7, 0.1));
    expect(result!['lng'], closeTo(46.6, 0.1));
    expect(result!['mapsUrl'], contains('google.com/maps'));
  });

  testWidgets('PickupLocationPickerScreen renders pickup title', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const PickupLocationPickerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('اختيار موقع الاستلام'), findsOneWidget);
  });

  testWidgets('DropoffLocationPickerScreen renders dropoff title', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const DropoffLocationPickerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('اختيار موقع التسليم'), findsOneWidget);
  });
}
