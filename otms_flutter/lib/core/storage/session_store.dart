import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Native bearer tokens are stored in the platform keystore. Web sessions use
/// an HttpOnly cookie managed by the backend, so no bearer token is exposed to
/// JavaScript-readable storage.
class SessionStore {
  static const _tokenKey = 'otms_access_token';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<String?> readToken() async {
    if (kIsWeb) return null;
    try {
      return await _secure.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken(String? token) async {
    if (kIsWeb) return;
    try {
      if (token == null) {
        await _secure.delete(key: _tokenKey);
      } else {
        await _secure.write(key: _tokenKey, value: token);
      }
    } catch (_) {
      // Keep the in-memory session even when a device keystore is unavailable.
    }
  }
}
