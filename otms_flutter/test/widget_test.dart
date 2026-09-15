import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otms_flutter/app.dart';
import 'package:otms_flutter/screens/auth/login_screen.dart';

void main() {
  setUp(() {
    // No stored token => AuthProvider.bootstrap() resolves to signed-out
    // without touching the network.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const OtmsApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('shows the login screen when no token is stored',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OtmsApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('applies the persisted dark theme', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'otms_theme_mode': 'dark'});

    await tester.pumpWidget(const OtmsApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('defaults to system theme when nothing is persisted',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OtmsApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });
}
