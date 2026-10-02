import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../state/auth_provider.dart';
import 'live_meeting_launcher.dart';
import 'widgets.dart';

/// Real Live-class control surface backed by the authorized live-session API.
/// The historical class name is retained to avoid breaking older routes.
class LiveDemoScreen extends StatefulWidget {
  final int classId;
  final String className;
  final bool asHost;
  const LiveDemoScreen({
    super.key,
    required this.classId,
    required this.className,
    this.asHost = false,
  });

  @override
  State<LiveDemoScreen> createState() => _LiveDemoScreenState();
}

class _LiveDemoScreenState extends State<LiveDemoScreen> {
  late Future<LiveSession?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.currentLive(widget.classId);
  }

  void _reload() =>
      setState(() => _future = Api.instance.currentLive(widget.classId));

  Future<void> _startOrJoin(LiveSession? current) async {
    setState(() => _busy = true);
    try {
      final session =
          current ??
          (widget.asHost
              ? await Api.instance.startLive(widget.classId)
              : throw StateError('No live session is active yet.'));
      final joined = await Api.instance.joinLive(session.id);
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user == null) throw StateError('Your session has expired.');
      await launchLiveMeeting(joined, user);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(LiveSession session) async {
    setState(() => _busy = true);
    try {
      await Api.instance.endLive(session.id);
      if (!mounted) return;
      showOk(context, 'Live session ended.');
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live · ${widget.className}')),
      body: FutureBuilder<LiveSession?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorRetry(error: snapshot.error!, onRetry: _reload);
          }
          final session = snapshot.data;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Icon(
                  session == null
                      ? Icons.videocam_off_outlined
                      : Icons.videocam,
                  size: 88,
                  color: session == null
                      ? Theme.of(context).colorScheme.outline
                      : Colors.red,
                ),
                const SizedBox(height: 20),
                Text(
                  session == null
                      ? 'No live session is active'
                      : 'The class is live now',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? (widget.asHost
                            ? 'Start a protected meeting for enrolled students.'
                            : 'Pull to refresh while you wait for the teacher.')
                      : 'Camera and microphone access is requested by the meeting provider.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _busy || (session == null && !widget.asHost)
                      ? null
                      : () => _startOrJoin(session),
                  icon: const Icon(Icons.video_call_outlined),
                  label: Text(
                    session == null ? 'Start live class' : 'Join live class',
                  ),
                ),
                if (widget.asHost && session != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _end(session),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End live session'),
                  ),
                ],
                if (session == null && !widget.asHost) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
