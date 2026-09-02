import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_browser/widgets/logo.dart';

void main() {
  testWidgets('LogoMark paints without plugins', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: LogoMark(size: 48)))),
    );
    // The asset isn't bundled in unit tests, so wait for the painted fallback.
    await tester.pumpAndSettle();
    expect(find.byType(LogoMark), findsOneWidget);
    expect(find.descendant(
      of: find.byType(LogoMark),
      matching: find.byType(CustomPaint),
    ), findsOneWidget);
  });
}
