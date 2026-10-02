import 'package:flutter/material.dart' hide Badge;
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/widgets.dart'
    show LoadingView, ErrorRetry, EmptyState, Badge, showError;

/// Teacher view of all submissions for one homework item.
/// Allows viewing files, text, and grading each submission.
class SubmissionsScreen extends StatefulWidget {
  final int homeworkId;
  final String title;
  const SubmissionsScreen({
    super.key,
    required this.homeworkId,
    required this.title,
  });
  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  late Future<List<Submission>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.submissions(widget.homeworkId);
  }

  void _reload() =>
      setState(() => _future = Api.instance.submissions(widget.homeworkId));

  Future<void> _openFile(String filePath) async {
    final url = Api.instance.fileUrl(filePath);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showError(context, 'Could not open file');
    }
  }

  Future<void> _showHistory(Submission submission) async {
    var history = Api.instance.submissionHistory(submission.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: .8,
            child: FutureBuilder<List<SubmissionVersion>>(
              future: history,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorRetry(
                    error: snapshot.error!,
                    onRetry: () => setSheetState(
                      () => history = Api.instance.submissionHistory(
                        submission.id,
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${submission.studentName} · submission history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...(snapshot.data ?? const []).map(
                      (version) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Version ${version.versionNo}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (version.isLate)
                                    const Badge('Late', color: Colors.orange),
                                ],
                              ),
                              if (version.submittedAt != null)
                                Text(
                                  version.submittedAt!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (version.text?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(version.text!),
                              ],
                              if (version.filePath != null)
                                TextButton.icon(
                                  onPressed: () => _openFile(version.filePath!),
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Open attachment'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _grade(Submission s) async {
    final gradeCtrl = TextEditingController(text: s.grade ?? '');
    final feedbackCtrl = TextEditingController(text: s.feedback ?? '');
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade ${s.studentName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grade (e.g. A, 85/100, Pass)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setSheet(() => busy = true);
                          try {
                            await Api.instance.gradeSubmission(
                              s.id,
                              gradeCtrl.text.trim(),
                              feedbackCtrl.text.trim(),
                            );
                            // `context` here is the bottom sheet's; guard against
                            // the sheet being dismissed while the request is in
                            // flight. `mounted` (the screen's State) guards
                            // `_reload()`, which rebuilds the screen, not the sheet.
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (mounted) _reload();
                          } catch (e) {
                            if (!context.mounted) return;
                            showError(context, e);
                            setSheet(() => busy = false);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save grade'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Submission>>(
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
              title: 'No submissions yet',
              subtitle:
                  'Students have not submitted anything for this homework.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _SubmissionCard(
              submission: items[i],
              onOpenFile: _openFile,
              onHistory: _showHistory,
              onGrade: _grade,
            ),
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  final void Function(String filePath) onOpenFile;
  final void Function(Submission) onHistory;
  final void Function(Submission) onGrade;

  const _SubmissionCard({
    required this.submission,
    required this.onOpenFile,
    required this.onHistory,
    required this.onGrade,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    submission.studentName.isNotEmpty
                        ? submission.studentName[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    submission.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Badge(
                  'Version ${submission.versionNo}',
                  icon: Icons.history_outlined,
                ),
                if (submission.isLate) ...[
                  const SizedBox(width: 6),
                  const Badge('Late', color: Colors.orange),
                ],
                if (submission.grade != null) ...[
                  const SizedBox(width: 6),
                  Badge(submission.grade!, color: Colors.green),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (submission.text != null && submission.text!.isNotEmpty) ...[
              Text(
                'Submission:',
                style: TextStyle(
                  color: scheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(submission.text!),
              const SizedBox(height: 12),
            ],
            if (submission.filePath != null) ...[
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      submission.filePath!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onOpenFile(submission.filePath!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View file'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (submission.submittedAt != null)
              Text(
                'Submitted: ${submission.submittedAt}',
                style: TextStyle(color: scheme.outline, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (submission.grade != null ||
                    submission.feedback != null) ...[
                  if (submission.feedback != null)
                    Expanded(
                      child: Text(
                        'Feedback: ${submission.feedback}',
                        style: TextStyle(color: scheme.outline, fontSize: 13),
                      ),
                    ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onHistory(submission),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
                TextButton.icon(
                  onPressed: () => onGrade(submission),
                  icon: const Icon(Icons.grade, size: 18),
                  label: const Text('Grade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
