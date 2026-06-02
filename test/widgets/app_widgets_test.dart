import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darbak/app_widgets.dart';

import '../helpers/test_app.dart';

void main() {
  group('DarbakSurface', () {
    testWidgets('renders child content within a rounded surface', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: DarbakSurface(child: Text('محتوى')),
          ),
        ),
      );

      expect(find.text('محتوى'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DarbakSurface),
          matching: find.byType(Container),
        ),
      );
      expect(container.decoration, isA<BoxDecoration>());
    });

    testWidgets('honors explicit width when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: DarbakSurface(
              width: 222,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(DarbakSurface));
      expect(size.width, 222);
    });
  });

  group('DarbakPrimaryButton', () {
    testWidgets('renders label and calls onPressed', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: Center(
              child: DarbakPrimaryButton(
                label: 'متابعة',
                onPressed: () => tapped++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('متابعة'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, 1);
    });

    testWidgets('renders leading icon when iconAlignment.start', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakPrimaryButton(
              label: 'تسجيل',
              icon: Icons.login_rounded,
              iconAlignment: IconAlignment.start,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    });

    testWidgets('renders trailing icon by default', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakPrimaryButton(
              label: 'متابعة',
              icon: Icons.arrow_forward,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('clamps widthFactor and wraps in FractionallySizedBox', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakPrimaryButton(
              label: 'متابعة',
              widthFactor: 5.0,
              onPressed: () {},
            ),
          ),
        ),
      );

      final fsb = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fsb.widthFactor, 1.0);
    });

    testWidgets('disables tap when onPressed is null', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: DarbakPrimaryButton(label: 'متابعة'),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('DarbakOutlinedButton', () {
    testWidgets('renders label and forwards taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakOutlinedButton(
              label: 'إلغاء',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('إلغاء'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 1);
    });
  });

  group('DarbakSectionTitle', () {
    testWidgets('renders title without subtitle', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(body: DarbakSectionTitle(title: 'الإعدادات')),
        ),
      );

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('فرعية'), findsNothing);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: DarbakSectionTitle(
              title: 'الإعدادات',
              subtitle: 'فرعية',
            ),
          ),
        ),
      );

      expect(find.text('فرعية'), findsOneWidget);
    });
  });

  group('DarbakAuthTextField', () {
    testWidgets('renders hint and prefix icon, supports password mode', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakAuthTextField(
              hint: 'البريد الإلكتروني',
              controller: controller,
              isPassword: true,
              prefixIcon: Icons.email_outlined,
            ),
          ),
        ),
      );

      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('omits prefix icon when not provided', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakAuthTextField(
              hint: 'الاسم',
              controller: controller,
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.prefixIcon, isNull);
    });
  });

  group('DarbakLogoutBarButton', () {
    testWidgets('renders Arabic logout label and forwards taps', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: DarbakLogoutBarButton(onPressed: () => pressed = true),
          ),
        ),
      );

      expect(find.text('تسجيل الخروج'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isTrue);
    });
  });

  group('DarbakProfileAvatar legacy wrapper', () {
    testWidgets('falls back to driver role for default icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(body: DarbakProfileAvatar()),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('uses shipper role when icon is Icons.domain_rounded', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: DarbakProfileAvatar(icon: Icons.domain_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.domain_rounded), findsOneWidget);
    });
  });
}
