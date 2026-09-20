import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api.dart';
import '../../shared/widgets.dart';
import '../qa_thread_screen.dart';

/// Class Q&A board. Students post questions and read replies; teachers
/// answer from the same thread view. Shared by both roles.
class QaTab extends StatefulWidget {
  final int classId;
  const QaTab({super.key, required this.classId});
  @override
  State<QaTab> createState() => _QaTabState();
}

class _QaTabState extends State<QaTab> with AutomaticKeepAliveClientMixin {
  late Future<List<QaThread>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.qaThreads(widget.classId);
  }

  void _reload() =>
      setState(() => _future = Api.instance.qaThreads(widget.classId));

  Future<void> _open(int threadId) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QaThreadScreen(threadId: threadId),
    ));
    _reload(); // reply count may have changed
  }

  Future<void> _ask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AskSheet(classId: widget.classId),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: FutureBuilder<List<QaThread>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorRetry(error: snap.error!, onRetry: _reload);
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No questions yet',
              subtitle: 'Be the first to ask something.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _card(items[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'student-qa-fab',
        onPressed: _ask,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Ask'),
      ),
    );
  }

  Widget _card(QaThread t) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(t.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Text('by ${t.authorName}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12)),
              const SizedBox(width: 10),
              Badge('${t.replyCount} repl${t.replyCount == 1 ? 'y' : 'ies'}',
                  icon: Icons.chat_bubble_outline),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(t.id),
      ),
    );
  }
}

class _AskSheet extends StatefulWidget {
  final int classId;
  const _AskSheet({required this.classId});
  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Give your question a title.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance
          .createThread(widget.classId, _title.text.trim(), _body.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ask a question',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _post,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Post question'),
            ),
          ),
        ],
      ),
    );
  }
}
