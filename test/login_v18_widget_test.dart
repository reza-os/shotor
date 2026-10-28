import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/auth/auth_config.dart';
import 'package:saraban_app/auth/login_page.dart';

void main() {
  testWidgets('login form appears before dashboard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text('مدیریت هوشمند گله'), findsOneWidget);
    expect(find.text('ورود به حساب'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    if (AuthConfig.demoAllowed) {
      expect(find.text('ورود آزمایشی بدون API'), findsOneWidget);
    }
  });
}
