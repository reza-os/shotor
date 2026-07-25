import 'package:url_launcher/url_launcher.dart';

class SmsService {
  static String? encodeQueryParameters(Map<String, String> params) {
    return params.entries.map((entry) {
      return '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}';
    }).join('&');
  }

  static Future<bool> openSmsApp({
    required String phoneNumber,
    required String message,
  }) async {
    final cleanPhone = phoneNumber.trim();

    if (cleanPhone.isEmpty) {
      throw Exception('شماره مرکز ثبت نشده است.');
    }

    final smsUri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      query: encodeQueryParameters({
        'body': message,
      }),
    );

    return launchUrl(smsUri);
  }
}