import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../../models/models.dart';

Future<void> launchLiveMeeting(LiveSession session, User user) async {
  final uri = Uri.tryParse(session.joinUrl ?? '');
  if (uri == null || uri.scheme != 'https') {
    throw StateError('The live meeting URL is invalid.');
  }
  final room =
      session.room ?? (uri.pathSegments.isEmpty ? null : uri.pathSegments.last);
  if (room == null || room.isEmpty) {
    throw StateError('The live room is missing.');
  }

  var serverPath = uri.pathSegments.toList();
  if (serverPath.isNotEmpty) serverPath.removeLast();
  final serverUrl = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: serverPath,
  ).toString().replaceFirst(RegExp(r'/$'), '');

  final options = JitsiMeetConferenceOptions(
    serverURL: serverUrl,
    room: room,
    token: session.token,
    configOverrides: const {
      'startWithAudioMuted': false,
      'startWithVideoMuted': false,
    },
    userInfo: JitsiMeetUserInfo(displayName: user.fullName, email: user.email),
  );
  await JitsiMeet().join(options);
}
