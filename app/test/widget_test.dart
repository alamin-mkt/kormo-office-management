import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kormo_app/main.dart';

void main() {
  testWidgets('KormoApp renders properly and displays dashboard', (WidgetTester tester) async {
    // Configure viewport for web desktop test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: KormoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Kormo application initializes and mounts dashboard elements
    expect(find.byType(KormoApp), findsOneWidget);
    expect(find.text('Total Workforce'), findsOneWidget);
    expect(find.text('Who is in office now'), findsOneWidget);
    expect(find.text('Quick Action Center'), findsOneWidget);
  });
}
