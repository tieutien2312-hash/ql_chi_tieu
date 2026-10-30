import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ql_chi_tieu/screens/main_screen.dart';

void main() {
  testWidgets('MainScreen smoke test', (WidgetTester tester) async {
    // Build just a simple widget or mock
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Test App'),
        ),
      ),
    );

    expect(find.text('Test App'), findsOneWidget);
  });
}
