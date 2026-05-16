import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart'; // relative import — no package name needed for tests

void main() {
  testWidgets('MyApp builds without errors', (WidgetTester tester) async {
    // Just verify the app widget tree builds successfully.
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}