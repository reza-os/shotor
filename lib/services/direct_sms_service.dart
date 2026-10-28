import 'package:flutter/services.dart';

class DirectSmsService {
  static const MethodChannel _channel = MethodChannel('saraban/native_sms');

  static Future<bool> hasSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> sendDirectSms({
    required String phoneNumber,
    required String message,
    bool askForPermission = true,
  }) async {
    final cleanPhone = phoneNumber.trim()
        .replaceAllMapped(RegExp(r'[۰-۹]'),
            (match) => '0123456789'['۰۱۲۳۴۵۶۷۸۹'.indexOf(match.group(0)!)] )
        .replaceAllMapped(RegExp(r'[٠-٩]'),
            (match) => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(match.group(0)!)] );
    final cleanMessage = message.trim();

    if (cleanPhone.isEmpty) {
      throw Exception('شماره مقصد پیامک ثبت نشده است.');
    }

    if (cleanMessage.isEmpty) {
      throw Exception('متن پیامک خالی است.');
    }

    var hasPermission = await hasSmsPermission();

    if (!hasPermission && askForPermission) {
      hasPermission = await requestSmsPermission();
    }

    if (!hasPermission) {
      throw Exception('مجوز ارسال پیامک داده نشد.');
    }

    try {
      final submitted = await _channel.invokeMethod<bool>(
        'sendSms',
        {
          'phoneNumber': cleanPhone,
          'message': cleanMessage,
        },
      );
      if (submitted != true) throw Exception('درخواست ارسال پیامک تأیید نشد.');
    } on PlatformException catch (e) {
      throw Exception(e.message ?? e.code);
    }
  }
}