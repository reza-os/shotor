import 'package:flutter/foundation.dart';

/// Compile-time configuration: never ship a fixed username/password in Flutter.
/// API_BASE_URL is the Laravel origin (e.g. https://api.example.com).
class AuthConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const loginPath = String.fromEnvironment(
    'AUTH_LOGIN_PATH', defaultValue: '/api/v1/auth/login');
  static const mePath = String.fromEnvironment(
    'AUTH_ME_PATH', defaultValue: '/api/v1/auth/me');
  static const logoutPath = String.fromEnvironment(
    'AUTH_LOGOUT_PATH', defaultValue: '/api/v1/auth/logout');

  /// A separate, clearly marked temporary release build may opt in.
  /// Never enable this for a real production deployment.
  static const bool demoAllowed = !kReleaseMode ||
      bool.fromEnvironment('ENABLE_TEMPORARY_DEMO_LOGIN', defaultValue: false);

  static bool get hasApi => apiBaseUrl.trim().isNotEmpty;

  static Uri endpoint(String path) {
    if (!hasApi) throw const FormatException('نشانی API تنظیم نشده است.');
    final base = Uri.parse(apiBaseUrl.trim());
    if (!(base.scheme == 'https' ||
        (!kReleaseMode && base.scheme == 'http'))) {
      throw const FormatException('برای ورود واقعی، اتصال HTTPS ضروری است.');
    }
    if (!base.hasAuthority) {
      throw const FormatException('نشانی API معتبر نیست.');
    }
    final route = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${apiBaseUrl.trim().replaceFirst(RegExp(r"/+$"), "")}$route');
  }
}
