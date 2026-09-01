import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Hello, Flutter!'),
          ),
        ),
      ),
    );

    expect(find.text('Hello, Flutter!'), findsOneWidget);
    expect(find.text('Goodbye, Flutter!'), findsNothing);
  });
}
