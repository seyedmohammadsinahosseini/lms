import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api.dart';
import 'showcase/showcase_api.dart';

/// Screenshot-only entrypoint. The production app always starts from main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final requestedRole = Uri.base.queryParameters['role'];
  final role = requestedRole == 'student' || requestedRole == 'anonymous'
      ? requestedRole!
      : 'teacher';
  final api = ShowcaseApi(role);
  Api.use(api);
  runApp(LmsApp(api: api));
}
