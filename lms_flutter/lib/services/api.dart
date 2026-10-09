/// Where the app picks its data layer.
///
/// Everything in the app reaches the backend through `Api.instance`, which is
/// typed as [LmsApi] rather than as any concrete client. That indirection is
/// the whole point: swapping the HTTP backend for an on-device one (so the app
/// runs on a phone with no server) becomes a change in exactly one place --
/// [use] -- instead of a change in every screen.
///
/// ```dart
/// Api.use(LocalApi());   // offline, SQLite on the device
/// Api.instance.classes(); // unchanged everywhere else
/// ```
///
/// The export below lets callers import a single file for both the interface
/// and the exceptions it documents, so screens do not need to know which
/// implementation is in play.
library;

import 'api_client.dart';
import 'lms_api.dart';

export 'api_client.dart' show ApiException;
export 'lms_api.dart' show LmsApi;

/// Holds the implementation in use. Defaults to the HTTP client, which is what
/// a web build and a networked phone talk to.
abstract final class Api {
  /// The active implementation. Read it, do not replace it directly -- use
  /// [use], which exists so the intent is visible at the call site.
  static LmsApi instance = ApiClient();

  /// Switches the app to [implementation].
  ///
  /// Call this once, before the widget tree reads any data (in `main`, next to
  /// the startup `loadToken`), so nothing observes a half-swapped client.
  static void use(LmsApi implementation) => instance = implementation;
}
