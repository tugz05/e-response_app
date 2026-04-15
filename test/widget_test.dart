import 'package:e_response_app_nemsu/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MyApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(firstRun: false));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
