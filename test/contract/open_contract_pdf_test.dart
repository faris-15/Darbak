import 'package:darbak/contract/open_contract_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  Future<BuildContext> pumpHarness(WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return capturedContext;
  }

  testWidgets('opens the signed contract URL externally', (tester) async {
    final context = await pumpHarness(tester);
    Uri? openedUrl;
    LaunchMode? openedMode;

    await openShipmentContractPdfInApp(
      context,
      42,
      getSignedUrl: (shipmentId) async {
        expect(shipmentId, 42);
        return 'https://cdn.test/contracts/42.pdf';
      },
      launch: (url, mode) async {
        openedUrl = url;
        openedMode = mode;
        return true;
      },
    );

    expect(openedUrl, Uri.parse('https://cdn.test/contracts/42.pdf'));
    expect(openedMode, LaunchMode.externalApplication);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows a SnackBar when the API returns no contract URL', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    await openShipmentContractPdfInApp(
      context,
      42,
      getSignedUrl: (_) async => '',
      launch: (_, __) async => true,
    );
    await tester.pump();

    expect(find.textContaining('تعذر جلب رابط العقد'), findsOneWidget);
  });

  testWidgets('shows a SnackBar when launching fails', (tester) async {
    final context = await pumpHarness(tester);

    await openShipmentContractPdfInApp(
      context,
      42,
      getSignedUrl: (_) async => 'https://cdn.test/contracts/42.pdf',
      launch: (_, __) async => false,
    );
    await tester.pump();

    expect(find.textContaining('لا يمكن فتح الرابط'), findsOneWidget);
  });

  testWidgets('shows a SnackBar when fetching the signed URL throws', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    await openShipmentContractPdfInApp(
      context,
      42,
      getSignedUrl: (_) async => throw Exception('network down'),
      launch: (_, __) async => true,
    );
    await tester.pump();

    expect(find.textContaining('حدث خطأ أثناء فتح العقد'), findsOneWidget);
  });
}
