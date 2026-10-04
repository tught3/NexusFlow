import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexusflow/screens/auth/login_screen.dart';

void main() {
  testWidgets('NexusFlow login screen smoke test', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('NexusFlow'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });
}
