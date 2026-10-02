import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otms_flutter/app.dart';
import 'package:otms_flutter/core/storage/session_store.dart';
import 'package:otms_flutter/screens/auth/login_screen.dart';
import 'package:otms_flutter/services/api_client.dart';

class _MemorySessionStore extends SessionStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String? value) async => token = value;
}

OtmsApp _testApp() => OtmsApp(
  api: ApiClient(
    sessionStore: _MemorySessionStore(),
    httpClient: MockClient(
      (_) async => http.Response('{"error":"unexpected request"}', 500),
    ),
  ),
);

Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the app shell', (tester) async {
    await _pumpReady(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('shows the login screen when no token is stored', (tester) async {
    await _pumpReady(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('applies the persisted dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({'otms_theme_mode': 'dark'});
    await _pumpReady(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('defaults to system theme when nothing is persisted', (
    tester,
  ) async {
    await _pumpReady(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });
}
