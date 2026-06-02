import 'package:darbak/auth_screens.dart';
import 'package:darbak/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DarbakApp builds with splash home and named routes', (tester) async {
    await tester.pumpWidget(const DarbakApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SplashScreen), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.routes, isNotNull);
    expect(materialApp.routes!.keys, containsAll(['/login', '/roleSelection', '/splash']));

    final loginRoute = materialApp.routes!['/login']!;
    final loginContext = tester.element(find.byType(MaterialApp));
    final loginWidget = loginRoute(loginContext);
    expect(loginWidget, isA<LoginScreen>());

    final roleRoute = materialApp.routes!['/roleSelection']!;
    expect(roleRoute(loginContext), isA<ChooseRoleScreen>());
  });
}
