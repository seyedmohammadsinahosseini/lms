import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';

/// Owns the authenticated user and drives the auth gate. Talks to LmsApi so
/// widgets never touch the network layer directly.
class AuthProvider extends ChangeNotifier {
  AuthProvider({LmsApi? api}) : _api = api ?? Api.instance {
    _api.onUnauthorized = _handleUnauthorized;
  }

  final LmsApi _api;

  User? _user;
  String? _demoExpiresAt;
  bool _loading = true; // true during the initial token restore

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  bool get isTeacher => _user?.isTeacher ?? false;
  bool get isDemo => _user?.email.endsWith('@demo.invalid') ?? false;
  String? get demoExpiresAt => _demoExpiresAt;

  /// Restore a stored token on startup and validate it against the server.
  Future<void> bootstrap() async {
    await _api.loadToken();
    try {
      _user = await _api.me();
    } catch (_) {
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _user = await _api.login(email, password);
    _demoExpiresAt = null;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? teacherInvite,
  }) async {
    _user = await _api.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      teacherInvite: teacherInvite,
    );
    _demoExpiresAt = null;
    notifyListeners();
  }

  Future<void> updateProfile(String fullName) async {
    _user = await _api.updateProfile(fullName);
    notifyListeners();
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _api.changePassword(currentPassword, newPassword);

  Future<DemoAccess> createDemo() => _api.createDemo();

  Future<void> loginDemo(DemoAccess access, String role) async {
    _user = await _api.loginDemo(access, role);
    _demoExpiresAt = access.expiresAt;
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _demoExpiresAt = null;
    notifyListeners();
  }

  /// The server rejected the stored token, so the session is gone whether the
  /// user asked for it or not. Dropping [_user] sends AuthGate back to login
  /// instead of letting every screen fail with "unauthorized".
  void _handleUnauthorized() {
    if (_user == null) return;
    _user = null;
    _demoExpiresAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_api.onUnauthorized == _handleUnauthorized) _api.onUnauthorized = null;
    super.dispose();
  }
}
