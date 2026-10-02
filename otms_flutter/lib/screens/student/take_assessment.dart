import 'dart:async';

import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/widgets.dart';
import 'attempt_result.dart';

/// Starts a server-side attempt before revealing questions. The local timer is
/// UX only; the backend remains authoritative for attempt limits and deadlines.
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
  late Future<StartedAttempt> _future;
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _text = {};
  Timer? _timer;
  Duration? _remaining;
  bool _submitting = false;
  bool _autoSubmitTriggered = false;
  String? _expiryMessage;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  Future<StartedAttempt> _start() async {
    final started = await Api.instance.startAttempt(widget.assessmentId);
    _startTimer(started);
    return started;
  }

  void _startTimer(StartedAttempt started) {
    final deadlineAt = started.deadlineAt;
    _timer?.cancel();
    if (deadlineAt == null) return;
    final deadline = DateTime.tryParse(deadlineAt)?.toUtc();
    if (deadline == null) return;
    void tick() {
      final next = deadline.difference(DateTime.now().toUtc());
      if (!mounted) return;
      setState(() => _remaining = next.isNegative ? Duration.zero : next);
      // Submit just before the server deadline. This leaves a small transport
      // margin and the endpoint is idempotent, so its single network retry is safe.
      if (next <= const Duration(seconds: 2) && !_autoSubmitTriggered) {
        _autoSubmitTriggered = true;
        unawaited(_submit(started, automatic: true));
      }
      if (next <= Duration.zero) _timer?.cancel();
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int questionId) =>
      _text.putIfAbsent(questionId, TextEditingController.new);

  Future<void> _submit(StartedAttempt started, {bool automatic = false}) async {
    if (_submitting) return;
    final assessment = started.assessment;
    for (final question in assessment.questions) {
      if (question.type == 'fill_blank' || question.type == 'essay') {
        _answers[question.id] = _controllerFor(question.id).text.trim();
      }
    }
    final unanswered = assessment.questions.where((question) {
      final value = _answers[question.id];
      return value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
    }).length;
    if (unanswered > 0 && !automatic) {
      final submit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit anyway?'),
          content: Text('$unanswered question(s) are unanswered.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (submit != true) return;
    }

    setState(() => _submitting = true);
    try {
      final result = await Api.instance.submitAttempt(
        started.attemptId,
        _answers,
      );
      if (!mounted) return;
      _timer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AttemptResultScreen(attemptId: result.attemptId),
        ),
        result: true,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _expiryMessage = automatic
              ? 'Automatic submission could not be confirmed. Open the attempt status to verify what the server received.'
              : null;
        });
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _timerText(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_remaining != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Badge(
                  _timerText(_remaining!),
                  icon: Icons.timer_outlined,
                  color: _remaining! < const Duration(minutes: 2)
                      ? Colors.red
                      : null,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<StartedAttempt>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () => setState(() => _future = _start()),
            );
          }
          final started = snapshot.data!;
          final questions = started.assessment.questions;
          if (questions.isEmpty) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'No questions',
              subtitle: 'This assessment cannot be taken yet.',
            );
          }
          final expired = _remaining == Duration.zero;
          return Column(
            children: [
              if (_expiryMessage != null)
                MaterialBanner(
                  content: Text(_expiryMessage!),
                  leading: const Icon(Icons.sync_problem_outlined),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              AttemptResultScreen(attemptId: started.attemptId),
                        ),
                        result: true,
                      ),
                      child: const Text('Check status'),
                    ),
                  ],
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  itemBuilder: (_, index) =>
                      _questionCard(questions[index], index),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : expired
                          ? () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => AttemptResultScreen(
                                  attemptId: started.attemptId,
                                ),
                              ),
                              result: true,
                            )
                          : () => _submit(started),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              expired
                                  ? 'View attempt status'
                                  : 'Submit answers',
                            ),
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

  Widget _questionCard(Question question, int index) => Card(
    key: ValueKey(question.id),
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Q${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Badge('${question.points} pt${question.points == 1 ? '' : 's'}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.text, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          _answerWidget(question),
        ],
      ),
    ),
  );

  Widget _answerWidget(Question question) {
    switch (question.type) {
      case 'single_choice':
      case 'multiple_choice': // compatibility with pre-migration test fakes
      case 'true_false':
      case 'yes_no':
        return RadioGroup<int>(
          groupValue: _answers[question.id] as int?,
          onChanged: (value) => setState(() => _answers[question.id] = value),
          child: Column(
            children: question.options
                .map(
                  (option) => RadioListTile<int>(
                    value: option.id,
                    title: Text(option.text),
                    contentPadding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),
        );
      case 'multiple_select':
        final selected = ((_answers[question.id] as List<int>?) ?? <int>[])
            .toSet();
        return Column(
          children: question.options.map((option) {
            return CheckboxListTile(
              value: selected.contains(option.id),
              title: Text(option.text),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    selected.add(option.id);
                  } else {
                    selected.remove(option.id);
                  }
                  _answers[question.id] = selected.toList();
                });
              },
            );
          }).toList(),
        );
      case 'fill_blank':
        return TextField(
          controller: _controllerFor(question.id),
          decoration: const InputDecoration(
            labelText: 'Your answer',
            prefixIcon: Icon(Icons.short_text),
          ),
        );
      case 'essay':
        return TextField(
          controller: _controllerFor(question.id),
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Your response',
            alignLabelWithHint: true,
          ),
        );
      default:
        return const Text('Unsupported question type.');
    }
  }
}
