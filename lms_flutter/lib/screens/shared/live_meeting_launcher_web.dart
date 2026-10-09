import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';

Future<void> launchLiveMeeting(LiveSession session, User user) async {
  final uri = Uri.tryParse(session.joinUrl ?? '');
  if (uri == null || uri.scheme != 'https' || !await launchUrl(uri)) {
    throw StateError('Could not open the live meeting.');
  }
}
