import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';

/// Owns the authenticated user and drives the auth gate. Talks to OmsApi so
/// widgets never touch the network layer directly.
class AuthProvider extends ChangeNotifier {
  AuthProvider({OmsApi? api}) : _api = api ?? Api.instance {
    _api.onUnauthorized = _handleUnauthorized;
  }

  final OmsApi _api;

  User? _user;
  bool _loading = true; // true during the initial token restore

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  bool get isTeacher => _user?.isTeacher ?? false;

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
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    _user = await _api.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    notifyListeners();
  }

  /// The server rejected the stored token, so the session is gone whether the
  /// user asked for it or not. Dropping [_user] sends AuthGate back to login
  /// instead of letting every screen fail with "unauthorized".
  void _handleUnauthorized() {
    if (_user == null) return;
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_api.onUnauthorized == _handleUnauthorized) _api.onUnauthorized = null;
    super.dispose();
  }
}
