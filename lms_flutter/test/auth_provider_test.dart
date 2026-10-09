import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lms_flutter/services/api_client.dart';
import 'package:lms_flutter/state/auth_provider.dart';

String _loginBody({String token = 'tok-1', String role = 'teacher'}) =>
    jsonEncode({
      'token': token,
      'user': {
        'id': 7,
        'full_name': 'Test User',
        'email': 'user@lms.test',
        'role': role,
      },
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'bootstrap with no stored token signs out without any request',
    () async {
      var requests = 0;
      final api = ApiClient(
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final auth = AuthProvider(api: api);

      await auth.bootstrap();

      expect(auth.loading, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(requests, 0, reason: 'there is no token to validate');
    },
  );

  test('login exposes the user and their role', () async {
    final api = ApiClient(
      httpClient: MockClient((_) async => http.Response(_loginBody(), 200)),
    );
    final auth = AuthProvider(api: api);

    await auth.login('user@lms.test', 'password');

    expect(auth.isAuthenticated, isTrue);
    expect(auth.isTeacher, isTrue);
    expect(auth.user?.fullName, 'Test User');
  });

  test('a rejected token ends the session and notifies listeners', () async {
    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('login.php')) {
          return http.Response(_loginBody(), 200);
        }
        return http.Response(jsonEncode({'error': 'Invalid token'}), 401);
      }),
    );
    final auth = AuthProvider(api: api);

    await auth.login('user@lms.test', 'password');
    expect(auth.isAuthenticated, isTrue);

    var notified = 0;
    auth.addListener(() => notified++);

    // Any authenticated call coming back 401 has to end the session.
    await expectLater(api.classes(), throwsA(isA<ApiException>()));

    expect(auth.isAuthenticated, isFalse);
    expect(auth.user, isNull);
    expect(notified, 1, reason: 'AuthGate rebuilds back to the login screen');
  });

  test(
    'logout clears the session even when the call cannot reach the server',
    () async {
      final api = ApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('login.php')) {
            return http.Response(_loginBody(), 200);
          }
          throw http.ClientException('offline');
        }),
      );
      final auth = AuthProvider(api: api);
      await auth.login('user@lms.test', 'password');

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
    },
  );

  test('dispose unhooks the unauthorized callback', () async {
    final api = ApiClient(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    final auth = AuthProvider(api: api);
    expect(api.onUnauthorized, isNotNull);

    auth.dispose();

    expect(api.onUnauthorized, isNull);
  });
}
