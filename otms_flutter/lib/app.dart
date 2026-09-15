import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/shared/widgets.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

/// Root of the app.
///
/// The provider tree lives here rather than in `main()` so that widget tests can
/// pump `OtmsApp` directly and still get a fully wired context.
class OtmsApp extends StatelessWidget {
  const OtmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: const _OtmsMaterialApp(),
    );
  }
}

/// Separated from [OtmsApp] because it reads the providers that its parent
/// creates; keeping them in one `build` would make the `watch` fail.
class _OtmsMaterialApp extends StatelessWidget {
  const _OtmsMaterialApp();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'OTMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.mode,
      home: const AuthGate(),
    );
  }
}

/// Decides which root screen to show based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: LoadingView());
    }
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    return auth.isTeacher ? const TeacherDashboard() : const StudentDashboard();
  }
}
