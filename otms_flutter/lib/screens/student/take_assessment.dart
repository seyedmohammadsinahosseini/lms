import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../shared/widgets.dart';
import 'attempt_result.dart';

/// Lets a student answer every question type and submit the attempt.
/// Answer values: option id (int) for mc/tf/yes_no, free text for
/// fill_blank/essay. Objective types auto-grade server-side.
class TakeAssessment extends StatefulWidget {
  final int assessmentId;
  final String title;
  const TakeAssessment({
    super.key,
    required this.assessmentId,
    required this.title,
  });
  @override
  State<TakeAssessment> createState() => _TakeAssessmentState();
}

class _TakeAssessmentState extends State<TakeAssessment> {
  late Future<AssessmentDetail> _future;
  final Map<int, dynamic> _answers = {}; // questionId -> optionId | String
  final Map<int, TextEditingController> _text = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.assessmentDetail(widget.assessmentId);
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int qid) =>
      _text.putIfAbsent(qid, () => TextEditingController());

  Future<void> _submit(AssessmentDetail a) async {
    // Collect text answers into the map.
    for (final q in a.questions) {
      if (q.type == 'fill_blank' || q.type == 'essay') {
        _answers[q.id] = _controllerFor(q.id).text.trim();
      }
    }
    final unanswered = a.questions
        .where((q) =>
            !_answers.containsKey(q.id) ||
            (_answers[q.id] is String &&
                (_answers[q.id] as String).isEmpty))
        .length;
    if (unanswered > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submit anyway?'),
          content: Text('$unanswered question(s) are unanswered.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep going')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit')),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _submitting = true);
    try {
      final result =
          await ApiClient.instance.submitAttempt(widget.assessmentId, _answers);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AttemptResultScreen(attemptId: result.attemptId),
      ));
      Navigator.of(context).pop(true); // signal the list to refresh
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
            return ErrorRetry(
                error: snap.error!,
                onRetry: () => setState(() => _future =
                    ApiClient.instance.assessmentDetail(widget.assessmentId)));
          }
          final a = snap.data!;
          if (a.questions.isEmpty) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'No questions',
              subtitle: 'This assessment has no questions yet.',
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: a.questions.length,
                  itemBuilder: (_, i) => _questionCard(a.questions[i], i),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : () => _submit(a),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Submit answers'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _questionCard(Question q, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Q${index + 1}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Badge('${q.points} pt${q.points == 1 ? '' : 's'}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(q.text, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            _answerWidget(q),
          ],
        ),
      ),
    );
  }

  Widget _answerWidget(Question q) {
    switch (q.type) {
      case 'multiple_choice':
      case 'true_false':
      case 'yes_no':
        return RadioGroup<int>(
          groupValue: _answers[q.id] as int?,
          onChanged: (v) => setState(() => _answers[q.id] = v),
          child: Column(
            children: q.options.map((o) {
              return RadioListTile<int>(
                value: o.id,
                title: Text(o.text),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }).toList(),
          ),
        );
      case 'fill_blank':
        return TextField(
          controller: _controllerFor(q.id),
          decoration: const InputDecoration(
            labelText: 'Your answer',
            prefixIcon: Icon(Icons.short_text),
          ),
        );
      case 'essay':
        return TextField(
          controller: _controllerFor(q.id),
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Your response',
            alignLabelWithHint: true,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
