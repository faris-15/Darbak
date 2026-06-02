import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/widgets/sar_price.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('SarPrice renders icon and formatted amount', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(
          body: SarPrice(amount: 1234.5, decimalDigits: 1),
        ),
      ),
    );

    expect(find.byType(SarIcon), findsOneWidget);
    expect(find.text('1,234.5'), findsOneWidget);
  });

  testWidgets('SarPrice uses fallback text for invalid values', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(body: SarPrice(amount: 'bad')),
      ),
    );

    expect(find.text('غير محدد'), findsOneWidget);
  });

  testWidgets('SarIcon respects provided size and color', (tester) async {
    const color = Colors.red;
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(body: SarIcon(size: 32, color: color)),
      ),
    );

    final icon = tester.widget<ImageIcon>(find.byType(ImageIcon));
    expect(icon.size, 32);
    expect(icon.color, color);
  });
}
