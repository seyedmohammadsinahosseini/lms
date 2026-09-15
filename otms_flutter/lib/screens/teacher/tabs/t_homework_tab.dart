import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;
import '../submissions_screen.dart';

/// Teacher homework manager: post homework and open each item to review
/// and grade student submissions.
class THomeworkTab extends StatefulWidget {
  final int classId;
  const THomeworkTab({super.key, required this.classId});
  @override
  State<THomeworkTab> createState() => _THomeworkTabState();
}

class _THomeworkTabState extends State<THomeworkTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Homework>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.homework(widget.classId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.homework(widget.classId));

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateHomeworkSheet(classId: widget.classId),
    );
    if (created == true) _reload();
  }

  Future<void> _deleteHomework(int homeworkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete homework?'),
        content: const Text('This will delete the homework and all student submissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.deleteHomework(homeworkId);
      if (!mounted) return;
      showOk(context, 'Homework deleted');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: FutureBuilder<List<Homework>>(
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
              icon: Icons.assignment_outlined,
              title: 'No homework yet',
              subtitle: 'Post homework for your students to submit.',
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
        heroTag: 'teacher-homework-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Homework'),
      ),
    );
  }

Widget _card(Homework hw) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(hw.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (hw.dueDate != null)
                Badge('Due ${hw.dueDate}',
                    icon: Icons.event_outlined, color: Colors.orange),
              Badge('${hw.submissionCount ?? 0} submission(s)',
                icon: Icons.inbox_outlined),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _deleteHomework(hw.id),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete homework',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              SubmissionsScreen(homeworkId: hw.id, title: hw.title),
        )),
      ),
    );
  }
}

class _CreateHomeworkSheet extends StatefulWidget {
  final int classId;
  const _CreateHomeworkSheet({required this.classId});
  @override
  State<_CreateHomeworkSheet> createState() => _CreateHomeworkSheetState();
}

class _CreateHomeworkSheetState extends State<_CreateHomeworkSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _due;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.createHomework(
        classId: widget.classId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        dueDate: _due?.toIso8601String().split('T').first,
      );
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
          const Text('New homework',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 20),
              const SizedBox(width: 8),
              Text(_due == null
                  ? 'No due date'
                  : 'Due ${_due!.toIso8601String().split('T').first}'),
              const Spacer(),
              TextButton(
                  onPressed: _pickDue, child: const Text('Set due date')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Post homework'),
            ),
          ),
        ],
      ),
    );
  }
}
