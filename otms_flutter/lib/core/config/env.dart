import 'package:flutter/foundation.dart';

/// Build-time configuration for the app.
///
/// The backend root is resolved in this order:
///
/// 1. `--dart-define=OTMS_API_BASE=...` — always wins, and is the only option
///    that works against a real device or a remote server:
///      `flutter run --dart-define=OTMS_API_BASE=http://192.168.1.15/OTMS1/backend`
///      `flutter build apk --dart-define=OTMS_API_BASE=https://example.com/otms/backend`
/// 2. A per-platform guess (see [_defaultOrigin]) that makes the common
///    local-development setups work without any flags.
class Env {
  const Env._();

  static const String _apiBaseOverride = String.fromEnvironment('OTMS_API_BASE');

  /// Where the PHP backend lives under the host root.
  static const String backendPath = '/OTMS1/backend';

  /// Backend root, e.g. `http://10.0.2.2/OTMS1/backend`. Relative file paths
  /// returned by the API are resolved against this.
  static String get apiBaseUrl {
    if (_apiBaseOverride.isNotEmpty) return _stripTrailingSlash(_apiBaseOverride);
    return '${_defaultOrigin()}$backendPath';
  }

  /// Base URL for the API endpoints, e.g. `http://10.0.2.2/OTMS1/backend/api`.
  static String get apiBase => '$apiBaseUrl/api';

  /// Best-effort default when the app is run without any flags:
  ///
  /// * web — the origin the app itself was served from, so a build deployed
  ///   next to the backend talks to the right host with no configuration.
  /// * Android — `10.0.2.2`, the emulator's alias for the host machine's
  ///   `localhost` (a bare `localhost` would point at the phone itself).
  /// * everything else — `localhost`, correct for desktop and the iOS simulator.
  ///
  /// A physical device on Wi-Fi can only be served by setting `OTMS_API_BASE`.
  static String _defaultOrigin() {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2';
    return 'http://localhost';
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
