import 'dart:convert';
import 'dart:io';
import 'auth_config.dart';

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;
  const AuthApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class AppUser {
  final String id;
  final String name;
  final String? role;
  const AppUser({required this.id, required this.name, this.role});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return AppUser(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? json['username'] ?? 'کاربر'}',
      role: role is String ? role : null,
    );
  }
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});
}

/// API endpoints are a proposed Laravel contract, not existing server routes.
/// The UI never talks to HTTP directly; future backup/sync can reuse bearerToken.
class AuthApiClient {
  const AuthApiClient();

  static Map<String, dynamic> _asObject(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const AuthApiException('پاسخ سرور ساختار معتبر JSON ندارد.');
  }

  static AuthResult parseLoginResponse(Map<String, dynamic> response) {
    final nested = response['data'];
    final root = nested is Map ? _asObject(nested) : response;
    final token = root['token'] ?? root['access_token'];
    if (token is! String || token.trim().isEmpty) {
      throw const AuthApiException('سرور توکن ورود ارسال نکرد.');
    }
    final userJson = root['user'];
    if (userJson is! Map) {
      throw const AuthApiException('اطلاعات کاربر در پاسخ سرور وجود ندارد.');
    }
    return AuthResult(token: token, user: AppUser.fromJson(_asObject(userJson)));
  }

  Future<Map<String, dynamic>> _request(String method, String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, AuthConfig.endpoint(path))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(const Duration(seconds: 15));
      final text = await utf8.decoder.bind(response).join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 422) {
        throw AuthApiException('نام کاربری یا رمز عبور صحیح نیست، یا نشست منقضی شده است.',
            statusCode: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthApiException('خطای سرور (${response.statusCode}).',
            statusCode: response.statusCode);
      }
      if (text.trim().isEmpty) return {};
      try {
        return _asObject(jsonDecode(text));
      } on FormatException {
        throw const AuthApiException('پاسخ سرور JSON معتبر نیست.');
      }
    } on AuthApiException {
      rethrow;
    } on SocketException {
      throw const AuthApiException('ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.');
    } on HandshakeException {
      throw const AuthApiException('گواهی امنیتی سرور معتبر نیست.');
    } on FormatException catch (e) {
      throw AuthApiException(e.message);
    } catch (_) {
      throw const AuthApiException('خطای شبکه یا پایان مهلت پاسخ سرور.');
    } finally {
      client.close(force: true);
    }
  }

  Future<AuthResult> login(String username, String password) async {
    final response = await _request('POST', AuthConfig.loginPath, body: {
      'username': username.trim(),
      'password': password,
      'device_name': 'Shotor Android',
    });
    return parseLoginResponse(response);
  }

  Future<AppUser> me(String token) async {
    final response = await _request('GET', AuthConfig.mePath, token: token);
    final data = response['data'] is Map ? _asObject(response['data']) : response;
    return AppUser.fromJson(data['user'] is Map ? _asObject(data['user']) : data);
  }

  Future<void> logout(String token) async {
    await _request('POST', AuthConfig.logoutPath, token: token);
  }
}
