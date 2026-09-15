import 'package:flutter/material.dart' hide Badge;

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../shared/widgets.dart';

/// Shows a graded (or pending) attempt with per-question breakdown.
/// Used by students to review their own results.
class AttemptResultScreen extends StatefulWidget {
  final int attemptId;
  const AttemptResultScreen({super.key, required this.attemptId});
  @override
  State<AttemptResultScreen> createState() => _AttemptResultScreenState();
}

class _AttemptResultScreenState extends State<AttemptResultScreen> {
  late Future<AttemptDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.attemptDetail(widget.attemptId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: FutureBuilder<AttemptDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorRetry(
                error: snap.error!,
                onRetry: () => setState(() => _future =
                    ApiClient.instance.attemptDetail(widget.attemptId)));
          }
          final a = snap.data!;
          final pending = a.status == 'completed';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _scoreHeader(a, pending),
              const SizedBox(height: 16),
              ...a.answers.map(_answerCard),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreHeader(AttemptDetail a, bool pending) {
    final scheme = Theme.of(context).colorScheme;
    final score = a.score?.toStringAsFixed(0) ?? '--';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(a.assessmentTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('$score%',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary)),
            const SizedBox(height: 8),
            if (pending)
              const Badge('Awaiting essay grade',
                  icon: Icons.hourglass_bottom, color: Colors.blueGrey)
            else
              const Badge('Graded',
                  icon: Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _answerCard(AttemptAnswer ans) {
    final scheme = Theme.of(context).colorScheme;
    Color? statusColor;
    IconData? statusIcon;
    if (ans.type == 'essay' && ans.isCorrect == null) {
      statusColor = Colors.blueGrey;
      statusIcon = Icons.hourglass_bottom;
    } else if (ans.isCorrect == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (ans.isCorrect == false) {
      statusColor = scheme.error;
      statusIcon = Icons.cancel;
    }

    final given = ans.chosenOption ?? ans.answerText;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (statusIcon != null)
                  Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ans.text,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  ans.pointsEarned != null
                      ? '${ans.pointsEarned}/${ans.points}'
                      : '-/${ans.points}',
                  style: TextStyle(color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _kv('Your answer', given?.isNotEmpty == true ? given! : '—'),
            if (ans.type != 'essay' &&
                ans.correctAnswer != null &&
                ans.isCorrect == false)
              _kv('Correct answer', ans.correctAnswer!),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(color: scheme.outline, fontSize: 13)),
            TextSpan(text: value, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
