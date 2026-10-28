import 'dart:io';

import 'package:flutter/foundation.dart';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/sms_report_settings.dart';
import '../utils/iran_time.dart';
import 'direct_sms_service.dart';
import 'sms_report_builder_service.dart';
import 'sms_report_settings_service.dart';

/// A persistent, best-effort Android background worker. Scheduling is not
/// minute-exact; Android Doze/battery optimizations may postpone execution.
class SmsAutoSenderService {
  static const taskUniqueId = 'saraban_periodic_sms_v16';
  static const taskName = 'saraban_generate_send_sms';
  static const _lastSlotKey = 'saraban_sms_last_slot_v16';
  static const _attemptSlotKey = 'saraban_sms_inflight_slot_v16';
  static bool _initialized = false;
  static bool _isSending = false;

  static final ValueNotifier<String> statusNotifier =
      ValueNotifier<String>('ارسال زمان‌بندی‌شده غیرفعال است.');

  static Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    await Workmanager().initialize(smsReportBackgroundDispatcher);
    _initialized = true;
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await initialize();
    final settings = await SmsReportSettingsService.loadSettings();
    if (settings.scheduled && settings.phoneNumber.trim().isNotEmpty &&
        await Workmanager().isScheduledByUniqueName(taskUniqueId)) return;
    await restart();
  }

  static Future<void> restart() async {
    if (!Platform.isAndroid) return;
    await initialize();
    final settings = await SmsReportSettingsService.loadSettings();
    // Only cancel our own work; do not interfere with other workers.
    await Workmanager().cancelByUniqueName(taskUniqueId);
    if (!settings.scheduled || settings.phoneNumber.trim().isEmpty) {
      statusNotifier.value = 'ارسال زمان‌بندی‌شده غیرفعال است.';
      return;
    }
    if (!await DirectSmsService.hasSmsPermission()) {
      statusNotifier.value = 'مجوز SMS لازم است؛ از تنظیمات پیامک فعال کنید.';
      return;
    }
    final now = IranTime.nowWallClock();
    final wait = untilNextSlot(settings, now);
    final frequency = settings.schedule == 'daily'
        ? const Duration(days: 1) : const Duration(days: 7);
    await Workmanager().registerPeriodicTask(
      taskUniqueId, taskName,
      frequency: frequency,
      initialDelay: wait,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      // No network required: send via carrier SIM and read local SQLite.
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
    statusNotifier.value = settings.schedule == 'daily'
        ? 'ارسال روزانه فعال شد (حدود ${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')} به وقت ایران).'
        : 'ارسال هفتگی فعال شد (با زمان‌بندی تقریبی اندروید).';
  }

  /// Pause scheduled SMS when the user explicitly signs out. Settings are kept.
  static Future<void> pause() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().cancelByUniqueName(taskUniqueId);
    statusNotifier.value = 'ارسال زمان‌بندی‌شده متوقف شد.';
  }

  static Duration untilNextSlot(SmsReportSettings settings, DateTime iranNow) {
    // IranTime exposes a UTC-tagged DateTime whose civil fields are Iran time.
    // Compare civil fields in UTC, not against the phone's local timezone.
    final nowCivil = DateTime.utc(iranNow.year, iranNow.month, iranNow.day,
        iranNow.hour, iranNow.minute, iranNow.second, iranNow.millisecond);
    var candidate = DateTime.utc(iranNow.year, iranNow.month, iranNow.day,
        settings.hour, settings.minute);
    if (settings.schedule == 'weekly') {
      final offset = (settings.weekday - candidate.weekday + 7) % 7;
      candidate = candidate.add(Duration(days: offset));
    }
    if (!candidate.isAfter(nowCivil)) {
      candidate = candidate.add(Duration(days: settings.schedule == 'weekly' ? 7 : 1));
    }
    return candidate.difference(nowCivil);
  }

  static String? dueSlot(SmsReportSettings settings, DateTime iranNow) {
    if (!settings.scheduled || !settings.validSchedule) return null;
    if (iranNow.hour < settings.hour ||
        (iranNow.hour == settings.hour && iranNow.minute < settings.minute)) return null;
    if (settings.schedule == 'weekly' && iranNow.weekday != settings.weekday) return null;
    final y = iranNow.year.toString().padLeft(4, '0');
    final m = iranNow.month.toString().padLeft(2, '0');
    final d = iranNow.day.toString().padLeft(2, '0');
    return '${settings.schedule}-$y$m$d';
  }

  /// Triggered in WorkManager's headless isolate. Never request permissions
  /// there; permission must be granted from the app's Settings UI first.
  static Future<bool> sendScheduledIfDue() async {
    if (_isSending) return true;
    _isSending = true;
    try {
      final settings = await SmsReportSettingsService.loadSettings();
      final slot = dueSlot(settings, IranTime.nowWallClock());
      if (slot == null || settings.phoneNumber.trim().isEmpty) return true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final targetSlot = '$slot-${settings.phoneNumber.trim()}';
      if (prefs.getString(_lastSlotKey) == targetSlot) return true;
      // In case two workers overlap, an in-flight reservation prevents a
      // double-send. This favors no duplicate over retry after a crash.
      if (prefs.getString(_attemptSlotKey) == targetSlot) return true;
      if (!await DirectSmsService.hasSmsPermission()) return false;
      await prefs.setString(_attemptSlotKey, targetSlot);
      final data = await SmsReportBuilderService.buildData(
          weekly: settings.schedule == 'weekly');
      if (settings.sendOnlyIfHasProblem && !data.hasProblem) {
        await prefs.setString(_lastSlotKey, targetSlot);
        return true;
      }
      final message = SmsReportBuilderService.buildMessage(settings: settings, data: data);
      await DirectSmsService.sendDirectSms(phoneNumber: settings.phoneNumber, message: message,
          askForPermission: false);
      await prefs.setString(_lastSlotKey, targetSlot);
      statusNotifier.value = 'درخواست پیامک زمان‌بندی‌شده ثبت شد.';
      return true;
    } catch (error) {
      statusNotifier.value = 'خطای ارسال زمان‌بندی‌شده: $error';
      return false;
    } finally {
      _isSending = false;
    }
  }

  static Future<void> sendNow(SmsReportSettings settings) async {
    if (_isSending) throw StateError('ارسال دیگری در حال انجام است.');
    _isSending = true;
    try {
      final data = await SmsReportBuilderService.buildData(
          weekly: settings.schedule == 'weekly');
      final msg = SmsReportBuilderService.buildMessage(settings: settings, data: data);
      await DirectSmsService.sendDirectSms(phoneNumber: settings.phoneNumber, message: msg);
      statusNotifier.value = 'درخواست ارسال پیامک به شبکه ثبت شد.';
    } finally { _isSending = false; }
  }
}

@pragma('vm:entry-point')
void smsReportBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != SmsAutoSenderService.taskName) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      return await SmsAutoSenderService.sendScheduledIfDue();
    } catch (_) { return false; }
  });
}
