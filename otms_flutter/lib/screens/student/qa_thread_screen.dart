import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../shared/widgets.dart';

/// A single Q&A thread: the original question plus replies, with an inline
/// composer at the bottom. Both students and teachers reply here; teacher
/// replies get an "Teacher" tag so answers stand out.
class QaThreadScreen extends StatefulWidget {
  final int threadId;
  const QaThreadScreen({super.key, required this.threadId});
  @override
  State<QaThreadScreen> createState() => _QaThreadScreenState();
}

class _QaThreadScreenState extends State<QaThreadScreen> {
  late Future<QaThreadDetail> _future;
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.qaThread(widget.threadId);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.qaThread(widget.threadId));

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.replyThread(widget.threadId, body);
      _reply.clear();
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Question')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<QaThreadDetail>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorRetry(error: snap.error!, onRetry: _reload);
                }
                final d = snap.data!;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _questionCard(d.thread),
                    const SizedBox(height: 8),
                    if (d.replies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No replies yet.',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.outline)),
                        ),
                      )
                    else
                      ...d.replies.map(_replyCard),
                  ],
                );
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _questionCard(QaThread t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            if (t.body != null && t.body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.body!),
            ],
            const SizedBox(height: 10),
            Text('Asked by ${t.authorName}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _replyCard(QaReply r) {
    final isTeacher = r.authorRole == 'teacher';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isTeacher ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(r.authorName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (isTeacher)
                  const Badge('Teacher',
                      icon: Icons.school, color: Colors.indigo),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.body),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _reply,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write a reply...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
