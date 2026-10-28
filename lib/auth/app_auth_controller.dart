import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_api_client.dart';
import 'auth_config.dart';

enum AuthStatus { checking, signedOut, signedIn }

/// Session gate: data screens are only mounted after authentication.
/// Remote tokens are encrypted at rest; passwords are never stored.
class AppAuthController extends ChangeNotifier {
  AppAuthController._();
  static final instance = AppAuthController._();
  static const _tokenKey = 'saraban_api_access_token_v18';

  final _storage = const FlutterSecureStorage();
  final _api = const AuthApiClient();
  AuthStatus status = AuthStatus.checking;
  AppUser? user;
  String? _token;
  bool isDemo = false;
  String? startupMessage;

  String? get bearerToken => isDemo ? null : _token;

  Future<void> restoreSession() async {
    status = AuthStatus.checking;
    notifyListeners();
    try {
      if (!AuthConfig.hasApi) {
        status = AuthStatus.signedOut;
        return;
      }
      final saved = await _storage.read(key: _tokenKey);
      if (saved == null || saved.isEmpty) {
        status = AuthStatus.signedOut;
        return;
      }
      final verified = await _api.me(saved);
      _token = saved;
      user = verified;
      isDemo = false;
      status = AuthStatus.signedIn;
    } on AuthApiException catch (error) {
      startupMessage = error.message;
      if (error.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
      }
      status = AuthStatus.signedOut;
    } catch (_) {
      status = AuthStatus.signedOut;
      startupMessage = 'بازیابی نشست ممکن نبود؛ دوباره وارد شوید.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> login({required String username, required String password}) async {
    if (!AuthConfig.hasApi) {
      throw const AuthApiException('هنوز نشانی API لاراول تعریف نشده است.');
    }
    final result = await _api.login(username, password);
    await _storage.write(key: _tokenKey, value: result.token);
    _token = result.token;
    user = result.user;
    isDemo = false;
    startupMessage = null;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> enterDemo() async {
    if (!AuthConfig.demoAllowed) {
      throw StateError('ورود آزمایشی در نسخه انتشار غیرفعال است.');
    }
    // Switching from a server account to demo must not restore that account
    // at the next startup.
    await _storage.delete(key: _tokenKey);
    _token = null;
    user = const AppUser(id: 'demo', name: 'کاربر آزمایشی');
    isDemo = true;
    startupMessage = null;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signOut() async {
    final old = _token;
    _token = null;
    user = null;
    isDemo = false;
    status = AuthStatus.signedOut;
    notifyListeners();
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Session has already been invalidated in memory.
    }
    if (old != null) {
      try {
        await _api.logout(old);
      } catch (_) {
        // Local sign-out must work even if the network is unavailable.
      }
    }
  }
}
