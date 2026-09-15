import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/file_helper.dart';
import '../../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;

/// Student view of a class's homework. Each item shows its own submission
/// status; tapping opens a sheet to submit text and/or a file. A student
/// only ever sees their own submission — never anyone else's.
class HomeworkTab extends StatefulWidget {
  final int classId;
  const HomeworkTab({super.key, required this.classId});
  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab>
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

  Future<void> _openSubmit(Homework hw) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubmitSheet(homework: hw),
    );
    if (done == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Homework>>(
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
            subtitle: 'Your teacher hasn\'t posted any homework.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _card(items[i]),
        );
      },
    );
  }

  Widget _card(Homework hw) {
    final sub = hw.mySubmission;
    final grade = sub?['grade'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hw.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (hw.description != null && hw.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(hw.description!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hw.dueDate != null)
                  Badge('Due ${hw.dueDate}',
                      icon: Icons.event_outlined, color: Colors.orange),
                if (sub == null)
                  const Badge('Not submitted',
                      icon: Icons.pending_outlined, color: Colors.blueGrey)
                else if (grade != null)
                  Badge('Grade: $grade',
                      icon: Icons.grade, color: Colors.green)
                else
                  const Badge('Submitted',
                      icon: Icons.check_circle_outline, color: Colors.teal),
              ],
            ),
            if (sub?['feedback'] != null &&
                (sub!['feedback'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Feedback: ${sub['feedback']}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (sub != null && grade == null)
                  TextButton.icon(
                    onPressed: () => _deleteSubmission(sub['id'] as int, hw),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                if (sub != null && grade == null) const SizedBox(width: 8),
                sub == null
                    ? FilledButton.icon(
                        onPressed: () => _openSubmit(hw),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Submit'),
                      )
                    : (grade == null
                        ? TextButton.icon(
                            onPressed: () => _openSubmit(hw),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Resubmit'),
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSubmission(int submissionId, Homework hw) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete submission?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.deleteSubmission(submissionId);
      if (!mounted) return;
      showOk(context, 'Submission deleted');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

class _SubmitSheet extends StatefulWidget {
  final Homework homework;
  const _SubmitSheet({required this.homework});
  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _text = TextEditingController();
  PickedFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(bool image) async {
    final f = image ? await pickImage() : await pickAnyFile();
    if (f != null) setState(() => _file = f);
  }

  Future<void> _submit() async {
    if (_text.text.trim().isEmpty && _file == null) {
      showError(context, 'Add some text or attach a file first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.submitHomework(
        homeworkId: widget.homework.id,
        text: _text.text.trim().isEmpty ? null : _text.text.trim(),
        fileBytes: _file?.bytes,
        fileName: _file?.name,
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
          Text('Submit: ${widget.homework.title}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your answer (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Image'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('File'),
              ),
            ],
          ),
          if (_file != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(_file!.name,
                          overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _file = null),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit homework'),
            ),
          ),
        ],
      ),
    );
  }
}
