import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/widgets.dart'
    show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;

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
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _future = Api.instance.assessmentDetail(widget.assessmentId);
  }

  void _reload() => setState(
    () => _future = Api.instance.assessmentDetail(widget.assessmentId),
  );

  Future<void> _addQuestion() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionEditorSheet(assessmentId: widget.assessmentId),
    );
    if (added == true) _reload();
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await Api.instance.publishAssessment(widget.assessmentId);
      if (!mounted) return;
      showOk(context, 'Assessment published. Students can now start it.');
      _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _deleteQuestion(int questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('This action cannot be undone.'),
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
      await Api.instance.deleteQuestion(questionId);
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: const Text('Publish'),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
        heroTag: 'assessment-builder-fab',
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
      case 'single_choice':
      case 'multiple_choice':
        return Icons.radio_button_checked;
      case 'multiple_select':
        return Icons.checklist;
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
      case 'single_choice':
      case 'multiple_choice':
        return 'Single Choice';
      case 'multiple_select':
        return 'Multiple Select';
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
                Icon(_iconFor(question.type), color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _typeLabel(question.type),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Badge('${question.points} pts', color: scheme.secondary),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete question',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (question.type == 'single_choice' ||
                question.type == 'multiple_choice' ||
                question.type == 'multiple_select' ||
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
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          )
                        : null,
                    backgroundColor: isCorrect
                        ? Colors.green.withValues(alpha: 0.12)
                        : null,
                  );
                }).toList(),
              ),
            ] else if (question.type == 'fill_blank') ...[
              if (question.options.isNotEmpty)
                Text(
                  'Answer: ${question.options.first.text}',
                  style: TextStyle(color: scheme.outline),
                ),
            ],
            if (question.type == 'essay')
              Text(
                '(Manually graded)',
                style: TextStyle(
                  color: scheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
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
  String _type = 'single_choice';
  final _text = TextEditingController();
  final _points = TextEditingController(text: '1');
  final _correctAnswer = TextEditingController();
  final List<_OptionInput> _options = [
    _OptionInput(text: '', isCorrect: true),
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

  bool get _isChoice => _type == 'single_choice' || _type == 'multiple_select';
  bool get _isSingleChoice => _type == 'single_choice';
  bool get _isTrueFalse => _type == 'true_false';
  bool get _isYesNo => _type == 'yes_no';
  bool get _isFillBlank => _type == 'fill_blank';
  bool get _isEssay => _type == 'essay';

  void _addOption() {
    if (_options.length < 10) {
      setState(() => _options.add(_OptionInput(text: '', isCorrect: false)));
    }
  }

  void _removeOption(int index) {
    if (_options.length > 2) setState(() => _options.removeAt(index));
  }

  void _setOptionCorrect(int index, bool correct) {
    setState(() {
      if (_isSingleChoice && correct) {
        for (final option in _options) {
          option.isCorrect = false;
        }
      }
      _options[index].isCorrect = correct;
    });
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      showError(context, 'Enter question text.');
      return;
    }
    final points = int.tryParse(_points.text.trim()) ?? 0;
    if (points < 1 || points > 1000) {
      showError(context, 'Points must be between 1 and 1000.');
      return;
    }

    final payload = <String, dynamic>{
      'assessment_id': widget.assessmentId,
      'type': _type,
      'text': _text.text.trim(),
      'points': points,
    };

    if (_isChoice) {
      final options = _options
          .where((option) => option.text.trim().isNotEmpty)
          .map(
            (option) => {
              'text': option.text.trim(),
              'is_correct': option.isCorrect,
            },
          )
          .toList();
      if (options.length < 2) {
        showError(context, 'Choice questions need at least two options.');
        return;
      }
      final correctCount = options
          .where((option) => option['is_correct'] == true)
          .length;
      if (_isSingleChoice && correctCount != 1) {
        showError(context, 'Single choice needs exactly one correct option.');
        return;
      }
      if (!_isSingleChoice && correctCount < 1) {
        showError(context, 'Mark at least one option as correct.');
        return;
      }
      payload['options'] = options;
    } else if (_isTrueFalse) {
      payload['correct'] = _correctAnswer.text.isEmpty
          ? 'true'
          : _correctAnswer.text;
    } else if (_isYesNo) {
      payload['correct'] = _correctAnswer.text.isEmpty
          ? 'yes'
          : _correctAnswer.text;
    } else if (_isFillBlank) {
      final answer = _correctAnswer.text.trim();
      if (answer.isEmpty) {
        showError(context, 'Enter the correct answer.');
        return;
      }
      payload['answer'] = answer;
    }

    setState(() => _busy = true);
    try {
      await Api.instance.addQuestion(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, keyboard + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add question', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Question type'),
              items: const [
                DropdownMenuItem(
                  value: 'single_choice',
                  child: Text('Single Choice'),
                ),
                DropdownMenuItem(
                  value: 'multiple_select',
                  child: Text('Multiple Select'),
                ),
                DropdownMenuItem(
                  value: 'true_false',
                  child: Text('True / False'),
                ),
                DropdownMenuItem(value: 'yes_no', child: Text('Yes / No')),
                DropdownMenuItem(
                  value: 'fill_blank',
                  child: Text('Fill in the Blank'),
                ),
                DropdownMenuItem(value: 'essay', child: Text('Essay')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _type = value ?? _type;
                      _correctAnswer.clear();
                    }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Question text',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _points,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: 16),
            if (_isChoice) ...[
              Text(
                _isSingleChoice
                    ? 'Options — select exactly one correct answer'
                    : 'Options — select every correct answer',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: option.isCorrect,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  _setOptionCorrect(index, value ?? false),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: option.text,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                          ),
                          onChanged: (value) => option.text = value,
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          onPressed: _busy ? null : () => _removeOption(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                );
              }),
              if (_options.length < 10)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
                ),
            ] else if (_isTrueFalse || _isYesNo) ...[
              Text(
                'Correct answer',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: _isTrueFalse
                    ? const [
                        ButtonSegment(value: 'true', label: Text('True')),
                        ButtonSegment(value: 'false', label: Text('False')),
                      ]
                    : const [
                        ButtonSegment(value: 'yes', label: Text('Yes')),
                        ButtonSegment(value: 'no', label: Text('No')),
                      ],
                selected: {
                  _correctAnswer.text.isEmpty
                      ? (_isTrueFalse ? 'true' : 'yes')
                      : _correctAnswer.text,
                },
                onSelectionChanged: _busy
                    ? null
                    : (selection) =>
                          setState(() => _correctAnswer.text = selection.first),
              ),
            ] else if (_isFillBlank) ...[
              TextField(
                controller: _correctAnswer,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Correct answer'),
              ),
            ] else if (_isEssay) ...[
              const Text('Essay responses are graded manually by the teacher.'),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add question'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionInput {
  String text;
  bool isCorrect;
  _OptionInput({required this.text, required this.isCorrect});
}
