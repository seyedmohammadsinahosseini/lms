import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otms_flutter/models/models.dart';
import 'package:otms_flutter/services/api.dart';
import 'package:otms_flutter/state/auth_provider.dart';

/// A stand-in for the real backend that satisfies [OmsApi] without being HTTP.
///
/// Only the members this test exercises are implemented; everything else falls
/// through to `noSuchMethod`, which is the usual way to write a test double for
/// a wide interface. That the app works against this at all is the point: it is
/// the same seam an on-device, offline implementation will plug into.
class _FakeApi implements OmsApi {
  int loginCalls = 0;
  String? seenEmail;

  @override
  void Function()? onUnauthorized;

  @override
  Future<void> loadToken() async {}

  @override
  String fileUrl(String relativePath) => 'fake://$relativePath';

  @override
  Future<User> login(String email, String password) async {
    loginCalls++;
    seenEmail = email;
    return User(
      id: 1,
      fullName: 'From The Fake',
      email: email,
      role: 'teacher',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a provider reads through Api.instance, not through the HTTP client',
    () async {
      final fake = _FakeApi();
      final previous = Api.instance;
      Api.use(fake);
      addTearDown(() => Api.use(previous));

      final auth = AuthProvider();

      expect(auth.user, isNull);
      await auth.login('someone@otms.test', 'password');

      expect(
        fake.loginCalls,
        1,
        reason: 'AuthProvider must go through whatever Api.instance holds',
      );
      expect(fake.seenEmail, 'someone@otms.test');
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.fullName, 'From The Fake');
    },
  );

  test('the seam carries the whole surface, not just auth', () async {
    final fake = _FakeApi();
    final previous = Api.instance;
    Api.use(fake);
    addTearDown(() => Api.use(previous));

    // A call an implementation has not overridden reaches noSuchMethod rather
    // than silently succeeding, so a screen that called an unimplemented
    // method would fail loudly instead of showing empty data.
    expect(() => Api.instance.classes(), throwsNoSuchMethodError);
    expect(Api.instance.fileUrl('uploads/a.pdf'), 'fake://uploads/a.pdf');
  });
}
