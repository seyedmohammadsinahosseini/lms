import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api.dart';
import '../../shared/widgets.dart'
    show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;
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
    _future = Api.instance.assessments(widget.classId);
  }

  @override
  void didUpdateWidget(covariant TAssessmentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _future = Api.instance.assessments(widget.classId);
    }
  }

  void _reload() =>
      setState(() => _future = Api.instance.assessments(widget.classId));

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
        content: const Text(
          'This will delete the assessment and all its questions/attempts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.instance.deleteAssessment(assessmentId);
      if (!mounted) return;
      showOk(context, 'Assessment deleted');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _publish(Assessment assessment) async {
    try {
      await Api.instance.publishAssessment(assessment.id);
      if (!mounted) return;
      showOk(
        context,
        assessment.status == 'closed'
            ? 'Assessment reopened.'
            : 'Assessment published.',
      );
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _close(Assessment assessment) async {
    try {
      await Api.instance.closeAssessment(assessment.id);
      if (!mounted) return;
      showOk(context, 'Assessment closed.');
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _setReleased(Assessment assessment, bool release) async {
    try {
      await Api.instance.releaseAssessmentAnswers(assessment.id, release);
      if (!mounted) return;
      showOk(context, release ? 'Answers released.' : 'Answers hidden.');
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AssessmentCard(
              assessment: items[i],
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssessmentBuilder(
                    assessmentId: items[i].id,
                    title: items[i].title,
                  ),
                ),
              ),
              onAttempts: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttemptsScreen(
                    assessmentId: items[i].id,
                    title: items[i].title,
                  ),
                ),
              ),
              onPublish: () => _publish(items[i]),
              onClose: () => _close(items[i]),
              onRelease: (release) => _setReleased(items[i], release),
              onDelete: () => _deleteAssessment(items[i].id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher-assessments-fab',
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
  final VoidCallback onPublish;
  final VoidCallback onClose;
  final ValueChanged<bool> onRelease;
  final VoidCallback onDelete;

  const _AssessmentCard({
    required this.assessment,
    required this.onEdit,
    required this.onAttempts,
    required this.onPublish,
    required this.onClose,
    required this.onRelease,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (assessment.status) {
      'published' => Colors.green,
      'closed' => Colors.blueGrey,
      _ => Colors.orange,
    };
    final releaseLabel = switch (assessment.answerReleasePolicy) {
      'immediately' => 'Answers: immediately',
      'after_close' => 'Answers: after close',
      'never' => 'Answers: never',
      _ =>
        assessment.answersReleased
            ? 'Answers: released'
            : 'Answers: teacher release',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    assessment.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Assessment actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'attempts':
                        onAttempts();
                        break;
                      case 'publish':
                        onPublish();
                        break;
                      case 'close':
                        onClose();
                        break;
                      case 'release':
                        onRelease(true);
                        break;
                      case 'hide':
                        onRelease(false);
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit questions'),
                    ),
                    const PopupMenuItem(
                      value: 'attempts',
                      child: Text('View attempts'),
                    ),
                    if (assessment.status != 'published')
                      PopupMenuItem(
                        value: 'publish',
                        child: Text(
                          assessment.status == 'closed'
                              ? 'Reopen assessment'
                              : 'Publish assessment',
                        ),
                      ),
                    if (assessment.status == 'published')
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Close assessment'),
                      ),
                    if (assessment.answerReleasePolicy == 'teacher_release')
                      PopupMenuItem(
                        value: assessment.answersReleased ? 'hide' : 'release',
                        child: Text(
                          assessment.answersReleased
                              ? 'Hide released answers'
                              : 'Release answers',
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Badge(
                  assessment.status.toUpperCase(),
                  icon: Icons.circle,
                  color: statusColor,
                ),
                Badge(assessment.kind.toUpperCase(), icon: Icons.label_outline),
                Badge(
                  '${assessment.questionCount} Qs',
                  icon: Icons.help_outline,
                ),
                Badge(
                  '${assessment.durationMin} min',
                  icon: Icons.timer_outlined,
                ),
                Badge(
                  '${assessment.maxAttempts} attempt(s)',
                  icon: Icons.replay_outlined,
                ),
                Badge(releaseLabel, icon: Icons.visibility_outlined),
                if (assessment.opensAt != null)
                  Badge(
                    'Opens ${assessment.opensAt}',
                    icon: Icons.lock_open_outlined,
                  ),
                if (assessment.closesAt != null)
                  Badge(
                    'Closes ${assessment.closesAt}',
                    icon: Icons.event_busy_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Questions'),
                ),
                TextButton.icon(
                  onPressed: onAttempts,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Attempts'),
                ),
                if (assessment.status == 'draft')
                  FilledButton.tonalIcon(
                    onPressed: onPublish,
                    icon: const Icon(Icons.publish_outlined),
                    label: const Text('Publish'),
                  ),
              ],
            ),
          ],
        ),
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
  int _maxAttempts = 1;
  String _releasePolicy = 'teacher_release';
  DateTime? _opensAt;
  DateTime? _closesAt;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool opening) async {
    final initial = (opening ? _opensAt : _closesAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (opening) {
        _opensAt = value;
      } else {
        _closesAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    if (_opensAt != null &&
        _closesAt != null &&
        !_closesAt!.isAfter(_opensAt!)) {
      showError(context, 'The closing time must be after the opening time.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.createAssessment(
        classId: widget.classId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        kind: _kind,
        durationMin: _duration,
        maxAttempts: _maxAttempts,
        opensAt: _opensAt?.toUtc().toIso8601String(),
        closesAt: _closesAt?.toUtc().toIso8601String(),
        answerReleasePolicy: _releasePolicy,
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New assessment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
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
                  icon: Icon(Icons.quiz),
                ),
                ButtonSegment(
                  value: 'test',
                  label: Text('Test'),
                  icon: Icon(Icons.assignment),
                ),
                ButtonSegment(
                  value: 'exam',
                  label: Text('Exam'),
                  icon: Icon(Icons.school),
                ),
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
            Row(
              children: [
                const Icon(Icons.replay_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Maximum attempts: '),
                Expanded(
                  child: Slider(
                    value: _maxAttempts.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_maxAttempts',
                    onChanged: (value) =>
                        setState(() => _maxAttempts = value.round()),
                  ),
                ),
                Text('$_maxAttempts'),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _releasePolicy,
              decoration: const InputDecoration(
                labelText: 'Answer release policy',
                prefixIcon: Icon(Icons.visibility_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'immediately',
                  child: Text('Immediately after submission'),
                ),
                DropdownMenuItem(
                  value: 'after_close',
                  child: Text('After the assessment closes'),
                ),
                DropdownMenuItem(
                  value: 'teacher_release',
                  child: Text('When I release answers'),
                ),
                DropdownMenuItem(
                  value: 'never',
                  child: Text('Never show answer keys'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _releasePolicy = value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_open_outlined),
              title: Text(
                _opensAt == null
                    ? 'Available immediately after publishing'
                    : 'Opens ${_opensAt!.toLocal()}',
              ),
              trailing: TextButton(
                onPressed: () => _pickDateTime(true),
                child: const Text('Set'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(
                _closesAt == null
                    ? 'No automatic closing time'
                    : 'Closes ${_closesAt!.toLocal()}',
              ),
              trailing: TextButton(
                onPressed: () => _pickDateTime(false),
                child: const Text('Set'),
              ),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
