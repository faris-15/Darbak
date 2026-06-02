import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darbak/widgets/profile_avatar.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('renders driver fallback avatar when no image is supplied', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(body: ProfileAvatar(role: 'driver')),
      ),
    );

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.domain_rounded), findsNothing);
  });

  testWidgets('renders shipper fallback avatar', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const Scaffold(body: ProfileAvatar(role: 'shipper')),
      ),
    );

    expect(find.byIcon(Icons.domain_rounded), findsOneWidget);
  });

  testWidgets('edit button calls onEdit when not uploading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildTestApp(
        Scaffold(
          body: ProfileAvatar(
            role: 'driver',
            showEditButton: true,
            onEdit: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    expect(tapped, isTrue);
  });

  testWidgets('uploading overlay disables edit and shows progress', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildTestApp(
        Scaffold(
          body: ProfileAvatar(
            role: 'driver',
            showEditButton: true,
            isUploading: true,
            uploadProgress: 0.5,
            onEdit: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    expect(tapped, isFalse);
  });
}
