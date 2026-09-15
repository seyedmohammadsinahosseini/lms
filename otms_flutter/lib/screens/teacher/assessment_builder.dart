import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;

/// Teacher screen to author questions for an assessment.
/// Supports all 5 question types with appropriate editors.
class AssessmentBuilder extends StatefulWidget {
  final int assessmentId;
  final String title;
  const AssessmentBuilder({
    super.key,
    required this.assessmentId,
    required this.title,
  });
  @override
  State<AssessmentBuilder> createState() => _AssessmentBuilderState();
}

class _AssessmentBuilderState extends State<AssessmentBuilder> {
  late Future<AssessmentDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.assessmentDetail(widget.assessmentId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.assessmentDetail(widget.assessmentId));

  Future<void> _addQuestion() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionEditorSheet(assessmentId: widget.assessmentId),
    );
    if (added == true) _reload();
  }

  Future<void> _deleteQuestion(int questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.instance.deleteQuestion(questionId);
      if (!mounted) return;
      showOk(context, 'Question deleted');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<AssessmentDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorRetry(error: snap.error!, onRetry: _reload);
          }
          final detail = snap.data!;
          final questions = detail.questions;
          if (questions.isEmpty) {
            return const EmptyState(
              icon: Icons.quiz_outlined,
              title: 'No questions yet',
              subtitle: 'Add your first question to this assessment.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: questions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _QuestionCard(
              question: questions[i],
              onDelete: () => _deleteQuestion(questions[i].id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addQuestion,
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onDelete;
  const _QuestionCard({required this.question, required this.onDelete});

  IconData _iconFor(String type) {
    switch (type) {
      case 'multiple_choice':
        return Icons.radio_button_checked;
      case 'true_false':
        return Icons.toggle_on;
      case 'yes_no':
        return Icons.check_box_outline_blank;
      case 'fill_blank':
        return Icons.edit_note;
      case 'essay':
        return Icons.edit_document;
      default:
        return Icons.help_outline;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'true_false':
        return 'True / False';
      case 'yes_no':
        return 'Yes / No';
      case 'fill_blank':
        return 'Fill in the Blank';
      case 'essay':
        return 'Essay';
      default:
        return type;
    }
  }

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
                Icon(_iconFor(question.type),
                    color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_typeLabel(question.type),
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                Badge('${question.points} pts',
                    color: scheme.secondary),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete question',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(question.text,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (question.type == 'multiple_choice' ||
                question.type == 'true_false' ||
                question.type == 'yes_no') ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: question.options.map((opt) {
                  final isCorrect = opt.isCorrect == true;
                  return Chip(
                    label: Text(opt.text),
                    avatar: isCorrect
                        ? Icon(Icons.check_circle, color: Colors.green, size: 16)
                        : null,
                    backgroundColor: isCorrect
                        ? Colors.green.withValues(alpha: 0.12)
                        : null,
                  );
                }).toList(),
              ),
            ] else if (question.type == 'fill_blank') ...[
              if (question.options.isNotEmpty)
                Text('Answer: ${question.options.first.text}',
                    style: TextStyle(color: scheme.outline)),
            ],
            if (question.type == 'essay')
              Text('(Manually graded)',
                  style: TextStyle(color: scheme.outline, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

class _QuestionEditorSheet extends StatefulWidget {
  final int assessmentId;
  const _QuestionEditorSheet({required this.assessmentId});
  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  String _type = 'multiple_choice';
  final _text = TextEditingController();
  final _points = TextEditingController(text: '1');
  final _correctAnswer = TextEditingController();
  final List<_OptionInput> _options = [
    _OptionInput(text: '', isCorrect: false),
    _OptionInput(text: '', isCorrect: false),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _points.dispose();
    _correctAnswer.dispose();
    super.dispose();
  }

  bool get _isMultipleChoice => _type == 'multiple_choice';
  bool get _isTrueFalse => _type == 'true_false';
  bool get _isYesNo => _type == 'yes_no';
  bool get _isFillBlank => _type == 'fill_blank';
  bool get _isEssay => _type == 'essay';

  void _addOption() {
    if (_options.length < 5) {
      setState(() => _options.add(_OptionInput(text: '', isCorrect: false)));
    }
  }

  void _removeOption(int index) {
    if (_options.length > 2) {
      setState(() => _options.removeAt(index));
    }
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      showError(context, 'Enter question text.');
      return;
    }
    final points = int.tryParse(_points.text.trim()) ?? 1;

    final payload = <String, dynamic>{
      'assessment_id': widget.assessmentId,
      'type': _type,
      'text': _text.text.trim(),
      'points': points,
    };

    if (_isMultipleChoice) {
      final opts = _options
          .where((o) => o.text.trim().isNotEmpty)
          .map((o) => {'text': o.text.trim(), 'is_correct': o.isCorrect})
          .toList();
      if (opts.length < 2) {
        showError(context, 'Multiple choice needs at least 2 options.');
        return;
      }
      if (!opts.any((o) => o['is_correct'] == true)) {
        showError(context, 'Mark at least one option as correct.');
        return;
      }
      payload['options'] = opts;
    } else if (_isTrueFalse) {
      payload['options'] = [
        {'text': 'True', 'is_correct': _correctAnswer.text == 'true'},
        {'text': 'False', 'is_correct': _correctAnswer.text == 'false'},
      ];
    } else if (_isYesNo) {
      payload['options'] = [
        {'text': 'Yes', 'is_correct': _correctAnswer.text == 'yes'},
        {'text': 'No', 'is_correct': _correctAnswer.text == 'no'},
      ];
    } else if (_isFillBlank) {
      if (_correctAnswer.text.trim().isEmpty) {
        showError(context, 'Enter the correct answer.');
        return;
      }
      // Backend expects options array with one correct option for fill_blank
      payload['options'] = [
        {'text': _correctAnswer.text.trim(), 'is_correct': true}
      ];
    }

    setState(() => _busy = true);
    try {
      await ApiClient.instance.addQuestion(payload);
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
          const Text('Add question',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'multiple_choice',
                  label: Text('Multiple Choice'),
                  icon: Icon(Icons.radio_button_checked)),
              ButtonSegment(
                  value: 'true_false',
                  label: Text('True / False'),
                  icon: Icon(Icons.toggle_on)),
              ButtonSegment(
                  value: 'yes_no',
                  label: Text('Yes / No'),
                  icon: Icon(Icons.check_box_outline_blank)),
              ButtonSegment(
                  value: 'fill_blank',
                  label: Text('Fill Blank'),
                  icon: Icon(Icons.edit_note)),
              ButtonSegment(
                  value: 'essay',
                  label: Text('Essay'),
                  icon: Icon(Icons.edit_document)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
            multiSelectionEnabled: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Question text',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isMultipleChoice) ...[
            const Text('Options (2–5, mark correct):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: opt.isCorrect,
                      onChanged: (v) =>
                          setState(() => opt.isCorrect = v ?? false),
                    ),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => opt.text = v,
                      ),
                    ),
                    if (_options.length > 2)
                      IconButton(
                        onPressed: () => _removeOption(i),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Remove option',
                      ),
                  ],
                ),
              );
            }),
            if (_options.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add option'),
              ),
          ] else if (_isTrueFalse) ...[
            const Text('Correct answer:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'true', label: Text('True')),
                ButtonSegment(value: 'false', label: Text('False')),
              ],
              selected: {_correctAnswer.text.isEmpty ? 'true' : _correctAnswer.text},
              onSelectionChanged: (s) =>
                  setState(() => _correctAnswer.text = s.first),
            ),
          ] else if (_isYesNo) ...[
            const Text('Correct answer:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'yes', label: Text('Yes')),
                ButtonSegment(value: 'no', label: Text('No')),
              ],
              selected: {_correctAnswer.text.isEmpty ? 'yes' : _correctAnswer.text},
              onSelectionChanged: (s) =>
                  setState(() => _correctAnswer.text = s.first),
            ),
          ] else if (_isFillBlank) ...[
            TextField(
              controller: _correctAnswer,
              decoration: const InputDecoration(
                labelText: 'Correct answer',
                border: OutlineInputBorder(),
              ),
            ),
          ] else if (_isEssay) ...[
            const Text(
              'Essay questions are manually graded after submission.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
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
                  : const Text('Add question'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionInput {
  String text;
  bool isCorrect;
  _OptionInput({required this.text, required this.isCorrect});
}