import 'package:flutter/material.dart' hide Badge;

import 'widgets.dart';

/// A DEMO-only live classroom. No real streaming — the video area is a
/// placeholder, participants are mocked, and chat is local to this screen.
class LiveDemoScreen extends StatefulWidget {
  final String className;
  final bool asHost;
  const LiveDemoScreen({
    super.key,
    required this.className,
    this.asHost = false,
  });
  @override
  State<LiveDemoScreen> createState() => _LiveDemoScreenState();
}

class _LiveDemoScreenState extends State<LiveDemoScreen> {
  bool _live = false;
  bool _muted = false;
  bool _camOff = false;
  final _chat = TextEditingController();
  final _messages = <_Msg>[
    _Msg('Ava', 'Is the session starting soon?'),
    _Msg('Liam', 'Can you share the slides after?'),
  ];
  final _participants = ['You', 'Ava', 'Liam', 'Noah', 'Mia'];

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  void _send() {
    final t = _chat.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg('You', t));
      _chat.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Live · ${widget.className}'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Badge('DEMO', color: Colors.orange)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video stage placeholder.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: const Color(0xFF0B0D12),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _live ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white54,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _live
                              ? (widget.asHost
                                  ? 'You are live (demo)'
                                  : 'Live session (demo)')
                              : 'Session not started',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (_live)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 10),
                            SizedBox(width: 6),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Controls.
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ctrl(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  active: !_muted,
                  onTap: () => setState(() => _muted = !_muted),
                ),
                const SizedBox(width: 12),
                _ctrl(
                  icon: _camOff ? Icons.videocam_off : Icons.videocam,
                  active: !_camOff,
                  onTap: () => setState(() => _camOff = !_camOff),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _live ? scheme.error : scheme.primary,
                  ),
                  onPressed: () => setState(() => _live = !_live),
                  icon: Icon(_live ? Icons.call_end : Icons.videocam),
                  label: Text(_live
                      ? 'End'
                      : (widget.asHost ? 'Go live' : 'Join')),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Participants + chat.
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text('Participants',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      ..._participants.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: scheme.primary,
                                  child: Text(p[0],
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.white)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(p,
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RichText(
                                text: TextSpan(
                                  style:
                                      DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                        text: '${m.author}: ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    TextSpan(text: m.text),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chat,
                                decoration: const InputDecoration(
                                  hintText: 'Message (local demo)',
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _send,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctrl(
      {required IconData icon,
      required bool active,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? scheme.secondaryContainer
            : scheme.errorContainer,
      ),
    );
  }
}

class _Msg {
  final String author;
  final String text;
  _Msg(this.author, this.text);
}
