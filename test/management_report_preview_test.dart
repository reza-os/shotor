import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/app_settings.dart';
import 'package:saraban_app/models/management_report.dart';
import 'package:saraban_app/screens/management_report_preview_page.dart';

CamelLastStatusReport camel(int index, {required bool problem}) =>
    CamelLastStatusReport(
      tagId: 'TAG-${1000 + index}',
      camelNo: '$index',
      camelName: 'شتر $index',
      lastSeenText: '۱۰:۳۰',
      lastLocationText: 'چراگاه',
      batteryText: '۸۰٪',
      lockText: 'بسته',
      statusText: problem ? 'دیده نشده' : 'عادی',
      hasProblem: problem,
    );

ManagementReport fakeReport() => ManagementReport(
  summary: ManagementReportSummary(
    date: DateTime(2026, 10, 26),
    totalRecords: 20,
    registeredCamelCount: 32,
    seenCamelCount: 10,
    missingCamelCount: 22,
    lowBatteryCamelCount: 0,
    unlockedEventCount: 0,
    forbiddenEventCount: 0,
    outsideAllowedEventCount: 0,
  ),
  timeSlots: const [],
  timeSlotRows: const [],
  locationDurationRows: const [],
  lastStatusRows: [
    for (int index = 1; index <= 22; index++) camel(index, problem: true),
    for (int index = 23; index <= 32; index++) camel(index, problem: false),
  ],
);

void main() {
  testWidgets('problem and normal previews use square grids and paging',
      (tester) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ManagementReportPreviewPage(
      report: fakeReport(),
      appSettings: const AppSettings(),
      date: DateTime(2026, 10, 26),
      profiles: const [],
      zones: const [],
    )));
    await tester.pumpAndSettle();

    expect(find.text('خلاصه'), findsOneWidget);
    expect(find.text('نیازمند بررسی'), findsOneWidget);
    expect(find.text('عادی'), findsOneWidget);

    await tester.tap(find.text('نیازمند بررسی'));
    await tester.pumpAndSettle();
    expect(find.text('شتر 1'), findsOneWidget);
    expect(find.text('شتر 9'), findsOneWidget);
    expect(find.text('TAG-1001'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.fling(find.byKey(
      const PageStorageKey('problem-camels-grid')),
      const Offset(330, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('شتر 10'), findsOneWidget);

    await tester.tap(find.text('عادی'));
    await tester.pumpAndSettle();
    expect(find.text('شتر 23'), findsOneWidget);
    expect(find.text('TAG-1023'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('tapping a compact card reveals all report details',
      (tester) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ManagementReportPreviewPage(
      report: fakeReport(),
      appSettings: const AppSettings(),
      date: DateTime(2026, 10, 26),
      profiles: const [],
      zones: const [],
    )));
    await tester.tap(find.text('نیازمند بررسی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-camel-TAG-1001')));
    await tester.pumpAndSettle();

    expect(find.text('آخرین مشاهده'), findsOneWidget);
    expect(find.text('آخرین مکان'), findsOneWidget);
    expect(find.text('باتری'), findsOneWidget);
    expect(find.text('قفل'), findsOneWidget);
  });
}
