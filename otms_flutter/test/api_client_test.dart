import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otms_flutter/core/config/env.dart';
import 'package:otms_flutter/services/api_client.dart';

/// A login response the client understands.
String _loginBody({String token = 'tok-1'}) => jsonEncode({
      'token': token,
      'user': {
        'id': 7,
        'full_name': 'Test Teacher',
        'email': 'teacher@otms.test',
        'role': 'teacher',
      },
    });

/// Builds an [ApiClient] backed by [handler], recording every request it makes
/// so tests can assert on retries, headers and payloads.
ApiClient _client(
  FutureOr<http.Response> Function(http.Request request) handler, {
  List<http.Request>? log,
}) {
  return ApiClient(
    httpClient: MockClient((request) async {
      log?.add(request);
      return await handler(request);
    }),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Env', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('resolves the API base from the configured backend path', () {
      expect(Env.apiBaseUrl, endsWith('/OTMS1/backend'));
      expect(Env.apiBase, endsWith('/OTMS1/backend/api'));
    });

    test('uses the emulator alias for the host on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(Env.apiBaseUrl, startsWith('http://10.0.2.2'));
    });

    test('uses localhost on desktop and iOS simulator', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(Env.apiBaseUrl, startsWith('http://localhost'));
    });
  });

  group('ApiClient requests', () {
    test('sends the bearer token once a login has stored one', () async {
      final log = <http.Request>[];
      final api = _client((request) async {
        if (request.url.path.endsWith('login.php')) {
          return http.Response(_loginBody(), 200);
        }
        return http.Response(jsonEncode({'classes': []}), 200);
      }, log: log);

      await api.login('teacher@otms.test', 'password');
      await api.classes();

      expect(log, hasLength(2));
      expect(log.first.headers['Authorization'], isNull,
          reason: 'the login request itself carries no token');
      expect(log.last.headers['Authorization'], 'Bearer tok-1');
    });

    test('surfaces the server error message for a failed request', () async {
      final api = _client(
        (_) => http.Response(jsonEncode({'error': 'Invalid credentials'}), 401),
      );

      await expectLater(
        api.login('teacher@otms.test', 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Invalid credentials')
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test('maps a server crash to a server error', () async {
      final api = _client((_) => http.Response('boom', 500));

      await expectLater(
        api.classes(),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 500)
            .having((e) => e.isServerError, 'isServerError', isTrue)),
      );
    });

    test('maps a transport failure to a network error naming the base URL',
        () async {
      final api = _client((_) => throw http.ClientException('connection refused'));

      await expectLater(
        api.classes(),
        throwsA(isA<ApiException>()
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
            .having((e) => e.message, 'message', contains(Env.apiBaseUrl))),
      );
    });

    test('retries a GET that fails at the transport level', () async {
      final log = <http.Request>[];
      var attempts = 0;
      final api = _client((_) async {
        attempts++;
        if (attempts == 1) throw http.ClientException('cold start');
        return http.Response(jsonEncode({'classes': []}), 200);
      }, log: log);

      final classes = await api.classes();

      expect(classes, isEmpty);
      expect(log, hasLength(2), reason: 'one retry after the transport failure');
    });

    test('never retries a POST, which may already have been applied', () async {
      final log = <http.Request>[];
      final api = _client(
        (_) => throw http.ClientException('connection lost'),
        log: log,
      );

      await expectLater(
        api.submitAttempt(1, {2: 3}),
        throwsA(isA<ApiException>()),
      );
      expect(log, hasLength(1),
          reason: 'replaying a submit could duplicate the attempt server-side');
    });
  });

  group('ApiClient session handling', () {
    test('clears the token and notifies when the server rejects it', () async {
      var unauthorizedCalls = 0;
      final api = _client((request) async {
        if (request.url.path.endsWith('login.php')) {
          return http.Response(_loginBody(), 200);
        }
        return http.Response(jsonEncode({'error': 'Invalid token'}), 401);
      });
      api.onUnauthorized = () => unauthorizedCalls++;

      await api.login('teacher@otms.test', 'password');
      expect(api.token, 'tok-1');

      await expectLater(api.classes(), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero); // let the token write settle

      expect(api.token, isNull);
      expect(unauthorizedCalls, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('otms_token'), isNull);
    });

    test('does not treat a rejected login as an expired session', () async {
      var unauthorizedCalls = 0;
      final api = _client(
        (_) => http.Response(jsonEncode({'error': 'Invalid credentials'}), 401),
      );
      api.onUnauthorized = () => unauthorizedCalls++;

      await expectLater(
        api.login('teacher@otms.test', 'wrong'),
        throwsA(isA<ApiException>()),
      );

      expect(unauthorizedCalls, 0,
          reason: 'there is no session to expire on a failed login');
    });

    test('logout clears the stored token even if the call fails', () async {
      final api = _client((request) async {
        if (request.url.path.endsWith('login.php')) {
          return http.Response(_loginBody(), 200);
        }
        throw http.ClientException('offline');
      });

      await api.login('teacher@otms.test', 'password');
      await api.logout();

      expect(api.token, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('otms_token'), isNull);
    });
  });
}
