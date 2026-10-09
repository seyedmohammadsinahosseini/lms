import 'package:flutter/foundation.dart';

/// Build-time configuration. `LMS_API_BASE` always means the directory that
/// contains the PHP endpoints, for example `https://example.net/api/v1`.
class Env {
  const Env._();

  static const String _apiBaseOverride = String.fromEnvironment('LMS_API_BASE');
  static const String appMode = String.fromEnvironment(
    'LMS_APP_MODE',
    defaultValue: 'development',
  );

  static bool get isPortfolioDemo => appMode == 'portfolio_demo';
  static bool get isProduction => appMode == 'production';

  static String get apiBase {
    if (_apiBaseOverride.isNotEmpty) {
      return _stripTrailingSlash(_apiBaseOverride);
    }
    if (isProduction || isPortfolioDemo) {
      throw StateError(
        'LMS_API_BASE is required for portfolio_demo and production builds.',
      );
    }
    return '${_defaultOrigin()}${kIsWeb ? '/api/v1' : '/lms/backend/api/v1'}';
  }

  /// Kept for older call sites; authenticated files now live behind an API
  /// endpoint and therefore resolve against [apiBase], not a public upload root.
  static String get apiBaseUrl => apiBase;

  static String _defaultOrigin() {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') return base.origin;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2';
    }
    return 'http://localhost';
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
