import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/auth/auth_api_client.dart';
import 'package:saraban_app/auth/auth_config.dart';

void main() {
  test('Laravel access_token + user is parsed safely', () {
    final result = AuthApiClient.parseLoginResponse({
      'data': {
        'access_token': 'test-only',
        'user': {'id': 12, 'name': 'ساربان', 'role': 'herder'},
      },
    });
    expect(result.token, 'test-only');
    expect(result.user.id, '12');
    expect(result.user.name, 'ساربان');
    expect(result.user.role, 'herder');
  });

  test('login without token must never be accepted', () {
    expect(() => AuthApiClient.parseLoginResponse({
      'user': {'id': 1, 'name': 'کاربر'}
    }), throwsA(isA<AuthApiException>()));
  });

  test('API endpoints are configurable independently of UI', () {
    expect(AuthConfig.loginPath, isNotEmpty);
    expect(AuthConfig.mePath, isNotEmpty);
  });
}
