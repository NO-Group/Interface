import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_browser/widgets/logo.dart';

void main() {
  testWidgets('LogoMark paints without plugins', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: LogoMark(size: 48)))),
    );
    expect(find.byType(LogoMark), findsOneWidget);
    // In unit tests the bundled asset never resolves, so let the error
    // path settle without throwing either.
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(LogoMark), findsOneWidget);
  });
}
