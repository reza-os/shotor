import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saraban_app/screens/unified_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unified settings exposes all four accordion sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: UnifiedSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('ساربان'), findsOneWidget);
    expect(find.text('گله'), findsOneWidget);
    expect(find.text('آنتن و Wi-Fi'), findsOneWidget);
    expect(find.text('پیامک'), findsOneWidget);

    await tester.tap(find.text('آنتن و Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('نام شبکه آنتن (SSID)'), findsOneWidget);
    expect(find.text('اتصال مجدد خودکار'), findsOneWidget);
  });
}
