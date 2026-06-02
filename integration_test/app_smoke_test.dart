import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:darbak/auth_screens.dart';
import 'package:darbak/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Darbak app launches to splash screen', (tester) async {
    await tester.pumpWidget(const DarbakApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
