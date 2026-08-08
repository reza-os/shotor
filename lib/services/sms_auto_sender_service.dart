import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sms_report_settings.dart';
import 'direct_sms_service.dart';
import 'sms_report_builder_service.dart';
import 'sms_report_settings_service.dart';

class SmsAutoSenderService {
  static Timer? _timer;
  static bool _isSending = false;

  static final ValueNotifier<String> statusNotifier =
      ValueNotifier<String>('ارسال خودکار غیرفعال است.');

  static Future<void> start() async {
    stop();

    final settings = await SmsReportSettingsService.loadSettings();

    if (!settings.enabled) {
      statusNotifier.value = 'ارسال خودکار غیرفعال است.';
      return;
    }

    if (settings.phoneNumber.trim().isEmpty) {
      statusNotifier.value = 'شماره مقصد پیامک ثبت نشده است.';
      return;
    }

    final interval = settings.intervalMinutes < 1
        ? 10
        : settings.intervalMinutes;

    statusNotifier.value = 'ارسال خودکار هر $interval دقیقه فعال است.';

    _timer = Timer.periodic(
      Duration(minutes: interval),
      (_) {
        sendOnce();
      },
    );
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> restart() async {
    stop();
    await start();
  }

  static Future<void> sendOnce() async {
    if (_isSending) return;

    _isSending = true;

    try {
      final settings = await SmsReportSettingsService.loadSettings();

      if (!settings.enabled) {
        statusNotifier.value = 'ارسال خودکار غیرفعال است.';
        return;
      }

      if (settings.phoneNumber.trim().isEmpty) {
        statusNotifier.value = 'شماره مقصد پیامک ثبت نشده است.';
        return;
      }

      final data = await SmsReportBuilderService.buildData();

      if (settings.sendOnlyIfHasProblem && !data.hasProblem) {
        statusNotifier.value = 'مشکلی وجود نداشت؛ پیامک ارسال نشد.';
        return;
      }

      final message = SmsReportBuilderService.buildMessage(
        settings: settings,
        data: data,
      );

      await DirectSmsService.sendDirectSms(
        phoneNumber: settings.phoneNumber,
        message: message,
      );

      final now = DateTime.now();
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');

      statusNotifier.value = 'آخرین پیامک در $hour:$minute ارسال شد.';
    } catch (e) {
      statusNotifier.value = 'خطا در ارسال پیامک: $e';
    } finally {
      _isSending = false;
    }
  }
}