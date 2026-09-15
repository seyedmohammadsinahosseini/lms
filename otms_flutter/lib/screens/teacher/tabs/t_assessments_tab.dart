import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;
import '../assessment_builder.dart';
import 'attempts_screen.dart';

/// Teacher assessments manager: create assessments, edit questions,
/// and view student attempts.
class TAssessmentsTab extends StatefulWidget {
  final int classId;
  const TAssessmentsTab({super.key, required this.classId});
  @override
  State<TAssessmentsTab> createState() => _TAssessmentsTabState();
}

class _TAssessmentsTabState extends State<TAssessmentsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Assessment>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.assessments(widget.classId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.assessments(widget.classId));

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateAssessmentSheet(classId: widget.classId),
    );
    if (created == true) _reload();
  }

  Future<void> _deleteAssessment(int assessmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete assessment?'),
        content: const Text('This will delete the assessment and all its questions/attempts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.deleteAssessment(assessmentId);
      if (!mounted) return;
      showOk(context, 'Assessment deleted');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: FutureBuilder<List<Assessment>>(
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
              icon: Icons.quiz_outlined,
              title: 'No assessments yet',
              subtitle: 'Create a quiz, test, or exam for your students.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AssessmentCard(
              assessment: items[i],
              onEdit: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AssessmentBuilder(
                  assessmentId: items[i].id,
                  title: items[i].title,
                ),
              )),
              onAttempts: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AttemptsScreen(
                  assessmentId: items[i].id,
                  title: items[i].title,
                ),
              )),
              onDelete: () => _deleteAssessment(items[i].id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Assessment'),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final Assessment assessment;
  final VoidCallback onEdit;
  final VoidCallback onAttempts;
  final VoidCallback onDelete;

  const _AssessmentCard({
    required this.assessment,
    required this.onEdit,
    required this.onAttempts,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(assessment.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Badge(assessment.kind.toUpperCase(),
                  icon: Icons.label_outline),
              Badge('${assessment.questionCount} Qs',
                  icon: Icons.help_outline),
              Badge('${assessment.durationMin} min',
                  icon: Icons.timer_outlined),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onAttempts,
              icon: const Icon(Icons.people_outline),
              tooltip: 'View attempts',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete assessment',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _CreateAssessmentSheet extends StatefulWidget {
  final int classId;
  const _CreateAssessmentSheet({required this.classId});
  @override
  State<_CreateAssessmentSheet> createState() => _CreateAssessmentSheetState();
}

class _CreateAssessmentSheetState extends State<_CreateAssessmentSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _kind = 'quiz';
  int _duration = 30;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.createAssessment(
        classId: widget.classId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        kind: _kind,
        durationMin: _duration,
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
          const Text('New assessment',
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
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'quiz',
                  label: Text('Quiz'),
                  icon: Icon(Icons.quiz)),
              ButtonSegment(
                  value: 'test',
                  label: Text('Test'),
                  icon: Icon(Icons.assignment)),
              ButtonSegment(
                  value: 'exam',
                  label: Text('Exam'),
                  icon: Icon(Icons.school)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Duration: '),
              Expanded(
                child: Slider(
                  value: _duration.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '$_duration min',
                  onChanged: (v) => setState(() => _duration = v.round()),
                ),
              ),
              Text('$_duration min'),
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
                  : const Text('Create assessment'),
            ),
          ),
        ],
      ),
    );
  }
}