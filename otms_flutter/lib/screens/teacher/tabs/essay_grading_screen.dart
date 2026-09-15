import 'package:flutter/material.dart' hide Badge;

import '../../../models/models.dart';
import '../../../services/api_client.dart';
import '../../shared/widgets.dart' show LoadingView, ErrorRetry, EmptyState, Badge, showError, showOk;

/// Teacher screen to grade essay answers in an attempt.
/// Shows only essay questions that haven't been graded yet.
class EssayGradingScreen extends StatefulWidget {
  final int attemptId;
  const EssayGradingScreen({super.key, required this.attemptId});
  @override
  State<EssayGradingScreen> createState() => _EssayGradingScreenState();
}

class _EssayGradingScreenState extends State<EssayGradingScreen> {
  late Future<AttemptDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.attemptDetail(widget.attemptId);
  }

  void _reload() =>
      setState(() => _future = ApiClient.instance.attemptDetail(widget.attemptId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grade essays')),
      body: FutureBuilder<AttemptDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorRetry(error: snap.error!, onRetry: _reload);
          }
          final detail = snap.data!;
          final essayAnswers = detail.answers.where((a) =>
              a.type == 'essay' &&
              a.answerId != null &&
              a.isCorrect == null).toList();

          if (essayAnswers.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No essays to grade',
              subtitle: 'All essay questions have been graded for this attempt.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: essayAnswers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _EssayGradeCard(
              answer: essayAnswers[i],
              onGraded: _reload,
            ),
          );
        },
      ),
    );
  }
}

class _EssayGradeCard extends StatefulWidget {
  final AttemptAnswer answer;
  final VoidCallback onGraded;
  const _EssayGradeCard({
    required this.answer,
    required this.onGraded,
  });
  @override
  State<_EssayGradeCard> createState() => _EssayGradeCardState();
}

class _EssayGradeCardState extends State<_EssayGradeCard> {
  final _pointsCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final points = int.tryParse(_pointsCtrl.text.trim());
    if (points == null || points < 0 || points > widget.answer.points) {
      showError(context, 'Enter points between 0 and ${widget.answer.points}.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.gradeEssay(widget.answer.answerId!, points);
      if (!mounted) return;
      showOk(context, 'Essay graded');
      widget.onGraded();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
                Icon(Icons.edit_document, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.answer.text,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Badge('${widget.answer.points} pts',
                    color: scheme.secondary),
              ],
            ),
            const SizedBox(height: 12),
            Text('Student answer:',
                style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.answer.answerText?.isNotEmpty == true
                    ? widget.answer.answerText!
                    : '(no answer)',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points earned (0-${widget.answer.points})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}