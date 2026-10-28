import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/widgets/floating_nav_bar.dart';

void main() {
  testWidgets('نوار پایین، چهار تب درست دارد و گله قابل کلیک است',
      (WidgetTester tester) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingNavBar(
            currentIndex: 0,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('گله'), findsOneWidget);
    expect(find.text('نقشه'), findsOneWidget);
    expect(find.text('بیشتر'), findsOneWidget);

    await tester.tap(find.text('گله'));
    await tester.pump();
    expect(tappedIndex, 1);
  });
}
