import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexusflow/screens/auth/login_screen.dart';

void main() {
  testWidgets('NexusFlow login screen smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('NexusFlow'), findsWidgets);
    expect(find.textContaining('로그인'), findsOneWidget);
  });
}
