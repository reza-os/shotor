import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/sms_report_settings.dart';
import 'package:saraban_app/services/sms_auto_sender_service.dart';

void main() {
  test('legacy minute schedules do not silently opt in to sending', () {
    final legacy = SmsReportSettings.fromJson({
      'enabled': true, 'intervalMinutes': 5, 'phoneNumber': '09123456789',
    });
    expect(legacy.enabled, false);
    expect(legacy.schedule, 'now');
  });

  test('today is due only after chosen Iran clock time', () {
    const prefs = SmsReportSettings(enabled: true, schedule: 'daily',
        hour: 9, minute: 30, phoneNumber: '09123456789');
    expect(SmsAutoSenderService.dueSlot(prefs, DateTime(2026, 10, 26, 9, 29)), null);
    expect(SmsAutoSenderService.dueSlot(prefs, DateTime(2026, 10, 26, 9, 30)),
        'daily-20261026');
    expect(SmsAutoSenderService.untilNextSlot(prefs, DateTime(2026, 10, 26, 9, 31)),
        const Duration(hours: 23, minutes: 59));
  });

  test('weekly reports only become due on selected day', () {
    const prefs = SmsReportSettings(enabled: true, schedule: 'weekly',
        weekday: DateTime.saturday, hour: 10, minute: 0);
    expect(SmsAutoSenderService.dueSlot(prefs, DateTime(2026, 10, 26, 11)), null);
    expect(SmsAutoSenderService.dueSlot(prefs, DateTime(2026, 10, 31, 11)),
        'weekly-20261031');
  });

  test('settings serialize time/day and message options', () {
    const settings = SmsReportSettings(enabled: true, schedule: 'weekly',
      weekday: DateTime.thursday, hour: 16, minute: 45,
      phoneNumber: '09123456789', includeLowBatteryCount: false);
    final restored = SmsReportSettings.fromJson(settings.toJson());
    expect(restored.schedule, 'weekly');
    expect(restored.weekday, DateTime.thursday);
    expect(restored.hour, 16);
    expect(restored.minute, 45);
    expect(restored.includeLowBatteryCount, false);
  });
}
