import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name.snakeCase()}}/app.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
