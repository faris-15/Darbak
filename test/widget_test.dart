import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/auth_screens.dart';
import 'package:darbak/main.dart';

void main() {
  testWidgets('Darbak Splash smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DarbakApp());

    // Verify that the splash screen is mounted.
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
